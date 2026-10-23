;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :clan/poo/object
        (only-in :clan/poo/mop element?)
        :agentic-ai-lab/modules/model-core/interface)

(def (model-core-test-row-ref row key)
  (let (entry (assq key row))
    (and entry (cdr entry))))

(export model-core-test)

(def model-core-test
  (test-suite "model core"
    (yuanxu-test-case "model specs expose POO-native accessors and projections"
      (check-equal? (element? AgenticAILabModelSpec
                              agentic-ai-lab-model-core-tool-json-model)
                    #t)
      (check-equal?
       (element? AgenticAILabModelSpec
                 (.o kind: +agentic-ai-lab-model-core-spec-kind+
                     model-ref: 'missing-contract-fields))
       #f)
      (check-equal? (agentic-ai-lab-model-spec-ref agentic-ai-lab-model-core-tool-json-model)
                    'tool-json)
      (check-equal? (agentic-ai-lab-model-spec-provider agentic-ai-lab-model-core-tool-json-model)
                    'runtime-local)
      (check-equal? (agentic-ai-lab-model-spec-model-id agentic-ai-lab-model-core-tool-json-model)
                    "local-tool-json")
      (check-equal? (agentic-ai-lab-model-spec-capabilities agentic-ai-lab-model-core-tool-json-model)
                    '(chat text json tool-calling))
      (check-equal? (model-core-test-row-ref
                     (agentic-ai-lab-model-spec->alist
                      agentic-ai-lab-model-core-tool-json-model)
                     'runtime-executed)
                    #f))
    (yuanxu-test-case "model catalog summarizes refs without runtime execution"
      (check-equal? (element? AgenticAILabModelCatalog
                              agentic-ai-lab-model-core-default-catalog)
                    #t)
      (check-equal? (agentic-ai-lab-model-catalog-ref agentic-ai-lab-model-core-default-catalog)
                    'model-core-default)
      (check-equal? (agentic-ai-lab-model-catalog-model-refs
                     agentic-ai-lab-model-core-default-catalog)
                    '(fast-text tool-json))
      (check-equal? (agentic-ai-lab-model-catalog-model-count
                     agentic-ai-lab-model-core-default-catalog)
                    2)
      (check-equal? (agentic-ai-lab-model-spec-ref
                     (agentic-ai-lab-model-catalog-find
                      agentic-ai-lab-model-core-default-catalog
                      'fast-text))
                    'fast-text))
    (yuanxu-test-case "selection policy chooses the first compatible model"
      (check-equal? (element? AgenticAILabModelSelectionPolicy
                              agentic-ai-lab-model-core-default-selection-policy)
                    #t)
      (def receipt
        (agentic-ai-lab-model-select
         agentic-ai-lab-model-core-default-selection-policy
         agentic-ai-lab-model-core-default-catalog))
      (check-equal? (agentic-ai-lab-model-selection-receipt-valid? receipt)
                    #t)
      (check-equal? (element? AgenticAILabModelSelectionReceipt receipt) #t)
      (check-equal? (agentic-ai-lab-model-selection-receipt-selected-model-ref receipt)
                    'tool-json)
      (check-equal? (agentic-ai-lab-model-selection-receipt-diagnostics receipt)
                    '())
      (check-equal? (model-core-test-row-ref
                     (agentic-ai-lab-model-selection-receipt->alist receipt)
                     'runtime-executed)
                    #f))
    (yuanxu-test-case "selection policy records diagnostics before fallback"
      (def small-catalog
        (agentic-ai-lab-model-catalog
         'small
         (list agentic-ai-lab-model-core-fast-text-model)))
      (def policy
        (agentic-ai-lab-model-selection-policy
         'needs-json
         '(missing tool-json)
         'fast-text
         '(chat text)
         'first-compatible
         '()))
      (def receipt (agentic-ai-lab-model-select policy small-catalog))
      (check-equal? (agentic-ai-lab-model-selection-receipt-valid? receipt)
                    #t)
      (check-equal? (agentic-ai-lab-model-selection-receipt-selected-model-ref receipt)
                    'fast-text)
      (check-equal? (model-core-test-row-ref
                     (car (agentic-ai-lab-model-selection-receipt-diagnostics receipt))
                     'reason)
                    'missing-model))))
