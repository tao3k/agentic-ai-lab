;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream durable operation bridge case.
;;; Invariant: this bridges user-visible durable rows to Marlin operation
;;; receipts only; Scheme does not execute runtime store side effects.

(import :agentic-ai-lab/modules/ai-agentic-context/features/memory/config
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store-backend
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store-operation
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store-operation-bridge
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/config)

(export agentic-ai-lab-custom-my-module-durable-operation-bridge-case)

(def agentic-ai-lab-custom-my-module-durable-operation-bridge-case
  (let* ((durable-policy
        (agentic-ai-lab-durable-policy
         'durable/custom-operation-bridge
         'objects.shared.durable
         '((journal-owner . runtime/fact-log)
           (checkpoint-store . runtime/checkpoint-store)
           (resume-identity . session-id)
           (repair-mode . rebuild)
           (action-classes . (replayable idempotent compensatable)))))
       (runtime-store
        (agentic-ai-lab-durable-runtime-store-contract
         'runtime-store/custom-project
         'marlin-runtime-store
         durable-policy
         '((metadata . ((source . user-interface)
                        (case . durable-operation-bridge))))))
       (contract-receipt
        (agentic-ai-lab-durable-runtime-store-contract->receipt
         runtime-store
         '((project-id . custom/project)
           (root-session-id . custom/root-session)
           (session-id . custom/audit-session))))
       (backend-receipt
        (agentic-ai-lab-durable-runtime-store-backend->receipt
         agentic-ai-lab-durable-runtime-store-backend/default))
       (negotiation
        (agentic-ai-lab-durable-runtime-store-backend-negotiation
         contract-receipt
         backend-receipt
         '((metadata . ((source . user-interface)
                        (case . durable-operation-bridge))))))
       (memory-intent
        (agentic-ai-lab-session-memory-intent
         'memory/operation-bridge-context
         'memory/durable-project
         'project
         '("last-40-turns")
         'review-only))
       (memory-job
        (agentic-ai-lab-memory-recall-job-receipt
         'memory-job/operation-bridge-context
         'custom/project
         'custom/root-session
         'custom/audit-session
         'agent/audit
         agentic-ai-lab-ai-agentic-context-memory-default-catalog
         memory-intent
         (list (cons 'durable-policy durable-policy)
               (cons 'source-watermark 'turn/40)
               (cons 'target-watermark 'memory/index/40)
               (cons 'metadata '((source . user-interface)
                                 (case . durable-operation-bridge))))))
       (communication
        (agentic-ai-lab-session-communication-receipt
         'custom/project
         'sibling
         'custom/root-session
         'custom/root-session
         'custom/build-session
         'custom/audit-session
         'agent/build
         'agent/audit
         'channel/build-audit
         'artifact-ready
         '((artifact . artifact/custom-package))
         'at-least-once
         (list (cons 'communication-ledger-ref 'runtime/communication-ledger)
               (cons 'durable-policy durable-policy)
               (cons 'metadata '((source . user-interface)
                                 (case . durable-operation-bridge))))))
       (session-graph-row
        '((kind . agentic-ai-lab.session.agent-graph)
          (project-id . custom/project)
          (root-session-ref . custom/root-session)
          (agent-ids . (agent/build agent/audit))
          (session-ids . (custom/root-session custom/build-session
                         custom/audit-session))
          (lineage-edge-pairs . ((custom/root-session . custom/build-session)
                                 (custom/root-session . custom/audit-session)))
          (runtime-executed . #f)))
       (communication-rows
        (agentic-ai-lab-session-communication-receipts->alists
         (list communication)))
       (memory-job-rows
        (agentic-ai-lab-memory-durable-job-receipts->alists (list memory-job)))
       (workflow-task-rows
        '(((kind . agentic-ai-lab.workflow.cicd.check-receipt)
           (check . build)
           (durable-task-id . workflow/custom-build)
           (action-class . idempotent)
           (checkpoint-ref . checkpoint/custom-build)
           (artifact-refs . (artifact/custom-log artifact/custom-package))
           (sandbox-refs . (agent/nono))
           (valid? . #t)
           (runtime-executed . #f))))
       (operations
        (agentic-ai-lab-durable-runtime-store-operations-from-rows
         negotiation
         session-graph-row
         communication-rows
         memory-job-rows
         workflow-task-rows
         '(agent/nono))))
  (list
   (agentic-ai-lab-durable-runtime-store-negotiation-receipt->alist negotiation)
   (agentic-ai-lab-durable-runtime-store-operation-receipts->alists operations)
    (agentic-ai-lab-durable-runtime-store-operations->marlin-handoff negotiation
                                                                operations))))
