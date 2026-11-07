-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
Abstract bounds for a single clock domain. These laws describe the numeric
rules used by the Scheme time module; they do not authenticate an external
clock or prove a refinement from Gerbil objects to this structure.
-/

namespace AgenticAILabProof.PooC4.TemporalBoundedTime

structure Bound where
  lower : Nat
  upper : Nat
  ordered : lower ≤ upper

def Contains (interval : Bound) (position : Nat) : Prop :=
  interval.lower ≤ position ∧ position ≤ interval.upper

def DefinitelyBefore (interval : Bound) (boundary : Nat) : Prop :=
  interval.upper < boundary

def DefinitelyAfter (interval : Bound) (boundary : Nat) : Prop :=
  boundary < interval.lower

def DefinitelyBeforePair (left right : Bound) : Prop :=
  left.upper < right.lower

def DefinitelyAfterPair (left right : Bound) : Prop :=
  right.upper < left.lower

def MayOverlap (left right : Bound) : Prop :=
  left.lower ≤ right.upper ∧ right.lower ≤ left.upper

/-- A watermark's whole uncertainty range must be at or beyond the cut. -/
def CoverageClaim (watermark : Bound) (cut : Nat) : Prop :=
  cut ≤ watermark.lower

theorem beforeSound (interval : Bound) (boundary position : Nat)
    (before : DefinitelyBefore interval boundary)
    (within : Contains interval position) :
    position < boundary :=
  Nat.lt_of_le_of_lt within.2 before

theorem afterSound (interval : Bound) (boundary position : Nat)
    (after : DefinitelyAfter interval boundary)
    (within : Contains interval position) :
    boundary < position :=
  Nat.lt_of_lt_of_le after within.1

theorem beforePairSound (left right : Bound) (leftPosition rightPosition : Nat)
    (before : DefinitelyBeforePair left right)
    (withinLeft : Contains left leftPosition)
    (withinRight : Contains right rightPosition) :
    leftPosition < rightPosition :=
  Nat.lt_of_lt_of_le (Nat.lt_of_le_of_lt withinLeft.2 before) withinRight.1

theorem afterPairSound (left right : Bound) (leftPosition rightPosition : Nat)
    (after : DefinitelyAfterPair left right)
    (withinLeft : Contains left leftPosition)
    (withinRight : Contains right rightPosition) :
    rightPosition < leftPosition :=
  Nat.lt_of_lt_of_le (Nat.lt_of_le_of_lt withinRight.2 after) withinLeft.1

theorem overlapCannotBeDefinite (left right : Bound)
    (overlap : MayOverlap left right) :
    ¬ DefinitelyBeforePair left right ∧ ¬ DefinitelyAfterPair left right := by
  constructor
  · intro before
    exact (Nat.not_lt_of_ge overlap.2) before
  · intro after
    exact (Nat.not_lt_of_ge overlap.1) after

theorem crossingCannotBeBefore (interval : Bound) (boundary : Nat)
    (crosses : Contains interval boundary) :
    ¬ DefinitelyBefore interval boundary := by
  intro before
  exact (Nat.not_lt_of_ge crosses.2) before

theorem crossingCannotBeAfter (interval : Bound) (boundary : Nat)
    (crosses : Contains interval boundary) :
    ¬ DefinitelyAfter interval boundary := by
  intro after
  exact (Nat.not_lt_of_ge crosses.1) after

theorem coverageClaimBoundsEveryPossibleTime
    (watermark : Bound) (cut position : Nat)
    (claim : CoverageClaim watermark cut)
    (within : Contains watermark position) :
    cut ≤ position :=
  Nat.le_trans claim within.1

theorem watermarkBeforeCutCannotClaimCoverage
    (watermark : Bound) (cut : Nat)
    (before : watermark.upper < cut) :
    ¬ CoverageClaim watermark cut := by
  intro claim
  have lowerBefore : watermark.lower < cut :=
    Nat.lt_of_le_of_lt watermark.ordered before
  exact (Nat.not_lt_of_ge claim) lowerBefore

end AgenticAILabProof.PooC4.TemporalBoundedTime
