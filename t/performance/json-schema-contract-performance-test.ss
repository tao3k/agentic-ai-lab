;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: JSON Schema recursive contract benchmark gates.
;;; Invariant: benchmark thunks exclude gxi startup, package install, schema
;;; download, Python execution, GitHub Actions execution, and external IO.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-elapsed-us
                 benchmark-p95-elapsed-ms
                 benchmark-p95-elapsed-us)
        "../support/json-schema-contract-performance.ss")

(export json-schema-contract-performance-test)

;; : (-> Alist Void)
(def (json-schema-contract-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] json-schema-contract-performance ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> Rational Rational Boolean)
(def (json-schema-contract-performance-within-budget? observed-ms max-ms)
  (and observed-ms
       (<= observed-ms max-ms)))

;; : (-> Symbol Rational Rational Void)
(def (json-schema-contract-performance-check-budget! name observed-ms max-ms)
  (check-equal?
   (json-schema-contract-performance-within-budget? observed-ms max-ms)
   #t))

;; : (-> Integer (-> Integer) Rational)
(def (json-schema-contract-performance-p95-ms attempts workload)
  (benchmark-p95-elapsed-ms
   attempts
   (lambda ()
     (workload))))

;; : (-> Integer (-> Integer) Integer)
(def (json-schema-contract-performance-p95-us attempts workload)
  (benchmark-p95-elapsed-us
   attempts
   (lambda ()
     (workload))))

;; : (-> Number Integer Number)
(def (json-schema-contract-performance-average-us total-us rounds)
  (/ total-us rounds))

;; : (-> [Rational] Rational)
(def (json-schema-contract-performance-median values)
  (let (ordered (list-sort < (append values '())))
    (list-ref ordered (quotient (length ordered) 2))))

;;; Measure each native/alist pair in alternating order.  The pair owns the
;;; same compiled schema and workload size, so process scheduling and warm-up
;;; affect both representations instead of becoming a false speedup.  The ASP
;;; benchmark API remains the clock owner.
;; : (-> Integer (-> Integer) (-> Integer) Alist)
(def (json-schema-contract-performance-paired-ab attempts native-workload
                                                    alist-workload)
  (let loop ((remaining attempts)
             (native-first? #t)
             (native-samples '())
             (alist-samples '()))
    (if (<= remaining 0)
      (let ((native-median
             (json-schema-contract-performance-median native-samples))
            (alist-median
             (json-schema-contract-performance-median alist-samples)))
        (list (cons 'native-samples-us (reverse native-samples))
              (cons 'alist-samples-us (reverse alist-samples))
              (cons 'native-median-us native-median)
              (cons 'alist-median-us alist-median)
              (cons 'native-over-alist-speedup
                    (/ alist-median native-median))))
      (let* ((first-workload
              (if native-first? native-workload alist-workload))
             (second-workload
              (if native-first? alist-workload native-workload))
             (first-us (benchmark-elapsed-us first-workload))
             (second-us (benchmark-elapsed-us second-workload))
             (native-us (if native-first? first-us second-us))
             (alist-us (if native-first? second-us first-us)))
        (loop (- remaining 1)
              (not native-first?)
              (cons native-us native-samples)
              (cons alist-us alist-samples))))))

;; : (-> Alist)
(def (json-schema-contract-performance-receipt)
  (let* ((attempts 3)
         (job-count 24)
         (step-count 4)
         (rounds 20)
         (micro-job-count 1)
         (micro-step-count 1)
         (micro-rounds 2000)
         (alist-workflow
          (json-schema-contract-performance-workflow job-count step-count))
         (poo-workflow
          (json-schema-contract-performance-poo-workflow job-count step-count))
         (micro-workflow
          (json-schema-contract-performance-native-workflow
           micro-job-count
           micro-step-count))
         (micro-alist-workflow
          (json-schema-contract-performance-workflow
           micro-job-count
           micro-step-count))
         (micro-ab
          (json-schema-contract-performance-paired-ab
           5
           (lambda ()
             (json-schema-contract-performance-fast-validate-rounds
              micro-workflow
              micro-rounds))
           (lambda ()
             (json-schema-contract-performance-fast-validate-rounds
              micro-alist-workflow
              micro-rounds))))
         (micro-fast-validations
          (json-schema-contract-performance-fast-validate-rounds
           micro-workflow
           micro-rounds))
         (alist-validations
          (json-schema-contract-performance-validate-rounds
           alist-workflow
           rounds))
         (poo-validations
          (json-schema-contract-performance-validate-rounds
           poo-workflow
           rounds))
         (alist-ms
          (json-schema-contract-performance-p95-ms
           attempts
           (lambda ()
             (json-schema-contract-performance-validate-rounds
              alist-workflow
              rounds))))
         (poo-ms
          (json-schema-contract-performance-p95-ms
           attempts
           (lambda ()
             (json-schema-contract-performance-validate-rounds
              poo-workflow
              rounds))))
         (micro-fast-us
          (json-schema-contract-performance-p95-us
           attempts
           (lambda ()
             (json-schema-contract-performance-fast-validate-rounds
              micro-workflow
              micro-rounds))))
         (micro-alist-fast-us
          (json-schema-contract-performance-p95-us
           attempts
           (lambda ()
             (json-schema-contract-performance-fast-validate-rounds
              micro-alist-workflow
              micro-rounds))))
         (micro-receipt-us
          (json-schema-contract-performance-p95-us
           attempts
           (lambda ()
             (json-schema-contract-performance-validate-rounds
              micro-workflow
              micro-rounds)))))
    (list
     (cons 'attempts attempts)
     (cons 'admissionStatistic 'p95)
     (cons 'job-count job-count)
     (cons 'step-count step-count)
     (cons 'rounds rounds)
     (cons 'micro-job-count micro-job-count)
     (cons 'micro-step-count micro-step-count)
     (cons 'micro-representation 'std/text/json-default-string-hash)
     (cons 'micro-rounds micro-rounds)
     (cons 'micro-fast-validations micro-fast-validations)
     (cons 'alist-validations alist-validations)
     (cons 'poo-validations poo-validations)
     (cons 'alist-ms alist-ms)
     (cons 'alist-ms-max-ms 100)
     (cons 'poo-ms poo-ms)
     (cons 'poo-ms-max-ms 100)
     (cons 'micro-fast-us micro-fast-us)
     (cons 'micro-fast-average-us
           (json-schema-contract-performance-average-us
            micro-fast-us
            micro-rounds))
     (cons 'micro-fast-average-us-max-us 50)
     (cons 'micro-alist-fast-us micro-alist-fast-us)
     (cons 'micro-alist-fast-average-us
           (json-schema-contract-performance-average-us
            micro-alist-fast-us
            micro-rounds))
     (cons 'native-over-alist-speedup
           (json-schema-contract-performance-ref
            micro-ab
            'native-over-alist-speedup))
     (cons 'native-over-alist-speedup-min 11/10)
     (cons 'native-over-alist-ab micro-ab)
     (cons 'micro-receipt-us micro-receipt-us)
     (cons 'micro-receipt-average-us
           (json-schema-contract-performance-average-us
            micro-receipt-us
            micro-rounds))
     (cons 'micro-receipt-average-us-max-us 90))))

;; : TestSuite
(def json-schema-contract-performance-test
  (test-suite "json schema contract performance"
    (yuanxu-test-case "keeps recursive map-value validation inside regression budgets"
      (let (receipt (json-schema-contract-performance-receipt))
        (json-schema-contract-performance-display-receipt receipt)
        (check-equal?
         (json-schema-contract-performance-ref receipt 'alist-validations)
         (json-schema-contract-performance-ref receipt 'rounds))
        (check-equal?
         (json-schema-contract-performance-ref receipt 'poo-validations)
         (json-schema-contract-performance-ref receipt 'rounds))
        (check-equal?
         (json-schema-contract-performance-ref receipt 'micro-fast-validations)
         (json-schema-contract-performance-ref receipt 'micro-rounds))
        (json-schema-contract-performance-check-budget!
         'alist-ms
         (json-schema-contract-performance-ref receipt 'alist-ms)
         (json-schema-contract-performance-ref receipt 'alist-ms-max-ms))
        (json-schema-contract-performance-check-budget!
         'poo-ms
         (json-schema-contract-performance-ref receipt 'poo-ms)
         (json-schema-contract-performance-ref receipt 'poo-ms-max-ms))
        (json-schema-contract-performance-check-budget!
         'micro-fast-average-us
         (json-schema-contract-performance-ref receipt 'micro-fast-average-us)
         (json-schema-contract-performance-ref
          receipt
          'micro-fast-average-us-max-us))
        (check-equal?
         (>= (json-schema-contract-performance-ref
              receipt
              'native-over-alist-speedup)
             (json-schema-contract-performance-ref
              receipt
              'native-over-alist-speedup-min))
         #t)
        (json-schema-contract-performance-check-budget!
         'micro-receipt-average-us
         (json-schema-contract-performance-ref receipt 'micro-receipt-average-us)
         (json-schema-contract-performance-ref
          receipt
          'micro-receipt-average-us-max-us))))))
