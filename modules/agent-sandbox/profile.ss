;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: agent-sandbox profile descriptor facade.
;;; Boundary: public import target for data, descriptor, validation, and projection owners.

(import :agentic-ai-lab/modules/agent-sandbox/profile-data
        :agentic-ai-lab/modules/agent-sandbox/profile-validation
        :agentic-ai-lab/modules/agent-sandbox/profile-descriptor
        :agentic-ai-lab/modules/agent-sandbox/profile-projection)

(export +agent-sandbox-profile-schema+
        +agent-sandbox-profile-runtime-summary-schema+
        +agent-sandbox-profile-handoff-summary-schema+
        agent-sandbox-profile-descriptor-prototype
        make-agent-sandbox-backend-profile-descriptor
        make-agent-sandbox-profile-descriptor
        agent-sandbox-profile-descriptor?
        agent-sandbox-profile-descriptor-name
        agent-sandbox-profile-descriptor-backend-kind
        agent-sandbox-profile-descriptor-backend-ref
        agent-sandbox-profile-descriptor-network-policy
        agent-sandbox-profile-descriptor-capabilities
        agent-sandbox-profile-descriptor-resource-policy
        agent-sandbox-profile-descriptor-metadata
        agent-sandbox-profile-descriptor-validator
        agent-sandbox-profile-descriptor->profile
        make-agent-sandbox-backend-profile
        agent-sandbox-required-field-errors
        agent-sandbox-profile-validation-errors
        agent-sandbox-profile-resource-policy-filesystem-entry?
        agent-sandbox-profile-resource-policy-structured-filesystem-entry?
        agent-sandbox-profile-resource-policy-has-structured-filesystem?
        agent-sandbox-profile-resource-policy-filesystem-diagnostics
        agent-sandbox-validate-profile
        agent-sandbox-profile-ref
        agent-sandbox-profile-backend-kind
        agent-sandbox-profile-backend-ref
        agent-sandbox-profile-network-policy
        agent-sandbox-profile-capabilities
        agent-sandbox-profile-resource-policy
        agent-sandbox-profile-metadata
        agent-sandbox-profile-runtime-summary
        agent-sandbox-profile-handoff-summary)
