;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .o .cc .ref)
        (only-in :tao3k/agentic-ai-lab/modules/gitops/features/worktrunk/objects GitOpsWorkTrunk.))
(export EnableContextWorkTrunk)

(def WorkTrunkContext. (.o (:: @ GitOpsWorkTrunk.) org: '()))

(def (EnableContextWorkTrunk inherited)
  (let* ((base (.ref inherited 'worktree-context))
         (contract (.ref base 'org-contract))
         (worktrunk-contract (.cc contract family: (string-append (.ref contract 'family) ".worktrunk"))))
    (.o (:: @ inherited)
        worktree-context: (.cc base org-contract: worktrunk-contract)
        worktrunk-context: WorkTrunkContext.)))
