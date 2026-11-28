-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore

open SourceBoundEffectCompletionRecoveryOwnerAuditCore
open SourceBoundEffectCompletionRecoveryProgressEvidenceClosure

/-!
# Canonical owner-audit commitment and authenticity algebra

The recovery proof consumes abstract authorization and signature-verification
relations.  Policy evaluation, credential verification, and cryptographic
implementation remain externally owned.
-/

structure SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentPayload where
  previousCommitment : Option String
  ordinal : Nat
  recoveryId : String
  owner : SourceBoundEffectCompletionRecoveryProgressOwner
  ownerIdentity : String
  beforeReceiptId : String
  afterReceiptId : String
  runtimeEpoch : Nat
  activeFenceToken : Nat

structure SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme where
  commit :
    SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentPayload → String
  collisionResistant : Function.Injective commit

structure SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope where
  payload :
    SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentPayload
  commitment : String

structure SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence where
  commitment : String
  authorityIdentity : String
  credentialIdentity : String
  policyDecisionIdentity : String
  policyEvidenceRoot : String
  accountabilityIdentity : String
  responsibilityScopeDigest : String
  signature : String

def SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence.Valid
    (authorized : String → String → Prop)
    (signatureVerified : String → String → String → Prop)
    (expectedCommitment : String)
    (evidence :
      SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence) :
    Prop :=
  evidence.commitment = expectedCommitment ∧
  evidence.authorityIdentity ≠ "" ∧
  evidence.credentialIdentity ≠ "" ∧
  evidence.policyDecisionIdentity ≠ "" ∧
  evidence.policyEvidenceRoot ≠ "" ∧
  evidence.accountabilityIdentity ≠ "" ∧
  evidence.responsibilityScopeDigest ≠ "" ∧
  evidence.signature ≠ "" ∧
  authorized evidence.authorityIdentity expectedCommitment ∧
  signatureVerified
    evidence.credentialIdentity expectedCommitment evidence.signature

structure SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentClosed
    (scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme)
    (witness : SourceBoundEffectCompletionRecoveryOwnerAuditWitness)
    (envelope :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope) :
    Prop where
  canonicalCommitment :
    envelope.commitment = scheme.commit envelope.payload
  witnessIdentityBound :
    witness.witnessId = envelope.commitment
  previousCommitmentBound :
    envelope.payload.previousCommitment = witness.previousWitnessId
  ordinalBound :
    envelope.payload.ordinal = witness.ordinal
  recoveryBound :
    envelope.payload.recoveryId = witness.recoveryId
  ownerBound :
    envelope.payload.owner = witness.owner
  ownerIdentityBound :
    envelope.payload.ownerIdentity = witness.ownerIdentity
  beforeReceiptBound :
    envelope.payload.beforeReceiptId = witness.beforeReceiptId
  afterReceiptBound :
    envelope.payload.afterReceiptId = witness.afterReceiptId
  runtimeEpochBound :
    envelope.payload.runtimeEpoch = witness.runtimeEpoch
  activeFenceBound :
    envelope.payload.activeFenceToken = witness.activeFenceToken

structure SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityClosed
    (scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme)
    (authorized : String → String → Prop)
    (signatureVerified : String → String → String → Prop)
    (witness : SourceBoundEffectCompletionRecoveryOwnerAuditWitness)
    (envelope :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope)
    (evidence :
      SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence) :
    Prop where
  commitmentClosed :
    SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentClosed
      scheme witness envelope
  authenticityValid :
    evidence.Valid authorized signatureVerified envelope.commitment

theorem commitmentClosedRejectsPayloadSubstitution
    {scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {witness : SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {left right :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    (leftClosed :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentClosed
        scheme witness left)
    (rightClosed :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentClosed
        scheme witness right) :
    left.payload = right.payload := by
  apply scheme.collisionResistant
  calc
    scheme.commit left.payload = left.commitment :=
      leftClosed.canonicalCommitment.symm
    _ = witness.witnessId := leftClosed.witnessIdentityBound.symm
    _ = right.commitment := rightClosed.witnessIdentityBound
    _ = scheme.commit right.payload := rightClosed.canonicalCommitment

theorem adjacentCommitmentsPreservePredecessor
    {scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {currentWitness nextWitness :
      SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {currentEnvelope nextEnvelope :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    (adjacent : currentWitness.Adjacent nextWitness)
    (currentClosed :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentClosed
        scheme currentWitness currentEnvelope)
    (nextClosed :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentClosed
        scheme nextWitness nextEnvelope) :
    nextEnvelope.payload.previousCommitment =
      some currentEnvelope.commitment := by
  calc
    nextEnvelope.payload.previousCommitment =
        nextWitness.previousWitnessId :=
      nextClosed.previousCommitmentBound
    _ = some currentWitness.witnessId := adjacent.2.1
    _ = some currentEnvelope.commitment :=
      congrArg some currentClosed.witnessIdentityBound

theorem mismatchedAuthenticityCommitmentRejectsClosure
    {scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {authorized : String → String → Prop}
    {signatureVerified : String → String → String → Prop}
    {witness : SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {envelope :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {evidence :
      SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    (mismatched : evidence.commitment ≠ envelope.commitment) :
    ¬ SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityClosed
        scheme authorized signatureVerified witness envelope evidence := by
  intro closed
  exact mismatched closed.authenticityValid.1

theorem unauthorizedCommitmentRejectsAuthenticityClosure
    {scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {authorized : String → String → Prop}
    {signatureVerified : String → String → String → Prop}
    {witness : SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {envelope :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {evidence :
      SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    (unauthorized :
      ¬ authorized evidence.authorityIdentity envelope.commitment) :
    ¬ SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityClosed
        scheme authorized signatureVerified witness envelope evidence := by
  intro closed
  exact unauthorized closed.authenticityValid.2.2.2.2.2.2.2.2.1

theorem invalidSignatureRejectsAuthenticityClosure
    {scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {authorized : String → String → Prop}
    {signatureVerified : String → String → String → Prop}
    {witness : SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {envelope :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {evidence :
      SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    (invalid :
      ¬ signatureVerified
        evidence.credentialIdentity envelope.commitment evidence.signature) :
    ¬ SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityClosed
        scheme authorized signatureVerified witness envelope evidence := by
  intro closed
  exact invalid closed.authenticityValid.2.2.2.2.2.2.2.2.2

theorem emptyAccountabilityRejectsAuthenticityClosure
    {scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {authorized : String → String → Prop}
    {signatureVerified : String → String → String → Prop}
    {witness : SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {envelope :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {evidence :
      SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    (empty : evidence.accountabilityIdentity = "") :
    ¬ SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityClosed
        scheme authorized signatureVerified witness envelope evidence := by
  intro closed
  exact closed.authenticityValid.2.2.2.2.2.1 empty

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore
