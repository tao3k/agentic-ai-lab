;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Focused Suite: FunFlow Coproduct / ChoiceFlowPlan (`modules/funflow/choice-flow.ss`)
;;; Verifies static branch completeness, Tarjan SCC cycle rejection, native
;;; `flow-then` / `flow-fanout` Arrows with cross-world `FunflowCasStore` reuse,
;;; `FencedEffect.` multi-world gating, `defyuanxu-choice`, and active epistemic
;;; probing auto-refutation convergence (`choice-flow-converge`).

(import :std/test
        (only-in :std/error Error?)
        (only-in :clan/poo/object .o .ref)
        (only-in :clan/poo/number Integer)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/api
                 Fun flow-arr flow-then flow-fanout
                 make-runner make-local-eager-strategy make-request-only-adapter)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/cas-store
                 make-funflow-cas-store)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/governed-runner
                 make-governed-funflow-runner)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/choice-flow
                 ChoiceFlowPlan.
                 EpistemicProbeEvidence
                 choice-flow-plan?
                 make-choice-task-entry
                 flow-choice
                 choice-flow-execute
                 choice-flow-converge
                 defyuanxu-choice))

(export funflow-choice-flow-test)

(def (make-test-runner)
  (make-governed-funflow-runner
   (make-runner (make-local-eager-strategy) (make-request-only-adapter))
   cas-store: (make-funflow-cas-store)
   env-digest: "sha256:funflow-choice-test-v1"
   source-cut: "cut-choice-1"))

