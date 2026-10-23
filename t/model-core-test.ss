;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :clan/poo/object
        (only-in :clan/poo/mop element?)
        :poo-flow/modules/model-core/interface)

(def (model-core-test-row-ref row key)
  (let (entry (assq key row))
    (and entry (cdr entry))))

(export model-core-test)

(def model-core-test
  (test-suite "model core"
    (yuanxu-test-case "model specs expose POO-native accessors and projections"
      (check-equal? (element? PooFlowModelSpec
                              poo-flow-model-core-tool-json-model)
                    #t)
      (check-equal?
       (element? PooFlowModelSpec
                 (.o kind: +poo-flow-model-core-spec-kind+
                     model-ref: 'missing-contract-fields))
       #f)
      (check-equal? (poo-flow-model-spec-ref poo-flow-model-core-tool-json-model)
                    'tool-json)
      (check-equal? (poo-flow-model-spec-provider poo-flow-model-core-tool-json-model)
                    'runtime-local)
      (check-equal? (poo-flow-model-spec-model-id poo-flow-model-core-tool-json-model)
                    "local-tool-json")
      (check-equal? (poo-flow-model-spec-capabilities poo-flow-model-core-tool-json-model)
                    '(chat text json tool-calling))
      (check-equal? (model-core-test-row-ref
                     (poo-flow-model-spec->alist
                      poo-flow-model-core-tool-json-model)
                     'runtime-executed)
                    #f))
    (yuanxu-test-case "model catalog summarizes refs without runtime execution"
      (check-equal? (element? PooFlowModelCatalog
                              poo-flow-model-core-default-catalog)
                    #t)
      (check-equal? (poo-flow-model-catalog-ref poo-flow-model-core-default-catalog)
                    'model-core-default)
      (check-equal? (poo-flow-model-catalog-model-refs
                     poo-flow-model-core-default-catalog)
                    '(fast-text tool-json))
      (check-equal? (poo-flow-model-catalog-model-count
                     poo-flow-model-core-default-catalog)
                    2)
      (check-equal? (poo-flow-model-spec-ref
                     (poo-flow-model-catalog-find
                      poo-flow-model-core-default-catalog
                      'fast-text))
                    'fast-text))
    (yuanxu-test-case "selection policy chooses the first compatible model"
      (check-equal? (element? PooFlowModelSelectionPolicy
                              poo-flow-model-core-default-selection-policy)
                    #t)
      (def receipt
        (poo-flow-model-select
         poo-flow-model-core-default-selection-policy
         poo-flow-model-core-default-catalog))
      (check-equal? (poo-flow-model-selection-receipt-valid? receipt)
                    #t)
      (check-equal? (element? PooFlowModelSelectionReceipt receipt) #t)
      (check-equal? (poo-flow-model-selection-receipt-selected-model-ref receipt)
                    'tool-json)
      (check-equal? (poo-flow-model-selection-receipt-diagnostics receipt)
                    '())
      (check-equal? (model-core-test-row-ref
                     (poo-flow-model-selection-receipt->alist receipt)
                     'runtime-executed)
                    #f))
    (yuanxu-test-case "selection policy records diagnostics before fallback"
      (def small-catalog
        (poo-flow-model-catalog
         'small
         (list poo-flow-model-core-fast-text-model)))
      (def policy
        (poo-flow-model-selection-policy
         'needs-json
         '(missing tool-json)
         'fast-text
         '(chat text)
         'first-compatible
         '()))
      (def receipt (poo-flow-model-select policy small-catalog))
      (check-equal? (poo-flow-model-selection-receipt-valid? receipt)
                    #t)
      (check-equal? (poo-flow-model-selection-receipt-selected-model-ref receipt)
                    'fast-text)
      (check-equal? (model-core-test-row-ref
                     (car (poo-flow-model-selection-receipt-diagnostics receipt))
                     'reason)
                    'missing-model))))
