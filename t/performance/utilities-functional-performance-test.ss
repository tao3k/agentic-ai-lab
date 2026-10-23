;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: algorithmic performance gate for shared functional utilities.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test check-equal? test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        (only-in :yuanxu/utilities/functional
                 yuanxu-stable-duplicates))

(export utilities-functional-performance-test)

(def functional-stable-duplicates-fixture-path
  "t/scenarios/performance/functional-stable-duplicates/benchmark.ss")

(def functional-stable-duplicates-fixture
  (call-with-input-file functional-stable-duplicates-fixture-path read))

(def (functional-performance-ref row key)
  (let (entry (assoc key row))
    (and entry (cdr entry))))

(def (functional-performance-summary values)
  (let (duplicates (yuanxu-stable-duplicates values))
    (list (cons 'input-count (length values))
          (cons 'duplicate-count (length duplicates))
          (cons 'first-duplicate (car duplicates))
          (cons 'last-duplicate (car (reverse duplicates))))))

(def (functional-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] functional-stable-duplicates ")
  (write receipt)
  (newline)
  (force-output))

(def utilities-functional-performance-test
  (test-suite "functional utility algorithms"
    (yuanxu-test-case "stable duplicate projection remains hash-linear at 20k inputs"
      (let* ((unique-count 10000)
             (values (append (iota unique-count) (iota unique-count)))
             (summary (functional-performance-summary values))
             (receipt
              (benchmark-run
               functional-stable-duplicates-fixture
               (lambda ()
                 (functional-performance-summary values)))))
        (check-equal?
         (benchmark-fixture-contract-pass?
          functional-stable-duplicates-fixture)
         #t)
        (check-equal? (functional-performance-ref summary 'input-count) 20000)
        (check-equal?
         (functional-performance-ref summary 'duplicate-count)
         unique-count)
        (check-equal? (functional-performance-ref summary 'first-duplicate) 0)
        (check-equal?
         (functional-performance-ref summary 'last-duplicate)
         (- unique-count 1))
        (functional-performance-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
