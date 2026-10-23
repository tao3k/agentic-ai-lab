;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: report-only session communication receipts.
;;; Invariant: communication receipts describe routing intent only; Scheme does
;;; not deliver messages or mutate source/target sessions.

(import :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/receipt-syntax
        :agentic-ai-lab/modules/session/receipt-projection)

(export +agentic-ai-lab-session-communication-receipt-kind+
        +agentic-ai-lab-session-communication-receipt-schema+
        +agentic-ai-lab-session-communication-channel-receipt-kind+
        +agentic-ai-lab-session-communication-channel-receipt-schema+
        +agentic-ai-lab-session-communication-ledger-ref/default+
        make-agentic-ai-lab-session-communication-channel-receipt-record
        agentic-ai-lab-session-communication-channel-receipt-record?
        agentic-ai-lab-session-communication-channel-receipt
        agentic-ai-lab-session-communication-channel-receipt?
        agentic-ai-lab-session-communication-channel-receipt-project-id
        agentic-ai-lab-session-communication-channel-receipt-channel-id
        agentic-ai-lab-session-communication-channel-receipt-relation-kind
        agentic-ai-lab-session-communication-channel-receipt-source-session-id
        agentic-ai-lab-session-communication-channel-receipt-target-session-id
        agentic-ai-lab-session-communication-channel-receipt-source-agent-id
        agentic-ai-lab-session-communication-channel-receipt-target-agent-id
        agentic-ai-lab-session-communication-channel-receipt-allowed-message-kinds
        agentic-ai-lab-session-communication-channel-receipt-delivery-policies
        agentic-ai-lab-session-communication-channel-receipt-communication-ledger-ref
        agentic-ai-lab-session-communication-channel-receipt-durable-policy-ref
        agentic-ai-lab-session-communication-channel-receipt-valid?
        agentic-ai-lab-session-communication-channel-receipt-diagnostics
        agentic-ai-lab-session-communication-channel-receipt-metadata
        agentic-ai-lab-session-communication-channel-receipt->alist
        agentic-ai-lab-session-communication-channel-receipts->alists
        make-agentic-ai-lab-session-communication-receipt-record
        agentic-ai-lab-session-communication-receipt-record?
        agentic-ai-lab-session-communication-receipt
        agentic-ai-lab-session-communication-receipt?
        agentic-ai-lab-session-communication-receipt-project-id
        agentic-ai-lab-session-communication-receipt-relation-kind
        agentic-ai-lab-session-communication-receipt-source-root-session-id
        agentic-ai-lab-session-communication-receipt-target-root-session-id
        agentic-ai-lab-session-communication-receipt-source-agent-id
        agentic-ai-lab-session-communication-receipt-target-agent-id
        agentic-ai-lab-session-communication-receipt-channel-id
        agentic-ai-lab-session-communication-receipt-source-session-id
        agentic-ai-lab-session-communication-receipt-target-session-id
        agentic-ai-lab-session-communication-receipt-message-kind
        agentic-ai-lab-session-communication-receipt-payload-summary
        agentic-ai-lab-session-communication-receipt-delivery-policy
        agentic-ai-lab-session-communication-receipt-communication-ledger-ref
        agentic-ai-lab-session-communication-receipt-durable-policy-ref
        agentic-ai-lab-session-communication-receipt-valid?
        agentic-ai-lab-session-communication-receipt-diagnostics
        agentic-ai-lab-session-communication-receipt-metadata
        agentic-ai-lab-session-communication-receipt->alist
        agentic-ai-lab-session-communication-receipts->alists)

;; : Symbol
(def +agentic-ai-lab-session-communication-receipt-kind+
  'agentic-ai-lab.session.communication-receipt)

;; : Symbol
(def +agentic-ai-lab-session-communication-receipt-schema+
  'agentic-ai-lab.modules.session.communication-receipt.v1)

;; : Symbol
(def +agentic-ai-lab-session-communication-channel-receipt-kind+
  'agentic-ai-lab.session.communication-channel-receipt)

;; : Symbol
(def +agentic-ai-lab-session-communication-channel-receipt-schema+
  'agentic-ai-lab.modules.session.communication-channel-receipt.v1)

;; : Symbol
(def +agentic-ai-lab-session-communication-ledger-ref/default+
  'runtime/communication-ledger)

;; : [Symbol]
(def +agentic-ai-lab-session-communication-relation-kinds+
  '(parent-child child-parent sibling cross-root))

;; : (-> Symbol Boolean)
(def (agentic-ai-lab-session-communication-relation-kind? value)
  (and (symbol? value)
       (and (memq value +agentic-ai-lab-session-communication-relation-kinds+)
            #t)))

;; : (-> Alist Symbol Object Object)
(def (agentic-ai-lab-session-communication-option options key default-value)
  (let (entry (assoc key options))
    (if entry (cdr entry) default-value)))

;; : (-> Object Boolean)
(def (agentic-ai-lab-session-communication-symbol-list? values)
  (and (list? values)
       (agentic-ai-lab-session-every? symbol? values)))

;; : (-> [Alist] Object)
(def (agentic-ai-lab-session-communication-durable-policy-ref metadata)
  (let (durable-policy
        (agentic-ai-lab-session-communication-option metadata 'durable-policy #f))
    (cond
     ((agentic-ai-lab-durable-policy? durable-policy)
      (agentic-ai-lab-durable-policy-receipt-policy-id
       (agentic-ai-lab-durable-policy->receipt durable-policy)))
     (else
      (agentic-ai-lab-session-communication-option metadata
                                             'durable-policy-ref
                                             #f)))))

;; : PooSessionCommunicationChannelReceiptRecordStruct
(defstruct agentic-ai-lab-session-communication-channel-receipt-record
  (project-id
   channel-id
   relation-kind
   source-session-id
   target-session-id
   source-agent-id
   target-agent-id
   allowed-message-kinds
   delivery-policies
   communication-ledger-ref
   durable-policy-ref
   valid?
   diagnostics
   metadata
   runtime-owner
   handoff-required
   open?
   runtime-executed)
  transparent: #t)

;;; Boundary: communication channel receipts declare allowed session links before
;;; any agent message transport is used.
;; : (-> Symbol Symbol Symbol Symbol Symbol Symbol Symbol [Symbol] [Symbol] [Alist] PooSessionCommunicationChannelReceipt)
(def (agentic-ai-lab-session-communication-channel-receipt project-id
                                                     channel-id
                                                     relation-kind
                                                     source-session-id
                                                     target-session-id
                                                     source-agent-id
                                                     target-agent-id
                                                     allowed-message-kinds
                                                     delivery-policies
                                                     . maybe-metadata)
  (let* ((metadata (if (null? maybe-metadata) '() (car maybe-metadata)))
         (communication-ledger-ref
          (agentic-ai-lab-session-communication-option
           metadata
           'communication-ledger-ref
           +agentic-ai-lab-session-communication-ledger-ref/default+))
         (durable-policy-ref
          (agentic-ai-lab-session-communication-durable-policy-ref metadata)))
    (agentic-ai-lab-session-require "session communication channel project id must be a symbol"
                              (symbol? project-id)
                              project-id)
    (agentic-ai-lab-session-require "session communication channel id must be a symbol"
                              (symbol? channel-id)
                              channel-id)
    (agentic-ai-lab-session-require
     "session communication channel relation kind must be parent-child, child-parent, sibling, or cross-root"
     (agentic-ai-lab-session-communication-relation-kind? relation-kind)
     relation-kind)
    (agentic-ai-lab-session-require "session communication channel source session must be a symbol"
                              (symbol? source-session-id)
                              source-session-id)
    (agentic-ai-lab-session-require "session communication channel target session must be a symbol"
                              (symbol? target-session-id)
                              target-session-id)
    (agentic-ai-lab-session-require "session communication channel source agent must be a symbol"
                              (symbol? source-agent-id)
                              source-agent-id)
    (agentic-ai-lab-session-require "session communication channel target agent must be a symbol"
                              (symbol? target-agent-id)
                              target-agent-id)
    (agentic-ai-lab-session-require "session communication channel message kinds must be symbols"
                              (agentic-ai-lab-session-communication-symbol-list?
                               allowed-message-kinds)
                              allowed-message-kinds)
    (agentic-ai-lab-session-require "session communication channel delivery policies must be symbols"
                              (agentic-ai-lab-session-communication-symbol-list?
                               delivery-policies)
                              delivery-policies)
    (agentic-ai-lab-session-require "session communication channel ledger ref must be a symbol"
                              (symbol? communication-ledger-ref)
                              communication-ledger-ref)
    (make-agentic-ai-lab-session-communication-channel-receipt-record
     project-id
     channel-id
     relation-kind
     source-session-id
     target-session-id
     source-agent-id
     target-agent-id
     allowed-message-kinds
     delivery-policies
     communication-ledger-ref
     durable-policy-ref
     #t
     '()
     metadata
     "marlin-agent-core"
     #t
     #f
     #f)))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-session-communication-channel-receipt? value)
  (agentic-ai-lab-session-communication-channel-receipt-record? value))

;; Public accessors stay as named functions so policy reports point at stable
;; definitions rather than a top-level macro expansion site.
;; : (-> PooSessionCommunicationChannelReceipt Symbol)
(def (agentic-ai-lab-session-communication-channel-receipt-project-id receipt)
  (agentic-ai-lab-session-communication-channel-receipt-record-project-id receipt))

;; : (-> PooSessionCommunicationChannelReceipt Symbol)
(def (agentic-ai-lab-session-communication-channel-receipt-channel-id receipt)
  (agentic-ai-lab-session-communication-channel-receipt-record-channel-id receipt))

;; : (-> PooSessionCommunicationChannelReceipt Symbol)
(def (agentic-ai-lab-session-communication-channel-receipt-relation-kind receipt)
  (agentic-ai-lab-session-communication-channel-receipt-record-relation-kind receipt))

;; : (-> PooSessionCommunicationChannelReceipt Symbol)
(def (agentic-ai-lab-session-communication-channel-receipt-source-session-id receipt)
  (agentic-ai-lab-session-communication-channel-receipt-record-source-session-id
   receipt))

;; : (-> PooSessionCommunicationChannelReceipt Symbol)
(def (agentic-ai-lab-session-communication-channel-receipt-target-session-id receipt)
  (agentic-ai-lab-session-communication-channel-receipt-record-target-session-id
   receipt))

;; : (-> PooSessionCommunicationChannelReceipt Symbol)
(def (agentic-ai-lab-session-communication-channel-receipt-source-agent-id receipt)
  (agentic-ai-lab-session-communication-channel-receipt-record-source-agent-id
   receipt))

;; : (-> PooSessionCommunicationChannelReceipt Symbol)
(def (agentic-ai-lab-session-communication-channel-receipt-target-agent-id receipt)
  (agentic-ai-lab-session-communication-channel-receipt-record-target-agent-id
   receipt))

;; : (-> PooSessionCommunicationChannelReceipt [Symbol])
(def (agentic-ai-lab-session-communication-channel-receipt-allowed-message-kinds
      receipt)
  (agentic-ai-lab-session-communication-channel-receipt-record-allowed-message-kinds
   receipt))

;; : (-> PooSessionCommunicationChannelReceipt [Symbol])
(def (agentic-ai-lab-session-communication-channel-receipt-delivery-policies receipt)
  (agentic-ai-lab-session-communication-channel-receipt-record-delivery-policies
   receipt))

;; : (-> PooSessionCommunicationChannelReceipt Symbol)
(def (agentic-ai-lab-session-communication-channel-receipt-communication-ledger-ref
      receipt)
  (agentic-ai-lab-session-communication-channel-receipt-record-communication-ledger-ref
   receipt))

;; : (-> PooSessionCommunicationChannelReceipt Object)
(def (agentic-ai-lab-session-communication-channel-receipt-durable-policy-ref receipt)
  (agentic-ai-lab-session-communication-channel-receipt-record-durable-policy-ref
   receipt))

;; : (-> PooSessionCommunicationChannelReceipt Boolean)
(def (agentic-ai-lab-session-communication-channel-receipt-valid? receipt)
  (agentic-ai-lab-session-communication-channel-receipt-record-valid? receipt))

;; : (-> PooSessionCommunicationChannelReceipt [Alist])
(def (agentic-ai-lab-session-communication-channel-receipt-diagnostics receipt)
  (agentic-ai-lab-session-communication-channel-receipt-record-diagnostics receipt))

;; : (-> PooSessionCommunicationChannelReceipt Alist)
(def (agentic-ai-lab-session-communication-channel-receipt-metadata receipt)
  (agentic-ai-lab-session-communication-channel-receipt-record-metadata receipt))

;; : (-> PooSessionCommunicationChannelReceipt Alist)
(defpoo-session-receipt-projection
  agentic-ai-lab-session-communication-channel-receipt->alist
  (receipt)
  (bindings
   ((diagnostics
     (agentic-ai-lab-session-communication-channel-receipt-diagnostics receipt))))
  (fields
   (('kind +agentic-ai-lab-session-communication-channel-receipt-kind+)
    ('schema +agentic-ai-lab-session-communication-channel-receipt-schema+)
    ('project-id
     (agentic-ai-lab-session-communication-channel-receipt-project-id receipt))
    ('channel-id
     (agentic-ai-lab-session-communication-channel-receipt-channel-id receipt))
    ('relation-kind
     (agentic-ai-lab-session-communication-channel-receipt-relation-kind receipt))
    ('source-session-id
     (agentic-ai-lab-session-communication-channel-receipt-source-session-id
      receipt))
    ('target-session-id
     (agentic-ai-lab-session-communication-channel-receipt-target-session-id
      receipt))
    ('source-agent-id
     (agentic-ai-lab-session-communication-channel-receipt-source-agent-id receipt))
    ('target-agent-id
     (agentic-ai-lab-session-communication-channel-receipt-target-agent-id receipt))
    ('allowed-message-kinds
     (agentic-ai-lab-session-communication-channel-receipt-allowed-message-kinds
      receipt))
    ('delivery-policies
     (agentic-ai-lab-session-communication-channel-receipt-delivery-policies
      receipt))
    ('communication-ledger-ref
     (agentic-ai-lab-session-communication-channel-receipt-communication-ledger-ref
      receipt))
    ('durable-policy-ref
     (agentic-ai-lab-session-communication-channel-receipt-durable-policy-ref
      receipt))
    ('valid?
     (agentic-ai-lab-session-communication-channel-receipt-valid? receipt))
    ('diagnostics diagnostics)
    ('diagnostic-count (length diagnostics))
    ('metadata
     (agentic-ai-lab-session-communication-channel-receipt-metadata receipt))
    ('runtime-owner
     (agentic-ai-lab-session-communication-channel-receipt-record-runtime-owner
      receipt))
    ('handoff-required
     (agentic-ai-lab-session-communication-channel-receipt-record-handoff-required
      receipt))
    ('open?
     (agentic-ai-lab-session-communication-channel-receipt-record-open? receipt))
    ('runtime-executed
     (agentic-ai-lab-session-communication-channel-receipt-record-runtime-executed
      receipt)))))

;; : (-> [PooSessionCommunicationChannelReceipt] [Alist])
(def (agentic-ai-lab-session-communication-channel-receipts->alists receipts)
  (agentic-ai-lab-session-receipt-projection-batch
   receipts
   agentic-ai-lab-session-communication-channel-receipt->alist
   "session communication channel serialization requires a list"))

;; : PooSessionCommunicationReceiptRecordStruct
(defstruct agentic-ai-lab-session-communication-receipt-record
  (project-id
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
   communication-ledger-ref
   durable-policy-ref
   valid?
   diagnostics
   metadata
   runtime-owner
   handoff-required
   delivered?
   runtime-executed)
  transparent: #t)

;;; Boundary: communication receipts capture message routing evidence while
;;; keeping payload handling outside session policy validation.
;; : (-> Symbol Symbol Symbol Symbol Symbol Symbol Symbol Symbol Symbol Symbol Datum Symbol [Alist] PooSessionCommunicationReceipt)
(def (agentic-ai-lab-session-communication-receipt project-id
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
                                             . maybe-metadata)
  (let* ((metadata (if (null? maybe-metadata) '() (car maybe-metadata)))
         (communication-ledger-ref
          (agentic-ai-lab-session-communication-option
           metadata
           'communication-ledger-ref
           +agentic-ai-lab-session-communication-ledger-ref/default+))
         (durable-policy-ref
          (agentic-ai-lab-session-communication-durable-policy-ref metadata)))
    (agentic-ai-lab-session-require "session communication project id must be a symbol"
                              (symbol? project-id)
                              project-id)
    (agentic-ai-lab-session-require
     "session communication relation kind must be parent-child, child-parent, sibling, or cross-root"
     (agentic-ai-lab-session-communication-relation-kind? relation-kind)
     relation-kind)
    (agentic-ai-lab-session-require "session communication source root must be a symbol"
                              (symbol? source-root-session-id)
                              source-root-session-id)
    (agentic-ai-lab-session-require "session communication target root must be a symbol"
                              (symbol? target-root-session-id)
                              target-root-session-id)
    (agentic-ai-lab-session-require "session communication source session must be a symbol"
                              (symbol? source-session-id)
                              source-session-id)
    (agentic-ai-lab-session-require "session communication target session must be a symbol"
                              (symbol? target-session-id)
                              target-session-id)
    (agentic-ai-lab-session-require "session communication source agent must be a symbol"
                              (symbol? source-agent-id)
                              source-agent-id)
    (agentic-ai-lab-session-require "session communication target agent must be a symbol"
                              (symbol? target-agent-id)
                              target-agent-id)
    (agentic-ai-lab-session-require "session communication channel must be a symbol"
                              (symbol? channel-id)
                              channel-id)
    (agentic-ai-lab-session-require "session communication message kind must be a symbol"
                              (symbol? message-kind)
                              message-kind)
    (agentic-ai-lab-session-require "session communication delivery policy must be a symbol"
                              (symbol? delivery-policy)
                              delivery-policy)
    (agentic-ai-lab-session-require "session communication ledger ref must be a symbol"
                              (symbol? communication-ledger-ref)
                              communication-ledger-ref)
    (make-agentic-ai-lab-session-communication-receipt-record
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
     communication-ledger-ref
     durable-policy-ref
     #t
     '()
     metadata
     "marlin-agent-core"
     #t
     #f
     #f)))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-session-communication-receipt? value)
  (agentic-ai-lab-session-communication-receipt-record? value))

;; Public accessors stay as named functions so policy reports point at stable
;; definitions rather than a top-level macro expansion site.
;; : (-> PooSessionCommunicationReceipt Symbol)
(def (agentic-ai-lab-session-communication-receipt-project-id receipt)
  (agentic-ai-lab-session-communication-receipt-record-project-id receipt))

;; : (-> PooSessionCommunicationReceipt Symbol)
(def (agentic-ai-lab-session-communication-receipt-relation-kind receipt)
  (agentic-ai-lab-session-communication-receipt-record-relation-kind receipt))

;; : (-> PooSessionCommunicationReceipt Symbol)
(def (agentic-ai-lab-session-communication-receipt-source-root-session-id receipt)
  (agentic-ai-lab-session-communication-receipt-record-source-root-session-id receipt))

;; : (-> PooSessionCommunicationReceipt Symbol)
(def (agentic-ai-lab-session-communication-receipt-target-root-session-id receipt)
  (agentic-ai-lab-session-communication-receipt-record-target-root-session-id receipt))

;; : (-> PooSessionCommunicationReceipt Symbol)
(def (agentic-ai-lab-session-communication-receipt-channel-id receipt)
  (agentic-ai-lab-session-communication-receipt-record-channel-id receipt))

;; : (-> PooSessionCommunicationReceipt Symbol)
(def (agentic-ai-lab-session-communication-receipt-source-session-id receipt)
  (agentic-ai-lab-session-communication-receipt-record-source-session-id receipt))

;; : (-> PooSessionCommunicationReceipt Symbol)
(def (agentic-ai-lab-session-communication-receipt-target-session-id receipt)
  (agentic-ai-lab-session-communication-receipt-record-target-session-id receipt))

;; : (-> PooSessionCommunicationReceipt Symbol)
(def (agentic-ai-lab-session-communication-receipt-source-agent-id receipt)
  (agentic-ai-lab-session-communication-receipt-record-source-agent-id receipt))

;; : (-> PooSessionCommunicationReceipt Symbol)
(def (agentic-ai-lab-session-communication-receipt-target-agent-id receipt)
  (agentic-ai-lab-session-communication-receipt-record-target-agent-id receipt))

;; : (-> PooSessionCommunicationReceipt Symbol)
(def (agentic-ai-lab-session-communication-receipt-message-kind receipt)
  (agentic-ai-lab-session-communication-receipt-record-message-kind receipt))

;; : (-> PooSessionCommunicationReceipt Object)
(def (agentic-ai-lab-session-communication-receipt-payload-summary receipt)
  (agentic-ai-lab-session-communication-receipt-record-payload-summary receipt))

;; : (-> PooSessionCommunicationReceipt Symbol)
(def (agentic-ai-lab-session-communication-receipt-delivery-policy receipt)
  (agentic-ai-lab-session-communication-receipt-record-delivery-policy receipt))

;; : (-> PooSessionCommunicationReceipt Symbol)
(def (agentic-ai-lab-session-communication-receipt-communication-ledger-ref receipt)
  (agentic-ai-lab-session-communication-receipt-record-communication-ledger-ref
   receipt))

;; : (-> PooSessionCommunicationReceipt Object)
(def (agentic-ai-lab-session-communication-receipt-durable-policy-ref receipt)
  (agentic-ai-lab-session-communication-receipt-record-durable-policy-ref receipt))

;; : (-> PooSessionCommunicationReceipt Boolean)
(def (agentic-ai-lab-session-communication-receipt-valid? receipt)
  (agentic-ai-lab-session-communication-receipt-record-valid? receipt))

;; : (-> PooSessionCommunicationReceipt [Alist])
(def (agentic-ai-lab-session-communication-receipt-diagnostics receipt)
  (agentic-ai-lab-session-communication-receipt-record-diagnostics receipt))

;; : (-> PooSessionCommunicationReceipt Alist)
(def (agentic-ai-lab-session-communication-receipt-metadata receipt)
  (agentic-ai-lab-session-communication-receipt-record-metadata receipt))

;; : (-> PooSessionCommunicationReceipt Alist)
(defpoo-session-receipt-projection
  agentic-ai-lab-session-communication-receipt->alist
  (receipt)
  (bindings
   ((diagnostics
     (agentic-ai-lab-session-communication-receipt-diagnostics receipt))))
  (fields
   (('kind +agentic-ai-lab-session-communication-receipt-kind+)
    ('schema +agentic-ai-lab-session-communication-receipt-schema+)
    ('project-id
     (agentic-ai-lab-session-communication-receipt-project-id receipt))
    ('relation-kind
     (agentic-ai-lab-session-communication-receipt-relation-kind receipt))
    ('source-root-session-id
     (agentic-ai-lab-session-communication-receipt-source-root-session-id
      receipt))
    ('target-root-session-id
     (agentic-ai-lab-session-communication-receipt-target-root-session-id
      receipt))
    ('source-session-id
     (agentic-ai-lab-session-communication-receipt-source-session-id receipt))
    ('target-session-id
     (agentic-ai-lab-session-communication-receipt-target-session-id receipt))
    ('source-agent-id
     (agentic-ai-lab-session-communication-receipt-source-agent-id receipt))
    ('target-agent-id
     (agentic-ai-lab-session-communication-receipt-target-agent-id receipt))
    ('channel-id
     (agentic-ai-lab-session-communication-receipt-channel-id receipt))
    ('message-kind
     (agentic-ai-lab-session-communication-receipt-message-kind receipt))
    ('payload-summary
     (agentic-ai-lab-session-communication-receipt-payload-summary receipt))
    ('delivery-policy
     (agentic-ai-lab-session-communication-receipt-delivery-policy receipt))
    ('communication-ledger-ref
     (agentic-ai-lab-session-communication-receipt-communication-ledger-ref
      receipt))
    ('durable-policy-ref
     (agentic-ai-lab-session-communication-receipt-durable-policy-ref receipt))
    ('valid?
     (agentic-ai-lab-session-communication-receipt-valid? receipt))
    ('diagnostics diagnostics)
    ('diagnostic-count (length diagnostics))
    ('metadata
     (agentic-ai-lab-session-communication-receipt-metadata receipt))
    ('runtime-owner
     (agentic-ai-lab-session-communication-receipt-record-runtime-owner receipt))
    ('handoff-required
     (agentic-ai-lab-session-communication-receipt-record-handoff-required
      receipt))
    ('delivered?
     (agentic-ai-lab-session-communication-receipt-record-delivered? receipt))
    ('runtime-executed
     (agentic-ai-lab-session-communication-receipt-record-runtime-executed
      receipt)))))

;; : (-> [PooSessionCommunicationReceipt] [Alist])
(def (agentic-ai-lab-session-communication-receipts->alists receipts)
  (agentic-ai-lab-session-receipt-projection-batch
   receipts
   agentic-ai-lab-session-communication-receipt->alist
   "session communication receipt serialization requires a list"))
