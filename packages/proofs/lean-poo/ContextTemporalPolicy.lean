-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import Lean
namespace AgenticAILabContextTemporalPolicyProof
-- Exact source metadata, not semantic refinement or an authenticated owner.
def quintSourceDigest : String := "sha256:61a322e9ffa316c0d3371734bca70fb1f68d7e6b1f758579f10fd59906000708"
def quintInvariantNames : List String := ["ExactSource", "ExactTemporal", "ExactPolicy", "CurrentEvidence",
  "ComparableClock", "ConservativeWindow", "TerminalReceipt", "NoResurrection", "NoObligationResurrection"]
structure Window where
  domain : Nat
  start : Nat
  finish : Nat
structure Observation where
  domain : Nat
  earliest : Nat
  latest : Nat
  observed : Bool

def eligible (w : Window) (c : Observation) : Prop :=
  w.domain = c.domain ∧ c.observed = true ∧
  w.start ≤ c.earliest ∧ c.earliest ≤ c.latest ∧ c.latest < w.finish
instance (w : Window) (c : Observation) : Decidable (eligible w c) :=
  inferInstanceAs (Decidable (_ ∧ _ ∧ _ ∧ _ ∧ _))
def assess (w : Window) (c : Observation) : Bool := if eligible w c then true else false

theorem accepted_has_whole_interval (w : Window) (c : Observation)
    (accepted : assess w c = true) : eligible w c := by
  unfold assess at accepted
  split at accepted
  · assumption
  · simp at accepted

theorem accepted_upper_is_strict (w : Window) (c : Observation)
    (accepted : assess w c = true) : c.latest < w.finish :=
  (accepted_has_whole_interval w c accepted).2.2.2.2

theorem foreign_domain_refused (w : Window) (c : Observation) (wrong : w.domain ≠ c.domain) :
    assess w c = false := by simp [assess, eligible, wrong]
theorem unobserved_clock_refused (w : Window) (c : Observation) (unknown : c.observed = false) :
    assess w c = false := by simp [assess, eligible, unknown]
theorem upper_boundary_refused (w : Window) (c : Observation) (outside : w.finish ≤ c.latest) :
    assess w c = false := by simp [assess, eligible, Nat.not_lt.mpr outside]
theorem lower_boundary_refused (w : Window) (c : Observation) (outside : c.earliest < w.start) :
    assess w c = false := by simp [assess, eligible, Nat.not_le.mpr outside]

-- Independent owner revisions. This is a guard theorem, not a distributed transaction.
structure Cut where
  source : Nat
  temporal : Nat
  policy : Nat
  deriving DecidableEq

def admit (expected current : Cut) (supported : Bool) (w : Window) (c : Observation) : Option Cut :=
  if expected = current ∧ supported = true ∧ eligible w c then some current else none

theorem accepted_has_exact_current_vector (e a : Cut) (supported : Bool) (w : Window)
    (c : Observation) (result : Cut) (accepted : admit e a supported w c = some result) :
    e = a ∧ supported = true ∧ eligible w c := by
  unfold admit at accepted
  split at accepted
  · assumption
  · simp at accepted

theorem stale_source_refused (e a : Cut) (supported : Bool) (w : Window) (c : Observation)
    (wrong : e.source ≠ a.source) : admit e a supported w c = none := by
  have different : e ≠ a := fun equal => wrong (congrArg Cut.source equal)
  simp [admit, different]
theorem stale_temporal_refused (e a : Cut) (supported : Bool) (w : Window) (c : Observation)
    (wrong : e.temporal ≠ a.temporal) : admit e a supported w c = none := by
  have different : e ≠ a := fun equal => wrong (congrArg Cut.temporal equal)
  simp [admit, different]
theorem stale_policy_refused (e a : Cut) (supported : Bool) (w : Window) (c : Observation)
    (wrong : e.policy ≠ a.policy) : admit e a supported w c = none := by
  have different : e ≠ a := fun equal => wrong (congrArg Cut.policy equal)
  simp [admit, different]
theorem refuted_evidence_refused (e a : Cut) (w : Window) (c : Observation) :
    admit e a false w c = none := by simp [admit]
-- A later source/policy event preserves pending work but cannot recreate settled work.
def invalidatePending (outstanding settled pending : Bool) : Bool :=
  pending || (outstanding && !settled)
theorem settled_obligation_stays_clear (outstanding : Bool) :
    invalidatePending outstanding true false = false := by simp [invalidatePending]
theorem unresolved_obligation_preserved (outstanding settled : Bool) :
    invalidatePending outstanding settled true = true := by simp [invalidatePending]
end AgenticAILabContextTemporalPolicyProof

open Lean Elab Command in
run_cmd do
  let environment ← getEnv
  let allowed := #[`propext, `Classical.choice, `Quot.sound]
  let mut count : Nat := 0
  for (name, info) in environment.constants.toList do
    if (`AgenticAILabContextTemporalPolicyProof).isPrefixOf name then
      if info.isTheorem then count := count + 1
      for axiomName in (← collectAxioms name) do
        unless allowed.contains axiomName do throwError "Disallowed temporal policy axiom: {axiomName}"
  for required in #[`AgenticAILabContextTemporalPolicyProof.accepted_has_whole_interval,
      `AgenticAILabContextTemporalPolicyProof.accepted_upper_is_strict,
      `AgenticAILabContextTemporalPolicyProof.foreign_domain_refused,
      `AgenticAILabContextTemporalPolicyProof.unobserved_clock_refused,
      `AgenticAILabContextTemporalPolicyProof.upper_boundary_refused,
      `AgenticAILabContextTemporalPolicyProof.lower_boundary_refused,
      `AgenticAILabContextTemporalPolicyProof.accepted_has_exact_current_vector,
      `AgenticAILabContextTemporalPolicyProof.stale_source_refused,
      `AgenticAILabContextTemporalPolicyProof.stale_temporal_refused,
      `AgenticAILabContextTemporalPolicyProof.stale_policy_refused,
      `AgenticAILabContextTemporalPolicyProof.refuted_evidence_refused,
      `AgenticAILabContextTemporalPolicyProof.settled_obligation_stays_clear,
      `AgenticAILabContextTemporalPolicyProof.unresolved_obligation_preserved] do
    unless environment.contains required do throwError "Missing temporal policy theorem: {required}"
  logInfo m!"CONTEXT-TEMPORAL-POLICY-AXIOM-AUDIT-OK: {count} theorems; standard Lean axioms only"
