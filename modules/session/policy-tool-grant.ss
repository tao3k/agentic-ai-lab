;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO session grants, wire projection and grant matching.

(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :clan/poo/mop element?)
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/policy-syntax
        :agentic-ai-lab/modules/session/policy-core
        (only-in :yuanxu/module-system/schema/slot-contracts
                 yuanxu-contract-check-slot!
                 yuanxu-contract-slot
                 yuanxu-contract-value-type
                 yuanxu-object-contract
                 yuanxu-object-contract->alist))

(export AgenticAILabSessionToolGrantContract
        agentic-ai-lab-session-tool-grant
        agentic-ai-lab-session-tool-grant->alist
        agentic-ai-lab-session-tool-grant?
        agentic-ai-lab-session-tool-grant-type-contract->alist
        agentic-ai-lab-session-tool-grant-check-slot!
        agentic-ai-lab-session-tool-grant-require-slots!
        agentic-ai-lab-session-tool-grant-id
        agentic-ai-lab-session-tool-grant-tool-ref
        agentic-ai-lab-session-tool-grant-actions
        agentic-ai-lab-session-tool-grant-resource-refs
        agentic-ai-lab-session-tool-grant-trigger-refs
        agentic-ai-lab-session-tool-grant-allows?
        agentic-ai-lab-session-tool-grants-allow?)

