-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoverySchedulingDeferralOwnerModel

structure DeterministicSchedulingProjection where
  budgetPlanIdentity : String
  maxDeferrals : Nat
  deriving DecidableEq, Repr

structure RecoverySchedulingProjection where
  recoveryIdentity : String
  stepIdentity : String
  runtimeEpoch : Nat
  activeFenceToken : Nat
  deriving DecidableEq, Repr

structure SchedulerOwnerContractModel where
  deterministic : DeterministicSchedulingProjection
  recovery : RecoverySchedulingProjection
  schedulerOwnerIdentity : String
  deriving DecidableEq, Repr

def schedulerOwnerContractCandidate
    (deterministic : DeterministicSchedulingProjection)
    (recovery : RecoverySchedulingProjection)
    (schedulerOwnerIdentity : String) :
    SchedulerOwnerContractModel :=
  { deterministic, recovery, schedulerOwnerIdentity }

theorem planAndRecoveryProjectionDoNotDetermineSchedulerOwner
    (deterministic : DeterministicSchedulingProjection)
    (recovery : RecoverySchedulingProjection) :
    (schedulerOwnerContractCandidate
        deterministic recovery "scheduler-owner-a").deterministic =
          deterministic ∧
      (schedulerOwnerContractCandidate
        deterministic recovery "scheduler-owner-b").deterministic =
          deterministic ∧
      (schedulerOwnerContractCandidate
        deterministic recovery "scheduler-owner-a").recovery = recovery ∧
      (schedulerOwnerContractCandidate
        deterministic recovery "scheduler-owner-b").recovery = recovery ∧
      (schedulerOwnerContractCandidate
        deterministic recovery
        "scheduler-owner-a").schedulerOwnerIdentity ≠
          (schedulerOwnerContractCandidate
            deterministic recovery
            "scheduler-owner-b").schedulerOwnerIdentity := by
  simp [schedulerOwnerContractCandidate]

inductive SchedulingAdmissionDecision where
  | admitted
  | deferred
  | rejected
  deriving DecidableEq, Repr

structure SchedulingDeferralState where
  decision : SchedulingAdmissionDecision
  remaining : Nat
  deriving DecidableEq, Repr

def SchedulingDeferralStep
    (before after : SchedulingDeferralState) : Prop :=
  before.decision = .deferred ∧
    before.remaining = after.remaining + 1

theorem schedulingDeferralStepStrictlyDecreases
    {before after : SchedulingDeferralState}
    (step : SchedulingDeferralStep before after) :
    after.remaining < before.remaining := by
  rw [step.2]
  exact Nat.lt_succ_self after.remaining

theorem unchangedSchedulingStateCannotDefer
    (state : SchedulingDeferralState) :
    ¬ SchedulingDeferralStep state state := by
  intro step
  exact
    (Nat.lt_irrefl state.remaining)
      (schedulingDeferralStepStrictlyDecreases step)

theorem admittedSchedulingStateCannotDefer
    (before after : SchedulingDeferralState)
    (admitted : before.decision = .admitted) :
    ¬ SchedulingDeferralStep before after := by
  intro step
  have impossible := step.1
  rw [admitted] at impossible
  contradiction

theorem rejectedSchedulingStateCannotDefer
    (before after : SchedulingDeferralState)
    (rejected : before.decision = .rejected) :
    ¬ SchedulingDeferralStep before after := by
  intro step
  have impossible := step.1
  rw [rejected] at impossible
  contradiction

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoverySchedulingDeferralOwnerModel
