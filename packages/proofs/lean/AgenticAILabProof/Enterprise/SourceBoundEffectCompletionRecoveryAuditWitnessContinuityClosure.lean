-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuditWitnessContinuityModel
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerCoverageClosure

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuditWitnessContinuityClosure

open SourceBoundEffectCompletionCrashRecoveryClosure
open SourceBoundEffectCompletionRecoveryAuditWitnessContinuityModel
open SourceBoundEffectCompletionRecoveryConvergenceClosure
open SourceBoundEffectCompletionRecoveryOwnerCoverageClosure
open SourceBoundEffectCompletionRecoveryProgressEvidenceClosure

namespace CrashOwner

open SourceBoundEffectCompletionRecoveryOwnerDeferralAdmissionContractClosure

abbrev ContractValid :=
  SourceBoundEffectCompletionRecoveryCrashDeferralContractValid

abbrev ReceiptValid :=
  SourceBoundEffectCompletionRecoveryCrashDeferralReceiptValid

abbrev Contract :=
  SourceBoundEffectCompletionRecoveryCrashDeferralContract

abbrev Receipt :=
  SourceBoundEffectCompletionRecoveryCrashDeferralReceipt

abbrev TransitionClosed :=
  SourceBoundEffectCompletionRecoveryCrashDeferralTransitionClosed

abbrev ProgressProjection :=
  SourceBoundEffectCompletionRecoveryCrashDeferralProgressProjection

end CrashOwner

namespace SchedulerOwner

open SourceBoundCompositionalFixedPointClosure
open SourceBoundCycleObservationClosure
open SourceBoundDeterministicBudgetClosure
open SourceBoundEffectCompletionRecoverySchedulingDeferralOwnerClosure
open SourceBoundProgressEvidenceClosure

abbrev PlanValid := SourceBoundDeterministicBudgetPlanValid
abbrev BudgetReceiptValid := SourceBoundDeterministicBudgetReceiptValid
abbrev ContractValid :=
  SourceBoundEffectCompletionRecoverySchedulingDeferralContractValid
abbrev ReceiptValid :=
  SourceBoundEffectCompletionRecoverySchedulingDeferralReceiptValid
abbrev Authority :=
  SourceBoundEffectCompletionRecoverySchedulerPlanAuthority
abbrev FixedPoint := SourceBoundFixedPointReceipt
abbrev Cycle := SourceBoundCycleDetectedObservation
abbrev ProgressReceipt := SourceBoundProgressReceipt
abbrev Plan := SourceBoundDeterministicBudgetPlan
abbrev BudgetReceipt := SourceBoundDeterministicBudgetReceipt
abbrev Contract :=
  SourceBoundEffectCompletionRecoverySchedulingDeferralContract
abbrev Receipt :=
  SourceBoundEffectCompletionRecoverySchedulingDeferralReceipt
abbrev TransitionClosed :=
  SourceBoundEffectCompletionRecoverySchedulingDeferralTransitionClosed
abbrev ProgressProjection :=
  SourceBoundEffectCompletionRecoverySchedulingDeferralProgressProjection

end SchedulerOwner

namespace StorageOwner

open SourceBoundEffectCompletionPublicationClosure
open SourceBoundEffectCompletionRecoveryOwnerDeferralAdmissionContractClosure

abbrev ContractValid :=
  SourceBoundEffectCompletionPrecommitStorageAdmissionContractValid
abbrev ReceiptValid :=
  SourceBoundEffectCompletionPrecommitStorageAdmissionReceiptValid
abbrev Publication := SourceBoundEffectCompletionPublication
abbrev Contract :=
  SourceBoundEffectCompletionPrecommitStorageAdmissionContract
abbrev Receipt :=
  SourceBoundEffectCompletionPrecommitStorageAdmissionReceipt
abbrev TransitionClosed :=
  SourceBoundEffectCompletionPrecommitStorageDeferralTransitionClosed
abbrev ProgressProjection :=
  SourceBoundEffectCompletionRecoveryStorageDeferralProgressProjection

end StorageOwner

