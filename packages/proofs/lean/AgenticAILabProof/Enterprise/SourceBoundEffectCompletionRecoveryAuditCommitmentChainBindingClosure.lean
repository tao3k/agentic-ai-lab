-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuditCommitmentChainBindingModel
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuditWitnessContinuityClosure
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuditCommitmentChainBindingClosure

open SourceBoundEffectCompletionCrashRecoveryClosure
open SourceBoundEffectCompletionRecoveryAuditWitnessContinuityClosure
open SourceBoundEffectCompletionRecoveryConvergenceClosure
open SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore
open SourceBoundEffectCompletionRecoveryOwnerAuditCore
open SourceBoundEffectCompletionRecoveryProgressEvidenceClosure

structure SourceBoundEffectCompletionRecoveryAuditCommitmentChainBinding
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    (auditEvidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations) :
    Type where
  scheme : SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme
  witnessAt : Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness
  envelopeAt : Nat → SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope
  witnessValid :
    ∀ index, (witnessAt index).Valid
  ordinalBinds :
    ∀ index, (witnessAt index).ordinal = index
  recoveryBinds :
    ∀ index,
      (witnessAt index).recoveryId =
        auditEvidence.recoveryIdentity
  ownerBinds :
    ∀ index,
      (witnessAt index).owner =
        auditEvidence.ownerAt index
  ownerIdentityBinds :
    ∀ index,
      (witnessAt index).ownerIdentity =
        auditEvidence.ownerIdentityAt index
  beforeReceiptBinds :
    ∀ index,
      (witnessAt index).beforeReceiptId =
        auditEvidence.receiptIdentityAt index
  afterReceiptBinds :
    ∀ index,
      (witnessAt index).afterReceiptId =
        auditEvidence.receiptIdentityAt (index + 1)
  runtimeEpochBinds :
    ∀ index,
      (witnessAt index).runtimeEpoch =
        (expectations index).runtimeEpoch
  activeFenceBinds :
    ∀ index,
      (witnessAt index).activeFenceToken =
        (expectations index).activeFenceToken
  witnessAdjacent :
    ∀ index,
      (witnessAt index).Adjacent (witnessAt (index + 1))
  commitmentClosed :
    ∀ index,
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentClosed
        scheme (witnessAt index) (envelopeAt index)

theorem auditCommitmentChainReceiptContinuous
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {auditEvidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations}
    (binding :
      SourceBoundEffectCompletionRecoveryAuditCommitmentChainBinding
        auditEvidence)
    (index : Nat) :
    (binding.witnessAt (index + 1)).beforeReceiptId =
      (binding.witnessAt index).afterReceiptId := by
  calc
    (binding.witnessAt (index + 1)).beforeReceiptId =
        auditEvidence.receiptIdentityAt (index + 1) :=
      binding.beforeReceiptBinds (index + 1)
    _ = (binding.witnessAt index).afterReceiptId :=
      (binding.afterReceiptBinds index).symm

theorem auditCommitmentChainRecoveryContinuous
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {auditEvidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations}
    (binding :
      SourceBoundEffectCompletionRecoveryAuditCommitmentChainBinding
        auditEvidence)
    (leftIndex rightIndex : Nat) :
    (binding.witnessAt leftIndex).recoveryId =
      (binding.witnessAt rightIndex).recoveryId := by
  rw [binding.recoveryBinds leftIndex, binding.recoveryBinds rightIndex]

theorem auditCommitmentChainAfterReceiptNotReused
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {auditEvidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations}
    (binding :
      SourceBoundEffectCompletionRecoveryAuditCommitmentChainBinding
        auditEvidence)
    {leftIndex rightIndex : Nat}
    (indicesDiffer : leftIndex ≠ rightIndex) :
    (binding.witnessAt leftIndex).afterReceiptId ≠
      (binding.witnessAt rightIndex).afterReceiptId := by
  intro receiptsEqual
  apply indicesDiffer
  have positionsEqual : leftIndex + 1 = rightIndex + 1 := by
    apply auditEvidence.receiptIdentityInjective
    calc
      auditEvidence.receiptIdentityAt (leftIndex + 1) =
          (binding.witnessAt leftIndex).afterReceiptId :=
        (binding.afterReceiptBinds leftIndex).symm
      _ = (binding.witnessAt rightIndex).afterReceiptId :=
        receiptsEqual
      _ = auditEvidence.receiptIdentityAt (rightIndex + 1) :=
        binding.afterReceiptBinds rightIndex
  omega

theorem auditCommitmentChainBuildsExistingGlobalNonreuse
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {auditEvidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations}
    (binding :
      SourceBoundEffectCompletionRecoveryAuditCommitmentChainBinding
        auditEvidence) :
    SourceBoundEffectCompletionRecoveryOwnerAuditGloballyNonreusing
      binding.witnessAt := by
  intro leftIndex rightIndex earlier keysEqual
  have receiptsEqual :
      (binding.witnessAt leftIndex).afterReceiptId =
        (binding.witnessAt rightIndex).afterReceiptId :=
    congrArg Prod.snd keysEqual
  exact
    auditCommitmentChainAfterReceiptNotReused binding
      (Nat.ne_of_lt earlier) receiptsEqual

theorem auditCommitmentChainPreservesPredecessorCommitment
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {auditEvidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations}
    (binding :
      SourceBoundEffectCompletionRecoveryAuditCommitmentChainBinding
        auditEvidence)
    (index : Nat) :
    (binding.envelopeAt (index + 1)).payload.previousCommitment =
      some (binding.envelopeAt index).commitment :=
  adjacentCommitmentsPreservePredecessor
    (binding.witnessAdjacent index)
    (binding.commitmentClosed index)
    (binding.commitmentClosed (index + 1))

theorem auditCommitmentPayloadBindsExactReceiptChain
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {auditEvidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations}
    (binding :
      SourceBoundEffectCompletionRecoveryAuditCommitmentChainBinding
        auditEvidence)
    (index : Nat) :
    (binding.envelopeAt index).payload.beforeReceiptId =
        auditEvidence.receiptIdentityAt index ∧
      (binding.envelopeAt index).payload.afterReceiptId =
        auditEvidence.receiptIdentityAt (index + 1) := by
  constructor
  · exact
      (binding.commitmentClosed index).beforeReceiptBound.trans
        (binding.beforeReceiptBinds index)
  · exact
      (binding.commitmentClosed index).afterReceiptBound.trans
        (binding.afterReceiptBinds index)

theorem auditCommitmentChainOwnerSwitchStillPreservesReceipt
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {auditEvidence :
      SourceBoundEffectCompletionRecoveryAuditWitnessEvidence
        trace budgets scopes providerAcknowledgementStable expectations}
    (binding :
      SourceBoundEffectCompletionRecoveryAuditCommitmentChainBinding
        auditEvidence)
    (index : Nat)
    (_ownerChanges :
      (binding.witnessAt (index + 1)).owner ≠
        (binding.witnessAt index).owner) :
    (binding.witnessAt (index + 1)).beforeReceiptId =
      (binding.witnessAt index).afterReceiptId :=
  auditCommitmentChainReceiptContinuous binding index

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuditCommitmentChainBindingClosure
