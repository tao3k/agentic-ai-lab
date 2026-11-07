-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.PooC4.CapabilityRoleIsolation

universe u

inductive CapabilityRole where
  | semanticAdmission
  | runtimeExecution
  | disclosure
deriving Repr, DecidableEq

structure CapabilityRequirement (Scope : Type u) where
  role : CapabilityRole
  requestedScope : Scope
  definitionIdentity : Nat
  policyIdentity : Nat
deriving Repr, DecidableEq

structure CanonicalCapabilityScope (Scope : Type u) where
  role : CapabilityRole
  scope : Scope
deriving Repr, DecidableEq

structure LiveCapabilityProof (Scope : Type u) where
  role : CapabilityRole
  admittedScope : CanonicalCapabilityScope Scope
  tokenIdentity : Nat
  leaseGeneration : Nat
deriving Repr, DecidableEq

inductive AdmissionOutcome where
  | admitted
  | rejected
deriving Repr, DecidableEq

structure CapabilityAdmissionReceipt (Scope : Type u) where
  requirement : CapabilityRequirement Scope
  canonicalScope : CanonicalCapabilityScope Scope
  proofDigest : Nat
  outcome : AdmissionOutcome
deriving Repr, DecidableEq

inductive CapabilityArtifactView (Scope : Type u) where
  | requirement (value : CapabilityRequirement Scope)
  | canonicalScope (value : CanonicalCapabilityScope Scope)
  | liveProof (value : LiveCapabilityProof Scope)
  | receipt (value : CapabilityAdmissionReceipt Scope)

def GrantsRuntimeExecutionAuthority
    {Scope : Type u} :
    CapabilityArtifactView Scope → Prop
  | CapabilityArtifactView.requirement _ => False
  | CapabilityArtifactView.canonicalScope _ => False
  | CapabilityArtifactView.liveProof proof =>
      proof.role = CapabilityRole.runtimeExecution
  | CapabilityArtifactView.receipt _ => False

structure SemanticTargetKey (Base Scope : Type u) where
  base : Base
  semanticScope : Option (CanonicalCapabilityScope Scope)
deriving Repr, DecidableEq

structure CapabilityBoundDemand (Base Scope : Type u) where
  semanticTarget : SemanticTargetKey Base Scope
  requirement : CapabilityRequirement Scope
  liveProof : Option (LiveCapabilityProof Scope)
  admissionReceipt : Option (CapabilityAdmissionReceipt Scope)
deriving Repr, DecidableEq

def businessResultCacheKey
    {Base Scope : Type u}
    (demand : CapabilityBoundDemand Base Scope) :
    SemanticTargetKey Base Scope :=
  demand.semanticTarget

theorem requirementDoesNotGrantRuntimeExecution
    {Scope : Type u}
    (requirement : CapabilityRequirement Scope) :
    ¬ GrantsRuntimeExecutionAuthority
      (CapabilityArtifactView.requirement requirement) := by
  intro authority
  exact authority

theorem canonicalScopeDoesNotGrantRuntimeExecution
    {Scope : Type u}
    (scope : CanonicalCapabilityScope Scope) :
    ¬ GrantsRuntimeExecutionAuthority
      (CapabilityArtifactView.canonicalScope scope) := by
  intro authority
  exact authority

theorem admissionReceiptDoesNotGrantRuntimeExecution
    {Scope : Type u}
    (receipt : CapabilityAdmissionReceipt Scope) :
    ¬ GrantsRuntimeExecutionAuthority
      (CapabilityArtifactView.receipt receipt) := by
  intro authority
  exact authority

theorem runtimeExecutionAuthorityRequiresLiveProof
    {Scope : Type u}
    (artifact : CapabilityArtifactView Scope)
    (authority : GrantsRuntimeExecutionAuthority artifact) :
    ∃ proof : LiveCapabilityProof Scope,
      artifact = CapabilityArtifactView.liveProof proof ∧
        proof.role = CapabilityRole.runtimeExecution := by
  cases artifact with
  | requirement requirement =>
      exact False.elim authority
  | canonicalScope scope =>
      exact False.elim authority
  | liveProof proof =>
      exact ⟨proof, rfl, authority⟩
  | receipt receipt =>
      exact False.elim authority

theorem changingLiveProofCannotSplitBusinessResultCache
    {Base Scope : Type u}
    (target : SemanticTargetKey Base Scope)
    (requirement : CapabilityRequirement Scope)
    (leftProof rightProof : Option (LiveCapabilityProof Scope))
    (receipt : Option (CapabilityAdmissionReceipt Scope)) :
    businessResultCacheKey
        ({ semanticTarget := target
           requirement := requirement
           liveProof := leftProof
           admissionReceipt := receipt } :
          CapabilityBoundDemand Base Scope) =
      businessResultCacheKey
        ({ semanticTarget := target
           requirement := requirement
           liveProof := rightProof
           admissionReceipt := receipt } :
          CapabilityBoundDemand Base Scope) := by
  rfl

theorem changingReceiptCannotSplitBusinessResultCache
    {Base Scope : Type u}
    (target : SemanticTargetKey Base Scope)
    (requirement : CapabilityRequirement Scope)
    (proof : Option (LiveCapabilityProof Scope))
    (leftReceipt rightReceipt :
      Option (CapabilityAdmissionReceipt Scope)) :
    businessResultCacheKey
        ({ semanticTarget := target
           requirement := requirement
           liveProof := proof
           admissionReceipt := leftReceipt } :
          CapabilityBoundDemand Base Scope) =
      businessResultCacheKey
        ({ semanticTarget := target
           requirement := requirement
           liveProof := proof
           admissionReceipt := rightReceipt } :
          CapabilityBoundDemand Base Scope) := by
  rfl

theorem changingRequirementCannotSplitFixedSemanticTarget
    {Base Scope : Type u}
    (target : SemanticTargetKey Base Scope)
    (leftRequirement rightRequirement : CapabilityRequirement Scope)
    (proof : Option (LiveCapabilityProof Scope))
    (receipt : Option (CapabilityAdmissionReceipt Scope)) :
    businessResultCacheKey
        ({ semanticTarget := target
           requirement := leftRequirement
           liveProof := proof
           admissionReceipt := receipt } :
          CapabilityBoundDemand Base Scope) =
      businessResultCacheKey
        ({ semanticTarget := target
           requirement := rightRequirement
           liveProof := proof
           admissionReceipt := receipt } :
          CapabilityBoundDemand Base Scope) := by
  rfl

end AgenticAILabProof.PooC4.CapabilityRoleIsolation
