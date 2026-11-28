;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def .o)
        "types.ss" "config.ss"
        (rename-in (only-in "./features/worktree/interface.ss" Feature) (Feature WorktreeFeature))
        (rename-in (only-in "./features/work/interface.ss" Feature) (Feature WorkFeature))
        (rename-in (only-in "./features/worktrunk/interface.ss" Feature) (Feature WorktrunkFeature)))
(export GitOps)

(.def GitOps
  identity: 'gitops
  tags: '(software-engineering policy)
  core: (.o scope-contract: GitOpsScopeContract exports: GitOpsOperations)
  features: (.o worktree: WorktreeFeature
                work: WorkFeature
                worktrunk: WorktrunkFeature))
