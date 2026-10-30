import Std

/- Agentic AI Lab scope policy for shared WorkTree Context references. MRR still
   owns admission of the referenced semantic Content and Context. -/
namespace AgenticAILabSessionProof.SharedContext

/-- A finite, immutable design-level head for Context shared by tasks in one
WorkTree. A real source cut and Content reference have typed digest profiles. -/
structure WorktreeContextHead where
  project : Nat
  worktree : Nat
  sourceCut : Nat
  revision : Nat
  refs : List Nat
  deriving DecidableEq, Repr

structure WorktreeContextReader where
  project : Nat
  worktree : Nat
  taskRun : Nat
  session : Nat
  sourceCut : Nat
  deriving DecidableEq, Repr

/-- Direct reads are scoped to the current WorkTree source cut and authority. -/
def directWorktreeContext (head : WorktreeContextHead)
    (reader : WorktreeContextReader) (authorized : Bool) :
    Option WorktreeContextHead :=
  if head.project = reader.project ∧ head.worktree = reader.worktree ∧
      head.sourceCut = reader.sourceCut ∧ authorized = true then
    some head
  else none

structure WorktreeTransferCandidate where
  sourceProject : Nat
  sourceWorktree : Nat
  sourceCut : Nat
  sourceRevision : Nat
  targetProject : Nat
  targetWorktree : Nat
  targetCut : Nat
  targetRevision : Nat
  content : Nat
  deriving DecidableEq, Repr

/-- Cross-WorkTree transfer creates a proposal for the target head. Runtime
conditional publication and owner-issued guard evidence remain external. -/
def admitWorktreeTransfer (candidate : WorktreeTransferCandidate)
    (source target : WorktreeContextHead)
    (sourceAuthorized targetAuthorized targetApplicable : Bool) :
    Option WorktreeContextHead :=
  if candidate.sourceProject = source.project ∧
      candidate.sourceProject = target.project ∧
      candidate.sourceWorktree = source.worktree ∧
      candidate.sourceCut = source.sourceCut ∧
      candidate.sourceRevision = source.revision ∧
      candidate.content ∈ source.refs ∧
      candidate.targetProject = target.project ∧
      candidate.targetWorktree = target.worktree ∧
      candidate.sourceWorktree ≠ candidate.targetWorktree ∧
      candidate.targetCut = target.sourceCut ∧
      candidate.targetRevision = target.revision ∧
      sourceAuthorized = true ∧ targetAuthorized = true ∧
      targetApplicable = true then
    some { target with
      revision := target.revision + 1
      refs := candidate.content :: target.refs }
  else none

theorem foreign_worktree_cannot_direct_read
    (head : WorktreeContextHead) (reader : WorktreeContextReader)
    (authorized : Bool) (foreign : reader.worktree ≠ head.worktree) :
    directWorktreeContext head reader authorized = none := by
  have mismatch : head.worktree ≠ reader.worktree := Ne.symm foreign
  simp [directWorktreeContext, mismatch]

theorem stale_worktree_cut_cannot_direct_read
    (head : WorktreeContextHead) (reader : WorktreeContextReader)
    (authorized : Bool) (stale : reader.sourceCut ≠ head.sourceCut) :
    directWorktreeContext head reader authorized = none := by
  have mismatch : head.sourceCut ≠ reader.sourceCut := Ne.symm stale
  simp [directWorktreeContext, mismatch]

theorem authorized_tasks_share_current_worktree_head
    (head : WorktreeContextHead)
    (first second : WorktreeContextReader)
    (firstProject : head.project = first.project)
    (secondProject : head.project = second.project)
    (firstWorktree : head.worktree = first.worktree)
    (secondWorktree : head.worktree = second.worktree)
    (firstCut : head.sourceCut = first.sourceCut)
    (secondCut : head.sourceCut = second.sourceCut) :
    directWorktreeContext head first true = some head ∧
    directWorktreeContext head second true = some head := by
  constructor
  · simp [directWorktreeContext, firstProject, firstWorktree, firstCut]
  · simp [directWorktreeContext, secondProject, secondWorktree, secondCut]

theorem foreign_target_cannot_transfer
    (candidate : WorktreeTransferCandidate)
    (source target : WorktreeContextHead)
    (sourceAuthorized targetAuthorized targetApplicable : Bool)
    (foreign : candidate.targetWorktree ≠ target.worktree) :
    admitWorktreeTransfer candidate source target
      sourceAuthorized targetAuthorized targetApplicable = none := by
  simp [admitWorktreeTransfer, foreign]

theorem stale_target_cut_cannot_transfer
    (candidate : WorktreeTransferCandidate)
    (source target : WorktreeContextHead)
    (sourceAuthorized targetAuthorized targetApplicable : Bool)
    (stale : candidate.targetCut ≠ target.sourceCut) :
    admitWorktreeTransfer candidate source target
      sourceAuthorized targetAuthorized targetApplicable = none := by
  simp [admitWorktreeTransfer, stale]

theorem refused_transfer_without_target_authority
    (candidate : WorktreeTransferCandidate)
    (source target : WorktreeContextHead)
    (sourceAuthorized targetApplicable : Bool) :
    admitWorktreeTransfer candidate source target
      sourceAuthorized false targetApplicable = none := by
  simp [admitWorktreeTransfer]

theorem accepted_transfer_advances_only_target
    (candidate : WorktreeTransferCandidate)
    (source target next : WorktreeContextHead)
    (sourceAuthorized targetAuthorized targetApplicable : Bool)
    (accepted : admitWorktreeTransfer candidate source target
      sourceAuthorized targetAuthorized targetApplicable = some next) :
    next.project = target.project ∧ next.worktree = target.worktree ∧
      next.sourceCut = target.sourceCut ∧
      next.revision = target.revision + 1 ∧ candidate.content ∈ next.refs := by
  unfold admitWorktreeTransfer at accepted
  split at accepted
  · cases accepted
    simp
  · contradiction

end AgenticAILabSessionProof.SharedContext
