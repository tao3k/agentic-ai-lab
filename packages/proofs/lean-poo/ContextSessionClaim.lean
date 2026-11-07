-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import Lean
namespace AgenticAILabContextSessionClaimProof
-- Metadata freshness only, never Scheme refinement or authenticated-source proof.
def quintSourceDigest : String := "sha256:e0c6d46354ca44a3e79b9cbc61b42c789dc544e01d69033fcb191d25e088e9bf"
def quintInvariantNames : List String := ["ExactOwner", "ExactSource", "CurrentGrant",
  "EnabledGrant", "EffectiveClock", "CurrentAnchor", "PendingPreserved", "FixedScope"]

structure Gates where
  expectedOwner : Nat
  currentOwner : Nat
  expectedSource : Nat
  currentSource : Nat
  expectedGrant : Nat
  currentGrant : Nat
  grantEnabled : Bool
  effectiveClock : Bool
  currentAnchor : Bool
  idle : Bool
  deriving DecidableEq

def admissible (g : Gates) : Prop :=
  g.expectedOwner = g.currentOwner ∧ g.expectedSource = g.currentSource ∧
  g.expectedGrant = g.currentGrant ∧ g.grantEnabled = true ∧
  g.effectiveClock = true ∧ g.currentAnchor = true ∧ g.idle = true
instance (g : Gates) : Decidable (admissible g) := inferInstanceAs (Decidable (_ ∧ _ ∧ _ ∧ _ ∧ _ ∧ _ ∧ _))
def claim (g : Gates) : Option Nat := if admissible g then some (g.currentOwner + 1) else none

theorem accepted_has_all_current_gates (g : Gates) (result : Nat)
    (accepted : claim g = some result) : admissible g := by
  unfold claim at accepted
  split at accepted
  · assumption
  · simp at accepted

theorem accepted_increments_owner (g : Gates) (result : Nat)
    (accepted : claim g = some result) : result = g.currentOwner + 1 := by
  unfold claim at accepted
  split at accepted
  · simpa using accepted.symm
  · simp at accepted

theorem stale_owner_refused (g : Gates) (wrong : g.expectedOwner ≠ g.currentOwner) :
    claim g = none := by simp [claim, admissible, wrong]
theorem stale_source_refused (g : Gates) (wrong : g.expectedSource ≠ g.currentSource) :
    claim g = none := by simp [claim, admissible, wrong]
theorem stale_grant_refused (g : Gates) (wrong : g.expectedGrant ≠ g.currentGrant) :
    claim g = none := by simp [claim, admissible, wrong]
theorem revoked_grant_refused (g : Gates) (revoked : g.grantEnabled = false) :
    claim g = none := by simp [claim, admissible, revoked]
theorem expired_clock_refused (g : Gates) (expired : g.effectiveClock = false) :
    claim g = none := by simp [claim, admissible, expired]
theorem missing_anchor_refused (g : Gates) (missing : g.currentAnchor = false) :
    claim g = none := by simp [claim, admissible, missing]
theorem pending_or_active_refused (g : Gates) (busy : g.idle = false) :
    claim g = none := by simp [claim, admissible, busy]
end AgenticAILabContextSessionClaimProof

open Lean Elab Command in
run_cmd do
  let environment ← getEnv
  let allowed := #[`propext, `Classical.choice, `Quot.sound]
  let mut count : Nat := 0
  for (name, info) in environment.constants.toList do
    if (`AgenticAILabContextSessionClaimProof).isPrefixOf name then
      if info.isTheorem then count := count + 1
      for axiomName in (← collectAxioms name) do
        unless allowed.contains axiomName do throwError "Disallowed claim axiom: {axiomName}"
  for required in #[`AgenticAILabContextSessionClaimProof.accepted_has_all_current_gates,
      `AgenticAILabContextSessionClaimProof.accepted_increments_owner,
      `AgenticAILabContextSessionClaimProof.stale_owner_refused,
      `AgenticAILabContextSessionClaimProof.stale_source_refused,
      `AgenticAILabContextSessionClaimProof.stale_grant_refused,
      `AgenticAILabContextSessionClaimProof.revoked_grant_refused,
      `AgenticAILabContextSessionClaimProof.expired_clock_refused,
      `AgenticAILabContextSessionClaimProof.missing_anchor_refused,
      `AgenticAILabContextSessionClaimProof.pending_or_active_refused] do
    unless environment.contains required do throwError "Missing claim theorem: {required}"
  logInfo m!"CONTEXT-SESSION-CLAIM-AXIOM-AUDIT-OK: {count} theorems; standard Lean axioms only"
