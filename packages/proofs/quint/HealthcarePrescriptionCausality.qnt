// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module HealthcarePrescriptionCausality {
  var phase: str
  var oldOrderActive: bool
  var pastAdministrationRecorded: bool
  var errorDiscovered: bool
  var postDiscoveryOldOrderCommit: bool
  var reassessmentRequired: bool
  var reassessed: bool
  var correctionIssued: bool
  var correctionHasNewIdentity: bool
  var counterfactualObserved: bool
  var actionAuthority: bool
  val Phases = Set("Ordered", "Administered", "ErrorDiscovered", "OldOrderBlocked", "Reassessed", "CounterfactualModeled", "Corrected")
  action Init = all { phase' = "Ordered", oldOrderActive' = true, pastAdministrationRecorded' = false, errorDiscovered' = false, postDiscoveryOldOrderCommit' = false, reassessmentRequired' = false, reassessed' = false, correctionIssued' = false, correctionHasNewIdentity' = false, counterfactualObserved' = false, actionAuthority' = false }
  action AdministerBeforeDiscovery = all { not(errorDiscovered), oldOrderActive, Set("Ordered", "Administered").contains(phase), phase' = "Administered", pastAdministrationRecorded' = true, oldOrderActive' = oldOrderActive, errorDiscovered' = errorDiscovered, postDiscoveryOldOrderCommit' = postDiscoveryOldOrderCommit, reassessmentRequired' = reassessmentRequired, reassessed' = reassessed, correctionIssued' = correctionIssued, correctionHasNewIdentity' = correctionHasNewIdentity, counterfactualObserved' = counterfactualObserved, actionAuthority' = actionAuthority }
  action DiscoverPrescriptionError = all { not(errorDiscovered), phase' = "ErrorDiscovered", errorDiscovered' = true, oldOrderActive' = false, reassessmentRequired' = true, pastAdministrationRecorded' = pastAdministrationRecorded, postDiscoveryOldOrderCommit' = postDiscoveryOldOrderCommit, reassessed' = reassessed, correctionIssued' = correctionIssued, correctionHasNewIdentity' = correctionHasNewIdentity, counterfactualObserved' = counterfactualObserved, actionAuthority' = actionAuthority }
  action BlockOldOrderAdministration = all { errorDiscovered, not(oldOrderActive), phase' = "OldOrderBlocked", postDiscoveryOldOrderCommit' = false, oldOrderActive' = oldOrderActive, pastAdministrationRecorded' = pastAdministrationRecorded, errorDiscovered' = errorDiscovered, reassessmentRequired' = reassessmentRequired, reassessed' = reassessed, correctionIssued' = correctionIssued, correctionHasNewIdentity' = correctionHasNewIdentity, counterfactualObserved' = counterfactualObserved, actionAuthority' = actionAuthority }
  action ReassessPatient = all { errorDiscovered, reassessmentRequired, phase' = "Reassessed", reassessed' = true, oldOrderActive' = oldOrderActive, pastAdministrationRecorded' = pastAdministrationRecorded, errorDiscovered' = errorDiscovered, postDiscoveryOldOrderCommit' = postDiscoveryOldOrderCommit, reassessmentRequired' = reassessmentRequired, correctionIssued' = correctionIssued, correctionHasNewIdentity' = correctionHasNewIdentity, counterfactualObserved' = counterfactualObserved, actionAuthority' = actionAuthority }
  action ModelCounterfactual = all { errorDiscovered, phase' = "CounterfactualModeled", counterfactualObserved' = false, oldOrderActive' = oldOrderActive, pastAdministrationRecorded' = pastAdministrationRecorded, errorDiscovered' = errorDiscovered, postDiscoveryOldOrderCommit' = postDiscoveryOldOrderCommit, reassessmentRequired' = reassessmentRequired, reassessed' = reassessed, correctionIssued' = correctionIssued, correctionHasNewIdentity' = correctionHasNewIdentity, actionAuthority' = actionAuthority }
  action IssueCorrection = all { errorDiscovered, reassessed, phase' = "Corrected", correctionIssued' = true, correctionHasNewIdentity' = true, oldOrderActive' = oldOrderActive, pastAdministrationRecorded' = pastAdministrationRecorded, errorDiscovered' = errorDiscovered, postDiscoveryOldOrderCommit' = postDiscoveryOldOrderCommit, reassessmentRequired' = reassessmentRequired, reassessed' = reassessed, counterfactualObserved' = counterfactualObserved, actionAuthority' = actionAuthority }
  action step = any { AdministerBeforeDiscovery , DiscoverPrescriptionError , BlockOldOrderAdministration , ReassessPatient , ModelCounterfactual , IssueCorrection }
  val TypeInvariant = Phases.contains(phase)  and  (oldOrderActive == true or oldOrderActive == false)  and  (pastAdministrationRecorded == true or pastAdministrationRecorded == false)  and  (errorDiscovered == true or errorDiscovered == false)  and  (postDiscoveryOldOrderCommit == true or postDiscoveryOldOrderCommit == false)  and  (reassessmentRequired == true or reassessmentRequired == false)  and  (reassessed == true or reassessed == false)  and  (correctionIssued == true or correctionIssued == false)  and  (correctionHasNewIdentity == true or correctionHasNewIdentity == false)  and  (counterfactualObserved == true or counterfactualObserved == false)  and  (actionAuthority == true or actionAuthority == false)
  val DiscoveryRevokesOldOrder = errorDiscovered  implies  not(oldOrderActive)
  val NoOldOrderCommitAfterDiscovery = errorDiscovered  implies  not(postDiscoveryOldOrderCommit)
  val CorrectionRequiresReassessmentAndNewIdentity = correctionIssued  implies  reassessed  and  correctionHasNewIdentity
  val CounterfactualNeverBecomesObservedFact = not(counterfactualObserved)
  val TemporalAnalysisNeverGrantsActionAuthority = not(actionAuthority)
  action init = Init
  val safety = and { TypeInvariant, DiscoveryRevokesOldOrder, NoOldOrderCommitAfterDiscovery, CorrectionRequiresReassessmentAndNewIdentity, CounterfactualNeverBecomesObservedFact, TemporalAnalysisNeverGrantsActionAuthority }
}
