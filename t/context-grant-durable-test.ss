;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Production grant revocation through the real durable owner and native
;;; ASCENT/Query/Session fixture. Raw source evidence stays valid and retained.
(import
 (only-in :clan/poo/object .o .ref .call)
 (only-in :std/list/list every find)
 (prefix-in :agentic-ai-lab/t/context-query-provider-test query.)
 (only-in :agentic-ai-lab/t/context-query-durable-test retain-originals!)
 :agentic-ai-lab/modules/ai-agentic-context/durable-owner
 :agentic-ai-lab/modules/ai-agentic-context/use-host
 :agentic-ai-lab/modules/ai-agentic-context/query-provider
 :agentic-ai-lab/modules/ai-agentic-context/session-host
 :agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
 :agentic-ai-lab/modules/temporal-causality/runtime/policy-clock)
(export grant-durable-driver)

(def (ensure value message)
  (unless value (error message)))

(def (rejected? operation)
  (with-catch (lambda (e) #t) (lambda () (operation) #f)))

(def (resource-grants resource)
  (.ref (.ref resource 'authority) 'grants))

;;; This is a fixture copy using the existing POO grant constructor, not a new
;;; authorization language. It also constructs a canonical resurrection probe.
(def (grant-copy grant-value identity-value generation-value enabled-value)
  (agentic-ai-lab-context-use-grant
   identity-value generation-value (.ref grant-value 'manifest-digest)
   (.ref grant-value 'admission-digest) (.ref grant-value 'contract)
   (.ref grant-value 'policy-identity) (.ref grant-value 'policy-digest)
   (.ref grant-value 'purposes) enabled-value))

(def (check-revoked! resource journal)
  (let* ((host (.ref resource 'host))
         (grants (resource-grants resource))
         (grant-value (agentic-ai-lab-context-use-host-current grants "grant")))
    ;; Check pushed cached state before asking the independent support guard.
    (query.assert-push host)
    (ensure (and (= (.ref grant-value 'generation) 2) (not (.ref grant-value 'enabled?)))
            "Revocation was not recovered at its exact grant cut")
    (for-each
     (lambda (role)
       (let ((terminals (query.outcomes host role))
             (pending (.ref (.ref (query.row host role) 'schedule) 'obligations)))
         (ensure (<= (length terminals) 1) "Duplicate Attempt terminal")
         (ensure (every (lambda (t) (not (.ref t 'current-use?))) terminals)
                 "Revoked or captured-parent result became current")
         (ensure (= (length pending) (if (null? terminals) 1 0))
                 "Grant recovery lost or duplicated a worker obligation")))
     '("a" "b"))
    (ensure (= (length (query.outcomes host "c")) 1) "Unaffected C completion disappeared")
    (ensure (every (lambda (t) (.ref t 'current-use?)) (query.outcomes host "c"))
            "Unrelated C lost authority")
    (let (root (context-query-export (.ref resource 'provider)))
      (ensure (= (length (.ref root 'history)) 2) "Grant revocation changed source history")
      (ensure (= (length (.ref root 'queries)) 3) "Original Query observations were lost")
      (ensure (every (lambda (q) (context-query-current? (.ref resource 'provider) q))
                     (.ref root 'queries))
              "Authority revocation incorrectly retracted source evidence"))
    (displayln "GRANT-STATE affected-a-b=invalidated unaffected-c=current evidence=supported obligations=exact")
    (force-output)))

(def (collect-order order-text caller)
  (thread-join! (thread-start! (make-thread (lambda () (thread-send caller 1)))))
  (thread-join! (thread-start! (make-thread (lambda ()
    (thread-send caller 4) (thread-yield!) (thread-send caller 5)))))
  (let (arrival '())
    (let receive ((remaining 5))
      (unless (= remaining 0)
        (set! arrival (append arrival (list (thread-receive))))
        (receive (- remaining 1))))
    (let (order (if (equal? order-text "arrival") arrival
                   (call-with-input-string order-text read)))
      (displayln "GRANT-ORDER owner=" order " arrival=" arrival)
      (force-output)
      order)))

;;; Unsafe native control: original state restored without the pending authority
;;; command. The cached view incorrectly stays admitted despite durable receipt
;;; of revocation. The correct adapter must replay before opening the reactor.
(def (missing-replay-counter! db)
  (let (journal (journal-open db))
    (retain-originals! journal db)
    (let-values (((authority-value host-value initial-provider workers-value) (query.fixture #t))
                 ((provider observed) (context-query-restore (journal-get journal "query-catalog"))))
      (context-host-restore! host-value (journal-get journal "context")
                            (lambda (registration) (.ref authority-value 'proof)) provider)
      (ensure (find (lambda (r) (and (equal? (.ref r 'id) "grant-revoke")
                                    (equal? (.ref r 'status) "pending")))
                    (journal-rows journal)) "Counter requires an actual pending revocation")
      (ensure (eq? (.ref (query.row host-value "a") 'context-state) 'admitted)
              "Missing replay did not expose a stale admitted Context")
      (displayln "GRANT-COUNTER pending-revocation=#t cached-a=admitted"))
    (journal-close! journal)))

(def (grant-durable-driver db mode order-text stage-text)
  (when (equal? mode "counter")
    (missing-replay-counter! db)
    (displayln "MODULE-OK t/context-grant-durable-test.ss")
    (displayln "HARNESS-OK context-grant-durable")
    (displayln "OK")
    (exit 0))
  (let ((journal #f) (adapter #f) (caller (current-thread)))
    (def (setup)
      (set! journal (journal-open db))
      (retain-originals! journal db)
      (let (restored? (if (journal-get journal "context") #t #f))
        (let-values (((authority-value host-value initial-provider workers-value) (query.fixture #t)))
          (unless restored?
            (query.attach host-value workers-value "a" 2 caller)
            (query.attach host-value workers-value "b" 3 caller)
            (query.attach host-value workers-value "c"))
          (set! adapter
            (context-durable-adapter journal host-value
              (.ref authority-value 'grants) (.ref authority-value 'policies)
              (lambda (registration) (.ref authority-value 'proof)) initial-provider))
          (values
           (.o authority: authority-value host: host-value workers: workers-value
               provider: (.call adapter .query-provider adapter))
           (.ref authority-value 'policies) adapter))))
    (let (clock (policy-clock-owner setup "txn" 1 3600. 0. 1 #t #f))
      (def (read! operation) (policy-clock-call! clock operation))
      (def (named! id-value operation-value body-value operation)
        (policy-clock-command! clock
          (.o kind: 'context.durable-command.v1 identity: id-value
              operation: operation-value body: body-value) operation))
      (def (revoke! intent)
        (policy-clock-command! clock intent
          (lambda (r) (.call adapter .revoke-grant! adapter intent))))
      (cond
       ((equal? mode "pre")
        (named! "complete-c" 'result "c"
          (lambda (r)
            (ensure (.ref (query.commit (.ref r 'host) (.ref r 'workers) "c") 'native-result-published?)
                    "C actual worker completion failed")))
        (let* ((intent (read! (lambda (r)
                         (context-durable-revoke-command "grant-revoke"
                           (agentic-ai-lab-context-use-host-current (resource-grants r) "grant")))))
               (order (collect-order order-text caller)))
          (let* ((original (.ref (.ref intent 'body) 'grant))
                 (identity-value (string-copy "isolated-grant"))
                 (isolated (grant-copy original identity-value 1 #t))
                 (frozen (context-durable-revoke-command "frozen-command" isolated)))
            (string-set! identity-value 0 #\X)
            (ensure (equal? (.ref (.ref (.ref frozen 'body) 'grant) 'identity) "isolated-grant")
                    "Caller mutation changed a frozen revocation command"))
          ;; A mismatched expected cut must refuse while the grant is still
          ;; enabled. This exercises CAS independently of the tombstone guard.
          (revoke! (.o (:: @ intent) identity: "wrong-cut-revoke"
            body: (.o (:: @ (.ref intent 'body)) expected: "unrelated-cut")))
          (read! (lambda (r)
            (let (current (agentic-ai-lab-context-use-host-current (resource-grants r) "grant"))
              (ensure (and (= (.ref current 'generation) 1) (.ref current 'enabled?))
                      "Mismatched expected cut revoked an active grant"))
            (ensure (not (.ref (journal-get journal "grant-revocation-decision:wrong-cut-revoke") 'accepted?))
                    "Mismatched expected cut was not durably refused")))
          (read! (lambda (r)
            (journal-cut! journal
              (lambda (stage id-value)
                (when (and (equal? id-value "grant-revoke")
                           (eq? stage (string->symbol stage-text)))
                  (unless (eq? stage 'after-receive) (check-revoked! r journal))
                  (displayln "GRANT-HELD " stage-text)
                  (force-output)
                  (read-line))))))
          (for-each
           (lambda (move)
             (case move
              ((1) (revoke! intent))
              ((2 3)
               (let (role (if (= move 2) "a" "b"))
                 (named! (string-append "result-" role) 'result role
                   (lambda (r) (query.commit (.ref r 'host) (.ref r 'workers) role)))))
              ((4) (named! "cancel-a" 'cancel "a"
                     (lambda (r) (agentic-ai-lab-ai-agentic-context-session-host-cancel!
                       (.ref r 'host) (query.sid "a") (query.revision (.ref r 'host) "a") 1))))
              ((5) (named! "recover-a" 'recover "a"
                     (lambda (r) (agentic-ai-lab-ai-agentic-context-session-host-recover!
                       (.ref r 'host) (query.sid "a") (query.revision (.ref r 'host) "a") 1))))))
           order)
          (error "Expected grant crash hook was not reached")))
       ((equal? mode "post")
        (read! (lambda (r) (check-revoked! r journal)))
        (let (original (read! (lambda (r)
                        (.ref (find (lambda (row) (equal? (.ref row 'id) "grant-revoke"))
                                    (journal-rows journal)) 'payload))))
          (ensure (.ref (revoke! original) 'historical?) "Duplicate revocation was rerun")
          (ensure (rejected? (lambda () (.call adapter .revoke-grant! adapter original)))
                  "Revocation ran outside an active owner transaction")
          (ensure (rejected? (lambda ()
            (revoke! (.o (:: @ original)
              body: (.o (:: @ (.ref original 'body)) expected: "different-cut")))))
            "Same input ID accepted another grant body")
          (revoke! (.o (:: @ original) identity: "delayed-revoke")))
        (read! (lambda (r)
          (ensure (not (.ref (journal-get journal "grant-revocation-decision:delayed-revoke") 'accepted?))
                  "Delayed grant command overwrote the retired cut")
          (let ((grants (resource-grants r))
                (retired (agentic-ai-lab-context-use-host-current (resource-grants r) "grant")))
            (ensure (rejected? (lambda ()
              (agentic-ai-lab-context-use-host-refresh! grants (grant-copy retired "grant" 3 #t))))
              "A later generation resurrected a retired grant")
            (ensure (rejected? (lambda () (agentic-ai-lab-context-use-grant-revoke retired)))
                    "Pure revocation accepted an already retired grant"))
          (check-revoked! r journal)
          (displayln "GRANT-RETRY duplicate=historical substituted=refused delayed=refused resurrection=refused")))
        (policy-clock-stop! clock))
       (else (error "Unknown grant test mode" mode))))
    (displayln "MODULE-OK t/context-grant-durable-test.ss")
    (displayln "HARNESS-OK context-grant-durable")
    (displayln "OK")))
