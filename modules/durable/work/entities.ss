;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure C4 POO Entity Prototypes for the Durable Work Engine Core:
;;; RepoNode -> WorktreeNode -> TaskNode -> SubTaskNode -> DetourNode.
;;; INVARIANT: ZERO orgize imports, ZERO ai-agentic-context imports.

(import (only-in :clan/poo/object .def .o)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/durable-dag
                 DurableGovernedStrategy.)
        "contracts.ss"
        "scheduler.ss")

(export RepoNode.
        WorktreeNode.
        TaskNode.
        SubTaskNode.
        DetourNode.
        BlockerDetourNode.
        SideQuestDetourNode.)

(def RepoNode.
  (.o (:: self)
      kind: 'agentic-ai-lab.durable.repo-node.v1
      repo-id: "repo-default"
      topology-path: "topology.org"
      index-path: "index.org"
      features: '(+funflow-dag +cas-resume +durable-agenda +auto-archive)
      policy: DurableWorkPolicy.
      strategy: DurableGovernedStrategy.
      .effective-rules: (lambda (rule-overrides)
                          (default-work-effective-rules self rule-overrides))
      .project-workbench-tabs: (lambda (task-records journal-state peek-set focused-task-id)
                                 (default-project-workbench-tabs self task-records journal-state
                                                                 peek-set focused-task-id))))

(def WorktreeNode.
  (.o worktree: "main"
      branch: "main"
      source-cut: "HEAD"
      grant-scope: 'worktree-local))

(def TaskNode.
  (.o (:: self)
      task-id: "task-default"
      artifact-path: #f
      org-path: #f
      scope-root-id: #f
      context-scope: #f
      restriction-envelope: #f
      trust-tier: 'verified
      .artifact-path: (default-work-artifact-path self)
      .funflow-dag: (lambda (snapshot)
                      (default-work-funflow-dag self snapshot))
      .orchestration-plan: (lambda (snapshot journal-state)
                             (default-work-orchestration-plan self snapshot journal-state))))

(def SubTaskNode.
  (.o (:: @ TaskNode.)
      node-id: #f
      needs: '()
      after-start: #f
      model-tier: 'builder
      disclosure-depth: 2))

(.def (DetourNode. @ SubTaskNode.)
  role: 'detour
  detour-kind: 'side-quest
  return-anchor: #f
  detour-depth: 1
  max-detour-depth: 2)

(.def (BlockerDetourNode. @ DetourNode.)
  detour-kind: 'blocker)

(.def (SideQuestDetourNode. @ DetourNode.)
  detour-kind: 'side-quest)
