;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO-native AgentParam contract objects.
;;; Invariant: AgentParam contracts bind agent topology to effective policy
;;; validation; they never run providers, tools, memory stores, or streams.

(import (only-in :clan/poo/object .ref object? object<-alist)
        :agentic-ai-lab/modules/session/agent
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/policy-validation
        :agentic-ai-lab/modules/session/receipt-syntax
        :agentic-ai-lab/modules/session/receipt-projection)

(export agentic-ai-lab-session-agent-param-contract
        agentic-ai-lab-session-agent-param-contract?
        agentic-ai-lab-session-agent-param-contract-id
        agentic-ai-lab-session-agent-param-contract-agent-id
        agentic-ai-lab-session-agent-param-contract-provider-ref
        agentic-ai-lab-session-agent-param-contract-effective-model-ref
        agentic-ai-lab-session-agent-param-contract-validation-valid?
        agentic-ai-lab-session-agent-param-contract->alist
        agentic-ai-lab-session-agent-param-contracts->alists)

;; : (-> POOObject Symbol Value Value)
(def (agentic-ai-lab-session-agent-param-slot object key default)
  (with-catch
   (lambda (_failure) default)
   (lambda ()
     (.ref object key))))

;;; Boundary: agent-param field rows preserve the session parameter projection
;;; shape used by agent graph and policy receipts.
;; agentic-ai-lab-session-agent-param-field-rows
;; : (-> SessionAgentParamFieldRowsClauseSyntax SessionAgentParamFieldRowsExpansionSyntax)
;; | doc m%
;;   Expands agent parameter field clauses into stable session param rows.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-session-agent-param-field-rows (agent-id 'worker))
;;   ;; => ((agent-id . worker))
;;   ```
(defrules agentic-ai-lab-session-agent-param-field-rows ()
  ((_ (field value) ...)
   (list (cons 'field value) ...)))

;;; Boundary: agent parameter contracts bind session agent nodes to validated
;;; policy receipts before child-session runtime launch.
;; : (-> Symbol PooSessionAgentNode PooSessionPolicyValidationReceipt Symbol Symbol Symbol [Alist] PooSessionAgentParamContract)
(def (agentic-ai-lab-session-agent-param-contract contract-id
                                            agent-node
                                            validation-receipt
                                            provider-ref
                                            streaming-policy
                                            event-policy
                                            . maybe-metadata)
  (agentic-ai-lab-session-require "session AgentParam contract id must be a symbol"
                            (symbol? contract-id)
                            contract-id)
  (agentic-ai-lab-session-require "session AgentParam requires an agent node"
                            (agentic-ai-lab-session-agent-node? agent-node)
                            agent-node)
  (agentic-ai-lab-session-require
   "session AgentParam requires a policy validation receipt"
   (agentic-ai-lab-session-policy-validation-receipt? validation-receipt)
   validation-receipt)
  (agentic-ai-lab-session-require "session AgentParam provider ref must be a symbol"
                            (symbol? provider-ref)
                            provider-ref)
  (agentic-ai-lab-session-require "session AgentParam streaming policy must be a symbol"
                            (symbol? streaming-policy)
                            streaming-policy)
  (agentic-ai-lab-session-require "session AgentParam event policy must be a symbol"
                            (symbol? event-policy)
                            event-policy)
  (object<-alist
   (agentic-ai-lab-session-agent-param-field-rows
    (kind 'agentic-ai-lab.session.agent-param-contract)
    (schema 'agentic-ai-lab.modules.session.agent-param-contract.v1)
    (contract-id contract-id)
    (project-ref (.ref agent-node 'project-ref))
    (agent-id
     (agentic-ai-lab-session-agent-node-agent-id agent-node))
    (root-session-ref (.ref agent-node 'root-session-ref))
    (parent-session-ref
     (agentic-ai-lab-session-agent-node-parent-session-ref agent-node))
    (agent-system-session-ref
     (.ref agent-node 'agent-system-session-ref))
    (input-session-ref (.ref agent-node 'input-session-ref))
    (output-session-ref
     (agentic-ai-lab-session-agent-node-output-session-ref agent-node))
    (provider-ref provider-ref)
    (effective-model-ref
     (agentic-ai-lab-session-policy-validation-receipt-effective-model-ref
      validation-receipt))
    (effective-prompt-session-ref
     (agentic-ai-lab-session-policy-validation-receipt-effective-prompt-session-ref
      validation-receipt))
    (effective-prompt-chunk-refs
     (agentic-ai-lab-session-policy-validation-receipt-effective-prompt-chunk-refs
      validation-receipt))
    (effective-isolation-mode
     (agentic-ai-lab-session-policy-validation-receipt-effective-isolation-mode
      validation-receipt))
    (effective-sandbox-profile-ref
     (agentic-ai-lab-session-policy-validation-receipt-effective-sandbox-profile-ref
      validation-receipt))
    (model-policy-ref (.ref agent-node 'model-policy-ref))
    (prompt-policy-ref (.ref agent-node 'prompt-policy-ref))
    (tool-permission-policy-ref
     (.ref agent-node 'tool-permission-policy-ref))
    (hook-tool-permission-policy-ref
     (.ref agent-node 'hook-tool-permission-policy-ref))
    (resource-sharing-policy-ref
     (.ref agent-node 'resource-sharing-policy-ref))
    (durable-policy-ref
     (agentic-ai-lab-session-agent-node-durable-policy-ref agent-node))
    (tool-refs (.ref agent-node 'tool-refs))
    (memory-refs (.ref agent-node 'memory-refs))
    (sandbox-profile-ref (.ref agent-node 'sandbox-profile-ref))
    (streaming-policy streaming-policy)
    (event-policy event-policy)
    (validation-id
     (agentic-ai-lab-session-policy-validation-receipt-validation-id
      validation-receipt))
    (validation-valid?
     (agentic-ai-lab-session-policy-validation-receipt-valid?
      validation-receipt))
    (validation-diagnostic-count
     (agentic-ai-lab-session-policy-validation-receipt-diagnostic-count
      validation-receipt))
    (tool-catalog-ref
     (agentic-ai-lab-session-policy-validation-receipt-tool-catalog-ref
      validation-receipt))
    (tool-catalog-valid?
     (agentic-ai-lab-session-policy-validation-receipt-tool-catalog-valid?
      validation-receipt))
    (tool-catalog-policy-tool-refs
     (agentic-ai-lab-session-policy-validation-receipt-tool-catalog-policy-tool-refs
      validation-receipt))
    (tool-catalog-resolved-tool-refs
     (agentic-ai-lab-session-policy-validation-receipt-tool-catalog-resolved-tool-refs
      validation-receipt))
    (tool-catalog-unresolved-tool-refs
     (agentic-ai-lab-session-policy-validation-receipt-tool-catalog-unresolved-tool-refs
      validation-receipt))
    (tool-catalog-allowed-attempt-tool-refs
     (agentic-ai-lab-session-policy-validation-receipt-tool-catalog-allowed-attempt-tool-refs
      validation-receipt))
    (tool-catalog-unresolved-attempt-tool-refs
     (agentic-ai-lab-session-policy-validation-receipt-tool-catalog-unresolved-attempt-tool-refs
      validation-receipt))
    (memory-catalog-ref
     (agentic-ai-lab-session-policy-validation-receipt-memory-catalog-ref
      validation-receipt))
    (memory-catalog-valid?
     (agentic-ai-lab-session-policy-validation-receipt-memory-catalog-valid?
      validation-receipt))
    (memory-catalog-resolved-store-refs
     (agentic-ai-lab-session-policy-validation-receipt-memory-catalog-resolved-store-refs
      validation-receipt))
    (memory-catalog-unresolved-store-refs
     (agentic-ai-lab-session-policy-validation-receipt-memory-catalog-unresolved-store-refs
      validation-receipt))
    (allowed-communication-receipts
     (agentic-ai-lab-session-policy-validation-receipt-allowed-communication-receipts
      validation-receipt))
    (denied-communication-receipts
     (agentic-ai-lab-session-policy-validation-receipt-denied-communication-receipts
      validation-receipt))
    (runtime-owner "marlin-agent-core")
    (runtime-executed #f)
    (metadata (if (null? maybe-metadata)
                '()
                (car maybe-metadata))))))

;; : (-> POOObject Boolean)
(def (agentic-ai-lab-session-agent-param-contract? value)
  (and (object? value)
       (eq? (agentic-ai-lab-session-agent-param-slot value 'kind #f)
            'agentic-ai-lab.session.agent-param-contract)))

;; : (-> PooSessionAgentParamContract Symbol)
(def (agentic-ai-lab-session-agent-param-contract-id contract)
  (.ref contract 'contract-id))

;; : (-> PooSessionAgentParamContract Symbol)
(def (agentic-ai-lab-session-agent-param-contract-agent-id contract)
  (.ref contract 'agent-id))

;; : (-> PooSessionAgentParamContract Symbol)
(def (agentic-ai-lab-session-agent-param-contract-provider-ref contract)
  (.ref contract 'provider-ref))

;; : (-> PooSessionAgentParamContract Symbol)
(def (agentic-ai-lab-session-agent-param-contract-effective-model-ref contract)
  (.ref contract 'effective-model-ref))

;; : (-> PooSessionAgentParamContract Boolean)
(def (agentic-ai-lab-session-agent-param-contract-validation-valid? contract)
  (.ref contract 'validation-valid?))

;; : (-> PooSessionAgentParamContract Alist)
(defpoo-session-receipt-projection
  agentic-ai-lab-session-agent-param-contract->alist
  (contract)
  (require agentic-ai-lab-session-require
           "session AgentParam projection requires an AgentParam contract"
           (agentic-ai-lab-session-agent-param-contract? contract)
           contract)
  (bindings ())
  (fields
   (('kind (.ref contract 'kind))
    ('schema (.ref contract 'schema))
    ('contract-id (.ref contract 'contract-id))
    ('project-ref (.ref contract 'project-ref))
    ('agent-id (.ref contract 'agent-id))
    ('root-session-ref (.ref contract 'root-session-ref))
    ('parent-session-ref (.ref contract 'parent-session-ref))
    ('agent-system-session-ref (.ref contract 'agent-system-session-ref))
    ('input-session-ref (.ref contract 'input-session-ref))
    ('output-session-ref (.ref contract 'output-session-ref))
    ('provider-ref (.ref contract 'provider-ref))
    ('effective-model-ref (.ref contract 'effective-model-ref))
    ('effective-prompt-session-ref
     (.ref contract 'effective-prompt-session-ref))
    ('effective-prompt-chunk-refs
     (.ref contract 'effective-prompt-chunk-refs))
    ('effective-isolation-mode (.ref contract 'effective-isolation-mode))
    ('effective-sandbox-profile-ref
     (.ref contract 'effective-sandbox-profile-ref))
    ('model-policy-ref (.ref contract 'model-policy-ref))
    ('prompt-policy-ref (.ref contract 'prompt-policy-ref))
    ('tool-permission-policy-ref
     (.ref contract 'tool-permission-policy-ref))
    ('hook-tool-permission-policy-ref
     (.ref contract 'hook-tool-permission-policy-ref))
    ('resource-sharing-policy-ref
     (.ref contract 'resource-sharing-policy-ref))
    ('durable-policy-ref (.ref contract 'durable-policy-ref))
    ('tool-refs (.ref contract 'tool-refs))
    ('memory-refs (.ref contract 'memory-refs))
    ('sandbox-profile-ref (.ref contract 'sandbox-profile-ref))
    ('streaming-policy (.ref contract 'streaming-policy))
    ('event-policy (.ref contract 'event-policy))
    ('validation-id (.ref contract 'validation-id))
    ('validation-valid? (.ref contract 'validation-valid?))
    ('validation-diagnostic-count
     (.ref contract 'validation-diagnostic-count))
    ('tool-catalog-ref (.ref contract 'tool-catalog-ref))
    ('tool-catalog-valid? (.ref contract 'tool-catalog-valid?))
    ('tool-catalog-policy-tool-refs
     (.ref contract 'tool-catalog-policy-tool-refs))
    ('tool-catalog-resolved-tool-refs
     (.ref contract 'tool-catalog-resolved-tool-refs))
    ('tool-catalog-unresolved-tool-refs
     (.ref contract 'tool-catalog-unresolved-tool-refs))
    ('tool-catalog-allowed-attempt-tool-refs
     (.ref contract 'tool-catalog-allowed-attempt-tool-refs))
    ('tool-catalog-unresolved-attempt-tool-refs
     (.ref contract 'tool-catalog-unresolved-attempt-tool-refs))
    ('memory-catalog-ref (.ref contract 'memory-catalog-ref))
    ('memory-catalog-valid? (.ref contract 'memory-catalog-valid?))
    ('memory-catalog-resolved-store-refs
     (.ref contract 'memory-catalog-resolved-store-refs))
    ('memory-catalog-unresolved-store-refs
     (.ref contract 'memory-catalog-unresolved-store-refs))
    ('allowed-communication-receipts
     (.ref contract 'allowed-communication-receipts))
    ('denied-communication-receipts
     (.ref contract 'denied-communication-receipts))
    ('runtime-owner (.ref contract 'runtime-owner))
    ('runtime-executed (.ref contract 'runtime-executed))
    ('metadata (.ref contract 'metadata)))))

;; : (-> [PooSessionAgentParamContract] [Alist])
(def (agentic-ai-lab-session-agent-param-contracts->alists contracts)
  (agentic-ai-lab-session-receipt-projection-batch
   contracts
   agentic-ai-lab-session-agent-param-contract->alist
   "session AgentParam contract serialization requires a list"))
