-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.AgentActionEvidenceEnvelopeClosure

namespace AgenticAILabProof.Enterprise.AgentActionEnterpriseInvariantClosure

open AgentActionEvidenceEnvelopeClosure

def capabilityConfinement
    (envelope : AgentActionEvidenceEnvelope) : Prop :=
  ∀ capability ∈ envelope.observation.grantedCapabilities,
    capability ∈ envelope.action.authorizedCapabilities

def toolIdentityClosed
    (envelope : AgentActionEvidenceEnvelope) : Prop :=
  envelope.observation.resolvedTool = envelope.action.declaredTool

def effectContainment
    (envelope : AgentActionEvidenceEnvelope) : Prop :=
  ∀ effect ∈ envelope.observation.observedEffects,
    effect ∈ envelope.action.declaredEffects

def causalContinuity
    (envelope : AgentActionEvidenceEnvelope) : Prop :=
  envelope.observation.actionId = envelope.action.actionId ∧
    envelope.observation.operationId = envelope.action.operationId ∧
    envelope.observation.previousEvidenceRoot =
      envelope.action.previousEvidenceRoot ∧
    envelope.observation.evidenceRoot = envelope.evidenceRoot ∧
    envelope.recovery.actionId = envelope.action.actionId ∧
    envelope.recovery.observationEventId =
      envelope.observation.eventId ∧
    envelope.recovery.priorEvidenceRoot =
      envelope.observation.evidenceRoot

structure AgentActionEnterpriseInvariantClosed
    (observationValid : AgentObservationEventValid)
    (recoveryValid : AgentRecoveryDecisionProjectionValid)
    (envelope : AgentActionEvidenceEnvelope) : Prop where
  envelopeCloses :
    AgentActionEvidenceEnvelopeClosed
      observationValid recoveryValid envelope
  capabilitiesConfined : capabilityConfinement envelope
  toolIdentityCloses : toolIdentityClosed envelope
  effectsContained : effectContainment envelope
  causalChainContinuous : causalContinuity envelope

theorem closedEnvelopeProvidesCausalContinuity
    {observationValid : AgentObservationEventValid}
    {recoveryValid : AgentRecoveryDecisionProjectionValid}
    {envelope : AgentActionEvidenceEnvelope}
    (closed :
      AgentActionEvidenceEnvelopeClosed
        observationValid recoveryValid envelope) :
    causalContinuity envelope :=
  ⟨closed.actionObservationMatches,
    closed.actionOperationMatches,
    closed.previousRootMatchesAction,
    closed.observationRootMatches,
    closed.recoveryActionMatches,
    closed.recoveryObservationMatches,
    closed.recoveryRootMatches⟩

theorem enterpriseInvariantClosureCarriesAllFourGuarantees
    {observationValid : AgentObservationEventValid}
    {recoveryValid : AgentRecoveryDecisionProjectionValid}
    {envelope : AgentActionEvidenceEnvelope}
    (closed :
      AgentActionEnterpriseInvariantClosed
        observationValid recoveryValid envelope) :
    capabilityConfinement envelope ∧
      toolIdentityClosed envelope ∧
      effectContainment envelope ∧
      causalContinuity envelope :=
  ⟨closed.capabilitiesConfined,
    closed.toolIdentityCloses,
    closed.effectsContained,
    closed.causalChainContinuous⟩

theorem unauthorizedCapabilityRejectsInvariantClosure
    (observationValid : AgentObservationEventValid)
    (recoveryValid : AgentRecoveryDecisionProjectionValid)
    (envelope : AgentActionEvidenceEnvelope)
    (capability : AgentCapabilityId)
    (granted :
      capability ∈ envelope.observation.grantedCapabilities)
    (unauthorized :
      capability ∉ envelope.action.authorizedCapabilities) :
    ¬ AgentActionEnterpriseInvariantClosed
      observationValid recoveryValid envelope := by
  intro closed
  exact unauthorized (closed.capabilitiesConfined capability granted)

theorem mismatchedToolIdentityRejectsInvariantClosure
    (observationValid : AgentObservationEventValid)
    (recoveryValid : AgentRecoveryDecisionProjectionValid)
    (envelope : AgentActionEvidenceEnvelope)
    (mismatch :
      envelope.observation.resolvedTool ≠ envelope.action.declaredTool) :
    ¬ AgentActionEnterpriseInvariantClosed
      observationValid recoveryValid envelope := by
  intro closed
  exact mismatch closed.toolIdentityCloses

theorem undeclaredEffectRejectsInvariantClosure
    (observationValid : AgentObservationEventValid)
    (recoveryValid : AgentRecoveryDecisionProjectionValid)
    (envelope : AgentActionEvidenceEnvelope)
    (effect : AgentEffectClaim)
    (observed : effect ∈ envelope.observation.observedEffects)
    (undeclared : effect ∉ envelope.action.declaredEffects) :
    ¬ AgentActionEnterpriseInvariantClosed
      observationValid recoveryValid envelope := by
  intro closed
  exact undeclared (closed.effectsContained effect observed)

theorem brokenCausalContinuityRejectsInvariantClosure
    (observationValid : AgentObservationEventValid)
    (recoveryValid : AgentRecoveryDecisionProjectionValid)
    (envelope : AgentActionEvidenceEnvelope)
    (broken : ¬ causalContinuity envelope) :
    ¬ AgentActionEnterpriseInvariantClosed
      observationValid recoveryValid envelope := by
  intro closed
  exact broken closed.causalChainContinuous

theorem sourceAdapterCannotOverrideToolIdentity
    (observationValid : AgentObservationEventValid)
    (recoveryValid : AgentRecoveryDecisionProjectionValid)
    (envelope : AgentActionEvidenceEnvelope)
    (_adapterPresent : envelope.observation.sourceAdapterId ≠ "")
    (mismatch :
      envelope.observation.resolvedTool ≠ envelope.action.declaredTool) :
    ¬ AgentActionEnterpriseInvariantClosed
      observationValid recoveryValid envelope :=
  mismatchedToolIdentityRejectsInvariantClosure
    observationValid recoveryValid envelope mismatch

end AgenticAILabProof.Enterprise.AgentActionEnterpriseInvariantClosure
