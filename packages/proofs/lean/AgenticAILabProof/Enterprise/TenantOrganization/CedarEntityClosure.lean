-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.TenantOrganization.Core
import AgenticAILabProof.Enterprise.TenantOrganization.Identity
import AgenticAILabProof.PooC4.CedarAuthorizationSemantics
import AgenticAILabProof.PooC4.CedarResponseArbitrationBridge

namespace AgenticAILabProof.Enterprise.TenantOrganization.CedarEntityClosure

open AgenticAILabProof.PooC4

structure Checks where
  organizationEntityPresent : Prop
  tenantEntityPresent : Prop
  projectEntityPresent : Prop
  principalEntityPresent : Prop
  resourceEntityPresent : Prop
  requestPrincipalMatches : Prop
  requestResourceMatches : Prop
  policyScopeMatches : Prop
  entityStoreRevisionCurrent : Prop
  noUnexpectedCrossTenantEntity : Prop

def Hold (checks : Checks) : Prop :=
  checks.organizationEntityPresent ∧
    checks.tenantEntityPresent ∧
    checks.projectEntityPresent ∧
    checks.principalEntityPresent ∧
    checks.resourceEntityPresent ∧
    checks.requestPrincipalMatches ∧
    checks.requestResourceMatches ∧
    checks.policyScopeMatches ∧
    checks.entityStoreRevisionCurrent ∧
    checks.noUnexpectedCrossTenantEntity

structure CanonicalInputIdentityScheme
    (ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
      InputIdentity : Type) where
  identity :
    ScopedIdentity →
      RequestIdentity →
      EntityStoreIdentity →
      PolicySetIdentity →
      InputIdentity
  scopeChangeChangesInput :
    ∀ scopeA scopeB request entities policies,
      scopeA ≠ scopeB →
        identity scopeA request entities policies ≠
          identity scopeB request entities policies
  requestChangeChangesInput :
    ∀ scope requestA requestB entities policies,
      requestA ≠ requestB →
        identity scope requestA entities policies ≠
          identity scope requestB entities policies
  entityStoreChangeChangesInput :
    ∀ scope request entitiesA entitiesB policies,
      entitiesA ≠ entitiesB →
        identity scope request entitiesA policies ≠
          identity scope request entitiesB policies
  policySetChangeChangesInput :
    ∀ scope request entities policiesA policiesB,
      policiesA ≠ policiesB →
        identity scope request entities policiesA ≠
          identity scope request entities policiesB

structure Projection
    (Organization Tenant Project Principal Resource ScopeEvidence
      ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
      InputIdentity : Type) where
  scope :
    Core.ScopeWitness
      Organization Tenant Project Principal Resource ScopeEvidence
  cedarInput : CedarAuthorizationSemantics.CedarAuthorizationInput
  scopeIdentityScheme :
    Identity.Scheme
      Organization Tenant Project Resource ScopedIdentity
  canonicalInputIdentityScheme :
    CanonicalInputIdentityScheme
      ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
      InputIdentity
  requestIdentityProjection : Cedar.Spec.Request → RequestIdentity
  entityStoreIdentityProjection : Cedar.Spec.Entities → EntityStoreIdentity
  policySetIdentityProjection : Cedar.Spec.Policies → PolicySetIdentity
  scopedIdentity : ScopedIdentity
  requestIdentity : RequestIdentity
  entityStoreIdentity : EntityStoreIdentity
  policySetIdentity : PolicySetIdentity
  inputIdentity : InputIdentity
  scopedIdentityExact :
    scopedIdentity =
      scopeIdentityScheme.identity
        scope.organization scope.tenant scope.project scope.resource
  requestIdentityExact :
    requestIdentity = requestIdentityProjection cedarInput.request
  entityStoreIdentityExact :
    entityStoreIdentity =
      entityStoreIdentityProjection cedarInput.entities
  policySetIdentityExact :
    policySetIdentity = policySetIdentityProjection cedarInput.policies
  inputIdentityExact :
    inputIdentity =
      canonicalInputIdentityScheme.identity
        scopedIdentity requestIdentity entityStoreIdentity policySetIdentity
  checks : Checks
  checksHold : Hold checks

def Admitted
    {Organization Tenant Project Principal Resource ScopeEvidence
      ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
      InputIdentity : Type}
    (projection :
      Projection
        Organization Tenant Project Principal Resource ScopeEvidence
        ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
        InputIdentity) : Prop :=
  Hold projection.checks

theorem admittedProjectionCarriesCompleteEntityClosure
    {Organization Tenant Project Principal Resource ScopeEvidence
      ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
      InputIdentity : Type}
    (projection :
      Projection
        Organization Tenant Project Principal Resource ScopeEvidence
        ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
        InputIdentity)
    (admitted : Admitted projection) :
    projection.checks.organizationEntityPresent ∧
      projection.checks.tenantEntityPresent ∧
      projection.checks.projectEntityPresent ∧
      projection.checks.principalEntityPresent ∧
      projection.checks.resourceEntityPresent :=
  ⟨admitted.1, admitted.2.1, admitted.2.2.1,
    admitted.2.2.2.1, admitted.2.2.2.2.1⟩

