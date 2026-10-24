;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: runtime and handoff summaries for validated sandbox profiles.
;;; Invariant: summaries are inert Scheme receipts for Marlin-owned execution.

(import :agentic-ai-lab/modules/agent-sandbox/alist
        :agentic-ai-lab/modules/agent-sandbox/projection-syntax
        :agentic-ai-lab/modules/agent-sandbox/profile-data
        :agentic-ai-lab/modules/agent-sandbox/profile-validation)

(export agent-sandbox-profile-runtime-summary
        agent-sandbox-profile-handoff-summary)

;;; Filesystem summary is the sandbox-owned projection that presentation,
;;; workflow, and runtime-handoff code should consume instead of reparsing the
;;; resource-policy row shape outside this module.
;; : (-> ResourcePolicy Alist)
(def (agent-sandbox-profile-filesystem-runtime-summary resource-policy)
  (let* ((entry
          (agent-sandbox-profile-resource-policy-filesystem-entry
           resource-policy))
         (spec (if (and entry (pair? entry)) (cdr entry) '()))
         (paths (agent-sandbox-alist-ref spec 'paths '()))
         (mounts (agent-sandbox-alist-ref spec 'mounts '()))
          (diagnostics
          (agent-sandbox-profile-resource-policy-filesystem-diagnostics
           resource-policy)))
    (agent-sandbox-field-rows
     (declared? (and entry #t))
     (structured?
      (agent-sandbox-profile-resource-policy-structured-filesystem-entry?
       entry))
     (scope (agent-sandbox-alist-ref spec 'scope #f))
     (access (agent-sandbox-alist-ref spec 'access #f))
     (paths paths)
     (path-count (agent-sandbox-profile-list-count paths))
     (mounts mounts)
     (mount-count (agent-sandbox-profile-list-count mounts))
     (entry entry)
     (diagnostics diagnostics))))

;;; Runtime summaries are still inert Scheme data. They name the exact sandbox
;;; policy that a Rust/Marlin bridge can consume later, while keeping execution
;;; state and validation evidence visible to agents.
;; : (-> AgentSandboxProfile Alist)
(def (agent-sandbox-profile-runtime-summary profile)
  (let* ((network-policy (agent-sandbox-profile-network-policy profile))
         (capabilities (agent-sandbox-profile-capabilities profile))
         (resource-policy (agent-sandbox-profile-resource-policy profile))
         (metadata (agent-sandbox-profile-metadata profile))
         (validation-errors
          (agent-sandbox-profile-validation-errors profile)))
    (agent-sandbox-field-rows
     (schema +agent-sandbox-profile-runtime-summary-schema+)
     (kind 'agent-sandbox-profile-runtime-summary)
     (profile-ref (agent-sandbox-profile-backend-ref profile))
     (backend-kind (agent-sandbox-profile-backend-kind profile))
     (backend-ref (agent-sandbox-profile-backend-ref profile))
     (network-policy network-policy)
     (capabilities capabilities)
     (capability-count
      (agent-sandbox-profile-list-count capabilities))
     (resource-policy resource-policy)
     (resource-policy-count
      (agent-sandbox-profile-list-count resource-policy))
     (filesystem
      (agent-sandbox-profile-filesystem-runtime-summary
       resource-policy))
     (metadata metadata)
     (valid? (null? validation-errors))
     (validation-errors validation-errors)
     (runtime-owner "marlin-agent-core")
     (package-management? #f)
     (dependency-installation? #f)
     (runtime-executed #f))))

;;; Handoff summaries validate first, then package the normalized profile and
;;; summary. This is the bridge-facing receipt shape for workflow/loop engines.
;; : (-> AgentSandboxProfile Alist)
(def (agent-sandbox-profile-handoff-summary profile)
  (let (validated-profile (agent-sandbox-validate-profile profile))
    (agent-sandbox-field-rows
     (schema +agent-sandbox-profile-handoff-summary-schema+)
     (kind 'agent-sandbox-profile-handoff-summary)
     (profile-ref
      (agent-sandbox-profile-backend-ref validated-profile))
     (backend-kind
      (agent-sandbox-profile-backend-kind validated-profile))
     (backend-ref
      (agent-sandbox-profile-backend-ref validated-profile))
     (handoff-target "marlin-agent-core")
     (handoff-contract
      'agentic-ai-lab.agent-sandbox-profile.runtime-handoff.v1)
     (profile validated-profile)
     (runtime-summary
      (agent-sandbox-profile-runtime-summary validated-profile))
     (runtime-executed #f))))
