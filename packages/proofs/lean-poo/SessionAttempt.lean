/- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
   SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later -/
import Lean
namespace AgenticAILabSessionAttemptProof
def quintSourceDigest : String := "sha256:2857ad1bc556179f034255a93537a136f08dcc21cd46458a6af18fef206f58b4"
def quintInvariantNames : List String := ["ExactAttempt", "RecoveryPreservesObligation", "ClosedIsTerminal"]
-- Pure owner-coordinate projection. Binding includes every native routing/input field.
-- Producer receipt resolution and runtime publication are outside these laws.
structure Schedule (α : Type) where
  revision : Nat
  generation : Nat
  closed : Bool
  active : Option (Nat × α)
  pending : List (Nat × α)

def recover (s : Schedule α) : Option (Schedule α) :=
  if s.closed then none else
    some { s with revision := s.revision + 1, generation := s.generation + 1,
                  active := none, pending := s.active.toList ++ s.pending }

def complete [DecidableEq α] (s : Schedule α) (expectedRevision : Nat)
    (request : Nat × α) : Option (Schedule α) :=
  if s.revision = expectedRevision ∧ s.closed = false ∧ s.active = some request
  then some { s with revision := s.revision + 1, active := none }
  else none

theorem closed_recovery_refused (s : Schedule α) (closed : s.closed = true) :
    recover s = none := by simp [recover, closed]
theorem recovery_generation_advances (s : Schedule α) (openState : s.closed = false) :
    (recover s).map Schedule.generation = some (s.generation + 1) := by
  simp [recover, openState]
theorem recovery_revision_advances (s : Schedule α) (openState : s.closed = false) :
    (recover s).map Schedule.revision = some (s.revision + 1) := by
  simp [recover, openState]
theorem recovery_keeps_obligations (s : Schedule α) (openState : s.closed = false) :
    (recover s).map Schedule.pending = some (s.active.toList ++ s.pending) := by
  simp [recover, openState]
theorem recovery_fences_active (s : Schedule α) (openState : s.closed = false) :
    (recover s).map Schedule.active = some none := by simp [recover, openState]
theorem wrong_revision_refused [DecidableEq α] (s : Schedule α) (r : Nat)
    (request : Nat × α) (wrong : s.revision ≠ r) : complete s r request = none := by
  simp [complete, wrong]
theorem wrong_attempt_refused [DecidableEq α] (s : Schedule α) (r : Nat)
    (request : Nat × α) (wrong : s.active ≠ some request) : complete s r request = none := by
  simp [complete, wrong]
theorem accepted_has_exact_attempt [DecidableEq α] (s result : Schedule α) (r : Nat)
    (request : Nat × α) (accepted : complete s r request = some result) :
    s.revision = r ∧ s.closed = false ∧ s.active = some request := by
  unfold complete at accepted
  split at accepted
  · assumption
  · simp at accepted
end AgenticAILabSessionAttemptProof

open Lean Elab Command in
run_cmd do
  let environment ← getEnv
  let allowed := #[`propext, `Classical.choice, `Quot.sound]
  let mut count : Nat := 0
  for (name, info) in environment.constants.toList do
    if (`AgenticAILabSessionAttemptProof).isPrefixOf name then
      if info.isTheorem then count := count + 1
      for axiomName in (← collectAxioms name) do
        unless allowed.contains axiomName do
          throwError "{name} depends on disallowed axiom {axiomName}"
  for required in #[`AgenticAILabSessionAttemptProof.closed_recovery_refused,
      `AgenticAILabSessionAttemptProof.recovery_generation_advances,
      `AgenticAILabSessionAttemptProof.recovery_revision_advances,
      `AgenticAILabSessionAttemptProof.recovery_keeps_obligations,
      `AgenticAILabSessionAttemptProof.recovery_fences_active,
      `AgenticAILabSessionAttemptProof.wrong_revision_refused,
      `AgenticAILabSessionAttemptProof.wrong_attempt_refused,
      `AgenticAILabSessionAttemptProof.accepted_has_exact_attempt] do
    unless environment.contains required do throwError "Missing Attempt theorem: {required}"
  logInfo m!"SESSION-ATTEMPT-AXIOM-AUDIT-OK: {count} theorems; standard Lean axioms only"