theorem projectionBindsActualCedarInputToCanonicalIdentity
    {Organization Tenant Project Principal Resource ScopeEvidence
      ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
      InputIdentity : Type}
    (projection :
      Projection
        Organization Tenant Project Principal Resource ScopeEvidence
        ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
        InputIdentity) :
    projection.scopedIdentity =
        projection.scopeIdentityScheme.identity
          projection.scope.organization projection.scope.tenant
          projection.scope.project projection.scope.resource ∧
      projection.requestIdentity =
        projection.requestIdentityProjection
          projection.cedarInput.request ∧
      projection.entityStoreIdentity =
        projection.entityStoreIdentityProjection
          projection.cedarInput.entities ∧
      projection.policySetIdentity =
        projection.policySetIdentityProjection
          projection.cedarInput.policies ∧
      projection.inputIdentity =
        projection.canonicalInputIdentityScheme.identity
          projection.scopedIdentity projection.requestIdentity
          projection.entityStoreIdentity projection.policySetIdentity :=
  ⟨projection.scopedIdentityExact,
    projection.requestIdentityExact,
    projection.entityStoreIdentityExact,
    projection.policySetIdentityExact,
    projection.inputIdentityExact⟩

theorem admittedProjectionBindsRequestPolicyAndEntityRevision
    {Organization Tenant Project Principal Resource ScopeEvidence
      ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
      InputIdentity : Type}
    (projection :
      Projection
        Organization Tenant Project Principal Resource ScopeEvidence
        ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
        InputIdentity)
    (admitted : Admitted projection) :
    projection.checks.requestPrincipalMatches ∧
      projection.checks.requestResourceMatches ∧
      projection.checks.policyScopeMatches ∧
      projection.checks.entityStoreRevisionCurrent :=
  ⟨admitted.2.2.2.2.2.1,
    admitted.2.2.2.2.2.2.1,
    admitted.2.2.2.2.2.2.2.1,
    admitted.2.2.2.2.2.2.2.2.1⟩

theorem missingTenantEntityBlocksProjection
    (checks : Checks)
    (missing : ¬ checks.tenantEntityPresent) :
    ¬ Hold checks := by
  intro hold
  exact missing hold.2.1

theorem missingPrincipalEntityBlocksProjection
    (checks : Checks)
    (missing : ¬ checks.principalEntityPresent) :
    ¬ Hold checks := by
  intro hold
  exact missing hold.2.2.2.1

theorem missingResourceEntityBlocksProjection
    (checks : Checks)
    (missing : ¬ checks.resourceEntityPresent) :
    ¬ Hold checks := by
  intro hold
  exact missing hold.2.2.2.2.1

theorem staleEntityStoreBlocksProjection
    (checks : Checks)
    (stale : ¬ checks.entityStoreRevisionCurrent) :
    ¬ Hold checks := by
  intro hold
  exact stale hold.2.2.2.2.2.2.2.2.1

theorem unexpectedCrossTenantEntityBlocksProjection
    (checks : Checks)
    (unexpected : ¬ checks.noUnexpectedCrossTenantEntity) :
    ¬ Hold checks := by
  intro hold
  exact unexpected hold.2.2.2.2.2.2.2.2.2

theorem tenantChangeChangesCanonicalCedarInput
    {Organization Tenant Project Resource ScopedIdentity RequestIdentity
      EntityStoreIdentity PolicySetIdentity InputIdentity : Type}
    (scopeScheme :
      Identity.Scheme
        Organization Tenant Project Resource ScopedIdentity)
    (inputScheme :
      CanonicalInputIdentityScheme
        ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
        InputIdentity)
    (organization : Organization)
    (tenantA tenantB : Tenant)
    (project : Project)
    (resource : Resource)
    (request : RequestIdentity)
    (entities : EntityStoreIdentity)
    (policies : PolicySetIdentity)
    (changed : tenantA ≠ tenantB) :
    inputScheme.identity
        (scopeScheme.identity organization tenantA project resource)
        request entities policies ≠
      inputScheme.identity
        (scopeScheme.identity organization tenantB project resource)
        request entities policies := by
  apply inputScheme.scopeChangeChangesInput
  exact
    scopeScheme.tenantChangeChangesIdentity
      organization tenantA tenantB project resource changed

theorem entityStoreChangeChangesCanonicalCedarInput
    {ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
      InputIdentity : Type}
    (scheme :
      CanonicalInputIdentityScheme
        ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
        InputIdentity)
    (scope : ScopedIdentity)
    (request : RequestIdentity)
    (entitiesA entitiesB : EntityStoreIdentity)
    (policies : PolicySetIdentity)
    (changed : entitiesA ≠ entitiesB) :
    scheme.identity scope request entitiesA policies ≠
      scheme.identity scope request entitiesB policies :=
  scheme.entityStoreChangeChangesInput
    scope request entitiesA entitiesB policies changed

theorem cedarInputIdentityDisagreementFailsClosed
    {SemanticVersion InputIdentity : Type}
    [DecidableEq SemanticVersion]
    [DecidableEq InputIdentity]
    (semanticVersion : SemanticVersion)
    (leftInput rightInput : InputIdentity)
    (response : Cedar.Spec.Response)
    (different : leftInput ≠ rightInput) :
    CedarDualEngineArbitration.arbitrateStrict
        (.completed
          (CedarResponseArbitrationBridge.CedarComparableOutcome.mk
            semanticVersion leftInput response))
        (.completed
          (CedarResponseArbitrationBridge.CedarComparableOutcome.mk
            semanticVersion rightInput response)) =
      CedarDualEngineArbitration.failClosed
        .engineDisagreement :=
  AgenticAILabProof.PooC4.CedarResponseArbitrationBridge.input_identity_disagreement_fails_closed
    semanticVersion leftInput rightInput response different

end AgenticAILabProof.Enterprise.TenantOrganization.CedarEntityClosure
