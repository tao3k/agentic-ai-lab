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
;;;      FunFlow `cas-get` / `sandbox-run` batches FIRST with ZERO LLM calls, and
;;;      completed receipts automatically mark tasks done & admit `EvidenceFact.`s!
;;;   3. Scoped Detour `blocker-active` fail-closed trunk-mutation / settlement gate
;;;   4. Competing Hypothesis Preservation: when `open-competition` hypotheses
;;;      exist alongside proposed POO branches, emits the full `(hypotheses × branches)`
;;;      read-only parallel batch, reconciles receipts into `CompetingHypothesisMatrix.`,
;;;      and records it on `ObligationGraph` without collapsing or authorizing effects!
;;;   5. Pure multi-round trampoline (`run-unified-driver-to-quiescence`) & direct
;;;      Marlin `WorkbenchTabProjection` projection (`project-driver-state->workbench-projection`).

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list filter find)
        "obligation-graph.ss"
        "ascent-reconciler.ss"
        "dag-frontier-scheduler.ss"
        "task-actor.ss"
        "atomic-effect-orchestrator.ss")

(export UnifiedDriverState.
        UnifiedDriverStepResult.
        UnifiedDriverRunTrace.
        make-unified-driver-state
        drive-graph-actor-step
        run-unified-driver-to-quiescence
        project-driver-state->workbench-projection)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(def (strip-prefix prefix s)
  (let ((plen (string-length prefix))
        (slen (string-length s)))
    (if (and (>= slen plen) (string-prefix? prefix s))
      (substring s plen slen)
      #f)))

(.def UnifiedDriverState.
  kind: 'agentic-ai-lab.graph-engine.unified-driver-state.v1
  authorizes-effect?: #f)

(.def UnifiedDriverStepResult.
  kind: 'agentic-ai-lab.graph-engine.unified-driver-step-result.v1
  authorizes-effect?: #f)

(.def UnifiedDriverRunTrace.
  kind: 'agentic-ai-lab.graph-engine.unified-driver-run-trace.v1
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

;;; Apply deterministic task completion receipts (`cas-hit` or `sandbox-exited` 0)
;;; directly onto the immutable `ObligationGraph`, admitting produced evidence
;;; and marking `(task-id . premise-digest)` completed for ASCENT idempotence.
(def (ingest-deterministic-receipts graph receipts prev-outputs)
  (let ((det-tasks (.ref graph 'det-tasks))
        (cut (.ref graph 'cut)))
    (let loop ((rs receipts) (g graph) (outs prev-outputs) (cas-hits 0))
      (if (null? rs)
        (values g outs cas-hits)
        (let* ((r (car rs))
               (rk (and (object? r) (opt-ref r 'kind #f)))
               (eid (and (object? r) (opt-ref r 'effect-id "")))
               (tid (cond
                     ((and (eq? rk 'cas-hit) (strip-prefix "cas-get:" eid)) => values)
                     ((and (eq? rk 'sandbox-exited)
                           (= (opt-ref r 'exit-code 1) 0)
                           (strip-prefix "sandbox:" eid))
                      => values)
                     (else #f)))
               (task (and tid (find (lambda (t) (equal? (.ref t 'task-id) tid)) det-tasks))))
          (if task
            (let* ((pdig (obligation-graph-premise-digest
                          g (.ref task 'obligation-id) (.ref task 'premise-ids)))
                   (payload (if (eq? rk 'cas-hit)
                              (opt-ref r 'payload "")
                              (opt-ref r 'stdout "")))
                   (ev (make-evidence-fact
                        (.ref task 'produces-evidence-id)
                        payload
                        cut: cut
                        premise-ids: (.ref task 'premise-ids)))
                   (g1 (obligation-graph-with-evidence g ev))
                   (g2 (obligation-graph-mark-task-completed g1 tid pdig)))
              (loop (cdr rs)
                    g2
                    (append outs (list (cons tid payload)))
                    (if (eq? rk 'cas-hit) (+ cas-hits 1) cas-hits)))
            (loop (cdr rs) g outs cas-hits)))))))

;;; Pure functional step: `(state, incoming-receipts) -> UnifiedDriverStepResult.`
;;; ZERO I/O, ZERO mutable globals — Marlin's thin Tokio pump executes `effects`
;;; in parallel and feeds raw receipts back into the next call.
(def (drive-graph-actor-step state (receipts '()))
  (let*-values
      (((actor) (.ref state 'actor))
       ((raw-graph) (.ref state 'obligation-graph))
       ((ctx) (.ref state 'governed-context))
       ((hyps) (.ref state 'competing-hypotheses))
       ((branches) (.ref state 'branch-proposals))
       ((detour-mode) (opt-ref actor 'detour-mode 'mainline))
       ((prev-matrix) (opt-ref state 'hypothesis-matrix #f))
       ((prev-outputs) (opt-ref state 'completed-step-outputs '()))
       ((next-count) (+ (opt-ref state 'step-count 0) 1))
       ;; Step 1a: Ingest deterministic FunFlow / Sandbox receipts into ObligationGraph.
       ((graph1 next-outputs cas-hits)
        (ingest-deterministic-receipts raw-graph receipts prev-outputs))
       ;; Step 1b: Reconcile any competing-hypothesis receipts into a full
       ;; non-authorizing CompetingHypothesisMatrix and archive on ObligationGraph.
       ((hyp-receipts)
        (filter (lambda (r)
                  (and (object? r)
                       (string-prefix? "hyp:" (opt-ref r 'effect-id ""))))
                receipts))
       ((matrix)
        (if (and (pair? hyp-receipts) (pair? hyps) (pair? branches))
          (reconcile-competing-hypothesis-matrix hyps branches hyp-receipts)
          prev-matrix))
       ((graph)
        (if (and (pair? hyp-receipts) matrix)
          (obligation-graph-record-branch-matrix graph1 matrix)
          graph1))
       ;; Step 2: Run real `gerbil-ascent` fixed-point reconciliation on updated graph.
       ((ascent) (ascent-reconcile-frontier graph))
       ((frontier-mode) (.ref ascent 'frontier-mode))
       ((ready-det) (.ref ascent 'ready-deterministic-tasks))
       ((epistemic-status) (.ref ascent 'epistemic-competition-status)))
    (cond
     ;; Gate A: Governance unhealthy -> halt fail-closed with 0 effects.
     ((eq? frontier-mode 'blocked-on-governance)
      (let ((next-state (make-unified-driver-state
                         actor graph ctx
                         competing-hypotheses: hyps
                         branch-proposals: branches
                         hypothesis-matrix: matrix
                         completed-step-outputs: next-outputs
                         step-count: next-count)))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.graph-engine.unified-driver-step-result.v1
            phase: 'blocked-on-governance
            llm-calls-emitted: 0
            cas-hits-observed: cas-hits
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
                          completed-step-outputs: next-outputs
                          step-count: next-count)))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.graph-engine.unified-driver-step-result.v1
            phase: (if (and (null? admitted-effects) (pair? blocked-plans))
                     'blocked-by-detour-or-policy
                     'deterministic-funflow-wave)
            llm-calls-emitted: 0
            cas-hits-observed: cas-hits
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
                          completed-step-outputs: next-outputs
                          step-count: next-count)))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.graph-engine.unified-driver-step-result.v1
            phase: 'evaluating-competing-hypotheses
            llm-calls-emitted: (length effs)
            cas-hits-observed: cas-hits
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
                         completed-step-outputs: next-outputs
                         step-count: next-count)))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.graph-engine.unified-driver-step-result.v1
            phase: 'blocker-detour-halting-settlement
            llm-calls-emitted: 0
            cas-hits-observed: cas-hits
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
                         completed-step-outputs: next-outputs
                         step-count: next-count)))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.graph-engine.unified-driver-step-result.v1
            phase: 'quiescent-fixed-point
            llm-calls-emitted: 0
            cas-hits-observed: cas-hits
            effects: '()
            ascent-frontier: ascent
            hypothesis-matrix: matrix
            state: next-state
            authorizes-effect?: #f))))))

;;; Pure functional multi-round trampoline over an injected atomic-effect
;;; interpreter (`(effects) -> receipts`, e.g. Marlin's thin Rust `effect_pump`).
(def (run-unified-driver-to-quiescence
      initial-state
      effect-interpreter
      max-rounds: (max-rounds 8))
  (let loop ((st initial-state)
             (incoming '())
             (round 1)
             (total-llm 0)
             (total-cas-hits 0)
             (trace '()))
    (let* ((step (drive-graph-actor-step st incoming))
           (phase (.ref step 'phase))
           (effs (.ref step 'effects))
           (llm-n (+ total-llm (.ref step 'llm-calls-emitted)))
           (cas-n (+ total-cas-hits (opt-ref step 'cas-hits-observed 0)))
           (entry (.o bind-these: #f
                      round: round
                      phase: phase
                      effects-count: (length effs)
                      llm-calls-emitted: (.ref step 'llm-calls-emitted)
                      cas-hits-observed: (opt-ref step 'cas-hits-observed 0)))
           (next-trace (append trace (list entry))))
      (if (or (null? effs) (>= round max-rounds))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.graph-engine.unified-driver-run-trace.v1
            final-phase: phase
            final-state: (.ref step 'state)
            final-step: step
            rounds-executed: round
            total-llm-calls: llm-n
            cas-hits-count: cas-n
            trace: next-trace
            authorizes-effect?: #f)
        (let ((next-receipts (effect-interpreter effs)))
          (loop (.ref step 'state) next-receipts (+ round 1) llm-n cas-n next-trace))))))

(def (enrich-hypothesis-for-workbench hyp matrix)
  (let* ((hid (.ref hyp 'hypothesis-id))
         (cells (if (object? matrix)
                  (filter (lambda (c) (equal? (.ref c 'hypothesis-id) hid))
                          (.ref matrix 'cells))
                  '()))
         (obs-count (length (filter (lambda (c) (opt-ref c 'observed? #f)) cells)))
         (total-count (length cells)))
    (.o bind-these: #f
        hypothesis-id: hid
        claim: (.ref hyp 'claim)
        contradictions: (.ref hyp 'contradictions)
        open-questions: (.ref hyp 'open-questions)
        observed-branches: obs-count
        total-branches: total-count
        authorizes-effect?: #f)))

;;; Project a live `UnifiedDriverStepResult.` (or `UnifiedDriverRunTrace.` /
;;; `UnifiedDriverState.`) directly into a Marlin `WorkbenchTabProjection` POO
;;; object consumable by `scheme/ui/task-workbench.ss` with ZERO Rust edits!
(def (project-driver-state->workbench-projection driver-obj archived-actors: (archived-actors '()))
  (let* ((step (cond
                ((and (object? driver-obj)
                      (eq? (opt-ref driver-obj 'kind #f)
                           'agentic-ai-lab.graph-engine.unified-driver-run-trace.v1))
                 (.ref driver-obj 'final-step))
                ((and (object? driver-obj)
                      (eq? (opt-ref driver-obj 'kind #f)
                           'agentic-ai-lab.graph-engine.unified-driver-step-result.v1))
                 driver-obj)
                (else (drive-graph-actor-step driver-obj))))
         (st (.ref step 'state))
         (actor (.ref st 'actor))
         (graph (.ref st 'obligation-graph))
         (ascent (.ref step 'ascent-frontier))
         (matrix (.ref step 'hypothesis-matrix))
         (hyps (.ref st 'competing-hypotheses))
         (enriched-hyps (map (lambda (h) (enrich-hypothesis-for-workbench h matrix)) hyps))
         (total-obs (length (.ref graph 'obligations)))
         (done-obs (length (.ref ascent 'discharged-obligations)))
         (tid (.ref actor 'task-id))
         (tab (.o bind-these: #f
                  id: tid
                  label: (opt-ref actor 'title tid)
                  status: (opt-ref actor 'status 'in-progress)
                  mode: 'active
                  detour-mode: (opt-ref actor 'detour-mode 'mainline)
                  detour-node-id: (opt-ref actor 'detour-node-id #f)
                  driver-phase: (.ref step 'phase)
                  pending-effects-count: (length (.ref step 'effects))
                  worktree: (opt-ref actor 'worktree "main")
                  checklist-done: done-obs
                  checklist-total: total-obs
                  competing-hypotheses: enriched-hyps))
         (archived (map (lambda (a)
                          (.o bind-these: #f
                              task-id: (.ref a 'task-id)
                              title: (opt-ref a 'title (.ref a 'task-id))
                              worktree: (opt-ref a 'worktree "main")))
                        archived-actors)))
    (.o bind-these: #f
        pinned-tab: 'index
        dynamic-tabs: (list tab)
        archived-index: archived
        visible-tab-ids: (list 'index tid))))