inductive SourceBoundEffectCompletionRecoveryAuditedOwnerCoveredStep :
    SourceBoundEffectCompletionRecoveryExpectation →
      SourceBoundEffectCompletionRecoveryProgressBudget →
        SourceBoundEffectCompletionRecoveryProgressBudget →
          SourceBoundEffectCompletionRecoveryProgressOwner →
            String → String → String → String → Prop
  | runtimeCrash
      {expectation : SourceBoundEffectCompletionRecoveryExpectation}
      {beforeBudget afterBudget :
        SourceBoundEffectCompletionRecoveryProgressBudget}
      {contractValid : CrashOwner.ContractValid}
      {receiptValid : CrashOwner.ReceiptValid}
      {contract : CrashOwner.Contract}
      {beforeReceipt afterReceipt : CrashOwner.Receipt}
      (closed :
        CrashOwner.TransitionClosed
          contractValid receiptValid expectation contract
          beforeReceipt afterReceipt)
      (projection :
        CrashOwner.ProgressProjection
          beforeReceipt afterReceipt beforeBudget afterBudget) :
      SourceBoundEffectCompletionRecoveryAuditedOwnerCoveredStep
        expectation beforeBudget afterBudget
        .runtimeCrashBudget
        afterReceipt.runtimeOwnerIdentity
        beforeReceipt.receiptId
        afterReceipt.receiptId
        afterReceipt.recoveryId
  | scheduler
      {expectation : SourceBoundEffectCompletionRecoveryExpectation}
      {beforeBudget afterBudget :
        SourceBoundEffectCompletionRecoveryProgressBudget}
      {planValid : SchedulerOwner.PlanValid}
      {budgetReceiptValid : SchedulerOwner.BudgetReceiptValid}
      {contractValid : SchedulerOwner.ContractValid}
      {receiptValid : SchedulerOwner.ReceiptValid}
      {schedulerAuthority : SchedulerOwner.Authority}
      {fixedPoint : SchedulerOwner.FixedPoint}
      {cycle : SchedulerOwner.Cycle}
      {beforeProgress afterProgress : SchedulerOwner.ProgressReceipt}
      {plan : SchedulerOwner.Plan}
      {beforeBudgetReceipt afterBudgetReceipt :
        SchedulerOwner.BudgetReceipt}
      {contract : SchedulerOwner.Contract}
      {beforeReceipt afterReceipt : SchedulerOwner.Receipt}
      (closed :
        SchedulerOwner.TransitionClosed
          planValid budgetReceiptValid contractValid receiptValid
          schedulerAuthority expectation fixedPoint cycle
          beforeProgress afterProgress plan
          beforeBudgetReceipt afterBudgetReceipt
          contract beforeReceipt afterReceipt)
      (projection :
        SchedulerOwner.ProgressProjection
          beforeReceipt afterReceipt beforeBudget afterBudget) :
      SourceBoundEffectCompletionRecoveryAuditedOwnerCoveredStep
        expectation beforeBudget afterBudget
        .schedulerAdmission
        afterReceipt.schedulerOwnerIdentity
        beforeReceipt.receiptId
        afterReceipt.receiptId
        afterReceipt.recoveryId
  | completionStorage
      {expectation : SourceBoundEffectCompletionRecoveryExpectation}
      {beforeBudget afterBudget :
        SourceBoundEffectCompletionRecoveryProgressBudget}
      {contractValid : StorageOwner.ContractValid}
      {receiptValid : StorageOwner.ReceiptValid}
      {publication : StorageOwner.Publication}
      {contract : StorageOwner.Contract}
      {beforeReceipt afterReceipt : StorageOwner.Receipt}
      (closed :
        StorageOwner.TransitionClosed
          contractValid receiptValid expectation publication contract
          beforeReceipt afterReceipt)
      (projection :
        StorageOwner.ProgressProjection
          beforeReceipt afterReceipt beforeBudget afterBudget) :
      SourceBoundEffectCompletionRecoveryAuditedOwnerCoveredStep
        expectation beforeBudget afterBudget
        .completionStorageAdmission
        afterReceipt.storageOwnerIdentity
        beforeReceipt.receiptId
        afterReceipt.receiptId
        afterReceipt.recoveryId

theorem auditedOwnerCoveredStepForgetsAuditIdentity
    {expectation : SourceBoundEffectCompletionRecoveryExpectation}
    {beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget}
    {owner : SourceBoundEffectCompletionRecoveryProgressOwner}
    {ownerIdentity beforeReceiptIdentity afterReceiptIdentity
      recoveryIdentity : String}
    (audited :
      SourceBoundEffectCompletionRecoveryAuditedOwnerCoveredStep
        expectation beforeBudget afterBudget owner
        ownerIdentity beforeReceiptIdentity afterReceiptIdentity
        recoveryIdentity) :
    SourceBoundEffectCompletionRecoveryOwnerCoveredStep
      expectation beforeBudget afterBudget owner := by
  cases audited with
  | runtimeCrash closed projection =>
      exact .runtimeCrash closed projection
  | scheduler closed projection =>
      exact .scheduler closed projection
  | completionStorage closed projection =>
      exact .completionStorage closed projection

theorem auditedOwnerCoveredStepOwnerIdentityPresent
    {expectation : SourceBoundEffectCompletionRecoveryExpectation}
    {beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget}
    {owner : SourceBoundEffectCompletionRecoveryProgressOwner}
    {ownerIdentity beforeReceiptIdentity afterReceiptIdentity
      recoveryIdentity : String}
    (audited :
      SourceBoundEffectCompletionRecoveryAuditedOwnerCoveredStep
        expectation beforeBudget afterBudget owner
        ownerIdentity beforeReceiptIdentity afterReceiptIdentity
        recoveryIdentity) :
    ownerIdentity ≠ "" := by
  cases audited with
  | runtimeCrash closed _ =>
      rw [closed.afterCloses.receiptRuntimeOwnerMatches]
      exact closed.afterCloses.runtimeOwnerIdentityPresent
  | scheduler closed _ =>
      rw [closed.afterCloses.receiptSchedulerOwnerMatches]
      exact
        closed.afterCloses.contractCloses.schedulerOwnerIdentityPresent
  | completionStorage closed _ =>
      rw [closed.afterCloses.receiptStorageOwnerMatches]
      exact closed.afterCloses.storageOwnerIdentityPresent

theorem auditedOwnerCoveredStepBeforeReceiptIdentityPresent
    {expectation : SourceBoundEffectCompletionRecoveryExpectation}
    {beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget}
    {owner : SourceBoundEffectCompletionRecoveryProgressOwner}
    {ownerIdentity beforeReceiptIdentity afterReceiptIdentity
      recoveryIdentity : String}
    (audited :
      SourceBoundEffectCompletionRecoveryAuditedOwnerCoveredStep
        expectation beforeBudget afterBudget owner
        ownerIdentity beforeReceiptIdentity afterReceiptIdentity
        recoveryIdentity) :
    beforeReceiptIdentity ≠ "" := by
  cases audited with
  | runtimeCrash closed _ =>
      exact closed.beforeCloses.receiptIdentityPresent
  | scheduler closed _ =>
      exact closed.beforeCloses.receiptIdentityPresent
  | completionStorage closed _ =>
      exact closed.beforeCloses.receiptIdentityPresent

theorem auditedOwnerCoveredStepAfterReceiptIdentityPresent
    {expectation : SourceBoundEffectCompletionRecoveryExpectation}
    {beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget}
    {owner : SourceBoundEffectCompletionRecoveryProgressOwner}
    {ownerIdentity beforeReceiptIdentity afterReceiptIdentity
      recoveryIdentity : String}
    (audited :
      SourceBoundEffectCompletionRecoveryAuditedOwnerCoveredStep
        expectation beforeBudget afterBudget owner
        ownerIdentity beforeReceiptIdentity afterReceiptIdentity
        recoveryIdentity) :
    afterReceiptIdentity ≠ "" := by
  cases audited with
  | runtimeCrash closed _ =>
      exact closed.afterCloses.receiptIdentityPresent
  | scheduler closed _ =>
      exact closed.afterCloses.receiptIdentityPresent
  | completionStorage closed _ =>
      exact closed.afterCloses.receiptIdentityPresent

theorem auditedOwnerCoveredStepReceiptIdentityAdvances
    {expectation : SourceBoundEffectCompletionRecoveryExpectation}
    {beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget}
    {owner : SourceBoundEffectCompletionRecoveryProgressOwner}
    {ownerIdentity beforeReceiptIdentity afterReceiptIdentity
      recoveryIdentity : String}
    (audited :
      SourceBoundEffectCompletionRecoveryAuditedOwnerCoveredStep
        expectation beforeBudget afterBudget owner
        ownerIdentity beforeReceiptIdentity afterReceiptIdentity
        recoveryIdentity) :
    afterReceiptIdentity ≠ beforeReceiptIdentity := by
  cases audited with
  | runtimeCrash closed _ =>
      exact closed.advanceCloses.receiptIdentityAdvances
  | scheduler closed _ =>
      exact closed.advanceCloses.receiptIdentityAdvances
  | completionStorage closed _ =>
      exact closed.advanceCloses.receiptIdentityAdvances

theorem auditedOwnerCoveredStepRecoveryMatchesExpectation
    {expectation : SourceBoundEffectCompletionRecoveryExpectation}
    {beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget}
    {owner : SourceBoundEffectCompletionRecoveryProgressOwner}
    {ownerIdentity beforeReceiptIdentity afterReceiptIdentity
      recoveryIdentity : String}
    (audited :
      SourceBoundEffectCompletionRecoveryAuditedOwnerCoveredStep
        expectation beforeBudget afterBudget owner
        ownerIdentity beforeReceiptIdentity afterReceiptIdentity
        recoveryIdentity) :
    recoveryIdentity = expectation.recoveryId := by
  cases audited with
  | runtimeCrash closed _ =>
      exact
        closed.afterCloses.receiptRecoveryMatches.trans
          closed.afterCloses.contractRecoveryMatches
  | scheduler closed _ =>
      exact
        closed.afterCloses.receiptRecoveryMatches.trans
          closed.afterCloses.contractCloses.recoveryMatches
  | completionStorage closed _ =>
      exact
        closed.afterCloses.receiptRecoveryMatches.trans
          closed.afterCloses.contractRecoveryMatches

theorem auditedOwnerCoveredStepOwnerUnique
    {expectation : SourceBoundEffectCompletionRecoveryExpectation}
    {beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget}
    {leftOwner rightOwner :
      SourceBoundEffectCompletionRecoveryProgressOwner}
    {leftOwnerIdentity leftBeforeReceiptIdentity
      leftAfterReceiptIdentity leftRecoveryIdentity : String}
    {rightOwnerIdentity rightBeforeReceiptIdentity
      rightAfterReceiptIdentity rightRecoveryIdentity : String}
    (left :
      SourceBoundEffectCompletionRecoveryAuditedOwnerCoveredStep
        expectation beforeBudget afterBudget leftOwner
        leftOwnerIdentity leftBeforeReceiptIdentity
        leftAfterReceiptIdentity leftRecoveryIdentity)
    (right :
      SourceBoundEffectCompletionRecoveryAuditedOwnerCoveredStep
        expectation beforeBudget afterBudget rightOwner
        rightOwnerIdentity rightBeforeReceiptIdentity
        rightAfterReceiptIdentity rightRecoveryIdentity) :
    leftOwner = rightOwner :=
  ownerCoveredStepOwnerUnique
    (auditedOwnerCoveredStepForgetsAuditIdentity left)
    (auditedOwnerCoveredStepForgetsAuditIdentity right)

structure SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
    (trace : SourceBoundEffectCompletionRecoveryTrace)
    (budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget)
    (scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope)
    (providerAcknowledgementStable : Nat → Prop)
    (expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation) :
    Type where
  currentGeneration :
    ∀ index,
      trace index ≠ .committed →
        scopes index = .current
  providerStable :
    ∀ index,
      trace index ≠ .committed →
        providerAcknowledgementStable index
  recoveryIdentity : String
  recoveryIdentityPresent : recoveryIdentity ≠ ""
  ownerAt : Nat → SourceBoundEffectCompletionRecoveryProgressOwner
  ownerIdentityAt : Nat → String
  receiptIdentityAt : Nat → String
  receiptIdentityPresent :
    ∀ index, receiptIdentityAt index ≠ ""
  receiptIdentityInjective :
    Function.Injective receiptIdentityAt
  auditedCoverage :
    ∀ index,
      trace index ≠ .committed →
        SourceBoundEffectCompletionRecoveryAuditedOwnerCoveredStep
          (expectations index)
          (budgets index)
          (budgets (index + 1))
          (ownerAt index)
          (ownerIdentityAt index)
          (receiptIdentityAt index)
          (receiptIdentityAt (index + 1))
          recoveryIdentity

def progressOwnerToAuditModel :
    SourceBoundEffectCompletionRecoveryProgressOwner →
      SourceBoundEffectCompletionRecoveryOwnerCoverageModel.ProgressOwnerModel
  | .runtimeCrashBudget => .runtimeCrashBudget
  | .schedulerAdmission => .schedulerAdmission
  | .completionStorageAdmission => .completionStorageAdmission

def auditWitnessEvidenceOwnerEvidenceAt
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    (evidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations)
    (index : Nat)
    (notCommitted : trace index ≠ .committed) :
    SourceBoundEffectCompletionRecoveryOwnerCoverageModel.OwnerEvidenceModel
      (progressOwnerToAuditModel (evidence.ownerAt index)) where
  ownerIdentity := evidence.ownerIdentityAt index
  ownerReceiptIdentity := evidence.receiptIdentityAt (index + 1)
  ownerIdentityPresent :=
    auditedOwnerCoveredStepOwnerIdentityPresent
      (evidence.auditedCoverage index notCommitted)
  ownerReceiptIdentityPresent :=
    auditedOwnerCoveredStepAfterReceiptIdentityPresent
      (evidence.auditedCoverage index notCommitted)

theorem auditWitnessEvidenceBuildsOwnerCoverage
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    (evidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations) :
    SourceBoundEffectCompletionRecoveryOwnerCoverageEvidence
      trace budgets scopes providerAcknowledgementStable expectations where
  currentGeneration := evidence.currentGeneration
  providerStable := evidence.providerStable
  ownerCoverage := by
    intro index notCommitted
    exact
      ⟨evidence.ownerAt index,
        auditedOwnerCoveredStepForgetsAuditIdentity
          (evidence.auditedCoverage index notCommitted)⟩

def auditWitnessBeforeReceiptIdentity
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    (evidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations)
    (index : Nat) : String :=
  evidence.receiptIdentityAt index

def auditWitnessAfterReceiptIdentity
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    (evidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations)
    (index : Nat) : String :=
  evidence.receiptIdentityAt (index + 1)

theorem auditWitnessEvidenceAdjacentReceiptIdentityContinuous
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    (evidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations)
    (index : Nat) :
    auditWitnessBeforeReceiptIdentity evidence (index + 1) =
      auditWitnessAfterReceiptIdentity evidence index := by
  rfl

theorem auditWitnessEvidenceReceiptIdentityNotReused
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    (evidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations)
    {leftIndex rightIndex : Nat}
    (identitiesEqual :
      evidence.receiptIdentityAt leftIndex =
        evidence.receiptIdentityAt rightIndex) :
    leftIndex = rightIndex :=
  evidence.receiptIdentityInjective identitiesEqual

theorem auditWitnessEvidenceTransitionReceiptAdvances
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    (evidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations)
    (index : Nat)
    (notCommitted : trace index ≠ .committed) :
    evidence.receiptIdentityAt (index + 1) ≠
      evidence.receiptIdentityAt index :=
  auditedOwnerCoveredStepReceiptIdentityAdvances
    (evidence.auditedCoverage index notCommitted)

theorem auditWitnessEvidenceRecoveryMatchesExpectation
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    (evidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations)
    (index : Nat)
    (notCommitted : trace index ≠ .committed) :
    evidence.recoveryIdentity = (expectations index).recoveryId :=
  auditedOwnerCoveredStepRecoveryMatchesExpectation
    (evidence.auditedCoverage index notCommitted)

theorem auditWitnessEvidenceRecoveryIdentityContinuous
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    (evidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations)
    (leftIndex rightIndex : Nat)
    (leftNotCommitted : trace leftIndex ≠ .committed)
    (rightNotCommitted : trace rightIndex ≠ .committed) :
    (expectations leftIndex).recoveryId =
      (expectations rightIndex).recoveryId := by
  rw [← auditWitnessEvidenceRecoveryMatchesExpectation
    evidence leftIndex leftNotCommitted]
  exact auditWitnessEvidenceRecoveryMatchesExpectation
    evidence rightIndex rightNotCommitted

theorem auditedOwnerCoverageConverges
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    (transitionClosed :
      SourceBoundEffectCompletionRecoveryTraceTransitionClosed trace)
    (evidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations) :
    SourceBoundEffectCompletionRecoveryTraceConverges trace :=
  closedOwnerCoverageConverges
    transitionClosed
    (auditWitnessEvidenceBuildsOwnerCoverage evidence)

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuditWitnessContinuityClosure
