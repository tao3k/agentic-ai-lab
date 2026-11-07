-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import Lean
import Lean.Util.CollectAxioms
namespace AgenticAILabContextProof

-- Source freshness only; this metadata is not a semantic refinement proof.
def coverageSourceDigest : String := "sha256:c099a7dc16730a608a576a27df757241f928a2b61c06ed0527d4c7213460442c"
def coverageInvariantNames : List String := ["IncrementalEqualsFull"]
def quintSourceDigest : String := "sha256:21e54b803a31ec72eaaa3999e8b79942e59171162b5e152620f39217d59d986c"
def quintInvariantNames : List String :=
  ["ExactTargetCut", "ExactReconstruction", "OnePublication",
   "CurrentConsumption", "AuthorizedConsumption"]


structure Edit (α : Type) where
  key : Nat
  expected : Option α
  replacement : Option α

def update (units : Nat → Option α) (e : Edit α) : Nat → Option α :=
  fun key => if key = e.key then e.replacement else units key

def applyEdit [DecidableEq α] (units : Nat → Option α) (e : Edit α) :
    Option (Nat → Option α) :=
  if units e.key = e.expected then some (update units e) else none

def applyEdits [DecidableEq α] (units : Nat → Option α) :
    List (Edit α) → Option (Nat → Option α)
  | [] => some units
  | e :: es => (applyEdit units e).bind (fun next => applyEdits next es)

theorem update_at_key (u : Nat → Option α) (e : Edit α) :
    update u e e.key = e.replacement := by simp [update]
theorem update_frame (u : Nat → Option α) (e : Edit α) (k : Nat)
    (outside : k ≠ e.key) : update u e k = u k := by simp [update, outside]
theorem wrong_version_refused [DecidableEq α] (u : Nat → Option α) (e : Edit α)
    (wrong : u e.key ≠ e.expected) : applyEdit u e = none := by simp [applyEdit, wrong]
theorem exact_version_applies [DecidableEq α] (u : Nat → Option α) (e : Edit α)
    (exact : u e.key = e.expected) : applyEdit u e = some (update u e) := by
  simp [applyEdit, exact]
theorem deletion_removes (u : Nat → Option α) (e : Edit α)
    (deleted : e.replacement = none) : update u e e.key = none := by
  simp [update, deleted]
theorem untouched_edits_frame [DecidableEq α] (es : List (Edit α))
    (u result : Nat → Option α) (k : Nat)
    (outside : ∀ e ∈ es, k ≠ e.key) (applied : applyEdits u es = some result) :
    result k = u k := by
  induction es generalizing u with
  | nil => simp [applyEdits] at applied; subst result; rfl
  | cons e es ih =>
    have head := outside e (by simp)
    have tail : ∀ e ∈ es, k ≠ e.key := fun e h => outside e (by simp [h])
    unfold applyEdits at applied
    unfold applyEdit at applied
    split at applied
    · simp only [Option.bind_some] at applied
      exact (ih (update u e) tail applied).trans (update_frame u e k head)
    · simp at applied

-- Full-target comparison is a differential admission guard, not a coverage axiom.
def admit [DecidableEq α] (expectedBase actualBase : Nat)
    (compatible : Bool) (candidate : List α) (full : List α) : Option (List α) :=
  if expectedBase = actualBase ∧ compatible = true ∧ candidate = full
  then some full else none

theorem accepted_equals_full [DecidableEq α] (b a : Nat) (c : Bool)
    (candidate full result : List α) (accepted : admit b a c candidate full = some result) :
    result = full := by
  unfold admit at accepted
  split at accepted
  · simp at accepted; exact accepted.symm
  · simp at accepted

theorem wrong_base_refused [DecidableEq α] (b a : Nat) (c : Bool)
    (candidate full : List α) (wrong : b ≠ a) : admit b a c candidate full = none := by
  simp [admit, wrong]
theorem incompatible_refused [DecidableEq α] (b a : Nat) (candidate full : List α) :
    admit b a false candidate full = none := by simp [admit]
theorem missing_content_refused [DecidableEq α] (b a : Nat) (candidate full : List α)
    (different : candidate ≠ full) : admit b a true candidate full = none := by
  simp [admit, different]

-- Local Query semantics: complete source-domain inputs include nonmatching units.
def localProject (query : α → Option β) (source : Nat → Option α) : Nat → Option β :=
  fun key => (source key).bind query

def changed [DecidableEq α] (old new : Nat → Option α) (key : Nat) : Bool :=
  decide (old key ≠ new key)

def incremental [DecidableEq α] (query : α → Option β)
    (old new : Nat → Option α) : Nat → Option β :=
  fun key => if changed old new key then localProject query new key
             else localProject query old key

theorem unchanged_source_is_equal [DecidableEq α] (old new : Nat → Option α) (k : Nat)
    (same : changed old new k = false) : old k = new k := by
  simpa [changed] using same

theorem incremental_equals_full [DecidableEq α] (query : α → Option β)
    (old new : Nat → Option α) : incremental query old new = localProject query new := by
  funext k
  by_cases h : old k = new k
  · simp [incremental, changed, localProject, h]
  · simp [incremental, changed, h]

theorem insertion_is_covered [DecidableEq α] (old new : Nat → Option α)
    (k : Nat) (value : α) (absent : old k = none) (added : new k = some value) :
    changed old new k = true := by simp [changed, absent, added]
theorem removal_is_covered [DecidableEq α] (old new : Nat → Option α)
    (k : Nat) (value : α) (present : old k = some value) (removed : new k = none) :
    changed old new k = true := by simp [changed, present, removed]
theorem nonmatching_to_matching_is_covered [DecidableEq α] (query : α → Option β)
    (old new : Nat → Option α) (k : Nat)
    (previous : localProject query old k = none)
    (current : localProject query new k ≠ none) : changed old new k = true := by
  by_cases h : old k = new k
  · have eqResults : localProject query old k = localProject query new k := by
      simp [localProject, h]
    exact False.elim (current (eqResults.symm.trans previous))
  · simp [changed, h]

theorem rebind_global_source (bind : γ → Option β → δ) (cut : γ)
    [DecidableEq α] (query : α → Option β) (old new : Nat → Option α) :
    (fun key => bind cut (incremental query old new key)) =
    (fun key => bind cut (localProject query new key)) := by
  rw [incremental_equals_full]
end AgenticAILabContextProof

open Lean Elab Command in
run_cmd do
  let environment ← getEnv
  let allowed := #[`propext, `Classical.choice, `Quot.sound]
  for required in #[`AgenticAILabContextProof.update_at_key,
      `AgenticAILabContextProof.update_frame, `AgenticAILabContextProof.wrong_version_refused,
      `AgenticAILabContextProof.exact_version_applies, `AgenticAILabContextProof.deletion_removes,
      `AgenticAILabContextProof.untouched_edits_frame, `AgenticAILabContextProof.accepted_equals_full,
      `AgenticAILabContextProof.wrong_base_refused, `AgenticAILabContextProof.incompatible_refused,
      `AgenticAILabContextProof.missing_content_refused,
      `AgenticAILabContextProof.unchanged_source_is_equal, `AgenticAILabContextProof.incremental_equals_full, `AgenticAILabContextProof.insertion_is_covered,
      `AgenticAILabContextProof.removal_is_covered, `AgenticAILabContextProof.nonmatching_to_matching_is_covered,
      `AgenticAILabContextProof.rebind_global_source] do
    unless environment.contains required do
      throwError "Required Context Delta theorem is missing: {required}"
  let mut count : Nat := 0
  for (name, info) in environment.constants.toList do
    if (`AgenticAILabContextProof).isPrefixOf name then
      if info.isTheorem then count := count + 1
      for axiomName in (← collectAxioms name) do
        unless allowed.contains axiomName do
          throwError "{name} depends on disallowed axiom {axiomName}"
  if count < 16 then throwError "Delta theorem inventory is incomplete"
  logInfo m!"CONTEXT-DELTA-AXIOM-AUDIT-OK: {count} theorems; standard Lean axioms only"
