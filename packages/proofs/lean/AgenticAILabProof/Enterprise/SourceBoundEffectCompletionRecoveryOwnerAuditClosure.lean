-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditModel
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCore
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerCoverageClosure

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditClosure

open SourceBoundCompositionalFixedPointClosure
open SourceBoundCycleObservationClosure
open SourceBoundDeterministicBudgetClosure
open SourceBoundEffectCompletionCrashRecoveryClosure
open SourceBoundEffectCompletionPublicationClosure
open SourceBoundEffectCompletionRecoveryConvergenceClosure
open SourceBoundEffectCompletionRecoveryOwnerAuditCore
open SourceBoundEffectCompletionRecoveryOwnerCoverageClosure
open SourceBoundEffectCompletionRecoveryOwnerDeferralAdmissionContractClosure
open SourceBoundEffectCompletionRecoveryProgressEvidenceClosure
open SourceBoundEffectCompletionRecoverySchedulingDeferralOwnerClosure
open SourceBoundProgressEvidenceClosure

/-!
# First-class recovery owner audit closure

Owner-native receipts remain the authority for each recovery transition.  This
closure adds one canonical, cross-owner audit chain that preserves the exact
native owner and receipt identities.  There is no compatibility, migration,
legacy, or fallback interpretation.
-/

inductive SourceBoundEffectCompletionRecoveryOwnerAuditBinding
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget)
    (witness :
      SourceBoundEffectCompletionRecoveryOwnerAuditWitness) : Prop where
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
          beforeReceipt afterReceipt beforeBudget afterBudget)
      (ownerMatches :
        witness.owner = .runtimeCrashBudget)
      (recoveryMatches :
        afterReceipt.recoveryId = witness.recoveryId)
      (ownerIdentityMatches :
        afterReceipt.runtimeOwnerIdentity = witness.ownerIdentity)
      (beforeReceiptMatches :
        beforeReceipt.receiptId = witness.beforeReceiptId)
      (afterReceiptMatches :
        afterReceipt.receiptId = witness.afterReceiptId)
      (runtimeEpochMatches :
        afterReceipt.runtimeEpoch = witness.runtimeEpoch)
      (activeFenceMatches :
        afterReceipt.activeFenceToken = witness.activeFenceToken) :
      SourceBoundEffectCompletionRecoveryOwnerAuditBinding
        expectation beforeBudget afterBudget witness
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
          beforeReceipt afterReceipt beforeBudget afterBudget)
      (ownerMatches :
        witness.owner = .schedulerAdmission)
      (recoveryMatches :
        afterReceipt.recoveryId = witness.recoveryId)
      (ownerIdentityMatches :
        afterReceipt.schedulerOwnerIdentity = witness.ownerIdentity)
      (beforeReceiptMatches :
        beforeReceipt.receiptId = witness.beforeReceiptId)
      (afterReceiptMatches :
        afterReceipt.receiptId = witness.afterReceiptId)
      (runtimeEpochMatches :
        afterReceipt.runtimeEpoch = witness.runtimeEpoch)
      (activeFenceMatches :
        afterReceipt.activeFenceToken = witness.activeFenceToken) :
      SourceBoundEffectCompletionRecoveryOwnerAuditBinding
        expectation beforeBudget afterBudget witness
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
          beforeReceipt afterReceipt beforeBudget afterBudget)
      (ownerMatches :
        witness.owner = .completionStorageAdmission)
      (recoveryMatches :
        afterReceipt.recoveryId = witness.recoveryId)
      (ownerIdentityMatches :
        afterReceipt.storageOwnerIdentity = witness.ownerIdentity)
      (beforeReceiptMatches :
        beforeReceipt.receiptId = witness.beforeReceiptId)
      (afterReceiptMatches :
        afterReceipt.receiptId = witness.afterReceiptId)
      (runtimeEpochMatches :
        afterReceipt.runtimeEpoch = witness.runtimeEpoch)
      (activeFenceMatches :
        afterReceipt.activeFenceToken = witness.activeFenceToken) :
      SourceBoundEffectCompletionRecoveryOwnerAuditBinding
        expectation beforeBudget afterBudget witness

theorem ownerAuditBindingBuildsOwnerCoveredStep
    {expectation : SourceBoundEffectCompletionRecoveryExpectation}
    {beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget}
    {witness :
      SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    (binding :
      SourceBoundEffectCompletionRecoveryOwnerAuditBinding
        expectation beforeBudget afterBudget witness) :
    SourceBoundEffectCompletionRecoveryOwnerCoveredStep
      expectation beforeBudget afterBudget witness.owner := by
  cases binding with
  | runtimeCrash closed projection ownerMatches =>
      simpa only [ownerMatches] using
        SourceBoundEffectCompletionRecoveryOwnerCoveredStep.runtimeCrash
          closed projection
  | scheduler closed projection ownerMatches =>
      simpa only [ownerMatches] using
        SourceBoundEffectCompletionRecoveryOwnerCoveredStep.scheduler
          closed projection
  | completionStorage closed projection ownerMatches =>
      simpa only [ownerMatches] using
        SourceBoundEffectCompletionRecoveryOwnerCoveredStep.completionStorage
          closed projection

theorem ownerAuditBindingForcesReceiptFreshness
    {expectation : SourceBoundEffectCompletionRecoveryExpectation}
    {beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget}
    {witness :
      SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    (binding :
      SourceBoundEffectCompletionRecoveryOwnerAuditBinding
        expectation beforeBudget afterBudget witness) :
    witness.beforeReceiptId ≠ witness.afterReceiptId := by
  cases binding with
  | runtimeCrash closed _ _ _ _ beforeMatches afterMatches =>
      intro reused
      apply closed.advanceCloses.receiptIdentityAdvances
      calc
        _ = witness.afterReceiptId := afterMatches
        _ = witness.beforeReceiptId := reused.symm
        _ = _ := beforeMatches.symm
  | scheduler closed _ _ _ _ beforeMatches afterMatches =>
      intro reused
      apply closed.advanceCloses.receiptIdentityAdvances
      calc
        _ = witness.afterReceiptId := afterMatches
        _ = witness.beforeReceiptId := reused.symm
        _ = _ := beforeMatches.symm
  | completionStorage closed _ _ _ _ beforeMatches afterMatches =>
      intro reused
      apply closed.advanceCloses.receiptIdentityAdvances
      calc
        _ = witness.afterReceiptId := afterMatches
        _ = witness.beforeReceiptId := reused.symm
        _ = _ := beforeMatches.symm

structure SourceBoundEffectCompletionRecoveryOwnerAuditEvidence
    (trace : SourceBoundEffectCompletionRecoveryTrace)
    (budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget)
    (scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope)
    (providerAcknowledgementStable : Nat → Prop)
    (expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation)
    (witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness) : Prop where
  currentGeneration :
    ∀ index,
      trace index ≠ .committed →
      scopes index = .current
  providerStable :
    ∀ index,
      trace index ≠ .committed →
      providerAcknowledgementStable index
  witnessValid :
    ∀ index,
      trace index ≠ .committed →
      (witnesses index).Valid
  ownerBinding :
    ∀ index,
      trace index ≠ .committed →
      SourceBoundEffectCompletionRecoveryOwnerAuditBinding
        (expectations index)
        (budgets index)
        (budgets (index + 1))
        (witnesses index)
  adjacent :
    ∀ index,
      trace index ≠ .committed →
      trace (index + 1) ≠ .committed →
      (witnesses index).Adjacent (witnesses (index + 1))
  globallyNonreusing :
    ∀ left right,
      left < right →
      trace left ≠ .committed →
      trace right ≠ .committed →
      (witnesses left).receiptKey ≠ (witnesses right).receiptKey

theorem closedOwnerAuditBuildsOwnerCoverage
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    (evidence :
      SourceBoundEffectCompletionRecoveryOwnerAuditEvidence
        trace budgets scopes providerAcknowledgementStable
        expectations witnesses) :
    SourceBoundEffectCompletionRecoveryOwnerCoverageEvidence
      trace budgets scopes providerAcknowledgementStable expectations := by
  refine
    {
      currentGeneration := evidence.currentGeneration
      providerStable := evidence.providerStable
      ownerCoverage := ?_
    }
  intro index notCommitted
  exact
    ⟨(witnesses index).owner,
      ownerAuditBindingBuildsOwnerCoveredStep
        (evidence.ownerBinding index notCommitted)⟩

theorem closedOwnerAuditConverges
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    (transitionClosed :
      SourceBoundEffectCompletionRecoveryTraceTransitionClosed trace)
    (evidence :
      SourceBoundEffectCompletionRecoveryOwnerAuditEvidence
        trace budgets scopes providerAcknowledgementStable
        expectations witnesses) :
    SourceBoundEffectCompletionRecoveryTraceConverges trace :=
  closedOwnerCoverageConverges
    transitionClosed
    (closedOwnerAuditBuildsOwnerCoverage evidence)

theorem emptyWitnessIdentityRejectsOwnerAudit
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {index : Nat}
    (notCommitted : trace index ≠ .committed)
    (empty : (witnesses index).witnessId = "") :
    ¬ SourceBoundEffectCompletionRecoveryOwnerAuditEvidence
        trace budgets scopes providerAcknowledgementStable
        expectations witnesses := by
  intro evidence
  exact (evidence.witnessValid index notCommitted).1 empty

theorem brokenPredecessorRejectsOwnerAudit
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {index : Nat}
    (currentNotCommitted : trace index ≠ .committed)
    (nextNotCommitted : trace (index + 1) ≠ .committed)
    (broken :
      (witnesses (index + 1)).previousWitnessId ≠
        some (witnesses index).witnessId) :
    ¬ SourceBoundEffectCompletionRecoveryOwnerAuditEvidence
        trace budgets scopes providerAcknowledgementStable
        expectations witnesses := by
  intro evidence
  exact broken
    (evidence.adjacent index currentNotCommitted nextNotCommitted).2.1

theorem reusedOwnerReceiptRejectsOwnerAudit
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {left right : Nat}
    (earlier : left < right)
    (leftNotCommitted : trace left ≠ .committed)
    (rightNotCommitted : trace right ≠ .committed)
    (reused :
      (witnesses left).receiptKey = (witnesses right).receiptKey) :
    ¬ SourceBoundEffectCompletionRecoveryOwnerAuditEvidence
        trace budgets scopes providerAcknowledgementStable
        expectations witnesses := by
  intro evidence
  exact
    (evidence.globallyNonreusing
      left right earlier leftNotCommitted rightNotCommitted) reused

theorem supersededNonCommittedStepRejectsOwnerAudit
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {index : Nat}
    (notCommitted : trace index ≠ .committed)
    (superseded : scopes index = .superseded) :
    ¬ SourceBoundEffectCompletionRecoveryOwnerAuditEvidence
        trace budgets scopes providerAcknowledgementStable
        expectations witnesses := by
  intro evidence
  have current := evidence.currentGeneration index notCommitted
  simp_all

theorem unstableProviderRejectsOwnerAudit
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {index : Nat}
    (notCommitted : trace index ≠ .committed)
    (unstable : ¬ providerAcknowledgementStable index) :
    ¬ SourceBoundEffectCompletionRecoveryOwnerAuditEvidence
        trace budgets scopes providerAcknowledgementStable
        expectations witnesses := by
  intro evidence
  exact unstable (evidence.providerStable index notCommitted)

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditClosure
