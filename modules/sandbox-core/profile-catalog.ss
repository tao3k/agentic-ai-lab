;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox profile catalog extraction for module-system projections.
;;; Invariant: catalog helpers read user module selections but never resolve runtimes.

(import (only-in :poo-flow/modules/agent-sandbox/config
                 poo-flow-default-sandbox-profiles
                 poo-flow-sandbox-profile?)
        :core/module-system/selection/objects)

(export poo-flow-user-module-selection-sandbox-profiles
        poo-flow-sandbox-profile-catalog-defaults
        poo-flow-user-config-sandbox-profile-catalog)

;;; Catalog defaults are owned by this facade so inlined catalog helpers do not
;;; leak imported agent-sandbox/config identifiers into callers.
;; : [PooSandboxProfile]
(def poo-flow-sandbox-profile-catalog-defaults
  poo-flow-default-sandbox-profiles)

;;; Config rows may mix profile objects with other declarations. Filtering keeps
;;; only validated POO sandbox profiles for downstream runtime handoff catalogs.
;; : (-> [Value] [PooSandboxProfile])
(def (poo-flow-user-module-selection-sandbox-profiles/filter values)
  (cond
   ((null? values) '())
   ((poo-flow-sandbox-profile? (car values))
    (cons (car values)
          (poo-flow-user-module-selection-sandbox-profiles/filter
           (cdr values))))
   (else
    (poo-flow-user-module-selection-sandbox-profiles/filter (cdr values)))))

;;; Boundary: user module selection sandbox profiles is the policy-visible edge
;;; for sandbox, module-system behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> PooUserModuleSelection [PooSandboxProfile])
(def (poo-flow-user-module-selection-sandbox-profiles selection)
  (let (entry (poo-flow-user-module-selection-flag-entry selection ':config))
    (if (and entry (pair? entry))
      (poo-flow-user-module-selection-sandbox-profiles/filter (cdr entry))
      '())))

;;; Boundary: user config sandbox profile catalog add is the policy-visible
;;; edge for sandbox, module-system behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> [PooUserModuleSelection] [PooSandboxProfile])
(def (poo-flow-user-config-sandbox-profile-catalog/add selected-modules)
  (cond
   ((null? selected-modules) '())
   (else
    (append
     (poo-flow-user-module-selection-sandbox-profiles (car selected-modules))
     (poo-flow-user-config-sandbox-profile-catalog/add
      (cdr selected-modules))))))

;;; The catalog includes selected module config first, then upstream defaults.
;;; This lets project/session profiles override names while keeping built-ins
;;; available for simple loop-engine profile refs.
;; : (-> [PooUserModuleSelection] [PooSandboxProfile])
(def (poo-flow-user-config-sandbox-profile-catalog selected-modules)
  (append (poo-flow-user-config-sandbox-profile-catalog/add selected-modules)
          poo-flow-sandbox-profile-catalog-defaults))
