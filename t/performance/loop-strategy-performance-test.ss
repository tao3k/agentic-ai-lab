;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop strategy performance gates cover batched slot projection.
;;; Invariant: strategy projection stays local contract data, not runtime work.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        "../support/performance"
        (only-in :poo-flow/modules/loop-engine/control/descriptor
                 make-loop-pattern-descriptor)
        (only-in :poo-flow/modules/loop-engine/control/strategy
                 make-loop-strategy-plan
                 loop-strategy-plan->contract))

(export loop-strategy-performance-test)

;; : String
(def loop-strategy-contract-projection-fixture-path
  "t/scenarios/performance/loop-strategy-contract-projection/benchmark.ss")

;; : Alist
(def loop-strategy-contract-projection-fixture
  (call-with-input-file loop-strategy-contract-projection-fixture-path read))

;; : (-> Alist Symbol Value)
(def (loop-strategy-performance-ref alist key)
  (cdr (assoc key alist)))

;; : (-> Alist Void)
(def (loop-strategy-performance-display-receipt receipt)
  (display "[poo-flow-benchmark] loop-strategy-contract-projection ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> Integer Symbol)
(def (loop-strategy-performance-name index)
  (string->symbol
   (string-append "loop-strategy-pattern-" (number->string index))))

;; : (-> Integer Symbol)
(def (loop-strategy-performance-level index)
  (case (modulo index 4)
    ((0) 'l1)
    ((1) 'l2)
    ((2) 'l2+)
    (else 'l3)))

;; : (-> Integer LoopPatternDescriptor)
(def (loop-strategy-performance-pattern index)
  (make-loop-pattern-descriptor
   (loop-strategy-performance-name index)
   "Exercise large strategy projection without runtime side effects."
   (list (cons 'level (loop-strategy-performance-level index))
         (cons 'priority index)
         (cons 'watched-scope '(pull-requests ci docs))
         (cons 'safety
               '((human-gates . (security dependency-upgrade))
                 (denylist . ("secrets/**"))
                 (auto-merge . #f)))
         (cons 'metadata (list (cons 'index index))))))

;; : (-> Integer [LoopPatternDescriptor])
(def (loop-strategy-performance-patterns count)
  (poo-flow-performance-build-list
   count
   loop-strategy-performance-pattern))

;; : (-> Integer LoopStrategyPlan)
(def (loop-strategy-performance-plan count)
  (make-loop-strategy-plan
   'large-strategy-projection
   (loop-strategy-performance-patterns count)
   (list (cons 'level-ceiling 'l3)
         (cons 'metadata '((source . loop-strategy-performance-test))))))

;; : (-> LoopStrategyPlan Alist)
(def (loop-strategy-performance-contract-summary plan)
  (let* ((contract (loop-strategy-plan->contract plan))
         (selected-patterns
          (loop-strategy-performance-ref contract 'selected-patterns))
         (actionable-patterns
          (loop-strategy-performance-ref contract 'actionable-patterns)))
    (list (cons 'pattern-count
                (loop-strategy-performance-ref contract 'pattern-count))
          (cons 'selected-count (length selected-patterns))
          (cons 'actionable-count (length actionable-patterns))
          (cons 'next-pattern
                (loop-strategy-performance-ref contract 'next-pattern)))))

;; : TestSuite
(def loop-strategy-performance-test
  (test-suite "loop strategy performance"
    (poo-flow-test-case "keeps large strategy projection inside benchmark contract"
      (let* ((pattern-count 600)
             (plan (loop-strategy-performance-plan pattern-count))
             (summary
              (loop-strategy-performance-contract-summary plan))
             (receipt
              (benchmark-run
               loop-strategy-contract-projection-fixture
               (lambda ()
                 (loop-strategy-performance-contract-summary plan)))))
        (check-equal?
         (benchmark-fixture-contract-pass?
          loop-strategy-contract-projection-fixture)
         #t)
        (check-equal?
         (loop-strategy-performance-ref summary 'pattern-count)
         pattern-count)
        (check-equal?
         (loop-strategy-performance-ref summary 'selected-count)
         pattern-count)
        (check-equal?
         (loop-strategy-performance-ref summary 'actionable-count)
         450)
        (check-equal?
         (loop-strategy-performance-ref summary 'next-pattern)
         'loop-strategy-pattern-1)
        (loop-strategy-performance-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
