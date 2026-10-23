;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable memory job receipts for Rust/Marlin handoff.
;;; Invariant: Scheme validates and projects memory jobs only; it never recalls,
;;; commits, consolidates, persists, or repairs memory stores.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object object?)
        :poo-flow/modules/ai-agentic-context/features/memory/durable/policy
        :poo-flow/modules/session/config
        :poo-flow/modules/ai-agentic-context/features/memory/config)

(export memory-durable-job-receipt-test)

;; : (-> Alist Symbol Value)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : (-> [Alist] Symbol Boolean)
(def (diagnostic-code-present? diagnostics code)
  (cond
   ((null? diagnostics) #f)
   ((equal? (test-ref (car diagnostics) 'code) code) #t)
   (else
    (diagnostic-code-present? (cdr diagnostics) code))))

;; : TestSuite
(def memory-durable-job-receipt-test
  (test-suite "poo-flow memory durable job receipts"
    (yuanxu-test-case "projects recall, write, consolidation, stale, and repair jobs"
      (let* ((durable-policy
              (poo-flow-durable-policy
               'durable/memory
               'objects.shared.memory
               '((journal-owner . runtime/fact-log)
                 (checkpoint-store . runtime/checkpoint-store)
                 (resume-identity . session-id)
                 (repair-mode . rebuild)
                 (action-classes . (replayable idempotent compensatable)))))
             (parent-summary
              (poo-flow-session-memory-intent
               'memory/parent-summary
               'memory/durable-project
               'parent-summary
               '(parent-summary)
               'review-only))
             (child-write
              (poo-flow-session-memory-intent
               'memory/child-write-back
               'memory/durable-project
               'current-session
               '()
               'append))
             (bounded-transcript
              (poo-flow-session-memory-intent
               'memory/bounded-transcript
               'memory/durable-project
               'project
               '("last-40-turns")
               'review-only))
             (options
              (list (cons 'durable-policy durable-policy)
                    (cons 'source-watermark 'turn/40)
                    (cons 'target-watermark 'memory/index/40)
                    (cons 'usage-counter 3)
                    (cons 'metadata '((case . memory-durable-job)))))
             (jobs
              (list
               (poo-flow-memory-recall-job-receipt
                'memory-job/parent-summary
                'project/poo-flow
                'session/root
                'session/child
                'agent/reviewer
                poo-flow-ai-agentic-context-memory-default-catalog
                parent-summary
                options)
               (poo-flow-memory-write-job-receipt
                'memory-job/child-write
                'project/poo-flow
                'session/root
                'session/child
                'agent/reviewer
                poo-flow-ai-agentic-context-memory-default-catalog
                child-write
                options)
               (poo-flow-memory-consolidation-job-receipt
                'memory-job/consolidate
                'project/poo-flow
                'session/root
                'session/child
                #f
                poo-flow-ai-agentic-context-memory-default-catalog
                bounded-transcript
                options)
               (poo-flow-memory-stale-source-job-receipt
                'memory-job/stale-source
                'project/poo-flow
                'session/root
                'session/child
                #f
                poo-flow-ai-agentic-context-memory-default-catalog
                bounded-transcript
                (cons (cons 'stale-source? #t) options))
               (poo-flow-memory-repair-job-receipt
                'memory-job/repair
                'project/poo-flow
                'session/root
                'session/child
                #f
                poo-flow-ai-agentic-context-memory-default-catalog
                bounded-transcript
                (cons (cons 'job-state 'repair-required) options))))
             (rows
              (poo-flow-memory-durable-job-receipts->alists jobs))
             (recall-row (car rows))
             (repair-row (car (cddddr rows))))
        (check-equal? (length jobs) 5)
        (check-equal? (length rows) 5)
        (check-equal? (poo-flow-memory-durable-job-receipt? (car jobs))
                      #t)
        (check-equal? (object? recall-row) #f)
        (check-equal? (test-ref recall-row 'kind)
                      +poo-flow-ai-agentic-context-memory-durable-job-receipt-kind+)
        (check-equal? (map (lambda (row) (test-ref row 'job-kind)) rows)
                      '(recall write consolidation stale-source repair))
        (check-equal? (test-ref recall-row 'project-id) 'project/poo-flow)
        (check-equal? (test-ref recall-row 'root-session-id) 'session/root)
        (check-equal? (test-ref recall-row 'session-id) 'session/child)
        (check-equal? (test-ref recall-row 'agent-id) 'agent/reviewer)
        (check-equal? (test-ref recall-row 'store-ref) 'memory/durable-project)
        (check-equal? (test-ref recall-row 'durable-policy-ref)
                      'durable/memory)
        (check-equal? (test-ref recall-row 'job-store-ref)
                      'runtime/job-store)
        (check-equal? (test-ref recall-row 'checkpoint-store-ref)
                      'runtime/checkpoint-store)
        (check-equal? (test-ref recall-row 'source-watermark) 'turn/40)
        (check-equal? (test-ref recall-row 'target-watermark)
                      'memory/index/40)
        (check-equal? (test-ref recall-row 'usage-counter) 3)
        (check-equal? (test-ref recall-row 'valid?) #t)
        (check-equal? (test-ref recall-row 'diagnostic-count) 0)
        (check-equal? (test-ref repair-row 'job-state) 'repair-required)
        (check-equal? (test-ref repair-row 'runtime-executed) #f)))

    (yuanxu-test-case "rejects fake durable memory jobs without durable store policy"
      (let* ((local-intent
              (poo-flow-session-memory-intent
               'memory/local-fake
               'memory/local-session
               'current-session
               '(last-turn)
               'append))
             (receipt
              (poo-flow-memory-recall-job-receipt
               'memory-job/local-fake
               'project/poo-flow
               'session/root
               'session/child
               #f
               poo-flow-ai-agentic-context-memory-default-catalog
               local-intent))
             (row (poo-flow-memory-durable-job-receipt->alist receipt))
             (diagnostics (test-ref row 'diagnostics)))
        (check-equal? (poo-flow-memory-durable-job-receipt-valid? receipt)
                      #f)
        (check-equal? (test-ref row 'valid?) #f)
        (check-equal? (> (test-ref row 'diagnostic-count) 0) #t)
        (check-equal?
         (diagnostic-code-present? diagnostics 'missing-durable-policy-ref)
         #t)
        (check-equal?
         (diagnostic-code-present? diagnostics 'memory-store-not-durable)
         #t)
        (check-equal?
         (diagnostic-code-present? diagnostics 'memory-intent-commit-denied)
         #t)))))
