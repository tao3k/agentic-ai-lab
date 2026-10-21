/- Host journal laws. Receipt admission and Scheme inference have independent
   contracts; these laws cover immutable submission and compare-and-swap. -/
namespace ClueSubmission

structure Clue where
  id : String
  source : String
  deriving DecidableEq

structure Journal where
  generation : Nat
  rows : List Clue

def submit (journal : Journal) (expected : Nat) (clue : Clue) : Option Journal :=
  if expected = journal.generation ∧ ¬ journal.rows.any (·.id == clue.id) then
    some { generation := journal.generation + 1, rows := journal.rows ++ [clue] }
  else none

theorem stale_submission_is_atomic (journal : Journal) (expected : Nat) (clue : Clue)
    (stale : expected ≠ journal.generation) : submit journal expected clue = none := by
  simp [submit, stale]

theorem accepted_submission_retains_prefix (journal result : Journal)
    (expected : Nat) (clue : Clue) (accepted : submit journal expected clue = some result) :
    result.rows = journal.rows ++ [clue] ∧ result.generation = journal.generation + 1 := by
  unfold submit at accepted
  split at accepted
  next => cases accepted; exact ⟨rfl, rfl⟩
  next => cases accepted

theorem accepted_submission_requires_current_prefix (journal result : Journal)
    (expected : Nat) (clue : Clue) (accepted : submit journal expected clue = some result) :
    expected = journal.generation := by
  unfold submit at accepted
  split at accepted
  next condition => exact condition.1
  next => cases accepted

theorem accepted_submission_preserves_count (journal result : Journal)
    (expected : Nat) (clue : Clue) (count : journal.rows.length = journal.generation)
    (accepted : submit journal expected clue = some result) :
    result.rows.length = result.generation := by
  obtain ⟨rows, generation⟩ := accepted_submission_retains_prefix journal result expected clue accepted
  simp [rows, generation, count]

#print axioms stale_submission_is_atomic
#print axioms accepted_submission_retains_prefix
#print axioms accepted_submission_requires_current_prefix
#print axioms accepted_submission_preserves_count
end ClueSubmission
