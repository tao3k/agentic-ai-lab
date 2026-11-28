-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
Agentic AI Lab Governance core semantics.

This model owns Profile admission, pre-threat evidence, threat assessment and
Provider-handoff eligibility.  It intentionally does not redefine Cedar
requests, policies, evaluation or responses; those semantics remain upstream.
-/

namespace AgenticAILabProof.PooC4.GovernanceCore

inductive ThreatPhase where
  | latent
  | exposed
  | realized
  | mitigated
  | accepted
  deriving DecidableEq, Repr

inductive ThreatSeverity where
  | low
  | moderate
  | high
  | critical
  deriving DecidableEq, Repr

structure PreThreatCondition where
  identity : String
  observed : Bool
  evidenceIdentity : Option String
  deriving DecidableEq, Repr

def PreThreatCondition.Valid (condition : PreThreatCondition) : Prop :=
  condition.identity ≠ "" ∧
    (condition.observed = true →
      ∃ evidence, condition.evidenceIdentity = some evidence ∧ evidence ≠ "")

structure Threat where
  identity : String
  severity : ThreatSeverity
  phase : ThreatPhase
  preconditions : List PreThreatCondition
  mitigations : List String
  acceptanceAuthority : Option String
  deriving DecidableEq, Repr

def Threat.Valid (threat : Threat) : Prop :=
  threat.identity ≠ "" ∧
    threat.preconditions ≠ [] ∧
    (∀ condition ∈ threat.preconditions, condition.Valid) ∧
    (threat.phase = .mitigated → threat.mitigations ≠ []) ∧
    (threat.phase = .accepted →
      ∃ authority, threat.acceptanceAuthority = some authority ∧ authority ≠ "")

def Threat.BlocksHandoff (threat : Threat) : Prop :=
  (threat.severity = .high ∨ threat.severity = .critical) ∧
    (threat.phase = .exposed ∨ threat.phase = .realized)

structure ThreatModel where
  identity : String
  threats : List Threat
  deriving DecidableEq, Repr

structure GovernanceProfile where
  identity : String
  revision : String
  owner : String
  threatModel : ThreatModel
  deriving DecidableEq, Repr

structure GovernanceAssessment where
  profileIdentity : String
  modelIdentity : String
  assessedThreats : List Threat
  runtimeExecuted : Bool
  deriving DecidableEq, Repr

def GovernanceAdmitted
    (profile : GovernanceProfile)
    (assessment : GovernanceAssessment) : Prop :=
  profile.identity ≠ "" ∧
    profile.revision ≠ "" ∧
    profile.owner ≠ "" ∧
    profile.threatModel.identity ≠ "" ∧
    assessment.profileIdentity = profile.identity ∧
    assessment.modelIdentity = profile.threatModel.identity ∧
    assessment.assessedThreats = profile.threatModel.threats ∧
    (∀ threat ∈ assessment.assessedThreats, threat.Valid) ∧
    assessment.runtimeExecuted = false

def ProviderHandoffEligible
    (profile : GovernanceProfile)
    (assessment : GovernanceAssessment) : Prop :=
  GovernanceAdmitted profile assessment ∧
    ∀ threat ∈ assessment.assessedThreats, ¬ threat.BlocksHandoff

/- Governance evidence can qualify a Provider input but never grants an effect. -/
def GovernanceCarriesActionAuthority
    (_profile : GovernanceProfile)
    (_assessment : GovernanceAssessment) : Prop :=
  False

theorem observedPreThreatConditionRequiresEvidence
    (condition : PreThreatCondition)
    (valid : condition.Valid)
    (observed : condition.observed = true) :
    ∃ evidence, condition.evidenceIdentity = some evidence ∧ evidence ≠ "" :=
  valid.2 observed

theorem governanceAdmissionNeverCarriesActionAuthority
    (profile : GovernanceProfile)
    (assessment : GovernanceAssessment) :
    ¬ GovernanceCarriesActionAuthority profile assessment := by
  simp [GovernanceCarriesActionAuthority]

theorem activeCriticalThreatBlocksProviderHandoff
    (profile : GovernanceProfile)
    (assessment : GovernanceAssessment)
    (threat : Threat)
    (member : threat ∈ assessment.assessedThreats)
    (critical : threat.severity = .critical)
    (active : threat.phase = .exposed ∨ threat.phase = .realized) :
    ¬ ProviderHandoffEligible profile assessment := by
  intro eligible
  have notBlocking := eligible.2 threat member
  exact notBlocking ⟨Or.inr critical, active⟩

theorem acceptedThreatRequiresExplicitAuthority
    (threat : Threat)
    (valid : threat.Valid)
    (accepted : threat.phase = .accepted) :
    ∃ authority, threat.acceptanceAuthority = some authority ∧ authority ≠ "" :=
  valid.2.2.2.2 accepted

/- A label-only admission is the countermodel that motivated typed assessment. -/
def LabelOnlyAdmission (profile : GovernanceProfile) : Prop :=
  profile.identity ≠ ""

def counterexampleCondition : PreThreatCondition :=
  { identity := "external-input"
    observed := true
    evidenceIdentity := some "evidence:external-input" }

def counterexampleThreat : Threat :=
  { identity := "unreviewed-external-input"
    severity := .critical
    phase := .exposed
    preconditions := [counterexampleCondition]
    mitigations := []
    acceptanceAuthority := none }

def counterexampleProfile : GovernanceProfile :=
  { identity := "governance/counterexample"
    revision := "1"
    owner := "agentic-ai-lab"
    threatModel :=
      { identity := "threat-model/counterexample"
        threats := [counterexampleThreat] } }

def counterexampleAssessment : GovernanceAssessment :=
  { profileIdentity := counterexampleProfile.identity
    modelIdentity := counterexampleProfile.threatModel.identity
    assessedThreats := counterexampleProfile.threatModel.threats
    runtimeExecuted := false }

theorem labelOnlyAdmissionMissesActiveCriticalThreat :
    LabelOnlyAdmission counterexampleProfile := by
  simp [LabelOnlyAdmission, counterexampleProfile]

theorem typedGovernanceRejectsLabelOnlyCounterexample :
    ¬ ProviderHandoffEligible counterexampleProfile counterexampleAssessment := by
  apply activeCriticalThreatBlocksProviderHandoff
    counterexampleProfile counterexampleAssessment counterexampleThreat
  · simp [counterexampleAssessment, counterexampleProfile]
  · rfl
  · exact Or.inl rfl

end AgenticAILabProof.PooC4.GovernanceCore
