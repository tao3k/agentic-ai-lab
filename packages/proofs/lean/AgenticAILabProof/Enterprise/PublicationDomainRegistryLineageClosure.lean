-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.PublicationDomainRegistryTrustClosure

namespace AgenticAILabProof.Enterprise.PublicationDomainRegistryLineageClosure

open AgenticAILabProof.Enterprise.CheckpointWatermarkRecoveryClosure
open AgenticAILabProof.Enterprise.PublicationDomainRegistryTrustClosure

structure VersionedPublicationDomainRegistryTrustRoot where
  generation : Nat
  trustRoot : PublicationDomainRegistryTrustRoot

def validRegistryTrustRootTransition
    (previous next : VersionedPublicationDomainRegistryTrustRoot) : Prop :=
  previous.trustRoot.registryAuthorityIdentity =
      next.trustRoot.registryAuthorityIdentity ∧
    previous.trustRoot.registrySemanticIdentity =
      next.trustRoot.registrySemanticIdentity ∧
    previous.generation < next.generation

def exactRegistryTrustRootAcceptance
    (current candidate : VersionedPublicationDomainRegistryTrustRoot) : Prop :=
  candidate = current

theorem exactTrustRootSelectionAlonePermitsRollback :
    ∃ (initial upgraded : VersionedPublicationDomainRegistryTrustRoot),
      validRegistryTrustRootTransition initial upgraded ∧
        exactRegistryTrustRootAcceptance initial initial ∧
        exactRegistryTrustRootAcceptance upgraded upgraded ∧
        exactRegistryTrustRootAcceptance initial initial := by
  let initialDescriptor : PublicationDomainDescriptor := {
    domainIdentity := 307
    authorityIdentity := 311
    semanticIdentity := 313
  }
  let upgradedDescriptor : PublicationDomainDescriptor := {
    domainIdentity := 307
    authorityIdentity := 311
    semanticIdentity := 317
  }
  let initial : VersionedPublicationDomainRegistryTrustRoot := {
    generation := 0
    trustRoot := {
      registryAuthorityIdentity := 331
      registrySemanticIdentity := 337
      registry := singletonPublicationDomainRegistry initialDescriptor
    }
  }
  let upgraded : VersionedPublicationDomainRegistryTrustRoot := {
    generation := 1
    trustRoot := {
      registryAuthorityIdentity := 331
      registrySemanticIdentity := 337
      registry := singletonPublicationDomainRegistry upgradedDescriptor
    }
  }
  exact ⟨initial, upgraded, ⟨rfl, rfl, by decide⟩, rfl, rfl, rfl⟩

theorem validRegistryTrustRootTransitionRejectsPriorGeneration
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    (transition : validRegistryTrustRootTransition previous next) :
    ¬ exactRegistryTrustRootAcceptance next previous := by
  intro sameRoot
  have sameGeneration :
      previous.generation = next.generation :=
    congrArg VersionedPublicationDomainRegistryTrustRoot.generation sameRoot
  exact (Nat.ne_of_lt transition.2.2) sameGeneration

structure PublicationDomainRegistryTrustRootLineage where
  published : Nat → VersionedPublicationDomainRegistryTrustRoot
  authorityStable :
    ∀ left right,
      (published left).trustRoot.registryAuthorityIdentity =
        (published right).trustRoot.registryAuthorityIdentity
  semanticsStable :
    ∀ left right,
      (published left).trustRoot.registrySemanticIdentity =
        (published right).trustRoot.registrySemanticIdentity
  generationStrict :
    ∀ {earlier later}, earlier < later →
      (published earlier).generation < (published later).generation

def registryTrustRootAcceptedAt
    (lineage : PublicationDomainRegistryTrustRootLineage)
    (position : Nat)
    (candidate : VersionedPublicationDomainRegistryTrustRoot) : Prop :=
  candidate = lineage.published position

