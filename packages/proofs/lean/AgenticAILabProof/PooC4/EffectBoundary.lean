-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.PooC4.EffectBoundary

abbrev OperationId := Nat
abbrev AttemptId := Nat

structure CommitReceipt where
  operation : OperationId
  attempt : AttemptId
  verifierEvidence : Nat
deriving Repr, DecidableEq

structure RetryAuthorization where
  operation : OperationId
  priorAttempt : AttemptId
  nextAttempt : AttemptId
  policyEvidence : Nat
deriving Repr, DecidableEq

structure ReconciliationCapability where
  operation : OperationId
  providerEvidence : Nat
deriving Repr, DecidableEq

inductive EffectState where
  | declared (operation : OperationId)
  | inFlight (operation : OperationId) (attempt : AttemptId)
  | committed (receipt : CommitReceipt)
  | failed (operation : OperationId) (attempt : AttemptId)
  | cancelled (operation : OperationId) (attempt : AttemptId)
  | indeterminate (operation : OperationId) (attempt : AttemptId)
  | reconciling (operation : OperationId) (attempt : AttemptId)
deriving Repr, DecidableEq

inductive EffectEvent where
  | begin (attempt : AttemptId)
  | functionReturned
  | verifiedCommit (receipt : CommitReceipt)
  | provenFailure
  | provenCancellation
  | terminalProofLost
  | policyRetry (authorization : RetryAuthorization)
  | requestReconciliation (capability : ReconciliationCapability)
  | reconciliationCommitted (receipt : CommitReceipt)
  | reconciliationNoCommit
  | reconciliationUnknown
  | continuationReentry
deriving Repr, DecidableEq

inductive Step : EffectState → EffectEvent → EffectState → Prop where
  | begin
      (operation : OperationId)
      (attempt : AttemptId) :
      Step
        (EffectState.declared operation)
        (EffectEvent.begin attempt)
        (EffectState.inFlight operation attempt)
  | commit
      (operation : OperationId)
      (attempt : AttemptId)
      (receipt : CommitReceipt)
      (operationMatches : receipt.operation = operation)
      (attemptMatches : receipt.attempt = attempt) :
      Step
        (EffectState.inFlight operation attempt)
        (EffectEvent.verifiedCommit receipt)
        (EffectState.committed receipt)
  | fail
      (operation : OperationId)
      (attempt : AttemptId) :
      Step
        (EffectState.inFlight operation attempt)
        EffectEvent.provenFailure
        (EffectState.failed operation attempt)
  | cancel
      (operation : OperationId)
      (attempt : AttemptId) :
      Step
        (EffectState.inFlight operation attempt)
        EffectEvent.provenCancellation
        (EffectState.cancelled operation attempt)
  | loseTerminalProof
      (operation : OperationId)
      (attempt : AttemptId) :
      Step
        (EffectState.inFlight operation attempt)
        EffectEvent.terminalProofLost
        (EffectState.indeterminate operation attempt)
  | retryFailed
      (operation : OperationId)
      (attempt : AttemptId)
      (authorization : RetryAuthorization)
      (operationMatches : authorization.operation = operation)
      (attemptMatches : authorization.priorAttempt = attempt)
      (freshAttempt :
        authorization.nextAttempt ≠ authorization.priorAttempt) :
      Step
        (EffectState.failed operation attempt)
        (EffectEvent.policyRetry authorization)
        (EffectState.inFlight operation authorization.nextAttempt)
  | restartCancelled
      (operation : OperationId)
      (attempt : AttemptId)
      (authorization : RetryAuthorization)
      (operationMatches : authorization.operation = operation)
      (attemptMatches : authorization.priorAttempt = attempt)
      (freshAttempt :
        authorization.nextAttempt ≠ authorization.priorAttempt) :
      Step
        (EffectState.cancelled operation attempt)
        (EffectEvent.policyRetry authorization)
        (EffectState.inFlight operation authorization.nextAttempt)
  | startReconciliation
      (operation : OperationId)
      (attempt : AttemptId)
      (capability : ReconciliationCapability)
      (operationMatches : capability.operation = operation) :
      Step
        (EffectState.indeterminate operation attempt)
        (EffectEvent.requestReconciliation capability)
        (EffectState.reconciling operation attempt)
  | reconcileCommitted
      (operation : OperationId)
      (attempt : AttemptId)
      (receipt : CommitReceipt)
      (operationMatches : receipt.operation = operation)
      (attemptMatches : receipt.attempt = attempt) :
      Step
        (EffectState.reconciling operation attempt)
        (EffectEvent.reconciliationCommitted receipt)
        (EffectState.committed receipt)
  | reconcileNoCommit
      (operation : OperationId)
      (attempt : AttemptId) :
      Step
        (EffectState.reconciling operation attempt)
        EffectEvent.reconciliationNoCommit
        (EffectState.failed operation attempt)
  | reconcileUnknown
      (operation : OperationId)
      (attempt : AttemptId) :
      Step
        (EffectState.reconciling operation attempt)
        EffectEvent.reconciliationUnknown
        (EffectState.indeterminate operation attempt)
  | reenterCommitted
      (receipt : CommitReceipt) :
      Step
        (EffectState.committed receipt)
        EffectEvent.continuationReentry
        (EffectState.committed receipt)

