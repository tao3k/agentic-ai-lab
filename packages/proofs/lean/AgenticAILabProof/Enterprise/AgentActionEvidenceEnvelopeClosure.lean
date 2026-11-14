-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.BundleEvidenceBinding
import AgenticAILabProof.PooC4.RecoveryPolicyAuthorization

namespace AgenticAILabProof.Enterprise.AgentActionEvidenceEnvelopeClosure

open BundleEvidenceBinding
open AgenticAILabProof.PooC4.RecoveryPolicyAuthorization

abbrev AgentActionId := String
abbrev AgentObservationEventId := String
abbrev AgentDecisionId := String
abbrev AgentEvidenceRoot := String
abbrev AgentCapabilityId := String

structure AgentToolIdentity where
  toolName : String
  providerIdentity : String
  implementationDigest : String
  resolutionDigest : String
  deriving DecidableEq, Repr

structure AgentEffectClaim where
  effectKind : String
  resourceIdentity : String
  actionDigest : String
  deriving DecidableEq, Repr

structure AgentActionIntent where
  actionId : AgentActionId
  operationId : Nat
  principalIdentity : String
  requestedCapabilities : List AgentCapabilityId
  authorizedCapabilities : List AgentCapabilityId
  declaredTool : AgentToolIdentity
  declaredEffects : List AgentEffectClaim
  inputDigest : String
  previousEvidenceRoot : AgentEvidenceRoot
  deriving DecidableEq, Repr

structure AgentObservationEvent where
  eventId : AgentObservationEventId
  actionId : AgentActionId
  operationId : Nat
  parentEventId : Option AgentObservationEventId
  grantedCapabilities : List AgentCapabilityId
  resolvedTool : AgentToolIdentity
  observedEffects : List AgentEffectClaim
  previousEvidenceRoot : AgentEvidenceRoot
  evidenceRoot : AgentEvidenceRoot
  observedAt : Nat
  sourceAdapterId : String
  sourceRecordDigest : String
  provenanceDigest : String
  deriving DecidableEq, Repr

inductive AgentRecoveryOutcome where
  | allowed
  | denied
  | escalated
  | failedClosed
  deriving DecidableEq, Repr

structure AgentRecoveryDecisionProjection where
  decisionId : AgentDecisionId
  actionId : AgentActionId
  observationEventId : AgentObservationEventId
  priorEvidenceRoot : AgentEvidenceRoot
  successorEvidenceRoot : Option AgentEvidenceRoot
  policyRevision : String
  outcome : AgentRecoveryOutcome
  reasonDigest : String
  receipt : RecoveryDecisionReceipt
  provenanceDigest : String
  deriving Repr

def agentRecoveryOutcomeClosed
    (decision : AgentRecoveryDecisionProjection) : Prop :=
  match decision.outcome with
  | .allowed =>
      ∃ successor,
        decision.successorEvidenceRoot = some successor ∧
          successor ≠ decision.priorEvidenceRoot
  | .denied => decision.successorEvidenceRoot = none
  | .escalated => decision.successorEvidenceRoot = none
  | .failedClosed => decision.successorEvidenceRoot = none

structure AgentActionEvidenceEnvelope where
  schemaId : String
  action : AgentActionIntent
  observation : AgentObservationEvent
  recovery : AgentRecoveryDecisionProjection
  evidenceRoot : AgentEvidenceRoot
  bundleDigest : BundleDigest
  bundleSubject : BundleSubject
  provenanceDigest : String
  deriving Repr

def AgentObservationEventValid := AgentObservationEvent → Prop

def AgentRecoveryDecisionProjectionValid :=
  AgentRecoveryDecisionProjection → Prop

structure AgentActionEvidenceEnvelopeClosed
    (observationValid : AgentObservationEventValid)
    (recoveryValid : AgentRecoveryDecisionProjectionValid)
    (envelope : AgentActionEvidenceEnvelope) : Prop where
  observationValidates : observationValid envelope.observation
  recoveryValidates : recoveryValid envelope.recovery
  schemaIdentityPresent : envelope.schemaId ≠ ""
  actionIdentityPresent : envelope.action.actionId ≠ ""
  principalIdentityPresent : envelope.action.principalIdentity ≠ ""
  observationIdentityPresent : envelope.observation.eventId ≠ ""
  decisionIdentityPresent : envelope.recovery.decisionId ≠ ""
  evidenceRootPresent : envelope.evidenceRoot ≠ ""
  bundleDigestPresent : envelope.bundleDigest ≠ ""
  envelopeProvenancePresent : envelope.provenanceDigest ≠ ""
  observationProvenancePresent :
    envelope.observation.provenanceDigest ≠ ""
  recoveryProvenancePresent : envelope.recovery.provenanceDigest ≠ ""
  sourceAdapterPresent : envelope.observation.sourceAdapterId ≠ ""
  sourceRecordDigestPresent :
    envelope.observation.sourceRecordDigest ≠ ""
  actionObservationMatches :
    envelope.observation.actionId = envelope.action.actionId
  actionOperationMatches :
    envelope.observation.operationId = envelope.action.operationId
  recoveryActionMatches :
    envelope.recovery.actionId = envelope.action.actionId
  recoveryOperationMatches :
    envelope.recovery.receipt.operation = envelope.action.operationId
  recoveryObservationMatches :
    envelope.recovery.observationEventId = envelope.observation.eventId
  previousRootMatchesAction :
    envelope.observation.previousEvidenceRoot =
      envelope.action.previousEvidenceRoot
  observationRootMatches :
    envelope.observation.evidenceRoot = envelope.evidenceRoot
  recoveryRootMatches :
    envelope.recovery.priorEvidenceRoot = envelope.observation.evidenceRoot
  bundleDigestMatches :
    envelope.bundleSubject.bundleDigest = envelope.bundleDigest
  recoveryOutcomeCloses : agentRecoveryOutcomeClosed envelope.recovery

theorem closedEnvelopeBindsActionObservationAndDecision
    {observationValid : AgentObservationEventValid}
    {recoveryValid : AgentRecoveryDecisionProjectionValid}
    {envelope : AgentActionEvidenceEnvelope}
    (closed :
      AgentActionEvidenceEnvelopeClosed
        observationValid recoveryValid envelope) :
    envelope.observation.actionId = envelope.action.actionId ∧
      envelope.recovery.actionId = envelope.action.actionId ∧
      envelope.recovery.observationEventId =
        envelope.observation.eventId ∧
      envelope.recovery.priorEvidenceRoot =
        envelope.observation.evidenceRoot :=
  ⟨closed.actionObservationMatches,
    closed.recoveryActionMatches,
    closed.recoveryObservationMatches,
    closed.recoveryRootMatches⟩

theorem mismatchedObservationActionRejectsEnvelope
    (observationValid : AgentObservationEventValid)
    (recoveryValid : AgentRecoveryDecisionProjectionValid)
    (envelope : AgentActionEvidenceEnvelope)
    (mismatch :
      envelope.observation.actionId ≠ envelope.action.actionId) :
    ¬ AgentActionEvidenceEnvelopeClosed
      observationValid recoveryValid envelope := by
  intro closed
  exact mismatch closed.actionObservationMatches

theorem mismatchedDecisionObservationRejectsEnvelope
    (observationValid : AgentObservationEventValid)
    (recoveryValid : AgentRecoveryDecisionProjectionValid)
    (envelope : AgentActionEvidenceEnvelope)
    (mismatch :
      envelope.recovery.observationEventId ≠
        envelope.observation.eventId) :
    ¬ AgentActionEvidenceEnvelopeClosed
      observationValid recoveryValid envelope := by
  intro closed
  exact mismatch closed.recoveryObservationMatches

theorem mismatchedEvidenceRootRejectsEnvelope
    (observationValid : AgentObservationEventValid)
    (recoveryValid : AgentRecoveryDecisionProjectionValid)
    (envelope : AgentActionEvidenceEnvelope)
    (mismatch :
      envelope.recovery.priorEvidenceRoot ≠
        envelope.observation.evidenceRoot) :
    ¬ AgentActionEvidenceEnvelopeClosed
      observationValid recoveryValid envelope := by
  intro closed
  exact mismatch closed.recoveryRootMatches

theorem sourceRecordPresenceDoesNotCloseEnvelope
    (envelope : AgentActionEvidenceEnvelope)
    (_sourcePresent : envelope.observation.sourceRecordDigest ≠ "") :
    ¬ AgentActionEvidenceEnvelopeClosed
      (fun _ => False)
      (fun _ => True)
      envelope := by
  intro closed
  exact closed.observationValidates

theorem failedClosedDecisionHasNoSuccessorRoot
    (decision : AgentRecoveryDecisionProjection)
    (outcome : decision.outcome = .failedClosed)
    (closed : agentRecoveryOutcomeClosed decision) :
    decision.successorEvidenceRoot = none := by
  simpa [agentRecoveryOutcomeClosed, outcome] using closed

end AgenticAILabProof.Enterprise.AgentActionEvidenceEnvelopeClosure
