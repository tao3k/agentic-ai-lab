;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Contract: validation receipt for P0 boundary namespace descriptors.

(import (only-in "../../query/semantic/boundary-namespace.ss"
                 agentic-ai-lab-intent-boundary-prototype
                 agentic-ai-lab-author-boundary-prototype
                 agentic-ai-lab-graph-boundary-prototype
                 agentic-ai-lab-semantic-boundary-prototype
                 agentic-ai-lab-contract-boundary-prototype
                 agentic-ai-lab-observability-boundary-prototype
                 agentic-ai-lab-projection-boundary-prototype
                 agentic-ai-lab-runtime-boundary-prototype
                 +agentic-ai-lab-boundary-layers+
                 +agentic-ai-lab-agent-repair-boundary-layers+
                 +agentic-ai-lab-disallowed-public-categories+
                 +agentic-ai-lab-boundary-namespace-prefix+
                 agentic-ai-lab-boundary-layer?
                 agentic-ai-lab-agent-repair-boundary-layer?
                 agentic-ai-lab-public-category-allowed?
                 agentic-ai-lab-boundary-prototype?
                 agentic-ai-lab-boundary-prototype-id
                 agentic-ai-lab-boundary-prototype->alist
                 make-agentic-ai-lab-namespace-descriptor
                 agentic-ai-lab-namespace-descriptor?
                 agentic-ai-lab-namespace-descriptor-kind
                 agentic-ai-lab-namespace-descriptor-boundary
                 agentic-ai-lab-namespace-descriptor-category
                 agentic-ai-lab-namespace-descriptor-module
                 agentic-ai-lab-namespace-descriptor-segments
                 agentic-ai-lab-namespace-descriptor-public?
                 agentic-ai-lab-namespace-descriptor-repair-layer
                 agentic-ai-lab-namespace-descriptor->symbol
                 agentic-ai-lab-namespace-descriptor->alist
                 agentic-ai-lab-boundary-namespace
                 agentic-ai-lab-category-module-namespace)
        (only-in "../../../core/type-facts/objects.ss"
                 yuanxu-type-fact
                 yuanxu-type-fact-contract->alist
                 yuanxu-lean-fact
                 yuanxu-lean-fact-contract->alist)
        (only-in :yuanxu/observability/objects
                 yuanxu-observability-diagnostic-record
                 yuanxu-observability-diagnostic-code
                 yuanxu-observability-diagnostic->alist
                 yuanxu-observability-feedback-receipt
                 yuanxu-observability-agent-feedback
                 yuanxu-observability-graph
                 yuanxu-observability-readiness
                 yuanxu-observability-repair))

(export agentic-ai-lab-intent-boundary-prototype
        agentic-ai-lab-author-boundary-prototype
        agentic-ai-lab-graph-boundary-prototype
        agentic-ai-lab-semantic-boundary-prototype
        agentic-ai-lab-contract-boundary-prototype
        agentic-ai-lab-observability-boundary-prototype
        agentic-ai-lab-projection-boundary-prototype
        agentic-ai-lab-runtime-boundary-prototype
        +agentic-ai-lab-boundary-layers+
        +agentic-ai-lab-agent-repair-boundary-layers+
        +agentic-ai-lab-disallowed-public-categories+
        +agentic-ai-lab-boundary-namespace-prefix+
        agentic-ai-lab-boundary-layer?
        agentic-ai-lab-agent-repair-boundary-layer?
        agentic-ai-lab-public-category-allowed?
        agentic-ai-lab-boundary-prototype?
        agentic-ai-lab-boundary-prototype-id
        agentic-ai-lab-boundary-prototype->alist
        make-agentic-ai-lab-namespace-descriptor
        agentic-ai-lab-namespace-descriptor?
        agentic-ai-lab-namespace-descriptor-kind
        agentic-ai-lab-namespace-descriptor-boundary
        agentic-ai-lab-namespace-descriptor-category
        agentic-ai-lab-namespace-descriptor-module
        agentic-ai-lab-namespace-descriptor-segments
        agentic-ai-lab-namespace-descriptor-public?
        agentic-ai-lab-namespace-descriptor-repair-layer
        agentic-ai-lab-namespace-descriptor->symbol
        agentic-ai-lab-namespace-descriptor->alist
        agentic-ai-lab-boundary-namespace
        agentic-ai-lab-category-module-namespace
        make-agentic-ai-lab-boundary-namespace-validation
        agentic-ai-lab-boundary-namespace-validation?
        agentic-ai-lab-boundary-namespace-validation-kind
        agentic-ai-lab-boundary-namespace-validation-schema
        agentic-ai-lab-boundary-namespace-validation-descriptor
        agentic-ai-lab-boundary-namespace-validation-valid
        agentic-ai-lab-boundary-namespace-validation-diagnostics
        agentic-ai-lab-boundary-namespace-validation-type-facts
        agentic-ai-lab-boundary-namespace-validation-lean-fact-contracts
        agentic-ai-lab-boundary-namespace-validation-valid?
        agentic-ai-lab-boundary-namespace-contract-validation
        agentic-ai-lab-boundary-namespace-validation->alist
        agentic-ai-lab-boundary-namespace-validation-summary
        agentic-ai-lab-boundary-namespace-agent-feedback
        agentic-ai-lab-require-boundary-namespace!)

;; : (-> Symbol String AgenticAILabDiagnosticValue YuanxuObservabilityDiagnostic)
(def (agentic-ai-lab-boundary-namespace-diagnostic code message value)
  (yuanxu-observability-diagnostic-record
   'error
   'contract
   'boundary-namespace-validator
   'boundary-namespace
   #f
   code
   message
   'author
   (list
    (cons 'object 'AgenticAILabNamespaceDescriptor)
    (cons 'value value))))

;; : (-> AgenticAILabNamespaceDescriptor [Alist])
(def (agentic-ai-lab-boundary-namespace-repair-layer-diagnostics descriptor)
  (let (repair-layer
        (agentic-ai-lab-namespace-descriptor-repair-layer descriptor))
    (if (or (not repair-layer)
            (agentic-ai-lab-agent-repair-boundary-layer? repair-layer))
      '()
      (list
       (agentic-ai-lab-boundary-namespace-diagnostic
        'invalid-agent-repair-layer
        "namespace repair layer must be a legal agent repair boundary"
        repair-layer)))))

;; : (-> AgenticAILabNamespaceDescriptor [Alist])
(def (agentic-ai-lab-category-module-namespace-diagnostics descriptor)
  (cond
   ((not (and (symbol? (agentic-ai-lab-namespace-descriptor-category descriptor))
              (symbol? (agentic-ai-lab-namespace-descriptor-module descriptor))))
    (list
     (agentic-ai-lab-boundary-namespace-diagnostic
      'invalid-category-module-namespace
      "category module namespace requires symbolic category and module names"
      descriptor)))
   ((not (agentic-ai-lab-public-category-allowed?
          (agentic-ai-lab-namespace-descriptor-category descriptor)))
    (list
     (agentic-ai-lab-boundary-namespace-diagnostic
      'disallowed-public-category
      "public category module namespace must not use stale or ambiguous categories"
      (agentic-ai-lab-namespace-descriptor-category descriptor))))
   (else '())))

;; : (-> AgenticAILabNamespaceDescriptor [Alist])
(def (agentic-ai-lab-boundary-namespace-local-diagnostics descriptor)
  (cond
   ((not (agentic-ai-lab-namespace-descriptor? descriptor))
    (list
     (agentic-ai-lab-boundary-namespace-diagnostic
      'namespace-descriptor-not-object
      "boundary namespace validation expects a namespace descriptor"
      descriptor)))
   ((eq? (agentic-ai-lab-namespace-descriptor-kind descriptor) 'boundary)
    (let (boundary-diagnostics
          (if (agentic-ai-lab-boundary-layer?
               (agentic-ai-lab-namespace-descriptor-boundary descriptor))
            '()
            (list
             (agentic-ai-lab-boundary-namespace-diagnostic
              'unknown-boundary-layer
              "boundary namespace must use a canonical P0 boundary layer"
              (agentic-ai-lab-namespace-descriptor-boundary descriptor)))))
      (append boundary-diagnostics
              (agentic-ai-lab-boundary-namespace-repair-layer-diagnostics
               descriptor))))
   ((eq? (agentic-ai-lab-namespace-descriptor-kind descriptor) 'category-module)
    (let (category-diagnostics
          (agentic-ai-lab-category-module-namespace-diagnostics descriptor))
      (append category-diagnostics
              (agentic-ai-lab-boundary-namespace-repair-layer-diagnostics
               descriptor))))
   (else
    (list
     (agentic-ai-lab-boundary-namespace-diagnostic
      'unknown-namespace-kind
      "namespace descriptor kind must be boundary or category-module"
      (agentic-ai-lab-namespace-descriptor-kind descriptor))))))

;; agentic-ai-lab-boundary-namespace-validation
;;   : (-> String String AgenticAILabNamespaceDescriptor Boolean [YuanxuObservabilityDiagnostic] [YuanxuTypeFactContract] [YuanxuLeanFactContract] AgenticAILabBoundaryNamespaceValidation)
;;   | doc m%
;;       Fixed validation receipt row for one namespace descriptor.
;;       Constructor and accessors are generated by defstruct; all public
;;       projection leaves through `agentic-ai-lab-boundary-namespace-validation->alist`.
;;     %
(defstruct agentic-ai-lab-boundary-namespace-validation
  (kind
   schema
   descriptor
   valid
   diagnostics
   type-facts
   lean-fact-contracts)
  transparent: #t)

;; : (-> AgenticAILabBoundaryNamespaceValidation Boolean)
(def (agentic-ai-lab-boundary-namespace-validation-valid? validation)
  (and (agentic-ai-lab-boundary-namespace-validation? validation)
       (agentic-ai-lab-boundary-namespace-validation-valid validation)))

;; : (-> AgenticAILabNamespaceDescriptor AgenticAILabBoundaryNamespaceValidation)
(def (agentic-ai-lab-boundary-namespace-contract-validation descriptor)
  (let* ((diagnostics
          (agentic-ai-lab-boundary-namespace-local-diagnostics descriptor))
         (valid? (null? diagnostics)))
    (make-agentic-ai-lab-boundary-namespace-validation
     "agentic-ai-lab-boundary-namespace-validation"
     "agentic-ai-lab-boundary-namespace-validation/v1"
     descriptor
     valid?
     diagnostics
     (list
      (yuanxu-type-fact
       'boundary.namespace/boundary-layer
       'slot-contract
       'AgenticAILabNamespaceDescriptor
       'boundaryLayer
       'boundary
       'Symbol
       'positive
       '((scope . boundary) (required-for . boundary-namespace)))
      (yuanxu-type-fact
       'boundary.namespace/category-module
       'slot-contract
       'AgenticAILabNamespaceDescriptor
       'categoryModule
       'category
       'Symbol
       'positive
       '((scope . boundary) (required-for . category-module)))
      (yuanxu-type-fact
       'boundary.namespace/repair-layer
       'slot-contract
       'AgenticAILabNamespaceDescriptor
       'repairLayer
       'repair-layer
       'Symbol
       'positive
       '((scope . boundary) (agent-visible . #t))))
     (list
      (yuanxu-lean-fact
       'boundary.namespace/runtime-not-semantic-owner
       'fact
       'BoundaryNamespace.BoundaryFact
       'runtimeNotSemanticOwner
       'runtime
       'negative
       '((scope . boundary)))
      (yuanxu-lean-fact
       'boundary.namespace/projection-not-source-owner
       'fact
       'BoundaryNamespace.BoundaryFact
       'projectionNotSourceOwner
       'projection
       'negative
       '((scope . boundary)))))))

;; : (forall (v) (-> v [(Pair Symbol Object)]))
;; : (-> AgenticAILabBoundaryNamespaceValidation Alist)
(def (agentic-ai-lab-boundary-namespace-validation->alist validation)
  (list
   (cons 'kind (agentic-ai-lab-boundary-namespace-validation-kind validation))
   (cons 'schema (agentic-ai-lab-boundary-namespace-validation-schema validation))
   (cons 'valid (agentic-ai-lab-boundary-namespace-validation-valid validation))
   (cons 'descriptor
         (if (agentic-ai-lab-namespace-descriptor?
              (agentic-ai-lab-boundary-namespace-validation-descriptor validation))
           (agentic-ai-lab-namespace-descriptor->alist
            (agentic-ai-lab-boundary-namespace-validation-descriptor validation))
           (agentic-ai-lab-boundary-namespace-validation-descriptor validation)))
   (cons 'diagnostics
         (map yuanxu-observability-diagnostic->alist
              (agentic-ai-lab-boundary-namespace-validation-diagnostics
               validation)))
   (cons 'diagnostic-count
         (length (agentic-ai-lab-boundary-namespace-validation-diagnostics
                  validation)))
   (cons 'type-facts
         (map yuanxu-type-fact-contract->alist
              (agentic-ai-lab-boundary-namespace-validation-type-facts
               validation)))
   (cons 'lean-fact-contracts
         (map yuanxu-lean-fact-contract->alist
              (agentic-ai-lab-boundary-namespace-validation-lean-fact-contracts
               validation)))))

;; : (-> AgenticAILabBoundaryNamespaceValidation [Symbol])
(def (agentic-ai-lab-boundary-namespace-validation-diagnostic-codes validation)
  (map yuanxu-observability-diagnostic-code
       (agentic-ai-lab-boundary-namespace-validation-diagnostics validation)))

;; : (-> AgenticAILabBoundaryNamespaceValidation Alist)
(def (agentic-ai-lab-boundary-namespace-validation-summary validation)
  (let ((descriptor
         (agentic-ai-lab-boundary-namespace-validation-descriptor validation))
        (diagnostics
         (agentic-ai-lab-boundary-namespace-validation-diagnostics validation)))
    (list
     (cons 'kind 'agentic-ai-lab-boundary-namespace-summary)
     (cons 'valid?
           (agentic-ai-lab-boundary-namespace-validation-valid? validation))
     (cons 'namespace
           (and (agentic-ai-lab-namespace-descriptor? descriptor)
                (agentic-ai-lab-namespace-descriptor->symbol descriptor)))
     (cons 'diagnostic-count (length diagnostics))
     (cons 'diagnostic-codes
           (agentic-ai-lab-boundary-namespace-validation-diagnostic-codes
           validation)))))

;; : (-> Boolean (Or Symbol False))
(def (agentic-ai-lab-boundary-namespace-feedback-repair-layer valid?)
  (if valid? #f 'author))

;; : (-> Boolean (Or Symbol False))
(def (agentic-ai-lab-boundary-namespace-feedback-repair-target valid?)
  (if valid? #f 'boundary-namespace-declaration))

;; : (-> Boolean Symbol)
(def (agentic-ai-lab-boundary-namespace-feedback-readiness-state valid?)
  (if valid? 'ready 'blocked))

;; : (-> AgenticAILabBoundaryNamespaceValidation Alist)
(def (agentic-ai-lab-boundary-namespace-agent-feedback validation)
  (let* ((summary
          (agentic-ai-lab-boundary-namespace-validation-summary validation))
         (valid?
          (agentic-ai-lab-boundary-namespace-validation-valid? validation))
         (receipt
          (yuanxu-observability-feedback-receipt
           "agentic-ai-lab-boundary-namespace-agent-feedback/v1"
           'boundary-namespace
           (yuanxu-observability-graph 'boundary-namespace summary)
           (agentic-ai-lab-boundary-namespace-validation-diagnostics validation)
           (yuanxu-observability-repair
            (agentic-ai-lab-boundary-namespace-feedback-repair-layer valid?)
            (agentic-ai-lab-boundary-namespace-feedback-repair-target valid?))
           (yuanxu-observability-readiness
            (agentic-ai-lab-boundary-namespace-feedback-readiness-state valid?)
            valid?)
           (list
            (cons 'validation
                  (agentic-ai-lab-boundary-namespace-validation->alist
                   validation))))))
    (yuanxu-observability-agent-feedback
     'yuanxu-agent-feedback
     'accept-boundary-namespace
     'repair-boundary-namespace
     receipt)))

;; : (-> AgenticAILabNamespaceDescriptor AgenticAILabNamespaceDescriptor)
(def (agentic-ai-lab-require-boundary-namespace! descriptor)
  (let (validation (agentic-ai-lab-boundary-namespace-contract-validation descriptor))
    (if (agentic-ai-lab-boundary-namespace-validation-valid? validation)
      descriptor
      (error "boundary namespace failed validation" validation))))
