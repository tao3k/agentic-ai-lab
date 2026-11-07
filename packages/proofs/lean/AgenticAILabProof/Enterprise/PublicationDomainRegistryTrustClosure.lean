-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.CheckpointWatermarkRecoveryClosure

namespace AgenticAILabProof.Enterprise.PublicationDomainRegistryTrustClosure

open AgenticAILabProof.Enterprise.CheckpointWatermarkRecoveryClosure

def singletonPublicationDomainRegistry
    (descriptor : PublicationDomainDescriptor) :
    PublicationDomainIdentityRegistry := {
  registered := fun candidate => candidate = descriptor
  identityInjective := by
    intro left right leftRegistered rightRegistered _
    exact leftRegistered.trans rightRegistered.symm
}

theorem individuallyInjectiveRegistriesCanDisagreeOnSameDomainIdentity :
    ∃ (leftRegistry rightRegistry : PublicationDomainIdentityRegistry)
      (leftDescriptor rightDescriptor : PublicationDomainDescriptor),
      leftRegistry.registered leftDescriptor ∧
        rightRegistry.registered rightDescriptor ∧
        leftDescriptor.domainIdentity = rightDescriptor.domainIdentity ∧
        leftDescriptor ≠ rightDescriptor := by
  let leftDescriptor : PublicationDomainDescriptor := {
    domainIdentity := 271
    authorityIdentity := 277
    semanticIdentity := 281
  }
  let rightDescriptor : PublicationDomainDescriptor := {
    domainIdentity := 271
    authorityIdentity := 283
    semanticIdentity := 293
  }
  let leftRegistry := singletonPublicationDomainRegistry leftDescriptor
  let rightRegistry := singletonPublicationDomainRegistry rightDescriptor
  refine
    ⟨leftRegistry, rightRegistry, leftDescriptor, rightDescriptor,
      rfl, rfl, rfl, ?_⟩
  decide

structure PublicationDomainRegistryTrustRoot where
  registryAuthorityIdentity : Nat
  registrySemanticIdentity : Nat
  registry : PublicationDomainIdentityRegistry

/--
The registry-level identity claim validated by the acceptance authority.  It
does not reuse either a publication-domain descriptor semantic identity or a
Cedar input content semantic identity.
-/
structure PublicationDomainRegistryTrustClaim where
  registryAuthorityIdentity : Nat
  registrySemanticIdentity : Nat
  deriving DecidableEq

def publicationDomainRegistryTrustClaim
    (trustRoot : PublicationDomainRegistryTrustRoot) :
    PublicationDomainRegistryTrustClaim :=
  {
    registryAuthorityIdentity := trustRoot.registryAuthorityIdentity
    registrySemanticIdentity := trustRoot.registrySemanticIdentity
  }

structure TrustRootBoundCheckpointWatermarkEvidence
    (trustRoot : PublicationDomainRegistryTrustRoot) where
  registeredEvidence :
    RegisteredCheckpointWatermarkEvidence trustRoot.registry

/--
The closed v1 evidence joins the exact acceptance-authority-validated registry
claim with checkpoint-watermark evidence indexed by the same trust-root
registry.  The type parameter supplies the registry join; the exact claim binds
the registry-level authority and semantics without structural equality on the
registry implementation.
-/
structure AuthorityValidatedTrustRootBoundCheckpointWatermarkEvidence
    (trustRoot : PublicationDomainRegistryTrustRoot) where
  registeredEvidence :
    RegisteredCheckpointWatermarkEvidence trustRoot.registry
  validatedClaim : PublicationDomainRegistryTrustClaim
  claimMatchesTrustRoot :
    validatedClaim = publicationDomainRegistryTrustClaim trustRoot

theorem trustRootBoundEvidencePreservesDescriptorAuthority
    {trustRoot : PublicationDomainRegistryTrustRoot}
    (evidence : TrustRootBoundCheckpointWatermarkEvidence trustRoot) :
    evidence.registeredEvidence.domainDescriptor.authorityIdentity =
      evidence.registeredEvidence.watermark.authorityIdentity :=
  evidence.registeredEvidence.authorityMatches

theorem trustRootBoundEvidencePermitsRegistryMetadataSubstitution
    {registry : PublicationDomainIdentityRegistry}
    (registeredEvidence : RegisteredCheckpointWatermarkEvidence registry) :
    ∃ (left right : PublicationDomainRegistryTrustRoot),
      left.registryAuthorityIdentity ≠ right.registryAuthorityIdentity ∧
        left.registrySemanticIdentity ≠ right.registrySemanticIdentity ∧
          Nonempty (TrustRootBoundCheckpointWatermarkEvidence left) ∧
            Nonempty (TrustRootBoundCheckpointWatermarkEvidence right) := by
  let left : PublicationDomainRegistryTrustRoot := {
    registryAuthorityIdentity := 307
    registrySemanticIdentity := 311
    registry := registry
  }
  let right : PublicationDomainRegistryTrustRoot := {
    registryAuthorityIdentity := 313
    registrySemanticIdentity := 317
    registry := registry
  }
  refine ⟨left, right, ?_, ?_, ?_, ?_⟩
  · simp [left, right]
  · simp [left, right]
  · exact ⟨{ registeredEvidence := registeredEvidence }⟩
  · exact ⟨{ registeredEvidence := registeredEvidence }⟩

theorem authorityValidatedTrustRootEvidenceBindsRegistryAuthority
    {trustRoot : PublicationDomainRegistryTrustRoot}
    (evidence :
      AuthorityValidatedTrustRootBoundCheckpointWatermarkEvidence trustRoot) :
    evidence.validatedClaim.registryAuthorityIdentity =
      trustRoot.registryAuthorityIdentity := by
  have claimEquality :=
    congrArg
      (fun claim : PublicationDomainRegistryTrustClaim =>
        claim.registryAuthorityIdentity)
      evidence.claimMatchesTrustRoot
  simpa [publicationDomainRegistryTrustClaim] using claimEquality

theorem authorityValidatedTrustRootEvidenceBindsRegistrySemantics
    {trustRoot : PublicationDomainRegistryTrustRoot}
    (evidence :
      AuthorityValidatedTrustRootBoundCheckpointWatermarkEvidence trustRoot) :
    evidence.validatedClaim.registrySemanticIdentity =
      trustRoot.registrySemanticIdentity := by
  have claimEquality :=
    congrArg
      (fun claim : PublicationDomainRegistryTrustClaim =>
        claim.registrySemanticIdentity)
      evidence.claimMatchesTrustRoot
  simpa [publicationDomainRegistryTrustClaim] using claimEquality

theorem mismatchedRegistryTrustClaimCannotBind
    {trustRoot : PublicationDomainRegistryTrustRoot}
    (evidence :
      AuthorityValidatedTrustRootBoundCheckpointWatermarkEvidence trustRoot)
    (authorityMismatch :
      evidence.validatedClaim.registryAuthorityIdentity ≠
        trustRoot.registryAuthorityIdentity ∨
      evidence.validatedClaim.registrySemanticIdentity ≠
        trustRoot.registrySemanticIdentity) : False := by
  rcases authorityMismatch with authorityMismatch | semanticsMismatch
  · exact
      authorityMismatch
        (authorityValidatedTrustRootEvidenceBindsRegistryAuthority evidence)
  · exact
      semanticsMismatch
        (authorityValidatedTrustRootEvidenceBindsRegistrySemantics evidence)

theorem sharedRegistryTrustRootRejectsSplitRegistry
    {trustRoot : PublicationDomainRegistryTrustRoot}
    (left right : TrustRootBoundCheckpointWatermarkEvidence trustRoot)
    (sameDomainIdentity :
      left.registeredEvidence.watermark.publicationDomainIdentity =
        right.registeredEvidence.watermark.publicationDomainIdentity) :
    left.registeredEvidence.domainDescriptor =
      right.registeredEvidence.domainDescriptor := by
  apply trustRoot.registry.identityInjective
  · exact left.registeredEvidence.descriptorRegistered
  · exact right.registeredEvidence.descriptorRegistered
  · calc
      left.registeredEvidence.domainDescriptor.domainIdentity =
          left.registeredEvidence.watermark.publicationDomainIdentity :=
        left.registeredEvidence.identityMatches
      _ = right.registeredEvidence.watermark.publicationDomainIdentity :=
        sameDomainIdentity
      _ = right.registeredEvidence.domainDescriptor.domainIdentity :=
        right.registeredEvidence.identityMatches.symm

end AgenticAILabProof.Enterprise.PublicationDomainRegistryTrustClosure
