;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: load! fixture module objects are integration validation cases.
;;; Invariant: unit receipt-shape tests do not import fixture packages.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :clan/poo/object .ref object?)
        (only-in :std/test
                 test-suite
                 check-equal?)
        :yuanxu/module-system/schema/interface
        :yuanxu/module-system/schema/validation
        "./fixtures/object-load-valid/objects")

(export module-object-load-validation-test)

;; : (-> POOObject Symbol Value)
(def (receipt-ref receipt key)
  (.ref receipt key))

;; : TestSuite
(def module-object-load-validation-test
  (test-suite "agentic-ai-lab module object load validation"
    (yuanxu-test-case "validates loaded objects with native Core contracts"
      (let* ((objects agentic-ai-lab-custom-module-object1-module)
             (validation
              (yuanxu-module-object-validation (car objects)))
             (field-validations
              (receipt-ref validation 'fieldContractValidations))
             (typed-field-validation
              (cadr field-validations))
             (value-kind
              (receipt-ref typed-field-validation 'valueKind)))
        (check-equal? (length objects) 1)
        (check-equal? (yuanxu-module-object-identity (car objects))
                      'objects.fixture.loaded)
        (check-equal? (yuanxu-module-object-validation-valid? validation)
                      #t)
        (check-equal? (and (object? validation)
                           (andmap object? field-validations)
                           (yuanxu-module-field-contract-validation-valid?
                            typed-field-validation))
                      #t)
        (check-equal? value-kind 'List)))))
