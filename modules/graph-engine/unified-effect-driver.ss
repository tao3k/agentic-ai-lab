;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Unified Pure Scheme High-Order Execution Driver
;;; (`modules/graph-engine/unified-effect-driver.ss`).
;;;
;;; Composes EVERY pure Scheme high-order engine in `poo-flow` into a single
;;; functional state machine over Marlin's thin 4-primitive `AtomicEffect` pump:
;;;   1. Real `gerbil-ascent` fixed-point reconciliation (`ascent-reconcile-frontier`)
;;;   2. Strict Deterministic-First Precedence: ready deterministic tasks emit
;;;      FunFlow `cas-get` / `sandbox-run` batches FIRST with ZERO LLM calls!
;;;   3. Scoped Detour `blocker-active` fail-closed trunk-mutation / settlement gate
;;;   4. Competing Hypothesis Preservation: when `open-competition` hypotheses
;;;      exist alongside proposed POO branches, emits the full `(hypotheses × branches)`
;;;      read-only parallel batch and reconciles receipts into `CompetingHypothesisMatrix.`
;;;      without collapsing or authorizing effects!
;;;   5. Quiescent Fixed Point projection with 0 remaining effects.

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list filter)
        "obligation-graph.ss"
        "ascent-reconciler.ss"
        "dag-frontier-scheduler.ss"
        "task-actor.ss"
        "atomic-effect-orchestrator.ss")

(export UnifiedDriverState.
        UnifiedDriverStepResult.
        make-unified-driver-state
        drive-graph-actor-step)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(.def UnifiedDriverState.
  kind: 'agentic-ai-lab.graph-engine.unified-driver-state.v1
  authorizes-effect?: #f)

(.def UnifiedDriverStepResult.
  kind: 'agentic-ai-lab.graph-engine.unified-driver-step-result.v1
  authorizes-effect?: #f)

(def (make-unified-driver-state
      actor
      obligation-graph
      governed-context
      competing-hypotheses: (competing-hypotheses '())
      branch-proposals: (branch-proposals '())
      hypothesis-matrix: (hypothesis-matrix #f)
      completed-step-outputs: (completed-step-outputs '())
      step-count: (step-count 0))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.graph-engine.unified-driver-state.v1
      actor: actor
      obligation-graph: obligation-graph
      governed-context: governed-context
      competing-hypotheses: competing-hypotheses
      branch-proposals: branch-proposals
      hypothesis-matrix: hypothesis-matrix
      completed-step-outputs: completed-step-outputs
      step-count: step-count
      authorizes-effect?: #f))

(def (det-task->funflow-step task)
  (let* ((tid (.ref task 'task-id))
         (eff-class (opt-ref task 'effect-class 'pure-cas))
         (purity (if (eq? eff-class 'fenced-effect) 'sandboxed-effect 'pure-cas))
         (mutates? (pair? (opt-ref task 'write-footprint '()))))
    (make-funflow-step-spec
     tid
     purity: purity
     input-digest: (string-append "det-input:" tid)
     program: (if (eq? purity 'sandboxed-effect)
                (opt-ref task 'program "verify-step")
                #f)
     args: (opt-ref task 'args '())
     mutates-trunk?: mutates?)))

(def (collect-plan-effects plans)
  (let loop ((ps plans) (acc '()))
    (if (null? ps)
      (reverse acc)
      (let ((effs (.ref (car ps) 'effects)))
        (loop (cdr ps) (append (reverse effs) acc))))))

;;; Pure functional step: `(state, incoming-receipts) -> UnifiedDriverStepResult.`
;;; ZERO I/O, ZERO mutable globals — Marlin's thin Tokio pump executes `effects`
;;; in parallel and feeds raw receipts back into the next call.
(def (drive-graph-actor-step state (receipts '()))
  (let* ((actor (.ref state 'actor))
         (graph (.ref state 'obligation-graph))
         (ctx (.ref state 'governed-context))
         (hyps (.ref state 'competing-hypotheses))
         (branches (.ref state 'branch-proposals))
         (detour-mode (opt-ref actor 'detour-mode 'mainline))
         (prev-matrix (opt-ref state 'hypothesis-matrix #f))
         (prev-outputs (opt-ref state 'completed-step-outputs '()))
         (next-count (+ (opt-ref state 'step-count 0) 1))
         ;; Step 1: If incoming receipts contain competing-hypothesis evaluations,
         ;; reconcile them into a full non-authorizing CompetingHypothesisMatrix.
         (hyp-receipts (filter (lambda (r)
                                 (and (object? r)
                                      (string-prefix? "hyp:" (opt-ref r 'effect-id ""))))
                               receipts))
         (matrix (if (and (pair? hyp-receipts) (pair? hyps) (pair? branches))
                   (reconcile-competing-hypothesis-matrix hyps branches hyp-receipts)
                   prev-matrix))
         ;; Step 2: Run real `gerbil-ascent` fixed-point reconciliation on ObligationGraph.
         (ascent (ascent-reconcile-frontier graph))
         (frontier-mode (.ref ascent 'frontier-mode))
         (ready-det (.ref ascent 'ready-deterministic-tasks))
         (epistemic-status (.ref ascent 'epistemic-competition-status)))
    (cond
     ;; Gate A: Governance unhealthy -> halt fail-closed with 0 effects.
     ((eq? frontier-mode 'blocked-on-governance)
      (let ((next-state (make-unified-driver-state
                         actor graph ctx
                         competing-hypotheses: hyps
                         branch-proposals: branches
                         hypothesis-matrix: matrix
                         completed-step-outputs: prev-outputs
                         step-count: next-count)))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.graph-engine.unified-driver-step-result.v1
            phase: 'blocked-on-governance
            llm-calls-emitted: 0
            effects: '()
            ascent-frontier: ascent
            hypothesis-matrix: matrix
            state: next-state
            authorizes-effect?: #f)))

     ;; Gate B: Strict Deterministic-First Precedence (0 LLM calls!)
     ;; Plan Bernstein disjoint-footprint wave and map admitted tasks into
     ;; atomic FunFlow `cas-get` / `sandbox-run` effects.
     ((pair? ready-det)
      (let* ((c4-plan (plan-funflow-c4-frontier graph ready-det))
             (wave-tasks (if (.ref c4-plan 'valid?)
                           (.ref c4-plan 'parallel-batch)
                           '()))
             (steps (map det-task->funflow-step wave-tasks))
             (plans (map (lambda (s) (plan-funflow-step-effects s actor ctx)) steps))
             (blocked-plans (filter (lambda (p) (not (.ref p 'admitted?))) plans))
             (admitted-effects (collect-plan-effects (filter (lambda (p) (.ref p 'admitted?)) plans)))
             (next-state (make-unified-driver-state
                          actor graph ctx
                          competing-hypotheses: hyps
                          branch-proposals: branches
                          hypothesis-matrix: matrix
                          completed-step-outputs: prev-outputs
                          step-count: next-count)))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.graph-engine.unified-driver-step-result.v1
            phase: (if (and (null? admitted-effects) (pair? blocked-plans))
                     'blocked-by-detour-or-policy
                     'deterministic-funflow-wave)
            llm-calls-emitted: 0
            c4-frontier-plan: c4-plan
            blocked-reasons: (map (lambda (p) (.ref p 'reason)) blocked-plans)
            effects: admitted-effects
            ascent-frontier: ascent
            hypothesis-matrix: matrix
            state: next-state
            authorizes-effect?: #f)))

     ;; Gate C: Competing Hypothesis Branch Evaluation (only after deterministic wave
     ;; is empty and before matrix has been reconciled for current proposals).
     ((and (not matrix) (pair? hyps) (pair? branches)
           (or (eq? epistemic-status 'open-competition)
               (> (length hyps) 1)))
      (let* ((hyp-plan (plan-competing-hypothesis-frontier actor hyps branches ctx))
             (effs (.ref hyp-plan 'effects))
             (next-state (make-unified-driver-state
                          actor graph ctx
                          competing-hypotheses: hyps
                          branch-proposals: branches
                          hypothesis-matrix: #f
                          completed-step-outputs: prev-outputs
                          step-count: next-count)))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.graph-engine.unified-driver-step-result.v1
            phase: 'evaluating-competing-hypotheses
            llm-calls-emitted: (length effs)
            effects: effs
            ascent-frontier: ascent
            hypothesis-matrix: #f
            state: next-state
            ;; Non-negotiable: hypothetical model evaluation NEVER authorizes effects!
            authorizes-effect?: #f)))

     ;; Gate D: BlockerActive Scoped Detour halts settlement even when deterministic wave is empty.
     ((eq? detour-mode 'blocker-active)
      (let ((next-state (make-unified-driver-state
                         actor graph ctx
                         competing-hypotheses: hyps
                         branch-proposals: branches
                         hypothesis-matrix: matrix
                         completed-step-outputs: prev-outputs
                         step-count: next-count)))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.graph-engine.unified-driver-step-result.v1
            phase: 'blocker-detour-halting-settlement
            llm-calls-emitted: 0
            effects: '()
            ascent-frontier: ascent
            hypothesis-matrix: matrix
            state: next-state
            authorizes-effect?: #f)))

     ;; Gate E: Quiescent Fixed Point (ready to settle or present preserved hypothesis matrix).
     (else
      (let ((next-state (make-unified-driver-state
                         actor graph ctx
                         competing-hypotheses: hyps
                         branch-proposals: branches
                         hypothesis-matrix: matrix
                         completed-step-outputs: prev-outputs
                         step-count: next-count)))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.graph-engine.unified-driver-step-result.v1
            phase: 'quiescent-fixed-point
            llm-calls-emitted: 0
            effects: '()
            ascent-frontier: ascent
            hypothesis-matrix: matrix
            state: next-state
            authorizes-effect?: #f))))))
