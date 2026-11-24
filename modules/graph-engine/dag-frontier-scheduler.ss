;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; FunFlow CAS DAG + C4 Strategy Frontier Scheduler for Post-ReAct LoopEngine
;;; (`modules/loop-engine/dag-frontier-scheduler.ss`).
;;;
;;; Strictly separates:
;;;   1. Deterministic parallel command/query fan-out (FunFlow CAS DAG + C4
;;;      ParallelFrontierStrategy + Disjoint Read/Write Footprints -> 0 Subagents,
;;;      0 LLM orchestration calls, CAS cache skip)
;;;   2. Causal/context dependencies (`Task A -> Task B` via `depends-on-tasks` or
;;;      `produces-evidence-id` -> `required-evidence-ids`, or overlapping write
;;;      footprints -> strict topological/C4 ordering).

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list filter every any)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/durable-dag
                 PureCAS.
                 VerifiedEpistemic.
                 FencedEffect.
                 OrchestratorStrategy.
                 ParallelFrontierStrategy.
                 DurableGovernedStrategy.
                 strategy-admit-frontier
                 funflow-dag-node
                 funflow-dag-build
                 funflow-resume-plan)
        "obligation-graph.ss")

(export FunflowFrontierPlan.
        footprints-compatible?
        task-node->funflow-dag-node
        plan-funflow-c4-frontier)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(.def FunflowFrontierPlan.
  kind: 'agentic-ai-lab.loop-engine.funflow-frontier-plan.v1)

(def (as-sym id)
  (cond
   ((symbol? id) id)
   ((string? id) (string->symbol id))
   (else 'unnamed-task)))

(def (lists-overlap? xs ys)
  (and (pair? xs) (pair? ys)
       (any (lambda (x) (and (member x ys) #t)) xs)))

(def (spans-compatible? sa sb)
  (cond
   ((or (not sa) (not sb)) #t)
   ((and (pair? sa) (pair? sb)
         (exact-integer? (car sa)) (exact-integer? (cdr sa))
         (exact-integer? (car sb)) (exact-integer? (cdr sb)))
    (or (<= (cdr sa) (car sb)) (<= (cdr sb) (car sa))))
   (else #t)))

;;; Classic Bernstein disjoint-footprint gate for parallel FunFlow DAG admission:
;;; - Write/Write conflict -> NOT compatible (must serialize)
;;; - Write/Read or Read/Write conflict -> NOT compatible (must serialize)
;;; - Overlapping numeric spans -> NOT compatible
;;; - Read-only tasks (`write-footprint: '()`) with disjoint/unconstrained spans
;;;   are 100% compatible and fan out in a single DAG wave with ZERO Subagents!
(def (footprints-compatible? node-a node-b)
  (let* ((ma (opt-ref node-a 'metadata #f))
         (mb (opt-ref node-b 'metadata #f))
         (ra (if (object? ma) (opt-ref ma 'read-footprint '()) (opt-ref node-a 'read-footprint '())))
         (wa (if (object? ma) (opt-ref ma 'write-footprint '()) (opt-ref node-a 'write-footprint '())))
         (rb (if (object? mb) (opt-ref mb 'read-footprint '()) (opt-ref node-b 'read-footprint '())))
         (wb (if (object? mb) (opt-ref mb 'write-footprint '()) (opt-ref node-b 'write-footprint '())))
         (sa (opt-ref node-a 'span #f))
         (sb (opt-ref node-b 'span #f)))
    (and (not (lists-overlap? wa wb))
         (not (lists-overlap? wa rb))
         (not (lists-overlap? ra wb))
         (spans-compatible? sa sb))))

(def (effect-symbol->class sym)
  (cond
   ((eq? sym 'fenced-effect) FencedEffect.)
   ((eq? sym 'verified-epistemic) VerifiedEpistemic.)
   (else PureCAS.)))

;;; Project a LoopEngine DeterministicTaskNode into a FunFlow CAS DAG node,
;;; resolving both explicit `depends-on-tasks` and implicit causal edges where
;;; Task B's `required-evidence-ids` matches Task A's `produces-evidence-id`.
(def (task-node->funflow-dag-node task all-tasks cut)
  (let* ((tid (.ref task 'task-id))
         (tid-sym (as-sym tid))
         (explicit-deps (map as-sym (opt-ref task 'depends-on-tasks '())))
         (req-evs (opt-ref task 'required-evidence-ids '()))
         (ev-deps
          (filter
           (lambda (dep-sym) (not (eq? dep-sym tid-sym)))
           (map (lambda (other) (as-sym (.ref other 'task-id)))
                (filter (lambda (other)
                          (and (member (.ref other 'produces-evidence-id) req-evs) #t))
                        all-tasks))))
         (all-deps
          (let loop ((xs (append explicit-deps ev-deps)) (seen '()) (acc '()))
            (cond
             ((null? xs) (reverse acc))
             ((memq (car xs) seen) (loop (cdr xs) seen acc))
             (else (loop (cdr xs) (cons (car xs) seen) (cons (car xs) acc))))))
         (cut-str (string-append "cut-" (number->string cut)))
         (eff (effect-symbol->class (opt-ref task 'effect-class 'pure-cas)))
         (r-fp (opt-ref task 'read-footprint '()))
         (w-fp (opt-ref task 'write-footprint '())))
    (funflow-dag-node
     tid-sym
     needs: all-deps
     source-cut: cut-str
     step-code-digest: (string-append "loop-task:" tid)
     env-digest: (opt-ref task 'env-digest "sha256:default-env")
     input-digest: (string-append "input:" tid)
     effect-class: eff
     idempotency-key: (opt-ref task 'idempotency-key #f)
     sandbox-profile: (opt-ref task 'sandbox-profile #f)
     span: (opt-ref task 'span #f)
     metadata: (.o bind-these: #f
                   task-id: tid
                   task-node: task
                   read-footprint: r-fp
                   write-footprint: w-fp))))

;;; Compute a C4-governed FunFlow DAG frontier execution plan over an
;;; ObligationGraph's ready deterministic tasks.
;;; Returns:
;;;   - `valid?`: #f if a cycle or unresolved task edge exists (fail-closed!)
;;;   - `dag`: full `funflow-dag-build` object with topological order & CAS fingerprints
;;;   - `parallel-batch`: admitted pairwise-disjoint ready tasks (0 Subagents, 0 LLM)
;;;   - `deferred-tasks`: ready tasks deferred by footprint conflict or max-concurrency
;;;   - `cas-skipped-ids`: tasks already satisfied in `completed-cas`
;;;   - `subagents-spawned`: ALWAYS 0 (parallel DAG != Subagent)
(def (plan-funflow-c4-frontier
      graph
      ready-tasks
      strategy: (strategy ParallelFrontierStrategy.)
      completed-cas: (completed-cas #f))
  (let* ((all-tasks (.ref graph 'det-tasks))
         (cut (.ref graph 'cut))
         (dag-nodes (map (lambda (t) (task-node->funflow-dag-node t all-tasks cut))
                         all-tasks))
         (dag (funflow-dag-build dag-nodes strategy: strategy))
         (valid? (.ref dag 'valid?)))
    (if (not valid?)
      (.o bind-these: #f
          kind: 'agentic-ai-lab.loop-engine.funflow-frontier-plan.v1
          valid?: #f
          reason: (if (pair? (.ref dag 'cycle-nodes))
                    'funflow-dag-cycle-detected
                    'funflow-dag-invalid-edges)
          dag: dag
          strategy-name: (.ref strategy 'name)
          parallel-batch: '()
          deferred-tasks: ready-tasks
          cas-skipped-ids: '()
          subagents-spawned: 0
          llm-calls-used: 0)
      (let* ((ready-syms (map (lambda (t) (as-sym (.ref t 'task-id))) ready-tasks))
             ;; Preserve topological order across ready tasks
             (topo-ready-syms
              (filter (lambda (id) (memq id ready-syms))
                      (.ref dag 'topological-order)))
             ;; Restrict to tasks whose DAG `needs` are already completed in graph!
             (completed-tids (map car (.ref graph 'completed-tasks)))
             (completed-syms (map as-sym completed-tids))
             (node-map (.ref dag 'node-map))
             (dag-unblocked-nodes
              (filter
               (lambda (n)
                 (every (lambda (dep) (memq dep completed-syms))
                        (.ref n 'needs)))
               (map (lambda (id) (hash-ref node-map id)) topo-ready-syms)))
             (resume (if completed-cas
                       (funflow-resume-plan dag completed-cas)
                       #f))
             (skipped-syms (if resume (.ref resume 'skipped-ids) '()))
             (exec-candidates
              (filter (lambda (n) (not (memq (.ref n 'id) skipped-syms)))
                      dag-unblocked-nodes))
             (admission (strategy-admit-frontier
                         strategy
                         exec-candidates
                         (.o bind-these: #f
                             pair-compatible?: footprints-compatible?)))
             (selected-tasks
              (map (lambda (n) (.ref (.ref n 'metadata) 'task-node))
                   (.ref admission 'selected)))
             (selected-ids (map (lambda (t) (.ref t 'task-id)) selected-tasks))
             (deferred-tasks
              (filter (lambda (t)
                        (and (not (member (.ref t 'task-id) selected-ids))
                             (not (memq (as-sym (.ref t 'task-id)) skipped-syms))))
                      ready-tasks))
             (cas-skipped-ids
              (map symbol->string
                   (filter (lambda (id) (memq id ready-syms)) skipped-syms))))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.loop-engine.funflow-frontier-plan.v1
            valid?: #t
            reason: 'funflow-c4-frontier-planned
            dag: dag
            dag-digest: (.ref dag 'dag-digest)
            strategy-name: (.ref strategy 'name)
            max-concurrency: (.ref strategy 'max-concurrency)
            parallel-batch: selected-tasks
            deferred-tasks: deferred-tasks
            cas-skipped-ids: cas-skipped-ids
            subagents-spawned: 0
            llm-calls-used: 0)))))
