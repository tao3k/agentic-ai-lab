;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public facade for effective session policy validation receipts.
;;; Implementation lives in policy-validation-* modules so catalog, transport,
;;; and receipt projection checks remain independently auditable.

(import :agentic-ai-lab/modules/session/policy-validation-support
        :agentic-ai-lab/modules/session/policy-validation-receipt)

(export agentic-ai-lab-session-policy-tool-attempt
        agentic-ai-lab-session-policy-tool-attempt?
        agentic-ai-lab-session-policy-tool-attempt-id
        agentic-ai-lab-session-policy-tool-attempt-trigger-ref
        agentic-ai-lab-session-policy-tool-attempt-tool-ref
        agentic-ai-lab-session-policy-tool-attempt-action
        agentic-ai-lab-session-policy-validation-receipt
        agentic-ai-lab-session-policy-validation-receipt?
        agentic-ai-lab-session-policy-validation-receipt-validation-id
        agentic-ai-lab-session-policy-validation-receipt-effective-model-ref
        agentic-ai-lab-session-policy-validation-receipt-effective-prompt-session-ref
        agentic-ai-lab-session-policy-validation-receipt-effective-prompt-chunk-refs
        agentic-ai-lab-session-policy-validation-receipt-effective-isolation-mode
        agentic-ai-lab-session-policy-validation-receipt-effective-sandbox-profile-ref
        agentic-ai-lab-session-policy-validation-receipt-tool-catalog-ref
        agentic-ai-lab-session-policy-validation-receipt-tool-catalog-valid?
        agentic-ai-lab-session-policy-validation-receipt-tool-catalog-policy-tool-refs
        agentic-ai-lab-session-policy-validation-receipt-tool-catalog-resolved-tool-refs
        agentic-ai-lab-session-policy-validation-receipt-tool-catalog-unresolved-tool-refs
        agentic-ai-lab-session-policy-validation-receipt-tool-catalog-allowed-attempt-tool-refs
        agentic-ai-lab-session-policy-validation-receipt-tool-catalog-unresolved-attempt-tool-refs
        agentic-ai-lab-session-policy-validation-receipt-memory-catalog-ref
        agentic-ai-lab-session-policy-validation-receipt-memory-catalog-valid?
        agentic-ai-lab-session-policy-validation-receipt-memory-catalog-resolved-store-refs
        agentic-ai-lab-session-policy-validation-receipt-memory-catalog-unresolved-store-refs
        agentic-ai-lab-session-policy-validation-receipt-allowed-communication-channel-receipts
        agentic-ai-lab-session-policy-validation-receipt-denied-communication-channel-receipts
        agentic-ai-lab-session-policy-validation-receipt-allowed-communication-receipts
        agentic-ai-lab-session-policy-validation-receipt-denied-communication-receipts
        agentic-ai-lab-session-policy-validation-receipt-valid?
        agentic-ai-lab-session-policy-validation-receipt-diagnostic-count
        agentic-ai-lab-session-policy-validation-receipt-diagnostics
        agentic-ai-lab-session-policy-validation-receipt-runtime-executed?
        agentic-ai-lab-session-policy-validation-receipt->alist
        agentic-ai-lab-session-policy-validation-receipts->alists)
