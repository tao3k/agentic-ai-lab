-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.PromotionTransactionRecovery

namespace AgenticAILabProof.Enterprise.EffectDomainCoverage

open PromotionTransactionAtomicity
open PromotionTransactionRecovery

abbrev EffectId := String
abbrev EffectStateDigest := String
abbrev EffectCoverageWitnessId := String
abbrev CompensationPlanDigest := String
abbrev CompensationReceiptId := String

structure EffectFact where
  effectId : EffectId
  stateDigest : EffectStateDigest
  deriving DecidableEq, Repr

abbrev EffectWorld := List EffectFact
abbrev EffectUniverse := List EffectId
abbrev ObservedEffectDomain := List EffectId

def projectEffectWorld
    (domain : ObservedEffectDomain)
    (world : EffectWorld) : EffectWorld :=
  world.filter fun fact => domain.contains fact.effectId

def runtimeOnlyDomain : ObservedEffectDomain :=
  ["runtime"]

def planEffectUniverse : EffectUniverse :=
  ["runtime", "external-message"]

def worldBeforeHiddenMessage : EffectWorld :=
  [
    ⟨"runtime", "sha256:runtime-before"⟩,
    ⟨"external-message", "sha256:not-sent"⟩
  ]

def worldAfterHiddenMessage : EffectWorld :=
  [
    ⟨"runtime", "sha256:runtime-before"⟩,
    ⟨"external-message", "sha256:sent"⟩
  ]

theorem equalDeclaredProjectionCanHideUncoveredEffect :
    projectEffectWorld runtimeOnlyDomain worldBeforeHiddenMessage =
        projectEffectWorld runtimeOnlyDomain worldAfterHiddenMessage ∧
      worldBeforeHiddenMessage ≠ worldAfterHiddenMessage := by
  decide

theorem equalProjectionDigestCannotProveWholeWorldRollback
    (digest : EffectWorld → String) :
    digest
        (projectEffectWorld runtimeOnlyDomain worldBeforeHiddenMessage) =
        digest
          (projectEffectWorld runtimeOnlyDomain worldAfterHiddenMessage) ∧
      worldBeforeHiddenMessage ≠ worldAfterHiddenMessage := by
  constructor
  · rw [equalDeclaredProjectionCanHideUncoveredEffect.1]
  · exact equalDeclaredProjectionCanHideUncoveredEffect.2

def effectDomainCoversUniverse
    (effectUniverse : EffectUniverse)
    (domain : ObservedEffectDomain) : Prop :=
  ∀ effectId,
    effectId ∈ effectUniverse →
      effectId ∈ domain

theorem runtimeOnlyDomainDoesNotCoverPlanUniverse :
    ¬ effectDomainCoversUniverse
      planEffectUniverse
      runtimeOnlyDomain := by
  intro covers
  have messageCovered :=
    covers "external-message" (by simp [planEffectUniverse])
  simp [runtimeOnlyDomain] at messageCovered

def effectWorldCoversDomain
    (domain : ObservedEffectDomain)
    (world : EffectWorld) : Prop :=
  ∀ effectId,
    effectId ∈ domain →
      ∃ fact ∈ world, fact.effectId = effectId

def effectWorldFunctional
    (world : EffectWorld) : Prop :=
  ∀ left ∈ world,
    ∀ right ∈ world,
      left.effectId = right.effectId →
        left = right

def worldsAgreeOn
    (domain : ObservedEffectDomain)
    (before after : EffectWorld) : Prop :=
  ∀ fact,
    fact.effectId ∈ domain →
      (fact ∈ before ↔ fact ∈ after)

structure EffectCoverageWitness where
  witnessId : EffectCoverageWitnessId
  materializationPlanDigest : MaterializationPlanDigest
  effectUniverse : EffectUniverse
  observedDomain : ObservedEffectDomain
  deriving DecidableEq, Repr

def EffectCoverageWitnessValid :=
  EffectCoverageWitness → Prop

def EffectWorldValid :=
  EffectWorld → Prop

def runtimeOnlyCoverageWitness : EffectCoverageWitness where
  witnessId := "coverage-runtime-only"
  materializationPlanDigest := "sha256:marlin-plan-a"
  effectUniverse := planEffectUniverse
  observedDomain := runtimeOnlyDomain

theorem populatedCoverageWitnessDoesNotProveCoverage :
    runtimeOnlyCoverageWitness.materializationPlanDigest =
        admissionSubjectA.materializationPlanDigest ∧
      ¬ effectDomainCoversUniverse
        runtimeOnlyCoverageWitness.effectUniverse
        runtimeOnlyCoverageWitness.observedDomain := by
  constructor
  · rfl
  · exact runtimeOnlyDomainDoesNotCoverPlanUniverse

theorem matchingCoverageFieldsDoNotProveOwnerValidity :
    runtimeOnlyCoverageWitness.materializationPlanDigest =
        admissionSubjectA.materializationPlanDigest ∧
      ¬ (fun _witness : EffectCoverageWitness => False)
        runtimeOnlyCoverageWitness := by
  simp [runtimeOnlyCoverageWitness, admissionSubjectA]

inductive EffectReversibility
  | reversible
  | compensable
  | irreversible
  deriving DecidableEq, Repr

structure EffectObligation where
  effectId : EffectId
  reversibility : EffectReversibility
  compensationPlanDigest : Option CompensationPlanDigest
  deriving DecidableEq, Repr

structure CompensationReceipt where
  receiptId : CompensationReceiptId
  transactionId : TransactionId
  effectId : EffectId
  compensationPlanDigest : CompensationPlanDigest
  fenceToken : Nat
  restoredStateDigest : EffectStateDigest
  deriving DecidableEq, Repr

def CompensationReceiptValid :=
  CompensationReceipt → Prop

def compensationReceiptCloses
    (transactionId : TransactionId)
    (before : EffectWorld)
    (compensationValid : CompensationReceiptValid)
    (receipts : List CompensationReceipt)
    (obligation : EffectObligation) : Prop :=
  ∃ planDigest,
    obligation.compensationPlanDigest = some planDigest ∧
      ∃ beforeFact ∈ before,
        beforeFact.effectId = obligation.effectId ∧
          ∃ receipt ∈ receipts,
            compensationValid receipt ∧
              receipt.transactionId = transactionId ∧
              receipt.effectId = obligation.effectId ∧
              receipt.compensationPlanDigest = planDigest ∧
              receipt.restoredStateDigest = beforeFact.stateDigest

def rollbackObligationClosed
    (transactionId : TransactionId)
    (before : EffectWorld)
    (compensationValid : CompensationReceiptValid)
    (receipts : List CompensationReceipt)
    (obligation : EffectObligation) : Prop :=
  match obligation.reversibility with
  | .reversible => True
  | .compensable =>
      compensationReceiptCloses
        transactionId
        before
        compensationValid
        receipts
        obligation
  | .irreversible => False

def rollbackPlanClosed
    (transactionId : TransactionId)
    (before : EffectWorld)
    (compensationValid : CompensationReceiptValid)
    (receipts : List CompensationReceipt)
    (obligations : List EffectObligation) : Prop :=
  ∀ obligation ∈ obligations,
    rollbackObligationClosed
      transactionId
      before
      compensationValid
      receipts
      obligation

def compensableMessageObligation : EffectObligation where
  effectId := "external-message"
  reversibility := .compensable
  compensationPlanDigest := some "sha256:message-compensation"

def irreversiblePaymentObligation : EffectObligation where
  effectId := "external-payment"
  reversibility := .irreversible
  compensationPlanDigest := none

theorem compensationPlanDigestDoesNotProveCompensation :
    compensableMessageObligation.compensationPlanDigest.isSome ∧
      ¬ rollbackObligationClosed
        commitRequestA.transactionId
        worldBeforeHiddenMessage
        (fun _receipt => True)
        []
        compensableMessageObligation := by
  simp [
    rollbackObligationClosed,
    compensationReceiptCloses,
    compensableMessageObligation
  ]

theorem irreversibleEffectRejectsWholeRollbackPlan
    (compensationValid : CompensationReceiptValid)
    (receipts : List CompensationReceipt) :
    ¬ rollbackPlanClosed
      commitRequestA.transactionId
      worldBeforeHiddenMessage
      compensationValid
      receipts
      [irreversiblePaymentObligation] := by
  intro closed
  have irreversibleClosed :=
    closed irreversiblePaymentObligation (by simp)
  simp [
    rollbackObligationClosed,
    irreversiblePaymentObligation
  ] at irreversibleClosed

def obligationsCoverUniverse
    (effectUniverse : EffectUniverse)
    (obligations : List EffectObligation) : Prop :=
  (∀ effectId,
      effectId ∈ effectUniverse →
        ∃ obligation ∈ obligations,
          obligation.effectId = effectId) ∧
    (∀ obligation,
      obligation ∈ obligations →
        obligation.effectId ∈ effectUniverse)

structure EffectRollbackEvidenceClosed
    (request : PromotionCommitRequest)
    (witnessValid : EffectCoverageWitnessValid)
    (worldValid : EffectWorldValid)
    (compensationValid : CompensationReceiptValid)
    (witness : EffectCoverageWitness)
    (obligations : List EffectObligation)
    (compensationReceipts : List CompensationReceipt)
    (before after : EffectWorld) : Prop where
  witnessPlanMatchesSubject :
    witness.materializationPlanDigest =
      request.subject.materializationPlanDigest
  witnessValidates : witnessValid witness
  domainCoversUniverse :
    effectDomainCoversUniverse
      witness.effectUniverse
      witness.observedDomain
  obligationsCover :
    obligationsCoverUniverse witness.effectUniverse obligations
  beforeWorldValidates : worldValid before
  afterWorldValidates : worldValid after
  beforeWorldCoversDomain :
    effectWorldCoversDomain witness.observedDomain before
  afterWorldCoversDomain :
    effectWorldCoversDomain witness.observedDomain after
  beforeWorldFunctional : effectWorldFunctional before
  afterWorldFunctional : effectWorldFunctional after
  observationsAgree :
    worldsAgreeOn witness.observedDomain before after
  rollbackObligationsClose :
    rollbackPlanClosed
      request.transactionId
      before
      compensationValid
      compensationReceipts
      obligations

def runtimeEffectFact : EffectFact where
  effectId := "runtime"
  stateDigest := "sha256:runtime-before"

def runtimeEffectWorld : EffectWorld :=
  [runtimeEffectFact]

def completeRuntimeCoverageWitness : EffectCoverageWitness where
  witnessId := "coverage-runtime-complete"
  materializationPlanDigest := "sha256:marlin-plan-a"
  effectUniverse := ["runtime"]
  observedDomain := ["runtime"]

def reversibleRuntimeObligation : EffectObligation where
  effectId := "runtime"
  reversibility := .reversible
  compensationPlanDigest := none

theorem reversibleRuntimeRollbackCloses :
    EffectRollbackEvidenceClosed
      commitRequestA
      (fun _witness => True)
      (fun _world => True)
      (fun _receipt => True)
      completeRuntimeCoverageWitness
      [reversibleRuntimeObligation]
      []
      runtimeEffectWorld
      runtimeEffectWorld := by
  constructor
  · rfl
  · trivial
  · intro effectId effectInUniverse
    simpa [completeRuntimeCoverageWitness] using effectInUniverse
  · constructor
    · intro effectId effectInUniverse
      refine ⟨reversibleRuntimeObligation, by simp, ?_⟩
      have effectIdIsRuntime : effectId = "runtime" := by
        simpa [completeRuntimeCoverageWitness] using effectInUniverse
      simpa [reversibleRuntimeObligation] using effectIdIsRuntime.symm
    · intro obligation obligationInPlan
      simp only [List.mem_singleton] at obligationInPlan
      subst obligation
      simp [
        completeRuntimeCoverageWitness,
        reversibleRuntimeObligation
      ]
  · trivial
  · trivial
  · intro effectId effectInDomain
    refine ⟨runtimeEffectFact, by simp [runtimeEffectWorld], ?_⟩
    have effectIdIsRuntime : effectId = "runtime" := by
      simpa [completeRuntimeCoverageWitness] using effectInDomain
    simpa [runtimeEffectFact] using effectIdIsRuntime.symm
  · intro effectId effectInDomain
    refine ⟨runtimeEffectFact, by simp [runtimeEffectWorld], ?_⟩
    have effectIdIsRuntime : effectId = "runtime" := by
      simpa [completeRuntimeCoverageWitness] using effectInDomain
    simpa [runtimeEffectFact] using effectIdIsRuntime.symm
  · intro left leftInWorld right rightInWorld sameId
    simp only [runtimeEffectWorld, List.mem_singleton] at leftInWorld
    simp only [runtimeEffectWorld, List.mem_singleton] at rightInWorld
    subst left
    subst right
    rfl
  · intro left leftInWorld right rightInWorld sameId
    simp only [runtimeEffectWorld, List.mem_singleton] at leftInWorld
    simp only [runtimeEffectWorld, List.mem_singleton] at rightInWorld
    subst left
    subst right
    rfl
  · intro fact factInDomain
    rfl
  · intro obligation obligationInPlan
    simp only [List.mem_singleton] at obligationInPlan
    subst obligation
    simp [
      rollbackObligationClosed,
      reversibleRuntimeObligation
    ]

theorem coveredRollbackAgreesOnEveryPlanEffect
    (request : PromotionCommitRequest)
    (witnessValid : EffectCoverageWitnessValid)
    (worldValid : EffectWorldValid)
    (compensationValid : CompensationReceiptValid)
    (witness : EffectCoverageWitness)
    (obligations : List EffectObligation)
    (compensationReceipts : List CompensationReceipt)
    (before after : EffectWorld)
    (closed :
      EffectRollbackEvidenceClosed
        request
        witnessValid
        worldValid
        compensationValid
        witness
        obligations
        compensationReceipts
        before
        after) :
    worldsAgreeOn witness.effectUniverse before after := by
  intro fact factInUniverse
  exact closed.observationsAgree
    fact
    (closed.domainCoversUniverse
      fact.effectId
      factInUniverse)

theorem closedCompensableRollbackProvidesValidEvidence
    (request : PromotionCommitRequest)
    (witnessValid : EffectCoverageWitnessValid)
    (worldValid : EffectWorldValid)
    (compensationValid : CompensationReceiptValid)
    (witness : EffectCoverageWitness)
    (obligations : List EffectObligation)
    (compensationReceipts : List CompensationReceipt)
    (before after : EffectWorld)
    (closed :
      EffectRollbackEvidenceClosed
        request
        witnessValid
        worldValid
        compensationValid
        witness
        obligations
        compensationReceipts
        before
        after)
    (obligation : EffectObligation)
    (obligationInPlan : obligation ∈ obligations)
    (compensable :
      obligation.reversibility = .compensable) :
    compensationReceiptCloses
      request.transactionId
      before
      compensationValid
      compensationReceipts
      obligation := by
  have obligationClosed :=
    closed.rollbackObligationsClose
      obligation
      obligationInPlan
  simp [rollbackObligationClosed, compensable] at obligationClosed
  exact obligationClosed

end AgenticAILabProof.Enterprise.EffectDomainCoverage
