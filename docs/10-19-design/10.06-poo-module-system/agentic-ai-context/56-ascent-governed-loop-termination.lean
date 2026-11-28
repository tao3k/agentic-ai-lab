-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
  Slice 56: ASCENT-Governed Loop Engine Termination, Anti-Oscillation,
  Safety-Dominance Lattice & Absorbing Halt Closure.

  Formally proves that an ASCENT-driven Loop Engine cannot infinite-loop
  under ANY adversarial LLM / environment policy, halts immediately on
  exact state cycles, A <-> B oscillations, repeated failures, zero-progress
  stalls, or upstream governance blocks (Slices 50-55), and never self-resets
  after halting without explicit non-self human reopen endorsement.
-/

namespace AscentGovernedLoopTermination

inductive LoopVerdict where
  | haltGovernanceBlocked
  | haltConverged
  | haltCycleDetected
  | haltStalledNoProgress
  | haltBudgetExhausted
  | admitNextStep
  deriving DecidableEq, Repr

structure LoopStepSnapshot where
  stepBudgetRemaining : Nat
  tokensRemaining : Nat
  remainingFrontier : Nat
  openInvariants : Nat
  openDefeaters : Nat
  openBlockers : Nat
  journalQuiescent : Bool
  exactStateCycle : Bool
  oscillationCycle : Bool
  repeatedFailureCount : Nat
  maxRepeatedFailures : Nat
  zeroProgressStreak : Nat
  maxStallTurns : Nat
  governanceBlocked : Bool
  haltedPrior : Bool
  humanReopenEndorsed : Bool
  deriving DecidableEq, Repr

def progressMeasure (s : LoopStepSnapshot) : Nat :=
  s.remainingFrontier + s.openInvariants + s.openDefeaters + s.openBlockers

/-- Strict mutually exclusive verdict priority lattice matching the
    ASCENT relational fixed-point governor in `modules/loop-engine/ascent-termination.ss`. -/
def evaluateLoopVerdict (s : LoopStepSnapshot) : LoopVerdict :=
  if s.haltedPrior && !s.humanReopenEndorsed then
    .haltGovernanceBlocked
  else if s.governanceBlocked then
    .haltGovernanceBlocked
  else if progressMeasure s == 0 && s.journalQuiescent then
    .haltConverged
  else if s.exactStateCycle || s.oscillationCycle then
    .haltCycleDetected
  else if decide (s.repeatedFailureCount ≥ s.maxRepeatedFailures) ||
          decide (s.zeroProgressStreak ≥ s.maxStallTurns) then
    .haltStalledNoProgress
  else if s.stepBudgetRemaining == 0 || s.tokensRemaining == 0 then
    .haltBudgetExhausted
  else
    .admitNextStep

def isHaltedVerdict (v : LoopVerdict) : Bool :=
  decide (v ≠ .admitNextStep)

-- ===========================================================================
-- 1. Safety Dominance & Absorbing Halt Theorems
-- ===========================================================================

theorem governanceBlock_dominates_retry_and_convergence
    (s : LoopStepSnapshot)
    (hBlocked : s.governanceBlocked = true) :
    evaluateLoopVerdict s = .haltGovernanceBlocked := by
  unfold evaluateLoopVerdict
  by_cases hHalt : (s.haltedPrior && !s.humanReopenEndorsed) = true
  · simp [hHalt]
  · simp [hHalt, hBlocked]

theorem haltedLoop_absorbing_without_human_reopen
    (s : LoopStepSnapshot)
    (hHalted : s.haltedPrior = true)
    (hNoReopen : s.humanReopenEndorsed = false) :
    evaluateLoopVerdict s = .haltGovernanceBlocked := by
  simp [evaluateLoopVerdict, hHalted, hNoReopen]

-- ===========================================================================
-- 2. Cycle, Oscillation, Stall & Budget Halt Theorems
-- ===========================================================================

theorem exactCycle_or_oscillation_always_halts
    (s : LoopStepSnapshot)
    (hCycle : s.exactStateCycle = true ∨ s.oscillationCycle = true) :
    evaluateLoopVerdict s ≠ .admitNextStep := by
  unfold evaluateLoopVerdict
  have hOr : (s.exactStateCycle || s.oscillationCycle) = true := by
    rcases hCycle with h | h <;> simp [h]
  by_cases h1 : (s.haltedPrior && !s.humanReopenEndorsed) = true
  · simp [h1]
  · by_cases h2 : s.governanceBlocked = true
    · simp [h1, h2]
    · by_cases h3 : (progressMeasure s == 0 && s.journalQuiescent) = true
      · simp [h1, h2, h3]
      · simp [h1, h2, h3, hOr]

theorem repeatedFailure_or_zeroProgress_always_halts
    (s : LoopStepSnapshot)
    (hStall : s.repeatedFailureCount ≥ s.maxRepeatedFailures ∨
              s.zeroProgressStreak ≥ s.maxStallTurns) :
    evaluateLoopVerdict s ≠ .admitNextStep := by
  unfold evaluateLoopVerdict
  have hOr : (decide (s.repeatedFailureCount ≥ s.maxRepeatedFailures) ||
              decide (s.zeroProgressStreak ≥ s.maxStallTurns)) = true := by
    rcases hStall with h | h <;> simp [h]
  by_cases h1 : (s.haltedPrior && !s.humanReopenEndorsed) = true
  · simp [h1]
  · by_cases h2 : s.governanceBlocked = true
    · simp [h1, h2]
    · by_cases h3 : (progressMeasure s == 0 && s.journalQuiescent) = true
      · simp [h1, h2, h3]
      · by_cases h4 : (s.exactStateCycle || s.oscillationCycle) = true
        · simp [h1, h2, h3, h4]
        · simp [h1, h2, h3, h4, hOr]

theorem budgetExhausted_always_halts
    (s : LoopStepSnapshot)
    (hBudget : s.stepBudgetRemaining = 0 ∨ s.tokensRemaining = 0) :
    evaluateLoopVerdict s ≠ .admitNextStep := by
  unfold evaluateLoopVerdict
  have hOr : ((s.stepBudgetRemaining == 0) || (s.tokensRemaining == 0)) = true := by
    rcases hBudget with h | h <;> simp [h]
  by_cases h1 : (s.haltedPrior && !s.humanReopenEndorsed) = true
  · simp [h1]
  · by_cases h2 : s.governanceBlocked = true
    · simp [h1, h2]
    · by_cases h3 : (progressMeasure s == 0 && s.journalQuiescent) = true
      · simp [h1, h2, h3]
      · by_cases h4 : (s.exactStateCycle || s.oscillationCycle) = true
        · simp [h1, h2, h3, h4]
        · by_cases h5 : (decide (s.repeatedFailureCount ≥ s.maxRepeatedFailures) ||
                         decide (s.zeroProgressStreak ≥ s.maxStallTurns)) = true
          · simp [h1, h2, h3, h4, h5]
          · simp [h1, h2, h3, h4, h5, hOr]

theorem convergedQuiescent_halts_cleanly
    (s : LoopStepSnapshot)
    (hNotPrior : s.haltedPrior = false)
    (hUnblocked : s.governanceBlocked = false)
    (hZero : progressMeasure s = 0)
    (hQuiescent : s.journalQuiescent = true) :
    evaluateLoopVerdict s = .haltConverged := by
  simp [evaluateLoopVerdict, hNotPrior, hUnblocked, hZero, hQuiescent]

-- ===========================================================================
-- 3. Universal Bounded Termination Against Arbitrary Adversarial LLM Policy
-- ===========================================================================

/-- Enforces monotonic runtime step-budget decrement on every admitted turn,
    regardless of what next snapshot an adversarial LLM/environment proposes. -/
def enforceMonotonicBudgetStep
    (adv : LoopStepSnapshot → LoopStepSnapshot)
    (s : LoopStepSnapshot) : LoopStepSnapshot :=
  let next := adv s
  { next with stepBudgetRemaining := s.stepBudgetRemaining - 1 }

/-- Runs the governed loop using structural fuel equal to `s.stepBudgetRemaining`.
    When `evaluateLoopVerdict s = .admitNextStep`, we necessarily have
    `s.stepBudgetRemaining > 0`, so the budget strictly decreases each turn. -/
def runGovernedLoop
    (adv : LoopStepSnapshot → LoopStepSnapshot) :
    Nat → LoopStepSnapshot → LoopVerdict
  | 0, s => evaluateLoopVerdict s
  | fuel + 1, s =>
      match evaluateLoopVerdict s with
      | .admitNextStep => runGovernedLoop adv fuel (enforceMonotonicBudgetStep adv s)
      | v => v

theorem adversarialLoop_universally_terminates
    (adv : LoopStepSnapshot → LoopStepSnapshot)
    (fuel : Nat)
    (s : LoopStepSnapshot)
    (hBound : s.stepBudgetRemaining ≤ fuel) :
    isHaltedVerdict (runGovernedLoop adv fuel s) = true := by
  induction fuel generalizing s with
  | zero =>
    have hZero : s.stepBudgetRemaining = 0 := Nat.le_zero.mp hBound
    have hNe : evaluateLoopVerdict s ≠ .admitNextStep :=
      budgetExhausted_always_halts s (Or.inl hZero)
    simp [runGovernedLoop, isHaltedVerdict, hNe]
  | succ k ih =>
    unfold runGovernedLoop
    cases hV : evaluateLoopVerdict s with
    | admitNextStep =>
      have hSub : (enforceMonotonicBudgetStep adv s).stepBudgetRemaining ≤ k := by
        simp [enforceMonotonicBudgetStep]
        omega
      exact ih (enforceMonotonicBudgetStep adv s) hSub
    | haltGovernanceBlocked => rfl
    | haltConverged => rfl
    | haltCycleDetected => rfl
    | haltStalledNoProgress => rfl
    | haltBudgetExhausted => rfl

end AscentGovernedLoopTermination
