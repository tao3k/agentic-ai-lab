;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .o)
        (only-in :tao3k/agentic-ai-lab/modules/gitops/features/worktree/objects GitOpsWorktree.)
        (only-in "../../task-publication.ss" context-task-select-worktree! context-task-start!))
(export EnableContextWorktree)

(def WorktreeOrgContract.
  (.o family: "context.gitops.worktree"
      revision: "1"
      identity: (string-append family ".v" revision)))

(def WorktreeContext.
  (.o (:: @ GitOpsWorktree.) org-contract: WorktreeOrgContract. tasks: (.o) org: (.o)))

(def (EnableContextWorktree inherited)
  (.o (:: @ inherited)
      worktree-context: WorktreeContext.
      bind-worktree!: context-task-select-worktree!
      start-task!: context-task-start!))
