-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityModel

structure HandoffIdentityEvidenceModel where
  beforeCommitment : String
  afterCommitment : String
  transferContractIdentity : String
  authorityEvidenceIdentity : String
  acceptanceEvidenceIdentity : String
  effectiveObservationIdentity : String
  deriving DecidableEq

def HandoffIdentityEvidenceModel.Valid
    (evidence : HandoffIdentityEvidenceModel) : Prop :=
  evidence.beforeCommitment ≠ "" ∧
    evidence.afterCommitment ≠ "" ∧
      evidence.beforeCommitment ≠ evidence.afterCommitment ∧
        evidence.transferContractIdentity ≠ "" ∧
          evidence.authorityEvidenceIdentity ≠ "" ∧
            evidence.acceptanceEvidenceIdentity ≠ "" ∧
              evidence.effectiveObservationIdentity ≠ ""

def sharedContractHandoffA : HandoffIdentityEvidenceModel where
  beforeCommitment := "commitment-0"
  afterCommitment := "commitment-1"
  transferContractIdentity := "contract-shared"
  authorityEvidenceIdentity := "authority-receipt-shared"
  acceptanceEvidenceIdentity := "acceptance-0"
  effectiveObservationIdentity := "observation-0"

def sharedContractHandoffB : HandoffIdentityEvidenceModel where
  beforeCommitment := "commitment-1"
  afterCommitment := "commitment-2"
  transferContractIdentity := "contract-shared"
  authorityEvidenceIdentity := "authority-receipt-shared"
  acceptanceEvidenceIdentity := "acceptance-1"
  effectiveObservationIdentity := "observation-1"

theorem blanketIdentityUniquenessWouldRejectValidSharedContract :
    sharedContractHandoffA.Valid ∧
      sharedContractHandoffB.Valid ∧
        sharedContractHandoffA.transferContractIdentity =
          sharedContractHandoffB.transferContractIdentity ∧
        sharedContractHandoffA.authorityEvidenceIdentity =
          sharedContractHandoffB.authorityEvidenceIdentity ∧
        sharedContractHandoffA.acceptanceEvidenceIdentity ≠
          sharedContractHandoffB.acceptanceEvidenceIdentity ∧
        sharedContractHandoffA.effectiveObservationIdentity ≠
          sharedContractHandoffB.effectiveObservationIdentity := by
  simp [
    HandoffIdentityEvidenceModel.Valid,
    sharedContractHandoffA,
    sharedContractHandoffB
  ]

def replayedExecutionHandoffA : HandoffIdentityEvidenceModel where
  beforeCommitment := "commitment-a0"
  afterCommitment := "commitment-a1"
  transferContractIdentity := "contract-a"
  authorityEvidenceIdentity := "authority-a"
  acceptanceEvidenceIdentity := "acceptance-replayed"
  effectiveObservationIdentity := "observation-replayed"

def replayedExecutionHandoffB : HandoffIdentityEvidenceModel where
  beforeCommitment := "commitment-b0"
  afterCommitment := "commitment-b1"
  transferContractIdentity := "contract-b"
  authorityEvidenceIdentity := "authority-b"
  acceptanceEvidenceIdentity := "acceptance-replayed"
  effectiveObservationIdentity := "observation-replayed"

theorem localHandoffValidityDoesNotPreventExecutionEvidenceReplay :
    replayedExecutionHandoffA.Valid ∧
      replayedExecutionHandoffB.Valid ∧
        replayedExecutionHandoffA.beforeCommitment ≠
          replayedExecutionHandoffB.beforeCommitment ∧
        replayedExecutionHandoffA.acceptanceEvidenceIdentity =
          replayedExecutionHandoffB.acceptanceEvidenceIdentity ∧
        replayedExecutionHandoffA.effectiveObservationIdentity =
          replayedExecutionHandoffB.effectiveObservationIdentity := by
  simp [
    HandoffIdentityEvidenceModel.Valid,
    replayedExecutionHandoffA,
    replayedExecutionHandoffB
  ]

def ExecutionEvidenceGloballyNonreusing
    (handoffAt : Nat → Prop)
    (evidenceAt : Nat → HandoffIdentityEvidenceModel) :
    Prop :=
  (∀ {left right},
      handoffAt left →
        handoffAt right →
          (evidenceAt left).acceptanceEvidenceIdentity =
              (evidenceAt right).acceptanceEvidenceIdentity →
            left = right) ∧
    (∀ {left right},
      handoffAt left →
        handoffAt right →
          (evidenceAt left).effectiveObservationIdentity =
              (evidenceAt right).effectiveObservationIdentity →
            left = right)

def canonicalHandoffAt (index : Nat) : Prop :=
  index = 0 ∨ index = 1

def canonicalHandoffEvidenceAt
    (index : Nat) : HandoffIdentityEvidenceModel :=
  if index = 0 then sharedContractHandoffA else sharedContractHandoffB

theorem canonicalExecutionEvidenceIsGloballyNonreusing :
    ExecutionEvidenceGloballyNonreusing
      canonicalHandoffAt
      canonicalHandoffEvidenceAt := by
  constructor
  · intro left right leftHandoff rightHandoff identitiesEqual
    rcases leftHandoff with rfl | rfl
    · rcases rightHandoff with rfl | rfl
      · rfl
      · simp [
          canonicalHandoffEvidenceAt,
          sharedContractHandoffA,
          sharedContractHandoffB
        ] at identitiesEqual
    · rcases rightHandoff with rfl | rfl
      · simp [
          canonicalHandoffEvidenceAt,
          sharedContractHandoffA,
          sharedContractHandoffB
        ] at identitiesEqual
      · rfl
  · intro left right leftHandoff rightHandoff identitiesEqual
    rcases leftHandoff with rfl | rfl
    · rcases rightHandoff with rfl | rfl
      · rfl
      · simp [
          canonicalHandoffEvidenceAt,
          sharedContractHandoffA,
          sharedContractHandoffB
        ] at identitiesEqual
    · rcases rightHandoff with rfl | rfl
      · simp [
          canonicalHandoffEvidenceAt,
          sharedContractHandoffA,
          sharedContractHandoffB
        ] at identitiesEqual
      · rfl

theorem classifiedNonreuseStillAllowsSharedContractIdentity :
    ExecutionEvidenceGloballyNonreusing
        canonicalHandoffAt
        canonicalHandoffEvidenceAt ∧
      (canonicalHandoffEvidenceAt 0).transferContractIdentity =
        (canonicalHandoffEvidenceAt 1).transferContractIdentity ∧
      (canonicalHandoffEvidenceAt 0).authorityEvidenceIdentity =
        (canonicalHandoffEvidenceAt 1).authorityEvidenceIdentity := by
  exact
    ⟨canonicalExecutionEvidenceIsGloballyNonreusing,
      by
        simp [
          canonicalHandoffEvidenceAt,
          sharedContractHandoffA,
          sharedContractHandoffB
        ],
      by
        simp [
          canonicalHandoffEvidenceAt,
          sharedContractHandoffA,
          sharedContractHandoffB
        ]⟩

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityModel
