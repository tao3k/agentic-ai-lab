-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.TenantOrganization.Identity

structure Scheme
    (Organization Tenant Project Resource ScopedIdentity : Type) where
  identity :
    Organization → Tenant → Project → Resource → ScopedIdentity
  organizationChangeChangesIdentity :
    ∀ organizationA organizationB tenant project resource,
      organizationA ≠ organizationB →
        identity organizationA tenant project resource ≠
          identity organizationB tenant project resource
  tenantChangeChangesIdentity :
    ∀ organization tenantA tenantB project resource,
      tenantA ≠ tenantB →
        identity organization tenantA project resource ≠
          identity organization tenantB project resource
  projectChangeChangesIdentity :
    ∀ organization tenant projectA projectB resource,
      projectA ≠ projectB →
        identity organization tenant projectA resource ≠
          identity organization tenant projectB resource
  resourceChangeChangesIdentity :
    ∀ organization tenant project resourceA resourceB,
      resourceA ≠ resourceB →
        identity organization tenant project resourceA ≠
          identity organization tenant project resourceB

theorem tenantChangeCannotAliasScopedIdentity
    {Organization Tenant Project Resource ScopedIdentity : Type}
    (scheme :
      Scheme Organization Tenant Project Resource ScopedIdentity)
    (organization : Organization)
    (tenantA tenantB : Tenant)
    (project : Project)
    (resource : Resource)
    (changed : tenantA ≠ tenantB) :
    scheme.identity organization tenantA project resource ≠
      scheme.identity organization tenantB project resource :=
  scheme.tenantChangeChangesIdentity
    organization tenantA tenantB project resource changed

theorem organizationChangeCannotAliasScopedIdentity
    {Organization Tenant Project Resource ScopedIdentity : Type}
    (scheme :
      Scheme Organization Tenant Project Resource ScopedIdentity)
    (organizationA organizationB : Organization)
    (tenant : Tenant)
    (project : Project)
    (resource : Resource)
    (changed : organizationA ≠ organizationB) :
    scheme.identity organizationA tenant project resource ≠
      scheme.identity organizationB tenant project resource :=
  scheme.organizationChangeChangesIdentity
    organizationA organizationB tenant project resource changed

end AgenticAILabProof.Enterprise.TenantOrganization.Identity
