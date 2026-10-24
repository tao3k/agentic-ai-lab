;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: bridge existing durable rows into runtime store operation rows.
;;; Invariant: bridge tests validate projection only; no runtime store runs.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store-backend
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store-operation
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store-operation-bridge)

(export durable-runtime-store-operation-bridge-test)

;; : (-> Alist Symbol Object)
(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : (-> [Alist] Symbol Alist)
(def (find-operation-row rows operation-kind)
  (cond
   ((null? rows) #f)
   ((eq? (test-ref (car rows) 'operation-kind) operation-kind) (car rows))
   (else (find-operation-row (cdr rows) operation-kind))))

;; : (-> Alist)
(def (test-negotiation)
  (let* ((contract
          (agentic-ai-lab-durable-runtime-store-contract
           'runtime-store/project
           'marlin-runtime-store
           (agentic-ai-lab-durable-policy
            'durable/bridge
            'objects.shared.durable
            '((repair-mode . rebuild)
              (action-classes . (replayable idempotent compensatable))))))
         (contract-receipt
          (agentic-ai-lab-durable-runtime-store-contract->receipt
           contract
           '((project-id . project/agentic-ai-lab)
             (root-session-id . session/root)
             (session-id . session/child))))
         (backend-receipt
          (agentic-ai-lab-durable-runtime-store-backend->receipt
           agentic-ai-lab-durable-runtime-store-backend/default)))
    (agentic-ai-lab-durable-runtime-store-backend-negotiation contract-receipt
                                                        backend-receipt)))

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
     (relation-kind . parent-child)
     (source-session-id . session/root)
     (target-session-id . session/child)
     (source-agent-id . agent/root)
     (target-agent-id . agent/audit)
     (channel-id . channel/root-child)
     (communication-ledger-ref . runtime/communication-ledger)
     (valid? . #t)
     (runtime-executed . #f))))

;; : [Alist]
(def test-memory-job-rows
  '(((kind . agentic-ai-lab.memory-core.durable-job-receipt)
     (job-id . memory-job/recovery-context)
     (job-kind . recall)
     (job-state . planned)
     (project-id . project/agentic-ai-lab)
     (root-session-id . session/root)
     (session-id . session/child)
     (source-ref . memory/recovery-context)
     (job-store-ref . runtime/job-store)
     (checkpoint-store-ref . runtime/checkpoint-store)
     (valid? . #t)
     (runtime-executed . #f))))

;; : [Alist]
(def test-workflow-task-rows
  '(((kind . agentic-ai-lab.workflow.cicd.check-receipt)
     (check . build)
     (durable-task-id . workflow/build)
     (action-class . idempotent)
     (checkpoint-ref . checkpoint/build)
     (artifact-refs . (artifact/build-log artifact/package))
     (sandbox-refs . (agent/nono))
     (valid? . #t)
     (runtime-executed . #f))))

;; : TestSuite
(def durable-runtime-store-operation-bridge-test
  (test-suite "agentic-ai-lab durable runtime store operation bridge"
    (yuanxu-test-case "bridges session memory workflow artifact and sandbox rows"
      (let* ((negotiation (test-negotiation))
             (operations
              (agentic-ai-lab-durable-runtime-store-operations-from-rows
               negotiation
               test-session-graph-row
               test-communication-rows
               test-memory-job-rows
               test-workflow-task-rows
               '(agent/nono)))
             (rows
              (agentic-ai-lab-durable-runtime-store-operation-receipts->alists
               operations))
             (handoff
              (agentic-ai-lab-durable-runtime-store-operations->marlin-handoff
               negotiation
               operations)))
        (check-equal? (length rows) 7)
        (check-equal? (map (lambda (row) (test-ref row 'operation-kind))
                           rows)
                      '(append-fact
                        append-communication-event
                        claim-job-lease
                        append-fact
                        retain-artifact
                        retain-artifact
                        attach-sandbox-handle))
        (check-equal? (map (lambda (row) (test-ref row 'valid?)) rows)
                      '(#t #t #t #t #t #t #t))
        (check-equal? (test-ref
                       (find-operation-row rows 'append-communication-event)
                       'target-ref)
                      'runtime/communication-ledger)
        (check-equal? (test-ref
                       (find-operation-row rows 'claim-job-lease)
                       'target-ref)
                      'runtime/job-store)
        (check-equal? (test-ref handoff 'handoff-ready?) #t)
        (check-equal? (test-ref handoff 'operation-count) 7)
        (check-equal? (test-ref handoff 'runtime-executed) #f)))

    (yuanxu-test-case "preserves operation diagnostics from invalid source rows"
      (let* ((operations
              (agentic-ai-lab-durable-runtime-store-operations-from-rows
               (test-negotiation)
               #f
               '()
               '(((kind . agentic-ai-lab.memory-core.durable-job-receipt)
                  (job-id . memory-job/bad)
                  (job-store-ref . "bad-target")
                  (valid? . #f)))
               '()
               '()))
             (rows
              (agentic-ai-lab-durable-runtime-store-operation-receipts->alists
               operations))
             (row (car rows)))
        (check-equal? (length rows) 1)
        (check-equal? (test-ref row 'operation-kind) 'claim-job-lease)
        (check-equal? (test-ref row 'valid?) #f)
        (check-equal? (test-ref row 'diagnostic-count) 1)))))
