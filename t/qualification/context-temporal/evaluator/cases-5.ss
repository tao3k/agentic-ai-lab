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
(export register-evaluator-cases-5!)

(def (register-evaluator-cases-5!)

    (yuanxu-test-case "Temporal correction invalidates active Context while preserving one obligation"
      (let-values (((context-host proof-host policy-host registration p ctx) (context-proof-setup)))
        (context-bind context-host proof-host registration p 0 0 1 1)
        (context-claim context-host 1 0)
        (agentic-ai-lab-temporal-proof-host-refresh! proof-host "source" 2 (car ctx) (corrected-journal (list-ref ctx 9)))
        (agentic-ai-lab-temporal-support-policy-host-refresh! policy-host p 2 (at 2))
        (let* ((r (agentic-ai-lab-ai-agentic-context-session-host-revalidate! context-host "session" 2 0))
               (schedule (.ref r 'schedule)))
          (check (.ref r 'reason) => 'temporal-proof-denied)
          (check (.ref r 'runtime-published?) => #t)
          (check (.ref schedule 'active) => #f)
          (check (.ref schedule 'generation) => 3)
          (check (length (.ref schedule 'obligations)) => 1)
          (check (.ref (car (.ref schedule 'obligations)) 'identity) => "attempt")
          (let (again (agentic-ai-lab-ai-agentic-context-session-host-revalidate! context-host "session" 3 0))
            (check (.ref again 'runtime-published?) => #f)
            (check (length (.ref (.ref again 'schedule) 'obligations)) => 1)))))
    (yuanxu-test-case "Context source refresh cannot reuse a Temporal requirement at another source generation"
      (let-values (((context-host proof-host policy-host registration p ctx) (context-proof-setup)))
        (context-bind context-host proof-host registration p 0 0 1 1)
        (agentic-ai-lab-ai-agentic-context-session-host-refresh! context-host "session" 0 1 context-source
          (.o (:: @ context-scope) source-cut: "cut:1"))
        (check (.ref (context-claim context-host 1 1) 'reason) => 'temporal-proof-denied)
        (context-bind context-host proof-host registration p 1 1 1 1)
        (check (.ref (context-claim context-host 2 1) 'accepted?) => #t)))
    (yuanxu-test-case "Context refuses unknown proof budget exhaustion policy drift and stale catalog"
      (let-values (((context-host proof-host policy-host registration p ctx) (context-proof-setup)))
        (check-rejected (agentic-ai-lab-ai-agentic-context-session-host-require-proof! context-host "session" 0 0
          proof-host "unknown" 1 1 (.ref p 'semantic-digest) 128))
        (check-rejected (agentic-ai-lab-ai-agentic-context-session-host-require-proof! context-host "session" 0 0
          proof-host (.ref registration 'identity) 1 1 (.ref p 'semantic-digest) 0))
        (check (.ref (.ref (agentic-ai-lab-ai-agentic-context-session-host-current context-host "session") 'schedule) 'revision) => 0)
        (context-bind context-host proof-host registration p 0 0 1 1)
        (agentic-ai-lab-temporal-support-policy-host-refresh! policy-host p 2 (at 2))
        (check (.ref (context-claim context-host 1 0) 'reason) => 'temporal-proof-denied)
        (let* ((program-value (car ctx))
               (changed (agentic-ai-lab-temporal-rule-program (.ref program-value 'identity) "replaced"
                 (.ref program-value 'generation) (.ref program-value 'ascent-generation)
                 (.ref program-value 'relations) (.ref program-value 'rules))))
          (agentic-ai-lab-temporal-proof-host-refresh! proof-host "source" 2 changed (list-ref ctx 9))
          (check-rejected (context-bind context-host proof-host registration p 1 0 2 2))
          (check (.ref (context-claim context-host 1 0) 'reason) => 'temporal-proof-denied))))
    (yuanxu-test-case "Temporal proof capability retains creating owner even before first use"
      (let* ((ph (agentic-ai-lab-temporal-support-policy-host)) (proof-host (agentic-ai-lab-temporal-proof-host ph))
             (ctx (mrr-derivation-fixture)))
        (check (thread-join! (thread-start! (make-thread (lambda ()
          (rejected? (lambda () (agentic-ai-lab-temporal-proof-host-refresh! proof-host "source" 1 (car ctx) (list-ref ctx 9)))))))) => #t)
        (check (.ref (agentic-ai-lab-temporal-proof-host-refresh! proof-host "source" 1 (car ctx) (list-ref ctx 9)) 'generation) => 1)))
    (yuanxu-test-case "retained native proof uses registered current source policy and observed clock"
      (let* ((ctx (mrr-derivation-fixture)) (ph (agentic-ai-lab-temporal-support-policy-host))
             (host (agentic-ai-lab-temporal-proof-host ph)) (p (policy "v1"))
             (snapshot (agentic-ai-lab-temporal-proof-host-refresh! host "source" 1 (car ctx) (list-ref ctx 9)))
             (registration (register-selected host snapshot ctx)))
        (agentic-ai-lab-temporal-support-policy-host-refresh! ph p 1 (at 1))
        (let (result (proof-current host registration 1 1 p))
          (check (.ref result 'status) => 'current)
          (check (.ref result 'proof-admitted?) => #t)
          (check (.ref result 'source-authenticated?) => #f)
          (check (.ref result 'selection-admitted?) => #f)
          (check (.ref result 'action-authorized?) => #f)
          (check (.ref result 'durable?) => #f)
          (check (.ref (.ref (.ref result 'guard) 'effective-at) 'coordinate) => 1))
        (check (.ref (register-selected host snapshot ctx) 'identity) => (.ref registration 'identity))
        (check-rejected (agentic-ai-lab-temporal-proof-host-current host "unknown" 1 1 (.ref p 'semantic-digest) 128) )
        (check-rejected (proof-current host registration 0 1 p) )
        (check-rejected (proof-current host registration 1 0 p) )
        (check (.ref (agentic-ai-lab-temporal-proof-host-current host (.ref registration 'identity) 1 1 (.ref p 'semantic-digest) 0) 'status) => 'unknown)))
    (yuanxu-test-case "current proof cannot reuse historical cut after late correction"
      (let* ((ctx (mrr-derivation-fixture)) (ph (agentic-ai-lab-temporal-support-policy-host))
             (host (agentic-ai-lab-temporal-proof-host ph)) (p (policy "v1")) (j (list-ref ctx 9))
             (snapshot (agentic-ai-lab-temporal-proof-host-refresh! host "source" 1 (car ctx) j))
             (registration (register-selected host snapshot ctx)) (changed (corrected-journal j)))
        (agentic-ai-lab-temporal-support-policy-host-refresh! ph p 1 (at 1))
        (check (.ref (proof-current host registration 1 1 p) 'status) => 'current)
        (agentic-ai-lab-temporal-proof-host-refresh! host "source" 2 (car ctx) changed)
        (agentic-ai-lab-temporal-support-policy-host-refresh! ph p 2 (at 2))
        (check (.ref (proof-current host registration 2 2 p) 'status) => 'unsupported)
        (check (.ref (replay-selected (derive-selected ctx (list-ref ctx 6)) ctx (list-ref ctx 6)) 'semantic-digest) => (.ref registration 'proof-digest))
        (check-rejected (agentic-ai-lab-temporal-proof-host-refresh! host "source" 3 (car ctx) j) )
        (check-rejected (agentic-ai-lab-temporal-proof-host-refresh! host "source" 1 (car ctx) changed) )
        (check-rejected (agentic-ai-lab-temporal-proof-host-refresh! host "source" 2 (car ctx) j) )
        (check-rejected (register-selected host snapshot ctx) )
        (check (.ref (proof-current host registration 2 2 p) 'status) => 'unsupported)))
    (yuanxu-test-case "registered proof detects catalog replacement and Host policy expiry"
      (let* ((ctx (mrr-derivation-fixture)) (ph (agentic-ai-lab-temporal-support-policy-host))
             (host (agentic-ai-lab-temporal-proof-host ph)) (p (policy "v1")) (program-value (car ctx))
             (snapshot (agentic-ai-lab-temporal-proof-host-refresh! host "source" 1 program-value (list-ref ctx 9)))
             (registration (register-selected host snapshot ctx))
             (changed (agentic-ai-lab-temporal-rule-program (.ref program-value 'identity) "new-catalog"
               (.ref program-value 'generation) (.ref program-value 'ascent-generation)
               (.ref program-value 'relations) (.ref program-value 'rules))))
        (agentic-ai-lab-temporal-support-policy-host-refresh! ph p 1 (at 4))
        (check (.ref (proof-current host registration 1 1 p) 'status) => 'expired-policy)
        (agentic-ai-lab-temporal-proof-host-refresh! host "source" 2 changed (list-ref ctx 9))
        (check (.ref (proof-current host registration 2 1 p) 'status) => 'stale-catalog)
        (check (.ref (replay-selected (derive-selected ctx (list-ref ctx 6)) ctx (list-ref ctx 6)) 'mrr-rule-equivalence-verified?) => #t)))
    (yuanxu-test-case "proof host rejects forged contexts and same generation conflict before mutation"
      (let* ((ctx (mrr-derivation-fixture)) (ph (agentic-ai-lab-temporal-support-policy-host))
             (host (agentic-ai-lab-temporal-proof-host ph)) (p (policy "v1")) (j (list-ref ctx 9))
             (snapshot (agentic-ai-lab-temporal-proof-host-refresh! host "source" 1 (car ctx) j))
             (registration (register-selected host snapshot ctx)) (context-value (selected-context ctx)))
        (agentic-ai-lab-temporal-support-policy-host-refresh! ph p 1 (at 1))
        (check-rejected (agentic-ai-lab-temporal-proof-host-register! host "source" (.ref snapshot 'semantic-digest)
          (.o (:: @ context-value) semantic-digest: "forged") "policy") )
        (check-rejected (agentic-ai-lab-temporal-proof-host-refresh! host "source" 1 (car ctx) (corrected-journal j)) )
        (check-rejected (agentic-ai-lab-temporal-proof-host-refresh! host "source" 2
          (.o (:: @ (car ctx)) catalog-digest: "forged") j) )
        (check-rejected (agentic-ai-lab-temporal-proof-host-refresh! host "source" 2 (car ctx)
          (.o (:: @ j) semantic-digest: "forged")) )
        (check (.ref (proof-current host registration 1 1 p) 'status) => 'current)))
)
