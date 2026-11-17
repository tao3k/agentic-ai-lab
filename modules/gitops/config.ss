;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .o) "objects.ss" "contracts.ss" "working-copy.ss")
(export GitOpsOperations)
(def GitOpsOperations
  (.o create-contract: GitOpsCreateContract
      working-copy-policy: GitOpsWorkingCopyPolicy
      bind-working-copy-policy: gitops-bind-working-copy-policy
      select-working-copy: gitops-select-working-copy
      working-copy-evidence: gitops-working-copy-evidence
      refresh-working-copy-evidence: gitops-refresh-working-copy-evidence
      admit-working-copy-receipt: gitops-admit-working-copy-receipt))
