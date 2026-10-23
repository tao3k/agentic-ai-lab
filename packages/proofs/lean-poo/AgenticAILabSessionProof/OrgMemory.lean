import Std

/- Orgize Scheme selects candidates. Agentic AI Lab owns the pure scope and Session
   policy gate; MRR admission and publication remain separate authorities. -/
namespace AgenticAILabSessionProof.OrgMemory

structure Selection where
  project : Nat
  worktree : Nat
  sourceCut : Nat
  bytes : Nat
  query : Nat
  candidates : List Nat
  deriving DecidableEq, Repr

structure Current where
  project : Nat
  worktree : Nat
  sourceCut : Nat
  bytes : Nat
  allowedQuery : Nat
  expectedHead : Nat
  currentHead : Nat
  readGranted : Bool
  sessionActive : Bool
  memoryPolicyAllows : Bool
  deriving DecidableEq, Repr

structure SelectionIntent where
  project : Nat
  worktree : Nat
  sourceCut : Nat
  bytes : Nat
  query : Nat
  expectedHead : Nat
  candidates : List Nat
  semanticAdmitted : Bool
  memoryPublished : Bool
  deriving DecidableEq, Repr

/-- The selected graph and query must be bound by the host to the supplied
source. This model checks the current Agentic AI Lab policy premises only. -/
def propose (selection : Selection) (current : Current) : Option SelectionIntent :=
  if selection.project = current.project ∧
      selection.worktree = current.worktree ∧
      selection.sourceCut = current.sourceCut ∧
      selection.bytes = current.bytes ∧
      selection.query = current.allowedQuery ∧
      current.expectedHead = current.currentHead ∧
      current.readGranted = true ∧
      current.sessionActive = true ∧
      current.memoryPolicyAllows = true ∧
      selection.candidates ≠ [] then
    some {
      project := selection.project
      worktree := selection.worktree
      sourceCut := selection.sourceCut
      bytes := selection.bytes
      query := selection.query
      expectedHead := current.expectedHead
      candidates := selection.candidates
      semanticAdmitted := false
      memoryPublished := false
    }
  else none

theorem foreign_worktree_refused (selection : Selection) (current : Current)
    (foreign : selection.worktree ≠ current.worktree) :
    propose selection current = none := by
  simp [propose, foreign]

theorem stale_source_cut_refused (selection : Selection) (current : Current)
    (stale : selection.sourceCut ≠ current.sourceCut) :
    propose selection current = none := by
  simp [propose, stale]

theorem changed_bytes_refused (selection : Selection) (current : Current)
    (changed : selection.bytes ≠ current.bytes) :
    propose selection current = none := by
  simp [propose, changed]

theorem revoked_read_refused (selection : Selection) (current : Current)
    (revoked : current.readGranted = false) :
    propose selection current = none := by
  simp [propose, revoked]

theorem inactive_session_refused (selection : Selection) (current : Current)
    (inactive : current.sessionActive = false) :
    propose selection current = none := by
  simp [propose, inactive]

theorem losing_head_refused (selection : Selection) (current : Current)
    (changed : current.expectedHead ≠ current.currentHead) :
    propose selection current = none := by
  simp [propose, changed]

theorem accepted_selection_preserves_source_without_publication
    (selection : Selection) (current : Current) (intent : SelectionIntent)
    (accepted : propose selection current = some intent) :
    intent.project = selection.project ∧
      intent.worktree = selection.worktree ∧
      intent.sourceCut = selection.sourceCut ∧
      intent.bytes = selection.bytes ∧
      intent.query = selection.query ∧
      intent.candidates = selection.candidates ∧
      intent.semanticAdmitted = false ∧
      intent.memoryPublished = false := by
  unfold propose at accepted
  split at accepted
  · cases accepted
    simp
  · contradiction

end AgenticAILabSessionProof.OrgMemory
