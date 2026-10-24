;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: backend capability registry extraction for module-system projections.
;;; Invariant: catalog helpers read user module selections but never probe runtimes.

(import :yuanxu/module-system/selection/objects
        (only-in :agentic-ai-lab/modules/sandbox-core/profile-support/policy
                 agentic-ai-lab-sandbox-backend-capability-registry/sandbox-core
                 agentic-ai-lab-sandbox-backend-capability-registry-merge
                 agentic-ai-lab-sandbox-backend-capability-registry-ref
                 agentic-ai-lab-sandbox-backend-capability-registry?
                 agentic-ai-lab-sandbox-backend-capability-registries-validation))

(export agentic-ai-lab-user-module-selection-sandbox-backend-capability-registry
        agentic-ai-lab-user-config-sandbox-backend-capability-registries/add
        agentic-ai-lab-user-config-sandbox-backend-capability-registries
        agentic-ai-lab-user-config-sandbox-backend-capability-registry/add
        agentic-ai-lab-user-config-sandbox-backend-capability-registry
        agentic-ai-lab-user-config-sandbox-backend-capability-registry-validation
        agentic-ai-lab-user-config-sandbox-backend-capability)

;;; Backend modules own their capability contribution and attach it as an
;;; internal selection slot.  sandbox-core consumes the slot generically, so a
;;; new backend never requires a symbolic branch or import in this owner.
;; : (-> PooUserModuleSelection MaybePooSandboxBackendCapabilityRegistry)
(def (agentic-ai-lab-user-module-selection-sandbox-backend-capability-registry
      selection)
  (let (entry
        (yuanxu-user-module-selection-flag-entry
         selection
         ':backend-capability-registry))
    (and (pair? entry)
         (agentic-ai-lab-sandbox-backend-capability-registry? (cdr entry))
         (cdr entry))))

;;; Keep the contribution list as a first-class evidence surface so validation
;;; can report duplicate ids before registry merge overwrites later entries.
;; : (-> [PooUserModuleSelection] [PooSandboxBackendCapabilityRegistry])
(def (agentic-ai-lab-user-config-sandbox-backend-capability-registries/add selected)
  (cond
   ((null? selected) '())
   ((agentic-ai-lab-user-module-selection-sandbox-backend-capability-registry
     (car selected))
    => (lambda (registry)
         (cons registry
               (agentic-ai-lab-user-config-sandbox-backend-capability-registries/add
                (cdr selected)))))
   (else
    (agentic-ai-lab-user-config-sandbox-backend-capability-registries/add
     (cdr selected)))))

;; : (-> [PooUserModuleSelection] [PooSandboxBackendCapabilityRegistry])
(def (agentic-ai-lab-user-config-sandbox-backend-capability-registries selected)
  (cons agentic-ai-lab-sandbox-backend-capability-registry/sandbox-core
        (agentic-ai-lab-user-config-sandbox-backend-capability-registries/add
         selected)))

;;; Merge selected backend capability registries in declaration order. The base
;;; registry contributes only sandbox-core so disabled backend modules do not
;;; become part of the selected module-system registry.
;; : (-> PooSandboxBackendCapabilityRegistry [PooUserModuleSelection] PooSandboxBackendCapabilityRegistry)
(def (agentic-ai-lab-user-config-sandbox-backend-capability-registry/add registry
                                                                   selected)
  (cond
   ((null? selected) registry)
   ((agentic-ai-lab-user-module-selection-sandbox-backend-capability-registry
     (car selected))
    => (lambda (extension)
         (agentic-ai-lab-user-config-sandbox-backend-capability-registry/add
          (agentic-ai-lab-sandbox-backend-capability-registry-merge
           registry
           extension)
          (cdr selected))))
   (else
    (agentic-ai-lab-user-config-sandbox-backend-capability-registry/add
     registry
     (cdr selected)))))

;; : (-> [PooUserModuleSelection] PooSandboxBackendCapabilityRegistry)
(def (agentic-ai-lab-user-config-sandbox-backend-capability-registry selected)
  (agentic-ai-lab-user-config-sandbox-backend-capability-registry/add
   agentic-ai-lab-sandbox-backend-capability-registry/sandbox-core
   selected))

;; : (-> [PooUserModuleSelection] PooSandboxBackendCapabilityRegistryValidation)
(def (agentic-ai-lab-user-config-sandbox-backend-capability-registry-validation
      selected)
  (agentic-ai-lab-sandbox-backend-capability-registries-validation
   (agentic-ai-lab-user-config-sandbox-backend-capability-registries selected)))

;; : (-> [PooUserModuleSelection] Symbol PooSandboxBackendCapability)
(def (agentic-ai-lab-user-config-sandbox-backend-capability selected backend-kind)
  (agentic-ai-lab-sandbox-backend-capability-registry-ref
   (agentic-ai-lab-user-config-sandbox-backend-capability-registry selected)
   backend-kind))
