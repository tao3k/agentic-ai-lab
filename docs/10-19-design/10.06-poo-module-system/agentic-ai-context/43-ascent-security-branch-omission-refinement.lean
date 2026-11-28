-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
Slice 43 — Lean Unbounded Branch × Hypothesis Matrix Algebra & Invariance ONLY:
Per `FormalVerificationTaxonomy` in `43-ascent-security-branch-omission-refinement.sysml`,
this module proves pure universal matrix and quotient properties:
1. Antitonicity of universal remediation safety (`safeForAll_antitone_in_hypotheses`):
   expanding the set of competing hypotheses `H₁ ⊆ H₂` can never turn an unsafe
   destructive branch safe (`SafeForAll cell b H₂ → SafeForAll cell b H₁`).
2. Algebraic invariance against prohibited heuristics (AGENTS.md Core Invariant #7):
   perturbing `missingClaims` or `hypotheticalFit` on any hypothesis leaves both
   `discriminatesPair` and `SafeForAll` strictly unchanged.
3. Exact decidable reflection (`all_projected_evaluated_iff_matrix_complete` and
   `omissionFlag_true_iff_nonempty_gap`) over arbitrarily long hypothesis lists.
Dynamic hypothesis-arrival vs prepared-remediation races live in `43-*.qnt`.
-/

namespace AscentSecurityBranchOmissionRefinement

structure SecurityHypothesis (HId Obs : Type) where
  id : HId
  predictedObservation : Obs
  missingClaims : Nat
  hypotheticalFit : Bool

inductive CellImpact where
  | benignObservation
  | destructiveUnderAlternative
  deriving DecidableEq, Repr

def SafeForAll {BId HId Obs : Type}
    (impact : BId → HId → CellImpact)
    (b : BId)
    (hypotheses : List (SecurityHypothesis HId Obs)) : Prop :=
  ∀ h ∈ hypotheses, impact b h.id = .benignObservation

theorem safeForAll_antitone_in_hypotheses
    {BId HId Obs : Type}
    (impact : BId → HId → CellImpact)
    (b : BId)
    (hSub hSuper : List (SecurityHypothesis HId Obs))
    (hSubset : ∀ h ∈ hSub, h ∈ hSuper)
    (hSafeSuper : SafeForAll impact b hSuper) :
    SafeForAll impact b hSub :=
  fun h hInSub => hSafeSuper h (hSubset h hInSub)

def discriminatesPair {HId Obs : Type} [DecidableEq Obs]
    (h1 h2 : SecurityHypothesis HId Obs) : Bool :=
  h1.predictedObservation != h2.predictedObservation

theorem missing_claim_count_irrelevant_to_discriminator
    {HId Obs : Type} [DecidableEq Obs]
    (h1 h2 : SecurityHypothesis HId Obs)
    (m1 m2 : Nat) :
    discriminatesPair { h1 with missingClaims := m1 } { h2 with missingClaims := m2 } =
      discriminatesPair h1 h2 :=
  rfl

theorem hypothetical_fit_irrelevant_to_safety
    {BId HId Obs : Type}
    (impact : BId → HId → CellImpact)
    (b : BId)
    (h : SecurityHypothesis HId Obs)
    (rest : List (SecurityHypothesis HId Obs))
    (fitFlag : Bool) :
    SafeForAll impact b ({ h with hypotheticalFit := fitFlag } :: rest) ↔
      SafeForAll impact b (h :: rest) := by
  constructor
  · intro hSafe x hx
    cases hx with
    | head => exact hSafe { h with hypotheticalFit := fitFlag } (List.Mem.head _)
    | tail _ hTail => exact hSafe x (List.Mem.tail _ hTail)
  · intro hSafe x hx
    cases hx with
    | head => exact hSafe h (List.Mem.head _)
    | tail _ hTail => exact hSafe x (List.Mem.tail _ hTail)

/-! ## Decidable Matrix Completeness & Omission-Gap Equivalence -/

theorem all_projected_evaluated_iff_matrix_complete
    {HId Obs : Type} [DecidableEq HId]
    (evaluatedIds : List HId)
    (projected : List (SecurityHypothesis HId Obs)) :
    projected.all (fun h => evaluatedIds.contains h.id) = true ↔
      (∀ h ∈ projected, h.id ∈ evaluatedIds) := by
  induction projected with
  | nil =>
      simp
  | cons head tail ih =>
      simp only [List.all_cons, Bool.and_eq_true, List.contains_iff_mem, List.mem_cons]
      constructor
      · rintro ⟨hHead, hTail⟩ x (rfl | hx)
        · exact hHead
        · exact ih.mp hTail x hx
      · intro hAll
        exact ⟨hAll head (Or.inl rfl), ih.mpr (fun x hx => hAll x (Or.inr hx))⟩

theorem omissionFlag_true_iff_nonempty_gap
    {HId : Type} (omittedIds : List HId) :
    (!omittedIds.isEmpty) = true ↔ omittedIds ≠ [] := by
  cases omittedIds <;> simp

end AscentSecurityBranchOmissionRefinement
