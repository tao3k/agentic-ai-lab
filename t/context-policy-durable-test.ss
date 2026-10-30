;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Production policy replacement through the real durable owner and native
;;; ASCENT/Query/Session fixture. Raw source evidence stays valid and retained.
(import
 (only-in :clan/poo/object .o .ref .call)
 (only-in :std/list/list every find)
 (prefix-in :agentic-ai-lab/t/context-query-provider-test query.)
 (only-in :agentic-ai-lab/t/context-query-durable-test retain-originals!)
 :agentic-ai-lab/modules/ai-agentic-context/durable-owner
 :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host
 :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy
 :agentic-ai-lab/modules/ai-agentic-context/query-provider
 :agentic-ai-lab/modules/ai-agentic-context/session-host
 :agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
 :agentic-ai-lab/modules/temporal-causality/runtime/policy-clock)
(export policy-durable-driver)

(def (ensure value message)
  (unless value (error message)))

(def (rejected? operation)
  (with-catch (lambda (e) #t) (lambda () (operation) #f)))

(def (resource-policies resource)
  (.ref (.ref resource 'authority) 'policies))

(def (replacement snapshot (revision-value "replacement-v2"))
  (let (old (.ref snapshot 'policy))
    (agentic-ai-lab-temporal-support-policy
     (.ref old 'identity) revision-value (.ref old 'start) (.ref old 'end))))

(def (check-replaced! resource journal)
  (let* ((host (.ref resource 'host))
         (policies (resource-policies resource))
         (snapshot (agentic-ai-lab-temporal-support-policy-host-registered policies "policy")))
    ;; Check pushed cached state before asking the independent support guard.
    (query.assert-push host)
    (ensure (and (= (.ref snapshot 'generation) 2)
                 (equal? (.ref (.ref snapshot 'policy) 'revision-identity) "replacement-v2"))
            "Policy was not recovered at its exact revision cut")
    (for-each
     (lambda (role)
       (let ((terminals (query.outcomes host role))
             (pending (.ref (.ref (query.row host role) 'schedule) 'obligations)))
         (ensure (<= (length terminals) 1) "Duplicate Attempt terminal")
         (ensure (every (lambda (t) (not (.ref t 'current-use?))) terminals)
                 "Old-policy or captured-parent result became current")
         (ensure (= (length pending) (if (null? terminals) 1 0))
                 "Policy recovery lost or duplicated a worker obligation")))
     '("a" "b"))
    (ensure (= (length (query.outcomes host "c")) 1) "Unaffected C completion disappeared")
    (ensure (every (lambda (t) (.ref t 'current-use?)) (query.outcomes host "c"))
            "Unrelated C lost authority")
    (let (root (context-query-export (.ref resource 'provider)))
      (ensure (= (length (.ref root 'history)) 2) "Policy replacement changed source history")
      (ensure (= (length (.ref root 'queries)) 3) "Original Query observations were lost")
      (ensure (every (lambda (q) (context-query-current? (.ref resource 'provider) q))
                     (.ref root 'queries))
              "Authority policy replacement incorrectly retracted source evidence"))
    (displayln "POLICY-STATE affected-a-b=invalidated unaffected-c=current evidence=supported obligations=exact")
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
      (displayln "POLICY-ORDER owner=" order " arrival=" arrival)
      (force-output)
      order)))

;;; Unsafe native control: original state restored without the pending authority
;;; command. The cached view incorrectly stays admitted despite durable receipt
;;; of policy replacement. The correct adapter must replay before opening the reactor.
(def (missing-replay-counter! db)
  (let (journal (journal-open db))
    (retain-originals! journal db)
    (let-values (((authority-value host-value initial-provider workers-value) (query.fixture #t))
                 ((provider observed) (context-query-restore (journal-get journal "query-catalog"))))
      (context-host-restore! host-value (journal-get journal "context")
                            (lambda (registration) (.ref authority-value 'proof)) provider)
      (ensure (find (lambda (r) (and (equal? (.ref r 'id) "policy-replace")
                                    (equal? (.ref r 'status) "pending")))
                    (journal-rows journal)) "Counter requires an actual pending policy replacement")
      (ensure (eq? (.ref (query.row host-value "a") 'context-state) 'admitted)
              "Missing replay did not expose a stale admitted Context")
      (displayln "POLICY-COUNTER pending-replacement=#t cached-a=admitted"))
    (journal-close! journal)))

(def (policy-durable-driver db mode order-text stage-text (profile "canonical"))
  (when (equal? mode "counter")
    (missing-replay-counter! db)
    (displayln "MODULE-OK t/context-policy-durable-test.ss")
    (displayln "HARNESS-OK context-policy-durable")
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
    (def (check-policy! r)
      (if (equal? profile "legacy-missing")
        (begin
          (ensure (= (.ref (agentic-ai-lab-temporal-support-policy-host-registered
                            (resource-policies r) "policy") 'generation) 1)
                  "Legacy missing-cut input changed current policy")
          (ensure (eq? (.ref (query.row (.ref r 'host) "a") 'context-state) 'admitted)
                  "Missing-cut refusal damaged admitted Context"))
        (check-replaced! r journal)))
    (let (clock (policy-clock-owner setup "txn" 1 3600. 0. 1 #t #f))
      (def (read! operation) (policy-clock-call! clock operation))
      (def (named! id-value operation-value body-value operation)
        (policy-clock-command! clock
          (.o kind: 'context.durable-command.v1 identity: id-value
              operation: operation-value body: body-value) operation))
      (def (replace! intent)
        (policy-clock-command! clock intent
          (lambda (r) (.call adapter .replace-policy! adapter intent))))
      (cond
       ((equal? mode "pre")
        (named! "complete-c" 'result "c"
          (lambda (r)
            (ensure (.ref (query.commit (.ref r 'host) (.ref r 'workers) "c") 'native-result-published?)
                    "C actual worker completion failed")))
        (let* ((intent (read! (lambda (r)
                         (let (snapshot (agentic-ai-lab-temporal-support-policy-host-registered
                                         (resource-policies r) "policy"))
                           (let (canonical (context-durable-policy-command "policy-replace" snapshot (replacement snapshot)))
                             (cond ((equal? profile "canonical") canonical)
                                   ((equal? profile "legacy-cut") (.o (:: @ canonical) operation: 'policy-replacement))
                                   ((equal? profile "legacy-missing")
                                    (.o kind: 'context.durable-command.v1 identity: "policy-replace"
                                        operation: 'policy-replacement
                                        body: (.o policy: (replacement snapshot) generation: 3)))
                                   (else (error "Unknown migration profile" profile))))))))
               (order (collect-order order-text caller)))
          ;; The command freezes the POO proposal before handing it to the owner.
          (let* ((label (string-copy "frozen-revision"))
                 (snapshot (read! (lambda (r)
                             (agentic-ai-lab-temporal-support-policy-host-registered
                              (resource-policies r) "policy"))))
                 (proposal (replacement snapshot label))
                 (frozen (context-durable-policy-command "frozen-command" snapshot proposal)))
            (string-set! label 0 #\X)
            (ensure (equal? (.ref (.ref (.ref frozen 'body) 'policy) 'revision-identity) "frozen-revision")
                    "Caller mutation changed a frozen policy command"))
          ;; Test generation and digest independently, while the original
          ;; revision is still registered. A deadline generation also fences CAS.
          (replace! (.o (:: @ intent) identity: "wrong-generation"
            body: (.o (:: @ (.ref intent 'body)) expected-generation: 0)))
          (replace! (.o (:: @ intent) identity: "wrong-digest"
            body: (.o (:: @ (.ref intent 'body)) expected-digest: "unrelated-cut")))
          (read! (lambda (r)
            (ensure (= (.ref (agentic-ai-lab-temporal-support-policy-host-registered
                              (resource-policies r) "policy") 'generation) 1)
                    "Mismatched expected policy cut changed registration")
            (for-each (lambda (id)
              (ensure (not (.ref (journal-get journal
                                  (string-append "policy-transition-decision:" id)) 'accepted?))
                      "Mismatched policy cut was not durably refused"))
              '("wrong-generation" "wrong-digest"))))
          (read! (lambda (r)
            (journal-cut! journal
              (lambda (stage id-value)
                (when (and (equal? id-value "policy-replace")
                           (eq? stage (string->symbol stage-text)))
                  (unless (eq? stage 'after-receive) (check-policy! r))
                  (displayln "POLICY-HELD " stage-text)
                  (force-output)
                  (read-line))))))
          (for-each
           (lambda (move)
             (case move
              ((1) (replace! intent))
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
          (error "Expected policy crash hook was not reached")))
       ((equal? mode "post")
        (read! (lambda (r) (check-policy! r)))
        (let (original (read! (lambda (r)
                        (.ref (find (lambda (row) (equal? (.ref row 'id) "policy-replace"))
                                    (journal-rows journal)) 'payload))))
          (ensure (.ref (replace! original) 'historical?) "Duplicate policy replacement was rerun")
          (ensure (rejected? (lambda () (.call adapter .replace-policy! adapter original)))
                  "Policy replacement ran outside an active owner transaction")
          (ensure (rejected? (lambda ()
            (replace! (.o (:: @ original)
              body: (.o (:: @ (.ref original 'body)) expected-digest: "different-cut")))))
            "Same input ID accepted another policy body")
          (replace! (.o (:: @ original) identity: "delayed-replace")))
        (read! (lambda (r)
          (ensure (not (.ref (journal-get journal "policy-transition-decision:delayed-replace") 'accepted?))
                  "Delayed policy command overwrote the current cut")
          ;; A saved old deadline names generation 1. It cannot expire generation
          ;; 2 even when delivered with an otherwise valid observed end instant.
          (let* ((policies (resource-policies r))
                 (snapshot (agentic-ai-lab-temporal-support-policy-host-registered policies "policy")))
            (unless (equal? profile "legacy-missing")
             (ensure (rejected? (lambda ()
              (agentic-ai-lab-temporal-support-policy-host-fire-deadline!
               policies "policy" 1 (.ref (.ref snapshot 'policy) 'end))))
              "Old expiry ticket damaged the replacement policy")))
          (check-policy! r)
          (displayln "POLICY-RETRY duplicate=historical substituted=refused delayed=refused old-ticket="
                     (if (equal? profile "legacy-missing") "not-applicable" "refused"))))
        (read! (lambda (r)
          (let (decision (journal-get journal "policy-transition-decision:policy-replace"))
            (ensure (eq? (.ref decision 'accepted?) (not (equal? profile "legacy-missing")))
                    "Recovered legacy command has the wrong decision")
            (displayln "POLICY-MIGRATION profile=" profile " accepted=" (.ref decision 'accepted?)
                       " reason=" (.ref decision 'reason)))))
        (policy-clock-stop! clock))
       (else (error "Unknown policy test mode" mode))))
    (displayln "MODULE-OK t/context-policy-durable-test.ss")
    (displayln "HARNESS-OK context-policy-durable")
    (displayln "OK")))
