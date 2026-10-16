;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: project a pure Core ProfileBundle into a POO Flow Scenario Case.

(import (only-in :clan/poo/object .o .ref)
        (only-in :core/profile-composition/profile-bundle
                 poo-flow-profile-bundle?)
        (only-in :poo-flow/modules/workflow/scenario/case
                 poo-flow-scenario-case))

(export poo-flow-profile-bundle-root)

(def (poo-flow-profile-bundle-root name bundle)
  (unless (and (symbol? name) (poo-flow-profile-bundle? bundle))
    (error "composition root requires a name and ProfileBundle" name bundle))
  (let (case-value
        (poo-flow-scenario-case
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
