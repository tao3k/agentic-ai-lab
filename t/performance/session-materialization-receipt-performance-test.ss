;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: runtime materialization receipt performance gate.
;;; Invariant: defstruct receipts project to bounded ABI rows in one pass.

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

(export session-materialization-receipt-performance-test)

;; : String
(def session-materialization-receipt-fixture-path
  "t/scenarios/performance/session-materialization-receipt/benchmark.ss")

;; : Alist
(def session-materialization-receipt-fixture
  (call-with-input-file session-materialization-receipt-fixture-path read))

;; : (-> Alist Symbol MaybeValue)
(def (materialization-performance-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : (-> Alist Void)
(def (materialization-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] session-materialization-receipt ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> String Integer Symbol)
(def (materialization-performance-symbol prefix index)
  (string->symbol
   (string-append prefix "/" (number->string index))))

;; : (-> Integer Symbol)
(def (materialization-performance-state index)
  (cond
   ((= (modulo index 3) 0) 'pending)
   ((= (modulo index 3) 1) 'materialized)
   (else 'failed)))

;; : (-> Integer MaybeSymbol)
(def (materialization-performance-sandbox-handle index)
  (if (= (modulo index 3) 2)
    #f
    (materialization-performance-symbol "sandbox/handle" index)))

;; : (-> Integer Alist)
(def (materialization-performance-token-usage index)
  (if (= (modulo index 3) 1)
    (list (cons 'prompt-tokens index)
          (cons 'completion-tokens 2)
          (cons 'total-tokens (+ index 2)))
    '()))

;; : (-> Integer MaybeAlist)
(def (materialization-performance-error index)
  (if (= (modulo index 3) 2)
    (list (cons 'error-kind 'RuntimeError)
          (cons 'message "runtime materialization failed")
          (cons 'request-index index))
    #f))

;; : (-> Integer Alist)
(def (materialization-performance-metadata index)
  (let* ((session-ref (materialization-performance-symbol "session/child"
                                                          index))
         (sandbox-handle-ref
          (materialization-performance-symbol "sandbox/handle" index)))
    (list (cons 'source 'performance)
          (cons 'declared-session-refs
                (list 'session/root session-ref))
          (cons 'declared-parent-session-refs
                '(session/root session/system))
          (cons 'declared-sandbox-handle-refs
                (list sandbox-handle-ref)))))

;; : (-> Integer Alist)
(def (materialization-performance-row index)
  (agentic-ai-lab-session-materialization-receipt->alist
   (agentic-ai-lab-session-runtime-materialization-receipt
    (materialization-performance-symbol "runtime/request" index)
    'project/materialization
    'session/root
    (materialization-performance-symbol "session/child" index)
    '(session/root session/system)
    (materialization-performance-state index)
    (materialization-performance-symbol "runtime/future" index)
    (materialization-performance-sandbox-handle index)
    (materialization-performance-token-usage index)
    (materialization-performance-error index)
    (materialization-performance-metadata index))))

;; materialization-performance-valid-count
;;   : (-> [SessionMaterializationPerformanceRow] Integer)
;;   | doc m%
;;       Count materialized session rows whose receipt status remained valid
;;       after the performance projection.
;;
;;       # Examples
;;       ```scheme
;;       (materialization-performance-valid-count '())
;;       ;; => 0
;;       ```
;;     %
(def (materialization-performance-valid-count rows)
  (length
   (filter (lambda (row)
             (materialization-performance-ref row 'valid?))
           rows)))

;; materialization-performance-diagnostic-count
;;   : (-> [SessionMaterializationPerformanceRow] Integer)
;;   | doc m%
;;       Count diagnostics emitted by materialization receipts so the benchmark
;;       can gate correctness and policy noise separately.
;;
;;       # Examples
;;       ```scheme
;;       (materialization-performance-diagnostic-count '())
;;       ;; => 0
;;       ```
;;     %
(def (materialization-performance-diagnostic-count rows)
  (let (counts
        (map (lambda (row)
               (materialization-performance-ref row 'diagnostic-count))
             rows))
    (if (null? counts) 0 (apply + counts))))

;; : (-> Integer Alist)
(def (materialization-performance-summary count)
  (let (rows
        (agentic-ai-lab-performance-build-list
         count
         materialization-performance-row))
    (list (cons 'receipt-count (length rows))
          (cons 'first-state
                (materialization-performance-ref
                 (car rows)
                 'materialization-state))
          (cons 'last-state
                (materialization-performance-ref
                 (list-ref rows (- count 1))
                 'materialization-state))
          (cons 'valid-count
                (materialization-performance-valid-count rows))
          (cons 'diagnostic-count
                (materialization-performance-diagnostic-count rows))
          (cons 'declaration-checked?
                (materialization-performance-ref
                 (car rows)
                 'declaration-checked?))
          (cons 'sandbox-handle-declared?
                (materialization-performance-ref
                 (car rows)
                 'sandbox-handle-declared?))
          (cons 'runtime-executed
                (materialization-performance-ref
                 (car rows)
                 'runtime-executed)))))

;; : TestSuite
(def session-materialization-receipt-performance-test
  (test-suite "session materialization receipt performance"
    (yuanxu-test-case "keeps materialization receipt batch projection inside benchmark contract"
      (let* ((receipt-count 300)
             (summary (materialization-performance-summary receipt-count))
             (receipt
              (benchmark-run
               session-materialization-receipt-fixture
               (lambda ()
                 (materialization-performance-summary receipt-count)))))
        (check-equal?
         (benchmark-fixture-contract-pass?
          session-materialization-receipt-fixture)
         #t)
        (check-equal?
         (materialization-performance-ref summary 'receipt-count)
         receipt-count)
        (check-equal? (materialization-performance-ref summary 'first-state)
                      'pending)
        (check-equal? (materialization-performance-ref summary 'last-state)
                      'failed)
        (check-equal?
         (materialization-performance-ref summary 'valid-count)
         receipt-count)
        (check-equal?
         (materialization-performance-ref summary 'diagnostic-count)
         0)
        (check-equal?
         (materialization-performance-ref summary 'declaration-checked?)
         #t)
        (check-equal?
         (materialization-performance-ref summary 'sandbox-handle-declared?)
         #t)
        (check-equal?
         (materialization-performance-ref summary 'runtime-executed)
         #f)
        (materialization-performance-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
