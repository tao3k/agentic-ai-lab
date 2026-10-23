;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module-selection syntax and declaration-contract admission.
;;; Invariant: contract qualification does not load profiles or root config.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test check-equal? test-suite)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection
                 yuanxu-user-module-selection-flags
                 yuanxu-user-module-selection-key
                 yuanxu-user-module-selection->alist
                 yuanxu-user-module-when)
        (only-in :yuanxu/module-system/selection/contract yuanxu-use-module-contract-validation-valid?)
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/selection-policy agentic-ai-lab-product-use-module agentic-ai-lab-product-selection-admit! agentic-ai-lab-product-selection-validation))

(export user-interface-config-syntax-contract-test)

(def (syntax-contract-alist-ref entries key)
  (let (entry (assoc key entries))
    (if entry (cdr entry) #f)))

(def user-interface-config-syntax-contract-test
  (test-suite "agentic-ai-lab user interface config syntax contract"
    (yuanxu-test-case "builds module selections and conditional gates"
      (let ((nono-selections
             (agentic-ai-lab-product-use-module
              'nono-sandbox
              '(+nono +doctor)))
            (flow-selection
             (yuanxu-user-module-selection 'flow 'funflow '(+dag))))
        (check-equal? (yuanxu-user-module-selection-key
                       (car nono-selections))
                      '(sandbox . nono-sandbox))
        (check-equal? (yuanxu-user-module-selection-flags
                       (car nono-selections))
                      '(+nono +doctor))
        (check-equal? (yuanxu-user-module-when #f
                       (sandbox cubeSandbox +doctor))
                      '())
        (check-equal? (yuanxu-user-module-selection->alist flow-selection)
                      '((group . flow)
                        (module . funflow)
                        (key flow . funflow)
                        (source-ref . #f)
                        (entrypoint . #f)
                        (flags +dag)
                        (enabled? . #t)))))
    (yuanxu-test-case "validates use-module declarations before projection"
      (let* ((valid-selections
              (agentic-ai-lab-product-use-module
               'nono-sandbox
               '(+nono +doctor)))
             (valid-validation
              (agentic-ai-lab-product-selection-validation
               'nono-sandbox
               valid-selections))
             (invalid-selection
              (yuanxu-user-module-selection 'custom 'workflow '())))
        (check-equal? (syntax-contract-alist-ref valid-validation 'valid) #t)
        (check-equal? (syntax-contract-alist-ref valid-validation 'module)
                      'nono-sandbox)
        (check-equal?
         (syntax-contract-alist-ref valid-validation 'selection-count)
         1)
        (check-equal? (agentic-ai-lab-product-selection-admit!
                       'nono-sandbox
                       valid-selections)
                      valid-selections)
        (check-equal?
         (yuanxu-use-module-contract-validation-valid?
          (agentic-ai-lab-product-selection-validation
           'workflow
           (list invalid-selection)))
         #f)
        (check-equal?
         (with-catch
          (lambda (_) #t)
          (lambda ()
            (agentic-ai-lab-product-selection-admit!
             'nono-sandbox
             '(not-a-selection))
            #f))
         #t)))))
