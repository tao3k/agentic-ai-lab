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

(import (only-in :clan/poo/object .get)
        :yuanxu/modules/funflow/control-plane/failure
        :yuanxu/modules/funflow/control-plane/task
        :yuanxu/modules/funflow/control-plane/flow
        :yuanxu/modules/funflow/control-plane/config
        :yuanxu/module-system/source/imports
        :yuanxu/module-system/source/objects
        :agentic-ai-lab/modules/module-authoring/module-descriptor
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-diagnostics
        :yuanxu/module-system/catalog/objects
        (prefix-in "./module-composition.ss" composition.)
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
        (catalog (.get catalog name))
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

;;; Retain the established runtime bindings for compiled callers.
(def agentic-ai-lab-module-activation-prototype
  composition.agentic-ai-lab-module-activation-prototype)
(def make-agentic-ai-lab-module-activation
  composition.make-agentic-ai-lab-module-activation)
(def agentic-ai-lab-module-activation?
  composition.agentic-ai-lab-module-activation?)
(def agentic-ai-lab-module-activation-modules
  composition.agentic-ai-lab-module-activation-modules)
(def agentic-ai-lab-module-activation-task-registry
  composition.agentic-ai-lab-module-activation-task-registry)
(def agentic-ai-lab-module-activation-flow-registry
  composition.agentic-ai-lab-module-activation-flow-registry)
(def agentic-ai-lab-module-activation-options
  composition.agentic-ai-lab-module-activation-options)
(def activate-agentic-ai-lab-modules
  composition.activate-agentic-ai-lab-modules)
(def activate-agentic-ai-lab-modules-with-base
  composition.activate-agentic-ai-lab-modules-with-base)

;;; Boundary: run-config lowering keeps modules outside runner internals.
;; : (-> Symbol Strategy RuntimeAdapter PooModuleActivation RunConfig)
(def (agentic-ai-lab-module-activation->run-config name strategy adapter activation)
  (make-run-config name
                   strategy
                   adapter
                   (agentic-ai-lab-module-activation-options activation)
                   (agentic-ai-lab-module-activation-task-registry activation)
                   (agentic-ai-lab-module-activation-flow-registry activation)))
