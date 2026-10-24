;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Contract: native POO Contracts project into type-fact proof rows.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test)

;; : (-> AgenticAILabTypeFactsProjectionExpr AgenticAILabTypeFactsProjectionValue)
(def (type-facts-projection-eval expr)
  (eval expr))

;; : (-> Alist Symbol AgenticAILabTypeFactsProjectionValue AgenticAILabTypeFactsProjectionValue)
(def (alist-ref/default entries key default-value)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default-value)))

(export type-facts-contract-projection-test)

(def type-facts-contract-projection-test
  (test-suite "type-facts-contract-projection-test"
    (yuanxu-test-case "validates the native contract"
      (eval '(import :yuanxu/module-system/schema/slot-contracts))
      (eval '(import "./core/type-facts/objects.ss"))
      (eval '(import :clan/poo/object :clan/poo/mop))
      (type-facts-projection-eval
 '(begin
    (def +type-facts-fixture-name-slot+
      (yuanxu-contract-slot
       'type-facts.fixture/name
       'name
       (yuanxu-contract-value-type 'Symbol symbol? 'Symbol 'symbol?)
       #t
       '((slot . name))))
    (def +type-facts-fixture-tags-slot+
      (yuanxu-contract-slot
       'type-facts.fixture/tags
       'tags
       (yuanxu-contract-value-type 'List list? 'List 'list?)
       #f
       '((slot . tags))))
    (def +type-facts-fixture-contract+
      (yuanxu-object-contract
       'type-facts/fixture
       'type-facts
       'AgenticAILabTypeFactsFixture
       object?
       (list +type-facts-fixture-name-slot+
             +type-facts-fixture-tags-slot+)
       '((projection . type-facts-test))))))

(let* ((rows
        (type-facts-projection-eval
         '(map yuanxu-type-fact-contract->alist
               (yuanxu-object-contract->type-facts
                +type-facts-fixture-contract+))))
       (name-row (car rows))
       (tags-row (cadr rows))
       (name-metadata (alist-ref/default name-row 'metadata '())))
  (unless (and (= (length rows) 2)
               (eq? (alist-ref/default name-row 'owner #f)
                    'AgenticAILabTypeFactsFixture)
               (eq? (alist-ref/default name-row 'source-slot #f) 'name)
               (eq? (alist-ref/default name-row 'value-kind #f) 'Symbol)
               (eq? (alist-ref/default name-row 'polarity #f) 'positive)
               (eq? (alist-ref/default tags-row 'polarity #f) 'optional)
               (eq? (alist-ref/default name-metadata 'predicate #f) 'symbol?)
               (eq? (alist-ref/default name-metadata 'required? #f) #t))
    (error "object contract should project stable type facts")))

(let* ((rows
        (type-facts-projection-eval
         '(map yuanxu-lean-fact-contract->alist
               (yuanxu-object-contract->lean-fact-contracts
                +type-facts-fixture-contract+))))
       (name-row (car rows))
       (tags-row (cadr rows)))
  (unless (and (= (length rows) 2)
               (eq? (alist-ref/default name-row 'kind #f) 'slot-contract)
               (eq? (alist-ref/default name-row 'lean-owner #f)
                    'AgenticAILabTypeFactsFixture)
               (eq? (alist-ref/default name-row 'lean-name #f) 'name)
               (eq? (alist-ref/default name-row 'source-slot #f) 'name)
               (eq? (alist-ref/default tags-row 'polarity #f) 'optional))
    (error "object contract should project stable Lean fact contracts"))))))
