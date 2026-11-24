;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Thin Public Facade for the Modularized Durable Task Orchestrator Subsystem:
;;; - orchestrator/contracts.ss       (POO ObjectContracts, .new/checked, MOP generics)
;;; - orchestrator/org-projection.ss  (Org Elements, Plan-A index.org, WorkbenchTabProjection)
;;; - orchestrator/ascent-planner.ss  (ASCENT 4-predicate scheduler, C4 prototypes, WAL journal)
;;; - orchestrator/detour-engine.ss   (Scoped Detours, CLOS 4-exit reconciler, OrgOverlay(g), re-anchor)
;;; - orchestrator/shared-claims.ss   (Zero-SubAgent `:ID:` ownership, Extend-Never-Overwrite, handover)

(import (only-in :clan/poo/object .o)
        "orchestrator/contracts.ss"
        "orchestrator/org-projection.ss"
        "orchestrator/ascent-planner.ss"
        "orchestrator/detour-engine.ss"
        "orchestrator/shared-claims.ss")

(export (import: "orchestrator/contracts.ss")
        (import: "orchestrator/ascent-planner.ss")
        (import: "orchestrator/detour-engine.ss")
        (import: "orchestrator/shared-claims.ss")
        DurableOrchestratorExports)

(def DurableOrchestratorExports
  (.o bind-these: #f
      DurableTaskPolicyContract: DurableTaskPolicyContract
      SharedContextClaimContract: SharedContextClaimContract
      DetourReconcileContract: DetourReconcileContract
      make-checked-task-policy: make-checked-task-policy
      make-checked-shared-claim: make-checked-shared-claim
      DurableTaskPolicy: DurableTaskPolicy.
      RepoNode: RepoNode.
      WorktreeNode: WorktreeNode.
      TaskNode: TaskNode.
      SubTaskNode: SubTaskNode.
      DetourNode: DetourNode.
      BlockerDetourNode: BlockerDetourNode.
      SideQuestDetourNode: SideQuestDetourNode.
      DetourExitState: DetourExitState.
      CompletedExit: CompletedExit.
      ParkedExit: ParkedExit.
      CancelledExit: CancelledExit.
      PromotedToTaskExit: PromotedToTaskExit.
      AnchorKind: AnchorKind.
      MainlineStepAnchor: MainlineStepAnchor.
      InvariantGateAnchor: InvariantGateAnchor.
      reconcile-detour-exit: durable-reconcile-detour-exit
      apply-org-overlay: task-apply-org-overlay
      reanchor-mainline: task-reanchor-mainline
      perceive-claims: shared-context-perceive-claims
      assert-write-owner: shared-context-assert-write-owner
      claim!: shared-context-claim!
      extend!: shared-context-extend!
      handover!: shared-context-handover!
      node-effective-rules: node-effective-rules
      task-artifact-path: task-artifact-path
      task-funflow-dag: task-funflow-dag
      task-orchestration-plan: task-orchestration-plan
      task-archive-transition: task-archive-transition
      project-workbench-tabs: project-workbench-tabs
      record-cas!: durable-orchestrator-record-cas!
      completed-cas: durable-orchestrator-completed-cas
      commit-archive!: durable-orchestrator-commit-archive!
      reopen!: durable-orchestrator-reopen!
      recover: durable-orchestrator-recover))