inductive Trace : EffectState → List EffectEvent → EffectState → Prop where
  | nil
      (state : EffectState) :
      Trace state [] state
  | cons
      {source middle target : EffectState}
      {event : EffectEvent}
      {events : List EffectEvent}
      (head : Step source event middle)
      (tail : Trace middle events target) :
      Trace source (event :: events) target

def commitCost : EffectEvent → Nat
  | EffectEvent.verifiedCommit _ => 1
  | EffectEvent.reconciliationCommitted _ => 1
  | _ => 0

def commitCount : List EffectEvent → Nat
  | [] => 0
  | event :: events => commitCost event + commitCount events

def commitBudget : EffectState → Nat
  | EffectState.committed _ => 0
  | _ => 1

theorem stepCommitAccounting
    {source target : EffectState}
    {event : EffectEvent}
    (transition : Step source event target) :
    commitCost event + commitBudget target ≤ commitBudget source := by
  cases transition <;> simp [commitCost, commitBudget]

theorem traceCommitAccounting
    {source target : EffectState}
    {events : List EffectEvent}
    (trace : Trace source events target) :
    commitCount events + commitBudget target ≤ commitBudget source := by
  induction trace with
  | nil state =>
      simp [commitCount]
  | @cons source middle target event events head tail inductionHypothesis =>
      have tailAccounting :
          commitCost event +
              (commitCount events + commitBudget target) ≤
            commitCost event + commitBudget middle :=
        Nat.add_le_add_left inductionHypothesis (commitCost event)
      have headAccounting :
          commitCost event + commitBudget middle ≤
            commitBudget source :=
        stepCommitAccounting head
      exact
        (by
          simpa [commitCount, Nat.add_assoc] using
            Nat.le_trans tailAccounting headAccounting)

theorem traceAcceptsAtMostOneCommit
    {source target : EffectState}
    {events : List EffectEvent}
    (trace : Trace source events target) :
    commitCount events ≤ 1 := by
  have countBelowAccounting :
      commitCount events ≤ commitCount events + commitBudget target :=
    Nat.le_add_right (commitCount events) (commitBudget target)
  have sourceBudget : commitBudget source ≤ 1 := by
    cases source <;> simp [commitBudget]
  exact
    Nat.le_trans countBelowAccounting
      (Nat.le_trans (traceCommitAccounting trace) sourceBudget)

structure LinearizableExecution (source : EffectState) where
  events : List EffectEvent
  target : EffectState
  linearization : Trace source events target

theorem linearizableExecutionAcceptsAtMostOneCommit
    {source : EffectState}
    (execution : LinearizableExecution source) :
    commitCount execution.events ≤ 1 := by
  exact traceAcceptsAtMostOneCommit execution.linearization

def SameSnapshotDoubleCommitPossible : Prop :=
  ∃ operation : OperationId,
  ∃ attempt : AttemptId,
  ∃ left right : CommitReceipt,
    left ≠ right ∧
    Step
      (EffectState.inFlight operation attempt)
      (EffectEvent.verifiedCommit left)
      (EffectState.committed left) ∧
    Step
      (EffectState.inFlight operation attempt)
      (EffectEvent.verifiedCommit right)
      (EffectState.committed right)

