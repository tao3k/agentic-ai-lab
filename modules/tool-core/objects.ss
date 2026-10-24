;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: stable facade for POO-native tool specs, catalogs, and receipts.

(import :agentic-ai-lab/modules/tool-core/objects-spec
        :agentic-ai-lab/modules/tool-core/objects-catalog
        :agentic-ai-lab/modules/tool-core/objects-handoff
        :agentic-ai-lab/modules/tool-core/objects-receipt
        :agentic-ai-lab/modules/tool-core/objects-builtin)

(export +agentic-ai-lab-tool-core-spec-kind+
        +agentic-ai-lab-tool-core-catalog-kind+
        +agentic-ai-lab-tool-core-handoff-manifest-kind+
        +agentic-ai-lab-tool-core-policy-validation-receipt-kind+
        agentic-ai-lab-tool-spec
        agentic-ai-lab-tool-spec?
        agentic-ai-lab-tool-spec-ref
        agentic-ai-lab-tool-spec-tool-kind
        agentic-ai-lab-tool-spec-actions
        agentic-ai-lab-tool-spec-sandbox-required?
        agentic-ai-lab-tool-spec-sandbox-profile-ref
        agentic-ai-lab-tool-spec->alist
        agentic-ai-lab-tool-handoff-manifest
        agentic-ai-lab-tool-handoff-manifest?
        agentic-ai-lab-tool-handoff-manifest->alist
        agentic-ai-lab-tool-catalog
        agentic-ai-lab-tool-catalog?
        agentic-ai-lab-tool-catalog-ref
        agentic-ai-lab-tool-catalog-tool-refs
        agentic-ai-lab-tool-catalog-tool-count
        agentic-ai-lab-tool-catalog-find
        agentic-ai-lab-tool-catalog->alist
        agentic-ai-lab-tool-policy-catalog-validation-receipt
        agentic-ai-lab-tool-policy-catalog-validation-receipt?
        agentic-ai-lab-tool-policy-catalog-validation-receipt-valid?
        agentic-ai-lab-tool-policy-catalog-validation-receipt-diagnostics
        agentic-ai-lab-tool-policy-catalog-validation-receipt->alist
        agentic-ai-lab-tool-core-builtin-read-workspace-file
        agentic-ai-lab-tool-core-builtin-write-workspace-file
        agentic-ai-lab-tool-core-builtin-run-shell-command
        agentic-ai-lab-tool-core-mcp-tool
        agentic-ai-lab-tool-core-default-catalog)
