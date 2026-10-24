;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: native Type/Contract owner for inert sandbox profile recipes.
;;; Invariant: profile objects are semantic POO values; rows are projections.

(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :yuanxu/module-system/schema/slot-contracts
                 yuanxu-contract-slot
                 yuanxu-contract-value-type
                 yuanxu-object-contract
                 yuanxu-object-contract->alist)
        (only-in :yuanxu/object-types/contracts
                 yuanxu-contract-admit
                 yuanxu-validation-evidence-accepted?))

(export agentic-ai-lab-sandbox-profile-kind
        AgenticAILabSandboxProfileContract
        agentic-ai-lab-sandbox-profile-contract-admission
        agentic-ai-lab-sandbox-profile-contract-admitted?
        agentic-ai-lab-sandbox-profile-type-contract->alist
        agentic-ai-lab-require-sandbox-profile-contract!)

;; Kind ids remain boundary vocabulary. They do not select a runtime backend.
(def agentic-ai-lab-sandbox-profile-kind
  "agentic-ai-lab.agent-sandbox.user-profile.v1")

;; : (-> Object Boolean)
(def (agentic-ai-lab-sandbox-profile-object? value)
  (and (object? value)
       (.slot? value 'kind)
       (equal? (.ref value 'kind) agentic-ai-lab-sandbox-profile-kind)))

;; : (-> Object Boolean)
(def (agentic-ai-lab-sandbox-profile-kind-value? value)
  (equal? value agentic-ai-lab-sandbox-profile-kind))

;; : (-> POOObject Symbol Boolean)
(def (agentic-ai-lab-sandbox-profile-slot-present? candidate slot)
  (.slot? candidate slot))

;; : (-> POOObject Symbol Object)
(def (agentic-ai-lab-sandbox-profile-slot-ref candidate slot)
  (.ref candidate slot))

(def AgenticAILabSandboxProfileKindType
  (yuanxu-contract-value-type
   'PooSandboxProfileKind
   agentic-ai-lab-sandbox-profile-kind-value?
   'String
   'sandbox-profile-kind))

(def AgenticAILabSandboxProfileSymbolType
  (yuanxu-contract-value-type 'Symbol symbol? 'Symbol))

(def AgenticAILabSandboxProfileListType
  (yuanxu-contract-value-type 'List list? 'List))

;; : (-> Symbol Symbol PooContractValueType Alist PooContractSlot)
(def (agentic-ai-lab-sandbox-profile-slot key slot value-type metadata)
  (yuanxu-contract-slot key slot value-type #t metadata))

(def +agentic-ai-lab-sandbox-profile-slots+
  (list
   (agentic-ai-lab-sandbox-profile-slot
    'sandbox.profile/kind 'kind AgenticAILabSandboxProfileKindType
    '((scope . agent-sandbox) (owned-by . profile-native-contract)))
   (agentic-ai-lab-sandbox-profile-slot
    'sandbox.profile/name 'name AgenticAILabSandboxProfileSymbolType
    '((scope . agent-sandbox) (owned-by . user-declaration)))
   (agentic-ai-lab-sandbox-profile-slot
    'sandbox.profile/backend-kind 'backend-kind AgenticAILabSandboxProfileSymbolType
    '((scope . sandbox-core) (owned-by . module-config)))
   (agentic-ai-lab-sandbox-profile-slot
    'sandbox.profile/backend-ref 'backend-ref AgenticAILabSandboxProfileSymbolType
    '((scope . sandbox-core) (owned-by . module-config)))
   (agentic-ai-lab-sandbox-profile-slot
    'sandbox.profile/network-policy 'network-policy AgenticAILabSandboxProfileListType
    '((scope . sandbox-core) (projection . network)))
   (agentic-ai-lab-sandbox-profile-slot
    'sandbox.profile/capabilities 'capabilities AgenticAILabSandboxProfileListType
    '((scope . sandbox-core) (projection . capabilities)))
   (agentic-ai-lab-sandbox-profile-slot
    'sandbox.profile/resource-policy 'resource-policy AgenticAILabSandboxProfileListType
    '((scope . sandbox-core) (projection . resources)))
   (agentic-ai-lab-sandbox-profile-slot
    'sandbox.profile/metadata 'metadata AgenticAILabSandboxProfileListType
    '((scope . agent-sandbox) (projection . metadata)))))

(def AgenticAILabSandboxProfileContract
  (yuanxu-object-contract
   'PooSandboxProfileContract
   'agent-sandbox
   'PooSandboxProfile
   agentic-ai-lab-sandbox-profile-object?
   +agentic-ai-lab-sandbox-profile-slots+
   agentic-ai-lab-sandbox-profile-slot-present?
   agentic-ai-lab-sandbox-profile-slot-ref
   '((semantic-owner . agent-sandbox)
     (runtime-executed . #f)
     (projection . sandbox-profile-recipe))))

;; : (-> PooSandboxProfile PooValidationEvidence)
(def (agentic-ai-lab-sandbox-profile-contract-admission profile)
  (yuanxu-contract-admit
   AgenticAILabSandboxProfileContract
   profile
   'sandbox-profile-recipe))

;; : (-> PooSandboxProfile Boolean)
(def (agentic-ai-lab-sandbox-profile-contract-admitted? profile)
  (yuanxu-validation-evidence-accepted?
   (agentic-ai-lab-sandbox-profile-contract-admission profile)))

;; : (-> Alist)
(def (agentic-ai-lab-sandbox-profile-type-contract->alist)
  (yuanxu-object-contract->alist AgenticAILabSandboxProfileContract))

;; : (-> PooSandboxProfile PooSandboxProfile)
(def (agentic-ai-lab-require-sandbox-profile-contract! profile)
  (let (evidence (agentic-ai-lab-sandbox-profile-contract-admission profile))
    (if (yuanxu-validation-evidence-accepted? evidence)
      profile
      (error "sandbox profile failed native contract admission" evidence))))
