;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: real module object catalog validation stays out of the unit root.
;;; Invariant: catalog checks load backend object sets but never realize runtime.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :clan/poo/object .ref object?)
        (only-in :std/test
                 test-suite
                 check-equal?)
        :core/module-system/schema/interface
        :core/module-system/schema/validation
        :poo-flow/modules/sandbox-core/shared-object
        :poo-flow/modules/sandbox-core/objects
        :poo-flow/modules/workflow/scenario/configuration/root-objects
        :poo-flow/modules/nono-sandbox/objects
        :poo-flow/modules/cubeSandbox/objects
        :poo-flow/modules/docker-sandbox/objects)

(export module-object-catalog-validation-test)

;; : (-> POOObject Symbol Value)
(def (receipt-ref receipt key)
  (.ref receipt key))

;; : TestSuite
(def module-object-catalog-validation-test
  (test-suite "poo-flow module object catalog validation"
    (poo-flow-test-case "validates real module object sets"
      (let* ((objects
              (append poo-flow-shared-module-objects
                      poo-flow-sandbox-core-module-objects
                      poo-flow-user-interface-root-module-objects
                      poo-flow-nono-sandbox-module-objects
                      poo-flow-cubeSandbox-module-objects
                      poo-flow-docker-sandbox-module-objects))
             (validations
              (poo-flow-module-objects-validation objects)))
        (check-equal? (length validations) 9)
        (check-equal?
         (eq? (car validations)
              (car (poo-flow-module-objects-validation objects)))
         #t)
        (check-equal? (andmap object? validations) #t)
        (check-equal? (map poo-flow-module-object-validation-valid?
                           validations)
                      '(#t #t #t #t #t #t #t #t #t))
        (let (summary
              (poo-flow-module-objects-validation-summary validations))
          (check-equal? (object? summary) #t)
          (check-equal? (receipt-ref summary 'valid) #t)
          (check-equal? (receipt-ref summary 'invalid-count) 0)
          (check-equal? (receipt-ref summary 'object-count) 9)
          (check-equal? (receipt-ref summary 'object-identities)
                        '(objects.shared.sandbox
                          objects.sandbox-core.profile
                          objects.user-interface.shared.sandbox
                          objects.nono-sandbox.sandbox
                          objects.nono-sandbox.profile
                          objects.cubeSandbox.sandbox
                          objects.cubeSandbox.profile
                          objects.docker-sandbox.sandbox
                          objects.docker-sandbox.profile))
          (check-equal? (receipt-ref summary 'inheritance-counts)
                        '(0 1 1 1 2 1 2 1 2))
          (check-equal? (car (receipt-ref summary 'inheritance-chains))
                        '(objects.shared.sandbox))
          (check-equal? (length (receipt-ref summary 'field-origins)) 9)
          (check-equal? (length (receipt-ref summary 'validation-phases)) 9)
          (check-equal? (receipt-ref summary 'checkedSignals)
                        '(native-poo-catalog-validation))
          (check-equal? (receipt-ref summary 'descriptor-realized?) #f)
          (check-equal? (receipt-ref summary 'runtime-executed) #f))))

    (poo-flow-test-case "pins nono sandbox object binding to native FFI"
      (let ((binding-field
             (poo-flow-module-object-field poo-flow-nono-sandbox-object
                                           'binding)))
        (check-equal? (not (not binding-field)) #t)
        (check-equal? (poo-flow-module-field-contract-default binding-field)
                      'native-ffi)))))
