;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream durable runtime store operation case.
;;; Invariant: this declares operation receipts only; Marlin owns all durable
;;; store side effects.

(import :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store-backend
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store-operation)

(export agentic-ai-lab-custom-my-module-durable-runtime-store-operations-case)

(def agentic-ai-lab-custom-my-module-durable-runtime-store-operations-case
  (let* ((durable-policy
        (agentic-ai-lab-durable-policy
         'durable/custom-runtime-store-operations
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
                        (case . durable-runtime-store-operations))))))
       (contract-receipt
        (agentic-ai-lab-durable-runtime-store-contract->receipt
         runtime-store
         '((project-id . custom/project)
           (root-session-id . custom/root-session)
           (session-id . custom/root-session))))
       (backend-receipt
        (agentic-ai-lab-durable-runtime-store-backend->receipt
         agentic-ai-lab-durable-runtime-store-backend/default))
       (negotiation
        (agentic-ai-lab-durable-runtime-store-backend-negotiation
         contract-receipt
         backend-receipt
         '((metadata . ((source . user-interface)
                        (case . durable-runtime-store-operations))))))
       (operation-options
        '((causal-refs . (custom/root-event))
          (watermark . custom/runtime-store-operation-watermark)
          (metadata . ((source . user-interface)
                       (case . durable-runtime-store-operations)))))
       (operations
        (agentic-ai-lab-durable-runtime-store-operation-receipts negotiation
                                                          operation-options)))
  (list
   (agentic-ai-lab-durable-runtime-store-negotiation-receipt->alist negotiation)
   (agentic-ai-lab-durable-runtime-store-operation-receipts->alists operations)
    (agentic-ai-lab-durable-runtime-store-operations->marlin-handoff negotiation
                                                                operations))))
