;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure Durable Work Engine Core Public Facade (ZERO orgize / ZERO Context).
;;; Carrier adapters (such as `+org`) attach via Yuanxu's Feature System under
;;; `modules/durable/features/`.

(import (only-in :clan/poo/object .o)
        "work/contracts.ss"
        "work/scheduler.ss"
        "work/entities.ss"
        "work/detour-engine.ss"
        "work/claims-engine.ss")

(export (import: "work/contracts.ss")
        (import: "work/scheduler.ss")
        (import: "work/entities.ss")
        (import: "work/detour-engine.ss")
        (import: "work/claims-engine.ss")
        DurableWorkExports)

(def DurableWorkExports
  (.o bind-these: #f
      DurableWorkPolicyContract: DurableWorkPolicyContract
      WorkClaimContract: WorkClaimContract
      WorkSnapshotContract: WorkSnapshotContract
      DetourReconcileContract: DetourReconcileContract
      DurableWorkPolicy: DurableWorkPolicy.
      make-checked-work-policy: make-checked-work-policy
      make-checked-work-claim: make-checked-work-claim
      make-checked-work-snapshot: make-checked-work-snapshot
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
      apply-overlay: work-apply-overlay
      reanchor-mainline: work-reanchor-mainline
      find-claim: work-find-claim
      assert-write-owner: work-assert-write-owner
      claim!: work-claim!
      extend!: work-extend!
      handover!: work-handover!
      work-effective-rules: work-effective-rules
      work-artifact-path: work-artifact-path
      work-funflow-dag: work-funflow-dag
      work-orchestration-plan: work-orchestration-plan
      project-workbench-tabs: project-workbench-tabs
      record-cas!: durable-work-record-cas!
      completed-cas: durable-work-completed-cas
      commit-archive!: durable-work-commit-archive!
      reopen!: durable-work-reopen!
      recover: durable-work-recover))
