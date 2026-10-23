;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: session tool grant rows, contracts, and grant matching.

(import :poo-flow/modules/session/objects
        :poo-flow/modules/session/policy-syntax
        :poo-flow/modules/session/policy-core
        (only-in :yuanxu/module-system/schema/slot-contracts
                 yuanxu-contract-check-slot!
                 yuanxu-contract-slot
                 yuanxu-contract-value-type
                 yuanxu-native-contract
                 yuanxu-native-contract->alist))

(export PooFlowSessionToolGrantContract
        poo-flow-session-tool-grant
        poo-flow-session-tool-grant?
        poo-flow-session-tool-grant-type-contract->alist
        poo-flow-session-tool-grant-check-slot!
        poo-flow-session-tool-grant-require-slots!
        poo-flow-session-tool-grant-id
        poo-flow-session-tool-grant-tool-ref
        poo-flow-session-tool-grant-actions
        poo-flow-session-tool-grant-resource-refs
        poo-flow-session-tool-grant-trigger-refs
        poo-flow-session-tool-grant-allows?
        poo-flow-session-tool-grants-allow?)

;; : (-> Symbol Symbol [Symbol] [Symbol/String] [Symbol] [Alist] PooSessionToolGrant)
(def (poo-flow-session-tool-grant grant-id
                                  tool-ref
                                  actions
                                  resource-refs
                                  trigger-refs
                                  . maybe-metadata)
  (poo-flow-session-require "session tool grant id must be a symbol"
                            (symbol? grant-id)
                            grant-id)
  (poo-flow-session-require "session tool grant tool ref must be a symbol"
                            (symbol? tool-ref)
                            tool-ref)
  (poo-flow-session-require "session tool grant actions must be symbols"
                            (poo-flow-session-symbol-list? actions)
                            actions)
  (poo-flow-session-require
   "session tool grant resource refs must be symbols or strings"
   (poo-flow-session-policy-ref-list? resource-refs)
   resource-refs)
  (poo-flow-session-require "session tool grant trigger refs must be symbols"
                            (poo-flow-session-symbol-list? trigger-refs)
                            trigger-refs)
  (let (metadata (if (null? maybe-metadata) '() (car maybe-metadata)))
    (poo-flow-session-tool-grant-require-slots!
     'poo-flow.session.tool-grant
     'poo-flow.modules.session.tool-grant.v1
     grant-id
     tool-ref
     actions
     resource-refs
     trigger-refs
     metadata
     #f)
    (list
     (cons 'kind 'poo-flow.session.tool-grant)
     (cons 'schema 'poo-flow.modules.session.tool-grant.v1)
     (cons 'grant-id grant-id)
     (cons 'tool-ref tool-ref)
     (cons 'actions actions)
     (cons 'resource-refs resource-refs)
     (cons 'trigger-refs trigger-refs)
     (cons 'metadata metadata)
     (cons 'runtime-executed #f))))

;; : (-> Datum Boolean)
(def (poo-flow-session-tool-grant? value)
  (and (list? value)
       (eq? (poo-flow-session-alist-ref value 'kind #f)
            'poo-flow.session.tool-grant)))

;;; Boundary: generated tool-grant accessors keep the alist receipt API stable.
(def (poo-flow-session-tool-grant-id grant)
  (poo-flow-session-alist-ref grant 'grant-id #f))

(def (poo-flow-session-tool-grant-tool-ref grant)
  (poo-flow-session-alist-ref grant 'tool-ref #f))

(def (poo-flow-session-tool-grant-actions grant)
  (poo-flow-session-alist-ref grant 'actions '()))

(def (poo-flow-session-tool-grant-resource-refs grant)
  (poo-flow-session-alist-ref grant 'resource-refs '()))

(def (poo-flow-session-tool-grant-trigger-refs grant)
  (poo-flow-session-alist-ref grant 'trigger-refs '()))

(def PooFlowSessionToolGrantKindType
  (yuanxu-contract-value-type
   'SessionToolGrantKind poo-flow-session-tool-grant-kind-value? 'Symbol))
(def PooFlowSessionToolGrantSymbolType
  (yuanxu-contract-value-type 'Symbol symbol? 'Symbol))
(def PooFlowSessionToolGrantSymbolListType
  (yuanxu-contract-value-type
   '[Symbol] poo-flow-session-symbol-list? '[Symbol]))
(def PooFlowSessionToolGrantRefListType
  (yuanxu-contract-value-type
   '[Symbol/String] poo-flow-session-policy-ref-list? '[Symbol/String]))
(def PooFlowSessionToolGrantAlistType
  (yuanxu-contract-value-type
   'Alist poo-flow-session-policy-alist? 'Alist))
(def PooFlowSessionToolGrantBooleanType
  (yuanxu-contract-value-type
   'Boolean poo-flow-session-policy-boolean? 'Boolean))

(def (poo-flow-session-tool-grant-slot-contract key slot value-type)
  (yuanxu-contract-slot key slot value-type #t '()))

(def PooFlowSessionToolGrantKindSlot
  (poo-flow-session-tool-grant-slot-contract
   'session.tool-grant/kind 'kind PooFlowSessionToolGrantKindType))
(def PooFlowSessionToolGrantSchemaSlot
  (poo-flow-session-tool-grant-slot-contract
   'session.tool-grant/schema 'schema PooFlowSessionToolGrantSymbolType))
(def PooFlowSessionToolGrantIdSlot
  (poo-flow-session-tool-grant-slot-contract
   'session.tool-grant/grant-id 'grant-id PooFlowSessionToolGrantSymbolType))
(def PooFlowSessionToolGrantToolRefSlot
  (poo-flow-session-tool-grant-slot-contract
   'session.tool-grant/tool-ref 'tool-ref PooFlowSessionToolGrantSymbolType))
(def PooFlowSessionToolGrantActionsSlot
  (poo-flow-session-tool-grant-slot-contract
   'session.tool-grant/actions 'actions PooFlowSessionToolGrantSymbolListType))
(def PooFlowSessionToolGrantResourceRefsSlot
  (poo-flow-session-tool-grant-slot-contract
   'session.tool-grant/resource-refs
   'resource-refs
   PooFlowSessionToolGrantRefListType))
(def PooFlowSessionToolGrantTriggerRefsSlot
  (poo-flow-session-tool-grant-slot-contract
   'session.tool-grant/trigger-refs
   'trigger-refs
   PooFlowSessionToolGrantSymbolListType))
(def PooFlowSessionToolGrantMetadataSlot
  (poo-flow-session-tool-grant-slot-contract
   'session.tool-grant/metadata 'metadata PooFlowSessionToolGrantAlistType))
(def PooFlowSessionToolGrantRuntimeExecutedSlot
  (poo-flow-session-tool-grant-slot-contract
   'session.tool-grant/runtime-executed
   'runtime-executed
   PooFlowSessionToolGrantBooleanType))

(def PooFlowSessionToolGrantSlots
  (list PooFlowSessionToolGrantKindSlot
        PooFlowSessionToolGrantSchemaSlot
        PooFlowSessionToolGrantIdSlot
        PooFlowSessionToolGrantToolRefSlot
        PooFlowSessionToolGrantActionsSlot
        PooFlowSessionToolGrantResourceRefsSlot
        PooFlowSessionToolGrantTriggerRefsSlot
        PooFlowSessionToolGrantMetadataSlot
        PooFlowSessionToolGrantRuntimeExecutedSlot))

(def PooFlowSessionToolGrantContract
  (yuanxu-native-contract
   'session/tool-grant
   'session
   'PooSessionToolGrant
   poo-flow-session-tool-grant?
   PooFlowSessionToolGrantSlots
   (lambda (grant slot) (if (assoc slot grant) #t #f))
   (lambda (grant slot) (poo-flow-session-alist-ref grant slot #f))
   '((boundary . session-policy) (runtime . marlin-agent-core))))

;; poo-flow-session-tool-grant-type-contract->alist
;;   | contract: adjacent machine contract below defines the projection.
;;   | doc m%
;;       Project the structured contract for session tool grant rows.
;;       # Examples
;;       (poo-flow-session-tool-grant-type-contract->alist)
;;       # Result
;;       An alist representation suitable for policy diagnostics.
;;     %
;; : (-> Unit Alist)
(def (poo-flow-session-tool-grant-type-contract->alist)
  (yuanxu-native-contract->alist PooFlowSessionToolGrantContract))

;; : (-> YuanxuSlotContract PooFlowValue PooFlowValue)
(def (poo-flow-session-tool-grant-check-slot! contract value)
  (yuanxu-contract-check-slot! contract value))

;; poo-flow-session-tool-grant-require-slots!
;;   | contract: adjacent machine contract below defines the tool grant gate.
;;   | doc m%
;;       Enforce generated slot contracts for one tool grant row. Tool execution
;;       remains outside Scheme; this gate only validates authorization data.
;;       # Examples
;;       (poo-flow-session-tool-grant-require-slots!
;;        'poo-flow.session.tool-grant schema grant tool actions resources triggers '() #f)
;;       # Result
;;       #t when every grant slot satisfies its contract.
;;     %
;; : (-> Symbol Symbol Symbol Symbol [Symbol] [Symbol/String] [Symbol] Alist Boolean Boolean)
(def (poo-flow-session-tool-grant-require-slots! kind
                                                 schema
                                                 grant-id
                                                 tool-ref
                                                 actions
                                                 resource-refs
                                                 trigger-refs
                                                 metadata
                                                 runtime-executed?)
  (poo-flow-session-tool-grant-check-slot!
   PooFlowSessionToolGrantKindSlot
   kind)
  (poo-flow-session-tool-grant-check-slot!
   PooFlowSessionToolGrantSchemaSlot
   schema)
  (poo-flow-session-tool-grant-check-slot!
   PooFlowSessionToolGrantIdSlot
   grant-id)
  (poo-flow-session-tool-grant-check-slot!
   PooFlowSessionToolGrantToolRefSlot
   tool-ref)
  (poo-flow-session-tool-grant-check-slot!
   PooFlowSessionToolGrantActionsSlot
   actions)
  (poo-flow-session-tool-grant-check-slot!
   PooFlowSessionToolGrantResourceRefsSlot
   resource-refs)
  (poo-flow-session-tool-grant-check-slot!
   PooFlowSessionToolGrantTriggerRefsSlot
   trigger-refs)
  (poo-flow-session-tool-grant-check-slot!
   PooFlowSessionToolGrantMetadataSlot
   metadata)
  (poo-flow-session-tool-grant-check-slot!
   PooFlowSessionToolGrantRuntimeExecutedSlot
   runtime-executed?)
  #t)

;; : (-> PooSessionToolGrant Symbol Symbol Boolean)
(def (poo-flow-session-tool-grant-allows? grant tool-ref action)
  (and (poo-flow-session-tool-grant? grant)
       (poo-flow-session-policy-match?
        tool-ref
        (list (poo-flow-session-tool-grant-tool-ref grant)))
       (poo-flow-session-policy-match?
        action
        (poo-flow-session-tool-grant-actions grant))))

;; : (-> [PooSessionToolGrant] Symbol Symbol Boolean)
(def (poo-flow-session-tool-grants-allow? grants tool-ref action)
  (cond
   ((null? grants) #f)
   ((poo-flow-session-tool-grant-allows? (car grants) tool-ref action) #t)
   (else
    (poo-flow-session-tool-grants-allow? (cdr grants) tool-ref action))))
