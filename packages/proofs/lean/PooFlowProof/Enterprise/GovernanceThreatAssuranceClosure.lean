-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import PooFlowProof.PooC4.GovernanceCore
import PooFlowCoreProof.PooC4.GovernanceDecisionAuthority
import PooFlowProof.Enterprise.AISecurityEmbodiedTypedRelationGraphClosure

/-!
Enterprise high-assurance closure for the POO Flow Governance core.

The enterprise layer composes core Governance admission with typed security
relations, threat-intelligence provenance, snapshot evidence and separation of
duties.  It does not redefine Cedar policy semantics or authorization results.
-/

namespace PooFlowProof.Enterprise.GovernanceThreatAssuranceClosure

open PooFlowProof.PooC4.GovernanceCore
open PooFlowProof.PooC4.GovernanceDecisionAuthority
open PooFlowProof.Enterprise.AISecurityEmbodiedTypedRelationGraphClosure

structure EnterpriseGovernanceAssurance (PrincipalIdentity : Type) where
  profile : GovernanceProfile
  assessment : GovernanceAssessment
  securityGraph : TypedRelationGraph
  threatIntelligenceIdentity : String
  evidenceSnapshotIdentity : String
  separation : SeparationOfDuties PrincipalIdentity
  governanceAdmitted : GovernanceAdmitted profile assessment
  providerHandoffEligible : ProviderHandoffEligible profile assessment
  securityGraphClosed : typedRelationGraphClosed securityGraph
  threatIntelligencePresent : threatIntelligenceIdentity ≠ ""
  evidenceSnapshotPresent : evidenceSnapshotIdentity ≠ ""

/- The composed receipt qualifies a Provider handoff; it never grants action. -/
def EnterpriseGovernanceEvidenceCarriesActionAuthority
    {PrincipalIdentity : Type}
    (_assurance : EnterpriseGovernanceAssurance PrincipalIdentity) : Prop :=
  False

theorem enterpriseGovernanceRequiresTypedSecurityGraph
    {PrincipalIdentity : Type}
    (assurance : EnterpriseGovernanceAssurance PrincipalIdentity) :
    typedRelationGraphClosed assurance.securityGraph :=
  assurance.securityGraphClosed

theorem enterpriseGovernanceRequiresThreatIntelligenceAndSnapshot
    {PrincipalIdentity : Type}
    (assurance : EnterpriseGovernanceAssurance PrincipalIdentity) :
    assurance.threatIntelligenceIdentity ≠ "" ∧
      assurance.evidenceSnapshotIdentity ≠ "" :=
  ⟨assurance.threatIntelligencePresent, assurance.evidenceSnapshotPresent⟩

theorem enterpriseGovernancePreservesSeparationOfDuties
    {PrincipalIdentity : Type}
    (assurance : EnterpriseGovernanceAssurance PrincipalIdentity) :
    assurance.separation.proposer ≠ assurance.separation.approver ∧
      assurance.separation.approver ≠ assurance.separation.executor :=
  ⟨assurance.separation.proposerNotApprover,
    assurance.separation.approverNotExecutor⟩

theorem enterpriseGovernanceNeverCarriesActionAuthority
    {PrincipalIdentity : Type}
    (assurance : EnterpriseGovernanceAssurance PrincipalIdentity) :
    ¬ EnterpriseGovernanceEvidenceCarriesActionAuthority assurance := by
  simp [EnterpriseGovernanceEvidenceCarriesActionAuthority]

theorem activeCriticalThreatPreventsEnterpriseAssurance
    {PrincipalIdentity : Type}
    (assurance : EnterpriseGovernanceAssurance PrincipalIdentity)
    (threat : Threat)
    (member : threat ∈ assurance.assessment.assessedThreats)
    (critical : threat.severity = .critical)
    (active : threat.phase = .exposed ∨ threat.phase = .realized) :
    False :=
  (activeCriticalThreatBlocksProviderHandoff
    assurance.profile assurance.assessment threat member critical active)
    assurance.providerHandoffEligible

end PooFlowProof.Enterprise.GovernanceThreatAssuranceClosure
