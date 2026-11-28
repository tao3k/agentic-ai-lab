-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.TenantOrganization.CedarEntityClosure
import AgenticAILabProof.PooC4.CedarAdapterContract

namespace AgenticAILabProof.Enterprise.TenantOrganization.CedarAdapterRefinement

open AgenticAILabProof.PooC4
open AgenticAILabProof.PooC4.CedarAdapterContract
open AgenticAILabProof.PooC4.CedarResponseArbitrationBridge
open AgenticAILabProof.PooC4.CedarDualEngineArbitration

structure Admission
    {RawResponse ExecutableDigest SemanticVersion InputIdentity
      Organization Tenant Project Principal Resource ScopeEvidence
      ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity :
      Type}
    (entityProjection :
      CedarEntityClosure.Projection
        Organization Tenant Project Principal Resource ScopeEvidence
        ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
        InputIdentity)
    (adapterProjection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity)
    (raw : RawResponse)
    (expected :
      CedarComparableOutcome SemanticVersion InputIdentity)
    (receipt :
      CedarAdapterReceipt
        ExecutableDigest SemanticVersion InputIdentity) : Prop where
  entityClosureAdmitted :
    CedarEntityClosure.Admitted entityProjection
  expectedInputExact :
    expected.inputIdentity = entityProjection.inputIdentity
  expectedResponseExact :
    expected.response =
      CedarAuthorizationSemantics.authorize entityProjection.cedarInput
  adapterAdmitted :
    CedarAdapterAdmission
      adapterProjection raw expected receipt

theorem requiresAdmittedEntityClosure
    {RawResponse ExecutableDigest SemanticVersion InputIdentity
      Organization Tenant Project Principal Resource ScopeEvidence
      ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity :
      Type}
    {entityProjection :
      CedarEntityClosure.Projection
        Organization Tenant Project Principal Resource ScopeEvidence
        ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
        InputIdentity}
    {adapterProjection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity}
    {raw : RawResponse}
    {expected :
      CedarComparableOutcome SemanticVersion InputIdentity}
    {receipt :
      CedarAdapterReceipt
        ExecutableDigest SemanticVersion InputIdentity}
    (admission :
      Admission
        entityProjection adapterProjection raw expected receipt) :
    CedarEntityClosure.Admitted entityProjection :=
  admission.entityClosureAdmitted

theorem expectedOutcomeUsesCanonicalTenantInput
    {RawResponse ExecutableDigest SemanticVersion InputIdentity
      Organization Tenant Project Principal Resource ScopeEvidence
      ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity :
      Type}
    {entityProjection :
      CedarEntityClosure.Projection
        Organization Tenant Project Principal Resource ScopeEvidence
        ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
        InputIdentity}
    {adapterProjection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity}
    {raw : RawResponse}
    {expected :
      CedarComparableOutcome SemanticVersion InputIdentity}
    {receipt :
      CedarAdapterReceipt
        ExecutableDigest SemanticVersion InputIdentity}
    (admission :
      Admission
        entityProjection adapterProjection raw expected receipt) :
    expected.inputIdentity = entityProjection.inputIdentity :=
  admission.expectedInputExact

theorem expectedOutcomeUsesFullDefinitionalResponse
    {RawResponse ExecutableDigest SemanticVersion InputIdentity
      Organization Tenant Project Principal Resource ScopeEvidence
      ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity :
      Type}
    {entityProjection :
      CedarEntityClosure.Projection
        Organization Tenant Project Principal Resource ScopeEvidence
        ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
        InputIdentity}
    {adapterProjection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity}
    {raw : RawResponse}
    {expected :
      CedarComparableOutcome SemanticVersion InputIdentity}
    {receipt :
      CedarAdapterReceipt
        ExecutableDigest SemanticVersion InputIdentity}
    (admission :
      Admission
        entityProjection adapterProjection raw expected receipt) :
    expected.response =
      CedarAuthorizationSemantics.authorize entityProjection.cedarInput :=
  admission.expectedResponseExact

theorem receiptUsesCanonicalTenantInput
    {RawResponse ExecutableDigest SemanticVersion InputIdentity
      Organization Tenant Project Principal Resource ScopeEvidence
      ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity :
      Type}
    {entityProjection :
      CedarEntityClosure.Projection
        Organization Tenant Project Principal Resource ScopeEvidence
        ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
        InputIdentity}
    {adapterProjection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity}
    {raw : RawResponse}
    {expected :
      CedarComparableOutcome SemanticVersion InputIdentity}
    {receipt :
      CedarAdapterReceipt
        ExecutableDigest SemanticVersion InputIdentity}
    (admission :
      Admission
        entityProjection adapterProjection raw expected receipt) :
    receipt.inputIdentity = entityProjection.inputIdentity := by
  have comparableExact :
      receiptComparable receipt = expected :=
    admission.adapterAdmitted.receiptExact
  calc
    receipt.inputIdentity =
        (receiptComparable receipt).inputIdentity := rfl
    _ = expected.inputIdentity :=
      congrArg CedarComparableOutcome.inputIdentity comparableExact
    _ = entityProjection.inputIdentity :=
      admission.expectedInputExact

theorem receiptUsesFullDefinitionalResponse
    {RawResponse ExecutableDigest SemanticVersion InputIdentity
      Organization Tenant Project Principal Resource ScopeEvidence
      ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity :
      Type}
    {entityProjection :
      CedarEntityClosure.Projection
        Organization Tenant Project Principal Resource ScopeEvidence
        ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
        InputIdentity}
    {adapterProjection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity}
    {raw : RawResponse}
    {expected :
      CedarComparableOutcome SemanticVersion InputIdentity}
    {receipt :
      CedarAdapterReceipt
        ExecutableDigest SemanticVersion InputIdentity}
    (admission :
      Admission
        entityProjection adapterProjection raw expected receipt) :
    receipt.response =
      CedarAuthorizationSemantics.authorize entityProjection.cedarInput := by
  have comparableExact :
      receiptComparable receipt = expected :=
    admission.adapterAdmitted.receiptExact
  calc
    receipt.response =
        (receiptComparable receipt).response := rfl
    _ = expected.response :=
      congrArg CedarComparableOutcome.response comparableExact
    _ = CedarAuthorizationSemantics.authorize
          entityProjection.cedarInput :=
      admission.expectedResponseExact

theorem receiptCarriesExecutableDigest
    {RawResponse ExecutableDigest SemanticVersion InputIdentity
      Organization Tenant Project Principal Resource ScopeEvidence
      ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity :
      Type}
    {entityProjection :
      CedarEntityClosure.Projection
        Organization Tenant Project Principal Resource ScopeEvidence
        ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
        InputIdentity}
    {adapterProjection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity}
    {raw : RawResponse}
    {expected :
      CedarComparableOutcome SemanticVersion InputIdentity}
    {receipt :
      CedarAdapterReceipt
        ExecutableDigest SemanticVersion InputIdentity}
    (admission :
      Admission
        entityProjection adapterProjection raw expected receipt) :
    ∃ digest, receipt.executableDigest = some digest :=
  admission.adapterAdmitted.executableDigestPresent

theorem admittedTenantAdapterYieldsDualWitness
    {RawResponse ExecutableDigest SemanticVersion InputIdentity
      Organization Tenant Project Principal Resource ScopeEvidence
      ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity :
      Type}
    [DecidableEq SemanticVersion]
    [DecidableEq InputIdentity]
    {entityProjection :
      CedarEntityClosure.Projection
        Organization Tenant Project Principal Resource ScopeEvidence
        ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
        InputIdentity}
    {adapterProjection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity}
    {raw : RawResponse}
    {expected :
      CedarComparableOutcome SemanticVersion InputIdentity}
    {receipt :
      CedarAdapterReceipt
        ExecutableDigest SemanticVersion InputIdentity}
    (admission :
      Admission
        entityProjection adapterProjection raw expected receipt) :
    arbitrateStrict
        (.completed expected)
        (.completed (adapterProjection.project raw)) =
      projectOutcome .dualWitnessed true .agreed expected :=
  admitted_adapter_yields_dual_witness admission.adapterAdmitted

theorem missingEntityClosureBlocksTenantAdapter
    {RawResponse ExecutableDigest SemanticVersion InputIdentity
      Organization Tenant Project Principal Resource ScopeEvidence
      ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity :
      Type}
    (entityProjection :
      CedarEntityClosure.Projection
        Organization Tenant Project Principal Resource ScopeEvidence
        ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
        InputIdentity)
    (adapterProjection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity)
    (raw : RawResponse)
    (expected :
      CedarComparableOutcome SemanticVersion InputIdentity)
    (receipt :
      CedarAdapterReceipt
        ExecutableDigest SemanticVersion InputIdentity)
    (missing : ¬ CedarEntityClosure.Admitted entityProjection) :
    ¬ Admission
      entityProjection adapterProjection raw expected receipt := by
  intro admission
  exact missing admission.entityClosureAdmitted

theorem expectedInputMismatchBlocksTenantAdapter
    {RawResponse ExecutableDigest SemanticVersion InputIdentity
      Organization Tenant Project Principal Resource ScopeEvidence
      ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity :
      Type}
    (entityProjection :
      CedarEntityClosure.Projection
        Organization Tenant Project Principal Resource ScopeEvidence
        ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
        InputIdentity)
    (adapterProjection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity)
    (raw : RawResponse)
    (expected :
      CedarComparableOutcome SemanticVersion InputIdentity)
    (receipt :
      CedarAdapterReceipt
        ExecutableDigest SemanticVersion InputIdentity)
    (different :
      expected.inputIdentity ≠ entityProjection.inputIdentity) :
    ¬ Admission
      entityProjection adapterProjection raw expected receipt := by
  intro admission
  exact different admission.expectedInputExact

theorem expectedResponseMismatchBlocksTenantAdapter
    {RawResponse ExecutableDigest SemanticVersion InputIdentity
      Organization Tenant Project Principal Resource ScopeEvidence
      ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity :
      Type}
    (entityProjection :
      CedarEntityClosure.Projection
        Organization Tenant Project Principal Resource ScopeEvidence
        ScopedIdentity RequestIdentity EntityStoreIdentity PolicySetIdentity
        InputIdentity)
    (adapterProjection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity)
    (raw : RawResponse)
    (expected :
      CedarComparableOutcome SemanticVersion InputIdentity)
    (receipt :
      CedarAdapterReceipt
        ExecutableDigest SemanticVersion InputIdentity)
    (different :
      expected.response ≠
        CedarAuthorizationSemantics.authorize
          entityProjection.cedarInput) :
    ¬ Admission
      entityProjection adapterProjection raw expected receipt := by
  intro admission
  exact different admission.expectedResponseExact

end AgenticAILabProof.Enterprise.TenantOrganization.CedarAdapterRefinement
