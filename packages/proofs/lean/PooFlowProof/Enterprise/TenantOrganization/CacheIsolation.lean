-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import PooFlowCoreProof.PooC4.DistributedCacheAdmission

namespace PooFlowProof.Enterprise.TenantOrganization.CacheIsolation

structure KeyScheme (Tenant SemanticIdentity CacheKey : Type) where
  key : Tenant → SemanticIdentity → CacheKey
  tenantChangeChangesKey :
    ∀ tenantA tenantB semanticIdentity,
      tenantA ≠ tenantB →
        key tenantA semanticIdentity ≠
          key tenantB semanticIdentity

structure LocalAdmissionBoundary where
  tenantBoundKey : Prop
  provenanceTrusted : Prop
  freshnessHolds : Prop
  confidentialityAllowed : Prop
  notRevoked : Prop
  allChecks :
    tenantBoundKey ∧
      provenanceTrusted ∧
      freshnessHolds ∧
      confidentialityAllowed ∧
      notRevoked

theorem differentTenantsCannotAliasCacheKey
    {Tenant SemanticIdentity CacheKey : Type}
    (scheme : KeyScheme Tenant SemanticIdentity CacheKey)
    (tenantA tenantB : Tenant)
    (semanticIdentity : SemanticIdentity)
    (changed : tenantA ≠ tenantB) :
    scheme.key tenantA semanticIdentity ≠
      scheme.key tenantB semanticIdentity :=
  scheme.tenantChangeChangesKey tenantA tenantB semanticIdentity changed

theorem localCacheAdmissionRequiresIsolationChecks
    (boundary : LocalAdmissionBoundary) :
    boundary.tenantBoundKey ∧
      boundary.provenanceTrusted ∧
      boundary.freshnessHolds ∧
      boundary.confidentialityAllowed ∧
      boundary.notRevoked :=
  boundary.allChecks

end PooFlowProof.Enterprise.TenantOrganization.CacheIsolation
