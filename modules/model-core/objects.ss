;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: declarative model catalog, policy, and receipt POO values;
;;; provider invocation and runtime routing stay behind the handoff boundary.
(export +poo-flow-model-core-spec-kind+
        +poo-flow-model-core-catalog-kind+
        +poo-flow-model-core-selection-policy-kind+
        +poo-flow-model-core-selection-receipt-kind+
        poo-flow-model-field-rows
        poo-flow-model-symbol-list?
        poo-flow-model-alist?
        poo-flow-model-spec
        poo-flow-model-spec?
        poo-flow-model-spec-ref
        poo-flow-model-spec-provider
        poo-flow-model-spec-model-id
        poo-flow-model-spec-capabilities
        poo-flow-model-spec-modalities
        poo-flow-model-spec-context-window
        poo-flow-model-spec-max-output-tokens
        poo-flow-model-spec->alist
        poo-flow-model-catalog
        poo-flow-model-catalog?
        poo-flow-model-catalog-ref
        poo-flow-model-catalog-model-refs
        poo-flow-model-catalog-model-count
        poo-flow-model-selection-policy
        poo-flow-model-selection-policy?
        poo-flow-model-selection-policy-ref
        poo-flow-model-selection-policy-candidate-model-refs
        poo-flow-model-selection-policy-required-capabilities
        poo-flow-model-selection-receipt
        poo-flow-model-selection-receipt?
        poo-flow-model-selection-receipt-valid?
        poo-flow-model-selection-receipt-selected-model-ref
        poo-flow-model-selection-receipt-diagnostics
        poo-flow-model-selection-receipt->alist)

(import (only-in :clan/poo/object .ref object<-alist)
        :yuanxu/object-family/syntax
        :poo-flow/modules/model-core/types
        :poo-flow/modules/session/policy
        (only-in :poo-flow/modules/session/objects-core
                 poo-flow-session-every?
                 poo-flow-session-require))

