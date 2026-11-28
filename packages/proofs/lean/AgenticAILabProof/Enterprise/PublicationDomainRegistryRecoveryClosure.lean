-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.PublicationDomainRegistryLineageClosure

namespace AgenticAILabProof.Enterprise.PublicationDomainRegistryRecoveryClosure

open AgenticAILabProof.Enterprise.PublicationDomainRegistryLineageClosure
open AgenticAILabProof.Enterprise.CheckpointWatermarkRecoveryClosure
open AgenticAILabProof.Enterprise.PublicationDomainRegistryTrustClosure

def registryPositionAcceptedByMinimum
    (minimumPosition candidatePosition : Nat) : Prop :=
  minimumPosition ≤ candidatePosition

theorem volatileRegistryCheckpointResetPermitsKnownRollback :
    ¬ registryPositionAcceptedByMinimum 5 3 ∧
      registryPositionAcceptedByMinimum 0 3 := by
  simp [registryPositionAcceptedByMinimum]

structure RegistryTrustRootRecoveryEvidence
    (lineage : PublicationDomainRegistryTrustRootLineage) where
  committedPosition : Nat
  recoveredPosition : Nat

def validRegistryTrustRootRecovery
    {lineage : PublicationDomainRegistryTrustRootLineage}
    (evidence : RegistryTrustRootRecoveryEvidence lineage) : Prop :=
  evidence.committedPosition ≤ evidence.recoveredPosition

def committedOnlyRegistryRecoveryIssuance
    {lineage : PublicationDomainRegistryTrustRootLineage}
    (durableCommittedPosition : Nat)
    (evidence : RegistryTrustRootRecoveryEvidence lineage) : Prop :=
  evidence.committedPosition = durableCommittedPosition

theorem committedOnlyIssuancePermitsUnboundedRecoveredPosition
    (lineage : PublicationDomainRegistryTrustRootLineage) :
    ∃ (evidence : RegistryTrustRootRecoveryEvidence lineage),
      committedOnlyRegistryRecoveryIssuance 5 evidence ∧
        validRegistryTrustRootRecovery evidence ∧
        5 < evidence.recoveredPosition := by
  let evidence : RegistryTrustRootRecoveryEvidence lineage := {
    committedPosition := 5
    recoveredPosition := 100
  }
  refine ⟨evidence, rfl, ?_, ?_⟩
  · change 5 ≤ 100
    decide
  · change 5 < 100
    decide

theorem validRegistryRecoveryRejectsEveryPreviouslyKnownPosition
    {lineage : PublicationDomainRegistryTrustRootLineage}
    {evidence : RegistryTrustRootRecoveryEvidence lineage}
    (valid : validRegistryTrustRootRecovery evidence)
    {candidatePosition : Nat}
    (previouslyRejected :
      candidatePosition < evidence.committedPosition) :
    ¬ registryPositionAcceptedByMinimum
        evidence.recoveredPosition candidatePosition := by
  exact Nat.not_le_of_gt (Nat.lt_of_lt_of_le previouslyRejected valid)

theorem selfReportedRegistryRecoveryCanHideDurableCheckpoint
    (lineage : PublicationDomainRegistryTrustRootLineage) :
    ∃ (evidence : RegistryTrustRootRecoveryEvidence lineage),
      validRegistryTrustRootRecovery evidence ∧
        evidence.committedPosition < 5 := by
  let evidence : RegistryTrustRootRecoveryEvidence lineage := {
    committedPosition := 0
    recoveredPosition := 0
  }
  refine ⟨evidence, ?_, ?_⟩
  · exact Nat.le_refl 0
  · exact Nat.zero_lt_succ 4

structure DurableRegistryCheckpointRecoveryAuthority
    (lineage : PublicationDomainRegistryTrustRootLineage) where
  durableCommittedPosition : Nat
  recoveredCheckpoint :
    PublicationDomainRegistryTrustRootCheckpoint lineage
  issued : RegistryTrustRootRecoveryEvidence lineage → Prop
  issuanceBindsDurableCheckpoint :
    ∀ {evidence : RegistryTrustRootRecoveryEvidence lineage}, issued evidence →
      evidence.committedPosition = durableCommittedPosition ∧
        evidence.recoveredPosition =
          recoveredCheckpoint.currentPosition

def authorityIssuedRegistryTrustRootRecovery
    {lineage : PublicationDomainRegistryTrustRootLineage}
    (authority : DurableRegistryCheckpointRecoveryAuthority lineage)
    (evidence : RegistryTrustRootRecoveryEvidence lineage) : Prop :=
  authority.issued evidence ∧ validRegistryTrustRootRecovery evidence

theorem authorityIssuedRecoveryNeverRestoresBeforeDurableCheckpoint
    {lineage : PublicationDomainRegistryTrustRootLineage}
    {authority : DurableRegistryCheckpointRecoveryAuthority lineage}
    {evidence : RegistryTrustRootRecoveryEvidence lineage}
    (accepted : authorityIssuedRegistryTrustRootRecovery authority evidence) :
    authority.durableCommittedPosition ≤ evidence.recoveredPosition := by
  calc
    authority.durableCommittedPosition = evidence.committedPosition :=
      (authority.issuanceBindsDurableCheckpoint accepted.1).1.symm
    _ ≤ evidence.recoveredPosition := accepted.2

theorem authorityIssuedRecoveryRestoresAuthorityCheckpoint
    {lineage : PublicationDomainRegistryTrustRootLineage}
    {authority : DurableRegistryCheckpointRecoveryAuthority lineage}
    {evidence : RegistryTrustRootRecoveryEvidence lineage}
    (accepted : authorityIssuedRegistryTrustRootRecovery authority evidence) :
    evidence.recoveredPosition =
      authority.recoveredCheckpoint.currentPosition :=
  (authority.issuanceBindsDurableCheckpoint accepted.1).2

theorem authorityIssuedRecoveryRejectsDurablyKnownRegistryRollback
    {lineage : PublicationDomainRegistryTrustRootLineage}
    {authority : DurableRegistryCheckpointRecoveryAuthority lineage}
    {evidence : RegistryTrustRootRecoveryEvidence lineage}
    (accepted : authorityIssuedRegistryTrustRootRecovery authority evidence)
    {candidatePosition : Nat}
    (knownRollback :
      candidatePosition < authority.durableCommittedPosition) :
    candidatePosition ≠ evidence.recoveredPosition := by
  exact Nat.ne_of_lt
    (Nat.lt_of_lt_of_le knownRollback
      (authorityIssuedRecoveryNeverRestoresBeforeDurableCheckpoint accepted))

inductive DurableRegistryCheckpointRecoveryOutcome
    (lineage : PublicationDomainRegistryTrustRootLineage)
    (authority : DurableRegistryCheckpointRecoveryAuthority lineage) where
  | recovered
      (evidence : RegistryTrustRootRecoveryEvidence lineage)
      (issued : authority.issued evidence)
      (valid : validRegistryTrustRootRecovery evidence)
  | indeterminate

def registryCheckpointPositionAdmittedAfterRecovery
    {lineage : PublicationDomainRegistryTrustRootLineage}
    {authority : DurableRegistryCheckpointRecoveryAuthority lineage}
    (outcome : DurableRegistryCheckpointRecoveryOutcome lineage authority)
    (candidatePosition : Nat) : Prop :=
  match outcome with
  | .recovered evidence _ _ =>
      candidatePosition = evidence.recoveredPosition
  | .indeterminate => False

