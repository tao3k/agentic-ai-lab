;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: backend capability registry extraction for module-system projections.
;;; Invariant: catalog helpers read user module selections but never probe runtimes.

(import :core/module-system/selection/objects
        (only-in :poo-flow/modules/sandbox-core/profile-support/policy
                 poo-flow-sandbox-backend-capability-registry/sandbox-core
                 poo-flow-sandbox-backend-capability-registry-merge
                 poo-flow-sandbox-backend-capability-registry-ref
                 poo-flow-sandbox-backend-capability-registry?
                 poo-flow-sandbox-backend-capability-registries-validation))

(export poo-flow-user-module-selection-sandbox-backend-capability-registry
        poo-flow-user-config-sandbox-backend-capability-registries/add
        poo-flow-user-config-sandbox-backend-capability-registries
        poo-flow-user-config-sandbox-backend-capability-registry/add
        poo-flow-user-config-sandbox-backend-capability-registry
        poo-flow-user-config-sandbox-backend-capability-registry-validation
        poo-flow-user-config-sandbox-backend-capability)

;;; Backend modules own their capability contribution and attach it as an
;;; internal selection slot.  sandbox-core consumes the slot generically, so a
;;; new backend never requires a symbolic branch or import in this owner.
;; : (-> PooUserModuleSelection MaybePooSandboxBackendCapabilityRegistry)
(def (poo-flow-user-module-selection-sandbox-backend-capability-registry
      selection)
  (let (entry
        (poo-flow-user-module-selection-flag-entry
         selection
         ':backend-capability-registry))
    (and (pair? entry)
         (poo-flow-sandbox-backend-capability-registry? (cdr entry))
         (cdr entry))))

;;; Keep the contribution list as a first-class evidence surface so validation
;;; can report duplicate ids before registry merge overwrites later entries.
;; : (-> [PooUserModuleSelection] [PooSandboxBackendCapabilityRegistry])
(def (poo-flow-user-config-sandbox-backend-capability-registries/add selected)
  (cond
   ((null? selected) '())
   ((poo-flow-user-module-selection-sandbox-backend-capability-registry
     (car selected))
    => (lambda (registry)
         (cons registry
               (poo-flow-user-config-sandbox-backend-capability-registries/add
                (cdr selected)))))
   (else
    (poo-flow-user-config-sandbox-backend-capability-registries/add
     (cdr selected)))))

;; : (-> [PooUserModuleSelection] [PooSandboxBackendCapabilityRegistry])
(def (poo-flow-user-config-sandbox-backend-capability-registries selected)
  (cons poo-flow-sandbox-backend-capability-registry/sandbox-core
        (poo-flow-user-config-sandbox-backend-capability-registries/add
         selected)))

;;; Merge selected backend capability registries in declaration order. The base
;;; registry contributes only sandbox-core so disabled backend modules do not
;;; become part of the selected module-system registry.
;; : (-> PooSandboxBackendCapabilityRegistry [PooUserModuleSelection] PooSandboxBackendCapabilityRegistry)
(def (poo-flow-user-config-sandbox-backend-capability-registry/add registry
                                                                   selected)
  (cond
   ((null? selected) registry)
   ((poo-flow-user-module-selection-sandbox-backend-capability-registry
     (car selected))
    => (lambda (extension)
         (poo-flow-user-config-sandbox-backend-capability-registry/add
          (poo-flow-sandbox-backend-capability-registry-merge
           registry
           extension)
          (cdr selected))))
   (else
    (poo-flow-user-config-sandbox-backend-capability-registry/add
     registry
     (cdr selected)))))

;; : (-> [PooUserModuleSelection] PooSandboxBackendCapabilityRegistry)
(def (poo-flow-user-config-sandbox-backend-capability-registry selected)
  (poo-flow-user-config-sandbox-backend-capability-registry/add
   poo-flow-sandbox-backend-capability-registry/sandbox-core
   selected))

;; : (-> [PooUserModuleSelection] PooSandboxBackendCapabilityRegistryValidation)
(def (poo-flow-user-config-sandbox-backend-capability-registry-validation
      selected)
  (poo-flow-sandbox-backend-capability-registries-validation
   (poo-flow-user-config-sandbox-backend-capability-registries selected)))

;; : (-> [PooUserModuleSelection] Symbol PooSandboxBackendCapability)
(def (poo-flow-user-config-sandbox-backend-capability selected backend-kind)
  (poo-flow-sandbox-backend-capability-registry-ref
   (poo-flow-user-config-sandbox-backend-capability-registry selected)
   backend-kind))
