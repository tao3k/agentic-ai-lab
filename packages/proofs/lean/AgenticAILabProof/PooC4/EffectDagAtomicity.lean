-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.EffectIntentHandoff

namespace AgenticAILabProof.PooC4.EffectDagAtomicity

open AgenticAILabProof.PooC4.EffectIntentHandoff

universe u

abbrev EffectId := Nat

structure PureEffectDag where
  planned : EffectId → Prop
  dependsOn : EffectId → EffectId → Prop
  conflictScopeDisjoint : EffectId → EffectId → Prop
  commutes : EffectId → EffectId → Prop
  semanticStable : EffectId → Prop
  dependencyProjectionPure : EffectId → Prop
  materializationPresent : EffectId → Prop
  runtimeCapabilityValidated : EffectId → Prop
  inUnstableSemanticScc : EffectId → Prop

inductive ObservedEffectOutcome where
  | unknown
  | pending
  | committed
  | failed
deriving Repr, DecidableEq

structure EffectObservation where
  outcome : EffectId → ObservedEffectOutcome

structure StableReady
    (dag : PureEffectDag)
    (observation : EffectObservation)
    (effect : EffectId) : Prop where
  planned : dag.planned effect
  semanticStable : dag.semanticStable effect
  dependencyProjectionPure : dag.dependencyProjectionPure effect
  materializationPresent : dag.materializationPresent effect
  predecessorsCommitted :
    (predecessor : EffectId) →
    dag.dependsOn effect predecessor →
    observation.outcome predecessor = ObservedEffectOutcome.committed
  predecessorsKnown :
    (predecessor : EffectId) →
    dag.dependsOn effect predecessor →
    observation.outcome predecessor ≠ ObservedEffectOutcome.unknown
  runtimeCapabilityValidated : dag.runtimeCapabilityValidated effect
  excludesUnstableSemanticScc : ¬ dag.inUnstableSemanticScc effect

structure StableReadyFrontier
    (dag : PureEffectDag)
    (observation : EffectObservation) where
  contains : EffectId → Prop
  ready :
    (effect : EffectId) →
    contains effect →
    StableReady dag observation effect

structure ParallelSafetyEvidence
    (dag : PureEffectDag)
    {observation : EffectObservation}
    (frontier : StableReadyFrontier dag observation) : Prop where
  safePair :
    (left right : EffectId) →
    frontier.contains left →
    frontier.contains right →
    left ≠ right →
    dag.conflictScopeDisjoint left right ∨ dag.commutes left right

structure RuntimeHandoffBatch
    (Role : Type u)
    (dag : PureEffectDag)
    (observation : EffectObservation) where
  frontier : StableReadyFrontier dag observation
  parallelSafety : ParallelSafetyEvidence dag frontier
  handoff :
    (effect : EffectId) →
    frontier.contains effect →
    StableIntentHandoff Role

theorem batchHandoffRequiresStableReady
    {Role : Type u}
    {dag : PureEffectDag}
    {observation : EffectObservation}
    (batch : RuntimeHandoffBatch Role dag observation)
    (effect : EffectId)
    (present : batch.frontier.contains effect) :
    StableReady dag observation effect :=
  batch.frontier.ready effect present

theorem batchHandoffRequiresParallelSafety
    {Role : Type u}
    {dag : PureEffectDag}
    {observation : EffectObservation}
    (batch : RuntimeHandoffBatch Role dag observation)
    (left right : EffectId)
    (leftPresent : batch.frontier.contains left)
    (rightPresent : batch.frontier.contains right)
    (different : left ≠ right) :
    dag.conflictScopeDisjoint left right ∨ dag.commutes left right :=
  batch.parallelSafety.safePair
    left right leftPresent rightPresent different

theorem batchMemberCarriesAuthorizedStableIntent
    {Role : Type u}
    {dag : PureEffectDag}
    {observation : EffectObservation}
    (batch : RuntimeHandoffBatch Role dag observation)
    (effect : EffectId)
    (present : batch.frontier.contains effect) :
    ∃ handoff : StableIntentHandoff Role,
      batch.handoff effect present = handoff := by
  exact ⟨batch.handoff effect present, rfl⟩

structure CommitHistory where
  committed : EffectId → Prop

def AllOrNothing
    (dag : PureEffectDag)
    (history : CommitHistory) : Prop :=
  ((effect : EffectId) → dag.planned effect → history.committed effect) ∨
  ((effect : EffectId) → dag.planned effect → ¬ history.committed effect)

structure PartialCommitOutcome (dag : PureEffectDag) where
  history : CommitHistory
  committedEffect : EffectId
  failedEffect : EffectId
  committedWasPlanned : dag.planned committedEffect
  failedWasPlanned : dag.planned failedEffect
  committedRecorded : history.committed committedEffect
  failedNotCommitted : ¬ history.committed failedEffect

theorem partialCommitIsNotAtomic
    {dag : PureEffectDag}
    (partialOutcome : PartialCommitOutcome dag) :
    ¬ AllOrNothing dag partialOutcome.history := by
  intro atomic
  cases atomic with
  | inl allCommitted =>
      exact
        partialOutcome.failedNotCommitted
          (allCommitted
            partialOutcome.failedEffect
            partialOutcome.failedWasPlanned)
  | inr noneCommitted =>
      exact
        (noneCommitted
          partialOutcome.committedEffect
          partialOutcome.committedWasPlanned)
          partialOutcome.committedRecorded

inductive CompensationOutcome where
  | committed
  | failed
deriving Repr, DecidableEq

structure CompensationEffect
    {dag : PureEffectDag}
    (partialOutcome : PartialCommitOutcome dag) where
  targetEffect : EffectId
  targetWasCommitted : partialOutcome.history.committed targetEffect
  compensationEffect : EffectId
  compensationIsNew :
    compensationEffect ≠ targetEffect
  outcome : CompensationOutcome

theorem compensationPreservesOriginalCommitHistory
    {dag : PureEffectDag}
    {partialOutcome : PartialCommitOutcome dag}
    (compensation : CompensationEffect partialOutcome) :
    partialOutcome.history.committed compensation.targetEffect :=
  compensation.targetWasCommitted

structure RuntimeAtomicityGuarantee (dag : PureEffectDag) where
  groupIdentity : Nat
  covers :
    (effect : EffectId) →
    dag.planned effect →
    Prop
  coverageProved :
    (effect : EffectId) →
    (planned : dag.planned effect) →
    covers effect planned

structure AtomicHandoffClaim
    (Role : Type u)
    (dag : PureEffectDag)
    (observation : EffectObservation) where
  batch : RuntimeHandoffBatch Role dag observation
  guarantee : RuntimeAtomicityGuarantee dag

theorem atomicityClaimRequiresWholeGroupGuarantee
    {Role : Type u}
    {dag : PureEffectDag}
    {observation : EffectObservation}
    (claim : AtomicHandoffClaim Role dag observation) :
    ∃ guarantee : RuntimeAtomicityGuarantee dag,
      claim.guarantee = guarantee := by
  exact ⟨claim.guarantee, rfl⟩

end AgenticAILabProof.PooC4.EffectDagAtomicity
