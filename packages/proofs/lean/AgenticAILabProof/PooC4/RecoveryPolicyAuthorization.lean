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

/-- Portable identifiers projected from the admitted POO snapshot. -/
structure DurableDecisionScope where
  attempt : AttemptId
  effect : OperationId
  policyRevision : Nat
  evidenceCut : Nat
deriving DecidableEq

inductive DurableEffectOutcome where
  | unknown
  | succeeded
  | failed
deriving DecidableEq

structure DurableEvidence where
  scope : DurableDecisionScope
  bindingMatches : Bool
  currentPermission : Bool
  repeatSafe : Bool
  hasObservations : Bool
  recordedOutcome : DurableEffectOutcome
deriving DecidableEq

/-- Callback returns are parameters, including a policy that always proposes retry. -/
structure DurablePolicyReturns where
  interpretation : DurableEffectOutcome
  allowsRetry : Bool

structure DurableDecision where
  evidence : DurableEvidence
  interpretation : DurableEffectOutcome
  outcome : DurableEffectOutcome
  proposed : Bool
  eligible : Bool
deriving DecidableEq

def durableInterpretation (e : DurableEvidence) (p : DurablePolicyReturns) :
    DurableEffectOutcome :=
  match e.recordedOutcome with
  | .unknown => if e.bindingMatches && e.hasObservations then p.interpretation else .unknown
  | _ => .unknown

def durableOutcome (recorded interpretation : DurableEffectOutcome) :
    DurableEffectOutcome :=
  match recorded with
  | .unknown => interpretation
  | .succeeded => .succeeded
  | .failed => .failed

/-- Mirrors recovery-decision.ss after Scheme truth values and symbols are normalized. -/
def durableDecision (e : DurableEvidence) (p : DurablePolicyReturns) : DurableDecision :=
  let interpretation := durableInterpretation e p
  let outcome := durableOutcome e.recordedOutcome interpretation
  let proposed := e.bindingMatches && decide (outcome ≠ .succeeded) && p.allowsRetry
  { evidence := e, interpretation, outcome, proposed,
    eligible := proposed && e.currentPermission && e.repeatSafe }

/-- Equality covers the entire projected result, including the original scope and guards. -/
def SchemeDurableDecisionRefines (e : DurableEvidence) (p : DurablePolicyReturns)
    (projected : DurableDecision) : Prop :=
  projected = durableDecision e p

def checkSchemeDurableProjection (e : DurableEvidence) (p : DurablePolicyReturns)
    (projected : DurableDecision) : Bool :=
  decide (projected = durableDecision e p)

theorem checkSchemeDurableProjectionSound
    {e : DurableEvidence} {p : DurablePolicyReturns} {projected : DurableDecision}
    (accepted : checkSchemeDurableProjection e p projected = true) :
    SchemeDurableDecisionRefines e p projected := by
  change projected = durableDecision e p
  exact of_decide_eq_true accepted

theorem durableRetryRequiresIndependentGuards
    {e : DurableEvidence} {p : DurablePolicyReturns} {d : DurableDecision}
    (refines : SchemeDurableDecisionRefines e p d) (eligible : d.eligible = true) :
    d.evidence.scope = e.scope ∧ e.currentPermission = true ∧ e.repeatSafe = true := by
  change d = durableDecision e p at refines
  subst d
  have h := (Bool.and_eq_true_iff.mp eligible)
  exact ⟨rfl, (Bool.and_eq_true_iff.mp h.1).2, h.2⟩

theorem durableRetryIneligibleAfterSuccess
    {e : DurableEvidence} {p : DurablePolicyReturns} {d : DurableDecision}
    (refines : SchemeDurableDecisionRefines e p d)
    (succeeded : e.recordedOutcome = .succeeded ∨ d.outcome = .succeeded) :
    d.eligible = false := by
  change d = durableDecision e p at refines
  subst d
  rcases succeeded with recorded | effective
  · simp [durableDecision, durableOutcome, recorded]
  · change durableOutcome e.recordedOutcome (durableInterpretation e p) = .succeeded at effective
    simp [durableDecision, effective]

/-- This witness is process-local. Journal restoration only restores the spend. -/
structure DurableLiveSpend where
  scope : DurableDecisionScope
  tokenIdentity : Nat
  spendDigest : Nat
  predecessor : Option Nat

/-- Host admission binds the current decision cut to an exact committed receipt
and its current authority. It is independent of the Scheme result. -/
structure DurableHostCut where
  scope : DurableDecisionScope
  authority : RecoveryPolicyAuthority
  decisionDigest : Nat
  contextCurrent : Bool
  endpointMatches : Bool
  observationCurrent : Bool
  originalOutstanding : Bool
  issuerConsumedToken : Option Nat
  latestSpend : Option Nat
  reconciledPredecessor : Option Nat
  liveSpend : Option DurableLiveSpend

