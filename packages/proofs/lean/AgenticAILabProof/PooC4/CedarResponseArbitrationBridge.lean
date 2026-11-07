-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.CedarAuthorizationSemantics
import AgenticAILabProof.PooC4.CedarDualEngineArbitration

namespace AgenticAILabProof.PooC4.CedarResponseArbitrationBridge

open AgenticAILabProof.PooC4.CedarDualEngineArbitration

/-!
Lossless Cedar response comparison at the arbitration boundary.

The comparable value includes the Cedar semantic version, the canonical policy
input identity, and the complete Cedar response.  Engine executable identity
belongs to the receipt observation and is intentionally excluded from semantic
outcome equality.
-/

structure CedarComparableOutcome
    (SemanticVersion InputIdentity : Type) where
  semanticVersion : SemanticVersion
  inputIdentity : InputIdentity
  response : Cedar.Spec.Response
deriving DecidableEq, Repr

instance
    {SemanticVersion InputIdentity : Type} :
    AuthorizationDecisionProjection
      (CedarComparableOutcome SemanticVersion InputIdentity) where
  decision outcome :=
    match outcome.response.decision with
    | .allow => .allow
    | .deny => .deny

structure CedarEngineObservation
    (EngineIdentity SemanticVersion InputIdentity : Type) where
  engineIdentity : EngineIdentity
  comparable : CedarComparableOutcome SemanticVersion InputIdentity
deriving DecidableEq, Repr

def comparableOutcome
    {EngineIdentity SemanticVersion InputIdentity : Type}
    (observation :
      CedarEngineObservation
        EngineIdentity SemanticVersion InputIdentity) :
    CedarComparableOutcome SemanticVersion InputIdentity :=
  observation.comparable

theorem cedar_allow_projects_to_local_allow
    {SemanticVersion InputIdentity : Type}
    (semanticVersion : SemanticVersion)
    (inputIdentity : InputIdentity)
    (determiningPolicies erroringPolicies :
      Cedar.Data.Set Cedar.Spec.PolicyID) :
    AuthorizationDecisionProjection.decision
      (CedarComparableOutcome.mk
        semanticVersion
        inputIdentity
        { decision := .allow
          determiningPolicies := determiningPolicies
          erroringPolicies := erroringPolicies }) =
      CedarDecision.allow := by
  rfl

theorem cedar_deny_projects_to_local_deny
    {SemanticVersion InputIdentity : Type}
    (semanticVersion : SemanticVersion)
    (inputIdentity : InputIdentity)
    (determiningPolicies erroringPolicies :
      Cedar.Data.Set Cedar.Spec.PolicyID) :
    AuthorizationDecisionProjection.decision
      (CedarComparableOutcome.mk
        semanticVersion
        inputIdentity
        { decision := .deny
          determiningPolicies := determiningPolicies
          erroringPolicies := erroringPolicies }) =
      CedarDecision.deny := by
  rfl

theorem exact_cedar_agreement_is_dual_witnessed
    {SemanticVersion InputIdentity : Type}
    [DecidableEq SemanticVersion]
    [DecidableEq InputIdentity]
    (outcome : CedarComparableOutcome SemanticVersion InputIdentity) :
    arbitrateStrict (.completed outcome) (.completed outcome) =
      projectOutcome .dualWitnessed true .agreed outcome := by
  simp [arbitrateStrict]

theorem cedar_response_disagreement_fails_closed
    {SemanticVersion InputIdentity : Type}
    [DecidableEq SemanticVersion]
    [DecidableEq InputIdentity]
    (semanticVersion : SemanticVersion)
    (inputIdentity : InputIdentity)
    (leftResponse rightResponse : Cedar.Spec.Response)
    (different : leftResponse ≠ rightResponse) :
    arbitrateStrict
        (.completed
          (CedarComparableOutcome.mk
            semanticVersion inputIdentity leftResponse))
        (.completed
          (CedarComparableOutcome.mk
            semanticVersion inputIdentity rightResponse)) =
      failClosed .engineDisagreement := by
  have differentOutcomes :
      (CedarComparableOutcome.mk
        semanticVersion inputIdentity leftResponse) ≠
      CedarComparableOutcome.mk
        semanticVersion inputIdentity rightResponse := by
    intro equalOutcomes
    apply different
    exact congrArg CedarComparableOutcome.response equalOutcomes
  simp [arbitrateStrict, differentOutcomes]

