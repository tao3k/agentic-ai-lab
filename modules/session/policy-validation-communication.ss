;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: communication receipt normalization and grant checks.

(import (only-in :agentic-ai-lab/modules/session/communication
                 agentic-ai-lab-session-communication-channel-receipt?
                 agentic-ai-lab-session-communication-channel-receipt->alist
                 agentic-ai-lab-session-communication-receipt?
                 agentic-ai-lab-session-communication-receipt->alist)
        :agentic-ai-lab/modules/session/policy-validation-support)

(export agentic-ai-lab-session-policy-communication-receipts
        agentic-ai-lab-session-policy-communication-channel-receipts
        agentic-ai-lab-session-policy-communication-channel-receipt-row
        agentic-ai-lab-session-policy-communication-channel-receipt-rows
        agentic-ai-lab-session-policy-communication-receipt-row
        agentic-ai-lab-session-policy-communication-receipt-rows
        agentic-ai-lab-session-policy-communication-receipt-channel
        agentic-ai-lab-session-policy-communication-channel-receipt-channel
        agentic-ai-lab-session-policy-communication-receipt-target
        agentic-ai-lab-session-policy-communication-channel-receipt-target
        agentic-ai-lab-session-policy-communication-receipt-channel-allowed?
        agentic-ai-lab-session-policy-communication-channel-receipt-channel-allowed?
        agentic-ai-lab-session-policy-communication-receipt-target-allowed?
        agentic-ai-lab-session-policy-communication-channel-receipt-target-allowed?
        agentic-ai-lab-session-policy-communication-receipt-allowed?
        agentic-ai-lab-session-policy-communication-channel-receipt-allowed?)

;; : (-> Alist [PooSessionCommunicationReceiptOrRow])
(def (agentic-ai-lab-session-policy-communication-receipts metadata)
  (agentic-ai-lab-session-validation-alist-ref metadata 'communication-receipts '()))

;; : (-> Alist [PooSessionCommunicationChannelReceiptOrRow])
(def (agentic-ai-lab-session-policy-communication-channel-receipts metadata)
  (agentic-ai-lab-session-validation-alist-ref
   metadata
   'communication-channel-receipts
   '()))

;; : (-> PooSessionCommunicationChannelReceiptOrRow Alist)
(def (agentic-ai-lab-session-policy-communication-channel-receipt-row receipt)
  (cond
   ((agentic-ai-lab-session-communication-channel-receipt? receipt)
    (agentic-ai-lab-session-communication-channel-receipt->alist receipt))
   ((list? receipt) receipt)
   (else
    (list (cons 'kind 'agentic-ai-lab.session.communication-channel-receipt.invalid)
          (cons 'value receipt)))))

;; : (forall (a b) (-> [a] [b]))
;; : (-> [PooSessionCommunicationChannelReceiptOrRow] [Alist])
(def (agentic-ai-lab-session-policy-communication-channel-receipt-rows receipts)
  (map agentic-ai-lab-session-policy-communication-channel-receipt-row receipts))

;; : (-> PooSessionCommunicationReceiptOrRow Alist)
(def (agentic-ai-lab-session-policy-communication-receipt-row receipt)
  (cond
   ((agentic-ai-lab-session-communication-receipt? receipt)
    (agentic-ai-lab-session-communication-receipt->alist receipt))
   ((list? receipt) receipt)
   (else
    (list (cons 'kind 'agentic-ai-lab.session.communication-receipt.invalid)
          (cons 'value receipt)))))

;; : (forall (a b) (-> [a] [b]))
;; : (-> [PooSessionCommunicationReceiptOrRow] [Alist])
(def (agentic-ai-lab-session-policy-communication-receipt-rows receipts)
  (map agentic-ai-lab-session-policy-communication-receipt-row receipts))

;; : (-> Alist Symbol)
(def (agentic-ai-lab-session-policy-communication-receipt-channel row)
  (agentic-ai-lab-session-validation-row-ref row 'channel-id #f))

;; : (-> Alist Symbol)
(def (agentic-ai-lab-session-policy-communication-channel-receipt-channel row)
  (agentic-ai-lab-session-validation-row-ref row 'channel-id #f))

;; : (-> Alist Symbol)
(def (agentic-ai-lab-session-policy-communication-receipt-target row)
  (agentic-ai-lab-session-validation-row-ref row 'target-session-id #f))

;; : (-> Alist Symbol)
(def (agentic-ai-lab-session-policy-communication-channel-receipt-target row)
  (agentic-ai-lab-session-validation-row-ref row 'target-session-id #f))

;; : (-> PooSessionPolicy Alist Boolean)
(def (agentic-ai-lab-session-policy-communication-receipt-channel-allowed?
      policy
      row)
  (agentic-ai-lab-session-validation-granted?
   (agentic-ai-lab-session-policy-communication-receipt-channel row)
   (agentic-ai-lab-session-policy-channel-allowed policy)))

;; : (-> PooSessionPolicy Alist Boolean)
(def (agentic-ai-lab-session-policy-communication-channel-receipt-channel-allowed?
      policy
      row)
  (agentic-ai-lab-session-validation-granted?
   (agentic-ai-lab-session-policy-communication-channel-receipt-channel row)
   (agentic-ai-lab-session-policy-channel-allowed policy)))

;; : (-> PooSessionPolicy Alist Boolean)
(def (agentic-ai-lab-session-policy-communication-receipt-target-allowed?
      policy
      row)
  (agentic-ai-lab-session-validation-granted?
   (agentic-ai-lab-session-policy-communication-receipt-target row)
   (agentic-ai-lab-session-policy-communication-targets policy)))

;; : (-> PooSessionPolicy Alist Boolean)
(def (agentic-ai-lab-session-policy-communication-channel-receipt-target-allowed?
      policy
      row)
  (agentic-ai-lab-session-validation-granted?
   (agentic-ai-lab-session-policy-communication-channel-receipt-target row)
   (agentic-ai-lab-session-policy-communication-targets policy)))

;; : (-> PooSessionPolicy Alist Boolean)
(def (agentic-ai-lab-session-policy-communication-receipt-allowed? policy row)
  (and (agentic-ai-lab-session-policy-communication-receipt-channel-allowed?
        policy
        row)
       (agentic-ai-lab-session-policy-communication-receipt-target-allowed?
        policy
        row)))

;; : (-> PooSessionPolicy Alist Boolean)
(def (agentic-ai-lab-session-policy-communication-channel-receipt-allowed?
      policy
      row)
  (and (agentic-ai-lab-session-policy-communication-channel-receipt-channel-allowed?
        policy
        row)
       (agentic-ai-lab-session-policy-communication-channel-receipt-target-allowed?
        policy
        row)))
