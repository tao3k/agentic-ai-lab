-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityRefinementClosure
import AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityGenerationTransitionModel

namespace AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityGenerationTransitionClosure

open AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityRefinementClosure
open AgenticAILabProof.Enterprise.UseCompositionCedarFullLifecycleRegistryJoinClosure

structure CompatibleCedarInputIdentityGenerationTransitionClosed
    (old current : CedarInputContentIdentityAuthority) : Prop where
  authorityStable : old.authorityIdentity = current.authorityIdentity
  semanticIdentityStable : old.semanticIdentity = current.semanticIdentity
  generationAdvances : old.generation < current.generation
  requestAdmissionMonotone :
    ∀ request, old.requestAdmitted request → current.requestAdmitted request
  entitiesAdmissionMonotone :
    ∀ entities, old.entitiesAdmitted entities → current.entitiesAdmitted entities
  policiesAdmissionMonotone :
    ∀ policies, old.policiesAdmitted policies → current.policiesAdmitted policies
  snapshotAdmissionMonotone :
    ∀ request entities policies,
      old.snapshotAdmitted request entities policies →
      current.snapshotAdmitted request entities policies
  requestProjectionStable :
    ∀ request, old.requestAdmitted request →
      old.requestDigest request = current.requestDigest request
  entityStoreProjectionStable :
    ∀ entities, old.entitiesAdmitted entities →
      old.entityStoreDigest entities = current.entityStoreDigest entities
  policySetProjectionStable :
    ∀ policies, old.policiesAdmitted policies →
      old.policySetDigest policies = current.policySetDigest policies
  bundleProjectionStable :
    ∀ request entities policies,
      old.snapshotAdmitted request entities policies →
      old.bundleDigest request entities policies =
        current.bundleDigest request entities policies

structure CedarInputSemanticIdentityRotationClosed
    (old current : CedarInputContentIdentityAuthority) : Prop where
  authorityStable : old.authorityIdentity = current.authorityIdentity
  semanticIdentityChanges : old.semanticIdentity ≠ current.semanticIdentity
  generationAdvances : old.generation < current.generation

theorem compatibleTransitionPreservesOldAdmittedRequest
    {old current : CedarInputContentIdentityAuthority}
    (transition :
      CompatibleCedarInputIdentityGenerationTransitionClosed old current)
    {request : Cedar.Spec.Request}
    (oldAdmitted : old.requestAdmitted request) :
    current.requestAdmitted request ∧
      old.requestDigest request = current.requestDigest request :=
  ⟨transition.requestAdmissionMonotone request oldAdmitted,
    transition.requestProjectionStable request oldAdmitted⟩

theorem compatibleTransitionPreservesOldAdmittedBundle
    {old current : CedarInputContentIdentityAuthority}
    (transition :
      CompatibleCedarInputIdentityGenerationTransitionClosed old current)
    {request : Cedar.Spec.Request}
    {entities : Cedar.Spec.Entities}
    {policies : Cedar.Spec.Policies}
    (oldAdmitted : old.snapshotAdmitted request entities policies) :
    current.snapshotAdmitted request entities policies ∧
      old.bundleDigest request entities policies =
        current.bundleDigest request entities policies :=
  ⟨transition.snapshotAdmissionMonotone request entities policies oldAdmitted,
    transition.bundleProjectionStable request entities policies oldAdmitted⟩

theorem compatibleTransitionRejectsStaleGeneration
    {old current : CedarInputContentIdentityAuthority}
    (transition :
      CompatibleCedarInputIdentityGenerationTransitionClosed old current) :
    old.generation ≠ current.generation :=
  Nat.ne_of_lt transition.generationAdvances

theorem compatibleTransitionPreservesRefinementSemanticIdentity
    {old current : CedarInputContentIdentityAuthority}
    (transition :
      CompatibleCedarInputIdentityGenerationTransitionClosed old current)
    {fullLifecycleAuthority :
      CompositionFullLifecycleGrantAcceptanceAuthority}
    {fullLifecycleNode :
      CompositionFullLifecycleGrantAuthorityBoundNode fullLifecycleAuthority}
    (currentClosed :
      CompositionCedarInputIdentityRefinementClosed
        current fullLifecycleAuthority fullLifecycleNode) :
    old.semanticIdentity =
      fullLifecycleNode.nodeBinding.inputIdentitySemanticIdentity := by
  calc
    old.semanticIdentity = current.semanticIdentity :=
      transition.semanticIdentityStable
    _ = fullLifecycleNode.nodeBinding.inputIdentitySemanticIdentity :=
      currentClosed.semanticIdentityBound

theorem semanticRotationRejectsOldRefinementSemanticIdentity
    {old current : CedarInputContentIdentityAuthority}
    (rotation : CedarInputSemanticIdentityRotationClosed old current)
    {fullLifecycleAuthority :
      CompositionFullLifecycleGrantAcceptanceAuthority}
    {fullLifecycleNode :
      CompositionFullLifecycleGrantAuthorityBoundNode fullLifecycleAuthority}
    (currentClosed :
      CompositionCedarInputIdentityRefinementClosed
        current fullLifecycleAuthority fullLifecycleNode) :
    old.semanticIdentity ≠
      fullLifecycleNode.nodeBinding.inputIdentitySemanticIdentity := by
  intro oldAccepted
  apply rotation.semanticIdentityChanges
  calc
    old.semanticIdentity =
        fullLifecycleNode.nodeBinding.inputIdentitySemanticIdentity := oldAccepted
    _ = current.semanticIdentity := currentClosed.semanticIdentityBound.symm

theorem semanticRotationRejectsOldRefinementGeneration
    {old current : CedarInputContentIdentityAuthority}
    (rotation : CedarInputSemanticIdentityRotationClosed old current)
    {fullLifecycleAuthority :
      CompositionFullLifecycleGrantAcceptanceAuthority}
    {fullLifecycleNode :
      CompositionFullLifecycleGrantAuthorityBoundNode fullLifecycleAuthority}
    (currentClosed :
      CompositionCedarInputIdentityRefinementClosed
        current fullLifecycleAuthority fullLifecycleNode)
    (oldGenerationBound :
      old.generation = fullLifecycleNode.nodeBinding.inputIdentityGeneration) :
    False := by
  apply Nat.ne_of_lt rotation.generationAdvances
  calc
    old.generation =
        fullLifecycleNode.nodeBinding.inputIdentityGeneration := oldGenerationBound
    _ = current.generation := currentClosed.generationBound.symm

end AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityGenerationTransitionClosure
