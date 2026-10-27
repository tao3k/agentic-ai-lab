;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Bounded compiler unit; register the unchanged native Cases in order.
(import (only-in :agentic-ai-lab/modules/workflow/runtime/scheme-wire scheme-wire-read scheme-wire-write)
        (only-in :agentic-ai-lab/modules/ai-agentic-context/objects AiAgenticContextScope.)
        (only-in :agentic-ai-lab/modules/ai-agentic-context/funs-features agentic-ai-lab-ai-agentic-context-profile)
        :agentic-ai-lab/modules/ai-agentic-context/session-host
        :agentic-ai-lab/modules/ai-agentic-context/use-host
        :agentic-ai-lab/modules/session/funs-attempt
        :agentic-ai-lab/modules/query/semantic/context-restriction
        :agentic-ai-lab/modules/temporal-causality/runtime/policy-clock
        :std/test (only-in :clan/poo/object .o .ref object?)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case yuanxu-test-case/with yuanxu-selected-testing-case-profile)
        (only-in :yuanxu/ops/progress execution-progress!)
        (only-in :gerbil-ascent/candidate/checked-program
                 reasoning-source-snapshot reasoning-attempt reasoning-receipt-status reasoning-receipt-proof
                 reasoning-receipt-rows reasoning-receipt-bound?)
        (only-in :gerbil-ascent/candidate/provenance positive-proof-status positive-proof-nodes positive-proof-roots proof-node-id proof-node-kind proof-node-row proof-node-relation proof-node-inputs)
        :agentic-ai-lab/modules/temporal-causality/evaluator/interface
        :agentic-ai-lab/modules/temporal-causality/time/objects
        :agentic-ai-lab/modules/temporal-causality/revisions/interface
        :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/interface
        :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host)
(import "./fixtures.ss")
(export register-evaluator-cases-4!)

(def (register-evaluator-cases-4!)

    (yuanxu-test-case "real background clock invalidates without consumer queries and deduplicates native events"
      (let (clock (clock-fixture #f 0. 2))
        (dynamic-wind void
          (lambda ()
            (check (>= (policy-clock-await-events! clock 2) 2) => #t)
            (policy-clock-call! clock (lambda (f)
              (push-check-cached! f)
              (clock-check-originals! f)
              (clock-cleanup! f)))
            (let (audit (policy-clock-audit clock))
              (check (clock-phases audit 'applied) => 1)
              (check (clock-phases audit 'duplicate) => 1)
              (check (every (lambda (r) (eq? (.ref r 'cause) 'timer)) audit) => #t)
              (clock-print-audit "autonomous" audit))
            (displayln "NATIVE-CLOCK-OBSERVE autonomous no-context-query-before-push=#t applied=1 duplicate=1 unaffected=completed originals-retained=#t"))
          (lambda () (policy-clock-stop! clock)))))
    (yuanxu-test-case "native result before real deadline retains one historical terminal after autonomous expiry"
      (let (clock (clock-fixture #f 0. 2 #t 1.))
        (dynamic-wind void
          (lambda ()
            (policy-clock-call! clock (lambda (f)
              (check (.ref (agentic-ai-lab-ai-agentic-context-session-host-commit-result! (.ref f 'host)
                "session" 2 0 (push-join! f "session")) 'native-result-published?) => #t)
              (check (.ref (car (agentic-ai-lab-ai-agentic-context-session-host-outcomes (.ref f 'host) "session")) 'current-use?) => #t)))
            (policy-clock-await-events! clock 2)
            (policy-clock-call! clock (lambda (f)
              (push-check-cached! f)
              (let ((host (.ref f 'host)))
                (check (.ref (car (agentic-ai-lab-ai-agentic-context-session-host-outcomes host "session")) 'outcome) => 'completed)
                (check (.ref (car (agentic-ai-lab-ai-agentic-context-session-host-outcomes host "session")) 'current-use?) => #f)
                (check (.ref (agentic-ai-lab-ai-agentic-context-session-host-commit-result! host "session" 2 0
                  (push-join! f "session")) 'accepted?) => #f)
                (agentic-ai-lab-ai-agentic-context-session-host-recover! host "session" (push-revision f "session") 0)
                (check (length (agentic-ai-lab-ai-agentic-context-session-host-outcomes host "session")) => 1))
              (clock-check-originals! f) (clock-cleanup! f)))
            (clock-print-audit "completed-before" (policy-clock-audit clock))
            (displayln "NATIVE-CLOCK-OBSERVE completion-before-deadline published=#t historical-terminal=completed current-after-expiry=#f duplicate-terminal=#f"))
          (lambda () (policy-clock-stop! clock)))))
    (yuanxu-test-case "delayed native clock delivery cannot beat actual deadline result guard"
      (let (clock (clock-fixture #t 0. 2))
        (dynamic-wind void
          (lambda ()
            (policy-clock-await-events! clock 2)
            (policy-clock-call! clock (lambda (f)
              (check (.ref (push-row f "session") 'context-state) => 'admitted)
              (let (observation (push-join! f "session"))
                (check (.ref (agentic-ai-lab-ai-agentic-context-session-host-commit-result! (.ref f 'host)
                  "session" (push-revision f "session") 0 observation) 'accepted?) => #f))
              (push-check-cached! f)))
            (policy-clock-resume! clock)
            (let (audit (policy-clock-audit clock))
              (check (clock-phases audit 'stale) => 1)
              (check (clock-phases audit 'duplicate) => 1)
              (clock-print-audit "delayed-guard" audit))
            (policy-clock-call! clock clock-cleanup!)
            (displayln "NATIVE-CLOCK-OBSERVE delayed guard-expires-before-result=#t queued-old-stale=#t duplicate-idempotent=#t"))
          (lambda () (policy-clock-stop! clock)))))
    (yuanxu-test-case "missing background activation preserves native no-query counterexample"
      (let (clock (clock-fixture #f 0. 1 #f))
        (dynamic-wind void
          (lambda ()
            (thread-sleep! 0.03)
            (policy-clock-call! clock (lambda (f)
              (check (.ref (push-row f "session") 'context-state) => 'admitted)
              (check (object? (.ref (.ref (push-row f "session-b") 'schedule) 'active)) => #t)))
            (check (policy-clock-audit clock) => '())
            (policy-clock-call! clock (lambda (f)
              (let (observation (push-join! f "session"))
                (check (.ref (agentic-ai-lab-ai-agentic-context-session-host-commit-result! (.ref f 'host)
                  "session" 2 0 observation) 'accepted?) => #f))
              (clock-cleanup! f)))
            (displayln "NATIVE-CLOCK-COUNTEREXAMPLE no-timer cached-admitted=#t active-after-deadline=#t final-clock-guard-denies=#t"))
          (lambda () (policy-clock-stop! clock)))))
    (yuanxu-test-case/with
      (let (base (yuanxu-selected-testing-case-profile))
        (.o (:: @ base) max-duration-milliseconds: 840000))
      "native delayed duplicate tickets policy replacement results cancellation recovery races"
      (let* ((all (clock-orders '() '(1 2 3 4 5)))
             (replay (getenv "AGENTIC_CONTEXT_CLOCK_ORDER" #f))
             (orders (if replay (list (call-with-input-string replay read)) all)) (count 0))
        (check (length all) => 60)
        (for-each (lambda (order)
          (unless (member order all) (error "Illegal native clock order" order))
          (displayln "NATIVE-CLOCK-BEGIN order=" order) (force-output)
          (clock-replay order)
          (set! count (+ count 1)) (execution-progress! '(native-clock-paths-verified) count)) orders)
        (check count => (if replay 1 60))
        (displayln "NATIVE-CLOCK-OBSERVE races paths=" count " duplicate-terminals=0 old-ticket-new-policy-damage=0 stale-reactivations=0 unaffected-failures=0")))
    (yuanxu-test-case/with
      (let (base (yuanxu-selected-testing-case-profile))
        (.o (:: @ base) max-duration-milliseconds:
          (if (getenv "AGENTIC_CONTEXT_PUSH_EXHAUSTIVE" #f) 840000 (.ref base 'max-duration-milliseconds))))
      "push native source propagation result cancellation recovery interleavings"
      (let* ((all (push-orders '() '(1 2 3 4 5 6 7)))
             (replay (getenv "AGENTIC_CONTEXT_PUSH_ORDER" #f))
             (full? (getenv "AGENTIC_CONTEXT_PUSH_EXHAUSTIVE" #f))
             (orders (cond (replay (list (call-with-input-string replay read))) (full? all)
                       (else (map (lambda (n) (list-ref all n)) '(0 40 80 120 160 200 240 279)))))
             (expected (cond (replay 1) (full? 280) (else 8))) (count 0))
        (check (length all) => 280)
        (for-each (lambda (order)
          (unless (member order all) (error "illegal push replay path" order))
          (displayln "NATIVE-PUSH-BEGIN order=" order) (force-output)
          (push-replay order)
          (set! count (+ count 1)) (execution-progress! '(native-push-paths-verified) count)) orders)
        (check count => expected)
        (displayln "NATIVE-PUSH-OBSERVE interleavings paths=" count " duplicate-terminals=0 stale-reactivations=0 unaffected-failures=0")))
    (yuanxu-test-case/with
      (let (base (yuanxu-selected-testing-case-profile))
        (.o (:: @ base) max-duration-milliseconds:
          (if (getenv "AGENTIC_CONTEXT_NATIVE_CAS_EXHAUSTIVE" #f) 840000 (.ref base 'max-duration-milliseconds))))
      "all bounded native owner interleavings preserve terminal and evidence fences"
      (let* ((ctx (mrr-derivation-fixture)) (admitted-context (selected-context ctx))
             (all-orders (native-cas-orders '() '(1 2 3 4 5 6 7 8)))
             (replay (getenv "AGENTIC_CONTEXT_NATIVE_CAS_ORDER" #f))
             (exhaustive? (getenv "AGENTIC_CONTEXT_NATIVE_CAS_EXHAUSTIVE" #f))
             (orders (cond (replay (list (call-with-input-string replay read)))
                           (exhaustive? all-orders)
                           (else '((1 2 3 4 5 6 7 8) (1 2 4 3 5 6 7 8)
                                   (6 7 8 1 2 3 4 5) (6 8 1 2 3 4 5 7)
                                   (4 1 2 3 5 6 7 8) (5 1 2 3 4 6 7 8)
                                   (1 2 6 3 7 4 5 8) (1 6 8 2 4 3 7 5)))))
             (expected-count (cond (replay 1) (exhaustive? 2240) (else 8))) (count 0))
        (check (length all-orders) => 2240)
        (for-each (lambda (order) (unless (member order all-orders) (error "illegal native replay order" order))) orders)
        (for-each (lambda (order)
          (with-catch (lambda (exception)
            (let* ((fresh (reasoning-attempt (list-ref ctx 4) proposal 512))
                   (fresh-proof (reasoning-receipt-proof fresh)))
              (displayln "NATIVE-CAS-FAILED index=" count " order=" order
                " receipt=" (reasoning-receipt-status fresh)
                " proof=" (and fresh-proof (positive-proof-status fresh-proof)))
              (force-output))
            (raise exception))
            (lambda () (native-cas-replay order ctx admitted-context)))
          (set! count (+ count 1))
          (execution-progress! '(native-owner-paths-verified) count)
          (when (= (modulo count 128) 0)
            (displayln "NATIVE-CAS-PROGRESS completed=" count) (force-output))) orders)
        (displayln "NATIVE-CAS-OBSERVE interleavings paths=" count " terminal-violations=0 stale-reactivations=0")
        (check count => expected-count)))
    (yuanxu-test-case "Context binds original proof into input and fences prepared claims"
      (let-values (((context-host proof-host policy-host registration p ctx) (context-proof-setup)))
        (check (.ref (context-claim context-host 0 0) 'reason) => 'temporal-proof-denied)
        (let* ((before (agentic-ai-lab-ai-agentic-context-session-host-current context-host "session"))
               (bound (context-bind context-host proof-host registration p 0 0 1 1)))
          (check (.ref bound 'reason) => 'proof-bound)
          (check (equal? (.ref (.ref (.ref before 'task) 'input) 'digest)
                         (.ref (.ref (.ref bound 'task) 'input) 'digest)) => #f)
          (check (.ref (context-claim context-host 0 0) 'reason) => 'stale-revision)
          (let (claim (context-claim context-host 1 0))
            (check (.ref claim 'accepted?) => #t)
            (check (.ref claim 'provider-disclosed?) => #f)
            (check (.ref claim 'action-authorized?) => #f)))))
)
