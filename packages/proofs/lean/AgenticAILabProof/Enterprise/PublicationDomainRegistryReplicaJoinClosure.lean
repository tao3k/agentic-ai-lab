-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.PublicationDomainRegistryRecoveryClosure

namespace AgenticAILabProof.Enterprise.PublicationDomainRegistryReplicaJoinClosure

open AgenticAILabProof.Enterprise.PublicationDomainRegistryLineageClosure
open AgenticAILabProof.Enterprise.PublicationDomainRegistryRecoveryClosure
open AgenticAILabProof.Enterprise.CheckpointWatermarkRecoveryClosure
open AgenticAILabProof.Enterprise.PublicationDomainRegistryTrustClosure

structure ReplicaRegistryCheckpointKnowledge
    (lineage : PublicationDomainRegistryTrustRootLineage) where
  minimumPosition : Nat
  deriving DecidableEq

def replicaKnowledgeAcceptsPosition
    {lineage : PublicationDomainRegistryTrustRootLineage}
    (knowledge : ReplicaRegistryCheckpointKnowledge lineage)
    (candidatePosition : Nat) : Prop :=
  knowledge.minimumPosition ≤ candidatePosition

theorem independentReplicaCheckpointsPermitSplitView
    (lineage : PublicationDomainRegistryTrustRootLineage) :
    ∃ (left right : ReplicaRegistryCheckpointKnowledge lineage)
      (candidatePosition : Nat),
      replicaKnowledgeAcceptsPosition left candidatePosition ∧
        ¬ replicaKnowledgeAcceptsPosition right candidatePosition := by
  let left : ReplicaRegistryCheckpointKnowledge lineage := {
    minimumPosition := 5
  }
  let right : ReplicaRegistryCheckpointKnowledge lineage := {
    minimumPosition := 8
  }
  refine ⟨left, right, 6, ?_, ?_⟩
  · simp [replicaKnowledgeAcceptsPosition, left]
  · simp [replicaKnowledgeAcceptsPosition, right]

def joinReplicaRegistryCheckpointKnowledge
    {lineage : PublicationDomainRegistryTrustRootLineage}
    (left right : ReplicaRegistryCheckpointKnowledge lineage) :
    ReplicaRegistryCheckpointKnowledge lineage := {
  minimumPosition := max left.minimumPosition right.minimumPosition
}

theorem replicaRegistryCheckpointJoinCommutative
    {lineage : PublicationDomainRegistryTrustRootLineage}
    (left right : ReplicaRegistryCheckpointKnowledge lineage) :
    joinReplicaRegistryCheckpointKnowledge left right =
      joinReplicaRegistryCheckpointKnowledge right left := by
  cases left
  cases right
  simp [joinReplicaRegistryCheckpointKnowledge, Nat.max_comm]

theorem replicaRegistryCheckpointJoinAssociative
    {lineage : PublicationDomainRegistryTrustRootLineage}
    (left middle right : ReplicaRegistryCheckpointKnowledge lineage) :
    joinReplicaRegistryCheckpointKnowledge
        (joinReplicaRegistryCheckpointKnowledge left middle) right =
      joinReplicaRegistryCheckpointKnowledge
        left (joinReplicaRegistryCheckpointKnowledge middle right) := by
  cases left
  cases middle
  cases right
  simp [joinReplicaRegistryCheckpointKnowledge, Nat.max_assoc]

theorem replicaRegistryCheckpointJoinIdempotent
    {lineage : PublicationDomainRegistryTrustRootLineage}
    (knowledge : ReplicaRegistryCheckpointKnowledge lineage) :
    joinReplicaRegistryCheckpointKnowledge knowledge knowledge =
      knowledge := by
  cases knowledge
  simp [joinReplicaRegistryCheckpointKnowledge]

theorem replicaRegistryCheckpointJoinNeverLowersLeft
    {lineage : PublicationDomainRegistryTrustRootLineage}
    (left right : ReplicaRegistryCheckpointKnowledge lineage) :
    left.minimumPosition ≤
      (joinReplicaRegistryCheckpointKnowledge left right).minimumPosition :=
  Nat.le_max_left _ _

theorem replicaRegistryCheckpointJoinNeverLowersRight
    {lineage : PublicationDomainRegistryTrustRootLineage}
    (left right : ReplicaRegistryCheckpointKnowledge lineage) :
    right.minimumPosition ≤
      (joinReplicaRegistryCheckpointKnowledge left right).minimumPosition :=
  Nat.le_max_right _ _

theorem replicaRegistryCheckpointJoinPreservesEitherRollbackRejection
    {lineage : PublicationDomainRegistryTrustRootLineage}
    (left right : ReplicaRegistryCheckpointKnowledge lineage)
    {candidatePosition : Nat}
    (rejected :
      candidatePosition < left.minimumPosition ∨
        candidatePosition < right.minimumPosition) :
    ¬ replicaKnowledgeAcceptsPosition
        (joinReplicaRegistryCheckpointKnowledge left right)
        candidatePosition := by
  intro joinedAcceptance
  cases rejected with
  | inl rejectedByLeft =>
      exact (Nat.not_le_of_gt rejectedByLeft)
        (Nat.le_trans
          (replicaRegistryCheckpointJoinNeverLowersLeft left right)
          joinedAcceptance)
  | inr rejectedByRight =>
      exact (Nat.not_le_of_gt rejectedByRight)
        (Nat.le_trans
          (replicaRegistryCheckpointJoinNeverLowersRight left right)
          joinedAcceptance)

def replicaKnowledgeFromIssuedRecovery
    {lineage : PublicationDomainRegistryTrustRootLineage}
    (authority : DurableRegistryCheckpointRecoveryAuthority lineage)
    (evidence : RegistryTrustRootRecoveryEvidence lineage)
    (_accepted : authorityIssuedRegistryTrustRootRecovery authority evidence) :
    ReplicaRegistryCheckpointKnowledge lineage := {
  minimumPosition := evidence.recoveredPosition
}

theorem issuedReplicaKnowledgeNeverFallsBelowDurableCheckpoint
    {lineage : PublicationDomainRegistryTrustRootLineage}
    {authority : DurableRegistryCheckpointRecoveryAuthority lineage}
    {evidence : RegistryTrustRootRecoveryEvidence lineage}
    (accepted : authorityIssuedRegistryTrustRootRecovery authority evidence) :
    authority.durableCommittedPosition ≤
      (replicaKnowledgeFromIssuedRecovery
        authority evidence accepted).minimumPosition :=
  authorityIssuedRecoveryNeverRestoresBeforeDurableCheckpoint accepted

/--
The weak validity-only shape is retained as a counterexample owner.  It can
carry interval-valid content evidence without proving that the durable recovery
authority issued that evidence.
-/
structure ValidityOnlyContentAwareReplicaRegistryCheckpointKnowledge
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage) where
  recoveryEvidence :
    ContentAwareRegistryTrustRootRecoveryEvidence governedLineage
  positionKnowledge :
    ReplicaRegistryCheckpointKnowledge governedLineage.lineage
  positionMatchesRecovery :
    positionKnowledge.minimumPosition =
      recoveryEvidence.positionEvidence.recoveredPosition
  positionRecoveryValid :
    validRegistryTrustRootRecovery recoveryEvidence.positionEvidence

/--
Replica knowledge derived from content-aware recovery retains the position
projection, recovery receipt, issuing authority, and issuance proof.
-/
structure ContentAwareReplicaRegistryCheckpointKnowledge
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage) where
  recoveryEvidence :
    ContentAwareRegistryTrustRootRecoveryEvidence governedLineage
  positionKnowledge :
    ReplicaRegistryCheckpointKnowledge governedLineage.lineage
  positionMatchesRecovery :
    positionKnowledge.minimumPosition =
      recoveryEvidence.positionEvidence.recoveredPosition
  positionRecoveryValid :
    validRegistryTrustRootRecovery recoveryEvidence.positionEvidence
  recoveryAuthority :
    DurableContentAwareRegistryCheckpointRecoveryAuthority governedLineage
  authorityIssued :
    authorityIssuedContentAwareRegistryTrustRootRecovery
      recoveryAuthority recoveryEvidence

def contentAwareReplicaKnowledgeFromIssuedRecovery
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (authority :
      DurableContentAwareRegistryCheckpointRecoveryAuthority governedLineage)
    (evidence : ContentAwareRegistryTrustRootRecoveryEvidence governedLineage)
    (accepted :
      authorityIssuedContentAwareRegistryTrustRootRecovery authority evidence) :
    ContentAwareReplicaRegistryCheckpointKnowledge governedLineage := by
  let positionAccepted :
      authorityIssuedRegistryTrustRootRecovery
        authority.positionAuthority evidence.positionEvidence :=
    ⟨authority.issuanceBindsPositionEvidence accepted.1, accepted.2⟩
  exact {
    recoveryEvidence := evidence
    positionKnowledge :=
      replicaKnowledgeFromIssuedRecovery
        authority.positionAuthority evidence.positionEvidence positionAccepted
    positionMatchesRecovery := rfl
    positionRecoveryValid := accepted.2
    recoveryAuthority := authority
    authorityIssued := accepted
  }

theorem validityOnlyReplicaKnowledgePermitsUnissuedRecovery
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (positionAuthority :
      DurableRegistryCheckpointRecoveryAuthority governedLineage.lineage)
    (evidence : ContentAwareRegistryTrustRootRecoveryEvidence governedLineage)
    (validPositionRecovery :
      validRegistryTrustRootRecovery evidence.positionEvidence) :
    ∃ (authority :
        DurableContentAwareRegistryCheckpointRecoveryAuthority governedLineage)
      (knowledge :
        ValidityOnlyContentAwareReplicaRegistryCheckpointKnowledge
          governedLineage),
      knowledge.recoveryEvidence = evidence ∧
        ¬ authority.issued evidence := by
  let authority :
      DurableContentAwareRegistryCheckpointRecoveryAuthority governedLineage := {
    positionAuthority := positionAuthority
    issued := fun _ => False
    issuanceBindsPositionEvidence := by
      intro candidate issued
      contradiction
    validatedRegistryClaim :=
      publicationDomainRegistryTrustClaim
        (governedLineage.lineage.published
          positionAuthority.durableCommittedPosition).trustRoot
    claimMatchesDurableRoot := rfl
  }
  let knowledge :
      ValidityOnlyContentAwareReplicaRegistryCheckpointKnowledge
        governedLineage := {
    recoveryEvidence := evidence
    positionKnowledge := {
      minimumPosition := evidence.positionEvidence.recoveredPosition
    }
    positionMatchesRecovery := rfl
    positionRecoveryValid := validPositionRecovery
  }
  refine ⟨authority, knowledge, rfl, ?_⟩
  simp [authority]

/--
A content-aware replica join supplies descriptor dispositions from both input
recovery origins to the max-position join.  It cannot manufacture content
safety from the arithmetic max alone.
-/
structure ContentAwareReplicaRegistryCheckpointJoinEvidence
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left right :
      ContentAwareReplicaRegistryCheckpointKnowledge governedLineage) where
  joinedPosition : Nat
  joinedPositionMatches :
    joinedPosition =
      max left.positionKnowledge.minimumPosition
        right.positionKnowledge.minimumPosition
  leftDescriptorDisposition :
    ∀ descriptor,
      (governedLineage.lineage.published
          left.recoveryEvidence.positionEvidence.committedPosition).trustRoot.registry.registered
        descriptor →
      DescriptorDispositionAcrossRegistryInterval
        governedLineage
        left.recoveryEvidence.positionEvidence.committedPosition
        joinedPosition
        descriptor
  rightDescriptorDisposition :
    ∀ descriptor,
      (governedLineage.lineage.published
          right.recoveryEvidence.positionEvidence.committedPosition).trustRoot.registry.registered
        descriptor →
      DescriptorDispositionAcrossRegistryInterval
        governedLineage
        right.recoveryEvidence.positionEvidence.committedPosition
        joinedPosition
        descriptor

def positionKnowledgeOfContentAwareReplicaJoin
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    {left right :
      ContentAwareReplicaRegistryCheckpointKnowledge governedLineage}
    (evidence :
      ContentAwareReplicaRegistryCheckpointJoinEvidence left right) :
    ReplicaRegistryCheckpointKnowledge governedLineage.lineage := {
  minimumPosition := evidence.joinedPosition
}

theorem positionOnlyReplicaJoinIsIndependentOfRegistryContent
    (lineage : PublicationDomainRegistryTrustRootLineage) :
    ∃ (descriptor : PublicationDomainDescriptor)
      (leftRegistry rightRegistry : PublicationDomainIdentityRegistry)
      (left right : ReplicaRegistryCheckpointKnowledge lineage),
      leftRegistry.registered descriptor ∧
        ¬ rightRegistry.registered descriptor ∧
          (joinReplicaRegistryCheckpointKnowledge left right).minimumPosition = 1 := by
  let descriptor : PublicationDomainDescriptor := {
    domainIdentity := 401
    authorityIdentity := 409
    semanticIdentity := 419
  }
  let replacement : PublicationDomainDescriptor := {
    domainIdentity := 401
    authorityIdentity := 409
    semanticIdentity := 421
  }
  let leftRegistry := singletonPublicationDomainRegistry descriptor
  let rightRegistry := singletonPublicationDomainRegistry replacement
  let left : ReplicaRegistryCheckpointKnowledge lineage := {
    minimumPosition := 1
  }
  let right : ReplicaRegistryCheckpointKnowledge lineage := {
    minimumPosition := 1
  }
  refine ⟨descriptor, leftRegistry, rightRegistry, left, right, ?_, ?_, ?_⟩
  · simp [leftRegistry, singletonPublicationDomainRegistry]
  · simp [rightRegistry, singletonPublicationDomainRegistry, descriptor,
      replacement]
  · simp [joinReplicaRegistryCheckpointKnowledge, left, right]

theorem contentAwareReplicaJoinPositionMatchesPositionJoin
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    {left right :
      ContentAwareReplicaRegistryCheckpointKnowledge governedLineage}
    (evidence :
      ContentAwareReplicaRegistryCheckpointJoinEvidence left right) :
    (positionKnowledgeOfContentAwareReplicaJoin evidence).minimumPosition =
      (joinReplicaRegistryCheckpointKnowledge
        left.positionKnowledge right.positionKnowledge).minimumPosition := by
  simp [positionKnowledgeOfContentAwareReplicaJoin,
    joinReplicaRegistryCheckpointKnowledge, evidence.joinedPositionMatches]

theorem contentAwareReplicaJoinCoversLeftPosition
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    {left right :
      ContentAwareReplicaRegistryCheckpointKnowledge governedLineage}
    (evidence :
      ContentAwareReplicaRegistryCheckpointJoinEvidence left right) :
    left.positionKnowledge.minimumPosition ≤ evidence.joinedPosition := by
  rw [evidence.joinedPositionMatches]
  exact Nat.le_max_left _ _

theorem contentAwareReplicaJoinCoversRightPosition
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    {left right :
      ContentAwareReplicaRegistryCheckpointKnowledge governedLineage}
    (evidence :
      ContentAwareReplicaRegistryCheckpointJoinEvidence left right) :
    right.positionKnowledge.minimumPosition ≤ evidence.joinedPosition := by
  rw [evidence.joinedPositionMatches]
  exact Nat.le_max_right _ _

theorem contentAwareReplicaJoinCarriesLeftDescriptorDisposition
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    {left right :
      ContentAwareReplicaRegistryCheckpointKnowledge governedLineage}
    (evidence :
      ContentAwareReplicaRegistryCheckpointJoinEvidence left right)
    {descriptor : PublicationDomainDescriptor}
    (committedDescriptor :
      (governedLineage.lineage.published
          left.recoveryEvidence.positionEvidence.committedPosition).trustRoot.registry.registered
        descriptor) :
    DescriptorDispositionAcrossRegistryInterval
      governedLineage
      left.recoveryEvidence.positionEvidence.committedPosition
      evidence.joinedPosition
      descriptor :=
  evidence.leftDescriptorDisposition descriptor committedDescriptor

theorem contentAwareReplicaJoinCarriesRightDescriptorDisposition
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    {left right :
      ContentAwareReplicaRegistryCheckpointKnowledge governedLineage}
    (evidence :
      ContentAwareReplicaRegistryCheckpointJoinEvidence left right)
    {descriptor : PublicationDomainDescriptor}
    (committedDescriptor :
      (governedLineage.lineage.published
          right.recoveryEvidence.positionEvidence.committedPosition).trustRoot.registry.registered
        descriptor) :
    DescriptorDispositionAcrossRegistryInterval
      governedLineage
      right.recoveryEvidence.positionEvidence.committedPosition
      evidence.joinedPosition
      descriptor :=
  evidence.rightDescriptorDisposition descriptor committedDescriptor

/--
A reusable content-aware replica summary records every committed origin whose
descriptor obligations are represented at its minimum position.  Unlike the
pairwise join evidence, this structure is closed under repeated joins.
-/
structure ContentAwareReplicaRegistryCheckpointSummary
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage) where
  minimumPosition : Nat
  coveredOrigin : Nat → Prop
  originCovered :
    ∀ {originPosition},
      coveredOrigin originPosition → originPosition ≤ minimumPosition
  descriptorDisposition :
    ∀ {originPosition},
      coveredOrigin originPosition →
        ∀ descriptor,
          (governedLineage.lineage.published
              originPosition).trustRoot.registry.registered descriptor →
            DescriptorDispositionAcrossRegistryInterval
              governedLineage originPosition minimumPosition descriptor

def contentAwareReplicaSummaryOfRecovery
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (knowledge :
      ContentAwareReplicaRegistryCheckpointKnowledge governedLineage) :
    ContentAwareReplicaRegistryCheckpointSummary governedLineage := {
  minimumPosition := knowledge.positionKnowledge.minimumPosition
  coveredOrigin := fun originPosition =>
    originPosition =
      knowledge.recoveryEvidence.positionEvidence.committedPosition
  originCovered := by
    intro originPosition originMatches
    subst originPosition
    rw [knowledge.positionMatchesRecovery]
    exact knowledge.positionRecoveryValid
  descriptorDisposition := by
    intro originPosition originMatches descriptor registeredAtOrigin
    subst originPosition
    rw [knowledge.positionMatchesRecovery]
    exact
      knowledge.recoveryEvidence.descriptorDisposition
        descriptor registeredAtOrigin
}

def joinContentAwareReplicaRegistryCheckpointSummary
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left right :
      ContentAwareReplicaRegistryCheckpointSummary governedLineage) :
    ContentAwareReplicaRegistryCheckpointSummary governedLineage := {
  minimumPosition := max left.minimumPosition right.minimumPosition
  coveredOrigin := fun originPosition =>
    left.coveredOrigin originPosition ∨ right.coveredOrigin originPosition
  originCovered := by
    intro originPosition covered
    rcases covered with leftCovered | rightCovered
    · exact
        Nat.le_trans (left.originCovered leftCovered)
          (Nat.le_max_left _ _)
    · exact
        Nat.le_trans (right.originCovered rightCovered)
          (Nat.le_max_right _ _)
  descriptorDisposition := by
    intro originPosition covered descriptor registeredAtOrigin
    rcases covered with leftCovered | rightCovered
    · exact
        extendDescriptorDispositionAcrossRegistryInterval
          governedLineage
          (left.originCovered leftCovered)
          (Nat.le_max_left _ _)
          (left.descriptorDisposition leftCovered descriptor registeredAtOrigin)
    · exact
        extendDescriptorDispositionAcrossRegistryInterval
          governedLineage
          (right.originCovered rightCovered)
          (Nat.le_max_right _ _)
          (right.descriptorDisposition rightCovered descriptor registeredAtOrigin)
}

def positionKnowledgeOfContentAwareReplicaSummary
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (summary :
      ContentAwareReplicaRegistryCheckpointSummary governedLineage) :
    ReplicaRegistryCheckpointKnowledge governedLineage.lineage := {
  minimumPosition := summary.minimumPosition
}

theorem contentAwareReplicaSummaryJoinPreservesLeftOrigin
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left right :
      ContentAwareReplicaRegistryCheckpointSummary governedLineage)
    {originPosition : Nat}
    (covered : left.coveredOrigin originPosition) :
    (joinContentAwareReplicaRegistryCheckpointSummary left right).coveredOrigin
      originPosition :=
  Or.inl covered

theorem contentAwareReplicaSummaryJoinPreservesRightOrigin
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left right :
      ContentAwareReplicaRegistryCheckpointSummary governedLineage)
    {originPosition : Nat}
    (covered : right.coveredOrigin originPosition) :
    (joinContentAwareReplicaRegistryCheckpointSummary left right).coveredOrigin
      originPosition :=
  Or.inr covered

theorem contentAwareReplicaSummaryJoinCarriesDescriptorDisposition
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left right :
      ContentAwareReplicaRegistryCheckpointSummary governedLineage)
    {originPosition : Nat}
    (covered :
      (joinContentAwareReplicaRegistryCheckpointSummary left right).coveredOrigin
        originPosition)
    {descriptor : PublicationDomainDescriptor}
    (registeredAtOrigin :
      (governedLineage.lineage.published
          originPosition).trustRoot.registry.registered descriptor) :
    DescriptorDispositionAcrossRegistryInterval
      governedLineage
      originPosition
      (joinContentAwareReplicaRegistryCheckpointSummary left right).minimumPosition
      descriptor :=
  (joinContentAwareReplicaRegistryCheckpointSummary left right).descriptorDisposition
    covered descriptor registeredAtOrigin

theorem contentAwareReplicaSummaryJoinPositionMatchesPositionJoin
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left right :
      ContentAwareReplicaRegistryCheckpointSummary governedLineage) :
    (positionKnowledgeOfContentAwareReplicaSummary
      (joinContentAwareReplicaRegistryCheckpointSummary left right)).minimumPosition =
      (joinReplicaRegistryCheckpointKnowledge
        (positionKnowledgeOfContentAwareReplicaSummary left)
        (positionKnowledgeOfContentAwareReplicaSummary right)).minimumPosition :=
  rfl

theorem contentAwareReplicaSummaryJoinPositionAssociative
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left middle right :
      ContentAwareReplicaRegistryCheckpointSummary governedLineage) :
    (joinContentAwareReplicaRegistryCheckpointSummary
      (joinContentAwareReplicaRegistryCheckpointSummary left middle)
      right).minimumPosition =
      (joinContentAwareReplicaRegistryCheckpointSummary
        left
        (joinContentAwareReplicaRegistryCheckpointSummary middle right)).minimumPosition := by
  exact Nat.max_assoc _ _ _

theorem contentAwareReplicaSummaryJoinOriginsAssociative
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left middle right :
      ContentAwareReplicaRegistryCheckpointSummary governedLineage)
    (originPosition : Nat) :
    (joinContentAwareReplicaRegistryCheckpointSummary
      (joinContentAwareReplicaRegistryCheckpointSummary left middle)
      right).coveredOrigin originPosition ↔
      (joinContentAwareReplicaRegistryCheckpointSummary
        left
        (joinContentAwareReplicaRegistryCheckpointSummary middle right)).coveredOrigin
        originPosition := by
  simp [joinContentAwareReplicaRegistryCheckpointSummary, or_assoc]

theorem contentAwareReplicaSummaryJoinPositionCommutative
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left right :
      ContentAwareReplicaRegistryCheckpointSummary governedLineage) :
    (joinContentAwareReplicaRegistryCheckpointSummary left right).minimumPosition =
      (joinContentAwareReplicaRegistryCheckpointSummary right left).minimumPosition := by
  exact Nat.max_comm _ _

theorem contentAwareReplicaSummaryJoinOriginsCommutative
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left right :
      ContentAwareReplicaRegistryCheckpointSummary governedLineage)
    (originPosition : Nat) :
    (joinContentAwareReplicaRegistryCheckpointSummary left right).coveredOrigin
        originPosition ↔
      (joinContentAwareReplicaRegistryCheckpointSummary right left).coveredOrigin
        originPosition := by
  simp [joinContentAwareReplicaRegistryCheckpointSummary, or_comm]

theorem contentAwareReplicaSummaryJoinPositionIdempotent
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (summary :
      ContentAwareReplicaRegistryCheckpointSummary governedLineage) :
    (joinContentAwareReplicaRegistryCheckpointSummary summary summary).minimumPosition =
      summary.minimumPosition := by
  exact Nat.max_self _

theorem contentAwareReplicaSummaryJoinOriginsIdempotent
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (summary :
      ContentAwareReplicaRegistryCheckpointSummary governedLineage)
    (originPosition : Nat) :
    (joinContentAwareReplicaRegistryCheckpointSummary summary summary).coveredOrigin
        originPosition ↔
      summary.coveredOrigin originPosition := by
  simp [joinContentAwareReplicaRegistryCheckpointSummary]

/--
An origin is the complete authority-issued recovery event, not merely its
committed position.  Distinct authorities or receipts at the same position
remain distinct provenance obligations.
-/
structure AuthorityIssuedReplicaRecoveryOrigin
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage) where
  authority :
    DurableContentAwareRegistryCheckpointRecoveryAuthority governedLineage
  evidence : ContentAwareRegistryTrustRootRecoveryEvidence governedLineage
  accepted :
    authorityIssuedContentAwareRegistryTrustRootRecovery authority evidence

def authorityIssuedReplicaRecoveryOriginOfKnowledge
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (knowledge :
      ContentAwareReplicaRegistryCheckpointKnowledge governedLineage) :
    AuthorityIssuedReplicaRecoveryOrigin governedLineage := {
  authority := knowledge.recoveryAuthority
  evidence := knowledge.recoveryEvidence
  accepted := knowledge.authorityIssued
}

theorem authorityIssuedReplicaRecoveryOriginCarriesIssuance
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage) :
    origin.authority.issued origin.evidence :=
  origin.accepted.1

theorem authorityIssuedReplicaRecoveryOriginCarriesPositionValidity
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage) :
    validRegistryTrustRootRecovery origin.evidence.positionEvidence :=
  origin.accepted.2

theorem authorityIssuedReplicaRecoveryOriginBindsRegistryAuthority
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage) :
    origin.authority.validatedRegistryClaim.registryAuthorityIdentity =
      (governedLineage.lineage.published
        origin.authority.positionAuthority.recoveredCheckpoint.currentPosition).trustRoot.registryAuthorityIdentity :=
  durableContentAwareRecoveryAuthorityBindsRecoveredRegistryAuthority
    origin.authority

theorem authorityIssuedReplicaRecoveryOriginBindsRegistrySemantics
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage) :
    origin.authority.validatedRegistryClaim.registrySemanticIdentity =
      (governedLineage.lineage.published
        origin.authority.positionAuthority.recoveredCheckpoint.currentPosition).trustRoot.registrySemanticIdentity :=
  durableContentAwareRecoveryAuthorityBindsRecoveredRegistrySemantics
    origin.authority

theorem authorityIssuedReplicaRecoveryOriginRejectsMismatchedRegistryClaim
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage)
    (mismatch :
      origin.authority.validatedRegistryClaim.registryAuthorityIdentity ≠
          (governedLineage.lineage.published
            origin.authority.positionAuthority.recoveredCheckpoint.currentPosition).trustRoot.registryAuthorityIdentity ∨
        origin.authority.validatedRegistryClaim.registrySemanticIdentity ≠
          (governedLineage.lineage.published
            origin.authority.positionAuthority.recoveredCheckpoint.currentPosition).trustRoot.registrySemanticIdentity) :
    False := by
  rcases mismatch with authorityMismatch | semanticsMismatch
  · exact
      authorityMismatch
        (authorityIssuedReplicaRecoveryOriginBindsRegistryAuthority origin)
  · exact
      semanticsMismatch
        (authorityIssuedReplicaRecoveryOriginBindsRegistrySemantics origin)

/--
The provenance-preserving n-way summary indexes obligations by the complete
authority-issued origin.  Its join remains closed over the same summary type.
-/
structure CommitBoundAuthorityProvenanceReplicaRegistryCheckpointSummary
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage) where
  minimumPosition : Nat
  coveredOrigin : AuthorityIssuedReplicaRecoveryOrigin governedLineage → Prop
  originCovered :
    ∀ {origin},
      coveredOrigin origin →
        origin.evidence.positionEvidence.committedPosition ≤ minimumPosition
  descriptorDisposition :
    ∀ {origin},
      coveredOrigin origin →
        ∀ descriptor,
          (governedLineage.lineage.published
              origin.evidence.positionEvidence.committedPosition).trustRoot.registry.registered
            descriptor →
          DescriptorDispositionAcrossRegistryInterval
            governedLineage
            origin.evidence.positionEvidence.committedPosition
            minimumPosition
            descriptor

theorem commitBoundProvenanceSummaryPermitsRecoveredHeadRegression
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage)
    (recoveredAfterCommit :
      origin.evidence.positionEvidence.committedPosition <
        origin.evidence.positionEvidence.recoveredPosition)
    (committedRegistryEmpty :
      ∀ descriptor,
        ¬ (governedLineage.lineage.published
            origin.evidence.positionEvidence.committedPosition).trustRoot.registry.registered
              descriptor) :
    ∃ summary :
        CommitBoundAuthorityProvenanceReplicaRegistryCheckpointSummary
          governedLineage,
      summary.coveredOrigin origin ∧
        summary.minimumPosition <
          origin.evidence.positionEvidence.recoveredPosition := by
  let summary :
      CommitBoundAuthorityProvenanceReplicaRegistryCheckpointSummary
        governedLineage := {
    minimumPosition := origin.evidence.positionEvidence.committedPosition
    coveredOrigin := fun candidate => candidate = origin
    originCovered := by
      intro candidate candidateMatches
      subst candidate
      exact Nat.le_refl _
    descriptorDisposition := by
      intro candidate candidateMatches descriptor registeredAtOrigin
      subst candidate
      exact False.elim (committedRegistryEmpty descriptor registeredAtOrigin)
  }
  exact ⟨summary, rfl, recoveredAfterCommit⟩

structure AuthorityProvenanceReplicaRegistryCheckpointSummary
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage) where
  minimumPosition : Nat
  coveredOrigin : AuthorityIssuedReplicaRecoveryOrigin governedLineage → Prop
  originCovered :
    ∀ {origin},
      coveredOrigin origin →
        origin.evidence.positionEvidence.committedPosition ≤ minimumPosition
  recoveredHeadCovered :
    ∀ {origin},
      coveredOrigin origin →
        origin.evidence.positionEvidence.recoveredPosition ≤ minimumPosition
  descriptorDisposition :
    ∀ {origin},
      coveredOrigin origin →
        ∀ descriptor,
          (governedLineage.lineage.published
              origin.evidence.positionEvidence.committedPosition).trustRoot.registry.registered
            descriptor →
          DescriptorDispositionAcrossRegistryInterval
            governedLineage
            origin.evidence.positionEvidence.committedPosition
            minimumPosition
            descriptor

def authorityProvenanceReplicaSummaryOfRecovery
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (knowledge :
      ContentAwareReplicaRegistryCheckpointKnowledge governedLineage) :
    AuthorityProvenanceReplicaRegistryCheckpointSummary governedLineage := by
  let origin := authorityIssuedReplicaRecoveryOriginOfKnowledge knowledge
  exact {
    minimumPosition := knowledge.positionKnowledge.minimumPosition
    coveredOrigin := fun candidate => candidate = origin
    originCovered := by
      intro candidate candidateMatches
      subst candidate
      change
        knowledge.recoveryEvidence.positionEvidence.committedPosition ≤
          knowledge.positionKnowledge.minimumPosition
      rw [knowledge.positionMatchesRecovery]
      exact knowledge.positionRecoveryValid
    recoveredHeadCovered := by
      intro candidate candidateMatches
      subst candidate
      change
        knowledge.recoveryEvidence.positionEvidence.recoveredPosition ≤
          knowledge.positionKnowledge.minimumPosition
      rw [knowledge.positionMatchesRecovery]
      exact Nat.le_refl _
    descriptorDisposition := by
      intro candidate candidateMatches descriptor registeredAtOrigin
      subst candidate
      change
        DescriptorDispositionAcrossRegistryInterval
          governedLineage
          knowledge.recoveryEvidence.positionEvidence.committedPosition
          knowledge.positionKnowledge.minimumPosition
          descriptor
      rw [knowledge.positionMatchesRecovery]
      exact
        knowledge.recoveryEvidence.descriptorDisposition
          descriptor registeredAtOrigin
  }

def joinAuthorityProvenanceReplicaRegistryCheckpointSummary
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left right :
      AuthorityProvenanceReplicaRegistryCheckpointSummary governedLineage) :
    AuthorityProvenanceReplicaRegistryCheckpointSummary governedLineage := {
  minimumPosition := max left.minimumPosition right.minimumPosition
  coveredOrigin := fun origin =>
    left.coveredOrigin origin ∨ right.coveredOrigin origin
  originCovered := by
    intro origin covered
    rcases covered with leftCovered | rightCovered
    · exact
        Nat.le_trans (left.originCovered leftCovered)
          (Nat.le_max_left _ _)
    · exact
        Nat.le_trans (right.originCovered rightCovered)
          (Nat.le_max_right _ _)
  recoveredHeadCovered := by
    intro origin covered
    rcases covered with leftCovered | rightCovered
    · exact
        Nat.le_trans (left.recoveredHeadCovered leftCovered)
          (Nat.le_max_left _ _)
    · exact
        Nat.le_trans (right.recoveredHeadCovered rightCovered)
          (Nat.le_max_right _ _)
  descriptorDisposition := by
    intro origin covered descriptor registeredAtOrigin
    rcases covered with leftCovered | rightCovered
    · exact
        extendDescriptorDispositionAcrossRegistryInterval
          governedLineage
          (left.originCovered leftCovered)
          (Nat.le_max_left _ _)
          (left.descriptorDisposition leftCovered descriptor registeredAtOrigin)
    · exact
        extendDescriptorDispositionAcrossRegistryInterval
          governedLineage
          (right.originCovered rightCovered)
          (Nat.le_max_right _ _)
          (right.descriptorDisposition rightCovered descriptor registeredAtOrigin)
}

theorem authorityProvenanceSummaryJoinPreservesLeftOrigin
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left right :
      AuthorityProvenanceReplicaRegistryCheckpointSummary governedLineage)
    {origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage}
    (covered : left.coveredOrigin origin) :
    (joinAuthorityProvenanceReplicaRegistryCheckpointSummary left right).coveredOrigin
      origin :=
  Or.inl covered

theorem authorityProvenanceSummaryJoinPreservesRightOrigin
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left right :
      AuthorityProvenanceReplicaRegistryCheckpointSummary governedLineage)
    {origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage}
    (covered : right.coveredOrigin origin) :
    (joinAuthorityProvenanceReplicaRegistryCheckpointSummary left right).coveredOrigin
      origin :=
  Or.inr covered

theorem authorityProvenanceSummaryJoinCarriesDescriptorDisposition
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left right :
      AuthorityProvenanceReplicaRegistryCheckpointSummary governedLineage)
    {origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage}
    (covered :
      (joinAuthorityProvenanceReplicaRegistryCheckpointSummary left right).coveredOrigin
        origin)
    {descriptor : PublicationDomainDescriptor}
    (registeredAtOrigin :
      (governedLineage.lineage.published
          origin.evidence.positionEvidence.committedPosition).trustRoot.registry.registered
        descriptor) :
    DescriptorDispositionAcrossRegistryInterval
      governedLineage
      origin.evidence.positionEvidence.committedPosition
      (joinAuthorityProvenanceReplicaRegistryCheckpointSummary
        left right).minimumPosition
      descriptor :=
  (joinAuthorityProvenanceReplicaRegistryCheckpointSummary left right).descriptorDisposition
    covered descriptor registeredAtOrigin

theorem authorityProvenanceSummaryJoinPositionAssociative
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left middle right :
      AuthorityProvenanceReplicaRegistryCheckpointSummary governedLineage) :
    (joinAuthorityProvenanceReplicaRegistryCheckpointSummary
      (joinAuthorityProvenanceReplicaRegistryCheckpointSummary left middle)
      right).minimumPosition =
      (joinAuthorityProvenanceReplicaRegistryCheckpointSummary
        left
        (joinAuthorityProvenanceReplicaRegistryCheckpointSummary
          middle right)).minimumPosition := by
  exact Nat.max_assoc _ _ _

theorem authorityProvenanceSummaryJoinOriginsAssociative
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left middle right :
      AuthorityProvenanceReplicaRegistryCheckpointSummary governedLineage)
    (origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage) :
    (joinAuthorityProvenanceReplicaRegistryCheckpointSummary
      (joinAuthorityProvenanceReplicaRegistryCheckpointSummary left middle)
      right).coveredOrigin origin ↔
      (joinAuthorityProvenanceReplicaRegistryCheckpointSummary
        left
        (joinAuthorityProvenanceReplicaRegistryCheckpointSummary
          middle right)).coveredOrigin origin := by
  simp [joinAuthorityProvenanceReplicaRegistryCheckpointSummary, or_assoc]

theorem authorityProvenanceSummaryJoinPositionCommutative
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left right :
      AuthorityProvenanceReplicaRegistryCheckpointSummary governedLineage) :
    (joinAuthorityProvenanceReplicaRegistryCheckpointSummary
      left right).minimumPosition =
      (joinAuthorityProvenanceReplicaRegistryCheckpointSummary
        right left).minimumPosition := by
  exact Nat.max_comm _ _

theorem authorityProvenanceSummaryJoinOriginsCommutative
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left right :
      AuthorityProvenanceReplicaRegistryCheckpointSummary governedLineage)
    (origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage) :
    (joinAuthorityProvenanceReplicaRegistryCheckpointSummary
      left right).coveredOrigin origin ↔
      (joinAuthorityProvenanceReplicaRegistryCheckpointSummary
        right left).coveredOrigin origin := by
  simp [joinAuthorityProvenanceReplicaRegistryCheckpointSummary, or_comm]

theorem authorityProvenanceSummaryJoinPositionIdempotent
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (summary :
      AuthorityProvenanceReplicaRegistryCheckpointSummary governedLineage) :
    (joinAuthorityProvenanceReplicaRegistryCheckpointSummary
      summary summary).minimumPosition = summary.minimumPosition := by
  exact Nat.max_self _

