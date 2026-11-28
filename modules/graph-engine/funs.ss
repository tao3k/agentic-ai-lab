;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: 100% pure GraphEngine functional combinators & POO export bundle.
;;; Follows Style 01/02 (`(slot)` constant capture in `GraphEngineExports.`,
;;; eliminating redundant `graph-*` aliases while preserving the 3 legacy test
;;; names). ZERO SQLite imports — Turso/SQLite WAL lives in `+sqlite-turso`.

(import (only-in :clan/poo/object .def .o)
        "obligation-graph.ss"
        "ascent-reconciler.ss"
        "dag-frontier-scheduler.ss"
        "synthesis-oracle.ss"
        "durable-event-bridge.ss"
        "delegation-fence.ss"
        "convergent-tree.ss"
        "journal-handoff.ss"
        "governed-context-bridge.ss"
        "cyclic-subgraph.ss"
        "task-actor.ss"
        "marlin-handoff.ss"
        "atomic-effect-orchestrator.ss"
        "unified-effect-driver.ss"
        "fleet-orchestrator.ss")

(export GraphEngineExports.
        (import: "ascent-reconciler.ss")
        (import: "synthesis-oracle.ss")
        (import: "durable-event-bridge.ss")
        (import: "atomic-effect-orchestrator.ss")
        (import: "unified-effect-driver.ss")
        (import: "fleet-orchestrator.ss")
        graph-make-task-actor
        graph-enter-task-actor-detour
        graph-exit-task-actor-detour)

(def graph-make-task-actor make-task-actor)
(def graph-enter-task-actor-detour enter-task-actor-detour)
(def graph-exit-task-actor-detour exit-task-actor-detour)

;;; Idiomatic POO constant-slot export bundle (`(slot)` / `(slot := expr)`).
(.def GraphEngineExports.
  (library := 'tao3k/agentic-ai-lab/modules/graph-engine/interface)
  (obligation-graph := ObligationGraph.)
  (frontier-plan := FunflowFrontierPlan.)
  (context-trunk := ContextTrunk.)
  (task-actor := TaskActor.)
  (steering-message := SteeringMessage.)
  (task-actor-index := TaskActorIndex.)
  (marlin-dispatch := MarlinDispatchEnvelope.)
  (marlin-receipt := MarlinExecutionReceipt.)
  (reconcile-frontier := ascent-reconcile-frontier)
  (plan-funflow-c4-frontier)
  (reconcile-to-fixed-point)
  (reconcile-event-stream)
  (work-snapshot->obligation-graph)
  (attenuate-delegation-envelope)
  (admit-delegated-execution-fence)
  (make-context-trunk)
  (spawn-trunk-branch)
  (execute-branch-funflow-dag)
  (absorb-branch-contribution)
  (converge-trunk-to-apex)
  (plan-trunk-journal-handoff)
  (project-recovered-trunk-receipt)
  (make-graph-cedar-handoff)
  (admit-graph-nono-sandbox)
  (make-governed-context-trunk)
  (governed-trunk->marlin-capsule-vector := governed-trunk-bundle->marlin-capsule-vector)
  (condense-graph-sccs)
  (execute-unified-graph)
  (make-task-actor)
  (make-open-focus-actor)
  (promote-focus->task-actor)
  (make-steering-message)
  (steer-task-actor)
  (complete-anchored-branch)
  (can-continue-trunk-at-join?)
  (make-task-actor-index)
  (admit-task-actor-scope-access)
  (settle-task-actor)
  (enter-task-actor-detour)
  (exit-task-actor-detour)
  (lookup-task-actor-by-id)
  (project-task-actors->workbench-tabs)
  (validate-marlin-dispatch := validate-graph-marlin-dispatch)
  (make-marlin-dispatch := make-graph-marlin-dispatch)
  (marlin-dispatch->alist := graph-marlin-dispatch->alist)
  (marlin-dispatch->c-abi-vector := graph-marlin-dispatch->c-abi-vector)
  (make-marlin-receipt := make-marlin-execution-receipt)
  (reconcile-marlin-receipt := reconcile-marlin-execution-receipt)
  (make-cas-hit-receipt)
  (make-cas-miss-receipt)
  (make-cas-stored-receipt)
  (make-llm-completed-receipt)
  (make-sandbox-exited-receipt)
  (make-effect-error-receipt)
  (compute-funflow-cas-key)
  (plan-funflow-step-effects)
  (reconcile-funflow-step-receipts)
  (make-competing-hypothesis)
  (make-hypothesis-branch-proposal)
  (plan-competing-hypothesis-frontier)
  (reconcile-competing-hypothesis-matrix)
  (make-unified-driver-state)
  (drive-graph-actor-step)
  (run-unified-driver-to-quiescence)
  (project-driver-state->workbench-projection)
  (make-graph-fleet-state)
  (fleet-spawn-sibling-from-detour)
  (fleet-apply-bitemporal-event)
  (fleet-propose-hypothesis-branch)
  (fleet-propagate-shared-defeater)
  (fleet-peek-archived-actor)
  (fleet-unpeek-archived-actor)
  (fleet-reopen-archived-actor)
  (fleet-export-audit-capsule)
  (step-graph-fleet)
  (run-graph-fleet-to-quiescence)
  (fleet->inert-snapshot)
  (inert-snapshot->fleet)
  (fleet->wire-string)
  (wire-string->fleet)
  (plan-fleet-cas-checkpoint)
  (restore-fleet-from-cas-receipt)
  (project-fleet->workbench-projection))
