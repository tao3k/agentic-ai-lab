-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityGenerationTransitionModel

structure IdentityAuthoritySnapshot where
  authorityIdentity : Nat
  semanticIdentity : Nat
  generation : Nat
  digest : Nat → Nat
  admitted : Nat → Prop

structure IdentityReceipt where
  semanticIdentity : Nat
  generation : Nat
  content : Nat
  digest : Nat
  deriving DecidableEq, Repr

def receiptAccepted
    (authority : IdentityAuthoritySnapshot)
    (receipt : IdentityReceipt) : Prop :=
  receipt.semanticIdentity = authority.semanticIdentity ∧
    receipt.generation = authority.generation ∧
    authority.admitted receipt.content ∧
    receipt.digest = authority.digest receipt.content

def legacySameSemanticTransition
    (old current : IdentityAuthoritySnapshot) : Prop :=
  old.authorityIdentity = current.authorityIdentity ∧
    old.semanticIdentity = current.semanticIdentity ∧
    old.generation < current.generation

structure CompatibleIdentityGenerationTransitionClosed
    (old current : IdentityAuthoritySnapshot) : Prop where
  authorityStable : old.authorityIdentity = current.authorityIdentity
  semanticIdentityStable : old.semanticIdentity = current.semanticIdentity
  generationAdvances : old.generation < current.generation
  admissionMonotone :
    ∀ content, old.admitted content → current.admitted content
  projectionStable :
    ∀ content, old.admitted content → old.digest content = current.digest content

structure SemanticIdentityRotationClosed
    (old current : IdentityAuthoritySnapshot) : Prop where
  authorityStable : old.authorityIdentity = current.authorityIdentity
  semanticIdentityChanges : old.semanticIdentity ≠ current.semanticIdentity
  generationAdvances : old.generation < current.generation

def oldAuthority : IdentityAuthoritySnapshot where
  authorityIdentity := 17
  semanticIdentity := 31
  generation := 3
  digest := fun content => content + 100
  admitted := fun content => content = 7

def driftingAuthority : IdentityAuthoritySnapshot where
  authorityIdentity := 17
  semanticIdentity := 31
  generation := 4
  digest := fun content => content + 200
  admitted := fun content => content = 7

theorem legacySameSemanticTransitionAllowsDigestDrift :
    legacySameSemanticTransition oldAuthority driftingAuthority ∧
      oldAuthority.admitted 7 ∧
      oldAuthority.digest 7 ≠ driftingAuthority.digest 7 := by
  simp [legacySameSemanticTransition, oldAuthority, driftingAuthority]

theorem compatibleTransitionPreservesOldAdmittedDigest
    {old current : IdentityAuthoritySnapshot}
    (transition : CompatibleIdentityGenerationTransitionClosed old current)
    {content : Nat}
    (oldAdmitted : old.admitted content) :
    old.digest content = current.digest content :=
  transition.projectionStable content oldAdmitted

theorem compatibleTransitionPreservesOldAdmission
    {old current : IdentityAuthoritySnapshot}
    (transition : CompatibleIdentityGenerationTransitionClosed old current)
    {content : Nat}
    (oldAdmitted : old.admitted content) :
    current.admitted content :=
  transition.admissionMonotone content oldAdmitted

theorem currentGenerationRejectsOldReceipt
    {current : IdentityAuthoritySnapshot}
    {receipt : IdentityReceipt}
    (oldGeneration : receipt.generation ≠ current.generation) :
    ¬ receiptAccepted current receipt := by
  intro accepted
  exact oldGeneration accepted.2.1

theorem semanticRotationRejectsOldSemanticReceipt
    {old current : IdentityAuthoritySnapshot}
    (rotation : SemanticIdentityRotationClosed old current)
    {receipt : IdentityReceipt}
    (oldSemanticIdentity : receipt.semanticIdentity = old.semanticIdentity) :
    ¬ receiptAccepted current receipt := by
  intro accepted
  apply rotation.semanticIdentityChanges
  calc
    old.semanticIdentity = receipt.semanticIdentity := oldSemanticIdentity.symm
    _ = current.semanticIdentity := accepted.1

theorem compatibleTransitionCannotUseStaleGeneration
    {old current : IdentityAuthoritySnapshot}
    (transition : CompatibleIdentityGenerationTransitionClosed old current) :
    old.generation ≠ current.generation :=
  Nat.ne_of_lt transition.generationAdvances

end AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityGenerationTransitionModel
