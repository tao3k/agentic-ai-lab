-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
/-! Local evidence validity and temporal observations have separate owners.
These laws assume a trusted domain checker; they do not prove model intent,
the native query kernel, or efficacy of model feedback. -/
namespace AgenticAILabProof.EvidenceInteraction
inductive Verdict where
  | supported | contradicted | unknown
  deriving DecidableEq, Repr
structure Evidence where
  generation : Nat
  supported : Bool
  complete : Bool
  deriving DecidableEq, Repr
structure Observation where
  generation : Nat
  tokens : Nat
  deriving DecidableEq, Repr
def classify (generation : Nat) (e : Evidence) : Verdict :=
  if e.generation != generation then .unknown
  else if e.supported then .supported
  else if e.complete then .contradicted else .unknown
def mayPrune (v : Verdict) : Bool := v == .contradicted
def conjoin (a b : Evidence) : Evidence :=
  if b.generation = a.generation then
    { generation := a.generation, supported := a.supported && b.supported,
      complete := a.complete && b.complete }
  else { a with supported := false, complete := false }
theorem conjunction_requires_both (a b : Evidence) (h : b.generation = a.generation) :
    (conjoin a b).supported = true ↔ a.supported = true ∧ b.supported = true := by
  simp [conjoin, h]
theorem conjunction_preserves_incomplete_scope (a b : Evidence) (h : b.complete = false) :
    (conjoin a b).complete = false := by simp [conjoin, h]; split <;> rfl
theorem mixed_generation_cannot_support (a b : Evidence) (h : b.generation ≠ a.generation) :
    (conjoin a b).supported = false := by simp [conjoin, h]
-- A readable path alias transports the same claim; it does not admit a new
-- meaning or extend scope. The current source generation is checked again.
def reusePath (current : Nat) (previous : Evidence) : Verdict := classify current previous
theorem path_alias_cannot_refresh_stale_evidence (g : Nat) (e : Evidence) (h : e.generation ≠ g) :
    reusePath g e = .unknown := by simp [reusePath, classify, h]
theorem extending_path_cannot_discard_previous_conditions (a b : Evidence)
    (h : a.supported = false) : (conjoin a b).supported = false := by
  simp [conjoin, h]; split <;> rfl
def observe (events : List Observation) (o : Observation) : List Observation := events ++ [o]
def cumulative (events : List Observation) : Nat := (events.map (·.tokens)).foldl (· + ·) 0
theorem incomplete_absence_is_unknown (g : Nat) :
    classify g ⟨g, false, false⟩ = .unknown := by simp [classify]
theorem unknown_does_not_prune : mayPrune .unknown = false := rfl
theorem stale_evidence_is_unknown (g : Nat) (e : Evidence) (h : e.generation ≠ g) :
    classify g e = .unknown := by simp [classify, h]
theorem observation_cannot_change_evidence (e : Evidence) (events : List Observation) (o : Observation) :
    (e, observe events o).1 = e := rfl
theorem completed_negative_can_prune (g : Nat) :
    mayPrune (classify g ⟨g, false, true⟩) = true := by simp [classify, mayPrune]
theorem positive_local_support (g : Nat) (complete : Bool) :
    classify g ⟨g, true, complete⟩ = .supported := by simp [classify]
end AgenticAILabProof.EvidenceInteraction
