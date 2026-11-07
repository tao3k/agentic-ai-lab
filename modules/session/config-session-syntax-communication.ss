;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: config-session communication syntax owns channel authoring before
;;; session runtime receipts materialize message routing.
;;; Invariant: channel expansion must preserve explicit session ids so policy
;;; can reason about allowed cross-agent communication.
(import :agentic-ai-lab/modules/session/config-session-runtime)

(export session-communication-channel
        session-communication-channel-rows
        session-communication
        session-communication-rows)

;; session-communication-channel
;; : (-> Syntax PooSessionCommunicationChannelReceipt)
;; | doc m%
;;   Build a communication channel receipt between session and agent ids.
;;   # Examples
;;   ```scheme
;;   (session-communication-channel project inbox (relation parent-child) ...)
;;   ;; => session communication channel object
;;   ```
(defrules session-communication-channel
  (relation sessions agents messages delivery metadata)
  ((_ project-id channel-id
      (relation relation-kind)
      (sessions source-session-id target-session-id)
      (agents source-agent-id target-agent-id)
      (messages message-kind ...)
      (delivery delivery-policy ...)
      (metadata metadata-entry ...))
   (agentic-ai-lab-session-syntax-communication-channel
    'project-id
    'channel-id
    'relation-kind
    'source-session-id
    'target-session-id
    'source-agent-id
    'target-agent-id
    '(message-kind ...)
    '(delivery-policy ...)
    '(metadata-entry ...)))
  ((_ project-id channel-id
      (relation relation-kind)
      (sessions source-session-id target-session-id)
      (agents source-agent-id target-agent-id)
      (messages message-kind ...)
      (delivery delivery-policy ...))
   (agentic-ai-lab-session-syntax-communication-channel
    'project-id
    'channel-id
    'relation-kind
    'source-session-id
    'target-session-id
    'source-agent-id
    'target-agent-id
    '(message-kind ...)
    '(delivery-policy ...))))

;; session-communication-channel-rows
;; : (-> PooSessionCommunicationChannelReceipt ... [Alist])
;; | doc m%
;;   Collect communication channel receipts into a bounded channel rows object.
;;   # Examples
;;   ```scheme
;;   (session-communication-channel-rows inbox outbox)
;;   ;; => communication channel rows object
;;   ```
(def (session-communication-channel-rows . receipts)
  (agentic-ai-lab-session-syntax-communication-channel-rows receipts))

;; session-communication
;; : (-> Syntax PooSessionCommunicationReceipt)
;; | doc m%
;;   Build a communication event receipt between roots, sessions, agents,
;;   channel id, message summary, and delivery policy.
;;   # Examples
;;   ```scheme
;;   (session-communication project (relation parent-child) ...)
;;   ;; => session communication object
;;   ```
(defrules session-communication
  (relation roots sessions agents channel message delivery metadata)
  ((_ project-id
      (relation relation-kind)
      (roots source-root-session-id target-root-session-id)
      (sessions source-session-id target-session-id)
      (agents source-agent-id target-agent-id)
      (channel channel-id)
      (message message-kind payload-summary)
      (delivery delivery-policy)
      (metadata metadata-entry ...))
   (agentic-ai-lab-session-syntax-communication
    'project-id
    'relation-kind
    'source-root-session-id
    'target-root-session-id
    'source-session-id
    'target-session-id
    'source-agent-id
    'target-agent-id
    'channel-id
    'message-kind
    'payload-summary
    'delivery-policy
    '(metadata-entry ...)))
  ((_ project-id
      (relation relation-kind)
      (roots source-root-session-id target-root-session-id)
      (sessions source-session-id target-session-id)
      (agents source-agent-id target-agent-id)
      (channel channel-id)
      (message message-kind payload-summary)
      (delivery delivery-policy))
   (agentic-ai-lab-session-syntax-communication
    'project-id
    'relation-kind
    'source-root-session-id
    'target-root-session-id
    'source-session-id
    'target-session-id
    'source-agent-id
    'target-agent-id
    'channel-id
    'message-kind
    'payload-summary
    'delivery-policy)))

;; session-communication-rows
;; : (-> PooSessionCommunicationReceipt ... [Alist])
;; | doc m%
;;   Collect communication event receipts into a bounded rows object.
;;   # Examples
;;   ```scheme
;;   (session-communication-rows request response)
;;   ;; => communication rows object
;;   ```
(def (session-communication-rows . receipts)
  (agentic-ai-lab-session-syntax-communication-rows receipts))