def DurableHandoffCurrent (current : DurableHostCut) (capability : RetryCapability) : Prop :=
  current.contextCurrent = true ∧ current.endpointMatches = true ∧
  current.observationCurrent = true ∧ current.originalOutstanding = true ∧
  current.issuerConsumedToken = some capability.token.tokenIdentity ∧
  ∃ live, current.liveSpend = some live ∧ live.scope = current.scope ∧
    live.tokenIdentity = capability.token.tokenIdentity ∧
    current.latestSpend = some live.spendDigest ∧
    current.reconciledPredecessor = live.predecessor

def DurableRedispatch (current : DurableHostCut) (d : DurableDecision)
    (capability : RetryCapability) : Prop :=
  let receipt := capability.evidence.receipt
  d.eligible = true ∧ d.evidence.scope = current.scope ∧
  receipt.operation = current.scope.effect ∧
  receipt.priorAttempt = current.scope.attempt ∧
  receipt.authority = current.authority ∧
  receipt.decisionDigest = current.decisionDigest ∧
  RetryCapabilityStep capability .available .consumed ∧
  DurableHandoffCurrent current capability

theorem durableRedispatchRequiresIndependentGuards
    {e : DurableEvidence} {p : DurablePolicyReturns} {d : DurableDecision}
    {current : DurableHostCut} {capability : RetryCapability}
    (refines : SchemeDurableDecisionRefines e p d)
    (dispatch : DurableRedispatch current d capability) :
    e.currentPermission = true ∧ e.repeatSafe = true :=
  (durableRetryRequiresIndependentGuards refines dispatch.1).2

theorem durableRedispatchRejectsStaleScope
    {d : DurableDecision} {current : DurableHostCut} {capability : RetryCapability}
    (stale : d.evidence.scope ≠ current.scope) :
    ¬ DurableRedispatch current d capability :=
  fun dispatch => stale dispatch.2.1

theorem durableRedispatchRequiresCurrentReceipt
    {d : DurableDecision} {current : DurableHostCut} {capability : RetryCapability}
    (dispatch : DurableRedispatch current d capability) :
    capability.evidence.receipt.authority = current.authority ∧
    capability.evidence.receipt.decisionDigest = current.decisionDigest :=
  ⟨dispatch.2.2.2.2.1, dispatch.2.2.2.2.2.1⟩

theorem durableRedispatchRequiresLiveSpend
    {d : DurableDecision} {current : DurableHostCut} {capability : RetryCapability}
    (dispatch : DurableRedispatch current d capability) :
    DurableHandoffCurrent current capability :=
  dispatch.2.2.2.2.2.2.2

theorem durableCannotReanimateCommittedSpend
    {d : DurableDecision} {current : DurableHostCut} {capability : RetryCapability}
    (noLiveSpend : current.liveSpend = none) :
    ¬ DurableRedispatch current d capability := by
  intro dispatch
  obtain ⟨live, liveWitness, _⟩ := (durableRedispatchRequiresLiveSpend dispatch).2.2.2.2.2
  rw [noLiveSpend] at liveWitness
  contradiction

theorem durableCannotRedispatchWithoutIssuerSpend
    {d : DurableDecision} {current : DurableHostCut} {capability : RetryCapability}
    (unspent : current.issuerConsumedToken ≠ some capability.token.tokenIdentity) :
    ¬ DurableRedispatch current d capability :=
  fun dispatch => unspent (durableRedispatchRequiresLiveSpend dispatch).2.2.2.2.1

theorem durableCannotRedispatchChangedObservation
    {d : DurableDecision} {current : DurableHostCut} {capability : RetryCapability}
    (changed : current.observationCurrent = false) :
    ¬ DurableRedispatch current d capability :=
  fun dispatch =>
    Bool.noConfusion (changed.symm.trans (durableRedispatchRequiresLiveSpend dispatch).2.2.1)

theorem durableCannotRedispatchIneligible
    {d : DurableDecision} {current : DurableHostCut} {capability : RetryCapability}
    (ineligible : d.eligible = false) :
    ¬ DurableRedispatch current d capability :=
  fun dispatch => Bool.noConfusion (ineligible.symm.trans dispatch.1)

theorem durableCannotRedispatchSuccess
    {e : DurableEvidence} {p : DurablePolicyReturns} {d : DurableDecision}
    {current : DurableHostCut} {capability : RetryCapability}
    (refines : SchemeDurableDecisionRefines e p d)
    (succeeded : e.recordedOutcome = .succeeded ∨ d.outcome = .succeeded) :
    ¬ DurableRedispatch current d capability := by
  intro dispatch
  have ineligible := durableRetryIneligibleAfterSuccess refines succeeded
  exact Bool.noConfusion (ineligible.symm.trans dispatch.1)

end AgenticAILabProof.PooC4.RecoveryPolicyAuthorization
