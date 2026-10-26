;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Native scenarios: real Orgize, GQL execution, ASCENT and worker observations.
(import (only-in :clan/poo/object .o .ref)
        (only-in :std/list/list find every)
        (only-in :std/text/pregexp pregexp-replace*)
        :agentic-ai-lab/modules/ai-agentic-context/query-provider
        :agentic-ai-lab/modules/ai-agentic-context/session-host
        :agentic-ai-lab/modules/ai-agentic-context/funs-features
        :agentic-ai-lab/modules/query/semantic/context-restriction
        :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host
        :agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
        :agentic-ai-lab/modules/session/funs-identity
        (only-in :agentic-ai-lab/t/temporal-evaluator-test
                 authority-fixture context-scope))
(export context-query-driver fixture sid row revision attach joined commit outcomes assert-push)

(def (ensure value message)
  (unless value (error message)))

(def (rejected? operation)
  (with-catch (lambda (e) #t) (lambda () (operation) #f)))

(def (template)
  (call-with-input-file
      "modules/ai-agentic-context/org-contract/templates/evidence-source.org"
    (lambda (port) (read-line port #f))))

(def session-namespace (make-parameter "context-query-native"))

(def (sid role)
  (agentic-ai-lab-session-identity (session-namespace) role))

(def (row host role)
  (agentic-ai-lab-ai-agentic-context-session-host-current host (sid role)))

(def (revision host role)
  (.ref (.ref (row host role) 'schedule) 'revision))

(def (scope role)
  (.o (:: @ context-scope) session: (sid role)))

(def (restriction)
  (agentic-ai-lab-context-restriction
   "domain" '("actor") '("provider") '("org") 0 10))

;;; Verify source identity, local ID and program/result binding independently
;;; before constructing a Session. No supplied result rows become authority.
;;; Consumer documents keep content IDs separate from their Session reference.
;;; A literal template placeholder cannot pass runtime source admission.
(def (consumer-template)
  (call-with-input-file
      "modules/ai-agentic-context/org-contract/templates/consumer-context.org"
    (lambda (port) (read-line port #f))))

(def (consumer-controls)
  (ensure
   (rejected? (lambda () (context-org-source "uninstantiated" 1 (consumer-template))))
   "Uninstantiated Session ID placeholder admitted")
  (let* ((f (authority-fixture #t #f 10 #f))
         (host (agentic-ai-lab-ai-agentic-context-session-host
                (.ref f 'grants) (.ref f 'policies) #t #t))
         (provider (context-query-host))
         (raw (pregexp-replace* "<session-owner-hash>" (consumer-template) (sid "consumer")))
         (source (context-query-source! provider (context-org-source "consumer-source" 1 raw))))
    (ensure
     (rejected?
      (lambda ()
        (context-host-enroll-query!
         host provider "consumer-source" (context-org-query source "work")
         (scope "foreign-consumer") (restriction)
         (agentic-ai-lab-ai-agentic-context-profile #f) 0 "grant" 1)))
     "Consumer Contract silently changed Session owner")
    (ensure
     (.ref
      (context-host-enroll-query!
       host provider "consumer-source" (context-org-query source "work")
       (scope "consumer") (restriction)
       (agentic-ai-lab-ai-agentic-context-profile #f) 0 "grant" 1)
      'accepted?)
     "Owner Session template rejected")
    ;; A catalog-only root is valid durable data but cannot stand in for the
    ;; selected observation in a consumer checkpoint. Check the actual restore
    ;; entry point, as well as an unchanged positive consumer checkpoint.
    (let* ((checkpoint (context-host-checkpoint host))
           (restored (agentic-ai-lab-ai-agentic-context-session-host
                      (.ref f 'grants) (.ref f 'policies) #t #t))
           (missing-observation
            (.o (:: @ checkpoint)
              entries:
              (map (lambda (entry)
                     (.o (:: @ entry)
                       query: (.o (:: @ (.ref entry 'query)) observation-ref: #f)))
                   (.ref checkpoint 'entries)))))
      (context-host-restore! restored checkpoint (lambda (registration) (.ref f 'proof)))
      (ensure (eq? (.ref (row restored "consumer") 'context-state) 'admitted)
              "Original consumer observation did not restore")
      (ensure
       (rejected? (lambda ()
         (context-host-restore!
          (agentic-ai-lab-ai-agentic-context-session-host
           (.ref f 'grants) (.ref f 'policies) #t #t)
          missing-observation (lambda (registration) (.ref f 'proof)))))
       "Catalog root was accepted as a consumer observation"))
    (let* ((foreign-raw
             (pregexp-replace* "<session-owner-hash>" (consumer-template)
               (sid "foreign-consumer")))
           (foreign-source
             (context-query-source! provider
               (context-org-source "consumer-source" 2 foreign-raw))))
      (ensure
        (rejected?
          (lambda ()
            (context-host-refresh-query!
              host (sid "consumer") (revision host "consumer") 1
              (context-org-query foreign-source "work"))))
        "Query re-admission silently changed Session ownership")
      (ensure (eq? (.ref (row host "consumer") 'context-state) 'invalidated)
        "Rejected re-admission restored old Context")))
  (displayln "QUERY-SESSION-ID placeholder=rejected foreign-session=rejected foreign-refresh=rejected owner-hash-admitted=#t"))

(def (source-controls)
  (let* ((provider (context-query-host))
         (a (context-query-source! provider (context-org-source "source-a" 1 (template))))
         (c (context-query-source! provider (context-org-source "source-c" 1 (template))))
         (query (context-org-query a "work"))
         (observed (context-query-execute provider "source-a" query))
         (lineage (context-query-lineage observed))
         (saved (context-query-export provider observed)))
    (ensure (= (length (.ref observed 'proofs)) 1) "Missing actual ASCENT proof")
    (ensure (pair? (.ref (car (.ref observed 'proofs)) 'dag)) "Missing original native proof DAG")
    (ensure (.ref (.ref observed 'query-receipt) 'admitted?) "Provider receipt denied")
    (ensure (context-query-current? provider observed) "Current Query denied")
    (ensure (not (equal? (.ref a 'semantic-digest) (.ref c 'semantic-digest)))
            "Equal local IDs merged different source catalogs")
    (ensure (rejected? (lambda () (context-query-execute provider "source-c" query)))
            "Same local ID silently rebound another source")
    (ensure (rejected? (lambda ()
                         (context-query-source! provider
                                                (context-org-source "source-a" 1 (string-append (template) "\nChanged bytes.\n")))))
            "Same-generation source replacement accepted")
    (ensure (rejected? (lambda ()
                         (context-org-source "duplicate" 1
                                             (string-append (template) "\n* TODO Duplicate\n:PROPERTIES:\n:ID: work\n:END:\n"))))
            "Duplicate Property ID accepted")
    (let* ((original-record (car (.ref saved 'queries)))
           (changed-descriptor
             (.o (:: @ (.ref original-record 'query-descriptor)) value: "reassessment"))
           (changed-record
             (.o (:: @ original-record) query-descriptor: changed-descriptor))
           (bad
             (.o (:: @ saved)
                 queries: (cons changed-record (cdr (.ref saved 'queries))))))
      (ensure (rejected? (lambda () (context-query-restore bad)))
              "Altered Query reused old proof/receipt"))
    ;; The same bytes survive the actual journal codec, not a test-only serializer.
    (let (portable (journal-unpack (journal-pack saved)))
      (let-values (((restored replayed) (context-query-restore portable)))
        (ensure (equal? (.ref replayed 'semantic-digest) (.ref observed 'semantic-digest))
                "Native Query proof replay differs")
        (ensure (context-query-current? restored replayed) "Replayed current support denied")))
    (displayln "QUERY-CONTROLS namespace=#t same-id-retarget=rejected duplicate-id=rejected query-forgery=rejected native-proof-replay=#t")
    (displayln "QUERY-EVIDENCE original=" (journal-pack saved))
    (ensure
     (rejected? (lambda ()
                  (context-query-execute provider "source-a"
                                         (.o (:: @ (context-org-query a "source-a" 'sourceId)) result-bound: 1))))
     "Bounded Query silently truncated its complete result")
    (let* ((raw
            (string-append (template)
                           "\n#+begin_src text\n:PROPERTIES:\n:ID: fake-id-in-block\n:END:\n#+end_src\n"))
           (block-source (context-query-source! provider (context-org-source "block-source" 1 raw)))
           (empty (context-query-execute provider "block-source"
                                         (context-org-query block-source "fake-id-in-block"))))
      (ensure (= (.ref (.ref empty 'result-set) 'result-count) 0)
              "Property-looking source block text became an Org anchor"))
    (context-query-withdraw! provider "source-a" 2)
    (ensure (not (context-query-current? provider observed)) "Withdrawn Query still current")
    (let-values (((restored replayed)
                  (context-query-restore (context-query-export provider observed))))
      (ensure (not (context-query-current? restored replayed))
              "Historical proof replay resurrected withdrawn source"))
    (let* ((new (context-query-source! provider
                                       (context-org-source "source-a" 3 (template))))
           (fresh (context-query-execute provider "source-a" (context-org-query new "work"))))
      (ensure (context-query-current? provider fresh) "New source version not admitted")
      (ensure (not (context-query-current? provider observed))
              "Re-admission resurrected old Query proof"))
    (ensure (equal? (sid "identity-check") (sid "identity-check"))
            "Session owner hash unstable")
    (ensure (not (equal? (sid "identity-check") (sid "another-creation-key")))
            "Different Session creation keys collided")
    (displayln "QUERY-CONTROLS withdrawal-support=unsupported original-proof-retained=#t")))

;;; Independent Session scope/grants still gate enrollment. The Context Provider
;;; supplies an input reference and the original domain proof remains mandatory.
(def (fixture eager?)
  (let* ((f (authority-fixture #t #f 10 #f))
         (host (agentic-ai-lab-ai-agentic-context-session-host
                (.ref f 'grants) (.ref f 'policies) #t eager?))
         (provider (context-query-host))
         (a (context-query-source! provider (context-org-source "source-a" 1 (template))))
         (c (context-query-source! provider (context-org-source "source-c" 1 (template))))
         (workers (make-hash-table)))
    (for-each
     (lambda (role)
       (let* ((source (if (equal? role "a") a c))
              (grant (if (equal? role "a") "grant" "safe-grant"))
              (registered (.ref f (if (equal? role "a") 'registration-a 'registration-c)))
              (policy-id (if (equal? role "a") "policy" "safe-policy"))
              (policy-snapshot
               (agentic-ai-lab-temporal-support-policy-host-current (.ref f 'policies) policy-id)))
         (context-host-enroll-query!
          host provider (.ref source 'identity) (context-org-query source "work")
          (scope role) (restriction) (agentic-ai-lab-ai-agentic-context-profile #f)
          0 grant 1)
         (when (equal? role "b")
           (agentic-ai-lab-ai-agentic-context-session-host-depend-on!
            host (sid role) 0 1 (list (sid "a"))))
         (agentic-ai-lab-ai-agentic-context-session-host-require-proof!
          host (sid role) 0 1 (.ref f 'proof) (.ref registered 'identity)
          1 1 (.ref (.ref policy-snapshot 'policy) 'semantic-digest) 128)
         (agentic-ai-lab-ai-agentic-context-session-host-claim!
          host (sid role) 1 1 (string-append "attempt-" role) (string-append "request-" role))))
     '("a" "b" "c"))
    (values f host provider workers)))

(def (attach host workers role (notify #f) (destination #f))
  (let* ((owner (or destination (current-thread)))
         (worker
          (thread-start!
           (make-thread
            (lambda ()
              (thread-receive)
              (when notify (thread-send owner notify))
              "native-query-result"))))
         (token
          (agentic-ai-lab-ai-agentic-context-session-host-attach-worker!
           host (sid role) (revision host role) 1 worker)))
    (hash-put! workers role (vector worker token #f))
    (thread-send worker 'return)))

(def (joined host workers role)
  (let (worker (hash-ref workers role))
    (or (vector-ref worker 2)
        (let loop ((remaining 1000))
          (let (observed
                (agentic-ai-lab-ai-agentic-context-session-host-observe-worker!
                 host (sid role) (vector-ref worker 1)))
            (if observed
                (begin (vector-set! worker 2 observed) observed)
                (begin
                  (when (= remaining 0) (error "Actual worker did not terminate"))
                  (thread-sleep! 0.001)
                  (loop (- remaining 1)))))))))

(def (commit host workers role)
  (agentic-ai-lab-ai-agentic-context-session-host-commit-result!
   host (sid role) (revision host role) 1 (joined host workers role)))

(def (outcomes host role)
  (agentic-ai-lab-ai-agentic-context-session-host-outcomes host (sid role)))

(def (assert-push host)
  ;; These are cached snapshots, before any current-proof or result-use query.
  (ensure (eq? (.ref (row host "a") 'context-state) 'invalidated) "A was not pushed invalid")
  (ensure (eq? (.ref (row host "b") 'context-state) 'invalidated) "Recalled parent did not invalidate B")
  (ensure (eq? (.ref (row host "c") 'context-state) 'admitted) "Unrelated source C overinvalidated"))

(def (index x xs)
  (let loop ((rest xs) (n 0))
    (if (= x (car rest)) n (loop (cdr rest) (+ n 1)))))

(def (orders xs)
  (if (null? xs)
      '(())
      (apply append
             (map
              (lambda (x)
                (map (lambda (tail) (cons x tail))
                     (orders (filter (lambda (v) (not (= x v))) xs))))
              xs))))

;;; Actual result workers and source/control producers race into one mailbox.
;;; Enumerated paths choose owner linearizations of those delivered messages.
;;; The observed mode runs the arrival order itself. Neither is an assertion
;;; that every possible OS schedule has been exhausted.
(def (run-path/owner kind requested-order eager?)
  (let-values (((f host provider workers) (fixture eager?)))
    (let ((owner (current-thread)) (arrival '()))
      (attach host workers "a" 2)
      (attach host workers "b" 3)
      (attach host workers "c")
      (let ((source-producer
             (thread-start! (make-thread (lambda () (thread-send owner 1)))))
            (control-producer
             (thread-start!
              (make-thread (lambda () (thread-send owner 4) (thread-yield!) (thread-send owner 5))))))
        (let receive ((n 5))
          (unless (= n 0)
            (set! arrival (append arrival (list (thread-receive))))
            (receive (- n 1))))
        (thread-join! source-producer)
        (thread-join! control-producer))
      (let ((order (or requested-order arrival)) (changed? #f))
        (for-each
         (lambda (operation)
           (case operation
             ((1)
              (if (equal? kind "withdraw")
                  (context-query-withdraw! provider "source-a" 2)
                  (context-query-source! provider
                                         (context-org-source "source-a" 2
                                                             (string-append (template) "\nA revised source with the same local ID.\n"))))
              (set! changed? #t)
              (if eager?
                  (assert-push host)
                  (ensure (eq? (.ref (row host "a") 'context-state) 'admitted)
                          "Missing-subscription counterexample not exposed")))
             ((2) (commit host workers "a"))
             ((3) (commit host workers "b"))
             ((4)
              (agentic-ai-lab-ai-agentic-context-session-host-cancel!
               host (sid "a") (revision host "a") 1))
             ((5)
              (agentic-ai-lab-ai-agentic-context-session-host-recover!
               host (sid "a") (revision host "a") 1)))
           (when (and changed? eager?) (assert-push host))
           (for-each
            (lambda (role)
              (ensure (equal? (.ref (.ref (row host role) 'schedule) 'identity) (sid role))
                      "Source revision changed independent Session identity"))
            '("a" "b" "c"))
           (for-each
            (lambda (role)
              (ensure (<= (length (outcomes host role)) 1) "Attempt acquired two native terminals")
              (when changed?
                (ensure (every (lambda (t) (not (.ref t 'current-use?))) (outcomes host role))
                        "Old result became current")))
            '("a" "b")))
         order)
        (ensure (.ref (commit host workers "c") 'native-result-published?) "Unrelated real worker C failed")
        (ensure (not (.ref (commit host workers "a") 'accepted?)) "Old result accepted after source event")
        (ensure (not (.ref (commit host workers "b") 'accepted?)) "Old parent result accepted after source event")
        ;; Round-trip the actual Context checkpoint through the persistent codec.
        ;; Recovery must reconstruct Query catalogs, native proofs and old bindings.
        (when eager?
          (let* ((saved (journal-unpack (journal-pack (context-host-checkpoint host))))
                 (restored (agentic-ai-lab-ai-agentic-context-session-host
                            (.ref f 'grants) (.ref f 'policies) #t #f)))
            (context-host-restore! restored saved (lambda (registration) (.ref f 'proof)))
            (assert-push restored)))
        (let ((expected-a (< (index 2 order) (min (index 1 order) (index 4 order))))
              (expected-b (< (index 3 order) (index 1 order))))
          (ensure
           (equal? expected-a
                   (if (find (lambda (t) (eq? (.ref t 'outcome) 'completed)) (outcomes host "a")) #t #f))
           "A did not publish exactly in the permitted native linearizations")
          (ensure
           (equal? expected-b
                   (if (find (lambda (t) (eq? (.ref t 'outcome) 'completed)) (outcomes host "b")) #t #f))
           "B did not publish exactly before source invalidation"))
        (when eager? (fresh-admission f host provider workers kind))
        (displayln (if eager? "QUERY-PATH" "QUERY-COUNTEREXAMPLE no-subscription")
                   " kind=" kind " order=" order " arrival=" arrival
                   " completed-a="
                   (if (find (lambda (t) (and (equal? (.ref t 'attempt) "attempt-a")
                                              (eq? (.ref t 'outcome) 'completed))) (outcomes host "a")) #t #f)
                   " completed-b="
                   (if (find (lambda (t) (eq? (.ref t 'outcome) 'completed)) (outcomes host "b")) #t #f)
                   " terminals-a=" (length (filter (lambda (t) (equal? (.ref t 'attempt) "attempt-a")) (outcomes host "a")))
                   " terminals-b=" (length (filter (lambda (t) (equal? (.ref t 'attempt) "attempt-b")) (outcomes host "b")))
                   " old-current=#f c-completed=#t push=" eager?)
        (when eager?
          (let ((kind-value kind)
                (order-value order)
                (checkpoint-value (context-host-checkpoint host)))
            (displayln "QUERY-CHECKPOINT "
                       (journal-pack
                        (.o kind: 'context.query-case.v1 change-kind: kind-value
                            order: order-value checkpoint: checkpoint-value)))))
        (displayln "QUERY-JOURNAL " (journal-pack (context-query-history provider)))))))

;;; Re-query inside the same Session after actual old-worker reconciliation.
;;; The new Attempt can publish, while B's captured old parent stays invalid.
(def (fresh-admission f host provider workers kind)
  (let* ((schedule (.ref (row host "a") 'schedule))
         (obligations (.ref schedule 'obligations)))
    (when (pair? obligations)
      (ensure
       (.ref
        (agentic-ai-lab-ai-agentic-context-session-host-reconcile!
         host (sid "a") (revision host "a") 1 (joined host workers "a"))
        'runtime-published?)
       "Actual old worker could not be reconciled"))
    (when (equal? kind "withdraw")
      (context-query-source! provider (context-org-source "source-a" 3 (template))))
    (let* ((source (context-query-current-source provider "source-a"))
           (generation (.ref source 'generation)))
      (context-host-refresh-query!
       host (sid "a") (revision host "a") 1 (context-org-query source "work"))
      (agentic-ai-lab-ai-agentic-context-session-host-require-proof!
       host (sid "a") (revision host "a") generation (.ref f 'proof)
       (.ref (.ref f 'registration-a) 'identity) 1 1
       (.ref (.ref f 'policy) 'semantic-digest) 128)
      (agentic-ai-lab-ai-agentic-context-session-host-claim!
       host (sid "a") (revision host "a") generation "attempt-a-fresh" "request-a-fresh")
      (let* ((worker (thread-start! (make-thread (lambda () "fresh-native-query-result"))))
             (token
              (agentic-ai-lab-ai-agentic-context-session-host-attach-worker!
               host (sid "a") (revision host "a") generation worker)))
        (thread-join! worker)
        (let (observation
              (agentic-ai-lab-ai-agentic-context-session-host-observe-worker!
               host (sid "a") token))
          (ensure
           (.ref
            (agentic-ai-lab-ai-agentic-context-session-host-commit-result!
             host (sid "a") (revision host "a") generation observation)
            'native-result-published?)
           "Fresh Query Attempt failed to publish")))
      (ensure (eq? (.ref (row host "b") 'context-state) 'invalidated)
              "Fresh parent reactivated an old captured Context version")
      (ensure (not (.ref (commit host workers "b") 'accepted?))
              "Old B result revived after parent re-admission")
      (ensure
       (every
        (lambda (t)
          (if (equal? (.ref t 'attempt) "attempt-a-fresh")
              (and (.ref t 'current-use?) (.ref t 'query-lineage))
              (not (.ref t 'current-use?))))
        (outcomes host "a"))
       "Terminal lineage or historical current-use fence failed")
      (displayln "QUERY-FRESH same-session=#t old-parent-stays-invalid=#t native-result-published=#t"))))

(def (run-path kind requested-order eager?)
  (parameterize
      ((session-namespace
        (string-append "query-scenario:"
                       (call-with-output-string
                        (lambda (port) (write (list kind requested-order eager?) port))))))
    (run-path/owner kind requested-order eager?)))

;;; Native counterexample for the missing Provider boundary. Raw source enrollment
;;; cannot subscribe to an unrelated catalog it was never told about. Its actual
;;; worker result remains publishable after that catalog withdraws the source.
(def (unbound-source-counter)
  (parameterize ((session-namespace "legacy-unbound-source-control"))
    (let* ((f (authority-fixture #t #f 10 #f))
           (provider (context-query-host))
           (source (context-query-source! provider (context-org-source "source-a" 1 (template))))
           (host (agentic-ai-lab-ai-agentic-context-session-host
                  (.ref f 'grants) (.ref f 'policies) #t #t))
           (workers (make-hash-table)))
      (agentic-ai-lab-ai-agentic-context-session-host-enroll!
       host 1 (.ref source 'source) (scope "a") (restriction)
       (agentic-ai-lab-ai-agentic-context-profile #f) 0 '("work") "grant" 1)
      (agentic-ai-lab-ai-agentic-context-session-host-require-proof!
       host (sid "a") 0 1 (.ref f 'proof)
       (.ref (.ref f 'registration-a) 'identity) 1 1
       (.ref (.ref f 'policy) 'semantic-digest) 128)
      (agentic-ai-lab-ai-agentic-context-session-host-claim!
       host (sid "a") 1 1 "legacy-attempt" "legacy-request")
      (attach host workers "a")
      (context-query-withdraw! provider "source-a" 2)
      (ensure (.ref (commit host workers "a") 'native-result-published?)
              "Unbound-source native counterexample failed to expose missing lineage")
      (displayln "QUERY-COUNTEREXAMPLE unbound-source actual-stale-result-published=#t"))))

;;; Replay an actual saved checkpoint in a fresh native process. Native source
;;; producers are reconstructed from the pinned original fixture inputs; GQL and
;;; Org membership proofs are reconstructed from the retained source history.
(def (restore-path path)
  (let* ((saved
          (journal-unpack
           (call-with-input-file path (lambda (port) (read-line port #f)))))
         (kind (.ref saved 'change-kind))
         (order (.ref saved 'order)))
    (parameterize
        ((session-namespace
          (string-append "query-scenario:"
                         (call-with-output-string
                          (lambda (port) (write (list kind order #t) port))))))
      (let* ((f (authority-fixture #t #f 10 #f))
             (host (agentic-ai-lab-ai-agentic-context-session-host
                    (.ref f 'grants) (.ref f 'policies) #t #f)))
        (context-host-restore! host (.ref saved 'checkpoint)
                               (lambda (registration) (.ref f 'proof)))
        (ensure (eq? (.ref (row host "a") 'context-state) 'admitted)
                "Fresh Query Context did not recover")
        (ensure (eq? (.ref (row host "b") 'context-state) 'invalidated)
                "Captured old parent reactivated during recovery")
        (ensure (eq? (.ref (row host "c") 'context-state) 'admitted)
                "Unrelated Context C lost admission")
        (ensure
         (every
          (lambda (terminal)
            (if (equal? (.ref terminal 'attempt) "attempt-a-fresh")
                (.ref terminal 'current-use?)
                (not (.ref terminal 'current-use?))))
          (outcomes host "a"))
         "Historical A result revived after native checkpoint replay")
        (ensure (every (lambda (t) (not (.ref t 'current-use?))) (outcomes host "b"))
                "Historical B result revived after native checkpoint replay")
        (ensure (every (lambda (t) (.ref t 'current-use?)) (outcomes host "c"))
                "Unrelated C result lost current support")
        (displayln "QUERY-RESTORE kind=" kind " order=" order
                   " native-proof-replayed=#t old-current=#f fresh-current=#t parent-fenced=#t")))))

(def (context-query-driver mode order-text)
  (if (equal? mode "restore")
      (restore-path order-text)
      (begin
        (source-controls)
        (consumer-controls)
        (cond
         ((equal? mode "smoke") #t)
         ((equal? mode "counter")
          (run-path "withdraw" '(1 2 3 4 5) #f)
          (unbound-source-counter))
         (else
          (let (paths
                (if (equal? order-text "all")
                    (filter (lambda (p) (< (index 4 p) (index 5 p)))
                            (orders '(1 2 3 4 5)))
                    (list (call-with-input-string order-text read))))
            (for-each
             (lambda (kind)
               (for-each (lambda (path) (run-path kind path #t)) paths)
               (run-path kind #f #t))
             '("replace" "withdraw")))))))
  (displayln "MODULE-OK t/context-query-provider-test.ss")
  (displayln "HARNESS-OK context-query-provider")
  (displayln "OK"))
