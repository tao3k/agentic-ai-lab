;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module runtime-facing projections and presentation receipts.
;;; Invariant: projection returns inspectable Scheme values, not runtime handles.

(import (only-in :clan/poo/object .@ .o .ref)
        :poo-flow/modules/workflow/control-plane/agent-harness-vocabulary
        :poo-flow/modules/module-authoring/module-interface
        :poo-flow/modules/module-authoring/module-descriptor
        :core/module-system/funs
        :core/module-system/projection/option-objects
        :core/module-system/catalog/values
        :poo-flow/modules/module-authoring/module-option-projection)

(export poo-flow-module-runtime-import
        poo-flow-module-apply
        poo-flow-module-evaluate
        poo-flow-module-workflow
        poo-flow-module-runtime-capability-projection
        poo-flow-module-value-catalog-find
        poo-flow-module-value-catalog-active?
        poo-flow-module-value-catalog-root
        pooFlowModuleActive?
        poo-flow-module-active?
        pooFlowEvalModules
        poo-flow-eval-modules
        pooFlowModuleSystemPresentation
        poo-flow-module-system-presentation)

;;; Boundary: runtime imports unwrap structured imports but preserve payloads.
;; : (-> ModuleImportValue RuntimeImport)
(def (poo-flow-module-runtime-import import-value)
  (let (profile (poo-flow-module-import-profile import-value))
    (cond
     ((poo-flow-module-config? profile)
      (poo-flow-module-apply profile))
     (else profile))))

;;; Boundary: apply creates an inspectable runtime-module value, not a handle.
;; : (-> PooModuleDescriptor POOObject)
(def (poo-flow-module-apply module)
  (.o kind: "poo-flow.modules.runtime-module.v1"
      id: (poo-flow-module-name module)
      group: (poo-flow-module-group module)
      flags: (poo-flow-module-flags module)
      features: (poo-flow-module-features module)
      depth: (poo-flow-module-depth module)
      phase-files: (poo-flow-module-phase-files module)
      hooks: (poo-flow-module-hooks module)
      imports: (map poo-flow-module-runtime-import
                    (poo-flow-module-imports module))
      extensions: (poo-flow-module-extensions module)
      scripts: (poo-flow-module-scripts module)
      options: (poo-flow-module-option-configs module)
      metadata: (poo-flow-module-metadata module)))