theorem indeterminateRegistryRecoveryCannotAdmitCheckpoint
    {lineage : PublicationDomainRegistryTrustRootLineage}
    {authority : DurableRegistryCheckpointRecoveryAuthority lineage}
    (candidatePosition : Nat) :
    ¬ registryCheckpointPositionAdmittedAfterRecovery
        (DurableRegistryCheckpointRecoveryOutcome.indeterminate
          (lineage := lineage) (authority := authority))
        candidatePosition := by
  simp [registryCheckpointPositionAdmittedAfterRecovery]

/--
A predecessor descriptor has a content disposition across a recovery interval
when it is still registered at the recovered position or an adjacent transition
inside the interval carries its authority-validated retirement.
-/
def DescriptorDispositionAcrossRegistryInterval
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage)
    (committedPosition recoveredPosition : Nat)
    (descriptor : PublicationDomainDescriptor) : Prop :=
  (governedLineage.lineage.published recoveredPosition).trustRoot.registry.registered
      descriptor ∨
    ∃ retirementPosition,
      committedPosition ≤ retirementPosition ∧
        retirementPosition < recoveredPosition ∧
          Nonempty
            (AuthorityIssuedDescriptorRetirementEvidence
              (governedLineage.lineage.published retirementPosition)
              (governedLineage.lineage.published (retirementPosition + 1))
              descriptor)

/--
The content-aware recovery evidence retains the existing position receipt and
adds a disposition for every descriptor registered at the committed position.
-/
structure ContentAwareRegistryTrustRootRecoveryEvidence
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage) where
  positionEvidence :
    RegistryTrustRootRecoveryEvidence governedLineage.lineage
  descriptorDisposition :
    ∀ descriptor,
      (governedLineage.lineage.published
          positionEvidence.committedPosition).trustRoot.registry.registered
        descriptor →
      DescriptorDispositionAcrossRegistryInterval
        governedLineage
        positionEvidence.committedPosition
        positionEvidence.recoveredPosition
        descriptor

/--
The weak recovery authority binds durable positions but carries no canonical
registry trust claim.  It is retained as the registry-metadata substitution
counterexample owner.
-/
structure RegistryClaimUnboundDurableContentAwareRecoveryAuthority
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage) where
  positionAuthority :
    DurableRegistryCheckpointRecoveryAuthority governedLineage.lineage
  issued : ContentAwareRegistryTrustRootRecoveryEvidence governedLineage → Prop
  issuanceBindsPositionEvidence :
    ∀ {evidence : ContentAwareRegistryTrustRootRecoveryEvidence governedLineage},
      issued evidence → positionAuthority.issued evidence.positionEvidence

/--
The safe recovery authority issues the entire content-aware receipt, proves that
its position projection is the existing durable recovery receipt, and binds its
registry-level identity to the canonical trust claim at the durable position.
-/
structure DurableContentAwareRegistryCheckpointRecoveryAuthority
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage) where
  positionAuthority :
    DurableRegistryCheckpointRecoveryAuthority governedLineage.lineage
  issued : ContentAwareRegistryTrustRootRecoveryEvidence governedLineage → Prop
  issuanceBindsPositionEvidence :
    ∀ {evidence : ContentAwareRegistryTrustRootRecoveryEvidence governedLineage},
      issued evidence → positionAuthority.issued evidence.positionEvidence
  validatedRegistryClaim : PublicationDomainRegistryTrustClaim
  claimMatchesDurableRoot :
    validatedRegistryClaim =
      publicationDomainRegistryTrustClaim
        (governedLineage.lineage.published
          positionAuthority.durableCommittedPosition).trustRoot

def authorityIssuedContentAwareRegistryTrustRootRecovery
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (authority :
      DurableContentAwareRegistryCheckpointRecoveryAuthority governedLineage)
    (evidence : ContentAwareRegistryTrustRootRecoveryEvidence governedLineage) :
    Prop :=
  authority.issued evidence ∧
    validRegistryTrustRootRecovery evidence.positionEvidence

