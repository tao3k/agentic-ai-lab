-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerDeferralAdmissionContractClosure
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoverySchedulingDeferralOwnerModel
import AgenticAILabProof.Enterprise.SourceBoundDeterministicBudgetClosure

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoverySchedulingDeferralOwnerClosure

open SourceBoundDeterministicBudgetClosure
open SourceBoundCompositionalFixedPointClosure
open SourceBoundCycleObservationClosure
open SourceBoundEffectCompletionCrashRecoveryClosure
open SourceBoundEffectCompletionRecoveryOwnerDeferralAdmissionContractModel
open SourceBoundEffectCompletionRecoveryProgressEvidenceClosure
open SourceBoundEffectCompletionRecoverySchedulingDeferralOwnerModel
open SourceBoundEffectReplayIdempotencyClosure
open SourceBoundProgressEvidenceClosure

/-!
# Recovery-scoped scheduler deferral ownership

The deterministic budget owner already records scheduling conservation, but
its receipt does not identify a recovery, runtime epoch, or active fence. This
proof-only model adds the smallest scheduler-owner contract needed to bind
that accounting to one recovery and to construct the existing scheduling
progress receipt.
-/

structure SourceBoundEffectCompletionRecoverySchedulingDeferralContract where
  contractId : String
  recoveryId : String
  schedulerOwnerIdentity : String
  budgetPlanId : DeterministicBudgetPlanId
  step : SourceBoundEffectReplayStep
  runtimeEpoch : Nat
  activeFenceToken : Nat
  maxDeferrals : Nat
  provenanceDigest : String
  deriving Repr

def SourceBoundEffectCompletionRecoverySchedulingDeferralContractValid :=
  SourceBoundEffectCompletionRecoverySchedulingDeferralContract → Prop

def SourceBoundEffectCompletionRecoverySchedulerPlanAuthority :=
  SourceBoundDeterministicBudgetPlan →
    SourceBoundEffectCompletionRecoverySchedulingDeferralContract → Prop

def schedulingDeferralContractMatchesDeterministicPlan
    (plan : SourceBoundDeterministicBudgetPlan)
    (contract :
      SourceBoundEffectCompletionRecoverySchedulingDeferralContract) : Prop :=
  contract.budgetPlanId = plan.planId ∧
    contract.maxDeferrals = plan.schedulingLimit

structure SourceBoundEffectCompletionRecoverySchedulingDeferralContractClosed
    (planValid : SourceBoundDeterministicBudgetPlanValid)
    (contractValid :
      SourceBoundEffectCompletionRecoverySchedulingDeferralContractValid)
    (schedulerAuthority :
      SourceBoundEffectCompletionRecoverySchedulerPlanAuthority)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (plan : SourceBoundDeterministicBudgetPlan)
    (contract :
      SourceBoundEffectCompletionRecoverySchedulingDeferralContract) :
    Prop where
  planValidates : planValid plan
  contractValidates : contractValid contract
  schedulerAuthorizesPlan : schedulerAuthority plan contract
  contractIdentityPresent : contract.contractId ≠ ""
  schedulerOwnerIdentityPresent : contract.schedulerOwnerIdentity ≠ ""
  contractProvenancePresent : contract.provenanceDigest ≠ ""
  recoveryMatches : contract.recoveryId = expectation.recoveryId
  exactStepMatches : contract.step = expectation.step
  runtimeEpochMatches : contract.runtimeEpoch = expectation.runtimeEpoch
  activeFenceMatches :
    contract.activeFenceToken = expectation.activeFenceToken
  deterministicPlanMatches :
    schedulingDeferralContractMatchesDeterministicPlan plan contract

abbrev SourceBoundEffectCompletionRecoverySchedulingAdmissionDecision :=
  SchedulingAdmissionDecision

structure SourceBoundEffectCompletionRecoverySchedulingDeferralReceipt where
  receiptId : String
  contractId : String
  recoveryId : String
  schedulerOwnerIdentity : String
  budgetReceiptId : DeterministicBudgetReceiptId
  runtimeEpoch : Nat
  activeFenceToken : Nat
  decision : SourceBoundEffectCompletionRecoverySchedulingAdmissionDecision
  decisionEvidenceDigest : String
  deferralsConsumed : Nat
  deferralsRemaining : Nat
  provenanceDigest : String
  deriving Repr

def SourceBoundEffectCompletionRecoverySchedulingDeferralReceiptValid :=
  SourceBoundEffectCompletionRecoverySchedulingDeferralReceipt → Prop

def schedulingAdmissionDecisionEvidenceClosed
    (receipt :
      SourceBoundEffectCompletionRecoverySchedulingDeferralReceipt) : Prop :=
  match receipt.decision with
  | .admitted => True
  | .deferred => 0 < receipt.deferralsRemaining
  | .rejected => True

structure SourceBoundEffectCompletionRecoverySchedulingDeferralReceiptClosed
    (planValid : SourceBoundDeterministicBudgetPlanValid)
    (budgetReceiptValid : SourceBoundDeterministicBudgetReceiptValid)
    (contractValid :
      SourceBoundEffectCompletionRecoverySchedulingDeferralContractValid)
    (receiptValid :
      SourceBoundEffectCompletionRecoverySchedulingDeferralReceiptValid)
    (schedulerAuthority :
      SourceBoundEffectCompletionRecoverySchedulerPlanAuthority)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (fixedPoint : SourceBoundFixedPointReceipt)
    (cycle : SourceBoundCycleDetectedObservation)
    (progress : SourceBoundProgressReceipt)
    (plan : SourceBoundDeterministicBudgetPlan)
    (budgetReceipt : SourceBoundDeterministicBudgetReceipt)
    (contract :
      SourceBoundEffectCompletionRecoverySchedulingDeferralContract)
    (receipt :
      SourceBoundEffectCompletionRecoverySchedulingDeferralReceipt) :
    Prop where
  contractCloses :
    SourceBoundEffectCompletionRecoverySchedulingDeferralContractClosed
      planValid
      contractValid
      schedulerAuthority
      expectation
      plan
      contract
  budgetEvidenceCloses :
    SourceBoundDeterministicBudgetEvidenceClosed
      planValid
      budgetReceiptValid
      fixedPoint
      cycle
      progress
      plan
      budgetReceipt
  receiptValidates : receiptValid receipt
  receiptIdentityPresent : receipt.receiptId ≠ ""
  decisionEvidencePresent : receipt.decisionEvidenceDigest ≠ ""
  receiptProvenancePresent : receipt.provenanceDigest ≠ ""
  receiptContractMatches : receipt.contractId = contract.contractId
  receiptRecoveryMatches : receipt.recoveryId = contract.recoveryId
  receiptSchedulerOwnerMatches :
    receipt.schedulerOwnerIdentity = contract.schedulerOwnerIdentity
  receiptBudgetMatches : receipt.budgetReceiptId = budgetReceipt.receiptId
  receiptRuntimeEpochMatches : receipt.runtimeEpoch = contract.runtimeEpoch
  receiptFenceMatches :
    receipt.activeFenceToken = contract.activeFenceToken
  receiptConsumedMatches :
    receipt.deferralsConsumed = budgetReceipt.schedulingConsumed
  receiptRemainingMatches :
    receipt.deferralsRemaining = budgetReceipt.schedulingRemaining
  accountingCloses :
    receipt.deferralsConsumed + receipt.deferralsRemaining =
      contract.maxDeferrals
  decisionEvidenceCloses :
    schedulingAdmissionDecisionEvidenceClosed receipt

structure SourceBoundEffectCompletionRecoverySchedulingDeferralAdvance
    (before after :
      SourceBoundEffectCompletionRecoverySchedulingDeferralReceipt) :
    Prop where
  beforeIsDeferred :
    before.decision =
      SchedulingAdmissionDecision.deferred
  receiptIdentityAdvances : after.receiptId ≠ before.receiptId
  contractStable : after.contractId = before.contractId
  recoveryStable : after.recoveryId = before.recoveryId
  schedulerOwnerStable :
    after.schedulerOwnerIdentity = before.schedulerOwnerIdentity
  runtimeEpochStable : after.runtimeEpoch = before.runtimeEpoch
  activeFenceStable : after.activeFenceToken = before.activeFenceToken
  consumedAdvances :
    after.deferralsConsumed = before.deferralsConsumed + 1
  remainingDecreases :
    before.deferralsRemaining = after.deferralsRemaining + 1

structure SourceBoundEffectCompletionRecoverySchedulingDeferralTransitionClosed
    (planValid : SourceBoundDeterministicBudgetPlanValid)
    (budgetReceiptValid : SourceBoundDeterministicBudgetReceiptValid)
    (contractValid :
      SourceBoundEffectCompletionRecoverySchedulingDeferralContractValid)
    (receiptValid :
      SourceBoundEffectCompletionRecoverySchedulingDeferralReceiptValid)
    (schedulerAuthority :
      SourceBoundEffectCompletionRecoverySchedulerPlanAuthority)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (fixedPoint : SourceBoundFixedPointReceipt)
    (cycle : SourceBoundCycleDetectedObservation)
    (beforeProgress afterProgress : SourceBoundProgressReceipt)
    (plan : SourceBoundDeterministicBudgetPlan)
    (beforeBudgetReceipt afterBudgetReceipt :
      SourceBoundDeterministicBudgetReceipt)
    (contract :
      SourceBoundEffectCompletionRecoverySchedulingDeferralContract)
    (beforeReceipt afterReceipt :
      SourceBoundEffectCompletionRecoverySchedulingDeferralReceipt) :
    Prop where
  beforeCloses :
    SourceBoundEffectCompletionRecoverySchedulingDeferralReceiptClosed
      planValid
      budgetReceiptValid
      contractValid
      receiptValid
      schedulerAuthority
      expectation
      fixedPoint
      cycle
      beforeProgress
      plan
      beforeBudgetReceipt
      contract
      beforeReceipt
  afterCloses :
    SourceBoundEffectCompletionRecoverySchedulingDeferralReceiptClosed
      planValid
      budgetReceiptValid
      contractValid
      receiptValid
      schedulerAuthority
      expectation
      fixedPoint
      cycle
      afterProgress
      plan
      afterBudgetReceipt
      contract
      afterReceipt
  budgetReceiptIdentityAdvances :
    afterBudgetReceipt.receiptId ≠ beforeBudgetReceipt.receiptId
  progressReceiptIdentityAdvances :
    afterProgress.receiptId ≠ beforeProgress.receiptId
  advanceCloses :
    SourceBoundEffectCompletionRecoverySchedulingDeferralAdvance
      beforeReceipt afterReceipt

theorem closedSchedulingDeferralAdvanceStrictlyDecreases
    {before after :
      SourceBoundEffectCompletionRecoverySchedulingDeferralReceipt}
    (advance :
      SourceBoundEffectCompletionRecoverySchedulingDeferralAdvance
        before after) :
    after.deferralsRemaining < before.deferralsRemaining := by
  exact
    schedulingDeferralStepStrictlyDecreases
      (before := {
          decision := before.decision
          remaining := before.deferralsRemaining
        })
      (after := {
          decision := after.decision
          remaining := after.deferralsRemaining
        })
      ⟨advance.beforeIsDeferred, advance.remainingDecreases⟩

theorem unchangedSchedulingDeferralReceiptCannotAdvance
    (receipt :
      SourceBoundEffectCompletionRecoverySchedulingDeferralReceipt) :
    ¬ SourceBoundEffectCompletionRecoverySchedulingDeferralAdvance
      receipt receipt := by
  intro advance
  exact
    (Nat.lt_irrefl receipt.deferralsRemaining)
      (closedSchedulingDeferralAdvanceStrictlyDecreases advance)

theorem admittedSchedulingReceiptCannotAdvanceAsDeferral
    {before after :
      SourceBoundEffectCompletionRecoverySchedulingDeferralReceipt}
    (admitted :
      before.decision =
        SchedulingAdmissionDecision.admitted) :
    ¬ SourceBoundEffectCompletionRecoverySchedulingDeferralAdvance
      before after := by
  intro advance
  have impossible := advance.beforeIsDeferred
  rw [admitted] at impossible
  contradiction

theorem rejectedSchedulingReceiptCannotAdvanceAsDeferral
    {before after :
      SourceBoundEffectCompletionRecoverySchedulingDeferralReceipt}
    (rejected :
      before.decision =
        SchedulingAdmissionDecision.rejected) :
    ¬ SourceBoundEffectCompletionRecoverySchedulingDeferralAdvance
      before after := by
  intro advance
  have impossible := advance.beforeIsDeferred
  rw [rejected] at impossible
  contradiction

def schedulingDeferralContractCandidate
    (plan : SourceBoundDeterministicBudgetPlan)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (contractId schedulerOwnerIdentity : String) :
    SourceBoundEffectCompletionRecoverySchedulingDeferralContract :=
  {
    contractId
    recoveryId := expectation.recoveryId
    schedulerOwnerIdentity
    budgetPlanId := plan.planId
    step := expectation.step
    runtimeEpoch := expectation.runtimeEpoch
    activeFenceToken := expectation.activeFenceToken
    maxDeferrals := plan.schedulingLimit
    provenanceDigest := "proof-only-scheduling-deferral-candidate"
  }

theorem deterministicPlanAndRecoveryDoNotDetermineSchedulerAuthority
    (plan : SourceBoundDeterministicBudgetPlan)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation) :
    schedulingDeferralContractMatchesDeterministicPlan
        plan
        (schedulingDeferralContractCandidate
          plan expectation "scheduler-contract-a" "scheduler-owner-a") ∧
      schedulingDeferralContractMatchesDeterministicPlan
        plan
        (schedulingDeferralContractCandidate
          plan expectation "scheduler-contract-b" "scheduler-owner-b") ∧
      (schedulingDeferralContractCandidate
          plan expectation
          "scheduler-contract-a"
          "scheduler-owner-a").schedulerOwnerIdentity ≠
        (schedulingDeferralContractCandidate
          plan expectation
          "scheduler-contract-b"
          "scheduler-owner-b").schedulerOwnerIdentity := by
  simp [
    schedulingDeferralContractMatchesDeterministicPlan,
    schedulingDeferralContractCandidate
  ]

structure SourceBoundEffectCompletionRecoverySchedulingDeferralProgressProjection
    (beforeReceipt afterReceipt :
      SourceBoundEffectCompletionRecoverySchedulingDeferralReceipt)
    (beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget) :
    Prop where
  beforeSchedulingMatches :
    beforeBudget.remainingSchedulingDeferrals =
      beforeReceipt.deferralsRemaining
  afterSchedulingMatches :
    afterBudget.remainingSchedulingDeferrals =
      afterReceipt.deferralsRemaining
  crashesStable :
    afterBudget.remainingCrashes = beforeBudget.remainingCrashes
  storageStable :
    afterBudget.remainingStorageDeferrals =
      beforeBudget.remainingStorageDeferrals

theorem closedSchedulingDeferralTransitionBuildsProgressReceipt
    {planValid : SourceBoundDeterministicBudgetPlanValid}
    {budgetReceiptValid : SourceBoundDeterministicBudgetReceiptValid}
    {contractValid :
      SourceBoundEffectCompletionRecoverySchedulingDeferralContractValid}
    {receiptValid :
      SourceBoundEffectCompletionRecoverySchedulingDeferralReceiptValid}
    {schedulerAuthority :
      SourceBoundEffectCompletionRecoverySchedulerPlanAuthority}
    {expectation : SourceBoundEffectCompletionRecoveryExpectation}
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
    {beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget}
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
    SourceBoundEffectCompletionRecoveryProgressReceipt
      beforeBudget afterBudget .schedulerAdmission := by
  apply
    SourceBoundEffectCompletionRecoveryProgressReceipt.schedulingDeferralDecreased
  · exact projection.crashesStable
  · rw [
      projection.beforeSchedulingMatches,
      projection.afterSchedulingMatches
    ]
    exact
      closedSchedulingDeferralAdvanceStrictlyDecreases
        closed.advanceCloses
  · exact projection.storageStable

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoverySchedulingDeferralOwnerClosure
