;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public facade for sandbox-core profile POO projection.

(import :agentic-ai-lab/modules/agent-sandbox/profile-native-contract
        :agentic-ai-lab/modules/sandbox-core/profile-support/prototype
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy
        :agentic-ai-lab/modules/sandbox-core/profile-support/authoring
        :agentic-ai-lab/modules/sandbox-core/profile-support/derivation
        :agentic-ai-lab/modules/sandbox-core/profile-support/resolve
        (only-in :agentic-ai-lab/modules/agent-sandbox/config
                 agentic-ai-lab-sandbox-profile?
                 agentic-ai-lab-sandbox-profile-name
                 agentic-ai-lab-sandbox-profile-backend-kind
                 agentic-ai-lab-sandbox-profile-backend-ref
                 agentic-ai-lab-sandbox-profile-network-policy
                 agentic-ai-lab-sandbox-profile-capabilities
                 agentic-ai-lab-sandbox-profile-resource-policy
                 agentic-ai-lab-sandbox-profile-metadata))

(export (import: :agentic-ai-lab/modules/agent-sandbox/profile-native-contract)
        (import: :agentic-ai-lab/modules/sandbox-core/resource-contract)
        (import: :agentic-ai-lab/modules/sandbox-core/profile-support/policy)
        agentic-ai-lab-sandbox-profile?
        agentic-ai-lab-sandbox-profile-name
        agentic-ai-lab-sandbox-profile-backend-kind
        agentic-ai-lab-sandbox-profile-backend-ref
        agentic-ai-lab-sandbox-profile-network-policy
        agentic-ai-lab-sandbox-profile-capabilities
        agentic-ai-lab-sandbox-profile-resource-policy
        agentic-ai-lab-sandbox-profile-metadata
        agentic-ai-lab-sandbox-core-profile-object
        agentic-ai-lab-sandbox-profile-object-row-slot
        agentic-ai-lab-sandbox-profile-object-row-operator?
        agentic-ai-lab-sandbox-profile-object-row-operator
        agentic-ai-lab-sandbox-profile-object-row-value
        agentic-ai-lab-sandbox-profile-object-authoring-diagnostic
        agentic-ai-lab-sandbox-profile-object-row-contains-symbol?
        agentic-ai-lab-sandbox-profile-object-runtime-executed-true?
        agentic-ai-lab-sandbox-profile-object-row-authoring-diagnostics
        agentic-ai-lab-sandbox-profile-object-authoring-diagnostics
        agentic-ai-lab-sandbox-profile-prototype
        agentic-ai-lab-sandbox-profile-prototype->profile
        agentic-ai-lab-sandbox-profile-prototypes
        agentic-ai-lab-sandbox-profile-object-profiles
        agentic-ai-lab-sandbox-profile-object-profiles/build
        agentic-ai-lab-sandbox-profile-object-derive
        agentic-ai-lab-sandbox-profile-object-config)
