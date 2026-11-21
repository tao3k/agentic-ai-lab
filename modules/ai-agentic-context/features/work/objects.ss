;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .o)
        (only-in :tao3k/agentic-ai-lab/modules/gitops/features/work/objects GitOpsWork.))
(export EnableContextWork)

(def WorkContext. (.o (:: @ GitOpsWork.) org: '()))

(def (EnableContextWork inherited)
  (.o (:: @ inherited) work-context: WorkContext.))