theorem claimUnboundRecoveryAuthorityPermitsRegistryClaimSubstitution
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (positionAuthority :
      DurableRegistryCheckpointRecoveryAuthority governedLineage.lineage)
    (evidence : ContentAwareRegistryTrustRootRecoveryEvidence governedLineage)
    (positionIssued : positionAuthority.issued evidence.positionEvidence) :
    ∃ (authority :
        RegistryClaimUnboundDurableContentAwareRecoveryAuthority governedLineage)
      (claim : PublicationDomainRegistryTrustClaim),
      authority.issued evidence ∧
        claim.registryAuthorityIdentity ≠
          (governedLineage.lineage.published
            positionAuthority.durableCommittedPosition).trustRoot.registryAuthorityIdentity ∧
        claim.registrySemanticIdentity ≠
          (governedLineage.lineage.published
            positionAuthority.durableCommittedPosition).trustRoot.registrySemanticIdentity := by
  let authority :
      RegistryClaimUnboundDurableContentAwareRecoveryAuthority
        governedLineage := {
    positionAuthority := positionAuthority
    issued := fun candidate => candidate = evidence
    issuanceBindsPositionEvidence := by
      intro candidate candidateMatches
      subst candidate
      exact positionIssued
  }
  let durableRoot :=
    (governedLineage.lineage.published
      positionAuthority.durableCommittedPosition).trustRoot
  let claim : PublicationDomainRegistryTrustClaim := {
    registryAuthorityIdentity := durableRoot.registryAuthorityIdentity + 1
    registrySemanticIdentity := durableRoot.registrySemanticIdentity + 1
  }
  refine ⟨authority, claim, rfl, ?_, ?_⟩
  · simp [claim, durableRoot]
  · simp [claim, durableRoot]

theorem positionOnlyRecoveryPermitsSilentRegistryContentLoss :
    ∃ (lineage : PublicationDomainRegistryTrustRootLineage)
      (evidence : RegistryTrustRootRecoveryEvidence lineage)
      (descriptor : PublicationDomainDescriptor),
      validRegistryTrustRootRecovery evidence ∧
        (lineage.published evidence.committedPosition).trustRoot.registry.registered
          descriptor ∧
        ¬ (lineage.published evidence.recoveredPosition).trustRoot.registry.registered
          descriptor := by
  let predecessorDescriptor : PublicationDomainDescriptor := {
    domainIdentity := 367
    authorityIdentity := 373
    semanticIdentity := 379
  }
  let successorDescriptor : PublicationDomainDescriptor := {
    domainIdentity := 367
    authorityIdentity := 373
    semanticIdentity := 383
  }
  let lineage : PublicationDomainRegistryTrustRootLineage := {
    published := fun position => {
      generation := position
      trustRoot := {
        registryAuthorityIdentity := 389
        registrySemanticIdentity := 397
        registry :=
          if position = 0 then
            singletonPublicationDomainRegistry predecessorDescriptor
          else
            singletonPublicationDomainRegistry successorDescriptor
      }
    }
    authorityStable := by
      intro left right
      rfl
    semanticsStable := by
      intro left right
      rfl
    generationStrict := by
      intro earlier later ordered
      exact ordered
  }
  let evidence : RegistryTrustRootRecoveryEvidence lineage := {
    committedPosition := 0
    recoveredPosition := 1
  }
  refine ⟨lineage, evidence, predecessorDescriptor, ?_, ?_, ?_⟩
  · simp [validRegistryTrustRootRecovery, evidence]
  · simp [lineage, evidence, singletonPublicationDomainRegistry]
  · simp [lineage, evidence, singletonPublicationDomainRegistry,
      predecessorDescriptor, successorDescriptor]

theorem authorityIssuedContentAwareRecoveryBindsDurablePositions
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    {authority :
      DurableContentAwareRegistryCheckpointRecoveryAuthority governedLineage}
    {evidence : ContentAwareRegistryTrustRootRecoveryEvidence governedLineage}
    (issued :
      authorityIssuedContentAwareRegistryTrustRootRecovery authority evidence) :
    evidence.positionEvidence.committedPosition =
        authority.positionAuthority.durableCommittedPosition ∧
      evidence.positionEvidence.recoveredPosition =
        authority.positionAuthority.recoveredCheckpoint.currentPosition := by
  exact
    authority.positionAuthority.issuanceBindsDurableCheckpoint
      (authority.issuanceBindsPositionEvidence issued.1)

theorem contentAwareRecoveryCarriesDescriptorDisposition
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    {evidence : ContentAwareRegistryTrustRootRecoveryEvidence governedLineage}
    {descriptor : PublicationDomainDescriptor}
    (committedDescriptor :
      (governedLineage.lineage.published
          evidence.positionEvidence.committedPosition).trustRoot.registry.registered
        descriptor) :
    DescriptorDispositionAcrossRegistryInterval
      governedLineage
      evidence.positionEvidence.committedPosition
      evidence.positionEvidence.recoveredPosition
      descriptor := by
  exact evidence.descriptorDisposition descriptor committedDescriptor

theorem governedLineageComposesDescriptorDispositionAcrossInterval
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage)
    {committedPosition recoveredPosition : Nat}
    (ordered : committedPosition ≤ recoveredPosition)
    {descriptor : PublicationDomainDescriptor}
    (committedDescriptor :
      (governedLineage.lineage.published
          committedPosition).trustRoot.registry.registered descriptor) :
    DescriptorDispositionAcrossRegistryInterval
      governedLineage committedPosition recoveredPosition descriptor := by
  induction ordered with
  | refl =>
      exact Or.inl committedDescriptor
  | @step recoveredPosition ordered inductionHypothesis =>
      rcases inductionHypothesis with preserved | retired
      · rcases
          (governedLineage.adjacentContentTransition recoveredPosition).descriptorDisposition
            descriptor preserved with
        nextPreserved | retiredAtSuccessor
        · exact Or.inl nextPreserved
        · exact
            Or.inr
              ⟨recoveredPosition, ordered, Nat.lt_succ_self recoveredPosition,
                retiredAtSuccessor⟩
      · rcases retired with
          ⟨retirementPosition, afterCommitted, beforeRecovered, retirement⟩
        exact
          Or.inr
            ⟨retirementPosition, afterCommitted,
              Nat.lt_trans beforeRecovered
                (Nat.lt_succ_self recoveredPosition),
              retirement⟩

def contentAwareRecoveryEvidenceOfGovernedLineage
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage)
    (positionEvidence :
      RegistryTrustRootRecoveryEvidence governedLineage.lineage)
    (validPositionRecovery :
      validRegistryTrustRootRecovery positionEvidence) :
    ContentAwareRegistryTrustRootRecoveryEvidence governedLineage := {
  positionEvidence := positionEvidence
  descriptorDisposition := by
    intro descriptor committedDescriptor
    exact
      governedLineageComposesDescriptorDispositionAcrossInterval
        governedLineage validPositionRecovery committedDescriptor
}

theorem extendDescriptorDispositionAcrossRegistryInterval
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage)
    {originPosition middlePosition targetPosition : Nat}
    (originBeforeMiddle : originPosition ≤ middlePosition)
    (middleBeforeTarget : middlePosition ≤ targetPosition)
    {descriptor : PublicationDomainDescriptor}
    (disposition :
      DescriptorDispositionAcrossRegistryInterval
        governedLineage originPosition middlePosition descriptor) :
    DescriptorDispositionAcrossRegistryInterval
      governedLineage originPosition targetPosition descriptor := by
  rcases disposition with registeredAtMiddle | retiredBeforeMiddle
  · rcases
      governedLineageComposesDescriptorDispositionAcrossInterval
        governedLineage middleBeforeTarget registeredAtMiddle with
      registeredAtTarget | retiredAfterMiddle
    · exact Or.inl registeredAtTarget
    · rcases retiredAfterMiddle with
        ⟨retirementPosition, afterMiddle, beforeTarget, retirement⟩
      exact
        Or.inr
          ⟨retirementPosition,
            Nat.le_trans originBeforeMiddle afterMiddle,
            beforeTarget,
            retirement⟩
  · rcases retiredBeforeMiddle with
      ⟨retirementPosition, afterOrigin, beforeMiddle, retirement⟩
    exact
      Or.inr
        ⟨retirementPosition,
          afterOrigin,
          Nat.lt_of_lt_of_le beforeMiddle middleBeforeTarget,
          retirement⟩

theorem durableContentAwareRecoveryAuthorityBindsRegistryAuthority
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (authority :
      DurableContentAwareRegistryCheckpointRecoveryAuthority governedLineage) :
    authority.validatedRegistryClaim.registryAuthorityIdentity =
      (governedLineage.lineage.published
        authority.positionAuthority.durableCommittedPosition).trustRoot.registryAuthorityIdentity := by
  have claimEquality :=
    congrArg
      (fun claim : PublicationDomainRegistryTrustClaim =>
        claim.registryAuthorityIdentity)
      authority.claimMatchesDurableRoot
  simpa [publicationDomainRegistryTrustClaim] using claimEquality

theorem durableContentAwareRecoveryAuthorityBindsRegistrySemantics
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (authority :
      DurableContentAwareRegistryCheckpointRecoveryAuthority governedLineage) :
    authority.validatedRegistryClaim.registrySemanticIdentity =
      (governedLineage.lineage.published
        authority.positionAuthority.durableCommittedPosition).trustRoot.registrySemanticIdentity := by
  have claimEquality :=
    congrArg
      (fun claim : PublicationDomainRegistryTrustClaim =>
        claim.registrySemanticIdentity)
      authority.claimMatchesDurableRoot
  simpa [publicationDomainRegistryTrustClaim] using claimEquality

theorem durableContentAwareRecoveryAuthorityBindsRecoveredRegistryAuthority
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (authority :
      DurableContentAwareRegistryCheckpointRecoveryAuthority governedLineage) :
    authority.validatedRegistryClaim.registryAuthorityIdentity =
      (governedLineage.lineage.published
        authority.positionAuthority.recoveredCheckpoint.currentPosition).trustRoot.registryAuthorityIdentity := by
  calc
    authority.validatedRegistryClaim.registryAuthorityIdentity =
        (governedLineage.lineage.published
          authority.positionAuthority.durableCommittedPosition).trustRoot.registryAuthorityIdentity :=
      durableContentAwareRecoveryAuthorityBindsRegistryAuthority authority
    _ =
        (governedLineage.lineage.published
          authority.positionAuthority.recoveredCheckpoint.currentPosition).trustRoot.registryAuthorityIdentity :=
      governedLineage.lineage.authorityStable _ _

theorem durableContentAwareRecoveryAuthorityBindsRecoveredRegistrySemantics
    {governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage}
    (authority :
      DurableContentAwareRegistryCheckpointRecoveryAuthority governedLineage) :
    authority.validatedRegistryClaim.registrySemanticIdentity =
      (governedLineage.lineage.published
        authority.positionAuthority.recoveredCheckpoint.currentPosition).trustRoot.registrySemanticIdentity := by
  calc
    authority.validatedRegistryClaim.registrySemanticIdentity =
        (governedLineage.lineage.published
          authority.positionAuthority.durableCommittedPosition).trustRoot.registrySemanticIdentity :=
      durableContentAwareRecoveryAuthorityBindsRegistrySemantics authority
    _ =
        (governedLineage.lineage.published
          authority.positionAuthority.recoveredCheckpoint.currentPosition).trustRoot.registrySemanticIdentity :=
      governedLineage.lineage.semanticsStable _ _

theorem positionOnlyRecoveryPermitsUnattributedRecoveredDescriptor :
    ∃ (lineage : PublicationDomainRegistryTrustRootLineage)
      (evidence : RegistryTrustRootRecoveryEvidence lineage)
      (descriptor : PublicationDomainDescriptor),
      validRegistryTrustRootRecovery evidence ∧
        ¬ (lineage.published
            evidence.committedPosition).trustRoot.registry.registered descriptor ∧
        (lineage.published
            evidence.recoveredPosition).trustRoot.registry.registered descriptor := by
  let descriptor : PublicationDomainDescriptor := {
    domainIdentity := 457
    authorityIdentity := 461
    semanticIdentity := 463
  }
  let emptyRegistry : PublicationDomainIdentityRegistry := {
    registered := fun _ => False
    identityInjective := by
      intro left right leftRegistered
      contradiction
  }
  let lineage : PublicationDomainRegistryTrustRootLineage := {
    published := fun position => {
      generation := position
      trustRoot := {
        registryAuthorityIdentity := 467
        registrySemanticIdentity := 479
        registry :=
          if position = 0 then
            emptyRegistry
          else
            singletonPublicationDomainRegistry descriptor
      }
    }
    authorityStable := by
      intro left right
      rfl
    semanticsStable := by
      intro left right
      rfl
    generationStrict := by
      intro earlier later earlierBeforeLater
      exact earlierBeforeLater
  }
  let evidence : RegistryTrustRootRecoveryEvidence lineage := {
    committedPosition := 0
    recoveredPosition := 1
  }
  refine ⟨lineage, evidence, descriptor, ?_, ?_, ?_⟩
  · simp [validRegistryTrustRootRecovery, evidence]
  · simp [lineage, evidence, emptyRegistry]
  · simp [lineage, evidence, singletonPublicationDomainRegistry]

def DescriptorAdmissionAcrossRegistryInterval
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage)
    (committedPosition recoveredPosition : Nat)
    (descriptor : PublicationDomainDescriptor) : Prop :=
  ∃ admissionPosition,
    committedPosition ≤ admissionPosition ∧
      admissionPosition < recoveredPosition ∧
        Nonempty
          (AuthorityIssuedDescriptorAdmissionEvidence
            (governedLineage.lineage.published admissionPosition)
            (governedLineage.lineage.published (admissionPosition + 1))
            descriptor)

theorem governedLineageRequiresIssuedAdmissionForRecoveredOnlyDescriptor
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage)
    {committedPosition recoveredPosition : Nat}
    (ordered : committedPosition ≤ recoveredPosition)
    {descriptor : PublicationDomainDescriptor}
    (notRegisteredAtCommit :
      ¬ (governedLineage.lineage.published
          committedPosition).trustRoot.registry.registered descriptor)
    (registeredAtRecovery :
      (governedLineage.lineage.published
          recoveredPosition).trustRoot.registry.registered descriptor) :
    DescriptorAdmissionAcrossRegistryInterval
      governedLineage committedPosition recoveredPosition descriptor := by
  induction ordered with
  | refl =>
      exact False.elim (notRegisteredAtCommit registeredAtRecovery)
  | @step recoveredPosition ordered inductionHypothesis =>
      rcases
          (governedLineage.adjacentContentTransition
            recoveredPosition).successorDisposition
            descriptor registeredAtRecovery with
        registeredBeforeRecovery | admittedAtRecovery
      · rcases inductionHypothesis registeredBeforeRecovery with
          ⟨admissionPosition, afterCommitted, beforeRecovery, admission⟩
        exact
          ⟨admissionPosition, afterCommitted,
            Nat.lt_trans beforeRecovery
              (Nat.lt_succ_self recoveredPosition),
            admission⟩
      · exact
          ⟨recoveredPosition, ordered, Nat.lt_succ_self recoveredPosition,
            admittedAtRecovery⟩

def DescriptorRetirementAcrossRegistryInterval
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage)
    (committedPosition recoveredPosition : Nat)
    (descriptor : PublicationDomainDescriptor) : Prop :=
  ∃ retirementPosition,
    committedPosition ≤ retirementPosition ∧
      retirementPosition < recoveredPosition ∧
        Nonempty
          (AuthorityIssuedDescriptorRetirementEvidence
            (governedLineage.lineage.published retirementPosition)
            (governedLineage.lineage.published (retirementPosition + 1))
            descriptor)

def AuthorityIssuedDomainRotationAcrossRegistryInterval
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage)
    (committedPosition recoveredPosition : Nat)
    (oldDescriptor newDescriptor : PublicationDomainDescriptor) : Prop :=
  oldDescriptor.domainIdentity = newDescriptor.domainIdentity ∧
    oldDescriptor ≠ newDescriptor ∧
      DescriptorRetirementAcrossRegistryInterval
        governedLineage committedPosition recoveredPosition oldDescriptor ∧
      DescriptorAdmissionAcrossRegistryInterval
        governedLineage committedPosition recoveredPosition newDescriptor

theorem governedLineageRequiresIssuedRotationAcrossRegistryInterval
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage)
    {committedPosition recoveredPosition : Nat}
    (ordered : committedPosition ≤ recoveredPosition)
    {oldDescriptor newDescriptor : PublicationDomainDescriptor}
    (oldRegisteredAtCommit :
      (governedLineage.lineage.published
          committedPosition).trustRoot.registry.registered oldDescriptor)
    (newRegisteredAtRecovery :
      (governedLineage.lineage.published
          recoveredPosition).trustRoot.registry.registered newDescriptor)
    (sameDomainIdentity :
      oldDescriptor.domainIdentity = newDescriptor.domainIdentity)
    (differentDescriptor : oldDescriptor ≠ newDescriptor) :
    AuthorityIssuedDomainRotationAcrossRegistryInterval
      governedLineage committedPosition recoveredPosition
      oldDescriptor newDescriptor := by
  have oldNotRegisteredAtRecovery :
      ¬ (governedLineage.lineage.published
          recoveredPosition).trustRoot.registry.registered oldDescriptor := by
    intro oldRegisteredAtRecovery
    have sameDescriptor :=
      (governedLineage.lineage.published
        recoveredPosition).trustRoot.registry.identityInjective
          oldRegisteredAtRecovery newRegisteredAtRecovery sameDomainIdentity
    exact differentDescriptor sameDescriptor
  have newNotRegisteredAtCommit :
      ¬ (governedLineage.lineage.published
          committedPosition).trustRoot.registry.registered newDescriptor := by
    intro newRegisteredAtCommit
    have sameDescriptor :=
      (governedLineage.lineage.published
        committedPosition).trustRoot.registry.identityInjective
          oldRegisteredAtCommit newRegisteredAtCommit sameDomainIdentity
    exact differentDescriptor sameDescriptor
  have oldDisposition :=
    governedLineageComposesDescriptorDispositionAcrossInterval
      governedLineage ordered oldRegisteredAtCommit
  have oldRetirement :
      DescriptorRetirementAcrossRegistryInterval
        governedLineage committedPosition recoveredPosition oldDescriptor := by
    rcases oldDisposition with oldRegisteredAtRecovery | retiredAcrossInterval
    · exact False.elim (oldNotRegisteredAtRecovery oldRegisteredAtRecovery)
    · exact retiredAcrossInterval
  have newAdmission :
      DescriptorAdmissionAcrossRegistryInterval
        governedLineage committedPosition recoveredPosition newDescriptor :=
    governedLineageRequiresIssuedAdmissionForRecoveredOnlyDescriptor
      governedLineage ordered newNotRegisteredAtCommit newRegisteredAtRecovery
  exact
    ⟨sameDomainIdentity, differentDescriptor, oldRetirement, newAdmission⟩

end AgenticAILabProof.Enterprise.PublicationDomainRegistryRecoveryClosure
