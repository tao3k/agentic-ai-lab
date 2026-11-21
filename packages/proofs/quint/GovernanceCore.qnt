// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module GovernanceCore {
  var threatPhase: str
  var preconditionObserved: bool
  var evidenceBound: bool
  var assessmentBound: bool
  var governanceAdmitted: bool
  var threatIntelligenceBound: bool
  var securityGraphClosed: bool
  var separationOfDuties: bool
  var enterpriseAssuranceBound: bool
  var providerBound: bool
  var residualAccepted: bool
  var actionAuthority: bool
  val ThreatPhases = Set("latent", "exposed", "realized", "mitigated", "accepted")
  val ActiveBlocker = Set("exposed", "realized").contains(threatPhase)
  action Init = all { threatPhase' = "latent", preconditionObserved' = false, evidenceBound' = false, assessmentBound' = false, governanceAdmitted' = false, threatIntelligenceBound' = false, securityGraphClosed' = false, separationOfDuties' = false, enterpriseAssuranceBound' = false, providerBound' = false, residualAccepted' = false, actionAuthority' = false }
  action ObservePrecondition = all { preconditionObserved' = true, evidenceBound' = true, threatPhase' = threatPhase, assessmentBound' = assessmentBound, governanceAdmitted' = governanceAdmitted, threatIntelligenceBound' = threatIntelligenceBound, securityGraphClosed' = securityGraphClosed, separationOfDuties' = separationOfDuties, enterpriseAssuranceBound' = enterpriseAssuranceBound, providerBound' = providerBound, residualAccepted' = residualAccepted, actionAuthority' = actionAuthority }
  action ExposeThreat = all { preconditionObserved, evidenceBound, threatPhase' = "exposed", assessmentBound' = false, governanceAdmitted' = false, enterpriseAssuranceBound' = false, providerBound' = false, preconditionObserved' = preconditionObserved, evidenceBound' = evidenceBound, threatIntelligenceBound' = threatIntelligenceBound, securityGraphClosed' = securityGraphClosed, separationOfDuties' = separationOfDuties, residualAccepted' = residualAccepted, actionAuthority' = actionAuthority }
  action RealizeThreat = all { threatPhase == "exposed", threatPhase' = "realized", assessmentBound' = false, governanceAdmitted' = false, enterpriseAssuranceBound' = false, providerBound' = false, preconditionObserved' = preconditionObserved, evidenceBound' = evidenceBound, threatIntelligenceBound' = threatIntelligenceBound, securityGraphClosed' = securityGraphClosed, separationOfDuties' = separationOfDuties, residualAccepted' = residualAccepted, actionAuthority' = actionAuthority }
  action MitigateThreat = all { Set("exposed", "realized").contains(threatPhase), threatPhase' = "mitigated", assessmentBound' = false, governanceAdmitted' = false, enterpriseAssuranceBound' = false, providerBound' = false, preconditionObserved' = preconditionObserved, evidenceBound' = evidenceBound, threatIntelligenceBound' = threatIntelligenceBound, securityGraphClosed' = securityGraphClosed, separationOfDuties' = separationOfDuties, residualAccepted' = residualAccepted, actionAuthority' = actionAuthority }
  action AcceptResidualThreat = all { threatPhase == "realized", evidenceBound, threatPhase' = "accepted", residualAccepted' = true, assessmentBound' = false, governanceAdmitted' = false, enterpriseAssuranceBound' = false, providerBound' = false, preconditionObserved' = preconditionObserved, evidenceBound' = evidenceBound, threatIntelligenceBound' = threatIntelligenceBound, securityGraphClosed' = securityGraphClosed, separationOfDuties' = separationOfDuties, actionAuthority' = actionAuthority }
  action AssessGovernance = all { not(ActiveBlocker), assessmentBound' = true, threatPhase' = threatPhase, preconditionObserved' = preconditionObserved, evidenceBound' = evidenceBound, governanceAdmitted' = governanceAdmitted, threatIntelligenceBound' = threatIntelligenceBound, securityGraphClosed' = securityGraphClosed, separationOfDuties' = separationOfDuties, enterpriseAssuranceBound' = enterpriseAssuranceBound, providerBound' = providerBound, residualAccepted' = residualAccepted, actionAuthority' = actionAuthority }
  action AdmitGovernance = all { assessmentBound, not(ActiveBlocker), governanceAdmitted' = true, threatPhase' = threatPhase, preconditionObserved' = preconditionObserved, evidenceBound' = evidenceBound, assessmentBound' = assessmentBound, threatIntelligenceBound' = threatIntelligenceBound, securityGraphClosed' = securityGraphClosed, separationOfDuties' = separationOfDuties, enterpriseAssuranceBound' = enterpriseAssuranceBound, providerBound' = providerBound, residualAccepted' = residualAccepted, actionAuthority' = actionAuthority }
  action BindEnterpriseEvidence = all { governanceAdmitted, assessmentBound, not(ActiveBlocker), threatIntelligenceBound' = true, securityGraphClosed' = true, separationOfDuties' = true, enterpriseAssuranceBound' = true, threatPhase' = threatPhase, preconditionObserved' = preconditionObserved, evidenceBound' = evidenceBound, assessmentBound' = assessmentBound, governanceAdmitted' = governanceAdmitted, providerBound' = providerBound, residualAccepted' = residualAccepted, actionAuthority' = actionAuthority }
  action BindProvider = all { governanceAdmitted, assessmentBound, enterpriseAssuranceBound, threatIntelligenceBound, securityGraphClosed, separationOfDuties, not(ActiveBlocker), providerBound' = true, threatPhase' = threatPhase, preconditionObserved' = preconditionObserved, evidenceBound' = evidenceBound, assessmentBound' = assessmentBound, governanceAdmitted' = governanceAdmitted, threatIntelligenceBound' = threatIntelligenceBound, securityGraphClosed' = securityGraphClosed, separationOfDuties' = separationOfDuties, enterpriseAssuranceBound' = enterpriseAssuranceBound, residualAccepted' = residualAccepted, actionAuthority' = actionAuthority }
  action step = any { ObservePrecondition , ExposeThreat , RealizeThreat , MitigateThreat , AcceptResidualThreat , AssessGovernance , AdmitGovernance , BindEnterpriseEvidence , BindProvider }
  val TypeInvariant = ThreatPhases.contains(threatPhase)
  val ObservedPreconditionHasEvidence = preconditionObserved  implies  evidenceBound
  val EnterpriseAssuranceIsClosed = enterpriseAssuranceBound  implies  threatIntelligenceBound  and  securityGraphClosed  and  separationOfDuties
  val ProviderHandoffIsFailClosed = providerBound  implies  assessmentBound  and  governanceAdmitted  and  enterpriseAssuranceBound  and  not(ActiveBlocker)
  val AcceptedResidualHasAuthorityEvidence = threatPhase == "accepted"  implies  residualAccepted  and  evidenceBound
  val GovernanceNeverGrantsActionAuthority = not(actionAuthority)
  action init = Init
  val safety = and { TypeInvariant, ObservedPreconditionHasEvidence, EnterpriseAssuranceIsClosed, ProviderHandoffIsFailClosed, AcceptedResidualHasAuthorityEvidence, GovernanceNeverGrantsActionAuthority }
}
