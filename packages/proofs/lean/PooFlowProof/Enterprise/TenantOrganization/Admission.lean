-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import PooFlowProof.Enterprise.Admission
import PooFlowProof.Enterprise.TenantOrganization.Core
import PooFlowProof.Enterprise.TenantOrganization.CacheIsolation
import PooFlowProof.Enterprise.TenantOrganization.EvidenceVisibility

namespace PooFlowProof.Enterprise.TenantOrganization.Admission

structure Checks where
  organizationScopeMatches : Prop
  tenantScopeMatches : Prop
  projectScopeMatches : Prop
  principalScopeMatches : Prop
  resourceScopeMatches : Prop
  policyScopeMatches : Prop
  cacheIdentityTenantBound : Prop
  evidenceVisibilityAllowed : Prop
  crossTenant : Prop
  federationAdmitted : Prop
  crossTenantRequiresFederation :
    crossTenant → federationAdmitted

def Hold (checks : Checks) : Prop :=
  checks.organizationScopeMatches ∧
    checks.tenantScopeMatches ∧
    checks.projectScopeMatches ∧
    checks.principalScopeMatches ∧
    checks.resourceScopeMatches ∧
    checks.policyScopeMatches ∧
    checks.cacheIdentityTenantBound ∧
    checks.evidenceVisibilityAllowed ∧
    (checks.crossTenant → checks.federationAdmitted)

structure Scoped
    (Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity Organization Tenant Project Resource
      ScopeEvidence : Type) [DecidableEq Principal] where
  enterprise :
    Enterprise.Admission.Admitted
      Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity
  scope :
    Core.ScopeWitness
      Organization Tenant Project Principal Resource ScopeEvidence
  checks : Checks
  checksHold : Hold checks

def enterpriseAdmission
    {Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity Organization Tenant Project Resource
      ScopeEvidence : Type} [DecidableEq Principal]
    (admission :
      Scoped
        Principal Asset Action Responsibility Evidence FacetIdentity
        CoreContractIdentity Organization Tenant Project Resource
        ScopeEvidence) :
    Enterprise.Admission.Admitted
      Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity :=
  admission.enterprise

theorem scopedAdmissionRequiresEnterpriseBase
    {Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity Organization Tenant Project Resource
      ScopeEvidence : Type} [DecidableEq Principal]
    (admission :
      Scoped
        Principal Asset Action Responsibility Evidence FacetIdentity
        CoreContractIdentity Organization Tenant Project Resource
        ScopeEvidence) :
    Enterprise.Core.BaseAdmission admission.enterprise.context :=
  admission.enterprise.baseAdmission

theorem scopedAdmissionRequiresAllIsolationChecks
    {Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity Organization Tenant Project Resource
      ScopeEvidence : Type} [DecidableEq Principal]
    (admission :
      Scoped
        Principal Asset Action Responsibility Evidence FacetIdentity
        CoreContractIdentity Organization Tenant Project Resource
        ScopeEvidence) :
    Hold admission.checks :=
  admission.checksHold

theorem crossTenantAdmissionRequiresFederation
    (checks : Checks)
    (hold : Hold checks)
    (crossTenant : checks.crossTenant) :
    checks.federationAdmitted :=
  hold.2.2.2.2.2.2.2.2 crossTenant

theorem tenantMismatchBlocksAdmission
    (checks : Checks)
    (mismatch : ¬ checks.tenantScopeMatches) :
    ¬ Hold checks := by
  intro hold
  exact mismatch hold.2.1

theorem cacheWithoutTenantBindingBlocksAdmission
    (checks : Checks)
    (unbound : ¬ checks.cacheIdentityTenantBound) :
    ¬ Hold checks := by
  intro hold
  exact unbound hold.2.2.2.2.2.2.1

end PooFlowProof.Enterprise.TenantOrganization.Admission
