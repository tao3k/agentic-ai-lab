;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public Loop Runtime orchestration owner.
;;; Focused owners hold the only implementations; this file only assembles the
;;; stable runtime surface used by config and downstream consumers.
(import "proof-abi.ss"
        "runtime-base.ss"
        "runtime-capability.ss"
        "runtime-agent.ss"
        "runtime-intent.ss"
        "runtime-projection.ss"
        "result-contract.ss")

(export make-loop-engine-capability-receipt
        loop-engine-capability-receipt?
        loop-engine-capability-receipt-backend
        loop-engine-capability-receipt-backend-kind
        loop-engine-capability-receipt-backend-capabilities
        loop-engine-capability-receipt-supported-backends
        loop-engine-capability-receipt-valid?
        loop-engine-capability-receipt-diagnostics
        loop-engine-capability-receipt-isolation
        loop-engine-capability-receipt-required
        loop-engine-capability-receipt-optional
        loop-engine-capability-receipt-unsupported-behavior
        loop-engine-capability-receipt-sandbox-ref
        loop-engine-capability-receipt-session-ref
        loop-engine-capability-receipt->alist
        agentic-ai-lab-user-loop-engine-primary-agent
        agentic-ai-lab-user-loop-engine-intent-status
        agentic-ai-lab-user-loop-engine-intent-operation-kind
        agentic-ai-lab-user-loop-engine-intent-result-contract
        agentic-ai-lab-user-loop-engine-result-contract-valid?
        agentic-ai-lab-user-loop-engine-result-contract-diagnostics
        agentic-ai-lab-user-loop-engine-intent-role-result-contract
        agentic-ai-lab-user-loop-engine-intent-operation-result-contract
        agentic-ai-lab-user-loop-engine-intent-agent-profiles
        agentic-ai-lab-user-loop-engine-intent-agent-harnesses
        agentic-ai-lab-user-loop-engine-intent-agent-sessions
        agentic-ai-lab-user-loop-engine-intent-session-agent-graph
        agentic-ai-lab-user-loop-engine-intent-session-agent-topology-trace
        agentic-ai-lab-user-loop-engine-intent-agent-operation
        agentic-ai-lab-user-loop-engine-intent-delegated-operation
        agentic-ai-lab-user-loop-engine-intent-dispatch-receipt
        agentic-ai-lab-user-loop-engine-intent-runtime-command-manifest
        agentic-ai-lab-user-loop-engine-intent-runtime-command-manifest-summary
        agentic-ai-lab-user-loop-engine-intent-proof-manifest
        +agentic-ai-lab-loop-engine-proof-abi-version+
        +agentic-ai-lab-loop-engine-proof-obligation-tags+
        +agentic-ai-lab-loop-engine-proof-obligations+
        +agentic-ai-lab-loop-engine-proof-obligation-count+
        +agentic-ai-lab-loop-engine-proof-required-obligation-mask+
        +agentic-ai-lab-loop-engine-proof-abi-tag-width+
        agentic-ai-lab-loop-engine-proof-obligation
        agentic-ai-lab-loop-engine-proof-obligation-mask
        agentic-ai-lab-loop-engine-proof-c-abi
        agentic-ai-lab-loop-engine-proof-manifest
        agentic-ai-lab-user-loop-engine-intent-runtime-capability-descriptor
        agentic-ai-lab-user-loop-engine-intent-policy-profile-packet
        agentic-ai-lab-user-loop-engine-intent-runtime-action-packet
        agentic-ai-lab-user-loop-engine-intent-runtime-receipt-batch-template
        agentic-ai-lab-user-loop-engine-intent-workflow-agreement
        agentic-ai-lab-user-loop-engine-intent-runtime-envelope
        agentic-ai-lab-user-loop-engine-intent-runtime-handoff-facts
        agentic-ai-lab-user-loop-engine-intent-sandbox-handoff-agreement
        agentic-ai-lab-user-loop-engine-intent-runtime-snapshot
        agentic-ai-lab-user-loop-engine-capability-receipt-ref
        agentic-ai-lab-user-loop-engine-capability-receipt->alist
        agentic-ai-lab-user-loop-engine-intent-workflow-run
        agentic-ai-lab-user-loop-engine-intent-runtime-intent
        agentic-ai-lab-user-loop-engine-intent-policy)
