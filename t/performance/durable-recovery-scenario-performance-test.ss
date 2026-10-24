;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable recovery scenario projection performance gate.
;;; Invariant: crash/replay/repair receipts stay bounded and report-only.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run/result)
        "../support/performance"
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/recovery-scenario
        :agentic-ai-lab/modules/session/transform
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects)

(export durable-recovery-scenario-performance-test)

;; : String
(def durable-recovery-scenario-fixture-path
  "t/scenarios/performance/durable-recovery-scenario/benchmark.ss")

;; : Alist
(def durable-recovery-scenario-fixture
  (call-with-input-file durable-recovery-scenario-fixture-path read))

;; : (-> Alist Symbol MaybeValue)
(def (durable-recovery-performance-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : (-> Alist Void)
(def (durable-recovery-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] durable-recovery-scenario ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> String Integer Symbol)
(def (durable-recovery-performance-symbol prefix index)
  (string->symbol
   (string-append prefix "/" (number->string index))))

;; : (-> PooDurableRuntimeStoreContractReceipt)
(def (durable-recovery-performance-runtime-store)
  (agentic-ai-lab-durable-runtime-store-contract->receipt
   agentic-ai-lab-durable-runtime-store-contract/default
   '((project-id . project/performance)
     (root-session-id . session/root)
     (session-id . session/recovery))))

;; : (-> [Alist])
(def (durable-recovery-performance-memory-job-rows)
  (let* ((intent
          (agentic-ai-lab-session-memory-intent
           'memory/performance-recovery
           'memory/durable-project
           'project
           '("last-40-turns")
           'review-only))
         (job
          (agentic-ai-lab-memory-recall-job-receipt
           'memory-job/performance-recovery
           'project/performance
           'session/root
           'session/recovery
           'agent/audit
           agentic-ai-lab-ai-agentic-context-memory-default-catalog
           intent
           (list (cons 'durable-policy agentic-ai-lab-durable-policy/default)
                 (cons 'source-watermark 'turn/40)
                 (cons 'target-watermark 'memory/index/40)))))
    (agentic-ai-lab-memory-durable-job-receipts->alists (list job))))

;; : Alist
(def durable-recovery-performance-session-graph-row
  '((kind . agentic-ai-lab.session.agent-graph)
    (project-id . project/performance)
    (root-session-ref . session/root)
    (agent-ids . (agent/build agent/audit))
    (session-ids . (session/root session/build session/recovery))
    (runtime-executed . #f)))

;; : [Alist]
(def durable-recovery-performance-communication-rows
  '(((kind . agentic-ai-lab.session.communication-receipt)
     (project-id . project/performance)
     (source-session-id . session/build)
     (target-session-id . session/recovery)
     (channel-id . channel/build-audit)
     (valid? . #t)
     (runtime-executed . #f))))

;; : (-> Integer Alist)
(def (durable-recovery-performance-workflow-task-row index)
  (list
   (cons 'kind 'agentic-ai-lab.workflow.cicd.check-receipt)
   (cons 'check (durable-recovery-performance-symbol "check" index))
   (cons 'durable-task-id
         (durable-recovery-performance-symbol "workflow/task" index))
   (cons 'action-class 'idempotent)
   (cons 'checkpoint-ref
         (durable-recovery-performance-symbol "checkpoint/task" index))
   (cons 'compensation-refs '())
   (cons 'sandbox-refs '(agent/nono))
   (cons 'valid? #t)
   (cons 'runtime-executed #f)))

;; : (-> PooDurableRuntimeStoreContractReceipt [Alist] Integer Alist)
(def (durable-recovery-performance-row runtime-store memory-job-rows index)
  (agentic-ai-lab-durable-recovery-scenario->alist
   (agentic-ai-lab-durable-recovery-scenario
    (durable-recovery-performance-symbol "recovery/perf" index)
    'project/performance
    'session/root
    'session/recovery
    runtime-store
    durable-recovery-performance-session-graph-row
    durable-recovery-performance-communication-rows
    memory-job-rows
    (list (durable-recovery-performance-workflow-task-row index))
    '(agent/nono))))

;; : (-> Integer Alist)
(def (durable-recovery-performance-summary count)
  (let* ((runtime-store (durable-recovery-performance-runtime-store))
         (memory-job-rows (durable-recovery-performance-memory-job-rows))
         (rows
          (agentic-ai-lab-performance-build-list
           count
           (lambda (index)
             (durable-recovery-performance-row
              runtime-store
              memory-job-rows
              index)))))
    (map (lambda (entry)
           (cons (car entry) ((cdr entry))))
         (list
          (cons 'scenario-count
                (lambda () (length rows)))
          (cons 'first-valid?
                (lambda ()
                  (durable-recovery-performance-ref (car rows) 'valid?)))
          (cons 'last-scenario-id
                (lambda ()
                  (durable-recovery-performance-ref
                   (list-ref rows (- count 1))
                   'scenario-id)))
          (cons 'observability-count
                (lambda ()
                  (length
                   (durable-recovery-performance-ref (car rows)
                                                     'observability-rows))))
          (cons 'runtime-executed
                (lambda ()
                  (durable-recovery-performance-ref (car rows)
                                                    'runtime-executed)))))))

;; : TestSuite
(def durable-recovery-scenario-performance-test
  (test-suite "durable recovery scenario performance"
    (yuanxu-test-case "keeps recovery scenario batch projection inside benchmark contract"
      (let* ((scenario-count 96))
        (let-values (((receipt summary)
                      (benchmark-run/result
                       durable-recovery-scenario-fixture
                       (lambda ()
                         (durable-recovery-performance-summary
                          scenario-count)))))
        (check-equal?
         (benchmark-fixture-contract-pass? durable-recovery-scenario-fixture)
         #t)
        (check-equal?
         (durable-recovery-performance-ref summary 'scenario-count)
         scenario-count)
        (check-equal?
         (durable-recovery-performance-ref summary 'first-valid?)
         #t)
        (check-equal?
         (durable-recovery-performance-ref summary 'last-scenario-id)
         'recovery/perf/95)
        (check-equal?
         (durable-recovery-performance-ref summary 'observability-count)
         6)
        (check-equal?
         (durable-recovery-performance-ref summary 'runtime-executed)
         #f)
        (durable-recovery-performance-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t))))))