(def funflow-choice-flow-test
  (test-suite "FunFlow ChoiceFlowPlan (Coproduct/ArrowChoice + Shared CAS + Convergence)"

    (test-case "1. defyuanxu-choice and ChoiceFlowPlan enforce branch completeness, share CAS across competing worlds, and block FencedEffect"
      (let* ((shared-calls (box 0))
             (branch-a-calls (box 0))
             (branch-b-calls (box 0))
             (fenced-calls (box 0))
             (int-sig (Fun Integer <- Integer))
             ;; Composed native FunFlow Arrow (flow-then) as shared prefix
             (shared-arrow
              (flow-then
               'shared-inc-dbl
               (flow-arr 'shared-inc int-sig
                         (lambda (x)
                           (set-box! shared-calls (+ 1 (unbox shared-calls)))
                           (+ x 1)))
               (flow-arr 'shared-dbl int-sig (lambda (x) (* x 2)))))
             ;; Fanout native FunFlow Arrow (flow-fanout) as branch-b probe
             (branch-a-arrow
              (flow-arr 'probe-a int-sig
                        (lambda (x)
                          (set-box! branch-a-calls (+ 1 (unbox branch-a-calls)))
                          (+ x 10))))
             (branch-b-arrow
              (flow-fanout
               'probe-b-fanout
               (flow-arr 'probe-b-left int-sig
                         (lambda (x)
                           (set-box! branch-b-calls (+ 1 (unbox branch-b-calls)))
                           (+ x 20)))
               (flow-arr 'probe-b-right int-sig (lambda (x) (+ x 30)))))
             (fenced-arrow
              (flow-arr 'fenced-commit int-sig
                        (lambda (x)
                          (set-box! fenced-calls (+ 1 (unbox fenced-calls)))
                          x)))
             (shared-entry (make-choice-task-entry shared-arrow 5 task-id: "task:shared"))
             (fenced-entry (make-choice-task-entry fenced-arrow 5
                                                   task-id: "task:fenced"
                                                   effect-class: 'fenced-effect))
             (worlds (list (.o bind-these: #f world-index: 0 choice: 'opt-a dispatch-decision: 'fenced-apply)
                           (.o bind-these: #f world-index: 1 choice: 'opt-b dispatch-decision: 'fenced-apply)))
             (incomplete-plan
              (flow-choice (.o bind-these: #f opt-a: (make-choice-task-entry branch-a-arrow 5))
                           shared-prefix: (list shared-entry)))
             (runner (make-test-runner))
             (bad-exec (choice-flow-execute worlds runner incomplete-plan approval-live?: #t)))
        ;; Negative control 1: incomplete branches fail closed with 0 executions
        (check-equal? (choice-flow-plan? incomplete-plan) #t)
        (check-equal? (.ref bad-exec 'admitted?) #f)
        (check-equal? (.ref bad-exec 'reason) 'incomplete-choice-flow-branches)
        (check-equal? (.ref bad-exec 'missing-branches) '(opt-b))
        (check-equal? (.ref bad-exec 'total-executions) 0)
        (check-equal? (unbox shared-calls) 0)
        ;; Negative control 2: fenced-effect forbidden inside shared-prefix
        (check-exception
         (flow-choice (.o bind-these: #f opt-a: '()) shared-prefix: (list fenced-entry))
         Error?)
        ;; Positive control via `defyuanxu-choice` hygienic macro
        (defyuanxu-choice complete-plan
          (.o bind-these: #f
              opt-a: (make-choice-task-entry branch-a-arrow 5)
              opt-b: (make-choice-task-entry branch-b-arrow 5))
          shared-prefix: (list shared-entry)
          fenced-tail: (list fenced-entry))
        (let ((exec (choice-flow-execute worlds runner complete-plan approval-live?: #t)))
          (check-equal? (.ref exec 'admitted?) #t)
          (check-equal? (.ref exec 'world-count) 2)
          (check-equal? (unbox shared-calls) 1)
          (check-equal? (unbox branch-a-calls) 1)
          (check-equal? (unbox branch-b-calls) 1)
          (check-equal? (.ref exec 'total-executions) 3)
          (check-equal? (.ref exec 'total-cas-hits) 1)
          (check-equal? (unbox fenced-calls) 0)
          (check-equal? (.ref exec 'fenced-blocked-count) 2)
          (check-equal? (.ref exec 'action-authorized?) #f)
          (check (string? (.ref (car (.ref exec 'worlds)) 'dag-digest)) => #t))))

    (test-case "2. Pre-execution Tarjan SCC check rejects cyclic ChoiceFlowPlan fail-closed with 0 executions"
      (let* ((ran (box 0))
             (sig (Fun Integer <- Integer))
             (a (make-choice-task-entry
                 (flow-arr 'cyc-a sig (lambda (x) (set-box! ran (+ 1 (unbox ran))) x))
                 1
                 task-id: "task:cyc-a"
                 produces-evidence-id: "ev:cyc-a"
                 required-evidence-ids: '("ev:cyc-b")))
             (b (make-choice-task-entry
                 (flow-arr 'cyc-b sig (lambda (x) (set-box! ran (+ 1 (unbox ran))) x))
                 1
                 task-id: "task:cyc-b"
                 produces-evidence-id: "ev:cyc-b"
                 required-evidence-ids: '("ev:cyc-a")))
             (plan (flow-choice (.o bind-these: #f only: (list a b))))
             (worlds (list (.o bind-these: #f choice: 'only)))
             (res (choice-flow-execute worlds (make-test-runner) plan)))
        (check-equal? (.ref res 'admitted?) #f)
        (check-equal? (.ref res 'reason) 'funflow-dag-cycle-detected)
        (check-equal? (.ref res 'total-executions) 0)
        (check-equal? (unbox ran) 0)))

    (test-case "3. choice-flow-converge auto-refutes disproven worlds across rounds with cross-round CAS reuse and unblocks FencedEffect only when unique + approved"
      (let* ((shared-calls (box 0))
             (a-calls (box 0))
             (b-calls (box 0))
             (fenced-calls (box 0))
             (int-sig (Fun Integer <- Integer))
             (probe-sig (Fun EpistemicProbeEvidence <- Integer))
             (shared-entry
              (make-choice-task-entry
               (flow-arr 'conv-shared int-sig
                         (lambda (x)
                           (set-box! shared-calls (+ 1 (unbox shared-calls)))
                           (+ x 1)))
               1
               task-id: "task:conv-shared"))
             (make-probe
              (lambda (opt verdict counter detail)
                (make-choice-task-entry
                 (flow-arr (string->symbol (string-append "probe-" (symbol->string opt)))
                           probe-sig
                           (lambda (_x)
                             (set-box! counter (+ 1 (unbox counter)))
                             (.o (kind := 'epistemic-verdict)
                                 (verdict := verdict)
                                 (option := opt)
                                 (detail := detail))))
                 1
                 task-id: (string-append "task:probe:" (symbol->string opt)))))
             (fenced-entry
              (make-choice-task-entry
               (flow-arr 'conv-fenced int-sig
                         (lambda (x)
                           (set-box! fenced-calls (+ 1 (unbox fenced-calls)))
                           (* x 100)))
               1
               task-id: "task:conv-fenced"
               effect-class: 'fenced-effect))
             (all-options '(opt-a opt-b))
             (solve-fn
              (lambda (refuted)
                (let ((surviving (filter (lambda (o) (not (memq o refuted))) all-options)))
                  (map (lambda (o)
                         (.o bind-these: #f choice: o dispatch-decision: 'fenced-apply))
                       surviving))))
             ;; Case A: opt-a refuted -> Round 1 converges to opt-b, reuses CAS on shared & opt-b, and runs fenced-tail once approved!
             (plan-a
              (flow-choice
               (.o bind-these: #f
                   opt-a: (make-probe 'opt-a 'refutes a-calls "Refuted by invariant probe")
                   opt-b: (make-probe 'opt-b 'supports b-calls "Supported by invariant probe"))
               shared-prefix: (list shared-entry)
               fenced-tail: (list fenced-entry)))
             (conv-a (choice-flow-converge solve-fn (make-test-runner) plan-a approval-live?: #t))
             ;; Case B: both refuted -> fail-closed 'unsatisfiable
             (b1 (box 0)) (b2 (box 0))
             (plan-b
              (flow-choice
               (.o bind-these: #f
                   opt-a: (make-probe 'opt-a 'refutes b1 "Refuted A")
                   opt-b: (make-probe 'opt-b 'refutes b2 "Refuted B"))))
             (conv-b (choice-flow-converge solve-fn (make-test-runner) plan-b))
             ;; Case C: inconclusive -> preserves irreducible competition in 1 round
             (c1 (box 0)) (c2 (box 0))
             (plan-c
              (flow-choice
               (.o bind-these: #f
                   opt-a: (make-probe 'opt-a 'inconclusive c1 "Ambiguous A")
                   opt-b: (make-probe 'opt-b 'inconclusive c2 "Ambiguous B"))))
             (conv-c (choice-flow-converge solve-fn (make-test-runner) plan-c)))
        ;; Case A assertions
        (check-equal? (.ref conv-a 'convergence-status) 'converged-unique)
        (check-equal? (.ref conv-a 'round-count) 2)
        (check-equal? (.ref conv-a 'refuted-options) '(opt-a))
        (check-equal? (unbox shared-calls) 1)
        (check-equal? (unbox a-calls) 1)
        (check-equal? (unbox b-calls) 1)
        ;; Fenced tail was blocked in Round 0 (2 competing worlds), then ran ONCE in Round 1 (unique + approved)!
        (check-equal? (unbox fenced-calls) 1)
        (check-equal? (.ref conv-a 'total-executions) 4)
        (check-equal? (.ref conv-a 'total-cas-hits) 3)
        (check-equal? (.ref conv-a 'action-authorized?) #f)
        ;; Case B assertions
        (check-equal? (.ref conv-b 'convergence-status) 'unsatisfiable)
        (check-equal? (.ref conv-b 'final-solution) '())
        (check-equal? (.ref conv-b 'action-authorized?) #f)
        ;; Case C assertions
        (check-equal? (.ref conv-c 'convergence-status) 'irreducible-competition)
        (check-equal? (.ref conv-c 'round-count) 1)
        (check-equal? (length (.ref conv-c 'final-solution)) 2)
        (check-equal? (.ref conv-c 'action-authorized?) #f)))))
