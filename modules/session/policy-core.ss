;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: core session policy object shape, projection, and contracts.

(import (only-in :clan/poo/object .o .ref .slot? object? object<-alist)
        :poo-flow/modules/ai-agentic-context/features/memory/durable/policy
        :poo-flow/modules/session/objects
        :poo-flow/modules/session/policy-syntax
        (only-in :yuanxu/module-system/schema/slot-contracts
                 yuanxu-contract-check-slot!
                 yuanxu-contract-slot
                 yuanxu-contract-value-type
                 yuanxu-native-contract
                 yuanxu-native-contract->alist))

(export poo-flow-session-policy-ref?
        poo-flow-session-policy-alist?
        poo-flow-session-policy-ref-list?
        poo-flow-session-symbol-list?
        poo-flow-session-policy-kind-value?
        poo-flow-session-tool-grant-kind-value?
        poo-flow-session-policy-runtime-owner?
        poo-flow-session-policy-boolean?
        poo-flow-session-policy-member?
        poo-flow-session-policy-match?
        poo-flow-session-policy-slot
        poo-flow-session-policy?
        poo-flow-session-policy-kind
        poo-flow-session-policy-name
        poo-flow-session-policy-scope-ref
        poo-flow-session-policy-default-action
        poo-flow-session-policy-attach-durable
        poo-flow-session-policy-durable-receipt
        poo-flow-session-policy-durable-rows
        poo-flow-session-policy-fast-policy?
        poo-flow-session-policy-slot-row
        poo-flow-session-policy->alist
        poo-flow-session-policy-rows/tail
        poo-flow-session-policy-slots/tail
        poo-flow-session-policy-object-rows
        poo-flow-session-policy-object
        PooFlowSessionPolicyContract
        poo-flow-session-policy-type-contract->alist
        poo-flow-session-policy-check-slot!
        poo-flow-session-policy-require-slots!)

;; : (-> Datum Boolean)
(def (poo-flow-session-policy-ref? value)
  (or (symbol? value) (string? value)))

;; : (-> Datum Boolean)
(def (poo-flow-session-policy-alist? value)
  (and (list? value)
       (andmap pair? value)))

;; : (-> Datum Boolean)
(def (poo-flow-session-policy-ref-list? values)
  (and (list? values)
       (poo-flow-session-every? poo-flow-session-policy-ref? values)))

;; : (-> Datum Boolean)
(def (poo-flow-session-symbol-list? values)
  (and (list? values)
       (poo-flow-session-every? symbol? values)))

;; : (-> Datum Boolean)
(def (poo-flow-session-policy-kind-value? value)
  (eq? value 'poo-flow.session.policy))

;; : (-> Datum Boolean)
(def (poo-flow-session-tool-grant-kind-value? value)
  (eq? value 'poo-flow.session.tool-grant))

;; : (-> Datum Boolean)
(def (poo-flow-session-policy-runtime-owner? value)
  (or (string? value) (symbol? value)))

;; : (-> Datum Boolean)
(def (poo-flow-session-policy-boolean? value)
  (boolean? value))

;; : (-> Datum List Boolean)
(def (poo-flow-session-policy-member? value values)
  (if (member value values) #t #f))

;; : (-> Datum List Boolean)
(def (poo-flow-session-policy-match? value values)
  (or (poo-flow-session-policy-member? value values)
      (poo-flow-session-policy-member? '* values)))

;; : (-> POOObject Symbol Value Value)
(def (poo-flow-session-policy-slot policy key default)
  (with-catch
   (lambda (_failure) default)
   (lambda ()
     (.ref policy key))))

;; : (-> POOObject Boolean)
(def (poo-flow-session-policy? value)
  (and (object? value)
       (eq? (poo-flow-session-policy-slot value 'kind #f)
            'poo-flow.session.policy)))

;;; Generated slot accessors for the stable POO session policy shape.
(def (poo-flow-session-policy-kind policy)
  (poo-flow-session-policy-slot policy 'policy-kind #f))

(def (poo-flow-session-policy-name policy)
  (poo-flow-session-policy-slot policy 'policy-name #f))

(def (poo-flow-session-policy-scope-ref policy)
  (poo-flow-session-policy-slot policy 'scope-ref #f))

(def (poo-flow-session-policy-default-action policy)
  (poo-flow-session-policy-slot policy 'default-action 'deny))

;; : (-> PooSessionPolicy PooDurablePolicy PooSessionPolicy)
(def (poo-flow-session-policy-attach-durable policy durable-policy)
  (poo-flow-session-require "session durable attach requires a session policy"
                            (poo-flow-session-policy? policy)
                            policy)
  (poo-flow-session-require "session durable attach requires a durable policy"
                            (poo-flow-durable-policy? durable-policy)
                            durable-policy)
  (.o (:: @ [policy durable-policy])))

;; : (-> PooSessionPolicy [Alist] MaybePooDurablePolicyReceipt)
(def (poo-flow-session-policy-durable-receipt policy . maybe-identity)
  (if (poo-flow-durable-policy? policy)
    (apply poo-flow-durable-policy->receipt policy maybe-identity)
    #f))

;; : Alist
(def +poo-flow-session-policy-no-durable-rows+
  '((durable-policy . #f)
    (durable-policy-ref . #f)
    (durable-valid? . #f)
    (durable-diagnostic-count . 0)))

;; : (-> PooSessionPolicy Alist)
(def (poo-flow-session-policy-durable-rows policy)
  (let (receipt (poo-flow-session-policy-durable-receipt policy))
    (if receipt
      (list
       (cons 'durable-policy
             (poo-flow-durable-policy-receipt->alist receipt))
       (cons 'durable-policy-ref
             (poo-flow-durable-policy-receipt-policy-id receipt))
       (cons 'durable-valid?
             (poo-flow-durable-policy-receipt-valid? receipt))
       (cons 'durable-diagnostic-count
             (length
              (poo-flow-durable-policy-receipt-diagnostics receipt))))
      +poo-flow-session-policy-no-durable-rows+)))

;; : (-> Datum Boolean)
(def (poo-flow-session-policy-fast-policy? value)
  (and (object? value)
       (.slot? value 'kind)
       (eq? (.ref value 'kind) 'poo-flow.session.policy)))

;; : (-> Alist Symbol Value Value)
(def (poo-flow-session-policy-slot-row policy-slots key default)
  (poo-flow-session-alist-ref policy-slots key default))

;;; Boundary: session policy serialization is the bounded projection from POO
;;; policy objects into manifests and test receipts.
;; : (-> PooSessionPolicy Alist)
(def (poo-flow-session-policy->alist policy)
  (poo-flow-session-require
   "session policy projection requires a policy"
   (poo-flow-session-policy-fast-policy? policy)
   policy)
  (let* ((policy-slots
          (.ref policy 'policy-slots))
         (tool-grants
          (poo-flow-session-policy-slot-row policy-slots
                                            'tool-grants
                                            '())))
    (poo-flow-session-policy-rows/tail
     (list
      (cons 'kind (.ref policy 'kind))
      (cons 'schema (.ref policy 'schema))
      (cons 'policy-kind (.ref policy 'policy-kind))
      (cons 'policy-name (.ref policy 'policy-name))
      (cons 'scope-ref (.ref policy 'scope-ref))
      (cons 'default-action (.ref policy 'default-action))
      (cons 'policy-slots policy-slots)
      (cons 'agent-ref
            (poo-flow-session-policy-slot-row policy-slots 'agent-ref #f))
      (cons 'session-ref
            (poo-flow-session-policy-slot-row policy-slots 'session-ref #f))
      (cons 'provider-ref
            (poo-flow-session-policy-slot-row policy-slots 'provider-ref #f))
      (cons 'model-ref
            (poo-flow-session-policy-slot-row policy-slots 'model-ref #f))
      (cons 'prompt-session-ref
            (poo-flow-session-policy-slot-row
             policy-slots
             'prompt-session-ref
             #f))
      (cons 'prompt-chunk-refs
            (poo-flow-session-policy-slot-row
             policy-slots
             'prompt-chunk-refs
             '()))
      (cons 'context-mode
            (poo-flow-session-policy-slot-row
             policy-slots
             'context-mode
             'isolated))
      (cons 'model-policy-ref
            (poo-flow-session-policy-slot-row
             policy-slots
             'model-policy-ref
             #f))
      (cons 'prompt-policy-ref
            (poo-flow-session-policy-slot-row
             policy-slots
             'prompt-policy-ref
             #f))
      (cons 'tool-policy-ref
            (poo-flow-session-policy-slot-row
             policy-slots
             'tool-policy-ref
             #f))
      (cons 'hook-policy-ref
            (poo-flow-session-policy-slot-row
             policy-slots
             'hook-policy-ref
             #f))
      (cons 'context-policy-ref
            (poo-flow-session-policy-slot-row
             policy-slots
             'context-policy-ref
             #f))
      (cons 'resource-policy-ref
            (poo-flow-session-policy-slot-row
             policy-slots
             'resource-policy-ref
             #f))
      (cons 'tool-grants tool-grants)
      (cons 'tool-grant-count (length tool-grants))
      (cons 'denied-tool-refs
            (poo-flow-session-policy-slot-row
             policy-slots
             'denied-tool-refs
             '()))
      (cons 'hook-events
            (poo-flow-session-policy-slot-row policy-slots
                                              'hook-events
                                              '()))
      (cons 'resource-grants
            (poo-flow-session-policy-slot-row
             policy-slots
             'resource-grants
             '()))
      (cons 'metadata (.ref policy 'metadata))
      (cons 'runtime-owner (.ref policy 'runtime-owner))
      (cons 'runtime-executed (.ref policy 'runtime-executed)))
     (poo-flow-session-policy-durable-rows policy))))

;; : (forall (a) (-> (List a) (List a) (List a)))
;; : (-> Alist Alist Alist)
(def (poo-flow-session-policy-rows/tail rows tail)
  (foldr cons tail rows))

;; : (-> Alist Alist Alist)
(def (poo-flow-session-policy-slots/tail policy-slots tail)
  (poo-flow-session-policy-rows/tail policy-slots tail))

;; : (-> Symbol Symbol Symbol Symbol Symbol Alist Alist Alist)
(def (poo-flow-session-policy-object-rows policy-kind
                                          schema
                                          policy-name
                                          scope-ref
                                          default-action
                                          policy-slots
                                          metadata)
  (poo-flow-session-policy-rows/tail
   (list
    (cons 'kind 'poo-flow.session.policy)
    (cons 'schema schema)
    (cons 'policy-kind policy-kind)
    (cons 'policy-name policy-name)
    (cons 'scope-ref scope-ref)
    (cons 'default-action default-action)
    (cons 'policy-slots policy-slots))
   (poo-flow-session-policy-slots/tail
    policy-slots
    (list
     (cons 'metadata metadata)
     (cons 'runtime-owner "marlin-agent-core")
     (cons 'runtime-executed #f)))))

;; : (-> Symbol Symbol Symbol Symbol Symbol Alist [Alist] PooSessionPolicy)
(def (poo-flow-session-policy-object policy-kind
                                     schema
                                     policy-name
                                     scope-ref
                                     default-action
                                     policy-slots
                                     . maybe-metadata)
  (poo-flow-session-require "session policy kind must be a symbol"
                            (symbol? policy-kind)
                            policy-kind)
  (poo-flow-session-require "session policy schema must be a symbol"
                            (symbol? schema)
                            schema)
  (poo-flow-session-require "session policy name must be a symbol"
                            (symbol? policy-name)
                            policy-name)
  (poo-flow-session-require "session policy scope ref must be a symbol"
                            (symbol? scope-ref)
                            scope-ref)
  (poo-flow-session-require "session policy default action must be a symbol"
                            (symbol? default-action)
                            default-action)
  (poo-flow-session-require "session policy slots must be an alist"
                            (list? policy-slots)
                            policy-slots)
  (let (metadata (if (null? maybe-metadata)
                   '()
                   (car maybe-metadata)))
    (poo-flow-session-policy-require-slots!
     'poo-flow.session.policy
     schema
     policy-kind
     policy-name
     scope-ref
     default-action
     policy-slots
     metadata
     "marlin-agent-core"
     #f)
    (object<-alist
     (poo-flow-session-policy-object-rows
      policy-kind
      schema
      policy-name
      scope-ref
      default-action
      policy-slots
      metadata))))

(def PooFlowSessionPolicyKindType
  (yuanxu-contract-value-type
   'SessionPolicyKind poo-flow-session-policy-kind-value? 'Symbol))
(def PooFlowSessionSymbolType
  (yuanxu-contract-value-type 'Symbol symbol? 'Symbol))
(def PooFlowSessionAlistType
  (yuanxu-contract-value-type
   'Alist poo-flow-session-policy-alist? 'Alist))
(def PooFlowSessionRuntimeOwnerType
  (yuanxu-contract-value-type
   'RuntimeOwner poo-flow-session-policy-runtime-owner? 'RuntimeOwner))
(def PooFlowSessionBooleanType
  (yuanxu-contract-value-type
   'Boolean poo-flow-session-policy-boolean? 'Boolean))

(def (poo-flow-session-policy-slot-contract key slot value-type)
  (yuanxu-contract-slot key slot value-type #t '()))

(def PooFlowSessionPolicyKindSlot
  (poo-flow-session-policy-slot-contract
   'session.policy/kind 'kind PooFlowSessionPolicyKindType))
(def PooFlowSessionPolicySchemaSlot
  (poo-flow-session-policy-slot-contract
   'session.policy/schema 'schema PooFlowSessionSymbolType))
(def PooFlowSessionPolicyPolicyKindSlot
  (poo-flow-session-policy-slot-contract
   'session.policy/policy-kind 'policy-kind PooFlowSessionSymbolType))
(def PooFlowSessionPolicyNameSlot
  (poo-flow-session-policy-slot-contract
   'session.policy/policy-name 'policy-name PooFlowSessionSymbolType))
(def PooFlowSessionPolicyScopeRefSlot
  (poo-flow-session-policy-slot-contract
   'session.policy/scope-ref 'scope-ref PooFlowSessionSymbolType))
(def PooFlowSessionPolicyDefaultActionSlot
  (poo-flow-session-policy-slot-contract
   'session.policy/default-action 'default-action PooFlowSessionSymbolType))
(def PooFlowSessionPolicySlotsSlot
  (poo-flow-session-policy-slot-contract
   'session.policy/policy-slots 'policy-slots PooFlowSessionAlistType))
(def PooFlowSessionPolicyMetadataSlot
  (poo-flow-session-policy-slot-contract
   'session.policy/metadata 'metadata PooFlowSessionAlistType))
(def PooFlowSessionPolicyRuntimeOwnerSlot
  (poo-flow-session-policy-slot-contract
   'session.policy/runtime-owner 'runtime-owner PooFlowSessionRuntimeOwnerType))
(def PooFlowSessionPolicyRuntimeExecutedSlot
  (poo-flow-session-policy-slot-contract
   'session.policy/runtime-executed 'runtime-executed PooFlowSessionBooleanType))

(def PooFlowSessionPolicySlots
  (list PooFlowSessionPolicyKindSlot
        PooFlowSessionPolicySchemaSlot
        PooFlowSessionPolicyPolicyKindSlot
        PooFlowSessionPolicyNameSlot
        PooFlowSessionPolicyScopeRefSlot
        PooFlowSessionPolicyDefaultActionSlot
        PooFlowSessionPolicySlotsSlot
        PooFlowSessionPolicyMetadataSlot
        PooFlowSessionPolicyRuntimeOwnerSlot
        PooFlowSessionPolicyRuntimeExecutedSlot))

(def PooFlowSessionPolicyContract
  (yuanxu-native-contract
   'session/policy
   'session
   'PooSessionPolicy
   poo-flow-session-policy?
   PooFlowSessionPolicySlots
   (lambda (policy slot) (and (object? policy) (.slot? policy slot)))
   (lambda (policy slot) (.ref policy slot))
   '((boundary . session-policy) (runtime . marlin-agent-core))))

;; poo-flow-session-policy-type-contract->alist
;;   | contract: adjacent machine contract below defines the projection.
;;   | doc m%
;;       Project the structured contract for POO session policy objects.
;;       # Examples
;;       (poo-flow-session-policy-type-contract->alist)
;;       # Result
;;       An alist representation suitable for doctor, type facts, and manifests.
;;     %
;; : (-> Unit Alist)
(def (poo-flow-session-policy-type-contract->alist)
  (yuanxu-native-contract->alist PooFlowSessionPolicyContract))

;; : (-> YuanxuSlotContract PooFlowValue PooFlowValue)
(def (poo-flow-session-policy-check-slot! contract value)
  (yuanxu-contract-check-slot! contract value))

;; poo-flow-session-policy-require-slots!
;;   | contract: adjacent machine contract below defines the session policy gate.
;;   | doc m%
;;       Enforce generated slot contracts for one session policy object before
;;       it crosses into projection, doctor, or runtime manifest code.
;;       # Examples
;;       (poo-flow-session-policy-require-slots!
;;        'poo-flow.session.policy schema kind name scope action slots '()
;;        "marlin-agent-core" #f)
;;       # Result
;;       #t when every slot satisfies its contract.
;;     %
;; : (-> Symbol Symbol Symbol Symbol Symbol Symbol Alist Alist PooRuntimeOwner Boolean Boolean)
(def (poo-flow-session-policy-require-slots! kind
                                             schema
                                             policy-kind
                                             policy-name
                                             scope-ref
                                             default-action
                                             policy-slots
                                             metadata
                                             runtime-owner
                                             runtime-executed?)
  (poo-flow-session-policy-check-slot!
   PooFlowSessionPolicyKindSlot
   kind)
  (poo-flow-session-policy-check-slot!
   PooFlowSessionPolicySchemaSlot
   schema)
  (poo-flow-session-policy-check-slot!
   PooFlowSessionPolicyPolicyKindSlot
   policy-kind)
  (poo-flow-session-policy-check-slot!
   PooFlowSessionPolicyNameSlot
   policy-name)
  (poo-flow-session-policy-check-slot!
   PooFlowSessionPolicyScopeRefSlot
   scope-ref)
  (poo-flow-session-policy-check-slot!
   PooFlowSessionPolicyDefaultActionSlot
   default-action)
  (poo-flow-session-policy-check-slot!
   PooFlowSessionPolicySlotsSlot
   policy-slots)
  (poo-flow-session-policy-check-slot!
   PooFlowSessionPolicyMetadataSlot
   metadata)
  (poo-flow-session-policy-check-slot!
   PooFlowSessionPolicyRuntimeOwnerSlot
   runtime-owner)
  (poo-flow-session-policy-check-slot!
   PooFlowSessionPolicyRuntimeExecutedSlot
   runtime-executed?)
  #t)
