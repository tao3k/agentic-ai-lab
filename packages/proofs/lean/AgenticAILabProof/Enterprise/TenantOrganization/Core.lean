-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.TenantOrganization.Core

structure ScopeRelations
    (Organization Tenant Project Principal Resource Evidence : Type) where
  tenantInOrganization : Tenant → Organization → Prop
  projectInTenant : Project → Tenant → Prop
  principalInTenant : Principal → Tenant → Prop
  resourceInProject : Resource → Project → Prop
  scopeEvidence :
    Evidence →
      Organization → Tenant → Project → Principal → Resource → Prop

structure ScopeWitness
    (Organization Tenant Project Principal Resource Evidence : Type) where
  relations :
    ScopeRelations
      Organization Tenant Project Principal Resource Evidence
  organization : Organization
  tenant : Tenant
  project : Project
  principal : Principal
  resource : Resource
  evidence : Evidence
  tenantBelongsToOrganization :
    relations.tenantInOrganization tenant organization
  projectBelongsToTenant :
    relations.projectInTenant project tenant
  principalBelongsToTenant :
    relations.principalInTenant principal tenant
  resourceBelongsToProject :
    relations.resourceInProject resource project
  evidenceSupportsExactScope :
    relations.scopeEvidence
      evidence organization tenant project principal resource

theorem witnessCarriesCompleteScopeClosure
    {Organization Tenant Project Principal Resource Evidence : Type}
    (witness :
      ScopeWitness
        Organization Tenant Project Principal Resource Evidence) :
    witness.relations.tenantInOrganization
        witness.tenant witness.organization ∧
      witness.relations.projectInTenant
        witness.project witness.tenant ∧
      witness.relations.principalInTenant
        witness.principal witness.tenant ∧
      witness.relations.resourceInProject
        witness.resource witness.project :=
  ⟨witness.tenantBelongsToOrganization,
    witness.projectBelongsToTenant,
    witness.principalBelongsToTenant,
    witness.resourceBelongsToProject⟩

theorem witnessCarriesExactScopeEvidence
    {Organization Tenant Project Principal Resource Evidence : Type}
    (witness :
      ScopeWitness
        Organization Tenant Project Principal Resource Evidence) :
    witness.relations.scopeEvidence
      witness.evidence witness.organization witness.tenant witness.project
      witness.principal witness.resource :=
  witness.evidenceSupportsExactScope

end AgenticAILabProof.Enterprise.TenantOrganization.Core
