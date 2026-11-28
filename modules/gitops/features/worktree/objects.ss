;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .o)
        (only-in "../../dependency.ss" gitops-module-dependency))
(export GitOpsWorktree. gitops-worktree-dependency EnableGitOpsWorktree)

(def GitOpsWorktree.
  (.o project: #f worktree: #f source-cut: #f))

(def gitops-worktree-dependency gitops-module-dependency)

(def (EnableGitOpsWorktree inherited)
  (.o (:: @ inherited)
      worktree-prototype: GitOpsWorktree.
      worktree-dependency: gitops-worktree-dependency))