theorem registryTrustRootLineageRejectsEarlierPosition
    (lineage : PublicationDomainRegistryTrustRootLineage)
    {earlier later : Nat}
    (ordered : earlier < later) :
    ¬ registryTrustRootAcceptedAt
        lineage later (lineage.published earlier) := by
  intro sameRoot
  have sameGeneration :
      (lineage.published earlier).generation =
        (lineage.published later).generation :=
    congrArg VersionedPublicationDomainRegistryTrustRoot.generation sameRoot
  exact (Nat.ne_of_lt (lineage.generationStrict ordered)) sameGeneration

structure PublicationDomainRegistryTrustRootCheckpoint
    (lineage : PublicationDomainRegistryTrustRootLineage) where
  currentPosition : Nat

def registryTrustRootAcceptedAtCheckpoint
    {lineage : PublicationDomainRegistryTrustRootLineage}
    (checkpoint : PublicationDomainRegistryTrustRootCheckpoint lineage)
    (candidate : VersionedPublicationDomainRegistryTrustRoot) : Prop :=
  registryTrustRootAcceptedAt lineage checkpoint.currentPosition candidate

def validRegistryTrustRootCheckpointAdvance
    {lineage : PublicationDomainRegistryTrustRootLineage}
    (previous next : PublicationDomainRegistryTrustRootCheckpoint lineage) :
    Prop :=
  previous.currentPosition < next.currentPosition

theorem registryTrustRootCheckpointAdvanceRejectsPriorHead
    {lineage : PublicationDomainRegistryTrustRootLineage}
    {previous next : PublicationDomainRegistryTrustRootCheckpoint lineage}
    (advance : validRegistryTrustRootCheckpointAdvance previous next) :
    ¬ registryTrustRootAcceptedAtCheckpoint
        next (lineage.published previous.currentPosition) :=
  registryTrustRootLineageRejectsEarlierPosition lineage advance

/--
An explicit retirement of a predecessor descriptor is validated against the
canonical registry trust claim and the exact successor generation.  This is a
pure proof contract; the executable signature and commitment witness remain the
responsibility of the registry acceptance authority.
-/
structure AuthorityValidatedDescriptorRetirementEvidence
    (previous next : VersionedPublicationDomainRegistryTrustRoot)
    (descriptor : PublicationDomainDescriptor) where
  predecessorRegistered :
    previous.trustRoot.registry.registered descriptor
  validatedRegistryClaim : PublicationDomainRegistryTrustClaim
  claimMatchesPreviousRoot :
    validatedRegistryClaim =
      publicationDomainRegistryTrustClaim previous.trustRoot
  retirementGeneration : Nat
  generationMatchesSuccessor : retirementGeneration = next.generation

/--
The retirement authority is identified by the canonical predecessor registry
claim and decides issuance for the exact descriptor/evidence pair.
-/
structure DescriptorRetirementAuthority
    (previous next : VersionedPublicationDomainRegistryTrustRoot) where
  validatedRegistryClaim : PublicationDomainRegistryTrustClaim
  claimMatchesPreviousRoot :
    validatedRegistryClaim =
      publicationDomainRegistryTrustClaim previous.trustRoot
  issued :
    (descriptor : PublicationDomainDescriptor) →
      AuthorityValidatedDescriptorRetirementEvidence
        previous next descriptor → Prop
  issuanceBindsEvidenceClaim :
    ∀ {descriptor evidence},
      issued descriptor evidence →
        evidence.validatedRegistryClaim = validatedRegistryClaim

/--
The safe retirement receipt carries the claim-bound evidence, exact retirement
authority, and proof that the authority issued this descriptor/evidence pair.
-/
structure AuthorityIssuedDescriptorRetirementEvidence
    (previous next : VersionedPublicationDomainRegistryTrustRoot)
    (descriptor : PublicationDomainDescriptor) where
  validatedEvidence :
    AuthorityValidatedDescriptorRetirementEvidence previous next descriptor
  retirementAuthority : DescriptorRetirementAuthority previous next
  authorityIssued :
    retirementAuthority.issued descriptor validatedEvidence

