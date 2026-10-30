;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: real module object catalog validation stays out of the unit root.
;;; Invariant: catalog checks load backend object sets but never realize runtime.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :clan/poo/object .ref object?)
        (only-in :std/test
                 test-suite
                 check-equal?)
        :yuanxu/module-system/schema/interface
        :yuanxu/module-system/schema/validation
        :agentic-ai-lab/modules/sandbox-core/shared-object
        :agentic-ai-lab/modules/sandbox-core/objects
        :agentic-ai-lab/modules/workflow/scenario/configuration/root-objects
        :agentic-ai-lab/modules/nono-sandbox/objects
        :agentic-ai-lab/modules/cubeSandbox/objects
        :agentic-ai-lab/modules/docker-sandbox/objects)

(export module-object-catalog-validation-test)

;; : (-> POOObject Symbol Value)
(def (receipt-ref receipt key)
  (.ref receipt key))

;; : TestSuite
(def module-object-catalog-validation-test
  (test-suite "agentic-ai-lab module object catalog validation"
    (yuanxu-test-case "validates real module object sets"
      (let* ((objects
              (append agentic-ai-lab-shared-module-objects
                      agentic-ai-lab-sandbox-core-module-objects
                      agentic-ai-lab-user-interface-root-module-objects
                      agentic-ai-lab-nono-sandbox-module-objects
                      agentic-ai-lab-cubeSandbox-module-objects
                      agentic-ai-lab-docker-sandbox-module-objects))
             (validations
              (yuanxu-module-objects-validation objects)))
        (check-equal? (length validations) 9)
        (check-equal?
         (eq? (car validations)
              (car (yuanxu-module-objects-validation objects)))
         #t)
        (check-equal? (andmap object? validations) #t)
        (check-equal? (map yuanxu-module-object-validation-valid?
                           validations)
                      '(#t #t #t #t #t #t #t #t #t))
        (let (summary
              (yuanxu-module-objects-validation-summary validations))
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

    (yuanxu-test-case "pins nono sandbox object binding to native FFI"
      (let ((binding-field
             (yuanxu-module-object-field agentic-ai-lab-nono-sandbox-object
                                           'binding)))
        (check-equal? (not (not binding-field)) #t)
        (check-equal? (yuanxu-module-field-contract-default binding-field)
                      'native-ffi)))))
