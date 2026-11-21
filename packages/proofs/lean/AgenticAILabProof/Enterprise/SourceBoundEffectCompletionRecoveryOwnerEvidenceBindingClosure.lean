-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.CedarDualEngineAuthorization
import AgenticAILabProof.Enterprise.EvidenceFreshness
import AgenticAILabProof.Enterprise.HumanAuthorityAccountability
import AgenticAILabProof.Enterprise.SourceBoundDeterministicBudgetClosure
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionPublicationClosure
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryProgressEvidenceClosure

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerEvidenceBindingClosure

open CedarDualEngineAuthorization
open EvidenceFreshness
open HumanAuthorityAccountability
open SourceBoundCompositionalFixedPointClosure
open SourceBoundCycleObservationClosure
open SourceBoundDeterministicBudgetClosure
open SourceBoundEffectCompletionCrashRecoveryClosure
open SourceBoundEffectCompletionPublicationClosure
open SourceBoundEffectCompletionRecoveryConvergenceClosure
open SourceBoundEffectCompletionRecoveryProgressEvidenceClosure
open SourceBoundProgressEvidenceClosure

/--
An authorized assertion binds Cedar dual-engine evidence, accountable human
authority, freshness checks, capability, and recovery epoch to one complete
authorization subject.

This is a proof-only composition. It does not issue a Cedar receipt, authority
grant, freshness receipt, or runtime progress receipt.
-/
structure SourceBoundEffectCompletionRecoveryAuthorizedOwnerAssertion
    (semantics : DecisionSemantics)
    (decisionValid : DecisionReceiptValid)
    (authorityValid : AuthorityReceiptValid)
    (subject : AuthorizationSubject)
    (left right : DecisionReceipt)
    (grant : AuthorityGrant)
    (authorityReceipt : BoundAuthorityReceipt)
    (checks : Checks)
    (recoveryEpoch : Nat) : Prop where
  cedarClosed : dualDecisionEvidenceClosed semantics decisionValid left right
  cedarPermits : left.decision = .allow
  leftSubjectBinds : left.subject = subject
  rightSubjectBinds : right.subject = subject
  authorityClosed : authorityEvidenceClosed authorityValid grant authorityReceipt
  grantSubjectBinds : grant.scopeSubject = subject
  authorityReceiptSubjectBinds : authorityReceipt.subject = subject
  grantCapabilityApproves : grant.capability = .approve
  authorityReceiptCapabilityApproves : authorityReceipt.capability = .approve
  freshnessHolds : Hold checks
  recoveryEpochBinds : subject.epoch = recoveryEpoch

theorem authorizedOwnerAssertionClosesBothCedarPermits
    {semantics : DecisionSemantics}
    {decisionValid : DecisionReceiptValid}
    {authorityValid : AuthorityReceiptValid}
    {subject : AuthorizationSubject}
    {left right : DecisionReceipt}
    {grant : AuthorityGrant}
    {authorityReceipt : BoundAuthorityReceipt}
    {checks : Checks}
    {recoveryEpoch : Nat}
    (evidence :
      SourceBoundEffectCompletionRecoveryAuthorizedOwnerAssertion
        semantics
        decisionValid
        authorityValid
        subject
        left
        right
        grant
        authorityReceipt
        checks
        recoveryEpoch) :
    left.decision = .allow ∧ right.decision = .allow := by
  constructor
  · exact evidence.cedarPermits
  · calc
      right.decision = left.decision := evidence.cedarClosed.2.2.2.2.2.1.symm
      _ = .allow := evidence.cedarPermits

theorem dualCedarClosureWithDenyRejectsAuthorizedOwnerAssertion
    {semantics : DecisionSemantics}
    {decisionValid : DecisionReceiptValid}
    {authorityValid : AuthorityReceiptValid}
    {subject : AuthorizationSubject}
    {left right : DecisionReceipt}
    {grant : AuthorityGrant}
    {authorityReceipt : BoundAuthorityReceipt}
    {checks : Checks}
    {recoveryEpoch : Nat}
    (_closed : dualDecisionEvidenceClosed semantics decisionValid left right)
    (denied : left.decision = .deny) :
    ¬ SourceBoundEffectCompletionRecoveryAuthorizedOwnerAssertion
        semantics
        decisionValid
        authorityValid
        subject
        left
        right
        grant
        authorityReceipt
        checks
        recoveryEpoch := by
  intro evidence
  simpa [denied] using evidence.cedarPermits

theorem freshnessHoldDoesNotBindAuthorizationSubject
    (checks : Checks)
    (subject : AuthorizationSubject)
    (fresh : Hold checks) :
    ∃ distinctSubject : AuthorizationSubject,
      Hold checks ∧ distinctSubject ≠ subject := by
  let distinctSubject := { subject with epoch := subject.epoch + 1 }
  refine ⟨distinctSubject, fresh, ?_⟩
  intro subjectsEqual
  have epochsEqual :=
    congrArg AuthorizationSubject.epoch subjectsEqual
  have impossible : subject.epoch + 1 = subject.epoch := by
    simp [distinctSubject] at epochsEqual
  exact (Nat.ne_of_gt (Nat.lt_succ_self subject.epoch)) impossible

/--
The existing deterministic budget receipt projects only the scheduling
coordinate of the recovery progress budget. No crash or completion-storage
coordinate is inferred here.
-/
def SourceBoundEffectCompletionRecoveryDeterministicSchedulingProjection
    (receipt : SourceBoundDeterministicBudgetReceipt)
    (budget : SourceBoundEffectCompletionRecoveryProgressBudget) : Prop :=
  budget.remainingSchedulingDeferrals = receipt.schedulingRemaining

/--
A valid existing deterministic-budget closure plus the explicit scheduling
projection. The binding is proof-only and does not reinterpret the existing
semantic budget as a storage-admission budget.
-/
structure SourceBoundEffectCompletionRecoveryDeterministicSchedulingBinding
    (planValid : SourceBoundDeterministicBudgetPlanValid)
    (receiptValid : SourceBoundDeterministicBudgetReceiptValid)
    (fixedPointReceipt : SourceBoundFixedPointReceipt)
    (cycleObservation : SourceBoundCycleDetectedObservation)
    (progressReceipt : SourceBoundProgressReceipt)
    (plan : SourceBoundDeterministicBudgetPlan)
    (receipt : SourceBoundDeterministicBudgetReceipt)
    (budget : SourceBoundEffectCompletionRecoveryProgressBudget) : Prop where
  deterministicEvidenceClosed :
    SourceBoundDeterministicBudgetEvidenceClosed
      planValid
      receiptValid
      fixedPointReceipt
      cycleObservation
      progressReceipt
      plan
      receipt
  schedulingProjects :
    SourceBoundEffectCompletionRecoveryDeterministicSchedulingProjection
      receipt
      budget

theorem deterministicSchedulingProjectionDoesNotDetermineCrashBudget
    (receipt : SourceBoundDeterministicBudgetReceipt) :
    ∃ low high : SourceBoundEffectCompletionRecoveryProgressBudget,
      SourceBoundEffectCompletionRecoveryDeterministicSchedulingProjection receipt low ∧
      SourceBoundEffectCompletionRecoveryDeterministicSchedulingProjection receipt high ∧
      low.remainingStorageDeferrals = high.remainingStorageDeferrals ∧
      low.remainingCrashes ≠ high.remainingCrashes ∧
      low.rank ≠ high.rank := by
  let low : SourceBoundEffectCompletionRecoveryProgressBudget := {
    remainingCrashes := 0
    remainingSchedulingDeferrals := receipt.schedulingRemaining
    remainingStorageDeferrals := 0
  }
  let high : SourceBoundEffectCompletionRecoveryProgressBudget := {
    remainingCrashes := 1
    remainingSchedulingDeferrals := receipt.schedulingRemaining
    remainingStorageDeferrals := 0
  }
  refine ⟨low, high, rfl, rfl, rfl, ?_, ?_⟩
  · simp [low, high]
  · simp [low, high, SourceBoundEffectCompletionRecoveryProgressBudget.rank]

theorem deterministicSchedulingProjectionDoesNotDetermineStorageBudget
    (receipt : SourceBoundDeterministicBudgetReceipt) :
    ∃ low high : SourceBoundEffectCompletionRecoveryProgressBudget,
      SourceBoundEffectCompletionRecoveryDeterministicSchedulingProjection receipt low ∧
      SourceBoundEffectCompletionRecoveryDeterministicSchedulingProjection receipt high ∧
      low.remainingCrashes = high.remainingCrashes ∧
      low.remainingStorageDeferrals ≠ high.remainingStorageDeferrals ∧
      low.rank ≠ high.rank := by
  let low : SourceBoundEffectCompletionRecoveryProgressBudget := {
    remainingCrashes := 0
    remainingSchedulingDeferrals := receipt.schedulingRemaining
    remainingStorageDeferrals := 0
  }
  let high : SourceBoundEffectCompletionRecoveryProgressBudget := {
    remainingCrashes := 0
    remainingSchedulingDeferrals := receipt.schedulingRemaining
    remainingStorageDeferrals := 1
  }
  refine ⟨low, high, rfl, rfl, rfl, ?_, ?_⟩
  · simp [low, high]
  · simp [low, high, SourceBoundEffectCompletionRecoveryProgressBudget.rank]

theorem closedProviderObservationCannotJustifyUnchangedRecoveryProgress
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (observation : SourceBoundEffectProviderRecoveryObservation)
    (_closed :
      SourceBoundEffectProviderRecoveryObservationClosed
        receiptValid
        expectation
        observation)
    (budget : SourceBoundEffectCompletionRecoveryProgressBudget) :
    ¬ ∃ owner : SourceBoundEffectCompletionRecoveryProgressOwner,
      SourceBoundEffectCompletionRecoveryProgressReceipt budget budget owner := by
  rintro ⟨owner, receipt⟩
  exact unchangedRecoveryProgressBudgetHasNoOwnerReceipt receipt

theorem authorizedOwnerAssertionCannotJustifyUnchangedRecoveryProgress
    {semantics : DecisionSemantics}
    {decisionValid : DecisionReceiptValid}
    {authorityValid : AuthorityReceiptValid}
    {subject : AuthorizationSubject}
    {left right : DecisionReceipt}
    {grant : AuthorityGrant}
    {authorityReceipt : BoundAuthorityReceipt}
    {checks : Checks}
    {recoveryEpoch : Nat}
    (_authorized :
      SourceBoundEffectCompletionRecoveryAuthorizedOwnerAssertion
        semantics
        decisionValid
        authorityValid
        subject
        left
        right
        grant
        authorityReceipt
        checks
        recoveryEpoch)
    (budget : SourceBoundEffectCompletionRecoveryProgressBudget) :
    ¬ ∃ owner : SourceBoundEffectCompletionRecoveryProgressOwner,
      SourceBoundEffectCompletionRecoveryProgressReceipt budget budget owner := by
  rintro ⟨owner, receipt⟩
  exact unchangedRecoveryProgressBudgetHasNoOwnerReceipt receipt

theorem completionCommitReceiptDoesNotDeterminePrecommitStorageBudget
    (_receipt : SourceBoundEffectCompletionCommitReceipt) :
    ∃ low high : SourceBoundEffectCompletionRecoveryProgressBudget,
      low.remainingCrashes = high.remainingCrashes ∧
      low.remainingSchedulingDeferrals = high.remainingSchedulingDeferrals ∧
      low.remainingStorageDeferrals ≠ high.remainingStorageDeferrals ∧
      low.rank ≠ high.rank := by
  let low : SourceBoundEffectCompletionRecoveryProgressBudget := {
    remainingCrashes := 0
    remainingSchedulingDeferrals := 0
    remainingStorageDeferrals := 0
  }
  let high : SourceBoundEffectCompletionRecoveryProgressBudget := {
    remainingCrashes := 0
    remainingSchedulingDeferrals := 0
    remainingStorageDeferrals := 1
  }
  refine ⟨low, high, rfl, rfl, ?_, ?_⟩
  · simp [low, high]
  · simp [low, high, SourceBoundEffectCompletionRecoveryProgressBudget.rank]

/--
Existing owner gates compose with the already-proved progress evidence, but
they do not replace it. The convergence conclusion is intentionally obtained
only by reusing `closedProgressEvidenceConverges`.
-/
theorem closedOwnerGatesPreserveExistingConvergence
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {planValid : SourceBoundDeterministicBudgetPlanValid}
    {deterministicReceiptValid : SourceBoundDeterministicBudgetReceiptValid}
    {fixedPointReceipt : SourceBoundFixedPointReceipt}
    {cycleObservation : SourceBoundCycleDetectedObservation}
    {progressReceipt : SourceBoundProgressReceipt}
    {plan : SourceBoundDeterministicBudgetPlan}
    {deterministicReceipt : SourceBoundDeterministicBudgetReceipt}
    {projectedBudget : SourceBoundEffectCompletionRecoveryProgressBudget}
    {completionReceiptValid : SourceBoundEffectCompletionReceiptValid}
    {expectation : SourceBoundEffectCompletionRecoveryExpectation}
    {observation : SourceBoundEffectProviderRecoveryObservation}
    {semantics : DecisionSemantics}
    {decisionValid : DecisionReceiptValid}
    {authorityValid : AuthorityReceiptValid}
    {subject : AuthorizationSubject}
    {left right : DecisionReceipt}
    {grant : AuthorityGrant}
    {authorityReceipt : BoundAuthorityReceipt}
    {checks : Checks}
    {recoveryEpoch : Nat}
    (transitionClosed : SourceBoundEffectCompletionRecoveryTraceTransitionClosed trace)
    (progressEvidence :
      SourceBoundEffectCompletionRecoveryProgressEvidence
        trace
        budgets
        scopes
        providerAcknowledgementStable)
    (_schedulingBinding :
      SourceBoundEffectCompletionRecoveryDeterministicSchedulingBinding
        planValid
        deterministicReceiptValid
        fixedPointReceipt
        cycleObservation
        progressReceipt
        plan
        deterministicReceipt
        projectedBudget)
    (_providerClosed :
      SourceBoundEffectProviderRecoveryObservationClosed
        completionReceiptValid
        expectation
        observation)
    (_authorized :
      SourceBoundEffectCompletionRecoveryAuthorizedOwnerAssertion
        semantics
        decisionValid
        authorityValid
        subject
        left
        right
        grant
        authorityReceipt
        checks
        recoveryEpoch) :
    SourceBoundEffectCompletionRecoveryTraceConverges trace :=
  closedProgressEvidenceConverges transitionClosed progressEvidence

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerEvidenceBindingClosure
