-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuditCommitmentChainBindingModel

open SourceBoundEffectCompletionRecoveryOwnerAuditCore
open SourceBoundEffectCompletionRecoveryProgressEvidenceClosure

def disconnectedCurrentAuditWitness :
    SourceBoundEffectCompletionRecoveryOwnerAuditWitness where
  witnessId := "witness-0"
  previousWitnessId := none
  ordinal := 0
  recoveryId := "recovery-a"
  owner := .runtimeCrashBudget
  ownerIdentity := "runtime-owner"
  beforeReceiptId := "receipt-0"
  afterReceiptId := "receipt-1"
  runtimeEpoch := 7
  activeFenceToken := 11

def disconnectedNextAuditWitness :
    SourceBoundEffectCompletionRecoveryOwnerAuditWitness where
  witnessId := "witness-1"
  previousWitnessId := some "witness-0"
  ordinal := 1
  recoveryId := "recovery-a"
  owner := .schedulerAdmission
  ownerIdentity := "scheduler-owner"
  beforeReceiptId := "orphan-receipt"
  afterReceiptId := "receipt-2"
  runtimeEpoch := 7
  activeFenceToken := 11

theorem disconnectedCurrentAuditWitnessValid :
    disconnectedCurrentAuditWitness.Valid := by
  simp [SourceBoundEffectCompletionRecoveryOwnerAuditWitness.Valid,
    disconnectedCurrentAuditWitness]

theorem disconnectedNextAuditWitnessValid :
    disconnectedNextAuditWitness.Valid := by
  simp [SourceBoundEffectCompletionRecoveryOwnerAuditWitness.Valid,
    disconnectedNextAuditWitness]

theorem ownerAuditAdjacencyAllowsCrossOwnerReceiptDiscontinuity :
    disconnectedCurrentAuditWitness.Adjacent
        disconnectedNextAuditWitness ∧
      disconnectedNextAuditWitness.beforeReceiptId ≠
        disconnectedCurrentAuditWitness.afterReceiptId := by
  simp [SourceBoundEffectCompletionRecoveryOwnerAuditWitness.Adjacent,
    disconnectedCurrentAuditWitness, disconnectedNextAuditWitness]

def crossOwnerReuseLeftAuditWitness :
    SourceBoundEffectCompletionRecoveryOwnerAuditWitness where
  witnessId := "reuse-witness-0"
  previousWitnessId := none
  ordinal := 0
  recoveryId := "recovery-a"
  owner := .runtimeCrashBudget
  ownerIdentity := "runtime-owner"
  beforeReceiptId := "receipt-0"
  afterReceiptId := "shared-receipt"
  runtimeEpoch := 7
  activeFenceToken := 11

def crossOwnerReuseRightAuditWitness :
    SourceBoundEffectCompletionRecoveryOwnerAuditWitness where
  witnessId := "reuse-witness-1"
  previousWitnessId := some "reuse-witness-0"
  ordinal := 1
  recoveryId := "recovery-a"
  owner := .completionStorageAdmission
  ownerIdentity := "storage-owner"
  beforeReceiptId := "receipt-other"
  afterReceiptId := "shared-receipt"
  runtimeEpoch := 7
  activeFenceToken := 11

theorem ownerPairedReceiptKeyDoesNotDetectCrossOwnerReceiptReuse :
    crossOwnerReuseLeftAuditWitness.afterReceiptId =
        crossOwnerReuseRightAuditWitness.afterReceiptId ∧
      crossOwnerReuseLeftAuditWitness.receiptKey ≠
        crossOwnerReuseRightAuditWitness.receiptKey := by
  decide

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuditCommitmentChainBindingModel
