-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryConvergenceClosure

open SourceBoundEffectCompletionCrashRecoveryClosure
open SourceBoundEffectCompletionPublicationClosure
open SourceBoundEffectReplayIdempotencyClosure

inductive SourceBoundEffectCompletionRecoveryTransition :
    SourceBoundEffectCompletionCrashRecoveryState →
      SourceBoundEffectCompletionCrashRecoveryState →
      Prop where
  | waitNotExecuted :
      SourceBoundEffectCompletionRecoveryTransition .notExecuted .notExecuted
  | providerAcknowledged :
      SourceBoundEffectCompletionRecoveryTransition .notExecuted .executedUncommitted
  | notExecutedIndeterminate :
      SourceBoundEffectCompletionRecoveryTransition .notExecuted .indeterminate
  | retryPublication :
      SourceBoundEffectCompletionRecoveryTransition
        .executedUncommitted
        .executedUncommitted
  | publicationCommitted :
      SourceBoundEffectCompletionRecoveryTransition .executedUncommitted .committed
  | publicationIndeterminate :
      SourceBoundEffectCompletionRecoveryTransition .executedUncommitted .indeterminate
  | committedAbsorbing :
      SourceBoundEffectCompletionRecoveryTransition .committed .committed
  | reobserveNotExecuted :
      SourceBoundEffectCompletionRecoveryTransition .indeterminate .notExecuted
  | reobserveAcknowledged :
      SourceBoundEffectCompletionRecoveryTransition .indeterminate .executedUncommitted
  | recoverCommittedEvidence :
      SourceBoundEffectCompletionRecoveryTransition .indeterminate .committed
  | remainIndeterminate :
      SourceBoundEffectCompletionRecoveryTransition .indeterminate .indeterminate

abbrev SourceBoundEffectCompletionRecoveryTrace :=
  Nat → SourceBoundEffectCompletionCrashRecoveryState

def SourceBoundEffectCompletionRecoveryTraceTransitionClosed
    (trace : SourceBoundEffectCompletionRecoveryTrace) : Prop :=
  ∀ sequence,
    SourceBoundEffectCompletionRecoveryTransition
      (trace sequence)
      (trace (sequence + 1))

def SourceBoundEffectCompletionRecoveryTraceReachesCommit
    (trace : SourceBoundEffectCompletionRecoveryTrace) : Prop :=
  ∃ sequence, trace sequence = .committed

def SourceBoundEffectCompletionRecoveryTraceCommittedAbsorbing
    (trace : SourceBoundEffectCompletionRecoveryTrace) : Prop :=
  ∀ sequence,
    trace sequence = .committed →
      trace (sequence + 1) = .committed

def SourceBoundEffectCompletionRecoveryTraceConverges
    (trace : SourceBoundEffectCompletionRecoveryTrace) : Prop :=
  SourceBoundEffectCompletionRecoveryTraceReachesCommit trace ∧
  SourceBoundEffectCompletionRecoveryTraceCommittedAbsorbing trace

def stalledExecutedUncommittedRecoveryTrace :
    SourceBoundEffectCompletionRecoveryTrace :=
  fun _ => .executedUncommitted

theorem stalledExecutedUncommittedRecoveryTraceIsTransitionClosed :
    SourceBoundEffectCompletionRecoveryTraceTransitionClosed
      stalledExecutedUncommittedRecoveryTrace := by
  intro sequence
  exact SourceBoundEffectCompletionRecoveryTransition.retryPublication

theorem stalledExecutedUncommittedRecoveryTraceNeverCommits :
    ¬ SourceBoundEffectCompletionRecoveryTraceReachesCommit
      stalledExecutedUncommittedRecoveryTrace := by
  intro hreaches
  rcases hreaches with ⟨sequence, hcommitted⟩
  simp [stalledExecutedUncommittedRecoveryTrace] at hcommitted

theorem transitionSafetyDoesNotEntailRecoveryConvergence :
    ∃ trace,
      SourceBoundEffectCompletionRecoveryTraceTransitionClosed trace ∧
      ¬ SourceBoundEffectCompletionRecoveryTraceConverges trace := by
  refine ⟨stalledExecutedUncommittedRecoveryTrace, ?_, ?_⟩
  · exact stalledExecutedUncommittedRecoveryTraceIsTransitionClosed
  · intro hconverges
    exact
      stalledExecutedUncommittedRecoveryTraceNeverCommits
        hconverges.1

def SourceBoundEffectCompletionRecoveryTraceStrictlyRanked
    (trace : SourceBoundEffectCompletionRecoveryTrace)
    (rank : Nat → Nat) : Prop :=
  ∀ sequence,
    trace sequence ≠ .committed →
      rank (sequence + 1) < rank sequence

theorem strictlyRankedRecoveryTraceReachesCommit
    (trace : SourceBoundEffectCompletionRecoveryTrace)
    (rank : Nat → Nat)
    (hranked :
      SourceBoundEffectCompletionRecoveryTraceStrictlyRanked trace rank) :
    SourceBoundEffectCompletionRecoveryTraceReachesCommit trace := by
  apply Classical.byContradiction
  intro hnever
  have hnotCommitted : ∀ sequence, trace sequence ≠ .committed := by
    intro sequence hcommitted
    exact hnever ⟨sequence, hcommitted⟩
  let rec contradictionFrom
      (remaining sequence : Nat)
      (hrank : rank sequence = remaining) :
      False :=
    have hdecreases :
        rank (sequence + 1) < remaining := by
      simpa [hrank] using hranked sequence (hnotCommitted sequence)
    contradictionFrom
      (rank (sequence + 1))
      (sequence + 1)
      rfl
  termination_by remaining
  decreasing_by exact hdecreases
  exact contradictionFrom (rank 0) 0 rfl

theorem committedRecoveryTransitionHasCommittedTarget
    {next : SourceBoundEffectCompletionCrashRecoveryState}
    (htransition :
      SourceBoundEffectCompletionRecoveryTransition .committed next) :
    next = .committed := by
  cases htransition
  rfl

theorem transitionClosedRecoveryTraceKeepsCommitAbsorbing
    (trace : SourceBoundEffectCompletionRecoveryTrace)
    (hclosed :
      SourceBoundEffectCompletionRecoveryTraceTransitionClosed trace) :
    SourceBoundEffectCompletionRecoveryTraceCommittedAbsorbing trace := by
  intro sequence hcommitted
  have htransition := hclosed sequence
  rw [hcommitted] at htransition
  exact committedRecoveryTransitionHasCommittedTarget htransition

theorem rankedTransitionClosedRecoveryTraceConverges
    (trace : SourceBoundEffectCompletionRecoveryTrace)
    (rank : Nat → Nat)
    (hclosed :
      SourceBoundEffectCompletionRecoveryTraceTransitionClosed trace)
    (hranked :
      SourceBoundEffectCompletionRecoveryTraceStrictlyRanked trace rank) :
    SourceBoundEffectCompletionRecoveryTraceConverges trace := by
  exact
    ⟨ strictlyRankedRecoveryTraceReachesCommit trace rank hranked
    , transitionClosedRecoveryTraceKeepsCommitAbsorbing trace hclosed
    ⟩

theorem stalledRecoveryTraceHasNoStrictNaturalRank
    (rank : Nat → Nat) :
    ¬ SourceBoundEffectCompletionRecoveryTraceStrictlyRanked
      stalledExecutedUncommittedRecoveryTrace
      rank := by
  intro hranked
  exact
    stalledExecutedUncommittedRecoveryTraceNeverCommits
      (strictlyRankedRecoveryTraceReachesCommit
        stalledExecutedUncommittedRecoveryTrace
        rank
        hranked)

structure SourceBoundEffectCompletionRecoveryAttempt where
  attemptId : String
  sequence : Nat
  physicalState : SourceBoundEffectPhysicalCompletionState
  snapshot : SourceBoundEffectCompletionCrashRecoverySnapshot
  classification : SourceBoundEffectCompletionCrashRecoveryClassification
  provenanceDigest : String

def SourceBoundEffectCompletionRecoveryAttemptClosed
    (idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid)
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (commitReceiptValid : SourceBoundEffectCompletionCommitReceiptValid)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (attempt : SourceBoundEffectCompletionRecoveryAttempt) : Prop :=
  attempt.attemptId ≠ "" ∧
  attempt.provenanceDigest ≠ "" ∧
  attempt.snapshot.expectation = expectation ∧
  SourceBoundEffectCompletionCrashRecoveryClassificationClosed
    idempotencyKeyValid
    receiptValid
    commitReceiptValid
    attempt.physicalState
    attempt.snapshot
    attempt.classification

def SourceBoundEffectProviderAcknowledgementMonotone
    (attempts : List SourceBoundEffectCompletionRecoveryAttempt) : Prop :=
  ∀ {earlier later},
    earlier ∈ attempts →
      later ∈ attempts →
        earlier.sequence < later.sequence →
          earlier.snapshot.providerObservation.status = .acknowledged →
            later.snapshot.providerObservation.status = .acknowledged ∧
            later.snapshot.providerObservation.completionReceipt =
              earlier.snapshot.providerObservation.completionReceipt

