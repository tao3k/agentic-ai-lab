;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: agent-sandbox profile data records and accessors.
;;; Invariant: this owner has no descriptor inheritance or validation side effects.

(import :agentic-ai-lab/modules/agent-sandbox/alist
        :agentic-ai-lab/modules/agent-sandbox/projection-syntax)

(export +agent-sandbox-profile-schema+
        +agent-sandbox-profile-runtime-summary-schema+
        +agent-sandbox-profile-handoff-summary-schema+
        make-agent-sandbox-backend-profile
        agent-sandbox-profile-ref
        agent-sandbox-profile-backend-kind
        agent-sandbox-profile-backend-ref
        agent-sandbox-profile-network-policy
        agent-sandbox-profile-capabilities
        agent-sandbox-profile-resource-policy
        agent-sandbox-profile-metadata
        agent-sandbox-profile-list-count)

;; : (-> Unit Symbol)
(def +agent-sandbox-profile-schema+ 'agentic-ai-lab.agent-sandbox-profile.v1)

;; : (-> Unit Symbol)
(def +agent-sandbox-profile-runtime-summary-schema+
  'agentic-ai-lab.agent-sandbox-profile.runtime-summary.v1)

;; : (-> Unit Symbol)
(def +agent-sandbox-profile-handoff-summary-schema+
  'agentic-ai-lab.agent-sandbox-profile.handoff-summary.v1)


;;; Backend profiles package reusable runtime defaults without choosing the
;;; actual adapter implementation. They are bridge hints, not runtime handles.
;; : (-> Symbol BackendRef NetworkPolicy Capabilities ResourcePolicy Metadata AgentSandboxProfile)
(def (make-agent-sandbox-backend-profile backend-kind
                                         backend-ref
                                         network-policy
                                         capabilities
                                         resource-policy
                                         metadata)
  (agent-sandbox-field-rows
   (schema +agent-sandbox-profile-schema+)
   (backend-kind backend-kind)
   (backend-ref backend-ref)
   (network-policy network-policy)
   (capabilities capabilities)
   (resource-policy resource-policy)
   (metadata metadata)))


;;; Profile accessors keep future bridges away from raw list positions.
;; : (-> AgentSandboxProfile Symbol Value Value)
(def (agent-sandbox-profile-ref profile key default)
  (agent-sandbox-alist-ref profile key default))

;; : (-> AgentSandboxProfile (U Symbol #f))
(def (agent-sandbox-profile-backend-kind profile)
  (agent-sandbox-profile-ref profile 'backend-kind #f))

;; : (-> AgentSandboxProfile (U BackendRef #f))
(def (agent-sandbox-profile-backend-ref profile)
  (agent-sandbox-profile-ref profile 'backend-ref #f))

;; : (-> AgentSandboxProfile NetworkPolicy)
(def (agent-sandbox-profile-network-policy profile)
  (agent-sandbox-profile-ref profile 'network-policy '()))

;; : (-> AgentSandboxProfile Capabilities)
(def (agent-sandbox-profile-capabilities profile)
  (agent-sandbox-profile-ref profile 'capabilities '()))

;; : (-> AgentSandboxProfile ResourcePolicy)
(def (agent-sandbox-profile-resource-policy profile)
  (agent-sandbox-profile-ref profile 'resource-policy '()))

;; : (-> AgentSandboxProfile Metadata)
(def (agent-sandbox-profile-metadata profile)
  (agent-sandbox-profile-ref profile 'metadata '()))

;;; Boundary: agent sandbox profile list count is the policy-visible edge for
;;; sandbox behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> MaybeList Integer)
(def (agent-sandbox-profile-list-count value)
  (if (list? value) (length value) 0))