theorem sameSnapshotDoubleCommitCounterexample :
    SameSnapshotDoubleCommitPossible := by
  let left : CommitReceipt :=
    { operation := 11
      attempt := 5
      verifierEvidence := 1 }
  let right : CommitReceipt :=
    { operation := 11
      attempt := 5
      verifierEvidence := 2 }
  refine ⟨11, 5, left, right, ?_, ?_, ?_⟩
  · decide
  · exact Step.commit 11 5 left rfl rfl
  · exact Step.commit 11 5 right rfl rfl

inductive CommitDecision where
  | accepted (receipt : CommitReceipt)
  | duplicate (receipt : CommitReceipt)
  | conflictingTerminalEvidence
      (existing proposed : CommitReceipt)
deriving Repr, DecidableEq

inductive AtomicCommitArbitration :
    EffectState → CommitReceipt → CommitDecision → EffectState → Prop where
  | accept
      (operation : OperationId)
      (attempt : AttemptId)
      (proposed : CommitReceipt)
      (operationMatches : proposed.operation = operation)
      (attemptMatches : proposed.attempt = attempt) :
      AtomicCommitArbitration
        (EffectState.inFlight operation attempt)
        proposed
        (CommitDecision.accepted proposed)
        (EffectState.committed proposed)
  | duplicate
      (existing proposed : CommitReceipt)
      (sameReceipt : proposed = existing) :
      AtomicCommitArbitration
        (EffectState.committed existing)
        proposed
        (CommitDecision.duplicate existing)
        (EffectState.committed existing)
  | conflict
      (existing proposed : CommitReceipt)
      (differentReceipt : proposed ≠ existing)
      (operationMatches : proposed.operation = existing.operation)
      (attemptMatches : proposed.attempt = existing.attempt) :
      AtomicCommitArbitration
        (EffectState.committed existing)
        proposed
        (CommitDecision.conflictingTerminalEvidence existing proposed)
        (EffectState.committed existing)

theorem repeatedReceiptIsIdempotent
    (receipt : CommitReceipt) :
    AtomicCommitArbitration
      (EffectState.committed receipt)
      receipt
      (CommitDecision.duplicate receipt)
      (EffectState.committed receipt) := by
  exact AtomicCommitArbitration.duplicate receipt receipt rfl

theorem conflictingReceiptCannotOverwrite
    (existing proposed : CommitReceipt)
    (differentReceipt : proposed ≠ existing)
    (operationMatches : proposed.operation = existing.operation)
    (attemptMatches : proposed.attempt = existing.attempt) :
    AtomicCommitArbitration
      (EffectState.committed existing)
      proposed
      (CommitDecision.conflictingTerminalEvidence existing proposed)
      (EffectState.committed existing) := by
  exact
    AtomicCommitArbitration.conflict
      existing proposed differentReceipt operationMatches attemptMatches

theorem arbitrationNeverOverwritesCommitted
    (existing proposed : CommitReceipt)
    (decision : CommitDecision)
    (target : EffectState)
    (arbitration :
      AtomicCommitArbitration
        (EffectState.committed existing)
        proposed
        decision
        target) :
    target = EffectState.committed existing := by
  cases arbitration <;> rfl

theorem acceptedCommitCannotBeAcceptedAgain
    {source middle target : EffectState}
    {firstProposal secondProposal : CommitReceipt}
    (first :
      AtomicCommitArbitration
        source
        firstProposal
        (CommitDecision.accepted firstProposal)
        middle)
    (second :
      AtomicCommitArbitration
        middle
        secondProposal
        (CommitDecision.accepted secondProposal)
        target) :
    False := by
  cases first
  cases second

theorem acceptedArbitrationCommitsProposal
    {source target : EffectState}
    (proposal : CommitReceipt)
    (arbitration :
      AtomicCommitArbitration
        source
        proposal
        (CommitDecision.accepted proposal)
        target) :
    target = EffectState.committed proposal := by
  cases arbitration
  rfl

structure RuntimeArbitrationReceipt where
  beforeState : EffectState
  proposal : CommitReceipt
  decision : CommitDecision
  afterState : EffectState
  runtimeOwner : String
  terminalKeyDigest : Nat
  arbitrationSequence : Nat
  refines :
    AtomicCommitArbitration
      beforeState
      proposal
      decision
      afterState

theorem runtimeArbitrationReceiptProvidesLinearization
    (receipt : RuntimeArbitrationReceipt) :
    AtomicCommitArbitration
      receipt.beforeState
      receipt.proposal
      receipt.decision
      receipt.afterState := by
  exact receipt.refines

theorem acceptedRuntimeReceiptCommitsProposal
    (receipt : RuntimeArbitrationReceipt)
    (accepted :
      receipt.decision = CommitDecision.accepted receipt.proposal) :
    receipt.afterState = EffectState.committed receipt.proposal := by
  exact
    acceptedArbitrationCommitsProposal
      receipt.proposal
      (by simpa [accepted] using receipt.refines)

theorem duplicateRuntimeReceiptPreservesCommittedState
    (receipt : RuntimeArbitrationReceipt)
    (existing : CommitReceipt)
    (before :
      receipt.beforeState = EffectState.committed existing)
    (duplicate :
      receipt.decision = CommitDecision.duplicate existing) :
    receipt.afterState = EffectState.committed existing := by
  have arbitration := receipt.refines
  rw [before, duplicate] at arbitration
  exact
    arbitrationNeverOverwritesCommitted
      existing receipt.proposal receipt.decision receipt.afterState
      (by simpa [duplicate] using arbitration)

theorem conflictingRuntimeReceiptCannotOverwrite
    (receipt : RuntimeArbitrationReceipt)
    (existing : CommitReceipt)
    (before :
      receipt.beforeState = EffectState.committed existing)
    (conflict :
      receipt.decision =
        CommitDecision.conflictingTerminalEvidence
          existing receipt.proposal) :
    receipt.afterState = EffectState.committed existing := by
  have arbitration := receipt.refines
  rw [before, conflict] at arbitration
  exact
    arbitrationNeverOverwritesCommitted
      existing receipt.proposal receipt.decision receipt.afterState
      (by simpa [conflict] using arbitration)

theorem failedRetryPreservesCausalLink
    (operation : OperationId)
    (attempt : AttemptId)
    (authorization : RetryAuthorization)
    (target : EffectState)
    (transition :
      Step
        (EffectState.failed operation attempt)
        (EffectEvent.policyRetry authorization)
        target) :
    authorization.operation = operation ∧
      authorization.priorAttempt = attempt ∧
      authorization.nextAttempt ≠ attempt ∧
      target =
        EffectState.inFlight operation authorization.nextAttempt := by
  cases transition with
  | retryFailed _ _ _ operationMatches attemptMatches freshAttempt =>
      exact
        ⟨operationMatches, attemptMatches,
          by simpa [attemptMatches] using freshAttempt,
          rfl⟩

theorem cancelledRetryPreservesCausalLink
    (operation : OperationId)
    (attempt : AttemptId)
    (authorization : RetryAuthorization)
    (target : EffectState)
    (transition :
      Step
        (EffectState.cancelled operation attempt)
        (EffectEvent.policyRetry authorization)
        target) :
    authorization.operation = operation ∧
      authorization.priorAttempt = attempt ∧
      authorization.nextAttempt ≠ attempt ∧
      target =
        EffectState.inFlight operation authorization.nextAttempt := by
  cases transition with
  | restartCancelled _ _ _ operationMatches attemptMatches freshAttempt =>
      exact
        ⟨operationMatches, attemptMatches,
          by simpa [attemptMatches] using freshAttempt,
          rfl⟩

theorem reconciliationNoCommitEnablesFreshRetry
    (operation : OperationId)
    (attempt : AttemptId)
    (capability : ReconciliationCapability)
    (authorization : RetryAuthorization)
    (capabilityMatches : capability.operation = operation)
    (authorizationMatches : authorization.operation = operation)
    (priorAttemptMatches : authorization.priorAttempt = attempt)
    (freshAttempt :
      authorization.nextAttempt ≠ authorization.priorAttempt) :
    Trace
      (EffectState.indeterminate operation attempt)
      [ EffectEvent.requestReconciliation capability
      , EffectEvent.reconciliationNoCommit
      , EffectEvent.policyRetry authorization
      ]
      (EffectState.inFlight operation authorization.nextAttempt) := by
  exact
    Trace.cons
      (Step.startReconciliation
        operation attempt capability capabilityMatches)
      (Trace.cons
        (Step.reconcileNoCommit operation attempt)
        (Trace.cons
          (Step.retryFailed
            operation attempt authorization
            authorizationMatches priorAttemptMatches freshAttempt)
          (Trace.nil
            (EffectState.inFlight
              operation authorization.nextAttempt))))

theorem committedTracePreservesReceipt
    (receipt : CommitReceipt)
    {events : List EffectEvent}
    {target : EffectState}
    (trace : Trace (EffectState.committed receipt) events target) :
    target = EffectState.committed receipt := by
  induction events with
  | nil =>
      cases trace
      rfl
  | cons event events inductionHypothesis =>
      cases trace with
      | cons head tail =>
          cases head
          exact inductionHypothesis tail

theorem functionReturnCannotEstablishCommit
    (operation : OperationId)
    (attempt : AttemptId)
    (receipt : CommitReceipt) :
    ¬ Step
      (EffectState.inFlight operation attempt)
      EffectEvent.functionReturned
      (EffectState.committed receipt) := by
  intro transition
  cases transition

theorem indeterminateCannotRetryDirectly
    (operation : OperationId)
    (attempt : AttemptId)
    (authorization : RetryAuthorization)
    (target : EffectState) :
    ¬ Step
      (EffectState.indeterminate operation attempt)
      (EffectEvent.policyRetry authorization)
      target := by
  intro transition
  cases transition

theorem indeterminateCanOnlyStartReconciliation
    (operation : OperationId)
    (attempt : AttemptId)
    (event : EffectEvent)
    (target : EffectState)
    (transition :
      Step (EffectState.indeterminate operation attempt) event target) :
    ∃ capability : ReconciliationCapability,
      event = EffectEvent.requestReconciliation capability ∧
      capability.operation = operation := by
  cases transition
  case startReconciliation capability operationMatches =>
    exact ⟨capability, rfl, operationMatches⟩

theorem indeterminateRetryRequiresPriorReconciliation
    (operation : OperationId)
    (attempt : AttemptId)
    (authorization : RetryAuthorization)
    {events : List EffectEvent}
    {target : EffectState}
    (trace :
      Trace
        (EffectState.indeterminate operation attempt)
        events
        target)
    (retryOccurs :
      EffectEvent.policyRetry authorization ∈ events) :
    ∃ capability : ReconciliationCapability,
      ∃ remaining : List EffectEvent,
        events =
          EffectEvent.requestReconciliation capability :: remaining ∧
        EffectEvent.policyRetry authorization ∈ remaining := by
  cases trace with
  | nil =>
      simp at retryOccurs
  | @cons source middle target event remaining head tail =>
      obtain ⟨capability, eventMatches, capabilityMatches⟩ :=
        indeterminateCanOnlyStartReconciliation
          operation attempt event middle head
      subst event
      exact
        ⟨capability, remaining, rfl, by simpa using retryOccurs⟩

theorem committedContinuationReentryPreservesReceipt
    (receipt : CommitReceipt)
    (target : EffectState)
    (transition :
      Step
        (EffectState.committed receipt)
        EffectEvent.continuationReentry
        target) :
    target = EffectState.committed receipt := by
  cases transition
  rfl

theorem committedStateCannotPolicyRetry
    (receipt : CommitReceipt)
    (authorization : RetryAuthorization)
    (target : EffectState) :
    ¬ Step
      (EffectState.committed receipt)
      (EffectEvent.policyRetry authorization)
      target := by
  intro transition
  cases transition

theorem verifiedCommitReceiptMatchesExecution
    (operation : OperationId)
    (attempt : AttemptId)
    (receipt : CommitReceipt)
    (transition :
      Step
        (EffectState.inFlight operation attempt)
        (EffectEvent.verifiedCommit receipt)
        (EffectState.committed receipt)) :
    receipt.operation = operation ∧ receipt.attempt = attempt := by
  cases transition with
  | commit _ _ _ operationMatches attemptMatches =>
      exact ⟨operationMatches, attemptMatches⟩

end AgenticAILabProof.PooC4.EffectBoundary
