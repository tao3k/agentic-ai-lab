-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.PublicationDomainRegistryReplicaJoinClosure

namespace AgenticAILabProof.Enterprise.PublicationDomainRegistryReplicaProvenanceClosure

open AgenticAILabProof.Enterprise.PublicationDomainRegistryLineageClosure
open AgenticAILabProof.Enterprise.PublicationDomainRegistryRecoveryClosure
open AgenticAILabProof.Enterprise.PublicationDomainRegistryReplicaJoinClosure
open AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure

structure UnverifiedReplicaKnowledgeEnvelope
    (lineage : PublicationDomainRegistryTrustRootLineage) where
  senderIdentity : Nat
  authorizationSnapshotIdentity : Nat
  knowledge : ReplicaRegistryCheckpointKnowledge lineage

theorem selfReportedHighReplicaKnowledgeCanPoisonJoin
    (lineage : PublicationDomainRegistryTrustRootLineage) :
    ∃ (localKnowledge : ReplicaRegistryCheckpointKnowledge lineage)
      (peer : UnverifiedReplicaKnowledgeEnvelope lineage)
      (candidatePosition : Nat),
      replicaKnowledgeAcceptsPosition localKnowledge candidatePosition ∧
        ¬ replicaKnowledgeAcceptsPosition
          (joinReplicaRegistryCheckpointKnowledge
            localKnowledge peer.knowledge)
          candidatePosition := by
  let localKnowledge : ReplicaRegistryCheckpointKnowledge lineage := {
    minimumPosition := 5
  }
  let peer : UnverifiedReplicaKnowledgeEnvelope lineage := {
    senderIdentity := 401
    authorizationSnapshotIdentity := 409
    knowledge := {
      minimumPosition := 100
    }
  }
  refine ⟨localKnowledge, peer, 6, ?_, ?_⟩
  · simp [replicaKnowledgeAcceptsPosition, localKnowledge]
  · simp [
      replicaKnowledgeAcceptsPosition,
      joinReplicaRegistryCheckpointKnowledge,
      localKnowledge,
      peer
    ]

theorem authorizationSnapshotEqualityAloneDoesNotEstablishAdmissionContext :
    ∃ (left right : ReceiptValidationContext),
      left.authorizationSnapshotIdentity =
          right.authorizationSnapshotIdentity ∧
        left ≠ right := by
  let left : ReceiptValidationContext := {
    authorityIdentity := 419
    authorityGeneration := 1
    policySnapshotIdentity := 421
    authorizationSnapshotIdentity := 431
    revocationSnapshotIdentity := 433
  }
  let right : ReceiptValidationContext := {
    authorityIdentity := 419
    authorityGeneration := 1
    policySnapshotIdentity := 421
    authorizationSnapshotIdentity := 431
    revocationSnapshotIdentity := 439
  }
  exact ⟨left, right, rfl, by decide⟩

structure ReplicaKnowledgeAdmissionAuthority
    (lineage : PublicationDomainRegistryTrustRootLineage) where
  validationContext : ReceiptValidationContext
  authorizedSender : Nat → Prop
  recoveryAuthority :
    Nat → DurableRegistryCheckpointRecoveryAuthority lineage

structure AuthorityIssuedReplicaKnowledgeEnvelope
    (lineage : PublicationDomainRegistryTrustRootLineage)
    (admissionAuthority : ReplicaKnowledgeAdmissionAuthority lineage) where
  senderIdentity : Nat
  validationContext : ReceiptValidationContext
  validationContextMatches :
    validationContext = admissionAuthority.validationContext
  senderAuthorized :
    admissionAuthority.authorizedSender senderIdentity
  recoveryEvidence : RegistryTrustRootRecoveryEvidence lineage
  recoveryAccepted :
    authorityIssuedRegistryTrustRootRecovery
      (admissionAuthority.recoveryAuthority senderIdentity)
      recoveryEvidence
  knowledge : ReplicaRegistryCheckpointKnowledge lineage
  knowledgeMatchesRecovery :
    knowledge.minimumPosition = recoveryEvidence.recoveredPosition

theorem admittedEnvelopeBindsValidationContext
    {lineage : PublicationDomainRegistryTrustRootLineage}
    {admissionAuthority : ReplicaKnowledgeAdmissionAuthority lineage}
    (envelope :
      AuthorityIssuedReplicaKnowledgeEnvelope lineage admissionAuthority) :
    envelope.validationContext = admissionAuthority.validationContext :=
  envelope.validationContextMatches

theorem admittedEnvelopeRequiresAuthorizedSender
    {lineage : PublicationDomainRegistryTrustRootLineage}
    {admissionAuthority : ReplicaKnowledgeAdmissionAuthority lineage}
    (envelope :
      AuthorityIssuedReplicaKnowledgeEnvelope lineage admissionAuthority) :
    admissionAuthority.authorizedSender envelope.senderIdentity :=
  envelope.senderAuthorized

