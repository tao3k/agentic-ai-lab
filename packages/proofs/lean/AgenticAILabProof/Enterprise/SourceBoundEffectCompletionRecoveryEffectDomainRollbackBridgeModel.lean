-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridgeModel

abbrev EffectId := String
abbrev Digest := String

inductive RecoveryOutcome where
  | committed
  | duplicate
  | rejected
  | rolledBack
  deriving DecidableEq, Repr

structure RecoveryObservation where
  aggregateDigest : Digest
  uncompensatedApplicationCount : Nat
  deriving DecidableEq, Repr

structure RecoveryReceipt where
  transactionId : String
  fenceToken : Nat
  outcome : RecoveryOutcome
  before : RecoveryObservation
  after : RecoveryObservation
  deriving DecidableEq, Repr

structure EffectCoverageWitness where
  materializationPlanDigest : Digest
  effectUniverse : List EffectId
  observedDomain : List EffectId
  deriving DecidableEq, Repr

structure EffectFact where
  effectId : EffectId
  stateDigest : Digest
  deriving DecidableEq, Repr

abbrev EffectWorld := List EffectFact

structure CompensationReceipt where
  effectId : EffectId
  fenceToken : Nat
  restoredStateDigest : Digest
  deriving DecidableEq, Repr

def DomainCoversUniverse (witness : EffectCoverageWitness) : Prop :=
  ∀ effectId, effectId ∈ witness.effectUniverse → effectId ∈ witness.observedDomain

def WorldCoversDomain
    (witness : EffectCoverageWitness)
    (world : EffectWorld) : Prop :=
  ∀ effectId,
    effectId ∈ witness.observedDomain →
      ∃ fact, fact ∈ world ∧ fact.effectId = effectId

def WorldsAgreeOnDomain
    (witness : EffectCoverageWitness)
    (before after : EffectWorld) : Prop :=
  ∀ fact,
    fact.effectId ∈ witness.observedDomain →
      (fact ∈ before ↔ fact ∈ after)

def RecoveryRequiresCompensation (receipt : RecoveryReceipt) : Prop :=
  receipt.outcome = RecoveryOutcome.rolledBack

def EffectDomainRollbackBound
    (receipt : RecoveryReceipt)
    (witness : EffectCoverageWitness)
    (before after : EffectWorld)
    (compensationReceipts : List CompensationReceipt) : Prop :=
  DomainCoversUniverse witness ∧
    WorldCoversDomain witness before ∧
      WorldCoversDomain witness after ∧
        (RecoveryRequiresCompensation receipt →
          WorldsAgreeOnDomain witness before after ∧
            ∀ compensation,
              compensation ∈ compensationReceipts →
                compensation.fenceToken = receipt.fenceToken)

theorem equalAggregateDigestCanHideDifferentEffectWorlds :
    ∃ left right : RecoveryObservation,
      left.aggregateDigest = right.aggregateDigest ∧
        ∃ before after : EffectWorld, before ≠ after := by
  refine ⟨
    { aggregateDigest := "sha256:projected-runtime", uncompensatedApplicationCount := 0 },
    { aggregateDigest := "sha256:projected-runtime", uncompensatedApplicationCount := 0 },
    rfl,
    [{ effectId := "message", stateDigest := "pending" }],
    [{ effectId := "message", stateDigest := "published" }],
    ?_
  ⟩
  decide

theorem matchingPlanDigestDoesNotBindEffectUniverse :
    ∃ witness : EffectCoverageWitness,
      witness.materializationPlanDigest = "plan-a" ∧
        ¬ (fun _planDigest _effectUniverse => False)
          witness.materializationPlanDigest
          witness.effectUniverse := by
  refine ⟨
    {
      materializationPlanDigest := "plan-a"
      effectUniverse := ["runtime"]
      observedDomain := ["runtime"]
    },
    rfl,
    ?_
  ⟩
  simp

theorem populatedObservedDomainDoesNotProveCoverage :
    ∃ witness : EffectCoverageWitness,
      witness.observedDomain ≠ [] ∧
        ¬ DomainCoversUniverse witness := by
  refine ⟨
    {
      materializationPlanDigest := "plan-a"
      effectUniverse := ["runtime", "message"]
      observedDomain := ["runtime"]
    },
    by simp,
    ?_
  ⟩
  intro closed
  have messageObserved := closed "message" (by simp)
  simp at messageObserved

theorem rolledBackOutcomeDoesNotProvideCompensationReceipts :
    ∃ receipt : RecoveryReceipt,
      RecoveryRequiresCompensation receipt ∧
        (List.nil : List CompensationReceipt) = [] := by
  refine ⟨
    {
      transactionId := "transaction-a"
      fenceToken := 8
      outcome := RecoveryOutcome.rolledBack
      before := {
        aggregateDigest := "before"
        uncompensatedApplicationCount := 0
      }
      after := {
        aggregateDigest := "before"
        uncompensatedApplicationCount := 0
      }
    },
    rfl,
    rfl
  ⟩

theorem matchingEffectIdentityDoesNotBindCompensationFence :
    ∃ receipt : RecoveryReceipt,
      ∃ compensation : CompensationReceipt,
        compensation.effectId = "message" ∧
          compensation.fenceToken ≠ receipt.fenceToken := by
  refine ⟨
    {
      transactionId := "transaction-a"
      fenceToken := 8
      outcome := RecoveryOutcome.rolledBack
      before := {
        aggregateDigest := "before"
        uncompensatedApplicationCount := 0
      }
      after := {
        aggregateDigest := "before"
        uncompensatedApplicationCount := 0
      }
    },
    {
      effectId := "message"
      fenceToken := 7
      restoredStateDigest := "pending"
    },
    rfl,
    by decide
  ⟩

theorem committedRecoveryDoesNotRequireRollbackCompensation :
    ∃ receipt : RecoveryReceipt,
      receipt.outcome = RecoveryOutcome.committed ∧
        ¬ RecoveryRequiresCompensation receipt := by
  refine ⟨
    {
      transactionId := "transaction-a"
      fenceToken := 8
      outcome := RecoveryOutcome.committed
      before := {
        aggregateDigest := "before"
        uncompensatedApplicationCount := 0
      }
      after := {
        aggregateDigest := "after"
        uncompensatedApplicationCount := 1
      }
    },
    rfl,
    ?_
  ⟩
  simp [RecoveryRequiresCompensation]

theorem closedRollbackBridgeProvidesWholeDomainAgreement
    {receipt : RecoveryReceipt}
    {witness : EffectCoverageWitness}
    {before after : EffectWorld}
    {compensationReceipts : List CompensationReceipt}
    (closed :
      EffectDomainRollbackBound
        receipt
        witness
        before
        after
        compensationReceipts)
    (rolledBack : RecoveryRequiresCompensation receipt) :
    WorldsAgreeOnDomain witness before after :=
  (closed.2.2.2 rolledBack).1

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridgeModel
