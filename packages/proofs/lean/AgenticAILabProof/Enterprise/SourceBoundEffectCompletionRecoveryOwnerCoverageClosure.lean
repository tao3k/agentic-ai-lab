-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerCoverageModel
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoverySchedulingDeferralOwnerClosure

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerCoverageClosure

open SourceBoundCompositionalFixedPointClosure
open SourceBoundCycleObservationClosure
open SourceBoundDeterministicBudgetClosure
open SourceBoundEffectCompletionCrashRecoveryClosure
open SourceBoundEffectCompletionPublicationClosure
open SourceBoundEffectCompletionRecoveryConvergenceClosure
open SourceBoundEffectCompletionRecoveryOwnerCoverageModel
open SourceBoundEffectCompletionRecoveryOwnerDeferralAdmissionContractClosure
open SourceBoundEffectCompletionRecoveryProgressEvidenceClosure
open SourceBoundEffectCompletionRecoverySchedulingDeferralOwnerClosure
open SourceBoundProgressEvidenceClosure

/-!
# Atomic owner coverage for every non-committed recovery step

The generic progress receipt proves a rank decrease.  It does not by itself
prove which external runtime, scheduler, or storage receipt justified that
decrease.  This closure requires one owner-native transition witness for every
non-committed step and projects that witness into the existing convergence
algebra.
-/

inductive SourceBoundEffectCompletionRecoveryOwnerCoveredStep
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget) :
    SourceBoundEffectCompletionRecoveryProgressOwner → Prop where
  | runtimeCrash
      {contractValid :
        SourceBoundEffectCompletionRecoveryCrashDeferralContractValid}
      {receiptValid :
        SourceBoundEffectCompletionRecoveryCrashDeferralReceiptValid}
      {contract :
        SourceBoundEffectCompletionRecoveryCrashDeferralContract}
      {beforeReceipt afterReceipt :
        SourceBoundEffectCompletionRecoveryCrashDeferralReceipt}
      (closed :
        SourceBoundEffectCompletionRecoveryCrashDeferralTransitionClosed
          contractValid receiptValid expectation contract
          beforeReceipt afterReceipt)
      (projection :
        SourceBoundEffectCompletionRecoveryCrashDeferralProgressProjection
          beforeReceipt afterReceipt beforeBudget afterBudget) :
      SourceBoundEffectCompletionRecoveryOwnerCoveredStep
        expectation beforeBudget afterBudget .runtimeCrashBudget
  | scheduler
      {planValid : SourceBoundDeterministicBudgetPlanValid}
      {budgetReceiptValid : SourceBoundDeterministicBudgetReceiptValid}
      {contractValid :
        SourceBoundEffectCompletionRecoverySchedulingDeferralContractValid}
      {receiptValid :
        SourceBoundEffectCompletionRecoverySchedulingDeferralReceiptValid}
      {schedulerAuthority :
        SourceBoundEffectCompletionRecoverySchedulerPlanAuthority}
      {fixedPoint : SourceBoundFixedPointReceipt}
      {cycle : SourceBoundCycleDetectedObservation}
      {beforeProgress afterProgress : SourceBoundProgressReceipt}
      {plan : SourceBoundDeterministicBudgetPlan}
      {beforeBudgetReceipt afterBudgetReceipt :
        SourceBoundDeterministicBudgetReceipt}
      {contract :
        SourceBoundEffectCompletionRecoverySchedulingDeferralContract}
      {beforeReceipt afterReceipt :
        SourceBoundEffectCompletionRecoverySchedulingDeferralReceipt}
      (closed :
        SourceBoundEffectCompletionRecoverySchedulingDeferralTransitionClosed
          planValid
          budgetReceiptValid
          contractValid
          receiptValid
          schedulerAuthority
          expectation
          fixedPoint
          cycle
          beforeProgress
          afterProgress
          plan
          beforeBudgetReceipt
          afterBudgetReceipt
          contract
          beforeReceipt
          afterReceipt)
      (projection :
        SourceBoundEffectCompletionRecoverySchedulingDeferralProgressProjection
          beforeReceipt afterReceipt beforeBudget afterBudget) :
      SourceBoundEffectCompletionRecoveryOwnerCoveredStep
        expectation beforeBudget afterBudget .schedulerAdmission
  | completionStorage
      {contractValid :
        SourceBoundEffectCompletionPrecommitStorageAdmissionContractValid}
      {receiptValid :
        SourceBoundEffectCompletionPrecommitStorageAdmissionReceiptValid}
      {publication : SourceBoundEffectCompletionPublication}
      {contract :
        SourceBoundEffectCompletionPrecommitStorageAdmissionContract}
      {beforeReceipt afterReceipt :
        SourceBoundEffectCompletionPrecommitStorageAdmissionReceipt}
      (closed :
        SourceBoundEffectCompletionPrecommitStorageDeferralTransitionClosed
          contractValid receiptValid expectation publication contract
          beforeReceipt afterReceipt)
      (projection :
        SourceBoundEffectCompletionRecoveryStorageDeferralProgressProjection
          beforeReceipt afterReceipt beforeBudget afterBudget) :
      SourceBoundEffectCompletionRecoveryOwnerCoveredStep
        expectation beforeBudget afterBudget .completionStorageAdmission

theorem ownerCoveredStepBuildsProgressReceipt
    {expectation : SourceBoundEffectCompletionRecoveryExpectation}
    {beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget}
    {owner : SourceBoundEffectCompletionRecoveryProgressOwner}
    (covered :
      SourceBoundEffectCompletionRecoveryOwnerCoveredStep
        expectation beforeBudget afterBudget owner) :
    SourceBoundEffectCompletionRecoveryProgressReceipt
      beforeBudget afterBudget owner := by
  cases covered with
  | runtimeCrash closed projection =>
      exact
        closedCrashDeferralTransitionBuildsProgressReceipt
          closed projection
  | scheduler closed projection =>
      exact
        closedSchedulingDeferralTransitionBuildsProgressReceipt
          closed projection
  | completionStorage closed projection =>
      exact
        closedStorageDeferralTransitionBuildsProgressReceipt
          closed projection

theorem ownerCoveredStepOwnerUnique
    {expectation : SourceBoundEffectCompletionRecoveryExpectation}
    {beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget}
    {leftOwner rightOwner :
      SourceBoundEffectCompletionRecoveryProgressOwner}
    (left :
      SourceBoundEffectCompletionRecoveryOwnerCoveredStep
        expectation beforeBudget afterBudget leftOwner)
    (right :
      SourceBoundEffectCompletionRecoveryOwnerCoveredStep
        expectation beforeBudget afterBudget rightOwner) :
    leftOwner = rightOwner :=
  recoveryProgressReceiptOwnerUnique
    (ownerCoveredStepBuildsProgressReceipt left)
    (ownerCoveredStepBuildsProgressReceipt right)

structure SourceBoundEffectCompletionRecoveryOwnerCoverageEvidence
    (trace : SourceBoundEffectCompletionRecoveryTrace)
    (budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget)
    (scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope)
    (providerAcknowledgementStable : Nat → Prop)
    (expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation) : Prop where
  currentGeneration :
    ∀ index,
      trace index ≠ .committed →
      scopes index = .current
  providerStable :
    ∀ index,
      trace index ≠ .committed →
      providerAcknowledgementStable index
  ownerCoverage :
    ∀ index,
      trace index ≠ .committed →
      ∃ owner,
        SourceBoundEffectCompletionRecoveryOwnerCoveredStep
          (expectations index)
          (budgets index)
          (budgets (index + 1))
          owner

theorem closedOwnerCoverageBuildsProgressEvidence
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    (evidence :
      SourceBoundEffectCompletionRecoveryOwnerCoverageEvidence
        trace
        budgets
        scopes
        providerAcknowledgementStable
        expectations) :
    SourceBoundEffectCompletionRecoveryProgressEvidence
      trace
      budgets
      scopes
      providerAcknowledgementStable := by
  refine
    {
      currentGeneration := evidence.currentGeneration
      providerStable := evidence.providerStable
      progress := ?_
    }
  intro index notCommitted
  obtain ⟨owner, covered⟩ :=
    evidence.ownerCoverage index notCommitted
  exact ⟨owner, ownerCoveredStepBuildsProgressReceipt covered⟩

theorem closedOwnerCoverageConverges
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    (transitionClosed :
      SourceBoundEffectCompletionRecoveryTraceTransitionClosed trace)
    (evidence :
      SourceBoundEffectCompletionRecoveryOwnerCoverageEvidence
        trace
        budgets
        scopes
        providerAcknowledgementStable
        expectations) :
    SourceBoundEffectCompletionRecoveryTraceConverges trace :=
  closedProgressEvidenceConverges
    transitionClosed
    (closedOwnerCoverageBuildsProgressEvidence evidence)

theorem supersededNonCommittedStepRejectsOwnerCoverage
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {index : Nat}
    (notCommitted : trace index ≠ .committed)
    (superseded : scopes index = .superseded) :
    ¬ SourceBoundEffectCompletionRecoveryOwnerCoverageEvidence
        trace
        budgets
        scopes
        providerAcknowledgementStable
        expectations := by
  intro evidence
  have current := evidence.currentGeneration index notCommitted
  simp_all

theorem unstableProviderRejectsOwnerCoverage
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {index : Nat}
    (notCommitted : trace index ≠ .committed)
    (unstable : ¬ providerAcknowledgementStable index) :
    ¬ SourceBoundEffectCompletionRecoveryOwnerCoverageEvidence
        trace
        budgets
        scopes
        providerAcknowledgementStable
        expectations := by
  intro evidence
  exact unstable (evidence.providerStable index notCommitted)

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerCoverageClosure
