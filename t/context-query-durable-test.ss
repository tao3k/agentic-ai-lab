;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Native source commands, actual workers and process-death recovery. Timer
;;; delivery is disabled here; the existing clock qualification owns expiry.
(import
 (only-in :clan/poo/object .o .ref .call)
 (only-in :std/list/list every find)
 (prefix-in :agentic-ai-lab/t/context-query-provider-test query.)
 (only-in :agentic-ai-lab/t/qualification/context-temporal/evaluator/fixtures
                 authority-fixture)
 :agentic-ai-lab/modules/ai-agentic-context/query-provider
 :agentic-ai-lab/modules/ai-agentic-context/durable-owner
 :agentic-ai-lab/modules/ai-agentic-context/session-host
 :agentic-ai-lab/modules/ai-agentic-context/funs-features
 :agentic-ai-lab/modules/query/semantic/context-restriction
 :agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
 :agentic-ai-lab/modules/temporal-causality/runtime/policy-clock)
(export query-durable-driver retain-originals!)

(def (ensure value message)
  (unless value (error message)))

(def (rejected? operation)
  (with-catch (lambda (e) #t) (lambda () (operation) #f)))

(def (file-text path)
  (call-with-input-file path (lambda (port) (read-line port #f))))

(def (original-source)
  (file-text "modules/ai-agentic-context/org-contract/templates/evidence-source.org"))

;;; Recovery cuts are installed before the adapter constructor. They therefore
;;; stop real pending-input replay or the current epoch's readiness commit,
;;; before the reactor can announce that bootstrap has completed.
(def (recovery-cut-input? identity-value kind-value)
  (if (equal? kind-value "source")
      (equal? identity-value "source-change")
      (let (prefix "owner-recovery:")
        (and (string? identity-value)
             (>= (string-length identity-value) (string-length prefix))
             (equal? prefix (substring identity-value 0 (string-length prefix)))))))

(def (inspect-recovery-cut! journal host zero? kind-value stage-value)
  (let* ((root (journal-get journal "query-catalog"))
         (head (find (lambda (cut) (equal? (.ref cut 'identity) "source-a"))
                     (reverse (.ref root 'history)))))
    ;; Within before-commit, this is provisional state seen by its own writer.
    ;; The Python gate independently checks the committed crash image afterwards.
    (ensure (= (.ref head 'generation) 2) "Recovery cut has the wrong source head")
    (unless zero?
      (query.assert-push host)
      (for-each
       (lambda (role)
         (let* ((terminals (query.outcomes host role))
                (obligations (.ref (.ref (query.row host role) 'schedule) 'obligations)))
           (ensure (<= (length terminals) 1) "Repeated recovery duplicated a terminal")
           (ensure (= (length obligations) (if (null? terminals) 1 0))
                   "Repeated recovery lost or duplicated a worker obligation")))
       '("a" "b")))
    (when zero?
      (ensure (null? (.ref root 'queries)) "Empty recovery fabricated a Query")
      (ensure (null? (.ref (context-host-checkpoint host) 'entries))
              "Empty recovery fabricated a Session consumer"))
    (displayln "QUERY-RECOVERY-STATE kind=" kind-value " stage=" stage-value
               " epoch=" (journal-epoch journal)
               " provisional-generation=2 obligations-exact=#t terminals-unique=#t zero=" zero?)
    (force-output)))

;;; Preserve the actual native domain fixture inputs used by both processes.
(def (retain-originals! journal db)
  (for-each
   (lambda (row)
     (let* ((key (car row))
            (bytes (or (journal-get journal key #t) (file-text (cadr row))))
            (copy-path (string-append db "." key ".ss")))
       (journal-evidence! journal key bytes)
       (when (file-exists? copy-path) (delete-file copy-path))
       (call-with-output-file copy-path (lambda (port) (display bytes port)))
       (setenv (caddr row) copy-path)))
   '(("query-rules" "t/qualification/temporal-library-basic/rule-correspondence-v1/typed-rules.ss"
      "AGENTIC_AI_LAB_MRR_RULE_ORACLE")
     ("query-facts" "t/qualification/temporal-library-basic/derivation-authority-v1/typed-derivations.ss"
      "AGENTIC_AI_LAB_MRR_DERIVATION_ORACLE"))))

(def (query-durable-driver db mode order-text stage-text profile)
  (let ((journal #f) (adapter #f) (restored? #f) (arrival '())
        (caller (current-thread)) (zero? (equal? profile "zero")))
    (def (setup)
      (set! journal (journal-open db))
      (retain-originals! journal db)
      (set! restored? (if (journal-get journal "context") #t #f))
      (let-values (((authority-value host-value initial-provider workers-value)
                    (if zero?
                        (let* ((f (authority-fixture #t #f 10 #f))
                               (h (agentic-ai-lab-ai-agentic-context-session-host
                                   (.ref f 'grants) (.ref f 'policies) #t #t))
                               (p (context-query-host)))
                          (context-query-source! p (context-org-source "source-a" 1 (original-source)))
                          (values f h p (make-hash-table)))
                        (query.fixture #t))))
        (unless (or restored? zero?)
          (query.attach host-value workers-value "a" 2 caller)
          (query.attach host-value workers-value "b" 3 caller)
          (query.attach host-value workers-value "c"))
        (when (equal? mode "recovery-cut")
          (ensure restored? "Recovery cut requires an original committed crash image")
          (ensure (or (equal? order-text "source") (equal? order-text "ready"))
                  "Unknown recovery cut kind")
          (journal-cut! journal
            (lambda (stage identity-value)
              (when (and (recovery-cut-input? identity-value order-text)
                         (eq? stage (string->symbol stage-text)))
                (inspect-recovery-cut! journal host-value zero? order-text stage-text)
                (displayln "QUERY-RECOVERY-HELD " order-text " " stage-text)
                (force-output)
                (read-line)))))
        (set! adapter
          (context-durable-adapter journal host-value
            (.ref authority-value 'grants) (.ref authority-value 'policies)
            (lambda (registration) (.ref authority-value 'proof)) initial-provider))
        (values
         (.o authority: authority-value host: host-value workers: workers-value
             provider: (.call adapter .query-provider adapter))
         (.ref authority-value 'policies) adapter)))

    ;; Deliberately unsafe native control: restore the committed catalog and
    ;; consumers but omit replay of the actually persisted pending source input.
    (if (equal? mode "counter")
        (begin
          (set! journal (journal-open db))
          (retain-originals! journal db)
          (let-values (((authority-value host-value initial-provider workers-value) (query.fixture #t))
                       ((provider observed) (context-query-restore (journal-get journal "query-catalog"))))
            (context-host-restore! host-value (journal-get journal "context")
                                  (lambda (registration) (.ref authority-value 'proof)) provider)
            (ensure (find (lambda (r) (and (equal? (.ref r 'id) "source-change")
                                          (equal? (.ref r 'status) "pending")))
                          (journal-rows journal)) "Counter requires real pending source input")
            (ensure (eq? (.ref (query.row host-value "a") 'context-state) 'admitted)
                    "Missing-replay control did not expose admitted old Context")
            (displayln "QUERY-DURABLE-COUNTER omitted-source-replay cached-a=admitted pending-source=#t"))
          (journal-close! journal))
        (let (clock (policy-clock-owner setup "txn" 1 3600. 0. 1 #t #f))
          (def (read! operation) (policy-clock-call! clock operation))
          (def (command! id-value name-value body-value operation)
            (policy-clock-command! clock
              (.o kind: 'context.durable-command.v1 identity: id-value
                  operation: name-value body: body-value) operation))
          (def (source-command! intent)
            (policy-clock-command! clock intent
              (lambda (resource) (.call adapter .query-source! adapter intent))))
          (cond
           ((equal? mode "recovery-cut")
            (policy-clock-stop! clock)
            (error "Expected recovery cut was not reached before owner opening"))
           ((equal? mode "pre")
            (ensure (not restored?) "Pre process requires a fresh journal")
            (unless zero?
              (command! "unaffected-c" 'result "c"
                (lambda (r)
                  (ensure (.ref (query.commit (.ref r 'host) (.ref r 'workers) "c")
                                'native-result-published?) "C actual completion failed"))))
            (let* ((intent
                    (read! (lambda (r)
                      (let* ((old (context-query-current-source (.ref r 'provider) "source-a"))
                             (replacement (context-org-source "source-a" 2
                                            (if (equal? profile "replace")
                                                (string-append (original-source) "\nNew source bytes.\n")
                                                (original-source))
                                            (equal? profile "replace"))))
                        (context-durable-source-command "source-change" (.ref old 'semantic-digest) replacement)))))
                   (order
                    (if zero? '(1)
                        (begin
                          (thread-join! (thread-start! (make-thread (lambda () (thread-send caller 1)))))
                          (thread-join! (thread-start! (make-thread (lambda ()
                            (thread-send caller 4) (thread-yield!) (thread-send caller 5)))))
                          (let receive ((remaining 5))
                            (unless (= remaining 0)
                              (set! arrival (append arrival (list (thread-receive))))
                              (receive (- remaining 1))))
                          (if (equal? order-text "arrival") arrival
                              (call-with-input-string order-text read))))))
              (displayln "QUERY-DURABLE-ORDER owner=" order " arrival=" arrival)
              (force-output)
              (read! (lambda (r)
                (journal-cut! journal
                  (lambda (stage id-value)
                    (when (and (equal? id-value "source-change")
                               (eq? stage (string->symbol stage-text)))
                      (displayln "QUERY-DURABLE-HELD " stage-text)
                      (force-output)
                      (read-line))))))
              (for-each
               (lambda (move)
                 (case move
                  ((1) (source-command! intent))
                  ((2 3)
                   (let (role (if (= move 2) "a" "b"))
                     (command! (string-append "result-" role) 'result role
                       (lambda (r) (query.commit (.ref r 'host) (.ref r 'workers) role)))))
                  ((4) (command! "cancel-a" 'cancel "a"
                         (lambda (r) (agentic-ai-lab-ai-agentic-context-session-host-cancel!
                           (.ref r 'host) (query.sid "a") (query.revision (.ref r 'host) "a") 1))))
                  ((5) (command! "recover-a" 'recover "a"
                         (lambda (r) (agentic-ai-lab-ai-agentic-context-session-host-recover!
                           (.ref r 'host) (query.sid "a") (query.revision (.ref r 'host) "a") 1))))))
               order)
              (error "Expected process-death hook was not reached")))

           ((equal? mode "post")
            (ensure restored? "Recovery did not use the committed journal")
            (read! (lambda (r)
              (let* ((provider (.ref r 'provider))
                     (current (context-query-current-source provider "source-a")))
                (ensure (= (.ref current 'generation) 2) "Pending source did not recover exactly once")
                (ensure (equal? (.ref current 'active?) (equal? profile "replace"))
                        "Recovered source operation changed kind")
                (unless zero?
                  ;; Inspect cached invalidation before any Query current-use check.
                  (query.assert-push (.ref r 'host))
                  (ensure (eq? provider (context-host-query-provider (.ref r 'host)))
                          "Restored consumers escaped the durable catalog")
                  (ensure (= (length (query.outcomes (.ref r 'host) "c")) 1)
                          "Unaffected actual completion was lost")
                  (ensure (every (lambda (t) (.ref t 'current-use?))
                                 (query.outcomes (.ref r 'host) "c"))
                          "Unaffected C completion lost applicability")
                  (for-each (lambda (role)
                    (ensure (<= (length (query.outcomes (.ref r 'host) role)) 1)
                            "Attempt acquired a second terminal")
                    (ensure (every (lambda (t) (not (.ref t 'current-use?)))
                                   (query.outcomes (.ref r 'host) role))
                            "Old result became current after restart")
                    (when (null? (query.outcomes (.ref r 'host) role))
                      (ensure (pair? (.ref (.ref (query.row (.ref r 'host) role) 'schedule) 'obligations))
                              "Owner death erased an unresolved worker obligation"))) '("a" "b"))
                  (ensure
                   (rejected? (lambda ()
                     (agentic-ai-lab-ai-agentic-context-session-host-commit-result!
                      (.ref r 'host) (query.sid "a") (query.revision (.ref r 'host) "a") 1
                      (.o kind: 'agentic-ai-lab.ai-agentic-context.observation-capability.v1))))
                   "Portable old worker data recreated a live observation capability"))
                (when zero?
                  (ensure (null? (.ref (context-query-export provider) 'queries))
                          "Zero-consumer recovery fabricated a Query"))
                (let* ((root (context-query-export provider))
                       (original (find (lambda (cut)
                         (and (equal? (.ref cut 'identity) "source-a") (= (.ref cut 'generation) 1)))
                         (.ref root 'history))))
                  (ensure (and original (equal? (.ref original 'source) (original-source)))
                          "Source withdrawal deleted the original bytes")
                  ;; Cache checks above precede this independent support check.
                  (for-each (lambda (observation)
                    (when (equal? (.ref (.ref observation 'source-cut) 'identity) "source-a")
                      (ensure (not (context-query-current? provider observation))
                              "Original native Query support revived")))
                    (.ref root 'queries)))
                (displayln "QUERY-DURABLE-RECOVER generation=2 affected-fenced=#t unaffected-preserved=#t zero=" zero?))))

            ;; Same original command returns a historical ACK without applying
            ;; again. Changed bytes at that ID must be refused before the ACK.
            (let* ((original
                    (read! (lambda (r)
                      (.ref (find (lambda (row) (equal? (.ref row 'id) "source-change"))
                                  (journal-rows journal)) 'payload)))))
              (ensure (.ref (source-command! original) 'historical?) "Duplicate command was re-executed")
              (ensure
               (rejected? (lambda ()
                 (source-command! (.o (:: @ original)
                   body: (.o (:: @ (.ref original 'body)) expected: "forged-cut")))))
               "Historical ACK accepted command identity substitution"))

            (let* ((intent3
                    (read! (lambda (r)
                      (let (current (context-query-current-source (.ref r 'provider) "source-a"))
                        (context-durable-source-command "readmit-source"
                          (.ref current 'semantic-digest)
                          (context-org-source "source-a" 3 (original-source))))))))
              (source-command! intent3)
              (let (delayed
                    (read! (lambda (r)
                      (let (original (.ref (find (lambda (row) (equal? (.ref row 'id) "source-change"))
                                                (journal-rows journal)) 'payload))
                        (.o (:: @ original) identity: "delayed-old-source")))))
                (source-command! delayed)))
            ;; First admission uses the same command/CAS path, with no previous
            ;; cut and no consumer or fabricated observation for this source.
            (source-command!
             (context-durable-source-command "admit-unqueried-source" #f
               (context-org-source "new-source" 1 (original-source))))
            (read! (lambda (r)
              (ensure (= (.ref (context-query-current-source (.ref r 'provider) "source-a") 'generation) 3)
                      "Delayed source command rolled back the new head")
              (ensure (not (.ref (journal-get journal "query-source-decision:delayed-old-source") 'accepted?))
                      "Delayed old command was rebased as a fresh source")
              (ensure (= (.ref (context-query-current-source (.ref r 'provider) "new-source") 'generation) 1)
                      "First source admission failed")
              (unless zero? (query.assert-push (.ref r 'host)))
              (displayln "QUERY-DURABLE-RETRY duplicate=historical substituted=refused delayed=refused generation=3")))
            (policy-clock-stop! clock))
           (else (error "Unknown durable Query mode" mode)))))
    (displayln "MODULE-OK t/context-query-durable-test.ss")
    (displayln "HARNESS-OK context-query-durable")
    (displayln "OK")))
