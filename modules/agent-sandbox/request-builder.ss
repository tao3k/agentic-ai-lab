;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: agent-sandbox request builders live here.
;;; Boundary:
;;; - Field and profile validation happen before normalized request assembly.
;;; - Final request validation remains delegated to request-validation.
;;; Runtime contract:
;;; - Builders return inert request alists for adapter handoff.
;;; Policy evidence:
;;; - The named-field macro and profiled flow both call these constructors.

(import :agentic-ai-lab/modules/agent-sandbox/alist
        :agentic-ai-lab/modules/agent-sandbox/projection-syntax
        :agentic-ai-lab/modules/agent-sandbox/profile
        :agentic-ai-lab/modules/agent-sandbox/request-field
        :agentic-ai-lab/modules/agent-sandbox/request-validation)

(export make-agent-sandbox-request-with
        make-agent-sandbox-request-from-fields)

;;; Normalized assembly is concrete: one validated profile plus one validated
;;; field alist becomes the bridge-stable request shape consumed by adapters.
;; : (-> AgentSandboxProfile AgentSandboxRequestFields AgentSandboxRequest)
(def (agent-sandbox-normalized-request profile fields)
  (let* ((valid-profile (agent-sandbox-validate-profile profile))
         (request-fields (agent-sandbox-validate-request-fields fields)))
    (agent-sandbox-validate-request
     (agent-sandbox-field-rows
      (schema +agent-sandbox-request-schema+)
      (backend-kind
       (agent-sandbox-profile-backend-kind valid-profile))
      (backend-ref
       (agent-sandbox-profile-backend-ref valid-profile))
      (command (agent-sandbox-option request-fields 'command #f))
      (args (agent-sandbox-option request-fields 'args '()))
      (env (agent-sandbox-option request-fields 'env '()))
      (workdir (agent-sandbox-option request-fields 'workdir #f))
      (mounts (agent-sandbox-option request-fields 'mounts '()))
      (network-policy
       (agent-sandbox-override
        (agent-sandbox-option request-fields 'network-policy #f)
        (agent-sandbox-profile-network-policy valid-profile)))
      (capabilities
       (agent-sandbox-merge-alists
        (agent-sandbox-option request-fields 'capabilities #f)
        (agent-sandbox-profile-capabilities valid-profile)))
      (resource-policy
       (agent-sandbox-merge-alists
        (agent-sandbox-option request-fields 'resource-policy #f)
        (agent-sandbox-profile-resource-policy valid-profile)))
      (output-policy
       (agent-sandbox-option request-fields 'output-policy #f))
      (metadata
       (agent-sandbox-merge-alists
        (agent-sandbox-option request-fields 'metadata '())
        (agent-sandbox-profile-metadata valid-profile)))))))

;;; Macro entry point: generated code supplies a thunk that materializes field
;;; data once, while the builder owns validation and request assembly.
;; | AgentSandboxRequestFieldsThunk = (-> Unit AgentSandboxRequestFields)
;; : (-> AgentSandboxProfile AgentSandboxRequestFieldsThunk AgentSandboxRequest)
;; make-agent-sandbox-request-with
;;   : (-> AgentSandboxProfile AgentSandboxRequestFieldsThunk AgentSandboxRequest)
;;   | contract: thunk is evaluated once and must return request field data
;;   | doc m%
;;   | # Examples
;;   | ```scheme
;;   | (make-agent-sandbox-request-with profile
;;   |   (lambda () '((command . "true"))))
;;   | ```
;;   | result: validated inert request alist for adapter handoff.
(def (make-agent-sandbox-request-with profile fields-thunk)
  (agent-sandbox-normalized-request profile (fields-thunk)))

;;; Named-field construction is the preferred typed contract for callers.
;;; Missing optional fields receive deterministic defaults during assembly.
;; : (-> AgentSandboxProfile AgentSandboxRequestFields AgentSandboxRequest)
(def (make-agent-sandbox-request-from-fields profile fields)
  (agent-sandbox-normalized-request profile fields))
