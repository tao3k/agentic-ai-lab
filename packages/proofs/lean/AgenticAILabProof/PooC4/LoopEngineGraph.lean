-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.AgentLifecycleTopology

namespace AgenticAILabProof.PooC4.LoopEngineGraph

def ScopeSubset {α : Type} (child parent : α -> Prop) : Prop :=
  ∀ item, child item -> parent item

theorem scope_subset_refl {α : Type} (scope : α -> Prop) :
    ScopeSubset scope scope := by
  intro item h
  exact h

theorem scope_subset_trans {α : Type}
    {a b c : α -> Prop}
    (hab : ScopeSubset a b)
    (hbc : ScopeSubset b c) :
    ScopeSubset a c := by
  intro item h
  exact hbc item (hab item h)

structure LoopStartContract (α : Type) where
  profileScope : α -> Prop
  sessionScope : α -> Prop
  sandboxScope : α -> Prop
  toolScope : α -> Prop
  dependenciesReady : Prop
  exitDefined : Prop
  profileWithinSession : ScopeSubset profileScope sessionScope
  sandboxWithinSession : ScopeSubset sandboxScope sessionScope
  toolWithinSandbox : ScopeSubset toolScope sandboxScope

def loopStartSound {α : Type} (contract : LoopStartContract α) : Prop :=
  contract.dependenciesReady ∧
  contract.exitDefined ∧
  ScopeSubset contract.profileScope contract.sessionScope ∧
  ScopeSubset contract.toolScope contract.sessionScope

theorem tool_scope_within_session {α : Type}
    (contract : LoopStartContract α) :
    ScopeSubset contract.toolScope contract.sessionScope :=
  scope_subset_trans contract.toolWithinSandbox contract.sandboxWithinSession

theorem start_sound_from_contract {α : Type}
    (contract : LoopStartContract α)
    (ready : contract.dependenciesReady)
    (exit : contract.exitDefined) :
    loopStartSound contract := by
  exact ⟨ready, exit, contract.profileWithinSession,
    tool_scope_within_session contract⟩

theorem cannot_start_without_dependencies {α : Type}
    (contract : LoopStartContract α)
    (missing : ¬ contract.dependenciesReady) :
    ¬ loopStartSound contract := by
  intro sound
  exact missing sound.left

theorem cannot_start_without_exit {α : Type}
    (contract : LoopStartContract α)
    (missing : ¬ contract.exitDefined) :
    ¬ loopStartSound contract := by
  intro sound
  exact missing sound.right.left

structure RankedEdge where
  fromRank : Nat
  toRank : Nat
  guard : Prop

def guardedRankProgress (edge : RankedEdge) : Prop :=
  edge.guard ∧ edge.fromRank < edge.toRank

theorem guarded_rank_progress_is_not_self_loop
    (edge : RankedEdge)
    (progress : guardedRankProgress edge) :
    edge.fromRank ≠ edge.toRank := by
  intro same
  exact Nat.lt_irrefl edge.fromRank (by
    simpa [same] using progress.right)

structure LoopTransition where
  fuelBefore : Nat
  fuelAfter : Nat
  guardSatisfied : Prop

def loopFuelProgress (transition : LoopTransition) : Prop :=
  transition.guardSatisfied ∧
  transition.fuelAfter < transition.fuelBefore

theorem no_fuel_progress_from_zero
    (fuelAfter : Nat)
    (guardSatisfied : Prop) :
    ¬ loopFuelProgress
      { fuelBefore := 0
      , fuelAfter := fuelAfter
      , guardSatisfied := guardSatisfied } := by
  intro progress
  exact (Nat.not_lt_zero fuelAfter) progress.right

theorem fuel_progress_requires_guard
    (transition : LoopTransition)
    (progress : loopFuelProgress transition) :
    transition.guardSatisfied :=
  progress.left

end AgenticAILabProof.PooC4.LoopEngineGraph
