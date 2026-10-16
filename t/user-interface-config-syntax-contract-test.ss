;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module-selection syntax and declaration-contract admission.
;;; Invariant: contract qualification does not load profiles or root config.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test check-equal? test-suite)
        (only-in :core/module-system/selection/objects
                 poo-flow-user-module-selection
                 poo-flow-user-module-selection-flags
                 poo-flow-user-module-selection-key
                 poo-flow-user-module-selection->alist
                 poo-flow-user-module-when)
        (only-in :core/module-system/selection/contract poo-flow-use-module-contract-validation-valid?)
        (only-in :poo-flow/modules/workflow/scenario/configuration/selection-policy poo-flow-product-use-module poo-flow-product-selection-admit! poo-flow-product-selection-validation))

(export user-interface-config-syntax-contract-test)

(def (syntax-contract-alist-ref entries key)
  (let (entry (assoc key entries))
    (if entry (cdr entry) #f)))

(def user-interface-config-syntax-contract-test
  (test-suite "poo-flow user interface config syntax contract"
    (poo-flow-test-case "builds module selections and conditional gates"
      (let ((nono-selections
             (poo-flow-product-use-module
              'nono-sandbox
              '(+nono +doctor)))
            (flow-selection
             (poo-flow-user-module-selection 'flow 'funflow '(+dag))))
        (check-equal? (poo-flow-user-module-selection-key
                       (car nono-selections))
                      '(sandbox . nono-sandbox))
        (check-equal? (poo-flow-user-module-selection-flags
                       (car nono-selections))
                      '(+nono +doctor))
        (check-equal? (poo-flow-user-module-when #f
                       (sandbox cubeSandbox +doctor))
                      '())
        (check-equal? (poo-flow-user-module-selection->alist flow-selection)
                      '((group . flow)
                        (module . funflow)
                        (key flow . funflow)
                        (source-ref . #f)
                        (entrypoint . #f)
                        (flags +dag)
                        (enabled? . #t)))))
    (poo-flow-test-case "validates use-module declarations before projection"
      (let* ((valid-selections
              (poo-flow-product-use-module
               'nono-sandbox
               '(+nono +doctor)))
             (valid-validation
              (poo-flow-product-selection-validation
               'nono-sandbox
               valid-selections))
             (invalid-selection
              (poo-flow-user-module-selection 'custom 'workflow '())))
        (check-equal? (syntax-contract-alist-ref valid-validation 'valid) #t)
        (check-equal? (syntax-contract-alist-ref valid-validation 'module)
                      'nono-sandbox)
        (check-equal?
         (syntax-contract-alist-ref valid-validation 'selection-count)
         1)
        (check-equal? (poo-flow-product-selection-admit!
                       'nono-sandbox
                       valid-selections)
                      valid-selections)
        (check-equal?
         (poo-flow-use-module-contract-validation-valid?
          (poo-flow-product-selection-validation
           'workflow
           (list invalid-selection)))
         #f)
        (check-equal?
         (with-catch
          (lambda (_) #t)
          (lambda ()
            (poo-flow-product-selection-admit!
             'nono-sandbox
             '(not-a-selection))
            #f))
         #t)))))
