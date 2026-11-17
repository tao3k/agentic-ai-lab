;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .cc)
        (only-in :clan/poo/type Object)
        (only-in :clan/poo/type Record)
        (only-in "../../dependency.ss" GitOpsModuleDependency GitOpsSelectionReader))
(export GitOpsWorktreeDependency GitOpsWorktreeScope)

(def GitOpsWorktreeDependency (.cc GitOpsModuleDependency identity: 'gitops/worktree-dependency))
(def GitOpsWorktreeScope
  (.cc (Record worktree-prototype: [Object] worktree-dependency: [GitOpsSelectionReader])
       identity: 'gitops/worktree-scope))
