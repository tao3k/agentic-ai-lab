-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.UseCompositionCedarFullLifecycleRegistryJoinClosure
import AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityRefinementModel

namespace AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityRefinementClosure

open AgenticAILabProof.Enterprise.UseCompositionCedarFullLifecycleRegistryJoinClosure

/-!
Content-identity authority for the exact Cedar inputs selected by the full
lifecycle registry.  Uniqueness is intentionally bounded to admitted inputs;
the model does not claim that a finite cryptographic digest is globally
injective.
-/

structure CedarInputContentIdentityAuthority where
  authorityIdentity : String
  semanticIdentity : String
  generation : Nat
  requestDigest : Cedar.Spec.Request → String
  entityStoreDigest : Cedar.Spec.Entities → String
  policySetDigest : Cedar.Spec.Policies → String
  bundleDigest :
    Cedar.Spec.Request → Cedar.Spec.Entities → Cedar.Spec.Policies → String
  requestAdmitted : Cedar.Spec.Request → Prop
  entitiesAdmitted : Cedar.Spec.Entities → Prop
  policiesAdmitted : Cedar.Spec.Policies → Prop
  snapshotAdmitted :
    Cedar.Spec.Request → Cedar.Spec.Entities → Cedar.Spec.Policies → Prop
  requestUniqueOnAdmitted :
    ∀ left right,
      requestAdmitted left → requestAdmitted right →
      requestDigest left = requestDigest right → left = right
  entitiesUniqueOnAdmitted :
    ∀ left right,
      entitiesAdmitted left → entitiesAdmitted right →
      entityStoreDigest left = entityStoreDigest right → left = right
  policiesUniqueOnAdmitted :
    ∀ left right,
      policiesAdmitted left → policiesAdmitted right →
      policySetDigest left = policySetDigest right → left = right
  snapshotUniqueOnAdmitted :
    ∀ leftRequest leftEntities leftPolicies
      rightRequest rightEntities rightPolicies,
      snapshotAdmitted leftRequest leftEntities leftPolicies →
      snapshotAdmitted rightRequest rightEntities rightPolicies →
      bundleDigest leftRequest leftEntities leftPolicies =
        bundleDigest rightRequest rightEntities rightPolicies →
      leftRequest = rightRequest ∧
        leftEntities = rightEntities ∧
        leftPolicies = rightPolicies

structure CompositionCedarInputIdentityRefinementClosed
    (identityAuthority : CedarInputContentIdentityAuthority)
    (fullLifecycleAuthority :
      CompositionFullLifecycleGrantAcceptanceAuthority)
    (fullLifecycleNode :
      CompositionFullLifecycleGrantAuthorityBoundNode fullLifecycleAuthority) :
    Prop where
  authorityBound :
    identityAuthority.authorityIdentity =
      fullLifecycleNode.nodeBinding.lifecycleEvidence.authorityIdentity
  semanticIdentityBound :
    identityAuthority.semanticIdentity =
      fullLifecycleNode.nodeBinding.inputIdentitySemanticIdentity
  generationBound :
    identityAuthority.generation =
      fullLifecycleNode.nodeBinding.inputIdentityGeneration
  requestAdmitted :
    identityAuthority.requestAdmitted
      fullLifecycleNode.nodeBinding.lifecycleEvidence.snapshot.request
  entitiesAdmitted :
    identityAuthority.entitiesAdmitted
      fullLifecycleNode.nodeBinding.lifecycleEvidence.snapshot.entities
  policiesAdmitted :
    identityAuthority.policiesAdmitted
      fullLifecycleNode.nodeBinding.lifecycleEvidence.snapshot.policies
  snapshotAdmitted :
    identityAuthority.snapshotAdmitted
      fullLifecycleNode.nodeBinding.lifecycleEvidence.snapshot.request
      fullLifecycleNode.nodeBinding.lifecycleEvidence.snapshot.entities
      fullLifecycleNode.nodeBinding.lifecycleEvidence.snapshot.policies
  requestDigestBound :
    fullLifecycleNode.nodeBinding.grant.authorizationSubject.requestDigest =
      identityAuthority.requestDigest
        fullLifecycleNode.nodeBinding.lifecycleEvidence.snapshot.request
  entityStoreDigestBound :
    fullLifecycleNode.nodeBinding.grant.authorizationSubject.entityStoreDigest =
      identityAuthority.entityStoreDigest
        fullLifecycleNode.nodeBinding.lifecycleEvidence.snapshot.entities
  policySetDigestBound :
    fullLifecycleNode.nodeBinding.grant.authorizationSubject.policySetDigest =
      identityAuthority.policySetDigest
        fullLifecycleNode.nodeBinding.lifecycleEvidence.snapshot.policies
  bundleDigestBound :
    fullLifecycleNode.nodeBinding.grant.authorizationSubject.bundleDigest =
      identityAuthority.bundleDigest
        fullLifecycleNode.nodeBinding.lifecycleEvidence.snapshot.request
        fullLifecycleNode.nodeBinding.lifecycleEvidence.snapshot.entities
        fullLifecycleNode.nodeBinding.lifecycleEvidence.snapshot.policies

theorem closedInputIdentityRefinementUsesAuthorityValidatedBinding
    {identityAuthority : CedarInputContentIdentityAuthority}
    {fullLifecycleAuthority :
      CompositionFullLifecycleGrantAcceptanceAuthority}
    {fullLifecycleNode :
      CompositionFullLifecycleGrantAuthorityBoundNode fullLifecycleAuthority}
    (_closed :
      CompositionCedarInputIdentityRefinementClosed
        identityAuthority fullLifecycleAuthority fullLifecycleNode) :
    fullLifecycleAuthority.accepted fullLifecycleNode.nodeBinding :=
  fullLifecycleGrantAuthorityBoundNodeAccepted fullLifecycleNode

theorem closedInputIdentityRefinementRejectsRequestMismatch
    {identityAuthority : CedarInputContentIdentityAuthority}
    {fullLifecycleAuthority :
      CompositionFullLifecycleGrantAcceptanceAuthority}
    {fullLifecycleNode :
      CompositionFullLifecycleGrantAuthorityBoundNode fullLifecycleAuthority}
    (closed :
      CompositionCedarInputIdentityRefinementClosed
        identityAuthority fullLifecycleAuthority fullLifecycleNode)
    (mismatch :
      fullLifecycleNode.nodeBinding.grant.authorizationSubject.requestDigest ≠
        identityAuthority.requestDigest
          fullLifecycleNode.nodeBinding.lifecycleEvidence.snapshot.request) :
    False :=
  mismatch closed.requestDigestBound

theorem closedInputIdentityRefinementRejectsPolicyMismatch
    {identityAuthority : CedarInputContentIdentityAuthority}
    {fullLifecycleAuthority :
      CompositionFullLifecycleGrantAcceptanceAuthority}
    {fullLifecycleNode :
      CompositionFullLifecycleGrantAuthorityBoundNode fullLifecycleAuthority}
    (closed :
      CompositionCedarInputIdentityRefinementClosed
        identityAuthority fullLifecycleAuthority fullLifecycleNode)
    (mismatch :
      fullLifecycleNode.nodeBinding.grant.authorizationSubject.policySetDigest ≠
        identityAuthority.policySetDigest
          fullLifecycleNode.nodeBinding.lifecycleEvidence.snapshot.policies) :
    False :=
  mismatch closed.policySetDigestBound

theorem closedInputIdentityRefinementRejectsBundleMismatch
    {identityAuthority : CedarInputContentIdentityAuthority}
    {fullLifecycleAuthority :
      CompositionFullLifecycleGrantAcceptanceAuthority}
    {fullLifecycleNode :
      CompositionFullLifecycleGrantAuthorityBoundNode fullLifecycleAuthority}
    (closed :
      CompositionCedarInputIdentityRefinementClosed
        identityAuthority fullLifecycleAuthority fullLifecycleNode)
    (mismatch :
      fullLifecycleNode.nodeBinding.grant.authorizationSubject.bundleDigest ≠
        identityAuthority.bundleDigest
          fullLifecycleNode.nodeBinding.lifecycleEvidence.snapshot.request
          fullLifecycleNode.nodeBinding.lifecycleEvidence.snapshot.entities
          fullLifecycleNode.nodeBinding.lifecycleEvidence.snapshot.policies) :
    False :=
  mismatch closed.bundleDigestBound

theorem equalAdmittedCedarRequestDigestIdentifiesExactRequest
    {identityAuthority : CedarInputContentIdentityAuthority}
    {left right : Cedar.Spec.Request}
    (leftAdmitted : identityAuthority.requestAdmitted left)
    (rightAdmitted : identityAuthority.requestAdmitted right)
    (sameDigest :
      identityAuthority.requestDigest left =
        identityAuthority.requestDigest right) :
    left = right :=
  identityAuthority.requestUniqueOnAdmitted
    left right leftAdmitted rightAdmitted sameDigest

end AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityRefinementClosure
