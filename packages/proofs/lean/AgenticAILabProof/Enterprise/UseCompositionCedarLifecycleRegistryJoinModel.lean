-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.UseCompositionCedarLifecycleRegistryJoinModel

structure RegistryLifecycleEvidence where
  evidenceIdentity : Nat
  commitment : Nat
  authorityIdentity : Nat
  runtimeEpoch : Nat
  activeFenceToken : Nat
  admitted : Bool
  deriving DecidableEq, Repr

structure LifecycleEvidenceRegistry where
  registryIdentity : Nat
  activeGeneration : Nat
  lookup : Nat → RegistryLifecycleEvidence

structure CompositionLifecycleBinding where
  grantIdentity : Nat
  registryIdentity : Nat
  registryGeneration : Nat
  evidence : RegistryLifecycleEvidence

structure CommitmentAuthenticity where
  commitment : Nat
  authorityIdentity : Nat
  registryIdentity : Nat
  registryGeneration : Nat
  signatureValid : Bool
  deriving DecidableEq, Repr

def localLifecycleClosed (evidence : RegistryLifecycleEvidence) : Prop :=
  evidence.evidenceIdentity ≠ 0 ∧
    evidence.commitment ≠ 0 ∧
    evidence.authorityIdentity ≠ 0 ∧
    evidence.admitted = true

def legacyLocalJoin
    (expectedAuthority runtimeGeneration : Nat)
    (binding : CompositionLifecycleBinding) : Prop :=
  localLifecycleClosed binding.evidence ∧
    binding.evidence.authorityIdentity = expectedAuthority ∧
    binding.evidence.runtimeEpoch = runtimeGeneration

structure FullRegistryLifecycleJoinClosed
    (expectedAuthority runtimeGeneration : Nat)
    (registry : LifecycleEvidenceRegistry)
    (binding : CompositionLifecycleBinding)
    (authenticity : CommitmentAuthenticity) : Prop where
  localClosed : localLifecycleClosed binding.evidence
  registryIdentityBound : binding.registryIdentity = registry.registryIdentity
  registryGenerationBound :
    binding.registryGeneration = registry.activeGeneration
  selectedEvidenceBound :
    binding.evidence = registry.lookup authenticity.commitment
  commitmentBound : binding.evidence.commitment = authenticity.commitment
  authorityBound : binding.evidence.authorityIdentity = expectedAuthority
  runtimeBound : binding.evidence.runtimeEpoch = runtimeGeneration
  authenticityCommitmentBound :
    authenticity.commitment = binding.evidence.commitment
  authenticityAuthorityBound :
    authenticity.authorityIdentity = expectedAuthority
  authenticityRegistryIdentityBound :
    authenticity.registryIdentity = registry.registryIdentity
  authenticityRegistryGenerationBound :
    authenticity.registryGeneration = registry.activeGeneration
  signatureValid : authenticity.signatureValid = true

def registeredEvidence : RegistryLifecycleEvidence where
  evidenceIdentity := 101
  commitment := 201
  authorityIdentity := 17
  runtimeEpoch := 11
  activeFenceToken := 401
  admitted := true

def forgedEvidence : RegistryLifecycleEvidence where
  evidenceIdentity := 102
  commitment := 202
  authorityIdentity := 17
  runtimeEpoch := 11
  activeFenceToken := 402
  admitted := true

def sampleRegistry : LifecycleEvidenceRegistry where
  registryIdentity := 29
  activeGeneration := 3
  lookup := fun _ => registeredEvidence

def forgedBinding : CompositionLifecycleBinding where
  grantIdentity := 700
  registryIdentity := 29
  registryGeneration := 3
  evidence := forgedEvidence

theorem localClosedAuthorityEpochJoinAcceptsUnregisteredEvidence :
    legacyLocalJoin 17 11 forgedBinding ∧
      forgedBinding.evidence ≠ sampleRegistry.lookup 202 := by
  simp [legacyLocalJoin, localLifecycleClosed, forgedBinding, forgedEvidence,
    sampleRegistry, registeredEvidence]

theorem fullRegistryJoinRejectsUnregisteredEvidence
    {expectedAuthority runtimeGeneration : Nat}
    {registry : LifecycleEvidenceRegistry}
    {binding : CompositionLifecycleBinding}
    {authenticity : CommitmentAuthenticity}
    (closed :
      FullRegistryLifecycleJoinClosed
        expectedAuthority runtimeGeneration registry binding authenticity)
    (mismatch :
      binding.evidence ≠ registry.lookup authenticity.commitment) : False :=
  mismatch closed.selectedEvidenceBound

theorem fullRegistryJoinRejectsStaleRegistryGeneration
    {expectedAuthority runtimeGeneration : Nat}
    {registry : LifecycleEvidenceRegistry}
    {binding : CompositionLifecycleBinding}
    {authenticity : CommitmentAuthenticity}
    (closed :
      FullRegistryLifecycleJoinClosed
        expectedAuthority runtimeGeneration registry binding authenticity)
    (mismatch : binding.registryGeneration ≠ registry.activeGeneration) : False :=
  mismatch closed.registryGenerationBound

theorem fullRegistryJoinRequiresSignatureAuthorityAndCommitment
    {expectedAuthority runtimeGeneration : Nat}
    {registry : LifecycleEvidenceRegistry}
    {binding : CompositionLifecycleBinding}
    {authenticity : CommitmentAuthenticity}
    (closed :
      FullRegistryLifecycleJoinClosed
        expectedAuthority runtimeGeneration registry binding authenticity) :
    authenticity.signatureValid = true ∧
      authenticity.authorityIdentity = expectedAuthority ∧
      authenticity.commitment = binding.evidence.commitment :=
  ⟨closed.signatureValid,
    closed.authenticityAuthorityBound,
    closed.authenticityCommitmentBound⟩

end AgenticAILabProof.Enterprise.UseCompositionCedarLifecycleRegistryJoinModel
