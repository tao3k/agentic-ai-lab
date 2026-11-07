;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop governor performance gates cover one-pass policy projection.
;;; Invariant: governor projection consumes state facts without runtime mutation.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        "../support/performance"
        (only-in :agentic-ai-lab/modules/loop-engine/control/descriptor
                 make-loop-pattern-descriptor)
        (only-in :agentic-ai-lab/modules/loop-engine/control/strategy
                 make-loop-strategy-plan)
        (only-in :agentic-ai-lab/modules/loop-engine/control/governor-core
                 make-loop-governor)
        (only-in :agentic-ai-lab/modules/loop-engine/control/governor-policy
                 loop-governor->contract))

(export loop-governor-performance-test)

;; : String
(def loop-governor-contract-projection-fixture-path
  "t/scenarios/performance/loop-governor-contract-projection/benchmark.ss")

;; : Alist
(def loop-governor-contract-projection-fixture
  (call-with-input-file loop-governor-contract-projection-fixture-path read))

;; : (-> Alist Symbol Value)
(def (loop-governor-performance-ref alist key)
  (cdr (assoc key alist)))

;; : (-> Alist Void)
(def (loop-governor-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] loop-governor-contract-projection ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> Integer String)
(def (loop-governor-performance-action-key index)
  (string-append "src/generated/" (number->string index)))

;; : (-> Integer LoopPatternDescriptor)
(def (loop-governor-performance-pattern index)
  (make-loop-pattern-descriptor
   (string->symbol
    (string-append "governor-pattern-" (number->string index)))
   "Exercise governor policy projection on large strategy output."
   (list (cons 'level 'l2)
         (cons 'priority index)
         (cons 'metadata
               (list (cons 'acting_on
                           (loop-governor-performance-action-key index)))))))

;; : (-> Integer [LoopPatternDescriptor])
(def (loop-governor-performance-patterns count)
  (agentic-ai-lab-performance-build-list
   count
   loop-governor-performance-pattern))

;; : (-> Integer Integer [String])
(def (loop-governor-performance-action-keys start count)
  (agentic-ai-lab-performance-build-list
   count
   (lambda (offset)
     (loop-governor-performance-action-key (+ start offset)))))

;; : (-> Integer Integer [Alist])
(def (loop-governor-performance-states start count)
  (agentic-ai-lab-performance-build-list
   count
   (lambda (offset)
     (list (cons 'acting_on
                 (loop-governor-performance-action-key (+ start offset)))))))

;; : (-> Integer LoopGovernor)
(def (loop-governor-performance-governor pattern-count)
  (let* ((strategy
          (make-loop-strategy-plan
           'large-governor-strategy
           (loop-governor-performance-patterns pattern-count)
           (list (cons 'level-ceiling 'l2))))
         (denylist
          (loop-governor-performance-action-keys 0 50)))
    (make-loop-governor
     'large-governor
     strategy
     (list (cons 'shared-denylist denylist)
           (cons 'aggregate-budget
                 '((max-actionable . 25)
                   (max-attempts . 2)))
           (cons 'metadata '((source . loop-governor-performance-test)))))))

;; : (-> LoopGovernor [Alist] Alist)
(def (loop-governor-performance-contract-summary governor states)
  (let (contract (loop-governor->contract governor states))
    (list (cons 'open-count
                (length (loop-governor-performance-ref contract 'open-patterns)))
          (cons 'conflicting-count
                (length (loop-governor-performance-ref contract 'conflicting-patterns)))
          (cons 'denied-count
                (length (loop-governor-performance-ref contract 'denied-patterns)))
          (cons 'human-inbox-count
                (length (loop-governor-performance-ref contract 'human-inbox-items)))
          (cons 'agent-node-count
                (length (loop-governor-performance-ref contract 'agent-judge-nodes))))))

;; : TestSuite
(def loop-governor-performance-test
  (test-suite "loop governor performance"
    (yuanxu-test-case "keeps large governor projection inside benchmark contract"
      (let* ((pattern-count 600)
             (governor
              (loop-governor-performance-governor pattern-count))
             (states
              (loop-governor-performance-states 50 50))
             (summary
              (loop-governor-performance-contract-summary governor states))
             (receipt
              (benchmark-run
               loop-governor-contract-projection-fixture
               (lambda ()
                 (loop-governor-performance-contract-summary
                  governor
                  states)))))
        (check-equal?
         (benchmark-fixture-contract-pass?
          loop-governor-contract-projection-fixture)
         #t)
        (check-equal?
         (loop-governor-performance-ref summary 'open-count)
         25)
        (check-equal?
         (loop-governor-performance-ref summary 'conflicting-count)
         50)
        (check-equal?
         (loop-governor-performance-ref summary 'denied-count)
         50)
        (check-equal?
         (loop-governor-performance-ref summary 'human-inbox-count)
         100)
        (check-equal?
         (loop-governor-performance-ref summary 'agent-node-count)
         3)
        (loop-governor-performance-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
