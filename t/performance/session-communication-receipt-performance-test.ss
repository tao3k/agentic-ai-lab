;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: session communication receipt performance gate.
;;; Invariant: communication projection stays bounded and report-only.

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

(export session-communication-receipt-performance-test)

;; : String
(def session-communication-receipt-fixture-path
  "t/scenarios/performance/session-communication-receipt/benchmark.ss")

;; : Alist
(def session-communication-receipt-fixture
  (call-with-input-file session-communication-receipt-fixture-path read))

;; : (-> Alist Symbol MaybeValue)
(def (communication-performance-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : (-> Alist Void)
(def (communication-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] session-communication-receipt ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> String Integer Symbol)
(def (communication-performance-symbol prefix index)
  (string->symbol
   (string-append prefix "/" (number->string index))))

;; : (-> Integer Symbol)
(def (communication-performance-relation-kind index)
  (cond
   ((= (modulo index 4) 0) 'parent-child)
   ((= (modulo index 4) 1) 'child-parent)
   ((= (modulo index 4) 2) 'sibling)
   (else 'cross-root)))

;; : (-> Integer PooSessionCommunicationReceipt)
(def (communication-performance-receipt index)
  (let* ((relation-kind (communication-performance-relation-kind index))
         (target-root (if (eq? relation-kind 'cross-root)
                        'root/release
                        'root/main)))
    (agentic-ai-lab-session-communication-receipt
     'project/performance
     relation-kind
     'root/main
     target-root
     (communication-performance-symbol "session/source" index)
     (communication-performance-symbol "session/target" index)
     (communication-performance-symbol "agent/source" index)
     (communication-performance-symbol "agent/target" index)
     (communication-performance-symbol "channel" index)
     'receipt
     (list (cons 'summary "performance communication receipt"))
     (if (eq? relation-kind 'cross-root)
       'explicit-project-root
       'declared-channel-only)
     '((communication-ledger-ref . runtime/performance-ledger)
       (durable-policy-ref . durable/performance)))))

;; : (-> Integer Alist)
(def (communication-performance-summary count)
  (let* ((receipts
          (agentic-ai-lab-performance-build-list
           count
           communication-performance-receipt))
         (rows (agentic-ai-lab-session-communication-receipts->alists receipts)))
    (map (lambda (entry)
           (cons (car entry) ((cdr entry))))
         (list
          (cons 'receipt-count
                (lambda () (length rows)))
          (cons 'first-relation
                (lambda ()
                  (communication-performance-ref (car rows) 'relation-kind)))
          (cons 'last-channel
                (lambda ()
                  (communication-performance-ref
                   (list-ref rows (- count 1))
                   'channel-id)))
          (cons 'handoff-required
                (lambda ()
                  (communication-performance-ref (car rows)
                                                 'handoff-required)))
          (cons 'runtime-executed
                (lambda ()
                  (communication-performance-ref (car rows)
                                                 'runtime-executed)))))))

;; : TestSuite
(def session-communication-receipt-performance-test
  (test-suite "session communication receipt performance"
    (yuanxu-test-case "keeps communication receipt batch projection inside benchmark contract"
      (let* ((receipt-count 320)
             (summary (communication-performance-summary receipt-count))
             (receipt
              (benchmark-run
               session-communication-receipt-fixture
               (lambda ()
                 (communication-performance-summary receipt-count)))))
        (check-equal?
         (benchmark-fixture-contract-pass?
          session-communication-receipt-fixture)
         #t)
        (check-equal?
         (communication-performance-ref summary 'receipt-count)
         receipt-count)
        (check-equal?
         (communication-performance-ref summary 'first-relation)
         'parent-child)
        (check-equal?
         (communication-performance-ref summary 'last-channel)
         'channel/319)
        (check-equal?
         (communication-performance-ref summary 'handoff-required)
         #t)
        (check-equal?
         (communication-performance-ref summary 'runtime-executed)
         #f)
        (communication-performance-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
