;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: selector receipt performance gate.
;;; Invariant: selector candidate projection stays bounded and report-only.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        "../support/performance"
        :agentic-ai-lab/modules/session/config)

(export session-selector-receipt-performance-test)

;; : String
(def session-selector-receipt-fixture-path
  "t/scenarios/performance/session-selector-receipt/benchmark.ss")

;; : Alist
(def session-selector-receipt-fixture
  (call-with-input-file session-selector-receipt-fixture-path read))

;; : (-> Alist Symbol MaybeValue)
(def (selector-performance-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : (-> Alist Void)
(def (selector-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] session-selector-receipt ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> Integer Symbol)
(def (selector-performance-candidate-id index)
  (string->symbol
   (string-append "candidate/" (number->string index))))

;; : (-> Integer Symbol)
(def (selector-performance-target-ref index)
  (string->symbol
   (string-append "transform/" (number->string index))))

;; : (-> Integer Symbol)
(def (selector-performance-candidate-kind index)
  (cond
   ((= (modulo index 3) 0) 'workflow)
   ((= (modulo index 3) 1) 'transform)
   (else 'agent-param)))

;; : (-> Integer PooSessionSelectorCandidate)
(def (selector-performance-candidate index)
  (agentic-ai-lab-session-selector-candidate
   (selector-performance-candidate-id index)
   (selector-performance-candidate-kind index)
   (selector-performance-target-ref index)
   "Synthetic selector candidate for batch projection."
   '(runtime-owner runtime-executed)))

;; selector-performance-target-refs
;;   : (-> Integer SelectorPerformanceCandidateKind [SelectorPerformanceTargetRef])
;;   | doc m%
;;       Generate target references for selector receipt candidates while
;;       preserving the requested candidate kind.
;;
;;       # Examples
;;       ```scheme
;;       (selector-performance-target-refs 0 'profile)
;;       ;; => ()
;;       ```
;;     %
(def (selector-performance-target-refs candidate-count candidate-kind)
  (filter
   (lambda (ref) ref)
   (agentic-ai-lab-performance-build-list
    candidate-count
    (lambda (index)
      (and (eq? (selector-performance-candidate-kind index) candidate-kind)
           (selector-performance-target-ref index))))))

;; : (-> Integer Alist)
(def (selector-performance-summary candidate-count)
  (let* ((candidates
          (agentic-ai-lab-performance-build-list
           candidate-count
           selector-performance-candidate))
         (selection-policy
          (list
           (cons 'strategy 'llm-router)
           (cons 'judge-inputs '(summary last-failure))
           (cons 'workflow-target-refs
                 (selector-performance-target-refs candidate-count
                                                   'workflow))
           (cons 'transform-target-refs
                 (selector-performance-target-refs candidate-count
                                                   'transform))
           (cons 'agent-param-target-refs
                 (selector-performance-target-refs candidate-count
                                                   'agent-param))
           (cons 'external-fallback-refs '(empty-workflow))))
         (receipt
          (agentic-ai-lab-session-selector-receipt
           'selector/performance
           'project/selector
           'session/root
           'session/root
           candidates
           selection-policy
           'empty-workflow))
         (row (agentic-ai-lab-session-selector-receipt->alist receipt))
         (projected-candidates (selector-performance-ref row 'candidates)))
    (list (cons 'candidate-count
                (selector-performance-ref row 'candidate-count))
          (cons 'projected-candidate-count (length projected-candidates))
          (cons 'workflow-count
                (length (selector-performance-ref
                         row
                         'workflow-candidate-ids)))
          (cons 'transform-count
                (length (selector-performance-ref
                         row
                         'transform-candidate-ids)))
          (cons 'agent-param-count
                (length (selector-performance-ref
                         row
                         'agent-param-candidate-ids)))
          (cons 'selection-state
                (selector-performance-ref row 'selection-state))
          (cons 'selected-candidate-ref
                (selector-performance-ref row 'selected-candidate-ref))
          (cons 'resolved-candidate-count
                (length
                 (selector-performance-ref row 'resolved-candidate-ids)))
          (cons 'unresolved-candidate-count
                (length
                 (selector-performance-ref row 'unresolved-candidate-ids)))
          (cons 'fallback-resolved?
                (selector-performance-ref row 'fallback-resolved?))
          (cons 'valid?
                (selector-performance-ref row 'valid?))
          (cons 'diagnostic-count
                (selector-performance-ref row 'diagnostic-count))
          (cons 'runtime-executed
                (selector-performance-ref row 'runtime-executed)))))

;; : TestSuite
(def session-selector-receipt-performance-test
  (test-suite "session selector receipt performance"
    (yuanxu-test-case "keeps selector candidate projection inside benchmark contract"
      (let* ((candidate-count 300)
             (summary (selector-performance-summary candidate-count))
             (receipt
              (benchmark-run
               session-selector-receipt-fixture
               (lambda ()
                 (selector-performance-summary candidate-count)))))
        (check-equal?
         (benchmark-fixture-contract-pass? session-selector-receipt-fixture)
         #t)
        (check-equal? (selector-performance-ref summary 'candidate-count)
                      candidate-count)
        (check-equal?
         (selector-performance-ref summary 'projected-candidate-count)
         candidate-count)
        (check-equal? (selector-performance-ref summary 'workflow-count)
                      100)
        (check-equal? (selector-performance-ref summary 'transform-count)
                      100)
        (check-equal? (selector-performance-ref summary 'agent-param-count)
                      100)
        (check-equal? (selector-performance-ref summary 'selection-state)
                      'pending)
        (check-equal? (selector-performance-ref summary
                                                'selected-candidate-ref)
                      #f)
        (check-equal? (selector-performance-ref summary
                                                'resolved-candidate-count)
                      candidate-count)
        (check-equal? (selector-performance-ref summary
                                                'unresolved-candidate-count)
                      0)
        (check-equal? (selector-performance-ref summary 'fallback-resolved?)
                      #t)
        (check-equal? (selector-performance-ref summary 'valid?) #t)
        (check-equal? (selector-performance-ref summary 'diagnostic-count)
                      0)
        (check-equal? (selector-performance-ref summary 'runtime-executed)
                      #f)
        (selector-performance-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
