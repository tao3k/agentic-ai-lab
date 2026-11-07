-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.Admission
import AgenticAILabProof.Enterprise.TenantOrganization.Core
import AgenticAILabProof.Enterprise.TenantOrganization.CacheIsolation
import AgenticAILabProof.Enterprise.TenantOrganization.EvidenceVisibility

namespace AgenticAILabProof.Enterprise.TenantOrganization.Admission

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

end AgenticAILabProof.Enterprise.TenantOrganization.Admission
