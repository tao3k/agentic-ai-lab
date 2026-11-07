import Std

/- Design-level contract owned by Agentic AI Lab modules/session. Runtime and MRR
   receipts are separate inputs; this model does not claim implementation
   refinement. -/
namespace AgenticAILabSessionProof.Lifecycle

/-- Design-level Session status. Runtime scheduling and physical head commit
remain with their owners. -/
inductive ContextSessionStatus where
  | active | suspended | closed | expired
  deriving DecidableEq, Repr

structure ContextSessionHead where
  key : Nat
  revision : Nat
  status : ContextSessionStatus
  nextTurn : Nat
  pending : Option Nat
  sourceCut : Nat
  deriving DecidableEq, Repr

structure ContextSessionRequest where
  key : Nat
  expectedRevision : Nat
  deriving DecidableEq, Repr

/-- Begin is a pure proposal. The runtime must compare and swap the head. -/
def beginContextTurn (head : ContextSessionHead)
    (request : ContextSessionRequest) : Option ContextSessionHead :=
  if head.status = .active ∧ head.pending = none ∧
      request.key = head.key ∧ request.expectedRevision = head.revision then
    some { head with
      revision := head.revision + 1
      pending := some head.nextTurn
      nextTurn := head.nextTurn + 1 }
  else none

structure ContextQueryUse where
  key : Nat
  turn : Nat
  cut : Nat
  queryBinding : Nat
  resultReceipt : Nat
  manifest : Nat
  deriving DecidableEq, Repr

/-- An admitted query use must match the pending Session, turn and source cut.
The receipt inputs stand for independently admitted Query/Context identities. -/
def bindContextQueryUse (head : ContextSessionHead) (candidate : ContextQueryUse)
    (currentCut : Nat) (authorized : Bool) : Option ContextQueryUse :=
  if head.status = .active ∧ head.key = candidate.key ∧
      head.pending = some candidate.turn ∧ head.sourceCut = currentCut ∧
      candidate.cut = currentCut ∧ authorized = true then
    some candidate
  else none

/-- Resume always requires a fresh owner decision and current source cut. -/
def resumeContextSession (head : ContextSessionHead) (validatedCut currentCut : Nat)
    (authorized : Bool) : Option ContextSessionHead :=
  if head.status = .suspended ∧ validatedCut = currentCut ∧
      authorized = true then
    some { head with
      revision := head.revision + 1
      status := .active
      sourceCut := currentCut }
  else none

theorem closed_session_cannot_begin (head : ContextSessionHead)
    (request : ContextSessionRequest) (closed : head.status = .closed) :
    beginContextTurn head request = none := by
  simp [beginContextTurn, closed]

theorem expired_session_cannot_begin (head : ContextSessionHead)
    (request : ContextSessionRequest) (expired : head.status = .expired) :
    beginContextTurn head request = none := by
  simp [beginContextTurn, expired]

theorem foreign_session_cannot_begin (head : ContextSessionHead)
    (request : ContextSessionRequest) (foreign : request.key ≠ head.key) :
    beginContextTurn head request = none := by
  simp [beginContextTurn, foreign]

theorem closed_session_cannot_resume (head : ContextSessionHead)
    (validatedCut currentCut : Nat) (authorized : Bool)
    (closed : head.status = .closed) :
    resumeContextSession head validatedCut currentCut authorized = none := by
  simp [resumeContextSession, closed]

theorem accepted_begin_preserves_key_and_advances (head next : ContextSessionHead)
    (request : ContextSessionRequest)
    (accepted : beginContextTurn head request = some next) :
    next.key = head.key ∧ next.revision = head.revision + 1 ∧
      next.pending = some head.nextTurn ∧ next.nextTurn = head.nextTurn + 1 := by
  unfold beginContextTurn at accepted
  split at accepted
  · cases accepted
    simp
  · contradiction

theorem accepted_query_use_has_exact_session_turn_cut
    (head : ContextSessionHead) (candidate receipt : ContextQueryUse)
    (currentCut : Nat) (authorized : Bool)
    (accepted : bindContextQueryUse head candidate currentCut authorized = some receipt) :
    receipt = candidate ∧ receipt.key = head.key ∧
      head.pending = some receipt.turn ∧ receipt.cut = currentCut := by
  unfold bindContextQueryUse at accepted
  split at accepted
  · rename_i guards
    cases accepted
    exact ⟨rfl, guards.2.1.symm, guards.2.2.1, guards.2.2.2.2.1⟩
  · contradiction

theorem foreign_query_use_cannot_bind (head : ContextSessionHead)
    (candidate : ContextQueryUse) (currentCut : Nat) (authorized : Bool)
    (foreign : candidate.key ≠ head.key) :
    bindContextQueryUse head candidate currentCut authorized = none := by
  have mismatch : head.key ≠ candidate.key := Ne.symm foreign
  simp [bindContextQueryUse, mismatch]

theorem accepted_resume_is_fresh (head next : ContextSessionHead)
    (validatedCut currentCut : Nat) (authorized : Bool)
    (accepted : resumeContextSession head validatedCut currentCut authorized = some next) :
    validatedCut = currentCut ∧ authorized = true ∧
      next.revision = head.revision + 1 ∧ next.sourceCut = currentCut ∧
      next.status = .active := by
  unfold resumeContextSession at accepted
  split at accepted
  · rename_i guards
    cases accepted
    exact ⟨guards.2.1, guards.2.2, rfl, rfl, rfl⟩
  · contradiction

end AgenticAILabSessionProof.Lifecycle
