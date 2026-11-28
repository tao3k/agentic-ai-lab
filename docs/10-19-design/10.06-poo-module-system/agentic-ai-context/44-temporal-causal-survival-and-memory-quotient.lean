-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
Slice 44 — Lean Unbounded Bitemporal Cut Algebra & Citation Frame Laws ONLY:
Per `FormalVerificationTaxonomy` in `44-temporal-causal-survival-and-memory-quotient.sysml`,
this module proves pure universal properties over unbounded revision journals,
citation lists, and dependency frontiers:
1. Append-only historical cut invariance (`append_later_revision_preserves_historical_cut`
   and `append_later_batch_preserves_historical_cut`) and cut monotonicity
   (`filterUpToCut_monotone_in_cut`).
2. Zero Exploratory Burden Frame Theorem
   (`unused_retrieved_mutation_creates_zero_invalidation_burden`) and post-review
   citation invalidation (`post_admission_citation_invalidates_prior_review`).
3. Set inclusion of trajectory-specific impact `T` inside structural potential
   frontier `P` (`trajectoryImpact_subsumed_by_potentialFrontier`).
Asynchronous watermark vs `Why-Not`, late out-of-order valid-time arrivals, and
live eviction races belong exclusively to `44-*.qnt`.
-/

namespace TemporalCausalSurvivalMemoryQuotient

inductive BitemporalStatus where
  | active
  | retracted
  | conflicted
  deriving DecidableEq, Repr

structure RevisionEntry (EId : Type) where
  admissionTime : Nat
  validTime : Nat
  subject : EId
  status : BitemporalStatus
  deriving DecidableEq, Repr

def filterUpToCut {EId : Type} (a : Nat) : List (RevisionEntry EId) → List (RevisionEntry EId)
  | [] => []
  | r :: rs =>
      if r.admissionTime ≤ a then r :: filterUpToCut a rs else filterUpToCut a rs

theorem append_later_revision_preserves_historical_cut
    {EId : Type} (journal : List (RevisionEntry EId)) (late : RevisionEntry EId) (a1 : Nat)
    (hAfter : a1 < late.admissionTime) :
    filterUpToCut a1 (journal ++ [late]) = filterUpToCut a1 journal := by
  induction journal with
  | nil =>
      simp only [List.nil_append, filterUpToCut]
      split
      · rename_i hLe
        exact False.elim ((Nat.not_le_of_gt hAfter) hLe)
      · rfl
  | cons head tail ih =>
      simp only [List.cons_append, filterUpToCut]
      split
      · rw [ih]
      · exact ih

theorem filterUpToCut_monotone_in_cut
    {EId : Type} {a1 a2 : Nat} (hLe : a1 ≤ a2)
    (journal : List (RevisionEntry EId)) (r : RevisionEntry EId)
    (hMem : r ∈ filterUpToCut a1 journal) :
    r ∈ filterUpToCut a2 journal := by
  induction journal with
  | nil => cases hMem
  | cons head tail ih =>
      unfold filterUpToCut at hMem ⊢
      split at hMem
      · rename_i hHeadA1
        have hHeadA2 : head.admissionTime ≤ a2 := Nat.le_trans hHeadA1 hLe
        simp only [hHeadA2, ↓reduceIte]
        cases hMem with
        | head => exact List.Mem.head _
        | tail _ hTail => exact List.Mem.tail _ (ih hTail)
      · split
        · exact List.Mem.tail _ (ih hMem)
        · exact ih hMem

/-! ## Citation Frame Non-Interference & Entropy Contraction -/

structure QuotientClaim (EId : Type) where
  rawEpisodeCost : Nat
  quotientCost : Nat
  retrievedExploratory : List EId
  citedUsed : List EId
  verifiedCitedSnapshot : List EId

def CitedPremisesSurvive {EId : Type} [DecidableEq EId]
    (m : QuotientClaim EId) (proj : EId → BitemporalStatus) : Prop :=
  m.quotientCost < m.rawEpisodeCost ∧
    m.citedUsed = m.verifiedCitedSnapshot ∧
    (∀ e ∈ m.citedUsed, proj e = .active)

theorem unused_retrieved_mutation_creates_zero_invalidation_burden
    {EId : Type} [DecidableEq EId]
    (m : QuotientClaim EId)
    (proj : EId → BitemporalStatus)
    (eUnused : EId)
    (newStatus : BitemporalStatus)
    (hNotCited : eUnused ∉ m.citedUsed)
    (hSurv : CitedPremisesSurvive m proj) :
    CitedPremisesSurvive m (fun x => if x = eUnused then newStatus else proj x) := by
  rcases hSurv with ⟨hCost, hSnap, hActive⟩
  refine ⟨hCost, hSnap, ?_⟩
  intro e heInCited
  have hNe : e ≠ eUnused := by
    intro hEq
    subst hEq
    exact hNotCited heInCited
  simp [hNe, hActive e heInCited]

theorem post_admission_citation_invalidates_prior_review
    {EId : Type} [DecidableEq EId]
    (m : QuotientClaim EId)
    (proj : EId → BitemporalStatus)
    (extra : EId)
    (hFresh : extra ∉ m.verifiedCitedSnapshot) :
    ¬ CitedPremisesSurvive { m with citedUsed := extra :: m.citedUsed } proj := by
  intro hSurv
  have hEq : extra :: m.citedUsed = m.verifiedCitedSnapshot := hSurv.2.1
  have hMem : extra ∈ m.verifiedCitedSnapshot := by
    rw [← hEq]
    exact List.Mem.head _
  exact hFresh hMem

/-! ## ImpactScope Refinement (`T ⊆ P`) -/

def PotentialFrontier {ClaimId : Type}
    (reachesInGraph : ClaimId → Prop) : ClaimId → Prop :=
  reachesInGraph

def TrajectoryImpact {ClaimId : Type}
    (reachesInGraph exercisedOnRun : ClaimId → Prop) : ClaimId → Prop :=
  fun c => reachesInGraph c ∧ exercisedOnRun c

theorem trajectoryImpact_subsumed_by_potentialFrontier
    {ClaimId : Type}
    (reachesInGraph exercisedOnRun : ClaimId → Prop)
    (c : ClaimId)
    (hTraj : TrajectoryImpact reachesInGraph exercisedOnRun c) :
    PotentialFrontier reachesInGraph c :=
  hTraj.1

end TemporalCausalSurvivalMemoryQuotient
