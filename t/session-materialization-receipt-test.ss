;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: runtime materialization receipt projection.
;;; Invariant: Scheme records pending/materialized/failed state only; it never
;;; synchronizes runtime futures, opens sandbox handles, or replays IO.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        :agentic-ai-lab/modules/session/config)

(export session-materialization-receipt-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : TestSuite
(def session-materialization-receipt-test
  (test-suite "agentic-ai-lab session materialization receipts"
    (yuanxu-test-case "projects pending runtime materialization receipt"
      (let* ((receipt
              (agentic-ai-lab-session-runtime-materialization-receipt
               'runtime/request-1
               'project/materialization
               'session/root
               'session/build
               '(session/root session/build-system)
               'pending
               'runtime/future-1
               'sandbox/build-handle
               '()
               #f
               '((case . unit))))
             (row
              (agentic-ai-lab-session-materialization-receipt->alist receipt)))
        (check-equal? (agentic-ai-lab-session-materialization-receipt? receipt)
                      #t)
        (check-equal?
         (agentic-ai-lab-session-materialization-receipt-request-id receipt)
         'runtime/request-1)
        (check-equal?
         (agentic-ai-lab-session-materialization-receipt-state receipt)
         'pending)
        (check-equal?
         (agentic-ai-lab-session-materialization-receipt-parent-session-refs
          receipt)
         '(session/root session/build-system))
        (check-equal?
         (agentic-ai-lab-session-materialization-receipt-sandbox-handle-ref
          receipt)
         'sandbox/build-handle)
        (check-equal? (test-ref row 'kind)
                      'agentic-ai-lab.session.materialization-receipt)
        (check-equal? (test-ref row 'materialization-state) 'pending)
        (check-equal? (test-ref row 'handoff-required) #t)
        (check-equal? (test-ref row 'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (test-ref row 'runtime-executed) #f)))
    (yuanxu-test-case "projects materialized token usage without executing runtime"
      (let* ((receipt
              (agentic-ai-lab-session-runtime-materialization-receipt
               'runtime/request-2
               'project/materialization
               'session/root
               'session/build
               '(session/root)
               'materialized
               'runtime/future-2
               'sandbox/build-handle
               '((prompt-tokens . 12)
                 (completion-tokens . 8)
                 (total-tokens . 20))
               #f))
             (row
              (agentic-ai-lab-session-materialization-receipt->alist receipt)))
        (check-equal? (test-ref row 'materialization-state)
                      'materialized)
        (check-equal? (test-ref (test-ref row 'token-usage-summary)
                                'total-tokens)
                      20)
        (check-equal? (test-ref row 'error-summary) #f)
        (check-equal? (test-ref row 'runtime-executed) #f)))
    (yuanxu-test-case "projects failed materialization error summary"
      (let* ((receipt
              (agentic-ai-lab-session-runtime-materialization-receipt
               'runtime/request-3
               'project/materialization
               'session/root
               'session/build
               '(session/root)
               'failed
               'runtime/future-3
               #f
               '()
               '((error-kind . RuntimeError)
                 (message . "kaboom")
                 (recoverable? . #f))))
             (row
              (agentic-ai-lab-session-materialization-receipt->alist receipt)))
        (check-equal? (test-ref row 'materialization-state) 'failed)
        (check-equal? (test-ref row 'sandbox-handle-ref) #f)
        (check-equal? (test-ref (test-ref row 'error-summary)
                                'error-kind)
                      'RuntimeError)
        (check-equal? (test-ref row 'runtime-executed) #f)))))
