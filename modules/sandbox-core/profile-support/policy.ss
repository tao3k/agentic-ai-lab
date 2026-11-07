;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Sandbox profile policy facade.
;;; Keep the public policy API here so downstream modules keep one stable import
;;; path; backend capability construction, backend diagnostics, profile policy
;;; construction, and profile validation are split into owner leaves so policy
;;; repairs stay local to the semantic family that owns the behavior.

(import :agentic-ai-lab/modules/sandbox-core/profile-support/policy-core
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy-backend-capability
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy-backend-validation
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy-profile-core
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy-profile-validation)

(export agentic-ai-lab-sandbox-backend-capability-kind
        agentic-ai-lab-sandbox-backend-capability-registry-kind
        agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-kind
        agentic-ai-lab-sandbox-backend-capability-registry-validation-kind
        agentic-ai-lab-sandbox-profile-policy-kind
        agentic-ai-lab-sandbox-profile-policy-diagnostic-kind
        agentic-ai-lab-sandbox-profile-policy-validation-kind
        agentic-ai-lab-sandbox-profile-policy-projection-kind
        agentic-ai-lab-sandbox-backend-capability
        agentic-ai-lab-sandbox-backend-capability?
        agentic-ai-lab-sandbox-backend-capability/backend-kind
        agentic-ai-lab-sandbox-backend-capability/capabilities
        agentic-ai-lab-sandbox-backend-capability-supports?
        agentic-ai-lab-sandbox-backend-capability-registry
        agentic-ai-lab-sandbox-backend-capability-registry?
        agentic-ai-lab-sandbox-backend-capability-registry-entries
        agentic-ai-lab-sandbox-backend-capability-registry-aliases
        agentic-ai-lab-sandbox-backend-capability-registry-default
        agentic-ai-lab-sandbox-backend-capability-registry-extend
        agentic-ai-lab-sandbox-backend-capability-registry-merge
        agentic-ai-lab-sandbox-backend-capability-registry-diagnostic
        agentic-ai-lab-sandbox-backend-capability-registry-diagnostic?
        agentic-ai-lab-sandbox-backend-capability-registry-validation
        agentic-ai-lab-sandbox-backend-capability-registries-validation
        agentic-ai-lab-sandbox-backend-capability-registry-validation?
        agentic-ai-lab-sandbox-backend-capability-registry-validation-valid?
        agentic-ai-lab-sandbox-backend-capability-registry-validation-diagnostics
        agentic-ai-lab-sandbox-backend-capability-registry-validation-diagnostic-count
        agentic-ai-lab-sandbox-backend-capability-registry-ref
        agentic-ai-lab-sandbox-backend-capability/sandbox
        agentic-ai-lab-sandbox-backend-capability/nono
        agentic-ai-lab-sandbox-backend-capability/cube
        agentic-ai-lab-sandbox-backend-capability/docker
        agentic-ai-lab-sandbox-backend-capability-registry/sandbox-core
        agentic-ai-lab-sandbox-backend-capability-registry/default
        agentic-ai-lab-sandbox-backend-capability-ref
        agentic-ai-lab-sandbox-profile-policy
        agentic-ai-lab-sandbox-profile-policy?
        agentic-ai-lab-sandbox-profile-policy-required-capabilities
        agentic-ai-lab-sandbox-profile-policy-resource-policy
        agentic-ai-lab-sandbox-profile-policy-durable-policy
        agentic-ai-lab-sandbox-profile-policy-durable-policy-ref
        agentic-ai-lab-sandbox-profile-policy-sandbox-handle-class
        agentic-ai-lab-sandbox-profile-policy/default
        agentic-ai-lab-sandbox-profile-policy-diagnostic
        agentic-ai-lab-sandbox-profile-policy-diagnostic?
        agentic-ai-lab-sandbox-profile-policy-diagnostics
        agentic-ai-lab-sandbox-profile-policy-validation
        agentic-ai-lab-sandbox-profile-policy-validation-valid?
        agentic-ai-lab-sandbox-profile-policy-validation-diagnostics
        agentic-ai-lab-sandbox-profile-policy-validation-diagnostic-count
        agentic-ai-lab-sandbox-profile-policy-projection-validation
        agentic-ai-lab-sandbox-profile-policy-projection-valid?
        agentic-ai-lab-sandbox-profile-policy-projection-diagnostics
        agentic-ai-lab-sandbox-profile-policy-projection)