theorem input_identity_disagreement_fails_closed
    {SemanticVersion InputIdentity : Type}
    [DecidableEq SemanticVersion]
    [DecidableEq InputIdentity]
    (semanticVersion : SemanticVersion)
    (leftInput rightInput : InputIdentity)
    (response : Cedar.Spec.Response)
    (different : leftInput ≠ rightInput) :
    arbitrateStrict
        (.completed
          (CedarComparableOutcome.mk
            semanticVersion leftInput response))
        (.completed
          (CedarComparableOutcome.mk
            semanticVersion rightInput response)) =
      failClosed .engineDisagreement := by
  have differentOutcomes :
      (CedarComparableOutcome.mk
        semanticVersion leftInput response) ≠
      CedarComparableOutcome.mk
        semanticVersion rightInput response := by
    intro equalOutcomes
    apply different
    exact congrArg CedarComparableOutcome.inputIdentity equalOutcomes
  simp [arbitrateStrict, differentOutcomes]

theorem semantic_version_disagreement_fails_closed
    {SemanticVersion InputIdentity : Type}
    [DecidableEq SemanticVersion]
    [DecidableEq InputIdentity]
    (leftVersion rightVersion : SemanticVersion)
    (inputIdentity : InputIdentity)
    (response : Cedar.Spec.Response)
    (different : leftVersion ≠ rightVersion) :
    arbitrateStrict
        (.completed
          (CedarComparableOutcome.mk
            leftVersion inputIdentity response))
        (.completed
          (CedarComparableOutcome.mk
            rightVersion inputIdentity response)) =
      failClosed .engineDisagreement := by
  have differentOutcomes :
      (CedarComparableOutcome.mk
        leftVersion inputIdentity response) ≠
      CedarComparableOutcome.mk
        rightVersion inputIdentity response := by
    intro equalOutcomes
    apply different
    exact congrArg CedarComparableOutcome.semanticVersion equalOutcomes
  simp [arbitrateStrict, differentOutcomes]

theorem exact_agreement_retains_determining_policies
    {SemanticVersion InputIdentity : Type}
    (outcome : CedarComparableOutcome SemanticVersion InputIdentity) :
    outcome.response.determiningPolicies =
      outcome.response.determiningPolicies := by
  rfl

theorem exact_agreement_retains_erroring_policies
    {SemanticVersion InputIdentity : Type}
    (outcome : CedarComparableOutcome SemanticVersion InputIdentity) :
    outcome.response.erroringPolicies =
      outcome.response.erroringPolicies := by
  rfl

theorem equal_comparable_outcomes_have_equal_responses
    {SemanticVersion InputIdentity : Type}
    {left right : CedarComparableOutcome SemanticVersion InputIdentity}
    (equalOutcomes : left = right) :
    left.response = right.response := by
  exact congrArg CedarComparableOutcome.response equalOutcomes

theorem equal_comparable_outcomes_have_equal_input_identities
    {SemanticVersion InputIdentity : Type}
    {left right : CedarComparableOutcome SemanticVersion InputIdentity}
    (equalOutcomes : left = right) :
    left.inputIdentity = right.inputIdentity := by
  exact congrArg CedarComparableOutcome.inputIdentity equalOutcomes

theorem equal_comparable_outcomes_have_equal_semantic_versions
    {SemanticVersion InputIdentity : Type}
    {left right : CedarComparableOutcome SemanticVersion InputIdentity}
    (equalOutcomes : left = right) :
    left.semanticVersion = right.semanticVersion := by
  exact congrArg CedarComparableOutcome.semanticVersion equalOutcomes

theorem engine_identity_is_receipt_only
    {EngineIdentity SemanticVersion InputIdentity : Type}
    (leftEngine rightEngine : EngineIdentity)
    (outcome : CedarComparableOutcome SemanticVersion InputIdentity) :
    comparableOutcome
        { engineIdentity := leftEngine
          comparable := outcome } =
      comparableOutcome
        { engineIdentity := rightEngine
          comparable := outcome } := by
  rfl

theorem unselected_cedar_shadow_is_conformance_backed_not_dual
    {SemanticVersion InputIdentity : Type}
    [DecidableEq SemanticVersion]
    [DecidableEq InputIdentity]
    (outcome : CedarComparableOutcome SemanticVersion InputIdentity) :
    arbitrateConformanceBacked true
        (.completed outcome)
        (.notSelected) =
      projectOutcome .conformanceBacked false .notSelected outcome := by
  rfl

end AgenticAILabProof.PooC4.CedarResponseArbitrationBridge
