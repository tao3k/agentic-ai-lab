-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.TemporalCausality

namespace AgenticAILabProof.Vertical.Healthcare.PrescriptionCausalityRefinement

open AgenticAILabProof.PooC4.TemporalCausality

abbrev ClinicalEvent := CausalEvent String String String

def observedEvent
    (identity payload : String) (position : Nat) (parents : List String) :
    ClinicalEvent :=
  { identity := identity
    subject := "patient-1"
    payloadIdentity := payload
    logicalPosition := position
    causalParents := parents
    modality := .observed
    committed := true }

def nonFactEvent
    (identity payload : String) (position : Nat) (parents : List String)
    (modality : EventModality) : ClinicalEvent :=
  { identity := identity
    subject := "patient-1"
    payloadIdentity := payload
    logicalPosition := position
    causalParents := parents
    modality := modality
    committed := false }

def aiRecommendation : ClinicalEvent :=
  observedEvent "ai-tmp-smx-recommendation-1" "proposed-order/tmp-smx-1" 3
    ["active-warfarin-context-1"]

def interactionEvidence : ClinicalEvent :=
  observedEvent "warfarin-tmp-smx-interaction-evidence-1"
    "healthcare/pharmacology/warfarin-tmp-smx-label-evidence/v1" 4
    [aiRecommendation.identity]

def governanceHold : ClinicalEvent :=
  observedEvent "prescription-governance-hold-1"
    "hold/proposed-order-tmp-smx-1" 5 [interactionEvidence.identity]

def clinicianReview : ClinicalEvent :=
  observedEvent "independent-clinician-review-1"
    "review/reject-tmp-smx-and-select-alternative" 6 [governanceHold.identity]

def alternativePrescription : ClinicalEvent :=
  observedEvent "alternative-prescription-1/rev1" "alternative-order-1" 7
    [clinicianReview.identity]

def wrongAutoApproval : ClinicalEvent :=
  nonFactEvent "wrong-ai-auto-approval-1" "proposed-order/tmp-smx-1" 5
    [interactionEvidence.identity] .counterfactual

def wrongAdministration : ClinicalEvent :=
  nonFactEvent "wrong-tmp-smx-administration-1" "dose/tmp-smx-1" 6
    [wrongAutoApproval.identity] .counterfactual

def anticoagulationRisk : ClinicalEvent :=
  nonFactEvent "elevated-anticoagulation-risk-1"
    "risk/prolonged-prothrombin-time" 7 [wrongAdministration.identity]
    .hypothesized

def declaredCaseEvents : List ClinicalEvent :=
  [aiRecommendation, interactionEvidence, governanceHold, clinicianReview,
   alternativePrescription, wrongAutoApproval, wrongAdministration,
   anticoagulationRisk]

def independentReviewCut : List String :=
  [aiRecommendation.identity, interactionEvidence.identity,
   governanceHold.identity, clinicianReview.identity]

def declaredErrorPath : List ClinicalEvent :=
  [wrongAutoApproval, wrongAdministration]

def declaredErrorImpacts : List ClinicalEvent :=
  [anticoagulationRisk]

theorem wrongPathSatisfiesTrajectoryContract :
    ErrorTrajectoryValid declaredErrorPath := by
  simp [ErrorTrajectoryValid, declaredErrorPath, wrongAutoApproval,
    wrongAdministration, nonFactEvent]

theorem errorImpactSatisfiesTrajectoryContract :
    ImpactTrajectoryValid declaredErrorImpacts := by
  simp [ImpactTrajectoryValid, declaredErrorImpacts, anticoagulationRisk,
    nonFactEvent]

theorem declaredErrorPathCannotBeAdmitted (asOf : Nat)
    (event : ClinicalEvent) (member : event ∈ declaredErrorPath) :
    ¬ AdmittedAt asOf event :=
  validErrorTrajectoryMemberCannotBeAdmitted declaredErrorPath
    wrongPathSatisfiesTrajectoryContract event member asOf

theorem declaredErrorImpactCannotBeAdmitted (asOf : Nat)
    (event : ClinicalEvent) (member : event ∈ declaredErrorImpacts) :
    ¬ AdmittedAt asOf event :=
  validImpactTrajectoryMemberCannotBeAdmitted declaredErrorImpacts
    errorImpactSatisfiesTrajectoryContract event member asOf

theorem declaredCaseBindsRecommendationToInteractionEvidence :
    interactionEvidence.causalParents = [aiRecommendation.identity] := by
  rfl

theorem declaredCaseBindsHoldToIndependentReview :
    clinicianReview.causalParents = [governanceHold.identity] := by
  rfl

theorem wrongAutoApprovalCommitmentIsValid :
    ModalityCommitmentValid wrongAutoApproval := by
  simp [ModalityCommitmentValid, wrongAutoApproval, nonFactEvent]

theorem wrongAdministrationCommitmentIsValid :
    ModalityCommitmentValid wrongAdministration := by
  simp [ModalityCommitmentValid, wrongAdministration, nonFactEvent]

theorem hypothesizedRiskCommitmentIsValid :
    ModalityCommitmentValid anticoagulationRisk := by
  simp [ModalityCommitmentValid, anticoagulationRisk, nonFactEvent]

theorem wrongAutoApprovalCannotBeAdmitted (asOf : Nat) :
    ¬ AdmittedAt asOf wrongAutoApproval := by
  simp [AdmittedAt, wrongAutoApproval, nonFactEvent]

theorem wrongAdministrationCannotBeAdmitted (asOf : Nat) :
    ¬ AdmittedAt asOf wrongAdministration := by
  simp [AdmittedAt, wrongAdministration, nonFactEvent]

theorem independentReviewCutExcludesWrongPath :
    wrongAutoApproval.identity ∉ independentReviewCut ∧
    wrongAdministration.identity ∉ independentReviewCut := by
  decide

theorem alternativePrescriptionHasIndependentHumanParent :
    alternativePrescription.causalParents = [clinicianReview.identity] := by
  rfl

end AgenticAILabProof.Vertical.Healthcare.PrescriptionCausalityRefinement
