;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO performance extension graph test cases.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-fixture-ref
                 benchmark-receipt-pass?)
        "../support/poo-performance-fixtures"
        "../support/poo-performance-object-scenarios"
        "../support/poo-performance"
        :yuanxu/module-system/schema/interface
        :yuanxu/graph/interface
        :yuanxu/module-system/schema/validation)

(export extensions-test)

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-extension-children-case)
  (yuanxu-test-case "merges extension children through indexed override boundary"
        (let* ((base-count 500)
               (extra-count 1600)
               (key-span 700)
               (base (poo-performance-extension-merge-root base-count))
               (operations
                (poo-performance-extension-node-extend-operations extra-count
                                                                  key-span))
               (contribution
                (yuanxu-graph-contribution 'extension-root
                                                        operations))
               (merged
                (yuanxu-graph-apply-contribution base
                                                              contribution))
               (receipt
                (poo-performance-run-gate
                 (poo-performance-extension-children-merge-fixture)
                 (lambda ()
                   (yuanxu-graph-apply-contribution
                    base
                    contribution)))))
          (check-equal?
           (length (yuanxu-graph-root-children merged))
           key-span)
          (check-equal?
           (cdar
            (yuanxu-graph-root-payload
             (car (yuanxu-graph-root-children merged))))
           3400)
          (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-cross-targeting-case)
  (yuanxu-test-case "preserves same-pass targeting after cross contribution child creation"
        (let* ((child-count 900)
               (target
                (poo-performance-cross-contribution-child-name 640))
               (base (poo-performance-extension-merge-root 0))
               (contributions
                (poo-performance-cross-contribution-targeting-contributions
                 child-count
                 target))
               (merged
                (yuanxu-graph-apply-contributions base
                                                               contributions))
               (target-child
                (yuanxu-graph-root-ref
                 (yuanxu-graph-root-children merged)
                 target))
               (receipt
                (poo-performance-run-gate
                 (poo-performance-cross-contribution-targeting-fixture)
                 (lambda ()
                   (yuanxu-graph-apply-contributions
                    base
                    contributions)))))
          (check-equal?
           (length (yuanxu-graph-root-children merged))
           child-count)
          (check-equal?
           (poo-performance-slot-ref/default
            (yuanxu-graph-root-payload target-child)
            'targeted?
            #f)
           #t)
          (check-equal?
           (poo-performance-slot-ref/default
            (yuanxu-graph-root-payload target-child)
            'target-phase
            #f)
           'same-pass)
          (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-local-coalescing-case)
  (yuanxu-test-case "coalesces adjacent local contributions before graph traversal"
        (let* ((child-count 900)
               (contribution-count 900)
               (base (poo-performance-extension-merge-root child-count))
               (contributions
                (poo-performance-local-slot-contributions 'extension-root
                                                          contribution-count))
               (merged
                (yuanxu-graph-apply-contributions base
                                                               contributions))
               (receipt
                (poo-performance-run-gate
                 (poo-performance-local-contribution-coalescing-fixture)
                 (lambda ()
                   (yuanxu-graph-apply-contributions
                    base
                    contributions)))))
          (check-equal?
           (length (yuanxu-graph-root-children merged))
           child-count)
          (check-equal?
           (length (yuanxu-graph-root-payload merged))
           (+ contribution-count 1))
          (check-equal?
           (poo-performance-slot-ref/default
            (yuanxu-graph-root-payload merged)
            'field-640
            #f)
           640)
          (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; : TestSuite
(def extensions-test
  (test-suite "agentic-ai-lab module system POO extension performance"
    (module-system-poo-performance-extension-children-case)
    (module-system-poo-performance-cross-targeting-case)
    (module-system-poo-performance-local-coalescing-case)))
