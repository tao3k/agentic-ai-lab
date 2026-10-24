;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: runtime helpers for user-facing session topology syntax.
;;; Invariant: syntax modules expand to these pure constructors, not directly
;;; to the wider session object graph.

(import (only-in :agentic-ai-lab/modules/agent-sandbox/config
                 agentic-ai-lab-default-sandbox-profiles)
        :agentic-ai-lab/modules/session/agent
        :agentic-ai-lab/modules/session/agent-param
        :agentic-ai-lab/modules/session/communication
        :agentic-ai-lab/modules/session/materialization
        :agentic-ai-lab/modules/session/objects-core
        :agentic-ai-lab/modules/session/objects-handoff
        :agentic-ai-lab/modules/session/objects-graph
        :agentic-ai-lab/modules/session/registry
        :agentic-ai-lab/modules/session/selector)

(export agentic-ai-lab-session-syntax-chunk
        agentic-ai-lab-session-syntax-lineage
        agentic-ai-lab-session-syntax-default-placement
        agentic-ai-lab-session-syntax-value
        agentic-ai-lab-session-default-placement
        agentic-ai-lab-session-syntax-graph-presentation
        agentic-ai-lab-session-syntax-registry-entry
        agentic-ai-lab-session-syntax-registry
        session-communication-channel-row
        agentic-ai-lab-session-syntax-communication-channel-rows
        agentic-ai-lab-session-syntax-communication-channel
        session-communication-row
        agentic-ai-lab-session-syntax-communication-rows
        agentic-ai-lab-session-syntax-communication
        agentic-ai-lab-session-syntax-selector-candidate
        session-selector-row
        agentic-ai-lab-session-syntax-selector
        session-materialization-row
        agentic-ai-lab-session-syntax-materialization
        agentic-ai-lab-session-syntax-agent-node
        session-agent-node-registry-entry
        agentic-ai-lab-session-syntax-agent-graph
        agentic-ai-lab-session-syntax-agent-param-contract
        session-agent-param-row)

;; : (-> Symbol Symbol String Alist)
(def (agentic-ai-lab-session-syntax-chunk chunk-id role content)
  (agentic-ai-lab-session-chunk chunk-id role content))

;; : (-> Symbol [Symbol] Symbol PooSessionLineage)
(def (agentic-ai-lab-session-syntax-lineage session-id parent-session-ids branch-kind)
  (agentic-ai-lab-session-lineage session-id parent-session-ids branch-kind))

;; : (-> Symbol [Alist] PooSessionPlacement)
(def (agentic-ai-lab-session-syntax-default-placement profile-ref . maybe-metadata)
  (apply agentic-ai-lab-session-default-placement profile-ref maybe-metadata))

;; : (-> Symbol [Alist] PooSessionLineage PooSessionPlacement [Alist] PooSessionValue)
(def (agentic-ai-lab-session-syntax-value session-id chunks lineage placement . metadata)
  (apply agentic-ai-lab-session-value session-id chunks lineage placement metadata))

;;; The default user-facing placement resolves against the maintained sandbox
;;; catalog. It remains report-only and never realizes a runtime descriptor.
;; : (-> Symbol [Alist] PooSessionPlacement)
(def (agentic-ai-lab-session-default-placement profile-ref . maybe-metadata)
  (apply agentic-ai-lab-session-placement-resolve
         profile-ref
         agentic-ai-lab-default-sandbox-profiles
         maybe-metadata))

;; : (-> [PooSessionValue] PooSessionGraphPresentation)
(def (agentic-ai-lab-session-syntax-graph-presentation session-values)
  (agenticAiLabSessionGraphPresentation session-values))

;; : (-> PooSession Symbol [Symbol] Alist [Alist] PooSessionRegistryEntry)
(def (agentic-ai-lab-session-syntax-registry-entry session-value
                                             agent-id
                                             channel-ids
                                             policies
                                             .
                                             maybe-metadata)
  (apply agentic-ai-lab-session-registry-entry
         session-value
         agent-id
         channel-ids
         policies
         maybe-metadata))

;; : (-> Symbol [Symbol] [Symbol] Symbol [PooSessionRegistryEntry] [Alist] PooSessionRegistryReceipt)
(def (agentic-ai-lab-session-syntax-registry project-id
                                       root-session-ids
                                       child-session-ids
                                       active-session-ref
                                       entries
                                       .
                                       maybe-metadata)
  (apply agentic-ai-lab-session-registry-receipt
         project-id
         root-session-ids
         child-session-ids
         active-session-ref
         entries
         maybe-metadata))

;; : (-> PooSessionCommunicationChannelReceipt Alist)
(def (session-communication-channel-row receipt)
  (agentic-ai-lab-session-communication-channel-receipt->alist receipt))

;; : (-> [PooSessionCommunicationChannelReceipt] [Alist])
(def (agentic-ai-lab-session-syntax-communication-channel-rows receipts)
  (agentic-ai-lab-session-communication-channel-receipts->alists receipts))

;; : (-> Symbol Symbol Symbol Symbol Symbol Symbol Symbol [Symbol] [Symbol] [Alist] PooSessionCommunicationChannelReceipt)
(def (agentic-ai-lab-session-syntax-communication-channel project-id
                                                    channel-id
                                                    relation-kind
                                                    source-session-id
                                                    target-session-id
                                                    source-agent-id
                                                    target-agent-id
                                                    message-kinds
                                                    delivery-policies
                                                    .
                                                    maybe-metadata)
  (apply agentic-ai-lab-session-communication-channel-receipt
         project-id
         channel-id
         relation-kind
         source-session-id
         target-session-id
         source-agent-id
         target-agent-id
         message-kinds
         delivery-policies
         maybe-metadata))

;; : (-> PooSessionCommunicationReceipt Alist)
(def (session-communication-row receipt)
  (agentic-ai-lab-session-communication-receipt->alist receipt))

;; : (-> [PooSessionCommunicationReceipt] [Alist])
(def (agentic-ai-lab-session-syntax-communication-rows receipts)
  (agentic-ai-lab-session-communication-receipts->alists receipts))

;; : (-> Symbol Symbol Symbol Symbol Symbol Symbol Symbol Symbol Symbol Symbol Symbol Symbol [Alist] PooSessionCommunicationReceipt)
(def (agentic-ai-lab-session-syntax-communication project-id
                                            relation-kind
                                            source-root-session-id
                                            target-root-session-id
                                            source-session-id
                                            target-session-id
                                            source-agent-id
                                            target-agent-id
                                            channel-id
                                            message-kind
                                            payload-summary
                                            delivery-policy
                                            .
                                            maybe-metadata)
  (apply agentic-ai-lab-session-communication-receipt
         project-id
         relation-kind
         source-root-session-id
         target-root-session-id
         source-session-id
         target-session-id
         source-agent-id
         target-agent-id
         channel-id
         message-kind
         payload-summary
         delivery-policy
         maybe-metadata))

;; : (-> Symbol Symbol Symbol Symbol [Symbol] [Alist] PooSessionSelectorCandidate)
(def (agentic-ai-lab-session-syntax-selector-candidate candidate-id
                                                 candidate-kind
                                                 target-ref
                                                 description-value
                                                 required-receipt-fields
                                                 .
                                                 maybe-metadata)
  (apply agentic-ai-lab-session-selector-candidate
         candidate-id
         candidate-kind
         target-ref
         description-value
         required-receipt-fields
         maybe-metadata))

;; : (-> PooSessionSelectorReceipt Alist)
(def (session-selector-row receipt)
  (agentic-ai-lab-session-selector-receipt->alist receipt))

;; : (-> Symbol Symbol Symbol Symbol [PooSessionSelectorCandidate] Alist Symbol [Alist] PooSessionSelectorReceipt)
(def (agentic-ai-lab-session-syntax-selector selector-id
                                       project-id
                                       root-session-ref
                                       input-session-ref
                                       candidates
                                       policy
                                       fallback-ref
                                       .
                                       maybe-metadata)
  (apply agentic-ai-lab-session-selector-receipt
         selector-id
         project-id
         root-session-ref
         input-session-ref
         candidates
         policy
         fallback-ref
         maybe-metadata))

;; : (-> PooSessionMaterializationReceipt Alist)
(def (session-materialization-row receipt)
  (agentic-ai-lab-session-materialization-receipt->alist receipt))

;; : (-> Symbol Symbol Symbol Symbol [Symbol] Symbol Symbol Symbol Alist Symbol [Alist] PooSessionMaterializationReceipt)
(def (agentic-ai-lab-session-syntax-materialization request-id
                                             project-id
                                             root-session-ref
                                             session-ref
                                             parent-session-refs
                                             materialization-state
                                             pending-runtime-ref
                                             sandbox-handle-ref
                                             token-summary-entries
                                             error-summary
                                             .
                                             maybe-metadata)
  (apply agentic-ai-lab-session-runtime-materialization-receipt
         request-id
         project-id
         root-session-ref
         session-ref
         parent-session-refs
         materialization-state
         pending-runtime-ref
         sandbox-handle-ref
         token-summary-entries
         error-summary
         maybe-metadata))

;; : (-> Symbol Symbol Symbol Symbol Symbol Symbol Symbol [Symbol] [Symbol] Symbol Symbol Symbol Symbol Symbol Symbol [Symbol] [Symbol] Symbol Symbol Symbol [Alist] PooSessionAgentNode)
(def (agentic-ai-lab-session-syntax-agent-node agent-id
                                        project-ref
                                        root-session-ref
                                        parent-session-ref
                                        agent-system-session-ref
                                        input-session-ref
                                        output-session-ref
                                        peer-session-refs
                                        communication-channels
                                        model-policy-ref
                                        prompt-policy-ref
                                        tool-permission-policy-ref
                                        hook-tool-permission-policy-ref
                                        resource-sharing-policy-ref
                                        durable-policy-ref
                                        tool-refs
                                        memory-refs
                                        sandbox-profile-ref
                                        role-value
                                        result-contract
                                        .
                                        maybe-metadata)
  (apply agentic-ai-lab-session-agent-node
         agent-id
         project-ref
         root-session-ref
         parent-session-ref
         agent-system-session-ref
         input-session-ref
         output-session-ref
         peer-session-refs
         communication-channels
         model-policy-ref
         prompt-policy-ref
         tool-permission-policy-ref
         hook-tool-permission-policy-ref
         resource-sharing-policy-ref
         durable-policy-ref
         tool-refs
         memory-refs
         sandbox-profile-ref
         role-value
         result-contract
         maybe-metadata))

;; : (-> PooSessionAgentNode PooSession PooSessionRegistryEntry)
(def (session-agent-node-registry-entry node session-value)
  (agentic-ai-lab-session-agent-node->registry-entry node session-value))

;; : (-> Alist Symbol Object Object)
(def (agentic-ai-lab-session-syntax-agent-graph-metadata-ref metadata
                                                        key
                                                        default-value)
  (if (list? metadata)
    (let (entry (assoc key metadata))
      (if entry (cdr entry) default-value))
    default-value))

;; : (-> [Object] Alist Alist)
(def (agentic-ai-lab-session-syntax-agent-graph-topology-metadata agent-nodes
                                                            metadata)
  (let (channel-receipts
        (agentic-ai-lab-session-syntax-agent-graph-metadata-ref
         metadata
         'communication-channel-receipts
         '()))
    (agentic-ai-lab-session-topology->handoff-metadata
     (list
      (cons 'agent-registered?
            (and (pair? agent-nodes) #t))
      (cons 'subagent-registered?
            (and (pair? agent-nodes)
                 (pair? (cdr agent-nodes))
                 #t))
      (cons 'channel-authorized?
            (and (pair? channel-receipts) #t)))
     metadata)))

;; : (-> Symbol Symbol [PooSessionAgentNode] [PooSession] PooSessionRegistryReceipt [PooSessionCommunicationReceipt] [Alist] PooSessionAgentGraph)
(def (agentic-ai-lab-session-syntax-agent-graph project-id
                                          root-session-ref
                                          agent-nodes
                                          session-values
                                          registry-receipt
                                          communication-receipts
                                          .
                                          maybe-metadata)
  (let* ((metadata (if (null? maybe-metadata)
                     '()
                     (car maybe-metadata)))
         (handoff-metadata
          (agentic-ai-lab-session-syntax-agent-graph-topology-metadata
           agent-nodes
           metadata)))
    (agentic-ai-lab-session-agent-graph
     project-id
     root-session-ref
     agent-nodes
     session-values
     registry-receipt
     communication-receipts
     handoff-metadata)))

;; : (-> Symbol PooSessionAgentNode PooSessionAgentParamValidationReceipt Symbol Symbol Symbol [Alist] PooSessionAgentParamContract)
(def (agentic-ai-lab-session-syntax-agent-param-contract contract-id
                                                   agent-node
                                                   validation-receipt
                                                   provider-ref
                                                   streaming-policy
                                                   event-policy
                                                   .
                                                   maybe-metadata)
  (apply agentic-ai-lab-session-agent-param-contract
         contract-id
         agent-node
         validation-receipt
         provider-ref
         streaming-policy
         event-policy
         maybe-metadata))

;; : (-> PooSessionAgentParamContract Alist)
(def (session-agent-param-row contract)
  (agentic-ai-lab-session-agent-param-contract->alist contract))
