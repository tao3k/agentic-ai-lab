-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.EffectBoundary

namespace AgenticAILabProof.PooC4.RecoveryPolicyAuthorization

open AgenticAILabProof.PooC4.EffectBoundary

abbrev PolicyRootId := Nat
abbrev BoundaryRootId := Nat

structure RecoveryPolicyAuthority where
  policyRoot : PolicyRootId
  boundaryRoot : BoundaryRootId
  lineageDigest : Nat
  generation : Nat
deriving Repr, DecidableEq

inductive RecoveryDecisionOutcome where
  | committed
  | rejected
deriving Repr, DecidableEq

structure RecoveryDecision where
  permitsRetry : Bool
  variantDigest : Nat
  restartDigest : Nat
  payloadDigest : Nat
  observationDigest : Nat
deriving Repr, DecidableEq

structure RecoveryDecisionReceipt where
  authority : RecoveryPolicyAuthority
  operation : OperationId
  priorAttempt : AttemptId
  nextAttempt : AttemptId
  policyEvidence : Nat
  decisionDigest : Nat
  outcome : RecoveryDecisionOutcome
  selectedDecision : RecoveryDecision
deriving Repr, DecidableEq

structure RetryAuthorizationRefinesReceipt
    (authorization : RetryAuthorization)
    (receipt : RecoveryDecisionReceipt) : Prop where
  operationMatches :
    authorization.operation = receipt.operation
  priorAttemptMatches :
    authorization.priorAttempt = receipt.priorAttempt
  nextAttemptMatches :
    authorization.nextAttempt = receipt.nextAttempt
  policyEvidenceMatches :
    authorization.policyEvidence = receipt.policyEvidence
  freshAttempt :
    receipt.nextAttempt ≠ receipt.priorAttempt

structure PolicyAuthorizedRetry where
  authorization : RetryAuthorization
  receipt : RecoveryDecisionReceipt
  refines :
    RetryAuthorizationRefinesReceipt authorization receipt

structure SingleUseRuntimeToken where
  tokenIdentity : Nat
  boundaryRoot : BoundaryRootId
  generation : Nat
deriving Repr, DecidableEq

structure RetryCapability where
  evidence : PolicyAuthorizedRetry
  token : SingleUseRuntimeToken
  receiptCommitted :
    evidence.receipt.outcome = RecoveryDecisionOutcome.committed
  selectedDecisionPermitsRetry :
    evidence.receipt.selectedDecision.permitsRetry = true
  tokenBoundaryMatches :
    token.boundaryRoot = evidence.receipt.authority.boundaryRoot
  tokenGenerationMatches :
    token.generation = evidence.receipt.authority.generation

inductive RetryCapabilityState where
  | available
  | consumed
deriving Repr, DecidableEq

inductive RetryCapabilityStep
    (capability : RetryCapability) :
    RetryCapabilityState → RetryCapabilityState → Prop where
  | consume :
      RetryCapabilityStep
        capability
        RetryCapabilityState.available
        RetryCapabilityState.consumed

structure RecoveryDecisionObservation where
  receipt : RecoveryDecisionReceipt
deriving Repr, DecidableEq

inductive RecoveryAuthorizationView where
  | receipt (value : RecoveryDecisionReceipt)
  | observation (value : RecoveryDecisionObservation)
  | capability (value : RetryCapability)

def GrantsRetryAuthority : RecoveryAuthorizationView → Prop
  | RecoveryAuthorizationView.receipt _ => False
  | RecoveryAuthorizationView.observation _ => False
  | RecoveryAuthorizationView.capability _ => True

def ProjectRetryCapability
    (receipt : RecoveryDecisionReceipt)
    (token : SingleUseRuntimeToken)
    (authority : RecoveryPolicyAuthority) :
    Prop :=
  receipt.outcome = RecoveryDecisionOutcome.committed ∧
    receipt.selectedDecision.permitsRetry = true ∧
    authority = receipt.authority ∧
    token.boundaryRoot = receipt.authority.boundaryRoot ∧
    token.generation = receipt.authority.generation ∧
    receipt.nextAttempt ≠ receipt.priorAttempt

def ConsumeRetryCapability
    (capability : RetryCapability)
    (before after : RetryCapabilityState) :
    Prop :=
  before = RetryCapabilityState.available ∧
    after = RetryCapabilityState.consumed ∧
    capability.evidence.receipt.nextAttempt ≠
      capability.evidence.receipt.priorAttempt

structure GovernedRetry
    (source target : EffectState) where
  evidence : PolicyAuthorizedRetry
  transition :
    Step
      source
      (EffectEvent.policyRetry evidence.authorization)
      target

theorem barePolicyEvidenceDoesNotIdentifyPolicyRoot :
    ∃ left right : RecoveryDecisionReceipt,
      left.policyEvidence = right.policyEvidence ∧
      left.authority.policyRoot ≠ right.authority.policyRoot := by
  let leftAuthority : RecoveryPolicyAuthority :=
    { policyRoot := 1
      boundaryRoot := 10
      lineageDigest := 100
      generation := 7 }
  let rightAuthority : RecoveryPolicyAuthority :=
    { policyRoot := 2
      boundaryRoot := 10
      lineageDigest := 200
      generation := 7 }
  let left : RecoveryDecisionReceipt :=
    { authority := leftAuthority
      operation := 11
      priorAttempt := 5
      nextAttempt := 6
      policyEvidence := 99
      decisionDigest := 1001
      outcome := RecoveryDecisionOutcome.committed
      selectedDecision :=
        { permitsRetry := true
          variantDigest := 301
          restartDigest := 401
          payloadDigest := 501
          observationDigest := 601 } }
  let right : RecoveryDecisionReceipt :=
    { authority := rightAuthority
      operation := 11
      priorAttempt := 5
      nextAttempt := 6
      policyEvidence := 99
      decisionDigest := 1002
      outcome := RecoveryDecisionOutcome.committed
      selectedDecision :=
        { permitsRetry := true
          variantDigest := 302
          restartDigest := 402
          payloadDigest := 502
          observationDigest := 602 } }
  refine ⟨left, right, rfl, ?_⟩
  decide

theorem policyAuthorizedRetryCarriesRecoveryPolicyAuthority
    (retry : PolicyAuthorizedRetry) :
    retry.authorization.operation = retry.receipt.operation ∧
      retry.authorization.priorAttempt = retry.receipt.priorAttempt ∧
      retry.authorization.nextAttempt = retry.receipt.nextAttempt ∧
      retry.authorization.policyEvidence = retry.receipt.policyEvidence ∧
      retry.receipt.nextAttempt ≠ retry.receipt.priorAttempt := by
  exact
    ⟨retry.refines.operationMatches,
      retry.refines.priorAttemptMatches,
      retry.refines.nextAttemptMatches,
      retry.refines.policyEvidenceMatches,
      retry.refines.freshAttempt⟩

theorem governedFailedRetryBindsPolicyAndCausalLineage
    (operation : OperationId)
    (attempt : AttemptId)
    (target : EffectState)
    (retry :
      GovernedRetry
        (EffectState.failed operation attempt)
        target) :
    retry.evidence.authorization.operation = operation ∧
      retry.evidence.authorization.priorAttempt = attempt ∧
      retry.evidence.authorization.nextAttempt ≠ attempt ∧
      retry.evidence.authorization.policyEvidence =
        retry.evidence.receipt.policyEvidence ∧
      target =
        EffectState.inFlight
          operation retry.evidence.authorization.nextAttempt := by
  obtain
      ⟨operationMatches, priorAttemptMatches, freshAttempt, targetMatches⟩ :=
    failedRetryPreservesCausalLink
      operation attempt retry.evidence.authorization target retry.transition
  exact
    ⟨operationMatches,
      priorAttemptMatches,
      freshAttempt,
      retry.evidence.refines.policyEvidenceMatches,
      targetMatches⟩

theorem governedCancelledRetryBindsPolicyAndCausalLineage
    (operation : OperationId)
    (attempt : AttemptId)
    (target : EffectState)
    (retry :
      GovernedRetry
        (EffectState.cancelled operation attempt)
        target) :
    retry.evidence.authorization.operation = operation ∧
      retry.evidence.authorization.priorAttempt = attempt ∧
      retry.evidence.authorization.nextAttempt ≠ attempt ∧
      retry.evidence.authorization.policyEvidence =
        retry.evidence.receipt.policyEvidence ∧
      target =
        EffectState.inFlight
          operation retry.evidence.authorization.nextAttempt := by
  obtain
      ⟨operationMatches, priorAttemptMatches, freshAttempt, targetMatches⟩ :=
    cancelledRetryPreservesCausalLink
      operation attempt retry.evidence.authorization target retry.transition
  exact
    ⟨operationMatches,
      priorAttemptMatches,
      freshAttempt,
      retry.evidence.refines.policyEvidenceMatches,
      targetMatches⟩

theorem governedRetryExposesPolicyLineage
    {source target : EffectState}
    (retry : GovernedRetry source target) :
    ∃ policyRoot boundaryRoot lineageDigest generation,
      retry.evidence.receipt.authority.policyRoot = policyRoot ∧
      retry.evidence.receipt.authority.boundaryRoot = boundaryRoot ∧
      retry.evidence.receipt.authority.lineageDigest = lineageDigest ∧
      retry.evidence.receipt.authority.generation = generation := by
  exact
    ⟨retry.evidence.receipt.authority.policyRoot,
      retry.evidence.receipt.authority.boundaryRoot,
      retry.evidence.receipt.authority.lineageDigest,
      retry.evidence.receipt.authority.generation,
      rfl, rfl, rfl, rfl⟩

theorem retryCapabilityCarriesCommittedRetryDecision
    (capability : RetryCapability) :
    capability.evidence.receipt.outcome =
        RecoveryDecisionOutcome.committed ∧
      capability.evidence.receipt.selectedDecision.permitsRetry = true ∧
      capability.token.boundaryRoot =
        capability.evidence.receipt.authority.boundaryRoot ∧
      capability.token.generation =
        capability.evidence.receipt.authority.generation := by
  exact
    ⟨capability.receiptCommitted,
      capability.selectedDecisionPermitsRetry,
      capability.tokenBoundaryMatches,
      capability.tokenGenerationMatches⟩

theorem consumedRetryCapabilityCannotStep
    (capability : RetryCapability)
    (target : RetryCapabilityState)
    (step :
      RetryCapabilityStep
        capability
        RetryCapabilityState.consumed
        target) :
    False := by
  cases step

theorem retryCapabilityCannotBeConsumedTwice
    (capability : RetryCapability)
    (intermediate target : RetryCapabilityState)
    (first :
      RetryCapabilityStep
        capability
        RetryCapabilityState.available
        intermediate)
    (second :
      RetryCapabilityStep capability intermediate target) :
    False := by
  cases first
  exact consumedRetryCapabilityCannotStep capability target second

theorem recoveryDecisionReceiptDoesNotGrantRetryAuthority
    (receipt : RecoveryDecisionReceipt) :
    ¬ GrantsRetryAuthority
      (RecoveryAuthorizationView.receipt receipt) := by
  intro authority
  exact authority

theorem recoveryDecisionObservationDoesNotGrantRetryAuthority
    (observation : RecoveryDecisionObservation) :
    ¬ GrantsRetryAuthority
      (RecoveryAuthorizationView.observation observation) := by
  intro authority
  exact authority

theorem retryAuthorityRequiresCapability
    (view : RecoveryAuthorizationView)
    (authority : GrantsRetryAuthority view) :
    ∃ capability : RetryCapability,
      view = RecoveryAuthorizationView.capability capability := by
  cases view with
  | receipt receipt =>
      exact False.elim authority
  | observation observation =>
      exact False.elim authority
  | capability capability =>
      exact ⟨capability, rfl⟩

theorem retryCapabilitySatisfiesProjectionContract
    (capability : RetryCapability) :
    ProjectRetryCapability
      capability.evidence.receipt
      capability.token
      capability.evidence.receipt.authority := by
  exact
    ⟨capability.receiptCommitted,
      capability.selectedDecisionPermitsRetry,
      rfl,
      capability.tokenBoundaryMatches,
      capability.tokenGenerationMatches,
      capability.evidence.refines.freshAttempt⟩

theorem retryCapabilityStepSatisfiesConsumptionContract
    (capability : RetryCapability)
    (before after : RetryCapabilityState)
    (step : RetryCapabilityStep capability before after) :
    ConsumeRetryCapability capability before after := by
  cases step
  exact
    ⟨rfl,
      rfl,
      capability.evidence.refines.freshAttempt⟩

end AgenticAILabProof.PooC4.RecoveryPolicyAuthorization
