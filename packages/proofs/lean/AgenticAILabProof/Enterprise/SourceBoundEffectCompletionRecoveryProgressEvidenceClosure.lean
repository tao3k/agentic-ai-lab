-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryConvergenceClosure

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryProgressEvidenceClosure

open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryConvergenceClosure

inductive SourceBoundEffectCompletionRecoveryProgressOwner where
  | runtimeCrashBudget
  | schedulerAdmission
  | completionStorageAdmission
deriving DecidableEq, Repr

structure SourceBoundEffectCompletionRecoveryProgressBudget where
  remainingCrashes : Nat
  remainingSchedulingDeferrals : Nat
  remainingStorageDeferrals : Nat
deriving DecidableEq, Repr

def SourceBoundEffectCompletionRecoveryProgressBudget.rank
    (budget : SourceBoundEffectCompletionRecoveryProgressBudget) : Nat :=
  budget.remainingCrashes
    + budget.remainingSchedulingDeferrals
    + budget.remainingStorageDeferrals

inductive SourceBoundEffectCompletionRecoveryProgressReceipt
    (before after : SourceBoundEffectCompletionRecoveryProgressBudget) :
    SourceBoundEffectCompletionRecoveryProgressOwner → Prop where
  | crashBudgetDecreased
      (crashes :
        after.remainingCrashes < before.remainingCrashes)
      (scheduling :
        after.remainingSchedulingDeferrals
          = before.remainingSchedulingDeferrals)
      (storage :
        after.remainingStorageDeferrals
          = before.remainingStorageDeferrals) :
      SourceBoundEffectCompletionRecoveryProgressReceipt
        before
        after
        .runtimeCrashBudget
  | schedulingDeferralDecreased
      (crashes :
        after.remainingCrashes = before.remainingCrashes)
      (scheduling :
        after.remainingSchedulingDeferrals
          < before.remainingSchedulingDeferrals)
      (storage :
        after.remainingStorageDeferrals
          = before.remainingStorageDeferrals) :
      SourceBoundEffectCompletionRecoveryProgressReceipt
        before
        after
        .schedulerAdmission
  | storageDeferralDecreased
      (crashes :
        after.remainingCrashes = before.remainingCrashes)
      (scheduling :
        after.remainingSchedulingDeferrals
          = before.remainingSchedulingDeferrals)
      (storage :
        after.remainingStorageDeferrals
          < before.remainingStorageDeferrals) :
      SourceBoundEffectCompletionRecoveryProgressReceipt
        before
        after
        .completionStorageAdmission

theorem recoveryProgressReceiptStrictlyDecreasesRank
    {owner : SourceBoundEffectCompletionRecoveryProgressOwner}
    {before after : SourceBoundEffectCompletionRecoveryProgressBudget}
    (receipt :
      SourceBoundEffectCompletionRecoveryProgressReceipt
        before
        after
        owner) :
    after.rank < before.rank := by
  cases receipt with
  | crashBudgetDecreased crashes scheduling storage =>
      exact
        Nat.add_lt_add_of_lt_of_le
          (Nat.add_lt_add_of_lt_of_le crashes (Nat.le_of_eq scheduling))
          (Nat.le_of_eq storage)
  | schedulingDeferralDecreased crashes scheduling storage =>
      exact
        Nat.add_lt_add_of_lt_of_le
          (Nat.add_lt_add_of_le_of_lt (Nat.le_of_eq crashes) scheduling)
          (Nat.le_of_eq storage)
  | storageDeferralDecreased crashes scheduling storage =>
      exact
        Nat.add_lt_add_of_le_of_lt
          (Nat.add_le_add
            (Nat.le_of_eq crashes)
            (Nat.le_of_eq scheduling))
          storage

theorem recoveryProgressReceiptOwnerUnique
    {before after : SourceBoundEffectCompletionRecoveryProgressBudget}
    {leftOwner rightOwner :
      SourceBoundEffectCompletionRecoveryProgressOwner}
    (left :
      SourceBoundEffectCompletionRecoveryProgressReceipt
        before after leftOwner)
    (right :
      SourceBoundEffectCompletionRecoveryProgressReceipt
        before after rightOwner) :
    leftOwner = rightOwner := by
  cases left <;> cases right <;> simp_all

theorem unchangedRecoveryProgressBudgetHasNoOwnerReceipt
    {owner : SourceBoundEffectCompletionRecoveryProgressOwner}
    {budget : SourceBoundEffectCompletionRecoveryProgressBudget} :
    ¬ SourceBoundEffectCompletionRecoveryProgressReceipt
        budget
        budget
        owner := by
  intro receipt
  exact
    (Nat.lt_irrefl budget.rank)
      (recoveryProgressReceiptStrictlyDecreasesRank receipt)

inductive SourceBoundEffectCompletionRecoveryProgressScope where
  | current
  | superseded
deriving DecidableEq, Repr

structure SourceBoundEffectCompletionRecoveryProgressEvidence
    (trace : SourceBoundEffectCompletionRecoveryTrace)
    (budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget)
    (scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope)
    (providerAcknowledgementStable : Nat → Prop) : Prop where
  currentGeneration :
    ∀ index,
      trace index ≠ .committed →
      scopes index = .current
  providerStable :
    ∀ index,
      trace index ≠ .committed →
      providerAcknowledgementStable index
  progress :
    ∀ index,
      trace index ≠ .committed →
      ∃ owner,
        SourceBoundEffectCompletionRecoveryProgressReceipt
          (budgets index)
          (budgets (index + 1))
          owner

theorem closedProgressEvidenceBuildsStrictRecoveryRank
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    (evidence :
      SourceBoundEffectCompletionRecoveryProgressEvidence
        trace
        budgets
        scopes
        providerAcknowledgementStable) :
    SourceBoundEffectCompletionRecoveryTraceStrictlyRanked
      trace
      (fun index => (budgets index).rank) := by
  intro index notCommitted
  obtain ⟨owner, receipt⟩ := evidence.progress index notCommitted
  exact
    recoveryProgressReceiptStrictlyDecreasesRank
      receipt

theorem closedProgressEvidenceConverges
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    (transitionClosed :
      SourceBoundEffectCompletionRecoveryTraceTransitionClosed trace)
    (evidence :
      SourceBoundEffectCompletionRecoveryProgressEvidence
        trace
        budgets
        scopes
        providerAcknowledgementStable) :
    SourceBoundEffectCompletionRecoveryTraceConverges trace := by
  apply rankedTransitionClosedRecoveryTraceConverges
  · exact transitionClosed
  · exact closedProgressEvidenceBuildsStrictRecoveryRank evidence

theorem supersededNonCommittedStepRejectsClosedProgressEvidence
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {index : Nat}
    (notCommitted : trace index ≠ .committed)
    (superseded : scopes index = .superseded) :
    ¬ SourceBoundEffectCompletionRecoveryProgressEvidence
        trace
        budgets
        scopes
        providerAcknowledgementStable := by
  intro evidence
  have current := evidence.currentGeneration index notCommitted
  cases superseded ▸ current

theorem stalledRecoveryRejectsConcreteProgressEvidence
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop} :
    ¬ SourceBoundEffectCompletionRecoveryProgressEvidence
        stalledExecutedUncommittedRecoveryTrace
        budgets
        scopes
        providerAcknowledgementStable := by
  intro evidence
  exact
    stalledRecoveryTraceHasNoStrictNaturalRank
      (fun index => (budgets index).rank)
      (closedProgressEvidenceBuildsStrictRecoveryRank evidence)

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryProgressEvidenceClosure
