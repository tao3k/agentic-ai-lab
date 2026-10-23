;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: config-session agent-node syntax owns the user-facing macro
;;; surface for child agent graph nodes.
;;; Invariant: macro expansion must preserve session id ancestry without
;;; materializing runtime agents during configuration parsing.
(import :agentic-ai-lab/modules/session/config-session-runtime)

(export session-agent-node
        session-agent-graph
        session-agent-param-contract)

;; session-agent-node
;; : (-> Syntax PooSessionAgentNode)
;; | doc m%
;;   Build one agent node receipt with parent-child session identity,
;;   communication channels, sandbox, memory, durable, and tool policies.
;;   # Examples
;;   ```scheme
;;   (session-agent-node worker (project demo) (root root) ...)
;;   ;; => session agent node object
;;   ```
(defrules session-agent-node
  (project root parent system input output peers channels model prompt tools hook-tools resources durable tool-refs memory sandbox role result metadata)
  ((_ agent-id
      (project project-ref)
      (root root-session-ref)
      (parent parent-session-ref)
      (system agent-system-session-ref)
      (input input-session-ref)
      (output output-session-ref)
      (peers peer-session-ref ...)
      (channels communication-channel ...)
      (model model-policy-ref)
      (prompt prompt-policy-ref)
      (tools tool-permission-policy-ref)
      (hook-tools hook-tool-permission-policy-ref)
      (resources resource-sharing-policy-ref)
      (durable durable-policy-ref)
      (tool-refs tool-ref ...)
      (memory memory-ref ...)
      (sandbox sandbox-profile-ref)
      (role role-value)
      (result result-contract)
      (metadata metadata-entry ...))
   (agentic-ai-lab-session-syntax-agent-node
    'agent-id
    'project-ref
    'root-session-ref
    'parent-session-ref
    'agent-system-session-ref
    'input-session-ref
    'output-session-ref
    '(peer-session-ref ...)
    '(communication-channel ...)
    'model-policy-ref
    'prompt-policy-ref
    'tool-permission-policy-ref
    'hook-tool-permission-policy-ref
    'resource-sharing-policy-ref
    'durable-policy-ref
    '(tool-ref ...)
    '(memory-ref ...)
    'sandbox-profile-ref
    'role-value
    'result-contract
    '(metadata-entry ...)))
  ((_ agent-id
      (project project-ref)
      (root root-session-ref)
      (parent parent-session-ref)
      (system agent-system-session-ref)
      (input input-session-ref)
      (output output-session-ref)
      (peers peer-session-ref ...)
      (channels communication-channel ...)
      (model model-policy-ref)
      (prompt prompt-policy-ref)
      (tools tool-permission-policy-ref)
      (hook-tools hook-tool-permission-policy-ref)
      (resources resource-sharing-policy-ref)
      (durable durable-policy-ref)
      (tool-refs tool-ref ...)
      (memory memory-ref ...)
      (sandbox sandbox-profile-ref)
      (role role-value)
      (result result-contract))
   (agentic-ai-lab-session-syntax-agent-node
    'agent-id
    'project-ref
    'root-session-ref
    'parent-session-ref
    'agent-system-session-ref
    'input-session-ref
    'output-session-ref
    '(peer-session-ref ...)
    '(communication-channel ...)
    'model-policy-ref
    'prompt-policy-ref
    'tool-permission-policy-ref
    'hook-tool-permission-policy-ref
    'resource-sharing-policy-ref
    'durable-policy-ref
    '(tool-ref ...)
    '(memory-ref ...)
    'sandbox-profile-ref
    'role-value
    'result-contract)))

;; session-agent-graph
;; : (-> Syntax PooSessionAgentGraph)
;; | doc m%
;;   Build the project-level multi-agent graph receipt that preserves root,
;;   node, registry, communication, and metadata relationships.
;;   # Examples
;;   ```scheme
;;   (session-agent-graph project root nodes sessions registry communications)
;;   ;; => session agent graph object
;;   ```
(defrules session-agent-graph ()
  ((_ project-id
      root-session-ref
      agent-nodes
      session-values
      registry-receipt
      communication-receipts
      metadata)
   (agentic-ai-lab-session-syntax-agent-graph
    'project-id
    'root-session-ref
    agent-nodes
    session-values
    registry-receipt
    communication-receipts
    metadata))
  ((_ project-id
      root-session-ref
      agent-nodes
      session-values
      registry-receipt
      communication-receipts)
   (agentic-ai-lab-session-syntax-agent-graph
    'project-id
    'root-session-ref
    agent-nodes
    session-values
    registry-receipt
    communication-receipts)))

;; session-agent-param-contract
;; : (-> Syntax PooSessionAgentParamContract)
;; | doc m%
;;   Build the parameter contract that binds an agent node to validation,
;;   provider, streaming, event, and metadata policies.
;;   # Examples
;;   ```scheme
;;   (session-agent-param-contract worker node validation provider stream events)
;;   ;; => session agent parameter contract object
;;   ```
(defrules session-agent-param-contract ()
  ((_ contract-id
      agent-node
      validation-receipt
      provider-ref
      streaming-policy
      event-policy
      metadata)
   (agentic-ai-lab-session-syntax-agent-param-contract
    'contract-id
    agent-node
    validation-receipt
    'provider-ref
    'streaming-policy
    'event-policy
    metadata))
  ((_ contract-id
      agent-node
      validation-receipt
      provider-ref
      streaming-policy
      event-policy)
   (agentic-ai-lab-session-syntax-agent-param-contract
    'contract-id
    agent-node
    validation-receipt
    'provider-ref
    'streaming-policy
    'event-policy)))

;; : (-> PooSessionAgentParamContract Alist)