;; : (-> Symbol Symbol [Symbol] [Symbol/String] [Symbol] [Alist] PooSessionToolGrant)
(def (agentic-ai-lab-session-tool-grant grant-id-value
                                  tool-ref-value
                                  actions-value
                                  resource-refs-value
                                  trigger-refs-value
                                  . maybe-metadata)
  (agentic-ai-lab-session-require "session tool grant id must be a symbol"
                            (symbol? grant-id-value)
                            grant-id-value)
  (agentic-ai-lab-session-require "session tool grant tool ref must be a symbol"
                            (symbol? tool-ref-value)
                            tool-ref-value)
  (agentic-ai-lab-session-require "session tool grant actions must be symbols"
                            (agentic-ai-lab-session-symbol-list? actions-value)
                            actions-value)
  (agentic-ai-lab-session-require
   "session tool grant resource refs must be symbols or strings"
   (agentic-ai-lab-session-policy-ref-list? resource-refs-value)
   resource-refs-value)
  (agentic-ai-lab-session-require "session tool grant trigger refs must be symbols"
                            (agentic-ai-lab-session-symbol-list? trigger-refs-value)
                            trigger-refs-value)
  (let (metadata-value (if (null? maybe-metadata) '() (car maybe-metadata)))
    (agentic-ai-lab-session-tool-grant-require-slots!
     'agentic-ai-lab.session.tool-grant
     'agentic-ai-lab.modules.session.tool-grant.v1
     grant-id-value
     tool-ref-value
     actions-value
     resource-refs-value
     trigger-refs-value
     metadata-value
     #f)
    (.o bind-these: #f
        kind: 'agentic-ai-lab.session.tool-grant
        schema: 'agentic-ai-lab.modules.session.tool-grant.v1
        grant-id: grant-id-value
        tool-ref: tool-ref-value
        actions: actions-value
        resource-refs: resource-refs-value
        trigger-refs: trigger-refs-value
        metadata: metadata-value
        runtime-executed: #f)))

;; The semantic grant is POO-native; wire rows are produced only by projection.
(def (session-tool-grant-object? value)
  (and (object? value) (.slot? value 'kind)
       (eq? (.ref value 'kind) 'agentic-ai-lab.session.tool-grant)))
(def (agentic-ai-lab-session-tool-grant? value)
  (element? AgenticAILabSessionToolGrantContract value))
(def (agentic-ai-lab-session-tool-grant-id grant) (.ref grant 'grant-id))
(def (agentic-ai-lab-session-tool-grant-tool-ref grant) (.ref grant 'tool-ref))
(def (agentic-ai-lab-session-tool-grant-actions grant) (.ref grant 'actions))
(def (agentic-ai-lab-session-tool-grant-resource-refs grant) (.ref grant 'resource-refs))
(def (agentic-ai-lab-session-tool-grant-trigger-refs grant) (.ref grant 'trigger-refs))

(def AgenticAILabSessionToolGrantKindType
  (yuanxu-contract-value-type
   'SessionToolGrantKind agentic-ai-lab-session-tool-grant-kind-value? 'Symbol))
(def AgenticAILabSessionToolGrantSymbolType
  (yuanxu-contract-value-type 'Symbol symbol? 'Symbol))
(def AgenticAILabSessionToolGrantSymbolListType
  (yuanxu-contract-value-type
   '[Symbol] agentic-ai-lab-session-symbol-list? '[Symbol]))
(def AgenticAILabSessionToolGrantRefListType
  (yuanxu-contract-value-type
   '[Symbol/String] agentic-ai-lab-session-policy-ref-list? '[Symbol/String]))
(def AgenticAILabSessionToolGrantAlistType
  (yuanxu-contract-value-type
   'Alist agentic-ai-lab-session-policy-alist? 'Alist))
(def AgenticAILabSessionToolGrantBooleanType
  (yuanxu-contract-value-type
   'Boolean agentic-ai-lab-session-policy-boolean? 'Boolean))

(def (agentic-ai-lab-session-tool-grant-slot-contract key slot value-type)
  (yuanxu-contract-slot key slot value-type #t '()))

(def AgenticAILabSessionToolGrantKindSlot
  (agentic-ai-lab-session-tool-grant-slot-contract
   'session.tool-grant/kind 'kind AgenticAILabSessionToolGrantKindType))
(def AgenticAILabSessionToolGrantSchemaSlot
  (agentic-ai-lab-session-tool-grant-slot-contract
   'session.tool-grant/schema 'schema AgenticAILabSessionToolGrantSymbolType))
(def AgenticAILabSessionToolGrantIdSlot
  (agentic-ai-lab-session-tool-grant-slot-contract
   'session.tool-grant/grant-id 'grant-id AgenticAILabSessionToolGrantSymbolType))
(def AgenticAILabSessionToolGrantToolRefSlot
  (agentic-ai-lab-session-tool-grant-slot-contract
   'session.tool-grant/tool-ref 'tool-ref AgenticAILabSessionToolGrantSymbolType))
(def AgenticAILabSessionToolGrantActionsSlot
  (agentic-ai-lab-session-tool-grant-slot-contract
   'session.tool-grant/actions 'actions AgenticAILabSessionToolGrantSymbolListType))
(def AgenticAILabSessionToolGrantResourceRefsSlot
  (agentic-ai-lab-session-tool-grant-slot-contract
   'session.tool-grant/resource-refs
   'resource-refs
   AgenticAILabSessionToolGrantRefListType))
(def AgenticAILabSessionToolGrantTriggerRefsSlot
  (agentic-ai-lab-session-tool-grant-slot-contract
   'session.tool-grant/trigger-refs
   'trigger-refs
   AgenticAILabSessionToolGrantSymbolListType))
(def AgenticAILabSessionToolGrantMetadataSlot
  (agentic-ai-lab-session-tool-grant-slot-contract
   'session.tool-grant/metadata 'metadata AgenticAILabSessionToolGrantAlistType))
(def AgenticAILabSessionToolGrantRuntimeExecutedSlot
  (agentic-ai-lab-session-tool-grant-slot-contract
   'session.tool-grant/runtime-executed
   'runtime-executed
   AgenticAILabSessionToolGrantBooleanType))

(def AgenticAILabSessionToolGrantSlots
  (list AgenticAILabSessionToolGrantKindSlot
        AgenticAILabSessionToolGrantSchemaSlot
        AgenticAILabSessionToolGrantIdSlot
        AgenticAILabSessionToolGrantToolRefSlot
        AgenticAILabSessionToolGrantActionsSlot
        AgenticAILabSessionToolGrantResourceRefsSlot
        AgenticAILabSessionToolGrantTriggerRefsSlot
        AgenticAILabSessionToolGrantMetadataSlot
        AgenticAILabSessionToolGrantRuntimeExecutedSlot))

(def AgenticAILabSessionToolGrantContract
  (yuanxu-object-contract
   'session/tool-grant
   'session
   'PooSessionToolGrant
   session-tool-grant-object?
   AgenticAILabSessionToolGrantSlots

   '((boundary . session-policy) (runtime . marlin-agent-core))))

;; agentic-ai-lab-session-tool-grant-type-contract->alist
;;   | contract: adjacent machine contract below defines the projection.
;;   | doc m%
;;       Project the structured contract for session tool grant rows.
;;       # Examples
;;       (agentic-ai-lab-session-tool-grant-type-contract->alist)
;;       # Result
;;       An alist representation suitable for policy diagnostics.
;;     %
;; : (-> Unit Alist)
(def (agentic-ai-lab-session-tool-grant-type-contract->alist)
  (yuanxu-object-contract->alist AgenticAILabSessionToolGrantContract))

;; : (-> YuanxuSlotContract AgenticAILabValue AgenticAILabValue)
(def (agentic-ai-lab-session-tool-grant-check-slot! contract value)
  (yuanxu-contract-check-slot! contract value))

;; agentic-ai-lab-session-tool-grant-require-slots!
;;   | contract: adjacent machine contract below defines the tool grant gate.
;;   | doc m%
;;       Enforce generated slot contracts for one tool grant row. Tool execution
;;       remains outside Scheme; this gate only validates authorization data.
;;       # Examples
;;       (agentic-ai-lab-session-tool-grant-require-slots!
;;        'agentic-ai-lab.session.tool-grant schema grant tool actions resources triggers '() #f)
;;       # Result
;;       #t when every grant slot satisfies its contract.
;;     %
;; : (-> Symbol Symbol Symbol Symbol [Symbol] [Symbol/String] [Symbol] Alist Boolean Boolean)
(def (agentic-ai-lab-session-tool-grant-require-slots! kind
                                                 schema
                                                 grant-id
                                                 tool-ref
                                                 actions
                                                 resource-refs
                                                 trigger-refs
                                                 metadata
                                                 runtime-executed?)
  (agentic-ai-lab-session-tool-grant-check-slot!
   AgenticAILabSessionToolGrantKindSlot
   kind)
  (agentic-ai-lab-session-tool-grant-check-slot!
   AgenticAILabSessionToolGrantSchemaSlot
   schema)
  (agentic-ai-lab-session-tool-grant-check-slot!
   AgenticAILabSessionToolGrantIdSlot
   grant-id)
  (agentic-ai-lab-session-tool-grant-check-slot!
   AgenticAILabSessionToolGrantToolRefSlot
   tool-ref)
  (agentic-ai-lab-session-tool-grant-check-slot!
   AgenticAILabSessionToolGrantActionsSlot
   actions)
  (agentic-ai-lab-session-tool-grant-check-slot!
   AgenticAILabSessionToolGrantResourceRefsSlot
   resource-refs)
  (agentic-ai-lab-session-tool-grant-check-slot!
   AgenticAILabSessionToolGrantTriggerRefsSlot
   trigger-refs)
  (agentic-ai-lab-session-tool-grant-check-slot!
   AgenticAILabSessionToolGrantMetadataSlot
   metadata)
  (agentic-ai-lab-session-tool-grant-check-slot!
   AgenticAILabSessionToolGrantRuntimeExecutedSlot
   runtime-executed?)
  #t)

;; : (-> PooSessionToolGrant Symbol Symbol Boolean)
(def (agentic-ai-lab-session-tool-grant-allows? grant tool-ref action)
  (and (agentic-ai-lab-session-tool-grant? grant)
       (agentic-ai-lab-session-policy-match?
        tool-ref
        (list (agentic-ai-lab-session-tool-grant-tool-ref grant)))
       (agentic-ai-lab-session-policy-match?
        action
        (agentic-ai-lab-session-tool-grant-actions grant))))

;; : (-> [PooSessionToolGrant] Symbol Symbol Boolean)
(def (agentic-ai-lab-session-tool-grants-allow? grants tool-ref action)
  (cond
   ((null? grants) #f)
   ((agentic-ai-lab-session-tool-grant-allows? (car grants) tool-ref action) #t)
   (else
    (agentic-ai-lab-session-tool-grants-allow? (cdr grants) tool-ref action))))
