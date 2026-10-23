;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module runtime-facing projections and presentation receipts.
;;; Invariant: projection returns inspectable Scheme values, not runtime handles.

(import (only-in :clan/poo/object .@ .o .ref .get)
        (only-in :yuanxu/modules/funflow/objects FunflowModule.)
        :agentic-ai-lab/modules/module-authoring/module-interface
        :agentic-ai-lab/modules/module-authoring/module-descriptor
        :yuanxu/module-system/funs
        :yuanxu/module-system/projection/option-objects
        :yuanxu/module-system/catalog/values
        :agentic-ai-lab/modules/module-authoring/module-option-projection)

(export agentic-ai-lab-module-runtime-import
        agentic-ai-lab-module-apply
        agentic-ai-lab-module-evaluate
        agentic-ai-lab-module-workflow
        agentic-ai-lab-module-runtime-capability-projection
        agentic-ai-lab-module-value-catalog-find
        agentic-ai-lab-module-value-catalog-active?
        agentic-ai-lab-module-value-catalog-root
        agenticAiLabModuleActive?
        agentic-ai-lab-module-active?
        agenticAiLabEvalModules
        agentic-ai-lab-eval-modules
        agenticAiLabModuleSystemPresentation
        agentic-ai-lab-module-system-presentation)

;;; Boundary: runtime imports unwrap structured imports but preserve payloads.
;; : (-> ModuleImportValue RuntimeImport)
(def (agentic-ai-lab-module-runtime-import import-value)
  (let (profile (agentic-ai-lab-module-import-profile import-value))
    (cond
     ((agentic-ai-lab-module-config? profile)
      (agentic-ai-lab-module-apply profile))
     (else profile))))

;;; Boundary: apply creates an inspectable runtime-module value, not a handle.
;; : (-> PooModuleDescriptor POOObject)
(def (agentic-ai-lab-module-apply module)
  (.o kind: "agentic-ai-lab.modules.runtime-module.v1"
      id: (agentic-ai-lab-module-name module)
      group: (agentic-ai-lab-module-group module)
      flags: (agentic-ai-lab-module-flags module)
      features: (agentic-ai-lab-module-features module)
      depth: (agentic-ai-lab-module-depth module)
      phase-files: (agentic-ai-lab-module-phase-files module)
      hooks: (agentic-ai-lab-module-hooks module)
      imports: (map agentic-ai-lab-module-runtime-import
                    (yuanxu-module-imports module))
      extensions: (agentic-ai-lab-module-extensions module)
      scripts: (agentic-ai-lab-module-scripts module)
      options: (agentic-ai-lab-module-option-configs module)
      metadata: (agentic-ai-lab-module-metadata module)))

