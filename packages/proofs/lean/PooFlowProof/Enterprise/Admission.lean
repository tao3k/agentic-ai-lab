-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import PooFlowProof.Enterprise.Core
import PooFlowProof.Enterprise.EvidenceFreshness
import PooFlowProof.Enterprise.SeparationOfDuties

namespace PooFlowProof.Enterprise.Admission

structure Admitted
    (Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity : Type) [DecidableEq Principal] where
  context :
    Core.GovernanceContext
      Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity
  baseAdmission : Core.BaseAdmission context
  decisionKind :
    PooFlowCoreProof.Admission.Decision.GovernanceDecisionKind
  decisionMayRequestScopedCapability :
    PooFlowCoreProof.Admission.Decision.MayRequestScopedCapability decisionKind
  governanceChecks : PooFlowCoreProof.Admission.Decision.GovernanceChecks
  governanceChecksHold :
    PooFlowCoreProof.Admission.Decision.GovernanceChecksHold governanceChecks
  approval : SeparationOfDuties.ApprovalDiscipline Principal
  freshness : EvidenceFreshness.Checks
  freshnessHolds : EvidenceFreshness.Hold freshness

theorem requiresBaseAdmission
    {Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity : Type} [DecidableEq Principal]
    (admission :
      Admitted
        Principal Asset Action Responsibility Evidence FacetIdentity
        CoreContractIdentity) :
    Core.BaseAdmission admission.context :=
  admission.baseAdmission

theorem requiresEveryGovernanceCheck
    {Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity : Type} [DecidableEq Principal]
    (admission :
      Admitted
        Principal Asset Action Responsibility Evidence FacetIdentity
        CoreContractIdentity) :
    PooFlowCoreProof.Admission.Decision.GovernanceChecksHold
      admission.governanceChecks :=
  admission.governanceChecksHold

theorem requiresFreshEvidence
    {Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity : Type} [DecidableEq Principal]
    (admission :
      Admitted
        Principal Asset Action Responsibility Evidence FacetIdentity
        CoreContractIdentity) :
    EvidenceFreshness.Hold admission.freshness :=
  admission.freshnessHolds

theorem expiredDecisionCannotBeAdmitted
    {Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity : Type} [DecidableEq Principal]
    (admission :
      Admitted
        Principal Asset Action Responsibility Evidence FacetIdentity
        CoreContractIdentity)
    (expired : admission.decisionKind = .expired) :
    False := by
  have mayRequest := admission.decisionMayRequestScopedCapability
  rw [expired] at mayRequest
  exact
    PooFlowCoreProof.Admission.Decision.expiredDecisionFailsClosed
      mayRequest

theorem revokedDecisionCannotBeAdmitted
    {Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity : Type} [DecidableEq Principal]
    (admission :
      Admitted
        Principal Asset Action Responsibility Evidence FacetIdentity
        CoreContractIdentity)
    (revoked : admission.decisionKind = .revoked) :
    False := by
  have mayRequest := admission.decisionMayRequestScopedCapability
  rw [revoked] at mayRequest
  exact
    PooFlowCoreProof.Admission.Decision.revokedDecisionFailsClosed
      mayRequest

end PooFlowProof.Enterprise.Admission