/--
The claim-bound successor admission owns the exact new descriptor, successor
registry claim and generation.  Reusing a predecessor domain identity also
requires issued retirement evidence for every predecessor descriptor carrying
that identity.
-/
structure AuthorityValidatedDescriptorAdmissionEvidence
    (previous next : VersionedPublicationDomainRegistryTrustRoot)
    (descriptor : PublicationDomainDescriptor) where
  successorRegistered : next.trustRoot.registry.registered descriptor
  validatedRegistryClaim : PublicationDomainRegistryTrustClaim
  claimMatchesSuccessorRoot :
    validatedRegistryClaim =
      publicationDomainRegistryTrustClaim next.trustRoot
  admissionGeneration : Nat
  generationMatchesSuccessor : admissionGeneration = next.generation
  predecessorSameDomainRetired :
    ∀ predecessorDescriptor,
      previous.trustRoot.registry.registered predecessorDescriptor →
        predecessorDescriptor.domainIdentity = descriptor.domainIdentity →
          Nonempty
            (AuthorityIssuedDescriptorRetirementEvidence
              previous next predecessorDescriptor)

structure DescriptorAdmissionAuthority
    (previous next : VersionedPublicationDomainRegistryTrustRoot) where
  validatedRegistryClaim : PublicationDomainRegistryTrustClaim
  claimMatchesSuccessorRoot :
    validatedRegistryClaim =
      publicationDomainRegistryTrustClaim next.trustRoot
  issued :
    (descriptor : PublicationDomainDescriptor) →
      AuthorityValidatedDescriptorAdmissionEvidence
        previous next descriptor → Prop
  issuanceBindsEvidenceClaim :
    ∀ {descriptor evidence},
      issued descriptor evidence →
        evidence.validatedRegistryClaim = validatedRegistryClaim

structure AuthorityIssuedDescriptorAdmissionEvidence
    (previous next : VersionedPublicationDomainRegistryTrustRoot)
    (descriptor : PublicationDomainDescriptor) where
  validatedEvidence :
    AuthorityValidatedDescriptorAdmissionEvidence previous next descriptor
  admissionAuthority : DescriptorAdmissionAuthority previous next
  authorityIssued :
    admissionAuthority.issued descriptor validatedEvidence

/--
The predecessor-only model is retained as the successor-injection counterexample
owner.  It governs retirement but places no obligation on successor additions.
-/
structure RetirementOnlyContentGovernedRegistryTrustRootTransition
    (previous next : VersionedPublicationDomainRegistryTrustRoot) where
  identityTransition : validRegistryTrustRootTransition previous next
  descriptorDisposition :
    ∀ descriptor,
      previous.trustRoot.registry.registered descriptor →
        next.trustRoot.registry.registered descriptor ∨
          Nonempty
            (AuthorityIssuedDescriptorRetirementEvidence
              previous next descriptor)

/--
A governed registry transition may preserve a predecessor descriptor or retire
it explicitly.  It never interprets generation monotonicity alone as proof of
registry-content preservation.
-/
structure ContentGovernedRegistryTrustRootTransition
    (previous next : VersionedPublicationDomainRegistryTrustRoot) where
  identityTransition : validRegistryTrustRootTransition previous next
  descriptorDisposition :
    ∀ descriptor,
      previous.trustRoot.registry.registered descriptor →
        next.trustRoot.registry.registered descriptor ∨
          Nonempty
            (AuthorityIssuedDescriptorRetirementEvidence
              previous next descriptor)
  successorDisposition :
    ∀ descriptor,
      next.trustRoot.registry.registered descriptor →
        previous.trustRoot.registry.registered descriptor ∨
          Nonempty
            (AuthorityIssuedDescriptorAdmissionEvidence
              previous next descriptor)

/--
The safe lineage surface requires the content-governed transition at every
adjacent published position.  The embedded lineage continues to own authority,
semantic, and generation monotonicity; this wrapper adds the missing registry
content disposition evidence.
-/
structure ContentGovernedPublicationDomainRegistryTrustRootLineage where
  lineage : PublicationDomainRegistryTrustRootLineage
  adjacentContentTransition :
    ∀ position,
      ContentGovernedRegistryTrustRootTransition
        (lineage.published position)
        (lineage.published (position + 1))

theorem validRegistryTrustRootTransitionPermitsSilentDescriptorDeletion :
    ∃ (previous next : VersionedPublicationDomainRegistryTrustRoot)
      (descriptor : PublicationDomainDescriptor),
      validRegistryTrustRootTransition previous next ∧
        previous.trustRoot.registry.registered descriptor ∧
          ¬ next.trustRoot.registry.registered descriptor := by
  let predecessorDescriptor : PublicationDomainDescriptor := {
    domainIdentity := 331
    authorityIdentity := 337
    semanticIdentity := 347
  }
  let successorDescriptor : PublicationDomainDescriptor := {
    domainIdentity := 331
    authorityIdentity := 337
    semanticIdentity := 349
  }
  let previous : VersionedPublicationDomainRegistryTrustRoot := {
    generation := 0
    trustRoot := {
      registryAuthorityIdentity := 353
      registrySemanticIdentity := 359
      registry := singletonPublicationDomainRegistry predecessorDescriptor
    }
  }
  let next : VersionedPublicationDomainRegistryTrustRoot := {
    generation := 1
    trustRoot := {
      registryAuthorityIdentity := 353
      registrySemanticIdentity := 359
      registry := singletonPublicationDomainRegistry successorDescriptor
    }
  }
  refine ⟨previous, next, predecessorDescriptor, ?_, ?_, ?_⟩
  · simp [validRegistryTrustRootTransition, previous, next]
  · simp [previous, singletonPublicationDomainRegistry]
  · simp [next, singletonPublicationDomainRegistry, predecessorDescriptor,
      successorDescriptor]

theorem descriptorRetirementBindsRegistryAuthority
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    {descriptor : PublicationDomainDescriptor}
    (evidence :
      AuthorityValidatedDescriptorRetirementEvidence
        previous next descriptor) :
    evidence.validatedRegistryClaim.registryAuthorityIdentity =
      previous.trustRoot.registryAuthorityIdentity := by
  have claimEquality :=
    congrArg
      (fun claim : PublicationDomainRegistryTrustClaim =>
        claim.registryAuthorityIdentity)
      evidence.claimMatchesPreviousRoot
  simpa [publicationDomainRegistryTrustClaim] using claimEquality

theorem descriptorRetirementBindsRegistrySemantics
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    {descriptor : PublicationDomainDescriptor}
    (evidence :
      AuthorityValidatedDescriptorRetirementEvidence
        previous next descriptor) :
    evidence.validatedRegistryClaim.registrySemanticIdentity =
      previous.trustRoot.registrySemanticIdentity := by
  have claimEquality :=
    congrArg
      (fun claim : PublicationDomainRegistryTrustClaim =>
        claim.registrySemanticIdentity)
      evidence.claimMatchesPreviousRoot
  simpa [publicationDomainRegistryTrustClaim] using claimEquality

theorem descriptorRetirementBindsSuccessorGeneration
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    {descriptor : PublicationDomainDescriptor}
    (evidence :
      AuthorityValidatedDescriptorRetirementEvidence
        previous next descriptor) :
    evidence.retirementGeneration = next.generation :=
  evidence.generationMatchesSuccessor

theorem contentGovernedTransitionRequiresPreservationOrIssuedRetirement
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    (transition : ContentGovernedRegistryTrustRootTransition previous next)
    {descriptor : PublicationDomainDescriptor}
    (predecessorRegistered :
      previous.trustRoot.registry.registered descriptor) :
    next.trustRoot.registry.registered descriptor ∨
      Nonempty
        (AuthorityIssuedDescriptorRetirementEvidence
          previous next descriptor) :=
  transition.descriptorDisposition descriptor predecessorRegistered

