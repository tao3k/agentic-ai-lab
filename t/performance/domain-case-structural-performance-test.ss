;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: exclusive complexity gate for DomainCase structural catalogs.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test check-equal? test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        :yuanxu/feature-system/domain-case/interface)

(export domain-case-structural-performance-test)

(def +domain-case-structural-performance-fixture-path+
  "t/scenarios/performance/domain-case-structural-catalog/benchmark.ss")

(def +domain-case-structural-performance-fixture+
  (call-with-input-file
   +domain-case-structural-performance-fixture-path+ read))

(def (domain-case-structural-performance-id prefix index)
  (string->symbol
   (string-append prefix (number->string index))))

(def (domain-case-structural-performance-component index)
  (let* ((component-id
          (domain-case-structural-performance-id "component/" index))
         (type-id
          (domain-case-structural-performance-id "type/" index))
         (projection-id
          (domain-case-structural-performance-id "projection/" index))
         (parent-component-ids
          (if (zero? index)
            '()
            (list
             (domain-case-structural-performance-id
              "component/" (- index 1)))))
         (parent-type-ids
          (if (zero? index)
            '()
            (list
             (domain-case-structural-performance-id
              "type/" (- index 1)))))
         (type-contract
          (yuanxu-case-type-contract type-id parent-type-ids
                                       (lambda (_value) #t)))
         (projection
          (yuanxu-case-projection projection-id component-id
                                    'domain-case.performance.v1
                                    (lambda (value) value))))
    (yuanxu-case-component
     component-id 1 #t type-contract '() '() (list projection)
     parent-component-ids #f #f)))

(def (domain-case-structural-performance-summary components selected-ids)
  (let* ((projections
          (apply append
                 (map domain-case-component-projections components)))
         (structural-diagnostics
          (domain-case-closure-structural-diagnostics
           components projections)))
    (let-values (((selected selection-diagnostics)
                  (domain-case-select-projections projections selected-ids)))
      (list (cons 'component-count (length components))
            (cons 'projection-count (length projections))
            (cons 'selected-count (length selected))
            (cons 'structural-diagnostic-count
                  (length structural-diagnostics))
            (cons 'selection-diagnostic-count
                  (length selection-diagnostics))))))

(def (domain-case-structural-performance-ref row key)
  (cdr (assoc key row)))

(def (domain-case-structural-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] domain-case-structural-catalog ")
  (write receipt)
  (newline)
  (force-output))

(def domain-case-structural-performance-test
  (test-suite "DomainCase structural catalog performance"
    (yuanxu-test-case "indexes 2000 ordered components and projections"
      (let* ((count 2000)
             (components
              (map domain-case-structural-performance-component
                   (iota count)))
             (selected-ids
              (map (lambda (index)
                     (domain-case-structural-performance-id
                      "projection/" index))
                   (iota count)))
             (summary
              (domain-case-structural-performance-summary
               components selected-ids))
             (receipt
              (benchmark-run
               +domain-case-structural-performance-fixture+
               (lambda ()
                 (domain-case-structural-performance-summary
                  components selected-ids)))))
        (check-equal?
         (benchmark-fixture-contract-pass?
          +domain-case-structural-performance-fixture+)
         #t)
        (check-equal?
         (domain-case-structural-performance-ref summary 'component-count)
         count)
        (check-equal?
         (domain-case-structural-performance-ref summary 'projection-count)
         count)
        (check-equal?
         (domain-case-structural-performance-ref summary 'selected-count)
         count)
        (check-equal?
         (domain-case-structural-performance-ref
          summary 'structural-diagnostic-count)
         0)
        (check-equal?
         (domain-case-structural-performance-ref
          summary 'selection-diagnostic-count)
         0)
        (domain-case-structural-performance-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
