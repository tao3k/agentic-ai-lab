;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: stable facade for memory-core POO objects.

(import :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects-core
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects-handoff
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects-catalog
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects-validation
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects-durable
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects-builtin)

(export +agentic-ai-lab-ai-agentic-context-memory-store-spec-kind+
        +agentic-ai-lab-ai-agentic-context-memory-catalog-kind+
        +agentic-ai-lab-ai-agentic-context-memory-handoff-manifest-kind+
        +agentic-ai-lab-ai-agentic-context-memory-policy-validation-receipt-kind+
        +agentic-ai-lab-ai-agentic-context-memory-durable-job-receipt-kind+
        +agentic-ai-lab-memory-durable-job-kinds+
        +agentic-ai-lab-memory-durable-job-states+
        agentic-ai-lab-memory-store-spec
        agentic-ai-lab-memory-store-spec?
        agentic-ai-lab-memory-store-spec-ref
        agentic-ai-lab-memory-store-spec-scopes
        agentic-ai-lab-memory-store-spec-commit-policies
        agentic-ai-lab-memory-store-spec-recall-policies
        agentic-ai-lab-memory-store-spec->alist
        agentic-ai-lab-memory-handoff-manifest
        agentic-ai-lab-memory-handoff-manifest?
        agentic-ai-lab-memory-handoff-manifest->alist
        agentic-ai-lab-memory-catalog
        agentic-ai-lab-memory-catalog?
        agentic-ai-lab-memory-catalog-ref
        agentic-ai-lab-memory-catalog-store-refs
        agentic-ai-lab-memory-catalog-store-count
        agentic-ai-lab-memory-catalog-find
        agentic-ai-lab-memory-catalog->alist
        agentic-ai-lab-memory-policy-catalog-validation-receipt
        agentic-ai-lab-memory-policy-catalog-validation-receipt?
        agentic-ai-lab-memory-policy-catalog-validation-receipt-valid?
        agentic-ai-lab-memory-policy-catalog-validation-receipt-diagnostics
        agentic-ai-lab-memory-policy-catalog-validation-receipt->alist
        make-agentic-ai-lab-memory-durable-job-receipt
        agentic-ai-lab-memory-durable-job-receipt?
        agentic-ai-lab-memory-durable-job-receipt-job-id
        agentic-ai-lab-memory-durable-job-receipt-job-kind
        agentic-ai-lab-memory-durable-job-receipt-job-state
        agentic-ai-lab-memory-durable-job-receipt-project-id
        agentic-ai-lab-memory-durable-job-receipt-root-session-id
        agentic-ai-lab-memory-durable-job-receipt-session-id
        agentic-ai-lab-memory-durable-job-receipt-agent-id
        agentic-ai-lab-memory-durable-job-receipt-store-ref
        agentic-ai-lab-memory-durable-job-receipt-durable-policy-ref
        agentic-ai-lab-memory-durable-job-receipt-job-store-ref
        agentic-ai-lab-memory-durable-job-receipt-checkpoint-store-ref
        agentic-ai-lab-memory-durable-job-receipt-source-ref
        agentic-ai-lab-memory-durable-job-receipt-source-watermark
        agentic-ai-lab-memory-durable-job-receipt-target-watermark
        agentic-ai-lab-memory-durable-job-receipt-stale-source?
        agentic-ai-lab-memory-durable-job-receipt-retry-policy
        agentic-ai-lab-memory-durable-job-receipt-retention-policy
        agentic-ai-lab-memory-durable-job-receipt-usage-counter
        agentic-ai-lab-memory-durable-job-receipt-scope
        agentic-ai-lab-memory-durable-job-receipt-recall
        agentic-ai-lab-memory-durable-job-receipt-commit-policy
        agentic-ai-lab-memory-durable-job-receipt-valid?
        agentic-ai-lab-memory-durable-job-receipt-diagnostics
        agentic-ai-lab-memory-durable-job-receipt-metadata
        agentic-ai-lab-memory-durable-job-receipt-from-intent
        agentic-ai-lab-memory-durable-job-receipt->alist
        agentic-ai-lab-memory-durable-job-receipts->alists
        agentic-ai-lab-memory-recall-job-receipt
        agentic-ai-lab-memory-write-job-receipt
        agentic-ai-lab-memory-consolidation-job-receipt
        agentic-ai-lab-memory-stale-source-job-receipt
        agentic-ai-lab-memory-repair-job-receipt
        agentic-ai-lab-ai-agentic-context-memory-local-session-store
        agentic-ai-lab-ai-agentic-context-memory-durable-project-store
        agentic-ai-lab-ai-agentic-context-memory-default-catalog)
