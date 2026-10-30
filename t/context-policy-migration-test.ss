;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; All causal five-event owner schedules, plus independently scheduled producers.
;;; Runtime effects use production Scheme; this file supplies no alternate CAS.
(import (only-in :clan/poo/object .o .ref .call)
        (only-in :std/list/list find every)
        (prefix-in :agentic-ai-lab/t/context-durable-owner old.)
        (only-in :agentic-ai-lab/t/qualification/context-temporal/evaluator/fixtures
                 authority-fixture clock-original-context push-row push-revision
                 push-join! context-source at policy
                 clock-check-originals!)
        :agentic-ai-lab/modules/ai-agentic-context/durable-owner
        :agentic-ai-lab/modules/ai-agentic-context/session-host
        :agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
        :agentic-ai-lab/modules/temporal-causality/runtime/policy-clock
        :agentic-ai-lab/modules/temporal-causality/runtime/monotonic-clock
        :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host
        :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy)
(export migration-driver migration-case)

(def (ensure value message) (unless value (error message)))
(def (rejected? fun) (with-catch (lambda (e) #t) (lambda () (fun) #f)))

;;; This enumerator is independent of the Python/SysML corpus generator. Cancel
;;; precedes recovery; every other ordering is explored, including expiry last.
(def (orders prefix remaining)
  (if (null? remaining) (list (reverse prefix))
    (apply append
      (map (lambda (move)
             (if (or (not (= move 5)) (member 4 prefix))
               (orders (cons move prefix) (filter (lambda (x) (not (= x move))) remaining))
               '())) remaining))))

(def (policy-head f)
  (agentic-ai-lab-temporal-support-policy-host-registered (.ref f 'policies) "policy"))

(def (proposal)
  (agentic-ai-lab-temporal-support-policy "policy" "clock-new" (at 1) (at 1000000)))

(def (intent-for f profile)
  (let (canonical (context-durable-policy-command "replace" (policy-head f) (proposal)))
    (cond ((equal? profile "canonical") canonical)
          ((equal? profile "legacy-cut") (.o (:: @ canonical) operation: 'policy-replacement))
          ((equal? profile "legacy-missing")
           (.o kind: 'context.durable-command.v1 identity: "replace" operation: 'policy-replacement
               body: (.o policy: (proposal) generation: 3)))
          (else (error "Unknown migration profile" profile)))))

(def (cached-check! f)
  ;; Inspect pushed snapshots before any support/current-use evaluation.
  (ensure (eq? (.ref (push-row f "session") 'context-state) 'invalidated) "A was not proactively invalidated")
  (ensure (eq? (.ref (push-row f "session-b") 'context-state) 'invalidated) "Captured-parent B remained admitted")
  (ensure (eq? (.ref (push-row f "session-c") 'context-state) 'admitted) "Independent C was invalidated")
  (for-each (lambda (sid)
    (let (outcomes (agentic-ai-lab-ai-agentic-context-session-host-outcomes (.ref f 'host) sid))
      (ensure (<= (length outcomes) 1) "Attempt acquired two terminals")
      (ensure (every (lambda (o) (not (.ref o 'current-use?))) outcomes) "Old result became current")))
    '("session" "session-b")))

(def (migration-case db profile requested live? (leaky-close? #f))
  (let ((journal #f) (adapter #f) (intent #f) (trace '()) (expiry-seen? #f)
        (callback-ran? #f) (caller (current-thread)) (held-context #f) (leaked-subscriptions #f))
    (def profile? (getenv "CONTEXT_RESOURCE_PROFILE" #f))
    (def profile-time (if profile? (native-monotonic-seconds) 0.))
    (def (phase! label)
      (when profile?
        (let (now (native-monotonic-seconds))
          (displayln "RESOURCE-PHASE phase=" label " seconds=" (- now profile-time))
          (force-output) (set! profile-time now))))
    (def (mark! move)
      (set! trace (append trace (list move))))
    (let (clock (policy-clock-owner
      (lambda ()
        (set! journal (journal-open db)) (phase! 'journal-open)
        (old.originals! journal db) (phase! 'originals)
        (let* ((ctx (begin0 (clock-original-context) (phase! 'source-fixture)))
               (f (begin0 (authority-fixture #t ctx 1000000) (phase! 'context-fixture))))
          (journal-evidence! journal "original-ascent" (old.proof-evidence ctx))
          (journal-evidence! journal "original-org" context-source)
          (set! held-context (.ref f 'host))
          (set! intent (intent-for f profile))
          (set! adapter (context-durable-adapter journal (.ref f 'host) (.ref f 'grants)
                           (.ref f 'policies) (lambda (registration) (.ref f 'proof))))
          (when leaky-close?
            ;; Isolated negative control: model the former omitted adapter
            ;; teardown. Its declared receipt lies; actual native handles below
            ;; expose the leak even if a caller retains all retired objects.
            (let (original-adapter adapter)
             (set! adapter (.o (:: @ original-adapter)
              .close!: (lambda (self)
                (set! leaked-subscriptions (context-host-subscription-count held-context))
                (.o kind: 'context.durable-close.v1 journal-closed?: #t
                    context-disposed?: #t subscriptions: 0))))))
          (phase! 'adapter-and-evidence)
          (journal-cut! journal
            (lambda (stage id)
              (when (eq? stage 'before-commit)
                (cond ((equal? id "replace") (mark! 2))
                      ((equal? id "old-result") (mark! 3))
                      ((equal? id "cancel") (mark! 4))
                      ((equal? id "recover") (mark! 5))
                      ((and (not expiry-seen?) (and (>= (string-length id) 9) (equal? (substring id 0 9) "delivery:")))
                       (let* ((row (journal-input journal id))
                              (ticket (.ref (.ref row 'payload) 'ticket)))
                         ;; Receipt while paused is not publication. Record the
                         ;; first actual processed timer ticket, including stale.
                         (when (journal-get journal (string-append "seen:" (.ref ticket 'identity)))
                           (set! expiry-seen? #t) (mark! 1))))))))
          (values f (.ref f 'policies) adapter)))
      "txn" 1 (if live? 0.01 0.002) 0.004 2 (not live?) #t))
      (def (read! fun) (policy-clock-call! clock fun))
      (def (command! id kind fun)
        (policy-clock-command! clock
          (.o kind: 'context.durable-command.v1 identity: id operation: kind body: id) fun))
      (def (step! move)
        (case move
          ((1) (policy-clock-resume! clock))
          ((2)
           ;; Deliberately supply a forbidden legacy compute hook. Production
           ;; dispatch must ignore it even for a legacy operation name.
           (policy-clock-command! clock intent
             (lambda (f)
               (set! callback-ran? #t)
               (agentic-ai-lab-temporal-support-policy-host-refresh! (.ref f 'policies) (proposal) 99 (at 1)))))
          ((3) (command! "old-result" 'result
                 (lambda (f)
                   (agentic-ai-lab-ai-agentic-context-session-host-commit-result! (.ref f 'host)
                     "session" (push-revision f "session") 0 (push-join! f "session")))))
          ((4) (command! "cancel" 'cancel
                 (lambda (f) (agentic-ai-lab-ai-agentic-context-session-host-cancel!
                   (.ref f 'host) "session" (push-revision f "session") 0))))
          ((5) (command! "recover" 'recover
                 (lambda (f) (agentic-ai-lab-ai-agentic-context-session-host-recover!
                   (.ref f 'host) "session" (push-revision f "session") 0))))))
      (command! "complete-c" 'result
        (lambda (f)
          (ensure (.ref (agentic-ai-lab-ai-agentic-context-session-host-commit-result!
                          (.ref f 'host) "session-c" 2 0 (push-join! f "session-c"))
                        'native-result-published?) "C actual completion failed")))
      (phase! 'bootstrap-and-c-completion)
      (if live?
        (let* ((spawn (lambda (moves delay)
                        (thread-start! (make-thread (lambda ()
                          (thread-receive)
                          (thread-sleep! delay)
                          (for-each step! moves)
                          (thread-send caller 'producer-done))))))
               (a (spawn '(2) (* requested 0.008)))
               (b (spawn '(3) (* (- 3 requested) 0.008)))
               (c (spawn '(4 5) 0.004)))
          (for-each (lambda (thread) (thread-send thread 'go)) (list a b c))
          (for-each (lambda (thread)
            (ensure (eq? (thread-receive 5 'producer-timeout) 'producer-done) "Independent producer did not finish")
            (thread-join! thread)) (list a b c))
          (policy-clock-await-events! clock 2))
        (begin
          ;; Real background time elapses and two copies are durably received.
          ;; The model explores publication ordering, never a synthetic expiry.
          (policy-clock-await-events! clock 2)
          (for-each (lambda (move) (step! move) (phase! move)) requested)))
      (ensure (not callback-ran?) "Legacy callback bypassed native CAS dispatch")
      (read! (lambda (f)
        (cached-check! f)
        (ensure (journal-verify! journal) "Journal chain verification failed")
        (let* ((decision (journal-get journal "policy-transition-decision:replace"))
               (cut? (not (equal? profile "legacy-missing")))
               (accepted (and cut? (= (.ref decision 'previous-generation) 1)))
               (snapshot (policy-head f)))
          (ensure (eq? (.ref decision 'accepted?) accepted) "Policy decision violated original-cut CAS")
          (ensure (equal? (.ref (.ref snapshot 'policy) 'revision-identity)
                          (if accepted "clock-new" "v1")) "Delayed input changed the selected revision")
          (ensure (= (.ref snapshot 'generation) 2) "Policy advanced more than once")
          (ensure (every (lambda (o) (.ref o 'current-use?))
                         (agentic-ai-lab-ai-agentic-context-session-host-outcomes (.ref f 'host) "session-c"))
                  "Independent completed result lost current use")
          (clock-check-originals! f)
          (displayln "MIGRATION-PATH profile=" profile " requested=" requested " actual=" trace
            " accepted=" accepted " generation=" (.ref snapshot 'generation) " callback=#f")
          ;; Finish actual endpoints without fabricating a terminal on recovery.
          (push-join! f "session-b"))))
      (phase! 'final-checks)
      (let (audit (policy-clock-audit clock))
        (ensure (= (length (filter (lambda (x) (eq? (.ref x 'phase) 'received)) audit)) 2) "Missing real duplicate timer events")
        (ensure (= (length (filter (lambda (x) (eq? (.ref x 'phase) 'duplicate)) audit)) 1) "Duplicate timer was reapplied")
        (ensure (= (length trace) 5) "Actual effect trace is incomplete")
        (for-each (lambda (row)
          (displayln "MIGRATION-TIMER phase=" (.ref row 'phase) " ticket=" (.ref row 'ticket)
                     " deadline=" (.ref row 'deadline-monotonic) " sample=" (.ref row 'sample-monotonic))) audit))
      (policy-clock-stop! clock) (phase! 'stop)
      (if leaky-close?
        (begin
          (ensure (not (journal-closed? journal)) "Omitted-close counter did not retain its actual journal")
          (ensure (> leaked-subscriptions 0) "Omitted-close counter lost its actual subscribers")
          (displayln "OWNER-COUNTER journal-open=#t retained-subscriptions=" leaked-subscriptions))
        (let (receipt (policy-clock-stop-receipt clock))
          (ensure (and (.ref receipt 'owner-joined?) (.ref receipt 'timer-joined?)
                       (.ref receipt 'clock-released?) (.ref receipt 'journal-closed?)
                       (journal-closed? journal) (context-host-disposed? held-context)
                       (= (context-host-subscription-count held-context) 0))
                  "Owner left native runtime resources open")
          (ensure (policy-clock-stop! clock) "Owner stop was not idempotent")
          (ensure (rejected? (lambda () (journal-input journal "replace"))) "Closed journal accepted a read")
          (ensure (rejected? (lambda () (context-host-checkpoint held-context))) "Disposed Context accepted reuse")
          (ensure (rejected? (lambda () (policy-clock-call! clock (lambda (r) #t)))) "Closed owner accepted RPC")
          (displayln "OWNER-CLOSE owner=#t timer=#t clock=#t journal=#t subscriptions=0"))))))

(def (non-durable-probe!)
  (let* ((callback-ran? #f)
         (clock (policy-clock-owner
                 (lambda () (values (.o kind: 'unbound-fixture)
                                    (agentic-ai-lab-temporal-support-policy-host)))
                 "txn" 1 1.)))
    (for-each (lambda (operation-value)
      (ensure (rejected? (lambda ()
        (policy-clock-command! clock
          (.o kind: 'context.durable-command.v1 identity: "unfenced-policy" operation: operation-value body: #f)
          (lambda (resource) (set! callback-ran? #t)))))
        "Named policy command bypassed durable ownership"))
      '(policy-transition policy-replacement))
    (ensure (not callback-ran?) "Non-durable legacy callback ran")
    (policy-clock-stop! clock)
    (displayln "MIGRATION-NON-DURABLE canonical=refused legacy=refused callback=#f")))

;;; Fixed-size process cohorts retain the same heap/watchdog limits. This
;;; partitions the complete 60-order corpus; it does not sample critical paths.
(def (controlled-chunk text)
  (let* ((index (string->number (substring text 6 (string-length text))))
         (all (orders '() '(1 2 3 4 5))))
    (unless (and (exact-integer? index) (<= 0 index 2)) (error "Invalid native chunk" text))
    (let loop ((rest (list-tail all (* index 20))) (left 20) (selected '()))
      (if (= left 0) (reverse selected)
          (loop (cdr rest) (- left 1) (cons (car rest) selected))))))

(def (migration-driver folder profile order-text)
  (non-durable-probe!)
  (let (selected (cond ((equal? order-text "all") (orders '() '(1 2 3 4 5)))
                      ((equal? order-text "live") '(0 1 2 3))
                      ((equal? order-text "counter") '((1 2 3 4 5)))
                      ((and (>= (string-length order-text) 6)
                            (equal? (substring order-text 0 6) "chunk:")) (controlled-chunk order-text))
                      (else (list (call-with-input-string order-text read)))))
    (let loop ((remaining selected) (index 0))
      (unless (null? remaining)
        (migration-case (string-append folder "/case-" (number->string index) ".sqlite")
                        profile (car remaining) (equal? order-text "live") (equal? order-text "counter"))
        (loop (cdr remaining) (+ index 1))))
    (displayln "MIGRATION-CORPUS paths=" (length selected) " profile=" profile " mode=" order-text))
  (displayln "MODULE-OK t/context-policy-migration-test.ss")
  (displayln "HARNESS-OK context-policy-migration")
  (displayln "OK"))
