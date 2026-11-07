;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Projects admitted validation receipts into the stable report ABI.
;;; This owner does not construct, validate, or execute a Session.
(import :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/receipt-syntax
        :agentic-ai-lab/modules/session/receipt-projection
        :agentic-ai-lab/modules/session/policy-validation-receipt-core)

(export agentic-ai-lab-session-policy-validation-receipt->alist
        agentic-ai-lab-session-policy-validation-receipts->alists)

;; : (-> PooSessionPolicyValidationReceipt Alist)
(defpoo-session-receipt-projection
  agentic-ai-lab-session-policy-validation-receipt->alist
  (receipt)
  (require agentic-ai-lab-session-require
           "session policy validation projection requires a receipt"
           (agentic-ai-lab-session-policy-validation-receipt? receipt)
           receipt)
  (bindings ())
  (fields
   (('kind 'agentic-ai-lab.session.policy-validation-receipt)
    ('schema 'agentic-ai-lab.modules.session.policy-validation-receipt.v1)
    ('validation-id
     (agentic-ai-lab-session-policy-validation-receipt-record-validation-id
      receipt))
    ('scope-ref
     (agentic-ai-lab-session-policy-validation-receipt-record-scope-ref
      receipt))
    ('valid?
     (agentic-ai-lab-session-policy-validation-receipt-valid? receipt))
    ('effective-model-ref
     (agentic-ai-lab-session-policy-validation-receipt-effective-model-ref
      receipt))
    ('effective-prompt-session-ref
     (agentic-ai-lab-session-policy-validation-receipt-effective-prompt-session-ref
      receipt))
    ('effective-prompt-chunk-refs
     (agentic-ai-lab-session-policy-validation-receipt-effective-prompt-chunk-refs
      receipt))
    ('effective-isolation-mode
     (agentic-ai-lab-session-policy-validation-receipt-effective-isolation-mode
      receipt))
    ('isolation-sibling-context
     (agentic-ai-lab-session-policy-validation-receipt-record-isolation-sibling-context
      receipt))
    ('isolation-parent-write
     (agentic-ai-lab-session-policy-validation-receipt-record-isolation-parent-write
      receipt))
    ('isolation-peer-communication
     (agentic-ai-lab-session-policy-validation-receipt-record-isolation-peer-communication
      receipt))
    ('effective-sandbox-profile-ref
     (agentic-ai-lab-session-policy-validation-receipt-effective-sandbox-profile-ref
      receipt))
    ('sandbox-inheritance-mode
     (agentic-ai-lab-session-policy-validation-receipt-record-sandbox-inheritance-mode
      receipt))
    ('sandbox-sharing-mode
     (agentic-ai-lab-session-policy-validation-receipt-record-sandbox-sharing-mode
      receipt))
    ('allowed-context-refs
     (agentic-ai-lab-session-policy-validation-receipt-record-allowed-context-refs
      receipt))
    ('denied-context-refs
     (agentic-ai-lab-session-policy-validation-receipt-record-denied-context-refs
      receipt))
    ('allowed-history-records
     (agentic-ai-lab-session-policy-validation-receipt-record-allowed-history-records
      receipt))
    ('denied-history-records
     (agentic-ai-lab-session-policy-validation-receipt-record-denied-history-records
      receipt))
    ('allowed-communication-channels
     (agentic-ai-lab-session-policy-validation-receipt-record-allowed-communication-channels
      receipt))
    ('denied-communication-channels
     (agentic-ai-lab-session-policy-validation-receipt-record-denied-communication-channels
      receipt))
    ('allowed-communication-channel-receipts
     (agentic-ai-lab-session-policy-validation-receipt-allowed-communication-channel-receipts
      receipt))
    ('denied-communication-channel-receipts
     (agentic-ai-lab-session-policy-validation-receipt-denied-communication-channel-receipts
      receipt))
    ('allowed-communication-receipts
     (agentic-ai-lab-session-policy-validation-receipt-allowed-communication-receipts
      receipt))
    ('denied-communication-receipts
     (agentic-ai-lab-session-policy-validation-receipt-denied-communication-receipts
      receipt))
    ('allowed-resource-refs
     (agentic-ai-lab-session-policy-validation-receipt-record-allowed-resource-refs
      receipt))
    ('denied-resource-refs
     (agentic-ai-lab-session-policy-validation-receipt-record-denied-resource-refs
      receipt))
    ('allowed-agent-tool-attempts
     (agentic-ai-lab-session-policy-validation-receipt-record-allowed-agent-tool-attempts
      receipt))
    ('denied-agent-tool-attempts
     (agentic-ai-lab-session-policy-validation-receipt-record-denied-agent-tool-attempts
      receipt))
    ('allowed-hook-tool-attempts
     (agentic-ai-lab-session-policy-validation-receipt-record-allowed-hook-tool-attempts
      receipt))
    ('denied-hook-tool-attempts
     (agentic-ai-lab-session-policy-validation-receipt-record-denied-hook-tool-attempts
      receipt))
    ('tool-catalog-validation-id
     (agentic-ai-lab-session-policy-validation-receipt-record-tool-catalog-validation-id
      receipt))
    ('tool-catalog-ref
     (agentic-ai-lab-session-policy-validation-receipt-record-tool-catalog-ref
      receipt))
    ('tool-catalog-valid?
     (agentic-ai-lab-session-policy-validation-receipt-tool-catalog-valid?
      receipt))
    ('tool-catalog-policy-tool-refs
     (agentic-ai-lab-session-policy-validation-receipt-record-tool-catalog-policy-tool-refs
      receipt))
    ('tool-catalog-resolved-tool-refs
     (agentic-ai-lab-session-policy-validation-receipt-record-tool-catalog-resolved-tool-refs
      receipt))
    ('tool-catalog-unresolved-tool-refs
     (agentic-ai-lab-session-policy-validation-receipt-record-tool-catalog-unresolved-tool-refs
      receipt))
    ('tool-catalog-sandbox-required-tool-refs
     (agentic-ai-lab-session-policy-validation-receipt-record-tool-catalog-sandbox-required-tool-refs
      receipt))
    ('tool-catalog-action-mismatch-grants
     (agentic-ai-lab-session-policy-validation-receipt-record-tool-catalog-action-mismatch-grants
      receipt))
    ('tool-catalog-allowed-attempt-tool-refs
     (agentic-ai-lab-session-policy-validation-receipt-record-tool-catalog-allowed-attempt-tool-refs
      receipt))
    ('tool-catalog-unresolved-attempt-tool-refs
     (agentic-ai-lab-session-policy-validation-receipt-record-tool-catalog-unresolved-attempt-tool-refs
      receipt))
    ('memory-catalog-validation-id
     (agentic-ai-lab-session-policy-validation-receipt-record-memory-catalog-validation-id
      receipt))
    ('memory-catalog-ref
     (agentic-ai-lab-session-policy-validation-receipt-memory-catalog-ref receipt))
    ('memory-catalog-valid?
     (agentic-ai-lab-session-policy-validation-receipt-memory-catalog-valid?
      receipt))
    ('memory-catalog-store-count
     (agentic-ai-lab-session-policy-validation-receipt-record-memory-catalog-store-count
      receipt))
    ('memory-catalog-store-refs
     (agentic-ai-lab-session-policy-validation-receipt-record-memory-catalog-store-refs
      receipt))
    ('memory-catalog-intent-count
     (agentic-ai-lab-session-policy-validation-receipt-record-memory-catalog-intent-count
      receipt))
    ('memory-catalog-intent-store-refs
     (agentic-ai-lab-session-policy-validation-receipt-record-memory-catalog-intent-store-refs
      receipt))
    ('memory-catalog-resolved-store-refs
     (agentic-ai-lab-session-policy-validation-receipt-memory-catalog-resolved-store-refs
      receipt))
    ('memory-catalog-unresolved-store-refs
     (agentic-ai-lab-session-policy-validation-receipt-memory-catalog-unresolved-store-refs
      receipt))
    ('shared-resource-grants
     (agentic-ai-lab-session-policy-validation-receipt-record-shared-resource-grants
      receipt))
    ('diagnostic-count
     (agentic-ai-lab-session-policy-validation-receipt-diagnostic-count receipt))
    ('diagnostics
     (agentic-ai-lab-session-policy-validation-receipt-diagnostics receipt))
    ('runtime-owner
     (agentic-ai-lab-session-policy-validation-receipt-record-runtime-owner
      receipt))
    ('runtime-executed
     (agentic-ai-lab-session-policy-validation-receipt-runtime-executed?
      receipt))
    ('metadata
     (agentic-ai-lab-session-policy-validation-receipt-record-metadata receipt)))))

;; : (-> [PooSessionPolicyValidationReceipt] [Alist])
(def (agentic-ai-lab-session-policy-validation-receipts->alists receipts)
  (agentic-ai-lab-session-receipt-projection-batch
   receipts
   agentic-ai-lab-session-policy-validation-receipt->alist
   "session policy validation projection requires a list"))
