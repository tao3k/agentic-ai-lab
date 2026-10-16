;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Contract: validation receipt for P0 boundary namespace descriptors.

(import (only-in "../../query/semantic/boundary-namespace.ss"
                 poo-flow-intent-boundary-prototype
                 poo-flow-author-boundary-prototype
                 poo-flow-graph-boundary-prototype
                 poo-flow-semantic-boundary-prototype
                 poo-flow-contract-boundary-prototype
                 poo-flow-observability-boundary-prototype
                 poo-flow-projection-boundary-prototype
                 poo-flow-runtime-boundary-prototype
                 +poo-flow-boundary-layers+
                 +poo-flow-agent-repair-boundary-layers+
                 +poo-flow-disallowed-public-categories+
                 +poo-flow-boundary-namespace-prefix+
                 poo-flow-boundary-layer?
                 poo-flow-agent-repair-boundary-layer?
                 poo-flow-public-category-allowed?
                 poo-flow-boundary-prototype?
                 poo-flow-boundary-prototype-id
                 poo-flow-boundary-prototype->alist
                 make-poo-flow-namespace-descriptor
                 poo-flow-namespace-descriptor?
                 poo-flow-namespace-descriptor-kind
                 poo-flow-namespace-descriptor-boundary
                 poo-flow-namespace-descriptor-category
                 poo-flow-namespace-descriptor-module
                 poo-flow-namespace-descriptor-segments
                 poo-flow-namespace-descriptor-public?
                 poo-flow-namespace-descriptor-repair-layer
                 poo-flow-namespace-descriptor->symbol
                 poo-flow-namespace-descriptor->alist
                 poo-flow-boundary-namespace
                 poo-flow-category-module-namespace)
        (only-in "../../../core/type-facts/objects.ss"
                 poo-flow-type-fact
                 poo-flow-type-fact-contract->alist
                 poo-flow-lean-fact
                 poo-flow-lean-fact-contract->alist)
        (only-in :core/observability/objects
                 poo-flow-observability-diagnostic-record
                 poo-flow-observability-diagnostic-code
                 poo-flow-observability-diagnostic->alist
                 poo-flow-observability-feedback-receipt
                 poo-flow-observability-agent-feedback
                 poo-flow-observability-graph
                 poo-flow-observability-readiness
                 poo-flow-observability-repair))

(export poo-flow-intent-boundary-prototype
        poo-flow-author-boundary-prototype
        poo-flow-graph-boundary-prototype
        poo-flow-semantic-boundary-prototype
        poo-flow-contract-boundary-prototype
        poo-flow-observability-boundary-prototype
        poo-flow-projection-boundary-prototype
        poo-flow-runtime-boundary-prototype
        +poo-flow-boundary-layers+
        +poo-flow-agent-repair-boundary-layers+
        +poo-flow-disallowed-public-categories+
        +poo-flow-boundary-namespace-prefix+
        poo-flow-boundary-layer?
        poo-flow-agent-repair-boundary-layer?
        poo-flow-public-category-allowed?
        poo-flow-boundary-prototype?
        poo-flow-boundary-prototype-id
        poo-flow-boundary-prototype->alist
        make-poo-flow-namespace-descriptor
        poo-flow-namespace-descriptor?
        poo-flow-namespace-descriptor-kind
        poo-flow-namespace-descriptor-boundary
        poo-flow-namespace-descriptor-category
        poo-flow-namespace-descriptor-module
        poo-flow-namespace-descriptor-segments
        poo-flow-namespace-descriptor-public?
        poo-flow-namespace-descriptor-repair-layer
        poo-flow-namespace-descriptor->symbol
        poo-flow-namespace-descriptor->alist
        poo-flow-boundary-namespace
        poo-flow-category-module-namespace
        make-poo-flow-boundary-namespace-validation
        poo-flow-boundary-namespace-validation?
        poo-flow-boundary-namespace-validation-kind
        poo-flow-boundary-namespace-validation-schema
        poo-flow-boundary-namespace-validation-descriptor
        poo-flow-boundary-namespace-validation-valid
        poo-flow-boundary-namespace-validation-diagnostics
        poo-flow-boundary-namespace-validation-type-facts
        poo-flow-boundary-namespace-validation-lean-fact-contracts
        poo-flow-boundary-namespace-validation-valid?
        poo-flow-boundary-namespace-contract-validation
        poo-flow-boundary-namespace-validation->alist
        poo-flow-boundary-namespace-validation-summary
        poo-flow-boundary-namespace-agent-feedback
        poo-flow-require-boundary-namespace!)

;; : (-> Symbol String PooFlowDiagnosticValue PooFlowObservabilityDiagnostic)
(def (poo-flow-boundary-namespace-diagnostic code message value)
  (poo-flow-observability-diagnostic-record
   'error
   'contract
   'boundary-namespace-validator
   'boundary-namespace
   #f
   code
   message
   'author
   (list
    (cons 'object 'PooFlowNamespaceDescriptor)
    (cons 'value value))))

;; : (-> PooFlowNamespaceDescriptor [Alist])
(def (poo-flow-boundary-namespace-repair-layer-diagnostics descriptor)
  (let (repair-layer
        (poo-flow-namespace-descriptor-repair-layer descriptor))
    (if (or (not repair-layer)
            (poo-flow-agent-repair-boundary-layer? repair-layer))
      '()
      (list
       (poo-flow-boundary-namespace-diagnostic
        'invalid-agent-repair-layer
        "namespace repair layer must be a legal agent repair boundary"
        repair-layer)))))

;; : (-> PooFlowNamespaceDescriptor [Alist])
(def (poo-flow-category-module-namespace-diagnostics descriptor)
  (cond
   ((not (and (symbol? (poo-flow-namespace-descriptor-category descriptor))
              (symbol? (poo-flow-namespace-descriptor-module descriptor))))
    (list
     (poo-flow-boundary-namespace-diagnostic
      'invalid-category-module-namespace
      "category module namespace requires symbolic category and module names"
      descriptor)))
   ((not (poo-flow-public-category-allowed?
          (poo-flow-namespace-descriptor-category descriptor)))
    (list
     (poo-flow-boundary-namespace-diagnostic
      'disallowed-public-category
      "public category module namespace must not use stale or ambiguous categories"
      (poo-flow-namespace-descriptor-category descriptor))))
   (else '())))

;; : (-> PooFlowNamespaceDescriptor [Alist])
(def (poo-flow-boundary-namespace-local-diagnostics descriptor)
  (cond
   ((not (poo-flow-namespace-descriptor? descriptor))
    (list
     (poo-flow-boundary-namespace-diagnostic
      'namespace-descriptor-not-object
      "boundary namespace validation expects a namespace descriptor"
      descriptor)))
   ((eq? (poo-flow-namespace-descriptor-kind descriptor) 'boundary)
    (let (boundary-diagnostics
          (if (poo-flow-boundary-layer?
               (poo-flow-namespace-descriptor-boundary descriptor))
            '()
            (list
             (poo-flow-boundary-namespace-diagnostic
              'unknown-boundary-layer
              "boundary namespace must use a canonical P0 boundary layer"
              (poo-flow-namespace-descriptor-boundary descriptor)))))
      (append boundary-diagnostics
              (poo-flow-boundary-namespace-repair-layer-diagnostics
               descriptor))))
   ((eq? (poo-flow-namespace-descriptor-kind descriptor) 'category-module)
    (let (category-diagnostics
          (poo-flow-category-module-namespace-diagnostics descriptor))
      (append category-diagnostics
              (poo-flow-boundary-namespace-repair-layer-diagnostics
               descriptor))))
   (else
    (list
     (poo-flow-boundary-namespace-diagnostic
      'unknown-namespace-kind
      "namespace descriptor kind must be boundary or category-module"
      (poo-flow-namespace-descriptor-kind descriptor))))))

;; poo-flow-boundary-namespace-validation
;;   : (-> String String PooFlowNamespaceDescriptor Boolean [PooFlowObservabilityDiagnostic] [PooFlowTypeFactContract] [PooFlowLeanFactContract] PooFlowBoundaryNamespaceValidation)
;;   | doc m%
;;       Fixed validation receipt row for one namespace descriptor.
;;       Constructor and accessors are generated by defstruct; all public
;;       projection leaves through `poo-flow-boundary-namespace-validation->alist`.
;;     %
(defstruct poo-flow-boundary-namespace-validation
  (kind
   schema
   descriptor
   valid
   diagnostics
   type-facts
   lean-fact-contracts)
  transparent: #t)

;; : (-> PooFlowBoundaryNamespaceValidation Boolean)
(def (poo-flow-boundary-namespace-validation-valid? validation)
  (and (poo-flow-boundary-namespace-validation? validation)
       (poo-flow-boundary-namespace-validation-valid validation)))

;; : (-> PooFlowNamespaceDescriptor PooFlowBoundaryNamespaceValidation)
(def (poo-flow-boundary-namespace-contract-validation descriptor)
  (let* ((diagnostics
          (poo-flow-boundary-namespace-local-diagnostics descriptor))
         (valid? (null? diagnostics)))
    (make-poo-flow-boundary-namespace-validation
     "poo-flow-boundary-namespace-validation"
     "poo-flow-boundary-namespace-validation/v1"
     descriptor
     valid?
     diagnostics
     (list
      (poo-flow-type-fact
       'boundary.namespace/boundary-layer
       'slot-contract
       'PooFlowNamespaceDescriptor
       'boundaryLayer
       'boundary
       'Symbol
       'positive
       '((scope . boundary) (required-for . boundary-namespace)))
      (poo-flow-type-fact
       'boundary.namespace/category-module
       'slot-contract
       'PooFlowNamespaceDescriptor
       'categoryModule
       'category
       'Symbol
       'positive
       '((scope . boundary) (required-for . category-module)))
      (poo-flow-type-fact
       'boundary.namespace/repair-layer
       'slot-contract
       'PooFlowNamespaceDescriptor
       'repairLayer
       'repair-layer
       'Symbol
       'positive
       '((scope . boundary) (agent-visible . #t))))
     (list
      (poo-flow-lean-fact
       'boundary.namespace/runtime-not-semantic-owner
       'fact
       'BoundaryNamespace.BoundaryFact
       'runtimeNotSemanticOwner
       'runtime
       'negative
       '((scope . boundary)))
      (poo-flow-lean-fact
       'boundary.namespace/projection-not-source-owner
       'fact
       'BoundaryNamespace.BoundaryFact
       'projectionNotSourceOwner
       'projection
       'negative
       '((scope . boundary)))))))

;; : (forall (v) (-> v [(Pair Symbol Object)]))
;; : (-> PooFlowBoundaryNamespaceValidation Alist)
(def (poo-flow-boundary-namespace-validation->alist validation)
  (list
   (cons 'kind (poo-flow-boundary-namespace-validation-kind validation))
   (cons 'schema (poo-flow-boundary-namespace-validation-schema validation))
   (cons 'valid (poo-flow-boundary-namespace-validation-valid validation))
   (cons 'descriptor
         (if (poo-flow-namespace-descriptor?
              (poo-flow-boundary-namespace-validation-descriptor validation))
           (poo-flow-namespace-descriptor->alist
            (poo-flow-boundary-namespace-validation-descriptor validation))
           (poo-flow-boundary-namespace-validation-descriptor validation)))
   (cons 'diagnostics
         (map poo-flow-observability-diagnostic->alist
              (poo-flow-boundary-namespace-validation-diagnostics
               validation)))
   (cons 'diagnostic-count
         (length (poo-flow-boundary-namespace-validation-diagnostics
                  validation)))
   (cons 'type-facts
         (map poo-flow-type-fact-contract->alist
              (poo-flow-boundary-namespace-validation-type-facts
               validation)))
   (cons 'lean-fact-contracts
         (map poo-flow-lean-fact-contract->alist
              (poo-flow-boundary-namespace-validation-lean-fact-contracts
               validation)))))

;; : (-> PooFlowBoundaryNamespaceValidation [Symbol])
(def (poo-flow-boundary-namespace-validation-diagnostic-codes validation)
  (map poo-flow-observability-diagnostic-code
       (poo-flow-boundary-namespace-validation-diagnostics validation)))

;; : (-> PooFlowBoundaryNamespaceValidation Alist)
(def (poo-flow-boundary-namespace-validation-summary validation)
  (let ((descriptor
         (poo-flow-boundary-namespace-validation-descriptor validation))
        (diagnostics
         (poo-flow-boundary-namespace-validation-diagnostics validation)))
    (list
     (cons 'kind 'poo-flow-boundary-namespace-summary)
     (cons 'valid?
           (poo-flow-boundary-namespace-validation-valid? validation))
     (cons 'namespace
           (and (poo-flow-namespace-descriptor? descriptor)
                (poo-flow-namespace-descriptor->symbol descriptor)))
     (cons 'diagnostic-count (length diagnostics))
     (cons 'diagnostic-codes
           (poo-flow-boundary-namespace-validation-diagnostic-codes
           validation)))))

;; : (-> Boolean (Or Symbol False))
(def (poo-flow-boundary-namespace-feedback-repair-layer valid?)
  (if valid? #f 'author))

;; : (-> Boolean (Or Symbol False))
(def (poo-flow-boundary-namespace-feedback-repair-target valid?)
  (if valid? #f 'boundary-namespace-declaration))

;; : (-> Boolean Symbol)
(def (poo-flow-boundary-namespace-feedback-readiness-state valid?)
  (if valid? 'ready 'blocked))

;; : (-> PooFlowBoundaryNamespaceValidation Alist)
(def (poo-flow-boundary-namespace-agent-feedback validation)
  (let* ((summary
          (poo-flow-boundary-namespace-validation-summary validation))
         (valid?
          (poo-flow-boundary-namespace-validation-valid? validation))
         (receipt
          (poo-flow-observability-feedback-receipt
           "poo-flow-boundary-namespace-agent-feedback/v1"
           'boundary-namespace
           (poo-flow-observability-graph 'boundary-namespace summary)
           (poo-flow-boundary-namespace-validation-diagnostics validation)
           (poo-flow-observability-repair
            (poo-flow-boundary-namespace-feedback-repair-layer valid?)
            (poo-flow-boundary-namespace-feedback-repair-target valid?))
           (poo-flow-observability-readiness
            (poo-flow-boundary-namespace-feedback-readiness-state valid?)
            valid?)
           (list
            (cons 'validation
                  (poo-flow-boundary-namespace-validation->alist
                   validation))))))
    (poo-flow-observability-agent-feedback
     'poo-flow-agent-feedback
     'accept-boundary-namespace
     'repair-boundary-namespace
     receipt)))

;; : (-> PooFlowNamespaceDescriptor PooFlowNamespaceDescriptor)
(def (poo-flow-require-boundary-namespace! descriptor)
  (let (validation (poo-flow-boundary-namespace-contract-validation descriptor))
    (if (poo-flow-boundary-namespace-validation-valid? validation)
      descriptor
      (error "boundary namespace failed validation" validation))))
