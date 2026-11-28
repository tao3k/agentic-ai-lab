;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .o)
        (only-in "../../dependency.ss" gitops-module-dependency))
(export GitOpsWork. EnableGitOpsWork)

(def GitOpsWork. (.o project: #f work: #f revision: #f))

(def (EnableGitOpsWork inherited)
  (.o (:: @ inherited)
      work-prototype: GitOpsWork.
      work-dependency: gitops-module-dependency))
