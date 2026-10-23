;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: declarative model catalog, policy, and receipt POO values;
;;; provider invocation and runtime routing stay behind the handoff boundary.
(export +agentic-ai-lab-model-core-spec-kind+
        +agentic-ai-lab-model-core-catalog-kind+
        +agentic-ai-lab-model-core-selection-policy-kind+
        +agentic-ai-lab-model-core-selection-receipt-kind+
        agentic-ai-lab-model-field-rows
        agentic-ai-lab-model-symbol-list?
        agentic-ai-lab-model-alist?
        agentic-ai-lab-model-spec
        agentic-ai-lab-model-spec?
        agentic-ai-lab-model-spec-ref
        agentic-ai-lab-model-spec-provider
        agentic-ai-lab-model-spec-model-id
        agentic-ai-lab-model-spec-capabilities
        agentic-ai-lab-model-spec-modalities
        agentic-ai-lab-model-spec-context-window
        agentic-ai-lab-model-spec-max-output-tokens
        agentic-ai-lab-model-spec->alist
        agentic-ai-lab-model-catalog
        agentic-ai-lab-model-catalog?
        agentic-ai-lab-model-catalog-ref
        agentic-ai-lab-model-catalog-model-refs
        agentic-ai-lab-model-catalog-model-count
        agentic-ai-lab-model-selection-policy
        agentic-ai-lab-model-selection-policy?
        agentic-ai-lab-model-selection-policy-ref
        agentic-ai-lab-model-selection-policy-candidate-model-refs
        agentic-ai-lab-model-selection-policy-required-capabilities
        agentic-ai-lab-model-selection-receipt
        agentic-ai-lab-model-selection-receipt?
        agentic-ai-lab-model-selection-receipt-valid?
        agentic-ai-lab-model-selection-receipt-selected-model-ref
        agentic-ai-lab-model-selection-receipt-diagnostics
        agentic-ai-lab-model-selection-receipt->alist)

(import (only-in :clan/poo/object .ref object<-alist)
        :yuanxu/object-family/syntax
        :agentic-ai-lab/modules/model-core/types
        :agentic-ai-lab/modules/session/policy
        (only-in :agentic-ai-lab/modules/session/objects-core
                 agentic-ai-lab-session-every?
                 agentic-ai-lab-session-require))

;; agentic-ai-lab-model-field-rows
;;   : (-> FieldRow... Alist)
;;   | doc m%
;;       `agentic-ai-lab-model-field-rows` constructs ordered model object fields.
;;
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-model-field-rows (model-ref primary) (valid? #t))
;;       ;; => ((model-ref . primary) (valid? . #t))
;;       ```
;;     %
(defrules agentic-ai-lab-model-field-rows ()
  ((_ (field value) ...)
   (list (cons 'field value) ...)))

;; : (-> Object Boolean)
(def (agentic-ai-lab-model-symbol-list? value)
  (and (list? value)
       (agentic-ai-lab-session-every? symbol? value)))

;; : (-> Object Boolean)
(def (agentic-ai-lab-model-alist? value)
  (and (list? value)
       (agentic-ai-lab-session-every? pair? value)))

;; : (-> Object Boolean)
(def (agentic-ai-lab-model-positive-integer? value)
  (and (integer? value)
       (> value 0)))

;; : (-> Object Boolean)
(def (agentic-ai-lab-model-optional-symbol? value)
  (or (not value)
      (symbol? value)))

;; : (-> Symbol Symbol String [Symbol] [Symbol] Integer Integer String Symbol Symbol [Alist] PooModelSpec)
(def (agentic-ai-lab-model-spec model-ref
                          provider
                          model-id
                          capabilities
                          modalities
                          context-window
                          max-output-tokens
                          runtime-owner
                          handoff-operation
                          runtime-backend
                          . maybe-metadata)
  (agentic-ai-lab-session-require "model ref must be a symbol"
                            (symbol? model-ref)
                            model-ref)
  (agentic-ai-lab-session-require "model provider must be a symbol"
                            (symbol? provider)
                            provider)
  (agentic-ai-lab-session-require "model id must be a string"
                            (string? model-id)
                            model-id)
  (agentic-ai-lab-session-require "model capabilities must be symbols"
                            (agentic-ai-lab-model-symbol-list? capabilities)
                            capabilities)
  (agentic-ai-lab-session-require "model modalities must be symbols"
                            (agentic-ai-lab-model-symbol-list? modalities)
                            modalities)
  (agentic-ai-lab-session-require "model context window must be a positive integer"
                            (agentic-ai-lab-model-positive-integer? context-window)
                            context-window)
  (agentic-ai-lab-session-require "model max output tokens must be a positive integer"
                            (agentic-ai-lab-model-positive-integer? max-output-tokens)
                            max-output-tokens)
  (agentic-ai-lab-session-require "model runtime owner must be a string"
                            (string? runtime-owner)
                            runtime-owner)
  (agentic-ai-lab-session-require "model handoff operation must be a symbol"
                            (symbol? handoff-operation)
                            handoff-operation)
  (agentic-ai-lab-session-require "model runtime backend must be a symbol"
                            (symbol? runtime-backend)
                            runtime-backend)
  (object<-alist
   (list
    (cons 'kind +agentic-ai-lab-model-core-spec-kind+)
    (cons 'schema 'agentic-ai-lab.modules.model-core.spec.v1)
    (cons 'model-ref model-ref)
    (cons 'provider provider)
    (cons 'model-id model-id)
    (cons 'capabilities capabilities)
    (cons 'modalities modalities)
    (cons 'context-window context-window)
    (cons 'max-output-tokens max-output-tokens)
    (cons 'runtime-owner runtime-owner)
    (cons 'handoff-operation handoff-operation)
    (cons 'runtime-backend runtime-backend)
    (cons 'runtime-executed #f)
    (cons 'metadata (if (null? maybe-metadata)
                      '()
                      (car maybe-metadata))))))

(defpoo-object-family +agentic-ai-lab-model-core-spec-kind+
  agentic-ai-lab-model-spec?
  (accessors
   (agentic-ai-lab-model-spec-ref model-ref)
   (agentic-ai-lab-model-spec-provider provider)
   (agentic-ai-lab-model-spec-model-id model-id)
   (agentic-ai-lab-model-spec-capabilities capabilities)
   (agentic-ai-lab-model-spec-modalities modalities)
   (agentic-ai-lab-model-spec-context-window context-window)
   (agentic-ai-lab-model-spec-max-output-tokens max-output-tokens))
  (projections
   (agentic-ai-lab-model-spec->alist
    (schema schema)
    (model-ref model-ref)
    (provider provider)
    (model-id model-id)
    (capabilities capabilities)
    (modalities modalities)
    (context-window context-window)
    (max-output-tokens max-output-tokens)
    (runtime-owner runtime-owner)
    (handoff-operation handoff-operation)
    (runtime-backend runtime-backend)
    (runtime-executed runtime-executed)
    (metadata metadata))))

;; : (-> [PooModelSpec] (Values [Symbol] Integer))
(def (agentic-ai-lab-model-catalog-summary models)
  (values (map agentic-ai-lab-model-spec-ref models) (length models)))

;; : (-> Symbol [PooModelSpec] [Alist] PooModelCatalog)
(def (agentic-ai-lab-model-catalog catalog-ref models . maybe-metadata)
  (agentic-ai-lab-session-require "model catalog ref must be a symbol"
                            (symbol? catalog-ref)
                            catalog-ref)
  (agentic-ai-lab-session-require "model catalog models must be model specs"
                            (agentic-ai-lab-session-every? agentic-ai-lab-model-spec?
                                                     models)
                            models)
  (let-values (((model-refs model-count)
                (agentic-ai-lab-model-catalog-summary models)))
    (object<-alist
     (list
      (cons 'kind +agentic-ai-lab-model-core-catalog-kind+)
      (cons 'schema 'agentic-ai-lab.modules.model-core.catalog.v1)
      (cons 'catalog-ref catalog-ref)
      (cons 'models models)
      (cons 'model-refs model-refs)
      (cons 'model-count model-count)
      (cons 'runtime-owner "runtime-model-adapter")
      (cons 'runtime-executed #f)
      (cons 'metadata (if (null? maybe-metadata)
                        '()
                        (car maybe-metadata)))))))

(defpoo-object-family +agentic-ai-lab-model-core-catalog-kind+
  agentic-ai-lab-model-catalog?
  (accessors
   (agentic-ai-lab-model-catalog-ref catalog-ref)
   (agentic-ai-lab-model-catalog-model-refs model-refs)
   (agentic-ai-lab-model-catalog-model-count model-count))
  (projections))

;; : (-> Symbol [Symbol] MaybeSymbol [Symbol] Symbol Alist [Alist] PooModelSelectionPolicy)
(def (agentic-ai-lab-model-selection-policy policy-ref
                                      candidate-model-refs
                                      fallback-model-ref
                                      required-capabilities
                                      routing-strategy
                                      budget-policy
                                      . maybe-metadata)
  (agentic-ai-lab-session-require "model selection policy ref must be a symbol"
                            (symbol? policy-ref)
                            policy-ref)
  (agentic-ai-lab-session-require "model selection candidates must be symbols"
                            (agentic-ai-lab-model-symbol-list? candidate-model-refs)
                            candidate-model-refs)
  (agentic-ai-lab-session-require "model selection fallback must be false or a symbol"
                            (agentic-ai-lab-model-optional-symbol? fallback-model-ref)
                            fallback-model-ref)
  (agentic-ai-lab-session-require "model selection required capabilities must be symbols"
                            (agentic-ai-lab-model-symbol-list? required-capabilities)
                            required-capabilities)
  (agentic-ai-lab-session-require "model routing strategy must be a symbol"
                            (symbol? routing-strategy)
                            routing-strategy)
  (agentic-ai-lab-session-require "model budget policy must be an alist"
                            (agentic-ai-lab-model-alist? budget-policy)
                            budget-policy)
  (object<-alist
   (list
    (cons 'kind +agentic-ai-lab-model-core-selection-policy-kind+)
    (cons 'schema 'agentic-ai-lab.modules.model-core.selection-policy.v1)
    (cons 'policy-ref policy-ref)
    (cons 'candidate-model-refs candidate-model-refs)
    (cons 'fallback-model-ref fallback-model-ref)
    (cons 'required-capabilities required-capabilities)
    (cons 'routing-strategy routing-strategy)
    (cons 'budget-policy budget-policy)
    (cons 'runtime-owner "runtime-model-adapter")
    (cons 'runtime-executed #f)
    (cons 'metadata (if (null? maybe-metadata)
                      '()
                      (car maybe-metadata))))))

(defpoo-object-family +agentic-ai-lab-model-core-selection-policy-kind+
  agentic-ai-lab-model-selection-policy?
  (accessors
   (agentic-ai-lab-model-selection-policy-ref policy-ref)
   (agentic-ai-lab-model-selection-policy-candidate-model-refs candidate-model-refs)
   (agentic-ai-lab-model-selection-policy-required-capabilities required-capabilities))
  (projections))

;; : (-> PooModelSelectionPolicy PooModelCatalog Boolean MaybeModelSpec [Alist] PooModelSelectionReceipt)
(def (agentic-ai-lab-model-selection-receipt policy
                                      catalog
                                      valid?
                                      selected-model
                                      diagnostics)
  (object<-alist
   (agentic-ai-lab-model-field-rows
    (kind +agentic-ai-lab-model-core-selection-receipt-kind+)
    (schema 'agentic-ai-lab.modules.model-core.selection-receipt.v1)
    (policy-ref (agentic-ai-lab-model-selection-policy-ref policy))
    (catalog-ref (agentic-ai-lab-model-catalog-ref catalog))
    (valid? valid?)
    (selected-model-ref
     (if selected-model (agentic-ai-lab-model-spec-ref selected-model) #f))
    (selected-model selected-model)
    (diagnostics diagnostics)
    (runtime-executed #f))))

;; : (-> Object Boolean)
(def (agentic-ai-lab-model-selection-receipt? value)
  (agentic-ai-lab-model-selection-receipt-value? value))

;; : (-> PooModelSelectionReceipt Boolean)
(def (agentic-ai-lab-model-selection-receipt-valid? receipt)
  (.ref receipt 'valid?))

;; : (-> PooModelSelectionReceipt MaybeSymbol)
(def (agentic-ai-lab-model-selection-receipt-selected-model-ref receipt)
  (.ref receipt 'selected-model-ref))

;; : (-> PooModelSelectionReceipt [Alist])
(def (agentic-ai-lab-model-selection-receipt-diagnostics receipt)
  (.ref receipt 'diagnostics))

;; : (-> PooModelSelectionReceipt Alist)
(def (agentic-ai-lab-model-selection-receipt->alist receipt)
  (agentic-ai-lab-model-field-rows
   (schema (.ref receipt 'schema))
   (policy-ref (.ref receipt 'policy-ref))
   (catalog-ref (.ref receipt 'catalog-ref))
   (valid? (.ref receipt 'valid?))
   (selected-model-ref (.ref receipt 'selected-model-ref))
   (diagnostics (.ref receipt 'diagnostics))
   (runtime-executed (.ref receipt 'runtime-executed))))