theorem admittedEnvelopeKnowledgeNeverFallsBelowDurableCheckpoint
    {lineage : PublicationDomainRegistryTrustRootLineage}
    {admissionAuthority : ReplicaKnowledgeAdmissionAuthority lineage}
    (envelope :
      AuthorityIssuedReplicaKnowledgeEnvelope lineage admissionAuthority) :
    (admissionAuthority.recoveryAuthority
        envelope.senderIdentity).durableCommittedPosition ≤
      envelope.knowledge.minimumPosition := by
  calc
    (admissionAuthority.recoveryAuthority
        envelope.senderIdentity).durableCommittedPosition ≤
        envelope.recoveryEvidence.recoveredPosition :=
      authorityIssuedRecoveryNeverRestoresBeforeDurableCheckpoint
        envelope.recoveryAccepted
    _ = envelope.knowledge.minimumPosition :=
      envelope.knowledgeMatchesRecovery.symm

theorem admittedEnvelopeKnowledgeEqualsAuthorityRecoveredCheckpoint
    {lineage : PublicationDomainRegistryTrustRootLineage}
    {admissionAuthority : ReplicaKnowledgeAdmissionAuthority lineage}
    (envelope :
      AuthorityIssuedReplicaKnowledgeEnvelope lineage admissionAuthority) :
    envelope.knowledge.minimumPosition =
      (admissionAuthority.recoveryAuthority
        envelope.senderIdentity).recoveredCheckpoint.currentPosition := by
  calc
    envelope.knowledge.minimumPosition =
        envelope.recoveryEvidence.recoveredPosition :=
      envelope.knowledgeMatchesRecovery
    _ = (admissionAuthority.recoveryAuthority
          envelope.senderIdentity).recoveredCheckpoint.currentPosition :=
      authorityIssuedRecoveryRestoresAuthorityCheckpoint
        envelope.recoveryAccepted

def joinAdmittedReplicaKnowledge
    {lineage : PublicationDomainRegistryTrustRootLineage}
    {admissionAuthority : ReplicaKnowledgeAdmissionAuthority lineage}
    (left right :
      AuthorityIssuedReplicaKnowledgeEnvelope lineage admissionAuthority) :
    ReplicaRegistryCheckpointKnowledge lineage :=
  joinReplicaRegistryCheckpointKnowledge left.knowledge right.knowledge

theorem admittedJoinNeverFallsBelowLeftDurableCheckpoint
    {lineage : PublicationDomainRegistryTrustRootLineage}
    {admissionAuthority : ReplicaKnowledgeAdmissionAuthority lineage}
    (left right :
      AuthorityIssuedReplicaKnowledgeEnvelope lineage admissionAuthority) :
    (admissionAuthority.recoveryAuthority
        left.senderIdentity).durableCommittedPosition ≤
      (joinAdmittedReplicaKnowledge left right).minimumPosition := by
  exact Nat.le_trans
    (admittedEnvelopeKnowledgeNeverFallsBelowDurableCheckpoint left)
    (replicaRegistryCheckpointJoinNeverLowersLeft
      left.knowledge right.knowledge)

theorem admittedJoinNeverFallsBelowRightDurableCheckpoint
    {lineage : PublicationDomainRegistryTrustRootLineage}
    {admissionAuthority : ReplicaKnowledgeAdmissionAuthority lineage}
    (left right :
      AuthorityIssuedReplicaKnowledgeEnvelope lineage admissionAuthority) :
    (admissionAuthority.recoveryAuthority
        right.senderIdentity).durableCommittedPosition ≤
      (joinAdmittedReplicaKnowledge left right).minimumPosition := by
  exact Nat.le_trans
    (admittedEnvelopeKnowledgeNeverFallsBelowDurableCheckpoint right)
    (replicaRegistryCheckpointJoinNeverLowersRight
      left.knowledge right.knowledge)

theorem admittedJoinPreservesEitherRollbackRejection
    {lineage : PublicationDomainRegistryTrustRootLineage}
    {admissionAuthority : ReplicaKnowledgeAdmissionAuthority lineage}
    (left right :
      AuthorityIssuedReplicaKnowledgeEnvelope lineage admissionAuthority)
    {candidatePosition : Nat}
    (rejected :
      candidatePosition < left.knowledge.minimumPosition ∨
        candidatePosition < right.knowledge.minimumPosition) :
    ¬ replicaKnowledgeAcceptsPosition
        (joinAdmittedReplicaKnowledge left right)
        candidatePosition :=
  replicaRegistryCheckpointJoinPreservesEitherRollbackRejection
    left.knowledge right.knowledge rejected

end AgenticAILabProof.Enterprise.PublicationDomainRegistryReplicaProvenanceClosure
