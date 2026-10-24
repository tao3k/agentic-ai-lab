;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: core session policy object shape, projection, and contracts.

(import (only-in :clan/poo/object .o .ref .slot? object? object<-alist)
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/policy-syntax
        (only-in :yuanxu/module-system/schema/slot-contracts
                 yuanxu-contract-check-slot!
                 yuanxu-contract-slot
                 yuanxu-contract-value-type
                 yuanxu-object-contract
                 yuanxu-object-contract->alist))

(export agentic-ai-lab-session-policy-ref?
        agentic-ai-lab-session-policy-alist?
        agentic-ai-lab-session-policy-ref-list?
        agentic-ai-lab-session-symbol-list?
        agentic-ai-lab-session-policy-kind-value?
        agentic-ai-lab-session-tool-grant-kind-value?
        agentic-ai-lab-session-policy-runtime-owner?
        agentic-ai-lab-session-policy-boolean?
        agentic-ai-lab-session-policy-member?
        agentic-ai-lab-session-policy-match?
        agentic-ai-lab-session-policy-slot
        agentic-ai-lab-session-policy?
        agentic-ai-lab-session-policy-kind
        agentic-ai-lab-session-policy-name
        agentic-ai-lab-session-policy-scope-ref
        agentic-ai-lab-session-policy-default-action
        agentic-ai-lab-session-policy-attach-durable
        agentic-ai-lab-session-policy-durable-receipt
        agentic-ai-lab-session-policy-durable-rows
        agentic-ai-lab-session-policy-fast-policy?
        agentic-ai-lab-session-policy-slot-row
        agentic-ai-lab-session-policy->alist
        agentic-ai-lab-session-policy-rows/tail
        agentic-ai-lab-session-policy-slots/tail
        agentic-ai-lab-session-policy-object-rows
        agentic-ai-lab-session-policy-object
        AgenticAILabSessionPolicyContract
        agentic-ai-lab-session-policy-type-contract->alist
        agentic-ai-lab-session-policy-check-slot!
        agentic-ai-lab-session-policy-require-slots!)

;; : (-> Datum Boolean)
(def (agentic-ai-lab-session-policy-ref? value)
  (or (symbol? value) (string? value)))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-session-policy-alist? value)
  (and (list? value)
       (andmap pair? value)))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-session-policy-ref-list? values)
  (and (list? values)
       (agentic-ai-lab-session-every? agentic-ai-lab-session-policy-ref? values)))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-session-symbol-list? values)
  (and (list? values)
       (agentic-ai-lab-session-every? symbol? values)))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-session-policy-kind-value? value)
  (eq? value 'agentic-ai-lab.session.policy))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-session-tool-grant-kind-value? value)
  (eq? value 'agentic-ai-lab.session.tool-grant))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-session-policy-runtime-owner? value)
  (or (string? value) (symbol? value)))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-session-policy-boolean? value)
  (boolean? value))