theorem silentDescriptorDeletionCannotCloseContentGovernedTransition
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    (transition : ContentGovernedRegistryTrustRootTransition previous next)
    {descriptor : PublicationDomainDescriptor}
    (predecessorRegistered :
      previous.trustRoot.registry.registered descriptor)
    (successorDoesNotRegister :
      ¬ next.trustRoot.registry.registered descriptor) :
    Nonempty
      (AuthorityIssuedDescriptorRetirementEvidence
        previous next descriptor) := by
  rcases
      transition.descriptorDisposition descriptor predecessorRegistered with
    preserved | retired
  · exact False.elim (successorDoesNotRegister preserved)
  · exact retired

theorem governedRegistryLineageRequiresPreservationOrIssuedRetirement
    (governedLineage :
      ContentGovernedPublicationDomainRegistryTrustRootLineage)
    (position : Nat)
    {descriptor : PublicationDomainDescriptor}
    (predecessorRegistered :
      (governedLineage.lineage.published position).trustRoot.registry.registered
        descriptor) :
    (governedLineage.lineage.published (position + 1)).trustRoot.registry.registered
        descriptor ∨
      Nonempty
        (AuthorityIssuedDescriptorRetirementEvidence
          (governedLineage.lineage.published position)
          (governedLineage.lineage.published (position + 1))
          descriptor) :=
  by
    exact
      contentGovernedTransitionRequiresPreservationOrIssuedRetirement
        (governedLineage.adjacentContentTransition position)
        predecessorRegistered

theorem claimValidDescriptorRetirementPermitsUnissuedRetirement
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    {descriptor : PublicationDomainDescriptor}
    (predecessorRegistered :
      previous.trustRoot.registry.registered descriptor) :
    ∃ (evidence :
        AuthorityValidatedDescriptorRetirementEvidence
          previous next descriptor)
      (authority : DescriptorRetirementAuthority previous next),
      ¬ authority.issued descriptor evidence := by
  let evidence :
      AuthorityValidatedDescriptorRetirementEvidence
        previous next descriptor := {
    predecessorRegistered := predecessorRegistered
    validatedRegistryClaim :=
      publicationDomainRegistryTrustClaim previous.trustRoot
    claimMatchesPreviousRoot := rfl
    retirementGeneration := next.generation
    generationMatchesSuccessor := rfl
  }
  let authority : DescriptorRetirementAuthority previous next := {
    validatedRegistryClaim :=
      publicationDomainRegistryTrustClaim previous.trustRoot
    claimMatchesPreviousRoot := rfl
    issued := fun _ _ => False
    issuanceBindsEvidenceClaim := by
      intro candidate candidateEvidence issued
      contradiction
  }
  refine ⟨evidence, authority, ?_⟩
  simp [authority]

theorem descriptorRetirementAuthorityBindsRegistryAuthority
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    (authority : DescriptorRetirementAuthority previous next) :
    authority.validatedRegistryClaim.registryAuthorityIdentity =
      previous.trustRoot.registryAuthorityIdentity := by
  have claimEquality :=
    congrArg
      (fun claim : PublicationDomainRegistryTrustClaim =>
        claim.registryAuthorityIdentity)
      authority.claimMatchesPreviousRoot
  simpa [publicationDomainRegistryTrustClaim] using claimEquality

theorem descriptorRetirementAuthorityBindsRegistrySemantics
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    (authority : DescriptorRetirementAuthority previous next) :
    authority.validatedRegistryClaim.registrySemanticIdentity =
      previous.trustRoot.registrySemanticIdentity := by
  have claimEquality :=
    congrArg
      (fun claim : PublicationDomainRegistryTrustClaim =>
        claim.registrySemanticIdentity)
      authority.claimMatchesPreviousRoot
  simpa [publicationDomainRegistryTrustClaim] using claimEquality

theorem authorityIssuedDescriptorRetirementCarriesIssuance
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    {descriptor : PublicationDomainDescriptor}
    (evidence :
      AuthorityIssuedDescriptorRetirementEvidence
        previous next descriptor) :
    evidence.retirementAuthority.issued
      descriptor evidence.validatedEvidence :=
  evidence.authorityIssued

theorem authorityIssuedDescriptorRetirementUsesExactAuthorityClaim
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    {descriptor : PublicationDomainDescriptor}
    (evidence :
      AuthorityIssuedDescriptorRetirementEvidence
        previous next descriptor) :
    evidence.validatedEvidence.validatedRegistryClaim =
      evidence.retirementAuthority.validatedRegistryClaim :=
  evidence.retirementAuthority.issuanceBindsEvidenceClaim
    evidence.authorityIssued

theorem authorityIssuedDescriptorRetirementBindsSuccessorGeneration
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    {descriptor : PublicationDomainDescriptor}
    (evidence :
      AuthorityIssuedDescriptorRetirementEvidence
        previous next descriptor) :
    evidence.validatedEvidence.retirementGeneration = next.generation :=
  evidence.validatedEvidence.generationMatchesSuccessor

theorem retirementOnlyTransitionPermitsUnissuedSuccessorInjection :
    ∃ (previous next : VersionedPublicationDomainRegistryTrustRoot)
      (descriptor : PublicationDomainDescriptor)
      (_transition :
        RetirementOnlyContentGovernedRegistryTrustRootTransition previous next),
      next.trustRoot.registry.registered descriptor ∧
        ¬ previous.trustRoot.registry.registered descriptor := by
  let descriptor : PublicationDomainDescriptor := {
    domainIdentity := 431
    authorityIdentity := 433
    semanticIdentity := 439
  }
  let emptyRegistry : PublicationDomainIdentityRegistry := {
    registered := fun _ => False
    identityInjective := by
      intro left right leftRegistered
      contradiction
  }
  let previous : VersionedPublicationDomainRegistryTrustRoot := {
    generation := 0
    trustRoot := {
      registryAuthorityIdentity := 443
      registrySemanticIdentity := 449
      registry := emptyRegistry
    }
  }
  let next : VersionedPublicationDomainRegistryTrustRoot := {
    generation := 1
    trustRoot := {
      registryAuthorityIdentity := 443
      registrySemanticIdentity := 449
      registry := singletonPublicationDomainRegistry descriptor
    }
  }
  let transition :
      RetirementOnlyContentGovernedRegistryTrustRootTransition previous next := {
    identityTransition := by
      simp [validRegistryTrustRootTransition, previous, next]
    descriptorDisposition := by
      intro candidate predecessorRegistered
      simp [previous, emptyRegistry] at predecessorRegistered
  }
  refine ⟨previous, next, descriptor, transition, ?_, ?_⟩
  · simp [next, singletonPublicationDomainRegistry]
  · simp [previous, emptyRegistry]

theorem descriptorAdmissionAuthorityBindsRegistryAuthority
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    (authority : DescriptorAdmissionAuthority previous next) :
    authority.validatedRegistryClaim.registryAuthorityIdentity =
      next.trustRoot.registryAuthorityIdentity := by
  have claimEquality :=
    congrArg
      (fun claim : PublicationDomainRegistryTrustClaim =>
        claim.registryAuthorityIdentity)
      authority.claimMatchesSuccessorRoot
  simpa [publicationDomainRegistryTrustClaim] using claimEquality

theorem descriptorAdmissionAuthorityBindsRegistrySemantics
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    (authority : DescriptorAdmissionAuthority previous next) :
    authority.validatedRegistryClaim.registrySemanticIdentity =
      next.trustRoot.registrySemanticIdentity := by
  have claimEquality :=
    congrArg
      (fun claim : PublicationDomainRegistryTrustClaim =>
        claim.registrySemanticIdentity)
      authority.claimMatchesSuccessorRoot
  simpa [publicationDomainRegistryTrustClaim] using claimEquality

