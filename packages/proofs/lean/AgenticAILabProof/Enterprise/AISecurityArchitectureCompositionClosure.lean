-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import YuanxuProof.Composition.Identity
import AgenticAILabProof.PooC4.AuthorizedEffectEvidence
import AgenticAILabProof.Enterprise.BundleEvidenceBinding
import AgenticAILabProof.Enterprise.BundleOwnership

namespace AgenticAILabProof.Enterprise.AISecurityArchitectureCompositionClosure

open YuanxuProof.Composition.Identity
open AgenticAILabProof.Enterprise.BundleEvidenceBinding

abbrev ArchitectureSemanticId := String
abbrev ArchitectureInvariantId := String
abbrev ArchitectureCapabilityId := String
abbrev ArchitectureEvidenceDigest := String
abbrev ArchitectureProfileId := String

inductive ArchitectureMappingStatus
  | exactMapping
  | refinement
  | projection
  | partialMapping
  | conflicting
  | unknown
  deriving DecidableEq, Repr

structure ArchitectureSemantic where
  semanticId : ArchitectureSemanticId
  ownerIdentity : String
  sourceArchitecture : Identity
  requiredCapabilities : List ArchitectureCapabilityId
  deriving DecidableEq, Repr

structure ArchitectureMapping where
  mappingId : String
  sourceArchitecture : Identity
  targetArchitecture : Identity
  status : ArchitectureMappingStatus
  preservedInvariants : List ArchitectureInvariantId
  omittedInvariants : List ArchitectureInvariantId
  claimedInvariants : List ArchitectureInvariantId
  evidenceDigest : ArchitectureEvidenceDigest
  deriving DecidableEq, Repr

structure AISecurityArchitecturePackage where
  identity : Identity
  semantics : List ArchitectureSemantic
  mappings : List ArchitectureMapping
  requiredInvariants : List ArchitectureInvariantId
  capabilities : List ArchitectureCapabilityId
  evidenceRoot : ArchitectureEvidenceDigest
  deriving DecidableEq, Repr

structure AISecurityArchitectureProfile where
  profileId : ArchitectureProfileId
  proofRequired : Bool
  evidenceRoot : ArchitectureEvidenceDigest
  deriving DecidableEq, Repr

def architectureInvariantListsDisjoint
    (left right : List ArchitectureInvariantId) : Prop :=
  ∀ invariant, invariant ∈ left → invariant ∈ right → False

def architectureMappingAdmissible
    (profile : AISecurityArchitectureProfile)
    (mapping : ArchitectureMapping) : Prop :=
  (∀ invariant ∈ mapping.claimedInvariants,
      invariant ∈ mapping.preservedInvariants) ∧
    architectureInvariantListsDisjoint
      mapping.omittedInvariants
      mapping.claimedInvariants ∧
    match mapping.status with
    | .exactMapping =>
        mapping.evidenceDigest ≠ "" ∧ mapping.omittedInvariants = []
    | .refinement =>
        mapping.evidenceDigest ≠ ""
    | .projection =>
        True
    | .partialMapping =>
        profile.proofRequired = false
    | .conflicting =>
        False
    | .unknown =>
        profile.proofRequired = false

def composeArchitecturePackages
    (identity : Identity)
    (evidenceRoot : ArchitectureEvidenceDigest)
    (left right : AISecurityArchitecturePackage) :
    AISecurityArchitecturePackage :=
  { identity
    semantics := left.semantics ++ right.semantics
    mappings := left.mappings ++ right.mappings
    requiredInvariants :=
      left.requiredInvariants ++ right.requiredInvariants
    capabilities := left.capabilities ++ right.capabilities
    evidenceRoot }

structure AISecurityArchitectureCompositionClosed
    (left right composed : AISecurityArchitecturePackage)
    (profile : AISecurityArchitectureProfile) : Prop where
  compositionIdentityBound :
    composed.identity =
      (composeArchitecturePackages
        composed.identity
        composed.evidenceRoot
        left
        right).identity
  semanticsDerived :
    composed.semantics = left.semantics ++ right.semantics
  mappingsDerived :
    composed.mappings = left.mappings ++ right.mappings
  invariantsDerived :
    composed.requiredInvariants =
      left.requiredInvariants ++ right.requiredInvariants
  capabilitiesConfined :
    ∀ capability ∈ composed.capabilities,
      capability ∈ left.capabilities ∨ capability ∈ right.capabilities
  packageEvidencePresent :
    composed.evidenceRoot ≠ ""
  profileEvidencePresent :
    profile.evidenceRoot ≠ ""
  mappingsAdmissible :
    ∀ mapping ∈ composed.mappings,
      architectureMappingAdmissible profile mapping

structure AISecurityArchitectureRuntimeProjectionClosed
    (left right composed : AISecurityArchitecturePackage)
    (profile : AISecurityArchitectureProfile)
    (subject : BundleSubject)
    (receipt : BoundVerificationReceipt)
    (effectEvidence : AgenticAILabProof.PooC4.AuthorizedEffectEvidenceFacts) :
    Prop where
  compositionClosed :
    AISecurityArchitectureCompositionClosed left right composed profile
  bundleEvidenceBound :
    acceptsBound subject receipt
  authorizedEffectEvidenceBound :
    AgenticAILabProof.PooC4.authorizedEffectL1 effectEvidence

theorem composeArchitecturePackagesDeterministic
    (identity : Identity)
    (evidenceRoot : ArchitectureEvidenceDigest)
    (left right : AISecurityArchitecturePackage) :
    composeArchitecturePackages identity evidenceRoot left right =
      composeArchitecturePackages identity evidenceRoot left right := by
  rfl

theorem composedSemanticsPreserveLeftOwner
    (identity : Identity)
    (evidenceRoot : ArchitectureEvidenceDigest)
    (left right : AISecurityArchitecturePackage)
    (semantic : ArchitectureSemantic)
    (member : semantic ∈ left.semantics) :
    semantic ∈
      (composeArchitecturePackages
        identity
        evidenceRoot
        left
        right).semantics := by
  simp [composeArchitecturePackages, member]

theorem composedSemanticsPreserveRightOwner
    (identity : Identity)
    (evidenceRoot : ArchitectureEvidenceDigest)
    (left right : AISecurityArchitecturePackage)
    (semantic : ArchitectureSemantic)
    (member : semantic ∈ right.semantics) :
    semantic ∈
      (composeArchitecturePackages
        identity
        evidenceRoot
        left
        right).semantics := by
  simp [composeArchitecturePackages, member]

theorem composeArchitecturePackagesDoesNotAmplifyCapabilities
    (identity : Identity)
    (evidenceRoot : ArchitectureEvidenceDigest)
    (left right : AISecurityArchitecturePackage)
    (capability : ArchitectureCapabilityId)
    (member :
      capability ∈
        (composeArchitecturePackages
          identity
          evidenceRoot
          left
          right).capabilities) :
    capability ∈ left.capabilities ∨ capability ∈ right.capabilities := by
  simpa [composeArchitecturePackages] using member

theorem admittedMappingCannotClaimOmittedInvariant
    (profile : AISecurityArchitectureProfile)
    (mapping : ArchitectureMapping)
    (admitted : architectureMappingAdmissible profile mapping)
    (invariant : ArchitectureInvariantId)
    (omitted : invariant ∈ mapping.omittedInvariants)
    (claimed : invariant ∈ mapping.claimedInvariants) :
    False :=
  admitted.2.1 invariant omitted claimed

theorem conflictingMappingRejectsCompositionClosure
    {left right composed : AISecurityArchitecturePackage}
    {profile : AISecurityArchitectureProfile}
    {mapping : ArchitectureMapping}
    (status : mapping.status = .conflicting)
    (member : mapping ∈ composed.mappings) :
    ¬ AISecurityArchitectureCompositionClosed
      left
      right
      composed
      profile := by
  intro closed
  have admitted := closed.mappingsAdmissible mapping member
  simp [architectureMappingAdmissible, status] at admitted

theorem unknownMappingRejectsProofRequiredComposition
    {left right composed : AISecurityArchitecturePackage}
    {profile : AISecurityArchitectureProfile}
    {mapping : ArchitectureMapping}
    (status : mapping.status = .unknown)
    (proofRequired : profile.proofRequired = true)
    (member : mapping ∈ composed.mappings) :
    ¬ AISecurityArchitectureCompositionClosed
      left
      right
      composed
      profile := by
  intro closed
  have admitted := closed.mappingsAdmissible mapping member
  simp [architectureMappingAdmissible, status, proofRequired] at admitted

theorem closedCompositionRequiresBoundBundleEvidence
    {left right composed : AISecurityArchitecturePackage}
    {profile : AISecurityArchitectureProfile}
    {subject : BundleSubject}
    {receipt : BoundVerificationReceipt}
    {effectEvidence : AgenticAILabProof.PooC4.AuthorizedEffectEvidenceFacts}
    (closed :
      AISecurityArchitectureRuntimeProjectionClosed
        left
        right
        composed
        profile
        subject
        receipt
        effectEvidence) :
    acceptsBound subject receipt :=
  closed.bundleEvidenceBound

theorem closedCompositionRequiresAuthorizedEffectEvidence
    {left right composed : AISecurityArchitecturePackage}
    {profile : AISecurityArchitectureProfile}
    {subject : BundleSubject}
    {receipt : BoundVerificationReceipt}
    {effectEvidence : AgenticAILabProof.PooC4.AuthorizedEffectEvidenceFacts}
    (closed :
      AISecurityArchitectureRuntimeProjectionClosed
        left
        right
        composed
        profile
        subject
        receipt
        effectEvidence) :
    AgenticAILabProof.PooC4.authorizedEffectL1 effectEvidence :=
  closed.authorizedEffectEvidenceBound

theorem mismatchedBundleEvidenceRejectsRuntimeProjectionClosure
    {left right composed : AISecurityArchitecturePackage}
    {profile : AISecurityArchitectureProfile}
    {subject : BundleSubject}
    {receipt : BoundVerificationReceipt}
    {effectEvidence : AgenticAILabProof.PooC4.AuthorizedEffectEvidenceFacts}
    (mismatch : ¬ acceptsBound subject receipt) :
    ¬ AISecurityArchitectureRuntimeProjectionClosed
      left
      right
      composed
      profile
      subject
      receipt
      effectEvidence := by
  intro closed
  exact mismatch closed.bundleEvidenceBound

end AgenticAILabProof.Enterprise.AISecurityArchitectureCompositionClosure