;; : (-> Datum List Boolean)
(def (agentic-ai-lab-session-policy-member? value values)
  (if (member value values) #t #f))

;; : (-> Datum List Boolean)
(def (agentic-ai-lab-session-policy-match? value values)
  (or (agentic-ai-lab-session-policy-member? value values)
      (agentic-ai-lab-session-policy-member? '* values)))

;; : (-> POOObject Symbol Value Value)
(def (agentic-ai-lab-session-policy-slot policy key default)
  (with-catch
   (lambda (_failure) default)
   (lambda ()
     (.ref policy key))))

;; : (-> POOObject Boolean)
(def (agentic-ai-lab-session-policy? value)
  (and (object? value)
       (eq? (agentic-ai-lab-session-policy-slot value 'kind #f)
            'agentic-ai-lab.session.policy)))

;;; Generated slot accessors for the stable POO session policy shape.
(def (agentic-ai-lab-session-policy-kind policy)
  (agentic-ai-lab-session-policy-slot policy 'policy-kind #f))

(def (agentic-ai-lab-session-policy-name policy)
  (agentic-ai-lab-session-policy-slot policy 'policy-name #f))

(def (agentic-ai-lab-session-policy-scope-ref policy)
  (agentic-ai-lab-session-policy-slot policy 'scope-ref #f))

(def (agentic-ai-lab-session-policy-default-action policy)
  (agentic-ai-lab-session-policy-slot policy 'default-action 'deny))

;; : (-> PooSessionPolicy PooDurablePolicy PooSessionPolicy)
(def (agentic-ai-lab-session-policy-attach-durable policy durable-policy)
  (agentic-ai-lab-session-require "session durable attach requires a session policy"
                            (agentic-ai-lab-session-policy? policy)
                            policy)
  (agentic-ai-lab-session-require "session durable attach requires a durable policy"
                            (agentic-ai-lab-durable-policy? durable-policy)
                            durable-policy)
  (.o (:: @ [policy durable-policy])))

;; : (-> PooSessionPolicy [Alist] MaybePooDurablePolicyReceipt)
(def (agentic-ai-lab-session-policy-durable-receipt policy . maybe-identity)
  (if (agentic-ai-lab-durable-policy? policy)
    (apply agentic-ai-lab-durable-policy->receipt policy maybe-identity)
    #f))

;; : Alist
(def +agentic-ai-lab-session-policy-no-durable-rows+
  '((durable-policy . #f)
    (durable-policy-ref . #f)
    (durable-valid? . #f)
    (durable-diagnostic-count . 0)))

;; : (-> PooSessionPolicy Alist)
(def (agentic-ai-lab-session-policy-durable-rows policy)
  (let (receipt (agentic-ai-lab-session-policy-durable-receipt policy))
    (if receipt
      (list
       (cons 'durable-policy
             (agentic-ai-lab-durable-policy-receipt->alist receipt))
       (cons 'durable-policy-ref
             (agentic-ai-lab-durable-policy-receipt-policy-id receipt))
       (cons 'durable-valid?
             (agentic-ai-lab-durable-policy-receipt-valid? receipt))
       (cons 'durable-diagnostic-count
             (length
              (agentic-ai-lab-durable-policy-receipt-diagnostics receipt))))
      +agentic-ai-lab-session-policy-no-durable-rows+)))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-session-policy-fast-policy? value)
  (and (object? value)
       (.slot? value 'kind)
       (eq? (.ref value 'kind) 'agentic-ai-lab.session.policy)))

;; : (-> Alist Symbol Value Value)
(def (agentic-ai-lab-session-policy-slot-row policy-slots key default)
  (agentic-ai-lab-session-alist-ref policy-slots key default))

;;; Boundary: session policy serialization is the bounded projection from POO
;;; policy objects into manifests and test receipts.
;; : (-> PooSessionPolicy Alist)
(def (agentic-ai-lab-session-policy->alist policy)
  (agentic-ai-lab-session-require
   "session policy projection requires a policy"
   (agentic-ai-lab-session-policy-fast-policy? policy)
   policy)
  (let* ((policy-slots
          (.ref policy 'policy-slots))
         (tool-grants
          (agentic-ai-lab-session-policy-slot-row policy-slots
                                            'tool-grants
                                            '())))
    (agentic-ai-lab-session-policy-rows/tail
     (list
      (cons 'kind (.ref policy 'kind))
      (cons 'schema (.ref policy 'schema))
      (cons 'policy-kind (.ref policy 'policy-kind))
      (cons 'policy-name (.ref policy 'policy-name))
      (cons 'scope-ref (.ref policy 'scope-ref))
      (cons 'default-action (.ref policy 'default-action))
      (cons 'policy-slots policy-slots)
      (cons 'agent-ref
            (agentic-ai-lab-session-policy-slot-row policy-slots 'agent-ref #f))
      (cons 'session-ref
            (agentic-ai-lab-session-policy-slot-row policy-slots 'session-ref #f))
      (cons 'provider-ref
            (agentic-ai-lab-session-policy-slot-row policy-slots 'provider-ref #f))
      (cons 'model-ref
            (agentic-ai-lab-session-policy-slot-row policy-slots 'model-ref #f))
      (cons 'prompt-session-ref
            (agentic-ai-lab-session-policy-slot-row
             policy-slots
             'prompt-session-ref
             #f))
      (cons 'prompt-chunk-refs
            (agentic-ai-lab-session-policy-slot-row
             policy-slots
             'prompt-chunk-refs
             '()))
      (cons 'context-mode
            (agentic-ai-lab-session-policy-slot-row
             policy-slots
             'context-mode
             'isolated))
      (cons 'model-policy-ref
            (agentic-ai-lab-session-policy-slot-row
             policy-slots
             'model-policy-ref
             #f))
      (cons 'prompt-policy-ref
            (agentic-ai-lab-session-policy-slot-row
             policy-slots
             'prompt-policy-ref
             #f))
      (cons 'tool-policy-ref
            (agentic-ai-lab-session-policy-slot-row
             policy-slots
             'tool-policy-ref
             #f))
      (cons 'hook-policy-ref
            (agentic-ai-lab-session-policy-slot-row
             policy-slots
             'hook-policy-ref
             #f))
      (cons 'context-policy-ref
            (agentic-ai-lab-session-policy-slot-row
             policy-slots
             'context-policy-ref
             #f))
      (cons 'resource-policy-ref
            (agentic-ai-lab-session-policy-slot-row
             policy-slots
             'resource-policy-ref
             #f))
      (cons 'tool-grants tool-grants)
      (cons 'tool-grant-count (length tool-grants))
      (cons 'denied-tool-refs
            (agentic-ai-lab-session-policy-slot-row
             policy-slots
             'denied-tool-refs
             '()))
      (cons 'hook-events
            (agentic-ai-lab-session-policy-slot-row policy-slots
                                              'hook-events
                                              '()))
      (cons 'resource-grants
            (agentic-ai-lab-session-policy-slot-row
             policy-slots
             'resource-grants
             '()))
      (cons 'metadata (.ref policy 'metadata))
      (cons 'runtime-owner (.ref policy 'runtime-owner))
      (cons 'runtime-executed (.ref policy 'runtime-executed)))
     (agentic-ai-lab-session-policy-durable-rows policy))))

;; : (forall (a) (-> (List a) (List a) (List a)))
;; : (-> Alist Alist Alist)
(def (agentic-ai-lab-session-policy-rows/tail rows tail)
  (foldr cons tail rows))

;; : (-> Alist Alist Alist)
(def (agentic-ai-lab-session-policy-slots/tail policy-slots tail)
  (agentic-ai-lab-session-policy-rows/tail policy-slots tail))

;; : (-> Symbol Symbol Symbol Symbol Symbol Alist Alist Alist)
(def (agentic-ai-lab-session-policy-object-rows policy-kind
                                          schema
                                          policy-name
                                          scope-ref
                                          default-action
                                          policy-slots
                                          metadata)
  (agentic-ai-lab-session-policy-rows/tail
   (list
    (cons 'kind 'agentic-ai-lab.session.policy)
    (cons 'schema schema)
    (cons 'policy-kind policy-kind)
    (cons 'policy-name policy-name)
    (cons 'scope-ref scope-ref)
    (cons 'default-action default-action)
    (cons 'policy-slots policy-slots))
   (agentic-ai-lab-session-policy-slots/tail
    policy-slots
    (list
     (cons 'metadata metadata)
     (cons 'runtime-owner "marlin-agent-core")
     (cons 'runtime-executed #f)))))

;; : (-> Symbol Symbol Symbol Symbol Symbol Alist [Alist] PooSessionPolicy)
(def (agentic-ai-lab-session-policy-object policy-kind
                                     schema
                                     policy-name
                                     scope-ref
                                     default-action
                                     policy-slots
                                     . maybe-metadata)
  (agentic-ai-lab-session-require "session policy kind must be a symbol"
                            (symbol? policy-kind)
                            policy-kind)
  (agentic-ai-lab-session-require "session policy schema must be a symbol"
                            (symbol? schema)
                            schema)
  (agentic-ai-lab-session-require "session policy name must be a symbol"
                            (symbol? policy-name)
                            policy-name)
  (agentic-ai-lab-session-require "session policy scope ref must be a symbol"
                            (symbol? scope-ref)
                            scope-ref)
  (agentic-ai-lab-session-require "session policy default action must be a symbol"
                            (symbol? default-action)
                            default-action)
  (agentic-ai-lab-session-require "session policy slots must be an alist"
                            (list? policy-slots)
                            policy-slots)
  (let (metadata (if (null? maybe-metadata)
                   '()
                   (car maybe-metadata)))
    (agentic-ai-lab-session-policy-require-slots!
     'agentic-ai-lab.session.policy
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
     (agentic-ai-lab-session-policy-object-rows
      policy-kind
      schema
      policy-name
      scope-ref
      default-action
      policy-slots
      metadata))))

(def AgenticAILabSessionPolicyKindType
  (yuanxu-contract-value-type
   'SessionPolicyKind agentic-ai-lab-session-policy-kind-value? 'Symbol))
(def AgenticAILabSessionSymbolType
  (yuanxu-contract-value-type 'Symbol symbol? 'Symbol))
(def AgenticAILabSessionAlistType
  (yuanxu-contract-value-type
   'Alist agentic-ai-lab-session-policy-alist? 'Alist))
(def AgenticAILabSessionRuntimeOwnerType
  (yuanxu-contract-value-type
   'RuntimeOwner agentic-ai-lab-session-policy-runtime-owner? 'RuntimeOwner))
(def AgenticAILabSessionBooleanType
  (yuanxu-contract-value-type
   'Boolean agentic-ai-lab-session-policy-boolean? 'Boolean))

(def (agentic-ai-lab-session-policy-slot-contract key slot value-type)
  (yuanxu-contract-slot key slot value-type #t '()))

(def AgenticAILabSessionPolicyKindSlot
  (agentic-ai-lab-session-policy-slot-contract
   'session.policy/kind 'kind AgenticAILabSessionPolicyKindType))
(def AgenticAILabSessionPolicySchemaSlot
  (agentic-ai-lab-session-policy-slot-contract
   'session.policy/schema 'schema AgenticAILabSessionSymbolType))
(def AgenticAILabSessionPolicyPolicyKindSlot
  (agentic-ai-lab-session-policy-slot-contract
   'session.policy/policy-kind 'policy-kind AgenticAILabSessionSymbolType))
(def AgenticAILabSessionPolicyNameSlot
  (agentic-ai-lab-session-policy-slot-contract
   'session.policy/policy-name 'policy-name AgenticAILabSessionSymbolType))
(def AgenticAILabSessionPolicyScopeRefSlot
  (agentic-ai-lab-session-policy-slot-contract
   'session.policy/scope-ref 'scope-ref AgenticAILabSessionSymbolType))
(def AgenticAILabSessionPolicyDefaultActionSlot
  (agentic-ai-lab-session-policy-slot-contract
   'session.policy/default-action 'default-action AgenticAILabSessionSymbolType))
(def AgenticAILabSessionPolicySlotsSlot
  (agentic-ai-lab-session-policy-slot-contract
   'session.policy/policy-slots 'policy-slots AgenticAILabSessionAlistType))
(def AgenticAILabSessionPolicyMetadataSlot
  (agentic-ai-lab-session-policy-slot-contract
   'session.policy/metadata 'metadata AgenticAILabSessionAlistType))
(def AgenticAILabSessionPolicyRuntimeOwnerSlot
  (agentic-ai-lab-session-policy-slot-contract
   'session.policy/runtime-owner 'runtime-owner AgenticAILabSessionRuntimeOwnerType))
(def AgenticAILabSessionPolicyRuntimeExecutedSlot
  (agentic-ai-lab-session-policy-slot-contract
   'session.policy/runtime-executed 'runtime-executed AgenticAILabSessionBooleanType))

(def AgenticAILabSessionPolicySlots
  (list AgenticAILabSessionPolicyKindSlot
        AgenticAILabSessionPolicySchemaSlot
        AgenticAILabSessionPolicyPolicyKindSlot
        AgenticAILabSessionPolicyNameSlot
        AgenticAILabSessionPolicyScopeRefSlot
        AgenticAILabSessionPolicyDefaultActionSlot
        AgenticAILabSessionPolicySlotsSlot
        AgenticAILabSessionPolicyMetadataSlot
        AgenticAILabSessionPolicyRuntimeOwnerSlot
        AgenticAILabSessionPolicyRuntimeExecutedSlot))

(def AgenticAILabSessionPolicyContract
  (yuanxu-object-contract
   'session/policy
   'session
   'PooSessionPolicy
   agentic-ai-lab-session-policy?
   AgenticAILabSessionPolicySlots
   '((boundary . session-policy) (runtime . marlin-agent-core))))

;; agentic-ai-lab-session-policy-type-contract->alist
;;   | contract: adjacent machine contract below defines the projection.
;;   | doc m%
;;       Project the structured contract for POO session policy objects.
;;       # Examples
;;       (agentic-ai-lab-session-policy-type-contract->alist)
;;       # Result
;;       An alist representation suitable for doctor, type facts, and manifests.
;;     %
;; : (-> Unit Alist)
(def (agentic-ai-lab-session-policy-type-contract->alist)
  (yuanxu-object-contract->alist AgenticAILabSessionPolicyContract))

;; : (-> YuanxuSlotContract AgenticAILabValue AgenticAILabValue)
(def (agentic-ai-lab-session-policy-check-slot! contract value)
  (yuanxu-contract-check-slot! contract value))

;; agentic-ai-lab-session-policy-require-slots!
;;   | contract: adjacent machine contract below defines the session policy gate.
;;   | doc m%
;;       Enforce generated slot contracts for one session policy object before
;;       it crosses into projection, doctor, or runtime manifest code.
;;       # Examples
;;       (agentic-ai-lab-session-policy-require-slots!
;;        'agentic-ai-lab.session.policy schema kind name scope action slots '()
;;        "marlin-agent-core" #f)
;;       # Result
;;       #t when every slot satisfies its contract.
;;     %
;; : (-> Symbol Symbol Symbol Symbol Symbol Symbol Alist Alist PooRuntimeOwner Boolean Boolean)
(def (agentic-ai-lab-session-policy-require-slots! kind
                                             schema
                                             policy-kind
                                             policy-name
                                             scope-ref
                                             default-action
                                             policy-slots
                                             metadata
                                             runtime-owner
                                             runtime-executed?)
  (agentic-ai-lab-session-policy-check-slot!
   AgenticAILabSessionPolicyKindSlot
   kind)
  (agentic-ai-lab-session-policy-check-slot!
   AgenticAILabSessionPolicySchemaSlot
   schema)
  (agentic-ai-lab-session-policy-check-slot!
   AgenticAILabSessionPolicyPolicyKindSlot
   policy-kind)
  (agentic-ai-lab-session-policy-check-slot!
   AgenticAILabSessionPolicyNameSlot
   policy-name)
  (agentic-ai-lab-session-policy-check-slot!
   AgenticAILabSessionPolicyScopeRefSlot
   scope-ref)
  (agentic-ai-lab-session-policy-check-slot!
   AgenticAILabSessionPolicyDefaultActionSlot
   default-action)
  (agentic-ai-lab-session-policy-check-slot!
   AgenticAILabSessionPolicySlotsSlot
   policy-slots)
  (agentic-ai-lab-session-policy-check-slot!
   AgenticAILabSessionPolicyMetadataSlot
   metadata)
  (agentic-ai-lab-session-policy-check-slot!
   AgenticAILabSessionPolicyRuntimeOwnerSlot
   runtime-owner)
  (agentic-ai-lab-session-policy-check-slot!
   AgenticAILabSessionPolicyRuntimeExecutedSlot
   runtime-executed?)
  #t)