;; poo-flow-model-field-rows
;;   : (-> FieldRow... Alist)
;;   | doc m%
;;       `poo-flow-model-field-rows` constructs ordered model object fields.
;;
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-model-field-rows (model-ref primary) (valid? #t))
;;       ;; => ((model-ref . primary) (valid? . #t))
;;       ```
;;     %
(defrules poo-flow-model-field-rows ()
  ((_ (field value) ...)
   (list (cons 'field value) ...)))

;; : (-> Object Boolean)
(def (poo-flow-model-symbol-list? value)
  (and (list? value)
       (poo-flow-session-every? symbol? value)))

;; : (-> Object Boolean)
(def (poo-flow-model-alist? value)
  (and (list? value)
       (poo-flow-session-every? pair? value)))

;; : (-> Object Boolean)
(def (poo-flow-model-positive-integer? value)
  (and (integer? value)
       (> value 0)))

;; : (-> Object Boolean)
(def (poo-flow-model-optional-symbol? value)
  (or (not value)
      (symbol? value)))

;; : (-> Symbol Symbol String [Symbol] [Symbol] Integer Integer String Symbol Symbol [Alist] PooModelSpec)
(def (poo-flow-model-spec model-ref
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
  (poo-flow-session-require "model ref must be a symbol"
                            (symbol? model-ref)
                            model-ref)
  (poo-flow-session-require "model provider must be a symbol"
                            (symbol? provider)
                            provider)
  (poo-flow-session-require "model id must be a string"
                            (string? model-id)
                            model-id)
  (poo-flow-session-require "model capabilities must be symbols"
                            (poo-flow-model-symbol-list? capabilities)
                            capabilities)
  (poo-flow-session-require "model modalities must be symbols"
                            (poo-flow-model-symbol-list? modalities)
                            modalities)
  (poo-flow-session-require "model context window must be a positive integer"
                            (poo-flow-model-positive-integer? context-window)
                            context-window)
  (poo-flow-session-require "model max output tokens must be a positive integer"
                            (poo-flow-model-positive-integer? max-output-tokens)
                            max-output-tokens)
  (poo-flow-session-require "model runtime owner must be a string"
                            (string? runtime-owner)
                            runtime-owner)
  (poo-flow-session-require "model handoff operation must be a symbol"
                            (symbol? handoff-operation)
                            handoff-operation)
  (poo-flow-session-require "model runtime backend must be a symbol"
                            (symbol? runtime-backend)
                            runtime-backend)
  (object<-alist
   (list
    (cons 'kind +poo-flow-model-core-spec-kind+)
    (cons 'schema 'poo-flow.modules.model-core.spec.v1)
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

(defpoo-object-family +poo-flow-model-core-spec-kind+
  poo-flow-model-spec?
  (accessors
   (poo-flow-model-spec-ref model-ref)
   (poo-flow-model-spec-provider provider)
   (poo-flow-model-spec-model-id model-id)
   (poo-flow-model-spec-capabilities capabilities)
   (poo-flow-model-spec-modalities modalities)
   (poo-flow-model-spec-context-window context-window)
   (poo-flow-model-spec-max-output-tokens max-output-tokens))
  (projections
   (poo-flow-model-spec->alist
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
(def (poo-flow-model-catalog-summary models)
  (values (map poo-flow-model-spec-ref models) (length models)))

;; : (-> Symbol [PooModelSpec] [Alist] PooModelCatalog)
(def (poo-flow-model-catalog catalog-ref models . maybe-metadata)
  (poo-flow-session-require "model catalog ref must be a symbol"
                            (symbol? catalog-ref)
                            catalog-ref)
  (poo-flow-session-require "model catalog models must be model specs"
                            (poo-flow-session-every? poo-flow-model-spec?
                                                     models)
                            models)
  (let-values (((model-refs model-count)
                (poo-flow-model-catalog-summary models)))
    (object<-alist
     (list
      (cons 'kind +poo-flow-model-core-catalog-kind+)
      (cons 'schema 'poo-flow.modules.model-core.catalog.v1)
      (cons 'catalog-ref catalog-ref)
      (cons 'models models)
      (cons 'model-refs model-refs)
      (cons 'model-count model-count)
      (cons 'runtime-owner "runtime-model-adapter")
      (cons 'runtime-executed #f)
      (cons 'metadata (if (null? maybe-metadata)
                        '()
                        (car maybe-metadata)))))))

(defpoo-object-family +poo-flow-model-core-catalog-kind+
  poo-flow-model-catalog?
  (accessors
   (poo-flow-model-catalog-ref catalog-ref)
   (poo-flow-model-catalog-model-refs model-refs)
   (poo-flow-model-catalog-model-count model-count))
  (projections))

;; : (-> Symbol [Symbol] MaybeSymbol [Symbol] Symbol Alist [Alist] PooModelSelectionPolicy)
(def (poo-flow-model-selection-policy policy-ref
                                      candidate-model-refs
                                      fallback-model-ref
                                      required-capabilities
                                      routing-strategy
                                      budget-policy
                                      . maybe-metadata)
  (poo-flow-session-require "model selection policy ref must be a symbol"
                            (symbol? policy-ref)
                            policy-ref)
  (poo-flow-session-require "model selection candidates must be symbols"
                            (poo-flow-model-symbol-list? candidate-model-refs)
                            candidate-model-refs)
  (poo-flow-session-require "model selection fallback must be false or a symbol"
                            (poo-flow-model-optional-symbol? fallback-model-ref)
                            fallback-model-ref)
  (poo-flow-session-require "model selection required capabilities must be symbols"
                            (poo-flow-model-symbol-list? required-capabilities)
                            required-capabilities)
  (poo-flow-session-require "model routing strategy must be a symbol"
                            (symbol? routing-strategy)
                            routing-strategy)
  (poo-flow-session-require "model budget policy must be an alist"
                            (poo-flow-model-alist? budget-policy)
                            budget-policy)
  (object<-alist
   (list
    (cons 'kind +poo-flow-model-core-selection-policy-kind+)
    (cons 'schema 'poo-flow.modules.model-core.selection-policy.v1)
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

(defpoo-object-family +poo-flow-model-core-selection-policy-kind+
  poo-flow-model-selection-policy?
  (accessors
   (poo-flow-model-selection-policy-ref policy-ref)
   (poo-flow-model-selection-policy-candidate-model-refs candidate-model-refs)
   (poo-flow-model-selection-policy-required-capabilities required-capabilities))
  (projections))

;; : (-> PooModelSelectionPolicy PooModelCatalog Boolean MaybeModelSpec [Alist] PooModelSelectionReceipt)
(def (poo-flow-model-selection-receipt policy
                                      catalog
                                      valid?
                                      selected-model
                                      diagnostics)
  (object<-alist
   (poo-flow-model-field-rows
    (kind +poo-flow-model-core-selection-receipt-kind+)
    (schema 'poo-flow.modules.model-core.selection-receipt.v1)
    (policy-ref (poo-flow-model-selection-policy-ref policy))
    (catalog-ref (poo-flow-model-catalog-ref catalog))
    (valid? valid?)
    (selected-model-ref
     (if selected-model (poo-flow-model-spec-ref selected-model) #f))
    (selected-model selected-model)
    (diagnostics diagnostics)
    (runtime-executed #f))))

;; : (-> Object Boolean)
(def (poo-flow-model-selection-receipt? value)
  (poo-flow-model-selection-receipt-value? value))

;; : (-> PooModelSelectionReceipt Boolean)
(def (poo-flow-model-selection-receipt-valid? receipt)
  (.ref receipt 'valid?))

;; : (-> PooModelSelectionReceipt MaybeSymbol)
(def (poo-flow-model-selection-receipt-selected-model-ref receipt)
  (.ref receipt 'selected-model-ref))

;; : (-> PooModelSelectionReceipt [Alist])
(def (poo-flow-model-selection-receipt-diagnostics receipt)
  (.ref receipt 'diagnostics))

;; : (-> PooModelSelectionReceipt Alist)
(def (poo-flow-model-selection-receipt->alist receipt)
  (poo-flow-model-field-rows
   (schema (.ref receipt 'schema))
   (policy-ref (.ref receipt 'policy-ref))
   (catalog-ref (.ref receipt 'catalog-ref))
   (valid? (.ref receipt 'valid?))
   (selected-model-ref (.ref receipt 'selected-model-ref))
   (diagnostics (.ref receipt 'diagnostics))
   (runtime-executed (.ref receipt 'runtime-executed))))
