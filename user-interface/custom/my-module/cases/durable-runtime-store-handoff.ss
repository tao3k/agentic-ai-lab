;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream durable runtime store backend handoff case.
;;; Invariant: this declares backend negotiation data only; Marlin owns the
;;; store implementation and all durable side effects.

(import :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store-backend)

(export agentic-ai-lab-custom-my-module-durable-runtime-store-handoff-case)

(def agentic-ai-lab-custom-my-module-durable-runtime-store-handoff-case
  (let* ((durable-policy
        (agentic-ai-lab-durable-policy
         'durable/custom-runtime-store
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
                        (case . durable-runtime-store-handoff))))))
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
                        (case . durable-runtime-store-handoff)))))))
  (list
   (agentic-ai-lab-durable-runtime-store-negotiation-receipt->alist negotiation)
    (agentic-ai-lab-durable-runtime-store-negotiation->marlin-handoff negotiation))))
