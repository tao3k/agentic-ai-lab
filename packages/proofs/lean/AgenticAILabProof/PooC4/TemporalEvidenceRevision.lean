-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
An abstract admission-time cut law for the Temporal Causality evidence journal.
It proves list-level replay stability under future append. It does not prove
the Gerbil implementation or the Quint module refines this model.
-/

namespace AgenticAILabProof.PooC4.TemporalEvidenceRevision

structure Revision (Subject : Type) where
  subject : Subject
  admission : Nat
  deriving Repr

def visibleAt {Subject : Type} (cut : Nat)
    (revisions : List (Revision Subject)) : List (Revision Subject) :=
  revisions.filter (fun revision => revision.admission ≤ cut)

/-- A semantic projection key keeps the valid-time query separate from the
admission cut. A concrete digest is only a representation of this key. -/
structure ProjectionKey (Subject : Type) where
  admissionCut : Nat
  validAt : Option Nat
  visible : List (Revision Subject)

def projectionAt {Subject : Type} (cut : Nat) (validAt : Option Nat)
    (revisions : List (Revision Subject)) : ProjectionKey Subject :=
  ⟨cut, validAt, visibleAt cut revisions⟩

theorem futureInvisible {Subject : Type}
    (cut : Nat) (future : List (Revision Subject))
    (afterCut : ∀ revision ∈ future, cut < revision.admission) :
    visibleAt cut future = [] := by
  induction future with
  | nil => simp [visibleAt]
  | cons revision tail ih =>
      have headAfter : cut < revision.admission :=
        afterCut revision (by simp)
      have tailAfter : ∀ item ∈ tail, cut < item.admission := by
        intro item member
        exact afterCut item (by simp [member])
      have tailInvisible : visibleAt cut tail = [] := ih tailAfter
      have headNotVisible : ¬ revision.admission ≤ cut :=
        Nat.not_le_of_gt headAfter
      simpa [visibleAt, headNotVisible] using tailInvisible

theorem appendFuturePreservesCut {Subject : Type}
    (cut : Nat) (history future : List (Revision Subject))
    (afterCut : ∀ revision ∈ future, cut < revision.admission) :
    visibleAt cut (history ++ future) = visibleAt cut history := by
  have futureEmpty : visibleAt cut future = [] :=
    futureInvisible cut future afterCut
  change (history ++ future).filter
    (fun revision => revision.admission ≤ cut) =
    history.filter (fun revision => revision.admission ≤ cut)
  rw [List.filter_append]
  rw [show future.filter (fun revision => revision.admission ≤ cut) = []
      from futureEmpty]
  simp

theorem appendFuturePreservesProjection {Subject : Type}
    (cut : Nat) (validAt : Option Nat)
    (history future : List (Revision Subject))
    (afterCut : ∀ revision ∈ future, cut < revision.admission) :
    projectionAt cut validAt (history ++ future) =
      projectionAt cut validAt history := by
  simp [projectionAt, appendFuturePreservesCut cut history future afterCut]

theorem differentValidTimeDifferentProjection {Subject : Type}
    (cut : Nat) (history : List (Revision Subject))
    (first second : Option Nat) (different : first ≠ second) :
    projectionAt cut first history ≠ projectionAt cut second history := by
  intro same
  exact different (congrArg ProjectionKey.validAt same)

theorem admittedAfterCutExcluded {Subject : Type}
    (cut : Nat) (revisions : List (Revision Subject))
    (revision : Revision Subject) (afterCut : cut < revision.admission) :
    revision ∉ visibleAt cut revisions := by
  intro member
  have admitted : revision.admission ≤ cut :=
    of_decide_eq_true (List.mem_filter.mp member).2
  exact (Nat.not_le_of_gt afterCut) admitted

end AgenticAILabProof.PooC4.TemporalEvidenceRevision
