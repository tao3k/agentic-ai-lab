-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.Core
import AgenticAILabProof.Enterprise.EvidenceFreshness
import AgenticAILabProof.Enterprise.SeparationOfDuties

namespace AgenticAILabProof.Enterprise.Admission

structure Admitted
    (Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity : Type) [DecidableEq Principal] where
  context :
    Core.GovernanceContext
      Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity
  baseAdmission : Core.BaseAdmission context
  decisionKind :
    YuanxuProof.Admission.Decision.GovernanceDecisionKind
  decisionMayRequestScopedCapability :
    YuanxuProof.Admission.Decision.MayRequestScopedCapability decisionKind
  governanceChecks : YuanxuProof.Admission.Decision.GovernanceChecks
  governanceChecksHold :
    YuanxuProof.Admission.Decision.GovernanceChecksHold governanceChecks
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
    YuanxuProof.Admission.Decision.GovernanceChecksHold
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
    YuanxuProof.Admission.Decision.expiredDecisionFailsClosed
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
    YuanxuProof.Admission.Decision.revokedDecisionFailsClosed
      mayRequest

end AgenticAILabProof.Enterprise.Admission
