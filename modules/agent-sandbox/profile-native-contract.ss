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
                 yuanxu-native-contract
                 yuanxu-native-contract->alist)
        (only-in :yuanxu/types
                 yuanxu-contract-admit
                 yuanxu-validation-evidence-accepted?))

(export poo-flow-sandbox-profile-kind
        PooFlowSandboxProfileContract
        poo-flow-sandbox-profile-contract-admission
        poo-flow-sandbox-profile-contract-admitted?
        poo-flow-sandbox-profile-type-contract->alist
        poo-flow-require-sandbox-profile-contract!)

;; Kind ids remain boundary vocabulary. They do not select a runtime backend.
(def poo-flow-sandbox-profile-kind
  "poo-flow.agent-sandbox.user-profile.v1")

;; : (-> Object Boolean)
(def (poo-flow-sandbox-profile-object? value)
  (and (object? value)
       (.slot? value 'kind)
       (equal? (.ref value 'kind) poo-flow-sandbox-profile-kind)))

;; : (-> Object Boolean)
(def (poo-flow-sandbox-profile-kind-value? value)
  (equal? value poo-flow-sandbox-profile-kind))

;; : (-> POOObject Symbol Boolean)
(def (poo-flow-sandbox-profile-slot-present? candidate slot)
  (.slot? candidate slot))

;; : (-> POOObject Symbol Object)
(def (poo-flow-sandbox-profile-slot-ref candidate slot)
  (.ref candidate slot))

(def PooFlowSandboxProfileKindType
  (yuanxu-contract-value-type
   'PooSandboxProfileKind
   poo-flow-sandbox-profile-kind-value?
   'String
   'sandbox-profile-kind))

(def PooFlowSandboxProfileSymbolType
  (yuanxu-contract-value-type 'Symbol symbol? 'Symbol))

(def PooFlowSandboxProfileListType
  (yuanxu-contract-value-type 'List list? 'List))

;; : (-> Symbol Symbol PooContractValueType Alist PooContractSlot)
(def (poo-flow-sandbox-profile-slot key slot value-type metadata)
  (yuanxu-contract-slot key slot value-type #t metadata))

(def +poo-flow-sandbox-profile-slots+
  (list
   (poo-flow-sandbox-profile-slot
    'sandbox.profile/kind 'kind PooFlowSandboxProfileKindType
    '((scope . agent-sandbox) (owned-by . profile-native-contract)))
   (poo-flow-sandbox-profile-slot
    'sandbox.profile/name 'name PooFlowSandboxProfileSymbolType
    '((scope . agent-sandbox) (owned-by . user-declaration)))
   (poo-flow-sandbox-profile-slot
    'sandbox.profile/backend-kind 'backend-kind PooFlowSandboxProfileSymbolType
    '((scope . sandbox-core) (owned-by . module-config)))
   (poo-flow-sandbox-profile-slot
    'sandbox.profile/backend-ref 'backend-ref PooFlowSandboxProfileSymbolType
    '((scope . sandbox-core) (owned-by . module-config)))
   (poo-flow-sandbox-profile-slot
    'sandbox.profile/network-policy 'network-policy PooFlowSandboxProfileListType
    '((scope . sandbox-core) (projection . network)))
   (poo-flow-sandbox-profile-slot
    'sandbox.profile/capabilities 'capabilities PooFlowSandboxProfileListType
    '((scope . sandbox-core) (projection . capabilities)))
   (poo-flow-sandbox-profile-slot
    'sandbox.profile/resource-policy 'resource-policy PooFlowSandboxProfileListType
    '((scope . sandbox-core) (projection . resources)))
   (poo-flow-sandbox-profile-slot
    'sandbox.profile/metadata 'metadata PooFlowSandboxProfileListType
    '((scope . agent-sandbox) (projection . metadata)))))

(def PooFlowSandboxProfileContract
  (yuanxu-native-contract
   'PooSandboxProfileContract
   'agent-sandbox
   'PooSandboxProfile
   poo-flow-sandbox-profile-object?
   +poo-flow-sandbox-profile-slots+
   poo-flow-sandbox-profile-slot-present?
   poo-flow-sandbox-profile-slot-ref
   '((semantic-owner . agent-sandbox)
     (runtime-executed . #f)
     (projection . sandbox-profile-recipe))))

;; : (-> PooSandboxProfile PooValidationEvidence)
(def (poo-flow-sandbox-profile-contract-admission profile)
  (yuanxu-contract-admit
   PooFlowSandboxProfileContract
   profile
   'sandbox-profile-recipe))

;; : (-> PooSandboxProfile Boolean)
(def (poo-flow-sandbox-profile-contract-admitted? profile)
  (yuanxu-validation-evidence-accepted?
   (poo-flow-sandbox-profile-contract-admission profile)))

;; : (-> Alist)
(def (poo-flow-sandbox-profile-type-contract->alist)
  (yuanxu-native-contract->alist PooFlowSandboxProfileContract))

;; : (-> PooSandboxProfile PooSandboxProfile)
(def (poo-flow-require-sandbox-profile-contract! profile)
  (let (evidence (poo-flow-sandbox-profile-contract-admission profile))
    (if (yuanxu-validation-evidence-accepted? evidence)
      profile
      (error "sandbox profile failed native contract admission" evidence))))