;;; Boundary: projection append preserves closure module order.
;; : (-> [PooModuleDescriptor] (-> PooModuleDescriptor ProjectionValueList) [ProjectionValue])
(def (poo-flow-module-append-projection modules projector)
  (foldr append '() (map projector modules)))

;;; Boundary: evaluation folds the import closure into one receipt object.
;; : (-> PooModuleDescriptor POOObject)
(def (poo-flow-module-evaluate module)
  (let (closed-modules (poo-flow-module-closure (list module)))
    (.o kind: "poo-flow.modules.runtime-evaluation.v1"
        module-ids: (poo-flow-module-names closed-modules)
        init-module-ids:
        (poo-flow-module-names
         (poo-flow-module-phase-order closed-modules 'init))
        config-module-ids:
        (poo-flow-module-names
         (poo-flow-module-phase-order closed-modules 'config))
        hooks:
        (poo-flow-module-append-projection
         closed-modules poo-flow-module-hooks)
        extensions:
        (poo-flow-module-append-projection
         closed-modules poo-flow-module-extensions)
        scripts:
        (poo-flow-module-append-projection
         closed-modules poo-flow-module-scripts)
        options:
        (poo-flow-module-append-projection
         closed-modules poo-flow-module-option-configs)
        validation-receipts:
        (poo-flow-module-append-projection
         closed-modules poo-flow-module-option-validation-receipts))))

;;; Boundary: workflow groups root projections and validation receipts.
;; : (-> PooModuleDescriptor [AllowedHookId] POOObject)
(def (poo-flow-module-workflow module . maybe-allowed-hook-id-values)
  (let* ((allowed-hook-id-values
          (if (null? maybe-allowed-hook-id-values)
            '()
            (car maybe-allowed-hook-id-values)))
         (runtime-module-value (poo-flow-module-apply module))
         (evaluation-value (poo-flow-module-evaluate module)))
    (.o kind: poo-flow-module-workflow-kind
        config: module
        runtime-module: runtime-module-value
        evaluation: evaluation-value
        allowed-hook-ids: allowed-hook-id-values
        root-options: (poo-flow-module-option-configs module)
        option-schemas: (poo-flow-module-option-schemas module)
        root-validation-receipts:
        (poo-flow-module-option-validation-receipts module)
        validation-receipts:
        (.ref evaluation-value 'validation-receipts))))

;;; Boundary: this projection reports runtime-facing object family capability.
;;; It does not construct runtime handles, start sessions, or submit dispatches.
;; : (-> POOObject)
(def (poo-flow-module-runtime-capability-projection)
  (.o kind: "poo-flow.modules.runtime-capability-projection.v1"
      owner: poo-flow-module-system-owner
      runtime-owner: "marlin-agent-core"
      runtime-executed: #f
      object-families:
      '(agent-profile
        agent-harness
        agent-session
        session-agent-graph
        agent-operation
        workflow-run
        dispatch-receipt
        runtime-snapshot)
      operation-kinds: +poo-flow-agent-operation-kinds+
      snapshot-statuses: +poo-flow-runtime-snapshot-statuses+
      handoff-contracts:
      '(start-workflow-run
        admit-dispatch
        open-agent-session
        execute-agent-operation
        stream-events
        read-runtime-snapshot)
      presentation-trace:
      '((stage . runtime-capability-projection)
        (runtime-executed . #f)
        (projection-only . #t))))

;;; Boundary: value catalog lookup is by module id only.
;; : (-> PooModuleValueCatalog ModuleName MaybePooModuleDescriptor)
(def (poo-flow-module-value-catalog-find catalog module-id-value)
  (find (lambda (module)
          (equal? (poo-flow-module-name module) module-id-value))
        (.ref catalog 'modules)))

;;; Boundary: catalog active checks make Doom's modulep behavior data-driven.
;; : (-> PooModuleValueCatalog ModuleName [ModuleFlag] Boolean)
(def (poo-flow-module-value-catalog-active? catalog module-id-value . required-flags)
  (let (module (poo-flow-module-value-catalog-find catalog module-id-value))
    (and module
         (apply poo-flow-module-active? module required-flags))))

;; : (-> PooModuleValueCatalog ModuleName [ModuleFlag] Boolean)
(def (pooFlowModuleActive? catalog module-id-value . required-flags)
  (apply poo-flow-module-value-catalog-active?
         catalog
         module-id-value
         required-flags))

;;; Boundary: missing root id falls back to the first catalog module.
;; : (-> PooModuleValueCatalog MaybeModuleName PooModuleDescriptor)
(def (poo-flow-module-value-catalog-root catalog module-id-value)
  (cond
   (module-id-value
    (or (poo-flow-module-value-catalog-find catalog module-id-value)
        (error "poo-flow module root not found" module-id-value)))
   ((pair? (.ref catalog 'modules))
    (car (.ref catalog 'modules)))
   (else
    (error "poo-flow module catalog is empty"))))

;;; Boundary: evalModules mirrors Marlin without entering runtime execution.
;; | PooFlowEvalModuleOptions = [MaybeModuleName [AllowedHookId]]
;; pooFlowEvalModules
;;   : (-> PooModuleValueCatalog PooFlowEvalModuleOptions POOObject)
;;   | contract: returns branded POO Flow evaluation data, never runtime handles
;;   | doc m%
;;   | # Examples
;;   | ```scheme
;;   | (pooFlowEvalModules catalog 'root '("after-config"))
;;   | ```
;;   | result: replayable module evaluation receipt with brand and owner fields.
;; : (-> PooModuleValueCatalog PooFlowEvalModuleOptions POOObject)
(def (poo-flow-eval-modules catalog . eval-options)
  (let* ((root-module-id-value
          (if (null? eval-options) #f (car eval-options)))
         (allowed-hook-id-values
          (if (or (null? eval-options)
                  (null? (cdr eval-options)))
            '()
            (cadr eval-options)))
         (root-module
          (poo-flow-module-value-catalog-root catalog root-module-id-value))
         (workflow
          (poo-flow-module-workflow root-module allowed-hook-id-values))
         (evaluation-value (.ref workflow 'evaluation))
         (runtime-capabilities
          (poo-flow-module-runtime-capability-projection)))
    (.o kind: poo-flow-eval-modules-result-kind
        catalog-kind: (.ref catalog 'kind)
        root-module-id: (poo-flow-module-name root-module)
        root-module-kind: (.@ root-module kind)
        workflow-kind: (.ref workflow 'kind)
        module-evaluation-kind: (.ref evaluation-value 'kind)
        module-count: (length (.ref evaluation-value 'module-ids))
        init-module-count: (length (.ref evaluation-value 'init-module-ids))
        config-module-count: (length (.ref evaluation-value 'config-module-ids))
        hook-count: (length (.ref evaluation-value 'hooks))
        extension-count: (length (.ref evaluation-value 'extensions))
        script-count: (length (.ref evaluation-value 'scripts))
        option-count: (length (.ref evaluation-value 'options))
        validation-receipt-count:
        (length (.ref evaluation-value 'validation-receipts))
        brand-name: poo-flow-brand-name
        brand-group: poo-flow-brand-group
        scheme-owner: poo-flow-scheme-owner
        module-system-owner: poo-flow-module-system-owner
        runtime-owner: "marlin-agent-core"
        runtime-boundary-owner: "marlin-agent-core"
        runtime-capability-projection-kind:
        (.ref runtime-capabilities 'kind)
        runtime-object-families:
        (.ref runtime-capabilities 'object-families)
        runtime-object-family-count:
        (length (.ref runtime-capabilities 'object-families))
        runtime-snapshot-statuses:
        (.ref runtime-capabilities 'snapshot-statuses)
        runtime-handoff-contracts:
        (.ref runtime-capabilities 'handoff-contracts)
        runtime-executed: #f
        replayable: #t)))

;; : (-> PooModuleValueCatalog PooFlowEvalModuleOptions POOObject)
(def (pooFlowEvalModules catalog . eval-options)
  (apply poo-flow-eval-modules catalog eval-options))

;;; Boundary: presentation is the debug/doctor scalar summary of evalModules.
;; | PooFlowModulePresentationOptions = [MaybeModuleName [AllowedHookId]]
;; pooFlowModuleSystemPresentation
;;   : (-> PooModuleValueCatalog PooFlowModulePresentationOptions POOObject)
;;   | contract: presents POO Flow brand, module counts, and owner boundaries
;;   | doc m%
;;   | # Examples
;;   | ```scheme
;;   | (pooFlowModuleSystemPresentation catalog 'root)
;;   | ```
;;   | result: user-facing presentation object with runtime-executed set to #f.
;; : (-> PooModuleValueCatalog PooFlowModulePresentationOptions POOObject)
(def (poo-flow-module-system-presentation catalog . eval-options)
  (let* ((root-module-id-value
          (if (null? eval-options) #f (car eval-options)))
         (allowed-hook-id-values
          (if (or (null? eval-options)
                  (null? (cdr eval-options)))
            '()
            (cadr eval-options)))
         (root-module
          (poo-flow-module-value-catalog-root catalog root-module-id-value))
         (eval-result
          (cond
           ((null? eval-options)
            (poo-flow-eval-modules catalog))
           ((null? (cdr eval-options))
            (poo-flow-eval-modules catalog root-module-id-value))
           (else
            (poo-flow-eval-modules
             catalog
             root-module-id-value
             allowed-hook-id-values))))
         (runtime-capabilities
          (poo-flow-module-runtime-capability-projection)))
    (.o kind: poo-flow-module-system-presentation-kind
        catalog-kind: (.ref catalog 'kind)
        catalog-module-count: (length (.ref catalog 'modules))
        root-module-id: (poo-flow-module-name root-module)
        root-module-kind: (.@ root-module kind)
        root-import-count: (length (poo-flow-module-imports root-module))
        root-flag-count: (length (poo-flow-module-flags root-module))
        root-hook-count: (length (poo-flow-module-hooks root-module))
        root-extension-count: (length (poo-flow-module-extensions root-module))
        root-script-count: (length (poo-flow-module-scripts root-module))
        allowed-hook-count: (length allowed-hook-id-values)
        user-entrypoints:
        '("poo-flow-modules"
          "poo-flow-module-catalog"
          "poo-flow-module-active?"
          "poo-flow-module-value-catalog-active?"
          "poo-flow-eval-modules"
          "poo-flow-module-system-presentation")
        module-eval-result-kind: (.ref eval-result 'kind)
        workflow-kind: (.ref eval-result 'workflow-kind)
        module-evaluation-receipt-kind:
        (.ref eval-result 'module-evaluation-kind)
        module-count: (.ref eval-result 'module-count)
        init-module-count: (.ref eval-result 'init-module-count)
        config-module-count: (.ref eval-result 'config-module-count)
        hook-count: (.ref eval-result 'hook-count)
        extension-count: (.ref eval-result 'extension-count)
        script-count: (.ref eval-result 'script-count)
        option-count: (.ref eval-result 'option-count)
        validation-receipt-count:
        (.ref eval-result 'validation-receipt-count)
        import-graph-owner: "poo-flow-module-system"
        brand-name: poo-flow-brand-name
        brand-group: poo-flow-brand-group
        option-policy-owner: poo-flow-module-system-owner
        extension-composition-owner: poo-flow-module-system-owner
        scheme-owner: (.ref eval-result 'scheme-owner)
        module-system-owner: (.ref eval-result 'module-system-owner)
        runtime-owner: (.ref eval-result 'runtime-owner)
        runtime-boundary-owner: (.ref eval-result 'runtime-boundary-owner)
        runtime-lifecycle-owner: "marlin-agent-core"
        runtime-capability-projection-kind:
        (.ref runtime-capabilities 'kind)
        runtime-object-family-count:
        (.ref eval-result 'runtime-object-family-count)
        runtime-object-families:
        (.ref eval-result 'runtime-object-families)
        runtime-snapshot-statuses:
        (.ref eval-result 'runtime-snapshot-statuses)
        runtime-handoff-contracts:
        (.ref eval-result 'runtime-handoff-contracts)
        runtime-executed: (.ref eval-result 'runtime-executed)
        runtime-parses-scheme-source: #f
        scheme-manufactures-runtime-handlers: #f
        replayable: (.ref eval-result 'replayable))))

;; : (-> PooModuleValueCatalog PooFlowModulePresentationOptions POOObject)
(def (pooFlowModuleSystemPresentation catalog . eval-options)
  (apply poo-flow-module-system-presentation catalog eval-options))