theorem authorityProvenanceSummaryJoinOriginsIdempotent
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (summary :
      AuthorityProvenanceReplicaRegistryCheckpointSummary governedLineage)
    (origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage) :
    (joinAuthorityProvenanceReplicaRegistryCheckpointSummary
      summary summary).coveredOrigin origin ↔
      summary.coveredOrigin origin := by
  simp [joinAuthorityProvenanceReplicaRegistryCheckpointSummary]

theorem authorityProvenanceSummaryRejectsRecoveredHeadRegression
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (summary :
      AuthorityProvenanceReplicaRegistryCheckpointSummary governedLineage)
    {origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage}
    (covered : summary.coveredOrigin origin)
    (summaryBeforeRecoveredHead :
      summary.minimumPosition <
        origin.evidence.positionEvidence.recoveredPosition) : False := by
  exact
    (Nat.not_lt_of_ge (summary.recoveredHeadCovered covered))
      summaryBeforeRecoveredHead

theorem authorityProvenanceSummaryJoinCoversLeftRecoveredHead
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left right :
      AuthorityProvenanceReplicaRegistryCheckpointSummary governedLineage)
    {origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage}
    (covered : left.coveredOrigin origin) :
    origin.evidence.positionEvidence.recoveredPosition ≤
      (joinAuthorityProvenanceReplicaRegistryCheckpointSummary
        left right).minimumPosition := by
  exact
    (joinAuthorityProvenanceReplicaRegistryCheckpointSummary
      left right).recoveredHeadCovered (Or.inl covered)

theorem authorityProvenanceSummaryJoinCoversRightRecoveredHead
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (left right :
      AuthorityProvenanceReplicaRegistryCheckpointSummary governedLineage)
    {origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage}
    (covered : right.coveredOrigin origin) :
    origin.evidence.positionEvidence.recoveredPosition ≤
      (joinAuthorityProvenanceReplicaRegistryCheckpointSummary
        left right).minimumPosition := by
  exact
    (joinAuthorityProvenanceReplicaRegistryCheckpointSummary
      left right).recoveredHeadCovered (Or.inr covered)

theorem authorityProvenanceSummaryCarriesRecoveredOnlyDescriptorAdmission
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (summary :
      AuthorityProvenanceReplicaRegistryCheckpointSummary governedLineage)
    {origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage}
    (covered : summary.coveredOrigin origin)
    {descriptor : PublicationDomainDescriptor}
    (notRegisteredAtOrigin :
      ¬ (governedLineage.lineage.published
          origin.evidence.positionEvidence.committedPosition).trustRoot.registry.registered
            descriptor)
    (registeredAtSummary :
      (governedLineage.lineage.published
          summary.minimumPosition).trustRoot.registry.registered descriptor) :
    DescriptorAdmissionAcrossRegistryInterval
      governedLineage
      origin.evidence.positionEvidence.committedPosition
      summary.minimumPosition
      descriptor := by
  exact
    governedLineageRequiresIssuedAdmissionForRecoveredOnlyDescriptor
      governedLineage
      (summary.originCovered covered)
      notRegisteredAtOrigin
      registeredAtSummary

theorem authorityProvenanceSummaryCarriesIssuedDomainRotation
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (summary :
      AuthorityProvenanceReplicaRegistryCheckpointSummary governedLineage)
    {origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage}
    (covered : summary.coveredOrigin origin)
    {oldDescriptor newDescriptor : PublicationDomainDescriptor}
    (oldRegisteredAtOrigin :
      (governedLineage.lineage.published
          origin.evidence.positionEvidence.committedPosition).trustRoot.registry.registered
            oldDescriptor)
    (newRegisteredAtSummary :
      (governedLineage.lineage.published
          summary.minimumPosition).trustRoot.registry.registered newDescriptor)
    (sameDomainIdentity :
      oldDescriptor.domainIdentity = newDescriptor.domainIdentity)
    (differentDescriptor : oldDescriptor ≠ newDescriptor) :
    AuthorityIssuedDomainRotationAcrossRegistryInterval
      governedLineage
      origin.evidence.positionEvidence.committedPosition
      summary.minimumPosition
      oldDescriptor newDescriptor := by
  exact
    governedLineageRequiresIssuedRotationAcrossRegistryInterval
      governedLineage
      (summary.originCovered covered)
      oldRegisteredAtOrigin
      newRegisteredAtSummary
      sameDomainIdentity
      differentDescriptor

theorem authorityIssuedReplicaRecoveryOriginCarriesRecoveredOnlyDescriptorAdmission
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (origin : AuthorityIssuedReplicaRecoveryOrigin governedLineage)
    {descriptor : PublicationDomainDescriptor}
    (notRegisteredAtCommit :
      ¬ (governedLineage.lineage.published
          origin.evidence.positionEvidence.committedPosition).trustRoot.registry.registered
            descriptor)
    (registeredAtRecovery :
      (governedLineage.lineage.published
          origin.evidence.positionEvidence.recoveredPosition).trustRoot.registry.registered
            descriptor) :
    DescriptorAdmissionAcrossRegistryInterval
      governedLineage
      origin.evidence.positionEvidence.committedPosition
      origin.evidence.positionEvidence.recoveredPosition
      descriptor := by
  exact
    governedLineageRequiresIssuedAdmissionForRecoveredOnlyDescriptor
      governedLineage
      (authorityIssuedReplicaRecoveryOriginCarriesPositionValidity origin)
      notRegisteredAtCommit
      registeredAtRecovery

end AgenticAILabProof.Enterprise.PublicationDomainRegistryReplicaJoinClosure
