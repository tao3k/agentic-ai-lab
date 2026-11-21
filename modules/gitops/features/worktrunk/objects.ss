;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .cc .get .o)
        (only-in "../../dependency.ss" gitops-module-dependency))
(export GitOpsWorkTrunk. EnableGitOpsWorkTrunk)

(def GitOpsWorkTrunk. (.o project: #f worktrunk: #f revision: #f))

(def (EnableGitOpsWorkTrunk inherited)
  (def policy (.get inherited working-copy-policy))
  (def providers (.get policy allowed))
  (.o (:: @ inherited)
      working-copy-policy:
      (.cc policy
           allowed: (if (memq 'worktrunk providers) providers (append providers '(worktrunk)))
           preferred: 'worktrunk)
      worktrunk-prototype: GitOpsWorkTrunk.
      worktrunk-dependency: gitops-module-dependency))
