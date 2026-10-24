;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: project a pure Core ProfileBundle into a Agentic AI Lab Scenario Case.

(import (only-in :clan/poo/object .o .ref)
        (only-in :yuanxu/profile-composition/profile-bundle
                 yuanxu-profile-bundle?)
        (only-in :agentic-ai-lab/modules/workflow/scenario/case
                 agentic-ai-lab-scenario-case))

(export agentic-ai-lab-profile-bundle-root)

(def (agentic-ai-lab-profile-bundle-root name bundle)
  (unless (and (symbol? name) (yuanxu-profile-bundle? bundle))
    (error "composition root requires a name and ProfileBundle" name bundle))
  (let (case-value
        (agentic-ai-lab-scenario-case
         name
         (.ref bundle 'module-bindings)
         (.ref bundle 'profiles)
         (.ref bundle 'stages)
         (.ref bundle 'profile-bindings)))
    (.o (:: @ case-value)
        profile-bundle: bundle
        imports: (.ref bundle 'imports)
        capabilities: (.ref bundle 'capabilities)
        selection-proofs: (.ref bundle 'selection-proofs)
        provenance: (.ref bundle 'provenance)
        runtime-executed?: #f)))