theorem authorityIssuedDescriptorAdmissionCarriesIssuance
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    {descriptor : PublicationDomainDescriptor}
    (evidence :
      AuthorityIssuedDescriptorAdmissionEvidence previous next descriptor) :
    evidence.admissionAuthority.issued
      descriptor evidence.validatedEvidence :=
  evidence.authorityIssued

theorem authorityIssuedDescriptorAdmissionUsesExactAuthorityClaim
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    {descriptor : PublicationDomainDescriptor}
    (evidence :
      AuthorityIssuedDescriptorAdmissionEvidence previous next descriptor) :
    evidence.validatedEvidence.validatedRegistryClaim =
      evidence.admissionAuthority.validatedRegistryClaim :=
  evidence.admissionAuthority.issuanceBindsEvidenceClaim
    evidence.authorityIssued

theorem authorityIssuedDescriptorAdmissionBindsSuccessorGeneration
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    {descriptor : PublicationDomainDescriptor}
    (evidence :
      AuthorityIssuedDescriptorAdmissionEvidence previous next descriptor) :
    evidence.validatedEvidence.admissionGeneration = next.generation :=
  evidence.validatedEvidence.generationMatchesSuccessor

theorem contentGovernedTransitionRequiresPreservationOrIssuedAdmission
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    (transition : ContentGovernedRegistryTrustRootTransition previous next)
    {descriptor : PublicationDomainDescriptor}
    (successorRegistered :
      next.trustRoot.registry.registered descriptor) :
    previous.trustRoot.registry.registered descriptor ∨
      Nonempty
        (AuthorityIssuedDescriptorAdmissionEvidence
          previous next descriptor) :=
  transition.successorDisposition descriptor successorRegistered

theorem unissuedSuccessorInjectionCannotCloseContentGovernedTransition
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    (transition : ContentGovernedRegistryTrustRootTransition previous next)
    {descriptor : PublicationDomainDescriptor}
    (successorRegistered :
      next.trustRoot.registry.registered descriptor)
    (notPreviouslyRegistered :
      ¬ previous.trustRoot.registry.registered descriptor) :
    Nonempty
      (AuthorityIssuedDescriptorAdmissionEvidence
        previous next descriptor) := by
  rcases
      transition.successorDisposition descriptor successorRegistered with
    preserved | admitted
  · exact False.elim (notPreviouslyRegistered preserved)
  · exact admitted

theorem sameDomainReplacementRequiresIssuedPredecessorRetirement
    {previous next : VersionedPublicationDomainRegistryTrustRoot}
    (transition : ContentGovernedRegistryTrustRootTransition previous next)
    {predecessorDescriptor successorDescriptor : PublicationDomainDescriptor}
    (predecessorRegistered :
      previous.trustRoot.registry.registered predecessorDescriptor)
    (successorRegistered :
      next.trustRoot.registry.registered successorDescriptor)
    (sameDomainIdentity :
      predecessorDescriptor.domainIdentity = successorDescriptor.domainIdentity)
    (differentDescriptor : predecessorDescriptor ≠ successorDescriptor) :
    Nonempty
      (AuthorityIssuedDescriptorRetirementEvidence
        previous next predecessorDescriptor) := by
  have successorNotPreviouslyRegistered :
      ¬ previous.trustRoot.registry.registered successorDescriptor := by
    intro successorPreviouslyRegistered
    have sameDescriptor :=
      previous.trustRoot.registry.identityInjective
        predecessorRegistered successorPreviouslyRegistered sameDomainIdentity
    exact differentDescriptor sameDescriptor
  rcases
      transition.successorDisposition successorDescriptor successorRegistered with
    preserved | admitted
  · exact False.elim (successorNotPreviouslyRegistered preserved)
  · rcases admitted with ⟨admission⟩
    exact
      admission.validatedEvidence.predecessorSameDomainRetired
        predecessorDescriptor predecessorRegistered sameDomainIdentity

end AgenticAILabProof.Enterprise.PublicationDomainRegistryLineageClosure
