;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Agentic AI Lab resolution admission and Task/Flow activation lowering.
;;; Invariant: Core Catalog matches existing values by SourceRef.
;;; It never evaluates, imports, or opens the source ref payload.
;;; Intent: agents can trust resolver receipts as replayable evidence of selection order.
;;; Ownership: Core owns Catalog lookup; this adapter owns typed failure,
;;; Doctor handoff, activation snapshots, and RunConfig lowering.
;;; Activation receives descriptors that were already constructed by descriptor owners.
;;; The resolver may report missing sources, but it must not try to load them.
;;; Run-config lowering is the only place this owner touches core config values.
;;; Parser policy should treat this file as the resolver/activation owner.

(import :yuanxu/modules/funflow/control-plane/failure
        :yuanxu/modules/funflow/control-plane/task
        :yuanxu/modules/funflow/control-plane/flow
        :yuanxu/modules/funflow/control-plane/config
        :yuanxu/module-system/source/imports
        :yuanxu/module-system/source/objects
        :agentic-ai-lab/modules/module-authoring/module-descriptor
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-diagnostics
        :yuanxu/module-system/catalog/objects
        (only-in :yuanxu/object-family/syntax
                 defpoo-object-family)
        :yuanxu/utilities/final-projection-syntax)

(export resolve-agentic-ai-lab-module-source
        resolve-agentic-ai-lab-module-sources
        agentic-ai-lab-module-resolve-doctor
        agentic-ai-lab-module-resolve-and-activate
        agentic-ai-lab-module-resolve-and-activate-with-base
        agentic-ai-lab-module-activation-prototype
        make-agentic-ai-lab-module-activation
        agentic-ai-lab-module-activation?
        agentic-ai-lab-module-activation-modules
        agentic-ai-lab-module-activation-task-registry
        agentic-ai-lab-module-activation-flow-registry
        agentic-ai-lab-module-activation-options
        activate-agentic-ai-lab-modules
        activate-agentic-ai-lab-modules-with-base
        agentic-ai-lab-module-activation->run-config)

;;; Boundary: missing catalog source is a typed config failure, not a loader miss.
;; : (-> PooModuleCatalog PooModuleSourceRef PooModuleDescriptor)
(def (resolve-agentic-ai-lab-module-source catalog source-ref)
  (let (module (resolve-yuanxu-module-source/default catalog source-ref #f))
    (if module
      module
      (raise-control-plane-failure
       'module-system
       'missing-module-source
       "agentic-ai-lab module source was not found in catalog"
       (yuanxu-product-field-rows
        (catalog (yuanxu-module-catalog-name catalog))
        (source (yuanxu-module-source-ref->alist source-ref)))))))

;;; Boundary: multi-source resolution preserves requested source order.
;; : (-> PooModuleCatalog [PooModuleSourceRef] [PooModuleDescriptor])
(def (resolve-agentic-ai-lab-module-sources catalog source-refs)
  (if (null? source-refs)
    '()
    (cons (resolve-agentic-ai-lab-module-source catalog (car source-refs))
          (resolve-agentic-ai-lab-module-sources catalog (cdr source-refs)))))

;;; Boundary: resolve-doctor validates source selection before activation.
;; : (-> PooModuleCatalog [PooModuleSourceRef] PooModuleDoctorReport)
(def (agentic-ai-lab-module-resolve-doctor catalog source-refs)
  (agentic-ai-lab-module-doctor
   (resolve-agentic-ai-lab-module-sources catalog source-refs)))

;;; Boundary: base activation allows callers to preserve existing registries.
;; : (-> PooModuleCatalog [PooModuleSourceRef] TaskFamilyRegistry FlowDeclarationRegistry ModuleOptionAlist PooModuleActivation)
(def (agentic-ai-lab-module-resolve-and-activate-with-base catalog source-refs base-task-registry base-flow-registry base-options)
  (activate-agentic-ai-lab-modules-with-base
   (resolve-agentic-ai-lab-module-sources catalog source-refs)
   base-task-registry
   base-flow-registry
   base-options))

;;; Boundary: source-selected activation uses the same activation path as direct modules.
;; : (-> PooModuleCatalog [PooModuleSourceRef] PooModuleActivation)
(def (agentic-ai-lab-module-resolve-and-activate catalog source-refs)
  (activate-agentic-ai-lab-modules
   (resolve-agentic-ai-lab-module-sources catalog source-refs)))

;;; Boundary: activation appends descriptor contributions without mutation.
;; : (-> [PooModuleDescriptor] TaskFamilyRegistry FlowDeclarationRegistry ModuleOptionAlist PooModuleActivation)
(defpoo-object-family
  (prototype agentic-ai-lab-module-activation-prototype
             activation?
             agentic-ai-lab-module-activation?)
  (constructor make-agentic-ai-lab-module-activation
               (modules-value modules)
               (task-registry-value task-registry)
               (flow-registry-value flow-registry)
               (options-value options))
  (accessors
   (agentic-ai-lab-module-activation-modules modules)
   (agentic-ai-lab-module-activation-task-registry task-registry)
   (agentic-ai-lab-module-activation-flow-registry flow-registry)
   (agentic-ai-lab-module-activation-options options))
  (projections))

;;; Boundary: activation validates closure then appends base-first registries.
;;; Intent: runtime-visible registries are deterministic snapshots of module data.
;; : (-> [PooModuleDescriptor] TaskFamilyRegistry FlowDeclarationRegistry ModuleOptionAlist PooModuleActivation)
(def (activate-agentic-ai-lab-modules-with-base modules base-task-registry base-flow-registry base-options)
  (let (closed-modules (agentic-ai-lab-module-closure modules))
    ;; Import validation must see the same closure that registry aggregation uses.
    (validate-yuanxu-module-imports closed-modules)
    (make-agentic-ai-lab-module-activation
     closed-modules
     (make-task-family-registry
      (task-family-registry-name base-task-registry)
      ;; Base descriptors stay first so existing lookup behavior is preserved.
      (append (task-family-registry-descriptors base-task-registry)
              (agentic-ai-lab-module-all-task-descriptors closed-modules)))
     (make-flow-declaration-registry
      (flow-declaration-registry-name base-flow-registry)
      (append (flow-declaration-registry-descriptors base-flow-registry)
             (agentic-ai-lab-module-all-flow-descriptors closed-modules)))
     (append base-options
             (agentic-ai-lab-module-all-options closed-modules)
             (list (cons 'agentic-ai-lab-modules
                         (agentic-ai-lab-module-names closed-modules)))))))

;;; Boundary: default activation uses project default task and flow registries.
;; : (-> [PooModuleDescriptor] PooModuleActivation)
(def (activate-agentic-ai-lab-modules modules)
  (activate-agentic-ai-lab-modules-with-base
   modules
   default-task-family-registry
   default-flow-declaration-registry
   '()))

;;; Boundary: run-config lowering keeps modules outside runner internals.
;; : (-> Symbol Strategy RuntimeAdapter PooModuleActivation RunConfig)
(def (agentic-ai-lab-module-activation->run-config name strategy adapter activation)
  (make-run-config name
                   strategy
                   adapter
                   (agentic-ai-lab-module-activation-options activation)
                   (agentic-ai-lab-module-activation-task-registry activation)
                   (agentic-ai-lab-module-activation-flow-registry activation)))