;;; Boundary: projection append preserves closure module order.
;; : (-> [PooModuleDescriptor] (-> PooModuleDescriptor ProjectionValueList) [ProjectionValue])
(def (agentic-ai-lab-module-append-projection modules projector)
  (foldr append '() (map projector modules)))

;;; Boundary: evaluation folds the import closure into one receipt object.
;; : (-> PooModuleDescriptor POOObject)
(def (agentic-ai-lab-module-evaluate module)
  (let (closed-modules (agentic-ai-lab-module-closure (list module)))
    (.o kind: "agentic-ai-lab.modules.runtime-evaluation.v1"
        module-ids: (agentic-ai-lab-module-names closed-modules)
        init-module-ids:
        (agentic-ai-lab-module-names
         (yuanxu-module-phase-order closed-modules 'init))
        config-module-ids:
        (agentic-ai-lab-module-names
         (yuanxu-module-phase-order closed-modules 'config))
        hooks:
        (agentic-ai-lab-module-append-projection
         closed-modules agentic-ai-lab-module-hooks)
        extensions:
        (agentic-ai-lab-module-append-projection
         closed-modules agentic-ai-lab-module-extensions)
        scripts:
        (agentic-ai-lab-module-append-projection
         closed-modules agentic-ai-lab-module-scripts)
        options:
        (agentic-ai-lab-module-append-projection
         closed-modules agentic-ai-lab-module-option-configs)
        validation-receipts:
        (agentic-ai-lab-module-append-projection
         closed-modules agentic-ai-lab-module-option-validation-receipts))))

;;; Boundary: workflow groups root projections and validation receipts.
;; : (-> PooModuleDescriptor [AllowedHookId] POOObject)
(def (agentic-ai-lab-module-workflow module . maybe-allowed-hook-id-values)
  (let* ((allowed-hook-id-values
          (if (null? maybe-allowed-hook-id-values)
            '()
            (car maybe-allowed-hook-id-values)))
         (runtime-module-value (agentic-ai-lab-module-apply module))
         (evaluation-value (agentic-ai-lab-module-evaluate module)))
    (.o kind: agentic-ai-lab-module-workflow-kind
        config: module
        runtime-module: runtime-module-value
        evaluation: evaluation-value
        allowed-hook-ids: allowed-hook-id-values
        root-options: (agentic-ai-lab-module-option-configs module)
        option-schemas: (agentic-ai-lab-module-option-schemas module)
        root-validation-receipts:
        (agentic-ai-lab-module-option-validation-receipts module)
        validation-receipts:
        (.ref evaluation-value 'validation-receipts))))

;;; Boundary: this projection reports runtime-facing object family capability.
;;; It does not construct runtime handles, start sessions, or submit dispatches.
;; : (-> POOObject)
(def (agentic-ai-lab-module-runtime-capability-projection)
  (.o kind: "agentic-ai-lab.modules.runtime-capability-projection.v1"
      owner: agentic-ai-lab-module-system-owner
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
      operation-kinds: (.get FunflowModule. runtime-vocabulary operation-kinds)
      snapshot-statuses: (.get FunflowModule. runtime-vocabulary snapshot-statuses)
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
(def (agentic-ai-lab-module-value-catalog-find catalog module-id-value)
  (find (lambda (module)
          (equal? (agentic-ai-lab-module-name module) module-id-value))
        (.ref catalog 'modules)))

;;; Boundary: catalog active checks make Doom's modulep behavior data-driven.
;; : (-> PooModuleValueCatalog ModuleName [ModuleFlag] Boolean)
(def (agentic-ai-lab-module-value-catalog-active? catalog module-id-value . required-flags)
  (let (module (agentic-ai-lab-module-value-catalog-find catalog module-id-value))
    (and module
         (apply agentic-ai-lab-module-active? module required-flags))))

;; : (-> PooModuleValueCatalog ModuleName [ModuleFlag] Boolean)
(def (agenticAiLabModuleActive? catalog module-id-value . required-flags)
  (apply agentic-ai-lab-module-value-catalog-active?
         catalog
         module-id-value
         required-flags))

;;; Boundary: missing root id falls back to the first catalog module.
;; : (-> PooModuleValueCatalog MaybeModuleName PooModuleDescriptor)
(def (agentic-ai-lab-module-value-catalog-root catalog module-id-value)
  (cond
   (module-id-value
    (or (agentic-ai-lab-module-value-catalog-find catalog module-id-value)
        (error "agentic-ai-lab module root not found" module-id-value)))
   ((pair? (.ref catalog 'modules))
    (car (.ref catalog 'modules)))
   (else
    (error "agentic-ai-lab module catalog is empty"))))

;;; Boundary: evalModules mirrors Marlin without entering runtime execution.
;; | AgenticAILabEvalModuleOptions = [MaybeModuleName [AllowedHookId]]
;; agenticAiLabEvalModules
;;   : (-> PooModuleValueCatalog AgenticAILabEvalModuleOptions POOObject)
;;   | contract: returns branded Agentic AI Lab evaluation data, never runtime handles
;;   | doc m%
;;   | # Examples
;;   | ```scheme
;;   | (agenticAiLabEvalModules catalog 'root '("after-config"))
;;   | ```
;;   | result: replayable module evaluation receipt with brand and owner fields.
;; : (-> PooModuleValueCatalog AgenticAILabEvalModuleOptions POOObject)
(def (agentic-ai-lab-eval-modules catalog . eval-options)
  (let* ((root-module-id-value
          (if (null? eval-options) #f (car eval-options)))
         (allowed-hook-id-values
          (if (or (null? eval-options)
                  (null? (cdr eval-options)))
            '()
            (cadr eval-options)))
         (root-module
          (agentic-ai-lab-module-value-catalog-root catalog root-module-id-value))
         (workflow
          (agentic-ai-lab-module-workflow root-module allowed-hook-id-values))
         (evaluation-value (.ref workflow 'evaluation))
         (runtime-capabilities
          (agentic-ai-lab-module-runtime-capability-projection)))
    (.o kind: agentic-ai-lab-eval-modules-result-kind
        catalog-kind: (.ref catalog 'kind)
        root-module-id: (agentic-ai-lab-module-name root-module)
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
        brand-name: agentic-ai-lab-brand-name
        brand-group: agentic-ai-lab-brand-group
        scheme-owner: agentic-ai-lab-scheme-owner
        module-system-owner: agentic-ai-lab-module-system-owner
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

;; : (-> PooModuleValueCatalog AgenticAILabEvalModuleOptions POOObject)
(def (agenticAiLabEvalModules catalog . eval-options)
  (apply agentic-ai-lab-eval-modules catalog eval-options))

;;; Boundary: presentation is the debug/doctor scalar summary of evalModules.
;; | AgenticAILabModulePresentationOptions = [MaybeModuleName [AllowedHookId]]
;; agenticAiLabModuleSystemPresentation
;;   : (-> PooModuleValueCatalog AgenticAILabModulePresentationOptions POOObject)
;;   | contract: presents Agentic AI Lab brand, module counts, and owner boundaries
;;   | doc m%
;;   | # Examples
;;   | ```scheme
;;   | (agenticAiLabModuleSystemPresentation catalog 'root)
;;   | ```
;;   | result: user-facing presentation object with runtime-executed set to #f.
;; : (-> PooModuleValueCatalog AgenticAILabModulePresentationOptions POOObject)
(def (agentic-ai-lab-module-system-presentation catalog . eval-options)
  (let* ((root-module-id-value
          (if (null? eval-options) #f (car eval-options)))
         (allowed-hook-id-values
          (if (or (null? eval-options)
                  (null? (cdr eval-options)))
            '()
            (cadr eval-options)))
         (root-module
          (agentic-ai-lab-module-value-catalog-root catalog root-module-id-value))
         (eval-result
          (cond
           ((null? eval-options)
            (agentic-ai-lab-eval-modules catalog))
           ((null? (cdr eval-options))
            (agentic-ai-lab-eval-modules catalog root-module-id-value))
           (else
            (agentic-ai-lab-eval-modules
             catalog
             root-module-id-value
             allowed-hook-id-values))))
         (runtime-capabilities
          (agentic-ai-lab-module-runtime-capability-projection)))
    (.o kind: agentic-ai-lab-module-system-presentation-kind
        catalog-kind: (.ref catalog 'kind)
        catalog-module-count: (length (.ref catalog 'modules))
        root-module-id: (agentic-ai-lab-module-name root-module)
        root-module-kind: (.@ root-module kind)
        root-import-count: (length (yuanxu-module-imports root-module))
        root-flag-count: (length (agentic-ai-lab-module-flags root-module))
        root-hook-count: (length (agentic-ai-lab-module-hooks root-module))
        root-extension-count: (length (agentic-ai-lab-module-extensions root-module))
        root-script-count: (length (agentic-ai-lab-module-scripts root-module))
        allowed-hook-count: (length allowed-hook-id-values)
        user-entrypoints:
        '("agentic-ai-lab-modules"
          "yuanxu-module-catalog"
          "agentic-ai-lab-module-active?"
          "agentic-ai-lab-module-value-catalog-active?"
          "agentic-ai-lab-eval-modules"
          "agentic-ai-lab-module-system-presentation")
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
        import-graph-owner: "agentic-ai-lab-module-system"
        brand-name: agentic-ai-lab-brand-name
        brand-group: agentic-ai-lab-brand-group
        option-policy-owner: agentic-ai-lab-module-system-owner
        extension-composition-owner: agentic-ai-lab-module-system-owner
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

;; : (-> PooModuleValueCatalog AgenticAILabModulePresentationOptions POOObject)
(def (agenticAiLabModuleSystemPresentation catalog . eval-options)
  (apply agentic-ai-lab-module-system-presentation catalog eval-options))