theorem monotoneAcknowledgementPreservesExactReceipt
    (attempts : List SourceBoundEffectCompletionRecoveryAttempt)
    (hmonotone : SourceBoundEffectProviderAcknowledgementMonotone attempts)
    {earlier later : SourceBoundEffectCompletionRecoveryAttempt}
    (hearlier : earlier ∈ attempts)
    (hlater : later ∈ attempts)
    (hsequence : earlier.sequence < later.sequence)
    (hacknowledged :
      earlier.snapshot.providerObservation.status = .acknowledged) :
    later.snapshot.providerObservation.status = .acknowledged ∧
    later.snapshot.providerObservation.completionReceipt =
      earlier.snapshot.providerObservation.completionReceipt := by
  exact
    hmonotone
      hearlier
      hlater
      hsequence
      hacknowledged

theorem acknowledgedAttemptCannotLaterBecomeAuthoritativeNegative
    (attempts : List SourceBoundEffectCompletionRecoveryAttempt)
    (hmonotone : SourceBoundEffectProviderAcknowledgementMonotone attempts)
    {earlier later : SourceBoundEffectCompletionRecoveryAttempt}
    (hearlier : earlier ∈ attempts)
    (hlater : later ∈ attempts)
    (hsequence : earlier.sequence < later.sequence)
    (hacknowledged :
      earlier.snapshot.providerObservation.status = .acknowledged) :
    later.snapshot.providerObservation.status ≠ .definitelyNotExecuted := by
  have hlaterAcknowledged :=
    (hmonotone hearlier hlater hsequence hacknowledged).1
  intro hnegative
  rw [hlaterAcknowledged] at hnegative
  cases hnegative

theorem advancedGenerationInvalidatesOlderRecoveryObservation
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (currentExpectation : SourceBoundEffectCompletionRecoveryExpectation)
    (olderObservation : SourceBoundEffectProviderRecoveryObservation)
    (hadvanced :
      olderObservation.runtimeEpoch ≠ currentExpectation.runtimeEpoch ∨
      olderObservation.activeFenceToken ≠ currentExpectation.activeFenceToken) :
    ¬ SourceBoundEffectProviderRecoveryObservationClosed
      receiptValid
      currentExpectation
      olderObservation := by
  cases hadvanced with
  | inl hepoch =>
      exact
        staleEpochObservationCannotCloseRecovery
          receiptValid
          currentExpectation
          olderObservation
          hepoch
  | inr hfence =>
      exact
        staleFenceObservationCannotCloseRecovery
          receiptValid
          currentExpectation
          olderObservation
          hfence

structure SourceBoundEffectCompletionRecoveryConvergenceWitness where
  trace : SourceBoundEffectCompletionRecoveryTrace
  rank : Nat → Nat
  history : SourceBoundEffectCompletionPublicationHistory

def SourceBoundEffectCompletionRecoveryConvergenceWitnessClosed
    (idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid)
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (commitReceiptValid : SourceBoundEffectCompletionCommitReceiptValid)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (witness : SourceBoundEffectCompletionRecoveryConvergenceWitness) : Prop :=
  SourceBoundEffectCompletionRecoveryExpectationClosed expectation ∧
  SourceBoundEffectCompletionRecoveryTraceTransitionClosed witness.trace ∧
  SourceBoundEffectCompletionRecoveryTraceStrictlyRanked
    witness.trace
    witness.rank ∧
  SourceBoundEffectCompletionPublicationHistoryClosed
    idempotencyKeyValid
    receiptValid
    commitReceiptValid
    expectation.request
    expectation.window
    expectation.ledger
    expectation.plan
    witness.history

theorem closedRecoveryConvergenceWitnessConverges
    (idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid)
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (commitReceiptValid : SourceBoundEffectCompletionCommitReceiptValid)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (witness : SourceBoundEffectCompletionRecoveryConvergenceWitness)
    (hclosed :
      SourceBoundEffectCompletionRecoveryConvergenceWitnessClosed
        idempotencyKeyValid
        receiptValid
        commitReceiptValid
        expectation
        witness) :
    SourceBoundEffectCompletionRecoveryTraceConverges witness.trace := by
  exact
    rankedTransitionClosedRecoveryTraceConverges
      witness.trace
      witness.rank
      hclosed.2.1
      hclosed.2.2.1

theorem closedRecoveryConvergenceWitnessReusesHistoryKeyUniqueness
    (idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid)
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (commitReceiptValid : SourceBoundEffectCompletionCommitReceiptValid)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (witness : SourceBoundEffectCompletionRecoveryConvergenceWitness)
    (hclosed :
      SourceBoundEffectCompletionRecoveryConvergenceWitnessClosed
        idempotencyKeyValid
        receiptValid
        commitReceiptValid
        expectation
        witness) :
    List.Pairwise
      (fun left right => left ≠ right)
      (historyExecutedKeys witness.history) := by
  exact
    closedCompletionHistorySeparatesCommittedKeys
      hclosed.2.2.2

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryConvergenceClosure
