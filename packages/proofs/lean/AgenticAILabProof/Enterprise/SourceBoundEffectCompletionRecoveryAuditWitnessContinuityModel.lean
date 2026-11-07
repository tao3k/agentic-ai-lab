-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerCoverageModel

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuditWitnessContinuityModel

open SourceBoundEffectCompletionRecoveryOwnerCoverageModel

structure LocalAuditTransitionModel where
  owner : ProgressOwnerModel
  ownerIdentity : String
  beforeReceiptIdentity : String
  afterReceiptIdentity : String
  recoveryIdentity : String
  ownerIdentityPresent : ownerIdentity ≠ ""
  beforeReceiptIdentityPresent : beforeReceiptIdentity ≠ ""
  afterReceiptIdentityPresent : afterReceiptIdentity ≠ ""
  recoveryIdentityPresent : recoveryIdentity ≠ ""
  receiptIdentityAdvances : afterReceiptIdentity ≠ beforeReceiptIdentity

def disconnectedFirstTransition : LocalAuditTransitionModel where
  owner := .runtimeCrashBudget
  ownerIdentity := "runtime-owner"
  beforeReceiptIdentity := "receipt-0"
  afterReceiptIdentity := "receipt-1"
  recoveryIdentity := "recovery-a"
  ownerIdentityPresent := by decide
  beforeReceiptIdentityPresent := by decide
  afterReceiptIdentityPresent := by decide
  recoveryIdentityPresent := by decide
  receiptIdentityAdvances := by decide

def disconnectedSecondTransition : LocalAuditTransitionModel where
  owner := .schedulerAdmission
  ownerIdentity := "scheduler-owner"
  beforeReceiptIdentity := "orphan-receipt"
  afterReceiptIdentity := "receipt-2"
  recoveryIdentity := "recovery-b"
  ownerIdentityPresent := by decide
  beforeReceiptIdentityPresent := by decide
  afterReceiptIdentityPresent := by decide
  recoveryIdentityPresent := by decide
  receiptIdentityAdvances := by decide

def reusedAfterIdentityTransition : LocalAuditTransitionModel where
  owner := .completionStorageAdmission
  ownerIdentity := "storage-owner"
  beforeReceiptIdentity := "receipt-other"
  afterReceiptIdentity := "receipt-1"
  recoveryIdentity := "recovery-a"
  ownerIdentityPresent := by decide
  beforeReceiptIdentityPresent := by decide
  afterReceiptIdentityPresent := by decide
  recoveryIdentityPresent := by decide
  receiptIdentityAdvances := by decide

theorem localClosureDoesNotImplyAdjacentContinuity :
    disconnectedSecondTransition.beforeReceiptIdentity ≠
      disconnectedFirstTransition.afterReceiptIdentity := by
  decide

theorem localClosureDoesNotImplyGlobalNonReuse :
    reusedAfterIdentityTransition.afterReceiptIdentity =
      disconnectedFirstTransition.afterReceiptIdentity := by
  rfl

theorem localClosureDoesNotImplyRecoveryContinuity :
    disconnectedSecondTransition.recoveryIdentity ≠
      disconnectedFirstTransition.recoveryIdentity := by
  decide

structure AuditWitnessChainModel where
  ownerAt : Nat → ProgressOwnerModel
  ownerEvidenceAt : (index : Nat) → OwnerEvidenceModel (ownerAt index)
  receiptIdentityAt : Nat → String
  recoveryIdentity : String
  receiptIdentityPresent : ∀ index, receiptIdentityAt index ≠ ""
  recoveryIdentityPresent : recoveryIdentity ≠ ""
  ownerEvidenceReceiptMatches :
    ∀ index,
      (ownerEvidenceAt index).ownerReceiptIdentity =
        receiptIdentityAt (index + 1)
  receiptIdentityInjective : Function.Injective receiptIdentityAt

def canonicalReceiptIdentity (index : Nat) : String :=
  String.ofList (List.replicate (index + 1) 'r')

theorem canonicalReceiptIdentityPresent
    (index : Nat) :
    canonicalReceiptIdentity index ≠ "" := by
  intro identityEmpty
  have lengthsEqual := congrArg String.length identityEmpty
  simp [canonicalReceiptIdentity] at lengthsEqual

theorem canonicalReceiptIdentityInjective :
    Function.Injective canonicalReceiptIdentity := by
  intro leftIndex rightIndex identitiesEqual
  have lengthsEqual := congrArg String.length identitiesEqual
  simp [canonicalReceiptIdentity] at lengthsEqual
  omega

def canonicalAuditWitnessChain : AuditWitnessChainModel where
  ownerAt := fun _ => .runtimeCrashBudget
  ownerEvidenceAt := fun index =>
    { ownerIdentity := "runtime-owner"
      ownerReceiptIdentity := canonicalReceiptIdentity (index + 1)
      ownerIdentityPresent := by decide
      ownerReceiptIdentityPresent :=
        canonicalReceiptIdentityPresent (index + 1) }
  receiptIdentityAt := canonicalReceiptIdentity
  recoveryIdentity := "recovery-a"
  receiptIdentityPresent := canonicalReceiptIdentityPresent
  recoveryIdentityPresent := by decide
  ownerEvidenceReceiptMatches := fun _ => rfl
  receiptIdentityInjective := canonicalReceiptIdentityInjective

theorem auditWitnessChainModelIsInhabited :
    Nonempty AuditWitnessChainModel :=
  ⟨canonicalAuditWitnessChain⟩

def beforeReceiptIdentity
    (chain : AuditWitnessChainModel)
    (index : Nat) : String :=
  chain.receiptIdentityAt index

def afterReceiptIdentity
    (chain : AuditWitnessChainModel)
    (index : Nat) : String :=
  chain.receiptIdentityAt (index + 1)

def recoveryIdentityAt
    (chain : AuditWitnessChainModel)
    (_index : Nat) : String :=
  chain.recoveryIdentity

theorem auditWitnessChainAdjacentContinuity
    (chain : AuditWitnessChainModel)
    (index : Nat) :
    beforeReceiptIdentity chain (index + 1) =
      afterReceiptIdentity chain index := by
  rfl

theorem auditWitnessChainTransitionAdvances
    (chain : AuditWitnessChainModel)
    (index : Nat) :
    afterReceiptIdentity chain index ≠
      beforeReceiptIdentity chain index := by
  intro identitiesEqual
  have indicesEqual : index + 1 = index :=
    chain.receiptIdentityInjective identitiesEqual
  omega

theorem auditWitnessChainGloballyDoesNotReuse
    (chain : AuditWitnessChainModel)
    {leftIndex rightIndex : Nat}
    (identitiesEqual :
      chain.receiptIdentityAt leftIndex =
        chain.receiptIdentityAt rightIndex) :
    leftIndex = rightIndex :=
  chain.receiptIdentityInjective identitiesEqual

theorem auditWitnessChainOwnerReceiptIsExact
    (chain : AuditWitnessChainModel)
    (index : Nat) :
    (chain.ownerEvidenceAt index).ownerReceiptIdentity =
      afterReceiptIdentity chain index :=
  chain.ownerEvidenceReceiptMatches index

theorem auditWitnessChainRecoveryIsContinuous
    (chain : AuditWitnessChainModel)
    (leftIndex rightIndex : Nat) :
    recoveryIdentityAt chain leftIndex =
      recoveryIdentityAt chain rightIndex := by
  rfl

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuditWitnessContinuityModel
