;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO performance cases for fixed slot projection.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-ref
                 benchmark-receipt-pass?)
        (only-in :clan/poo/object
                 .get
                 .o)
        "../support/poo-performance-fixtures"
        "../support/poo-performance")

(export projection-test)

;; : (-> Alist Unit)
(def (module-system-poo-performance-projection-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] ")
  (write (benchmark-fixture-ref receipt 'feature))
  (display " ")
  (write receipt)
  (newline)
  (force-output))

;; : PooObject
(def module-system-poo-performance-fixed-slot-profile
  (.o (base 11)
      (limit 17)
      (step 3)
      (weight 5)
      (offset 7)))

;; module-system-poo-performance-fixed-slot-sum
;;   : (-> PooObject Integer Integer)
;;   | doc m%
;;       Projects fixed POO lenses once, then keeps the benchmark loop scalar.
;;
;;       # Examples
;;       ```scheme
;;       (module-system-poo-performance-fixed-slot-sum
;;        module-system-poo-performance-fixed-slot-profile
;;        1)
;;       ;; => 43
;;       ```
;;     %
(def (module-system-poo-performance-fixed-slot-sum profile rounds)
  (let* ((family +poo-performance-fixed-slot-projection-family+)
         (base-lens (poo-performance-family-slot-lens family 'base))
         (limit-lens (poo-performance-family-slot-lens family 'limit))
         (step-lens (poo-performance-family-slot-lens family 'step))
         (weight-lens (poo-performance-family-slot-lens family 'weight))
         (offset-lens (poo-performance-family-slot-lens family 'offset))
         (base (poo-performance-family-slot-lens-ref base-lens profile))
         (limit (poo-performance-family-slot-lens-ref limit-lens profile))
         (step (poo-performance-family-slot-lens-ref step-lens profile))
         (weight (poo-performance-family-slot-lens-ref weight-lens profile))
         (offset (poo-performance-family-slot-lens-ref offset-lens profile))
         (slot-total (+ base limit step weight offset)))
    (+ (* slot-total rounds)
       (quotient (* rounds (- rounds 1)) 2))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-fixed-slot-projection-case)
  (yuanxu-test-case "projects fixed POO slots once before scalar loops"
    (let* ((rounds 4000)
           (expected (module-system-poo-performance-fixed-slot-sum
                      module-system-poo-performance-fixed-slot-profile
                      rounds))
           (receipt
            (poo-performance-run-gate
             (poo-performance-fixed-slot-projection-fixture)
             (lambda ()
               (module-system-poo-performance-fixed-slot-sum
                module-system-poo-performance-fixed-slot-profile
                rounds)))))
      (check-equal? (.get module-system-poo-performance-fixed-slot-profile base)
                    11)
      (check-equal? expected 8170000)
      (module-system-poo-performance-projection-display-receipt receipt)
      (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; : TestSuite
(def projection-test
  (test-suite "agentic-ai-lab module system POO projection performance"
    (module-system-poo-performance-fixed-slot-projection-case)))
