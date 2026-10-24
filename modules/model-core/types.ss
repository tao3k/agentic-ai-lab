;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: model-core value kinds and closed shape contracts.
;;; Invariant: this owner defines admission only; construction and selection
;;; behavior belong to objects.ss and funs.ss respectively.

(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :std/list/list every))

(export +agentic-ai-lab-model-core-spec-kind+
        +agentic-ai-lab-model-core-catalog-kind+
        +agentic-ai-lab-model-core-selection-policy-kind+
        +agentic-ai-lab-model-core-selection-receipt-kind+
        AgenticAILabModelSpec AgenticAILabModelCatalog
        AgenticAILabModelSelectionPolicy AgenticAILabModelSelectionReceipt
        agentic-ai-lab-model-spec-value? agentic-ai-lab-model-catalog-value?
        agentic-ai-lab-model-selection-policy-value?
        agentic-ai-lab-model-selection-receipt-value?)

(def +agentic-ai-lab-model-core-spec-kind+ 'agentic-ai-lab-model-core-spec)
(def +agentic-ai-lab-model-core-catalog-kind+ 'agentic-ai-lab-model-core-catalog)
(def +agentic-ai-lab-model-core-selection-policy-kind+
  'agentic-ai-lab-model-core-selection-policy)
(def +agentic-ai-lab-model-core-selection-receipt-kind+
  'agentic-ai-lab-model-core-selection-receipt)

(def (model-value-has-slots? value slots)
  (and (object? value)
       (every (lambda (slot) (.slot? value slot)) slots)))

(def (model-value-kind? value kind slots)
  (and (model-value-has-slots? value (cons 'kind slots))
       (eq? (.ref value 'kind) kind)))

(def (model-symbol-list? value)
  (and (list? value) (every symbol? value)))

(def (agentic-ai-lab-model-spec-shape? value)
  (and (model-value-kind?
        value +agentic-ai-lab-model-core-spec-kind+
        '(schema model-ref provider model-id capabilities modalities
          context-window max-output-tokens runtime-owner handoff-operation
          runtime-backend runtime-executed metadata))
       (symbol? (.ref value 'model-ref))
       (symbol? (.ref value 'provider))
       (string? (.ref value 'model-id))
       (model-symbol-list? (.ref value 'capabilities))
       (model-symbol-list? (.ref value 'modalities))
       (exact-integer? (.ref value 'context-window))
       (> (.ref value 'context-window) 0)
       (exact-integer? (.ref value 'max-output-tokens))
       (> (.ref value 'max-output-tokens) 0)
       (string? (.ref value 'runtime-owner))
       (symbol? (.ref value 'handoff-operation))
       (symbol? (.ref value 'runtime-backend))
       (eq? (.ref value 'runtime-executed) #f)))

(define-type (AgenticAILabModelSpec @ Type.)
  .element?: agentic-ai-lab-model-spec-shape?)

(def (agentic-ai-lab-model-catalog-shape? value)
  (and (model-value-kind?
        value +agentic-ai-lab-model-core-catalog-kind+
        '(schema catalog-ref models model-refs model-count runtime-owner
          runtime-executed metadata))
       (symbol? (.ref value 'catalog-ref))
       (list? (.ref value 'models))
       (every (lambda (model) (element? AgenticAILabModelSpec model))
              (.ref value 'models))
       (equal? (.ref value 'model-refs)
               (map (lambda (model) (.ref model 'model-ref))
                    (.ref value 'models)))
       (= (.ref value 'model-count) (length (.ref value 'models)))
       (eq? (.ref value 'runtime-executed) #f)))

(define-type (AgenticAILabModelCatalog @ Type.)
  .element?: agentic-ai-lab-model-catalog-shape?)

(def (agentic-ai-lab-model-selection-policy-shape? value)
  (and (model-value-kind?
        value +agentic-ai-lab-model-core-selection-policy-kind+
        '(schema policy-ref candidate-model-refs fallback-model-ref
          required-capabilities routing-strategy budget-policy runtime-owner
          runtime-executed metadata))
       (symbol? (.ref value 'policy-ref))
       (model-symbol-list? (.ref value 'candidate-model-refs))
       (or (not (.ref value 'fallback-model-ref))
           (symbol? (.ref value 'fallback-model-ref)))
       (model-symbol-list? (.ref value 'required-capabilities))
       (symbol? (.ref value 'routing-strategy))
       (list? (.ref value 'budget-policy))
       (every pair? (.ref value 'budget-policy))
       (eq? (.ref value 'runtime-executed) #f)))

(define-type (AgenticAILabModelSelectionPolicy @ Type.)
  .element?: agentic-ai-lab-model-selection-policy-shape?)

(def (agentic-ai-lab-model-selection-receipt-shape? value)
  (and (model-value-kind?
        value +agentic-ai-lab-model-core-selection-receipt-kind+
        '(schema policy-ref catalog-ref valid? selected-model-ref
          selected-model diagnostics runtime-executed))
       (boolean? (.ref value 'valid?))
       (or (not (.ref value 'selected-model-ref))
           (symbol? (.ref value 'selected-model-ref)))
       (list? (.ref value 'diagnostics))
       (eq? (.ref value 'runtime-executed) #f)))

(define-type (AgenticAILabModelSelectionReceipt @ Type.)
  .element?: agentic-ai-lab-model-selection-receipt-shape?)

(def (agentic-ai-lab-model-spec-value? value)
  (element? AgenticAILabModelSpec value))
(def (agentic-ai-lab-model-catalog-value? value)
  (element? AgenticAILabModelCatalog value))
(def (agentic-ai-lab-model-selection-policy-value? value)
  (element? AgenticAILabModelSelectionPolicy value))
(def (agentic-ai-lab-model-selection-receipt-value? value)
  (element? AgenticAILabModelSelectionReceipt value))
