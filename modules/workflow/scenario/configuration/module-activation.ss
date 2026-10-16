;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO Flow resolution admission and Task/Flow activation lowering.
;;; Invariant: Core Catalog matches existing values by SourceRef.
;;; It never evaluates, imports, or opens the source ref payload.
;;; Intent: agents can trust resolver receipts as replayable evidence of selection order.
;;; Ownership: Core owns Catalog lookup; this adapter owns typed failure,
;;; Doctor handoff, activation snapshots, and RunConfig lowering.
;;; Activation receives descriptors that were already constructed by descriptor owners.
;;; The resolver may report missing sources, but it must not try to load them.
;;; Run-config lowering is the only place this owner touches core config values.
;;; Parser policy should treat this file as the resolver/activation owner.

(import :poo-flow/modules/workflow/control-plane/failure
        :poo-flow/modules/workflow/control-plane/task
        :poo-flow/modules/workflow/control-plane/flow
        :poo-flow/modules/workflow/control-plane/config
        :core/module-system/source/imports
        :core/module-system/source/objects
        :poo-flow/modules/module-authoring/module-descriptor
        :poo-flow/modules/workflow/scenario/configuration/module-diagnostics
        :core/module-system/catalog/objects
        (only-in :core/object-family/syntax
                 defpoo-object-family)
        :core/utilities/final-projection-syntax)

(export resolve-poo-flow-module-source
        resolve-poo-flow-module-sources
        poo-flow-module-resolve-doctor
        poo-flow-module-resolve-and-activate
        poo-flow-module-resolve-and-activate-with-base
        poo-flow-module-activation-prototype
        make-poo-flow-module-activation
        poo-flow-module-activation?
        poo-flow-module-activation-modules
        poo-flow-module-activation-task-registry
        poo-flow-module-activation-flow-registry
        poo-flow-module-activation-options
        activate-poo-flow-modules
        activate-poo-flow-modules-with-base
        poo-flow-module-activation->run-config)

;;; Boundary: missing catalog source is a typed config failure, not a loader miss.
;; : (-> PooModuleCatalog PooModuleSourceRef PooModuleDescriptor)
(def (resolve-poo-flow-module-source catalog source-ref)
  (let (module (resolve-poo-flow-module-source/default catalog source-ref #f))
    (if module
      module
      (raise-control-plane-failure
       'module-system
       'missing-module-source
       "poo-flow module source was not found in catalog"
       (poo-flow-product-field-rows
        (catalog (poo-flow-module-catalog-name catalog))
        (source (poo-flow-module-source-ref->alist source-ref)))))))

;;; Boundary: multi-source resolution preserves requested source order.
;; : (-> PooModuleCatalog [PooModuleSourceRef] [PooModuleDescriptor])
(def (resolve-poo-flow-module-sources catalog source-refs)
  (if (null? source-refs)
    '()
    (cons (resolve-poo-flow-module-source catalog (car source-refs))
          (resolve-poo-flow-module-sources catalog (cdr source-refs)))))

;;; Boundary: resolve-doctor validates source selection before activation.
;; : (-> PooModuleCatalog [PooModuleSourceRef] PooModuleDoctorReport)
(def (poo-flow-module-resolve-doctor catalog source-refs)
  (poo-flow-module-doctor
   (resolve-poo-flow-module-sources catalog source-refs)))

;;; Boundary: base activation allows callers to preserve existing registries.
;; : (-> PooModuleCatalog [PooModuleSourceRef] TaskFamilyRegistry FlowDeclarationRegistry ModuleOptionAlist PooModuleActivation)
(def (poo-flow-module-resolve-and-activate-with-base catalog source-refs base-task-registry base-flow-registry base-options)
  (activate-poo-flow-modules-with-base
   (resolve-poo-flow-module-sources catalog source-refs)
   base-task-registry
   base-flow-registry
   base-options))

;;; Boundary: source-selected activation uses the same activation path as direct modules.
;; : (-> PooModuleCatalog [PooModuleSourceRef] PooModuleActivation)
(def (poo-flow-module-resolve-and-activate catalog source-refs)
  (activate-poo-flow-modules
   (resolve-poo-flow-module-sources catalog source-refs)))

;;; Boundary: activation appends descriptor contributions without mutation.
;; : (-> [PooModuleDescriptor] TaskFamilyRegistry FlowDeclarationRegistry ModuleOptionAlist PooModuleActivation)
(defpoo-object-family
  (prototype poo-flow-module-activation-prototype
             activation?
             poo-flow-module-activation?)
  (constructor make-poo-flow-module-activation
               (modules-value modules)
               (task-registry-value task-registry)
               (flow-registry-value flow-registry)
               (options-value options))
  (accessors
   (poo-flow-module-activation-modules modules)
   (poo-flow-module-activation-task-registry task-registry)
   (poo-flow-module-activation-flow-registry flow-registry)
   (poo-flow-module-activation-options options))
  (projections))

;;; Boundary: activation validates closure then appends base-first registries.
;;; Intent: runtime-visible registries are deterministic snapshots of module data.
;; : (-> [PooModuleDescriptor] TaskFamilyRegistry FlowDeclarationRegistry ModuleOptionAlist PooModuleActivation)
(def (activate-poo-flow-modules-with-base modules base-task-registry base-flow-registry base-options)
  (let (closed-modules (poo-flow-module-closure modules))
    ;; Import validation must see the same closure that registry aggregation uses.
    (validate-poo-flow-module-imports closed-modules)
    (make-poo-flow-module-activation
     closed-modules
     (make-task-family-registry
      (task-family-registry-name base-task-registry)
      ;; Base descriptors stay first so existing lookup behavior is preserved.
      (append (task-family-registry-descriptors base-task-registry)
              (poo-flow-module-all-task-descriptors closed-modules)))
     (make-flow-declaration-registry
      (flow-declaration-registry-name base-flow-registry)
      (append (flow-declaration-registry-descriptors base-flow-registry)
             (poo-flow-module-all-flow-descriptors closed-modules)))
     (append base-options
             (poo-flow-module-all-options closed-modules)
             (list (cons 'poo-flow-modules
                         (poo-flow-module-names closed-modules)))))))

;;; Boundary: default activation uses project default task and flow registries.
;; : (-> [PooModuleDescriptor] PooModuleActivation)
(def (activate-poo-flow-modules modules)
  (activate-poo-flow-modules-with-base
   modules
   default-task-family-registry
   default-flow-declaration-registry
   '()))

;;; Boundary: run-config lowering keeps modules outside runner internals.
;; : (-> Symbol Strategy RuntimeAdapter PooModuleActivation RunConfig)
(def (poo-flow-module-activation->run-config name strategy adapter activation)
  (make-run-config name
                   strategy
                   adapter
                   (poo-flow-module-activation-options activation)
                   (poo-flow-module-activation-task-registry activation)
                   (poo-flow-module-activation-flow-registry activation)))
