-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import Std.Tactic

/-! Finite observations of unbounded accounting. The relations mirror the
Quint sets and include every nonnegative increment, without a trace cutoff.
Safety observes signs and snapshot order, not exact counter magnitudes.
Other evidence fields and transitions are unchanged. -/
namespace AgenticAILabProof.AccountingAbstraction
inductive Sign where
  | negative | zero | positive
  deriving DecidableEq
def sign (n : Int) : Sign :=
  if n < 0 then .negative else if n = 0 then .zero else .positive
def signStep (before : Sign) (tokens : Int) (after : Sign) : Prop :=
  (tokens = 0 ∧ after = before) ∨
  (0 < tokens ∧ (before = .negative ∨ after = .positive))
theorem add_sign_sound (n tokens : Int) (nonnegative : 0 ≤ tokens) :
    signStep (sign n) tokens (sign (n + tokens)) := by
  by_cases zero : tokens = 0
  · simp [signStep, zero]
  · have positive : 0 < tokens := by omega
    by_cases negative : n < 0
    · simp [signStep, positive, sign, negative]
    · have sumNonzero : n + tokens ≠ 0 := by omega
      have sumNonnegative : ¬ n + tokens < 0 := by omega
      exact Or.inr ⟨positive, Or.inr (by simp [sign, sumNonnegative, sumNonzero])⟩
theorem sign_safety_exact (n : Int) : sign n ≠ .negative ↔ 0 ≤ n := by
  by_cases negative : n < 0
  · simp [sign, negative] <;> omega
  · by_cases zero : n = 0 <;> simp [sign, negative, zero] <;> omega

inductive SnapshotOrder where
  | unset | before | equal | after
  deriving DecidableEq
def snapshotOrder (first : Option Nat) (cost : Nat) : SnapshotOrder :=
  match first with
  | none => .unset
  | some value => if value = cost then .equal else if value < cost then .before else .after
def snapshotStep (previous : SnapshotOrder) (tokens : Nat) (next : SnapshotOrder) : Prop :=
  (tokens = 0 ∧ next = previous) ∨ (0 < tokens ∧
    match previous with
    | .unset => next = .unset
    | .before => next = .before
    | .equal => next = .before
    | .after => next ≠ .unset)
theorem snapshot_add_sound (first : Option Nat) (cost tokens : Nat) :
    snapshotStep (snapshotOrder first cost) tokens (snapshotOrder first (cost + tokens)) := by
  by_cases zero : tokens = 0
  · simp [snapshotStep, zero]
  · have positive : 0 < tokens := by omega
    apply Or.inr
    refine ⟨positive, ?_⟩
    cases first with
    | none => rfl
    | some value =>
      by_cases equal : value = cost
      · have less : value < cost + tokens := by omega
        have different : value ≠ cost + tokens := by omega
        simp [snapshotOrder, equal, zero, positive]
      · by_cases less : value < cost
        · have increased : value < cost + tokens := by omega
          have different : value ≠ cost + tokens := by omega
          simp [snapshotOrder, equal, less, different, increased]
        · simp [snapshotOrder, equal, less]
          split <;> simp_all
          split <;> simp_all
theorem snapshot_safety_exact (first : Option Nat) (cost : Nat) :
    snapshotOrder first cost ≠ .after ↔ first.all (· ≤ cost) := by
  cases first with
  | none => simp [snapshotOrder]
  | some value =>
    by_cases equal : value = cost
    · simp [snapshotOrder, equal]
    · by_cases less : value < cost <;> simp [snapshotOrder, equal, less] <;> omega
theorem first_snapshot_equal (cost : Nat) : snapshotOrder (some cost) cost = .equal := by
  simp [snapshotOrder]
theorem cleared_snapshot_unset (cost : Nat) : snapshotOrder none cost = .unset := rfl
end AgenticAILabProof.AccountingAbstraction
