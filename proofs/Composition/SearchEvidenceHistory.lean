-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import SearchEvidence
namespace POO.Flow.SearchEvidence
open POO.Flow.SearchAttempt
def historySourceDigest : String := "sha256:ece080383dbe1a7fb2f6a4baa71c9253227cdbd252dda1c00aa4b4066df1ae69"
def historyInvariantNames : List String := ["UniqueEventAdmission", "HistoryRetention"]

-- History belongs to one retained engine generation, including invalidated events.
def retainIdentity (history : List Nat) (event : Event) : List Nat :=
  event.identity :: history

def reviseHistory (history : List Nat) : List Nat := history

theorem history_retained_after_admission (history : List Nat) (event : Event)
    (identity : Nat) (present : identity ∈ history) :
    identity ∈ retainIdentity history event := by
  simp [retainIdentity, present]

theorem history_retained_after_revision (history : List Nat) :
    reviseHistory history = history := rfl

theorem historical_identity_rejects {node : LeanPoo.C4.Node} {state : State}
    {request : Request} {observations : String → Option Event}
    {history : List Nat} {event : Event} (used : event.identity ∈ history) :
    ¬ AdmitsEvidence node state request observations history event := by
  intro admitted
  rcases admitted with ⟨_, _, _, _, _, _, fresh, _⟩
  exact fresh used

theorem admitted_event_cannot_be_reused {node : LeanPoo.C4.Node} {state : State}
    {request : Request} {observations : String → Option Event}
    (history : List Nat) (event : Event) :
    ¬ AdmitsEvidence node state request observations
      (reviseHistory (retainIdentity history event)) event := by
  apply historical_identity_rejects
  simp [reviseHistory, retainIdentity]

end POO.Flow.SearchEvidence
