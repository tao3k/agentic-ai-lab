;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .o .get .ref .slot?))
(export GitOpsWorkingCopyPolicy gitops-provider-available?)

(def (gitops-provider-available? availability provider)
  (and (.slot? availability provider)
       (eq? (.ref availability provider) #t)))

(def (gitops-default-working-copy-provider policy availability)
  (def allowed (.get policy allowed))
  (def preferred (.get policy preferred))
  (def (available? provider) (gitops-provider-available? availability provider))
  (if (and (memq preferred allowed) (available? preferred))
    preferred
    (find available? allowed)))

(def GitOpsWorkingCopyPolicy
  (.o select-provider: gitops-default-working-copy-provider
      allowed: '(git-worktree)
      preferred: 'git-worktree
      source: #f
      anchor: #f
      revision: #f))
