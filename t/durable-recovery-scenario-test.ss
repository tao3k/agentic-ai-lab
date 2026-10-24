;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: crash/replay/repair scenario receipts for durable policy.
;;; Invariant: tests validate scenario projection only; no runtime recovery runs.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object object?)
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/recovery-scenario
        :agentic-ai-lab/modules/session/config
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/config)

(export durable-recovery-scenario-test)

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

;; : (-> PooDurableRuntimeStoreContractReceipt)
(def (test-runtime-store-receipt)
  (agentic-ai-lab-durable-runtime-store-contract->receipt
   agentic-ai-lab-durable-runtime-store-contract/default
   '((project-id . project/agentic-ai-lab)
     (root-session-id . session/root)
     (session-id . session/child))))

;; : (-> [Alist])
(def (test-memory-job-rows)
  (let* ((intent
          (agentic-ai-lab-session-memory-intent
           'memory/recovery-context
           'memory/durable-project
           'project
           '("last-40-turns")
           'review-only))
         (job
          (agentic-ai-lab-memory-recall-job-receipt
           'memory-job/recovery-context
           'project/agentic-ai-lab
           'session/root
           'session/child
           'agent/audit
           agentic-ai-lab-ai-agentic-context-memory-default-catalog
           intent
           (list (cons 'durable-policy agentic-ai-lab-durable-policy/default)
                 (cons 'source-watermark 'turn/40)
                 (cons 'target-watermark 'memory/index/40)))))
    (agentic-ai-lab-memory-durable-job-receipts->alists (list job))))

;; : Alist
(def test-session-graph-row
  '((kind . agentic-ai-lab.session.agent-graph)
    (project-id . project/agentic-ai-lab)
    (root-session-ref . session/root)
    (agent-ids . (agent/build agent/audit))
    (session-ids . (session/root session/child))
    (runtime-executed . #f)))

;; : [Alist]
(def test-communication-rows
  '(((kind . agentic-ai-lab.session.communication-receipt)
     (project-id . project/agentic-ai-lab)
     (source-session-id . session/root)
     (target-session-id . session/child)
     (channel-id . channel/root-child)
     (valid? . #t)
     (runtime-executed . #f))))

;; : [Alist]
(def test-workflow-task-rows
  '(((kind . agentic-ai-lab.workflow.cicd.check-receipt)
     (check . build)
     (durable-task-id . workflow/build)
     (action-class . idempotent)
     (checkpoint-ref workflow-cicd-check build)
     (compensation-refs)
     (sandbox-refs agent/nono)
     (valid? . #t)
     (runtime-executed . #f))))

;; : TestSuite
(def durable-recovery-scenario-test
  (test-suite "agentic-ai-lab durable recovery scenario"
    (yuanxu-test-case "projects crash replay recovery with observability stages"
      (let* ((receipt
              (agentic-ai-lab-durable-recovery-scenario
               'recovery-scenario/build-audit
               'project/agentic-ai-lab
               'session/root
               'session/child
               (test-runtime-store-receipt)
               test-session-graph-row
               test-communication-rows
               (test-memory-job-rows)
               test-workflow-task-rows
               '(agent/nono)
               '((metadata . ((case . durable-recovery-scenario))))))
             (row (agentic-ai-lab-durable-recovery-scenario->alist receipt))
             (observability-rows (test-ref row 'observability-rows)))
        (check-equal? (agentic-ai-lab-durable-recovery-scenario-receipt? receipt)
                      #t)
        (check-equal? (object? row) #f)
        (check-equal? (test-ref row 'kind)
                      +agentic-ai-lab-durable-recovery-scenario-kind+)
        (check-equal? (test-ref row 'scenario-id)
                      'recovery-scenario/build-audit)
        (check-equal? (test-ref row 'failure-kind) 'process-crash)
        (check-equal? (test-ref row 'recovery-mode) 'replay)
        (check-equal? (test-ref row 'event-log-ref) 'runtime/fact-log)
        (check-equal? (test-ref row 'checkpoint-ref)
                      'runtime/checkpoint-store)
        (check-equal? (test-ref row 'derived-index-ref)
                      'runtime/derived-index)
        (check-equal? (test-ref row 'job-lease-ref) 'runtime/job-store)
        (check-equal? (test-ref row 'repair-journal-ref)
                      'runtime/repair-journal)
        (check-equal? (test-ref row 'deterministic-replay?) #t)
        (check-equal? (test-ref row 'valid?) #t)
        (check-equal? (test-ref row 'diagnostic-count) 0)
        (check-equal? (length observability-rows) 6)
        (check-equal? (map (lambda (row) (test-ref row 'stage))
                           observability-rows)
                      +agentic-ai-lab-durable-recovery-stages+)
        (check-equal? (map (lambda (row) (test-ref row 'runtime-executed))
                           observability-rows)
                      '(#f #f #f #f #f #f))
        (check-equal? (test-ref row 'runtime-executed) #f)))

    (yuanxu-test-case "rejects unsafe replay without memory durable jobs"
      (let* ((unsafe-task-rows
              '(((kind . agentic-ai-lab.workflow.cicd.check-receipt)
                 (check . release)
                 (durable-task-id . workflow/release)
                 (action-class . manual)
                 (checkpoint-ref . #f)
                 (compensation-refs)
                 (sandbox-refs agent/nono)
                 (valid? . #t))))
             (receipt
              (agentic-ai-lab-durable-recovery-scenario
               'recovery-scenario/unsafe-release
               'project/agentic-ai-lab
               'session/root
               'session/child
               (test-runtime-store-receipt)
               test-session-graph-row
               '()
               '()
               unsafe-task-rows
               '()))
             (row (agentic-ai-lab-durable-recovery-scenario->alist receipt))
             (diagnostics (test-ref row 'diagnostics)))
        (check-equal? (test-ref row 'valid?) #f)
        (check-equal? (test-ref row 'deterministic-replay?) #f)
        (check-equal? (> (test-ref row 'diagnostic-count) 0) #t)
        (check-equal?
         (diagnostic-code-present? diagnostics 'missing-memory-durable-job)
         #t)
        (check-equal?
         (diagnostic-code-present? diagnostics 'missing-task-checkpoint)
         #t)
        (check-equal?
         (diagnostic-code-present? diagnostics
                                   'non-idempotent-without-compensation)
         #t)
        (check-equal?
         (diagnostic-code-present? diagnostics 'unsafe-manual-replay)
         #t)
        (check-equal?
         (diagnostic-code-present? diagnostics 'unresolved-sandbox-ref)
         #t)))

    (yuanxu-test-case "reports invalid durable memory job rows"
      (let* ((invalid-memory-rows
              '(((kind . agentic-ai-lab.memory-core.durable-job-receipt)
                 (job-id . memory-job/fake)
                 (valid? . #f)
                 (diagnostics . (((code . memory-store-not-durable)))))))
             (receipt
              (agentic-ai-lab-durable-recovery-scenario
               'recovery-scenario/invalid-memory
               'project/agentic-ai-lab
               'session/root
               'session/child
               (test-runtime-store-receipt)
               test-session-graph-row
               '()
               invalid-memory-rows
               test-workflow-task-rows
               '(agent/nono)))
             (row (agentic-ai-lab-durable-recovery-scenario->alist receipt))
             (diagnostics (test-ref row 'diagnostics)))
        (check-equal? (test-ref row 'valid?) #f)
        (check-equal?
         (diagnostic-code-present? diagnostics 'invalid-memory-durable-job)
         #t)))))
