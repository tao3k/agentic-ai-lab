// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module HealthcareAIAssistedPrescriptionCausality {
  var phase: str
  var interactionEvidenceBound: bool
  var governanceHoldActive: bool
  var independentReviewRecorded: bool
  var alternativePrescriptionSelected: bool
  var pharmacyVerified: bool
  var wrongAutoApprovalCommitted: bool
  var wrongAdministrationCommitted: bool
  var hypothesizedRiskPromoted: bool
  var actionAuthority: bool
  val Phases = Set("AIRecommended", "InteractionFound", "GovernanceHold", "ClinicianReviewed", "AlternativeSelected", "PharmacyVerified", "CounterfactualModeled")
  action Init = all { phase' = "AIRecommended", interactionEvidenceBound' = false, governanceHoldActive' = false, independentReviewRecorded' = false, alternativePrescriptionSelected' = false, pharmacyVerified' = false, wrongAutoApprovalCommitted' = false, wrongAdministrationCommitted' = false, hypothesizedRiskPromoted' = false, actionAuthority' = false }
  action BindInteractionEvidence = all { phase == "AIRecommended", phase' = "InteractionFound", interactionEvidenceBound' = true, governanceHoldActive' = governanceHoldActive, independentReviewRecorded' = independentReviewRecorded, alternativePrescriptionSelected' = alternativePrescriptionSelected, pharmacyVerified' = pharmacyVerified, wrongAutoApprovalCommitted' = wrongAutoApprovalCommitted, wrongAdministrationCommitted' = wrongAdministrationCommitted, hypothesizedRiskPromoted' = hypothesizedRiskPromoted, actionAuthority' = actionAuthority }
  action ApplyGovernanceHold = all { phase == "InteractionFound", interactionEvidenceBound, phase' = "GovernanceHold", governanceHoldActive' = true, interactionEvidenceBound' = interactionEvidenceBound, independentReviewRecorded' = independentReviewRecorded, alternativePrescriptionSelected' = alternativePrescriptionSelected, pharmacyVerified' = pharmacyVerified, wrongAutoApprovalCommitted' = wrongAutoApprovalCommitted, wrongAdministrationCommitted' = wrongAdministrationCommitted, hypothesizedRiskPromoted' = hypothesizedRiskPromoted, actionAuthority' = actionAuthority }
  action RecordIndependentReview = all { phase == "GovernanceHold", governanceHoldActive, phase' = "ClinicianReviewed", independentReviewRecorded' = true, interactionEvidenceBound' = interactionEvidenceBound, governanceHoldActive' = governanceHoldActive, alternativePrescriptionSelected' = alternativePrescriptionSelected, pharmacyVerified' = pharmacyVerified, wrongAutoApprovalCommitted' = wrongAutoApprovalCommitted, wrongAdministrationCommitted' = wrongAdministrationCommitted, hypothesizedRiskPromoted' = hypothesizedRiskPromoted, actionAuthority' = actionAuthority }
  action SelectAlternative = all { phase == "ClinicianReviewed", independentReviewRecorded, phase' = "AlternativeSelected", alternativePrescriptionSelected' = true, interactionEvidenceBound' = interactionEvidenceBound, governanceHoldActive' = governanceHoldActive, independentReviewRecorded' = independentReviewRecorded, pharmacyVerified' = pharmacyVerified, wrongAutoApprovalCommitted' = wrongAutoApprovalCommitted, wrongAdministrationCommitted' = wrongAdministrationCommitted, hypothesizedRiskPromoted' = hypothesizedRiskPromoted, actionAuthority' = actionAuthority }
  action VerifyAlternative = all { phase == "AlternativeSelected", alternativePrescriptionSelected, phase' = "PharmacyVerified", pharmacyVerified' = true, interactionEvidenceBound' = interactionEvidenceBound, governanceHoldActive' = governanceHoldActive, independentReviewRecorded' = independentReviewRecorded, alternativePrescriptionSelected' = alternativePrescriptionSelected, wrongAutoApprovalCommitted' = wrongAutoApprovalCommitted, wrongAdministrationCommitted' = wrongAdministrationCommitted, hypothesizedRiskPromoted' = hypothesizedRiskPromoted, actionAuthority' = actionAuthority }
  action ModelWrongPath = all { interactionEvidenceBound, phase' = "CounterfactualModeled", wrongAutoApprovalCommitted' = false, wrongAdministrationCommitted' = false, hypothesizedRiskPromoted' = false, interactionEvidenceBound' = interactionEvidenceBound, governanceHoldActive' = governanceHoldActive, independentReviewRecorded' = independentReviewRecorded, alternativePrescriptionSelected' = alternativePrescriptionSelected, pharmacyVerified' = pharmacyVerified, actionAuthority' = actionAuthority }
  action step = any { BindInteractionEvidence , ApplyGovernanceHold , RecordIndependentReview , SelectAlternative , VerifyAlternative , ModelWrongPath }
  val TypeInvariant = Phases.contains(phase)  and  (interactionEvidenceBound == true or interactionEvidenceBound == false)  and  (governanceHoldActive == true or governanceHoldActive == false)  and  (independentReviewRecorded == true or independentReviewRecorded == false)  and  (alternativePrescriptionSelected == true or alternativePrescriptionSelected == false)  and  (pharmacyVerified == true or pharmacyVerified == false)  and  (wrongAutoApprovalCommitted == true or wrongAutoApprovalCommitted == false)  and  (wrongAdministrationCommitted == true or wrongAdministrationCommitted == false)  and  (hypothesizedRiskPromoted == true or hypothesizedRiskPromoted == false)  and  (actionAuthority == true or actionAuthority == false)
  val AlternativeRequiresIndependentReview = alternativePrescriptionSelected  implies  independentReviewRecorded
  val WrongAIPathNeverCommits = not(wrongAutoApprovalCommitted)  and  not(wrongAdministrationCommitted)
  val HypothesizedRiskNeverBecomesFact = not(hypothesizedRiskPromoted)
  val TemporalAssuranceNeverGrantsActionAuthority = not(actionAuthority)
  val IntendedTrajectoryReady = interactionEvidenceBound  and  governanceHoldActive  and  independentReviewRecorded  and  alternativePrescriptionSelected  and  pharmacyVerified
  val ErrorTrajectoryRemainsCounterfactual = not(wrongAutoApprovalCommitted)  and  not(wrongAdministrationCommitted)
  val ErrorImpactRemainsHypothesized = not(hypothesizedRiskPromoted)
  val TrajectoryHandoffReady = IntendedTrajectoryReady  and  ErrorTrajectoryRemainsCounterfactual  and  ErrorImpactRemainsHypothesized
  val TrajectoryHandoffRequiresIndependentReview = TrajectoryHandoffReady  implies  independentReviewRecorded
  val TrajectoryLayersNeverCollapse = ErrorTrajectoryRemainsCounterfactual  and  ErrorImpactRemainsHypothesized
  action init = Init
  val safety = and { TypeInvariant, AlternativeRequiresIndependentReview, WrongAIPathNeverCommits, HypothesizedRiskNeverBecomesFact, TemporalAssuranceNeverGrantsActionAuthority, TrajectoryHandoffRequiresIndependentReview, TrajectoryLayersNeverCollapse }
}
