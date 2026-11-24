-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
  Slice 54: Pure Durable Work Engine Core Formal Challenge (BUG-D1..BUG-D5).

  Unbounded algebraic & structural repair laws matching the exact real bugs
  uncovered by auditing:
  - `modules/durable/work/detour-engine.ss` (BUG-D1, BUG-D2)
  - `modules/durable/work/claims-engine.ss` (BUG-D3)
  - `modules/durable/work/scheduler.ss` (BUG-D1, BUG-D4)
  - `modules/ai-agentic-context/features/durable/org-adapter.ss` (BUG-D5)
-/

namespace DurableWorkEngineCoreChallenge

-- ===========================================================================
-- 1. BUG-D1: Monotonic Overlay Budget & Rule Meet vs Buggy Direct Overwrite
-- ===========================================================================

structure WorkPolicyBudget where
  maxConcurrency : Nat
  retryBudget : Nat
  maxDetourDepth : Nat
  allowAgentDrillDown : Bool
  deriving DecidableEq, Repr

/-- Repaired monotonic meet: hot overlays can only narrow parent budgets. -/
def overlayBudgetMeet (parent overlay : WorkPolicyBudget) : WorkPolicyBudget :=
  { maxConcurrency := Nat.min parent.maxConcurrency overlay.maxConcurrency
  , retryBudget := Nat.min parent.retryBudget overlay.retryBudget
  , maxDetourDepth := Nat.min parent.maxDetourDepth overlay.maxDetourDepth
  , allowAgentDrillDown := parent.allowAgentDrillDown && overlay.allowAgentDrillDown
  }

/-- Buggy original `work-apply-overlay` L178-180 + `default-work-effective-rules` L48. -/
def buggyOverwriteOverlay (_parent overlay : WorkPolicyBudget) : WorkPolicyBudget :=
  overlay

theorem buggyOverwriteOverlay_escalates_concurrency :
    ∃ p o : WorkPolicyBudget,
      (buggyOverwriteOverlay p o).maxConcurrency > p.maxConcurrency := by
  refine ⟨{ maxConcurrency := 2, retryBudget := 2, maxDetourDepth := 2, allowAgentDrillDown := false },
          { maxConcurrency := 6, retryBudget := 2, maxDetourDepth := 2, allowAgentDrillDown := true }, ?_⟩
  decide

theorem overlayBudgetMeet_never_escalates (p o : WorkPolicyBudget) :
    (overlayBudgetMeet p o).maxConcurrency ≤ p.maxConcurrency ∧
    (overlayBudgetMeet p o).retryBudget ≤ p.retryBudget ∧
    (overlayBudgetMeet p o).maxDetourDepth ≤ p.maxDetourDepth ∧
    ((overlayBudgetMeet p o).allowAgentDrillDown = true → p.allowAgentDrillDown = true) := by
  refine ⟨Nat.min_le_left _ _, Nat.min_le_left _ _, Nat.min_le_left _ _, ?_⟩
  intro h
  simp [overlayBudgetMeet] at h
  exact h.1

-- ===========================================================================
-- 2. BUG-D2: Tainted Detour CompletedExit APPA Confinement Gate
-- ===========================================================================

structure CompletedExitRequest where
  detourTainted : Bool
  hasReceiptDigest : Bool
  schemaAttested : Bool
  hasDeclassCert : Bool
  deriving DecidableEq, Repr

/-- Buggy original `DetourExitMethods` on `CompletedExit.` L85-103. -/
def buggyAdmitCompletedExit (req : CompletedExitRequest) : Bool :=
  req.hasReceiptDigest

/-- Repaired Slice 50+54 `CompletedExit.` admission gate. -/
def admitCompletedExit (req : CompletedExitRequest) : Bool :=
  req.hasReceiptDigest &&
  (!req.detourTainted || req.schemaAttested || req.hasDeclassCert)

theorem buggyCompletedExit_leaks_tainted_payload :
    ∃ req : CompletedExitRequest,
      req.detourTainted = true ∧
      req.schemaAttested = false ∧
      req.hasDeclassCert = false ∧
      buggyAdmitCompletedExit req = true := by
  refine ⟨{ detourTainted := true, hasReceiptDigest := true,
            schemaAttested := false, hasDeclassCert := false }, rfl, rfl, rfl, rfl⟩

theorem taintedDetourCompletedExit_requires_attestation_or_cert
    (req : CompletedExitRequest)
    (htaint : req.detourTainted = true)
    (hadmit : admitCompletedExit req = true) :
    req.schemaAttested = true ∨ req.hasDeclassCert = true := by
  simp [admitCompletedExit, htaint] at hadmit
  exact hadmit.2

-- ===========================================================================
-- 3. BUG-D5: Cancelled `:INVARIANT:` Remains Unsatisfied Fail-Closed
-- ===========================================================================

inductive HeadlineTodoState where
  | todo
  | inProgress
  | done
  | cancelled
  | failed
  deriving DecidableEq, Repr

/-- Repaired invariant satisfaction: only `done` satisfies an `:INVARIANT:`. -/
def invariantSatisfied (st : HeadlineTodoState) : Bool :=
  match st with
  | .done => true
  | _ => false

theorem cancelledInvariant_remains_unsatisfied_fail_closed :
    invariantSatisfied .cancelled = false ∧
    ∀ st : HeadlineTodoState, invariantSatisfied st = true → st = .done := by
  refine ⟨rfl, ?_⟩
  intro st h
  cases st <;> simp [invariantSatisfied] at h ⊢

-- ===========================================================================
-- 4. BUG-D4: Unclosed Attempts Unconditionally Block Auto-Archive
-- ===========================================================================

structure ArchiveQuiescenceState where
  rootDone : Bool
  dagValid : Bool
  dagComplete : Bool
  checklistsDone : Bool
  openBlockers : List Nat
  unsatisfiedInvariants : List Nat
  inFlightIds : List Nat
  pendingEffects : List Nat
  unclosedAttempts : List Nat
  alreadyArchived : Bool
  deriving DecidableEq, Repr

/-- Buggy original `run-ascent-work-rules` L119: ignores `unclosedAttempts`. -/
def buggyReadyToAutoArchive (s : ArchiveQuiescenceState) : Bool :=
  s.rootDone && s.dagValid && s.dagComplete && s.checklistsDone &&
  s.openBlockers.isEmpty && s.unsatisfiedInvariants.isEmpty &&
  s.inFlightIds.isEmpty && s.pendingEffects.isEmpty && !s.alreadyArchived

/-- Repaired quiescent archive guard: requires `unclosedAttempts.isEmpty`. -/
def readyToAutoArchive (s : ArchiveQuiescenceState) : Bool :=
  buggyReadyToAutoArchive s && s.unclosedAttempts.isEmpty

theorem buggyQuiescentCheck_archives_with_unclosed_attempt :
    ∃ s : ArchiveQuiescenceState,
      s.unclosedAttempts ≠ [] ∧ buggyReadyToAutoArchive s = true := by
  refine ⟨{ rootDone := true, dagValid := true, dagComplete := true, checklistsDone := true,
            openBlockers := [], unsatisfiedInvariants := [], inFlightIds := [],
            pendingEffects := [], unclosedAttempts := [1], alreadyArchived := false }, ?_, rfl⟩
  decide

theorem unclosedAttempt_blocks_autoArchive_fail_closed
    (s : ArchiveQuiescenceState) (hne : s.unclosedAttempts ≠ []) :
    readyToAutoArchive s = false := by
  have hempty : s.unclosedAttempts.isEmpty = false := by
    cases h : s.unclosedAttempts with
    | nil => exact absurd h hne
    | cons _ _ => rfl
  simp [readyToAutoArchive, hempty]

-- ===========================================================================
-- 5. BUG-D3: Authorized Explicit Handover & Expected-Epoch CAS Fencing
-- ===========================================================================

structure HandoverGuardInput where
  priorOwner : Nat
  nextActor : Nat
  endorser : Option Nat
  liveEpoch : Nat
  expectedEpoch : Option Nat
  now : Nat
  heartbeatAt : Nat
  leaseTtl : Nat
  forceExplicit : Bool
  hasCustody : Bool
  deriving DecidableEq, Repr

def leaseExpired (h : HandoverGuardInput) : Bool :=
  decide (h.now ≥ h.heartbeatAt + h.leaseTtl)

def nonSelfEndorsementValid (h : HandoverGuardInput) : Bool :=
  match h.endorser with
  | none => false
  | some e => decide (e ≠ h.nextActor)

def epochCasMatches (liveEpoch : Nat) (expected : Option Nat) : Bool :=
  match expected with
  | none => true
  | some exp => decide (exp = liveEpoch)

/-- Buggy original `work-handover!` L170: `forceExplicit = true` bypasses everything. -/
def buggyAdmitHandover (h : HandoverGuardInput) : Bool :=
  (h.forceExplicit || leaseExpired h) && h.hasCustody

/-- Repaired Slice 54 `work-handover!`: non-self endorsement + expected-epoch CAS. -/
def admitHandover (h : HandoverGuardInput) : Bool :=
  epochCasMatches h.liveEpoch h.expectedEpoch &&
  h.hasCustody &&
  (leaseExpired h || (h.forceExplicit && nonSelfEndorsementValid h))

theorem buggyForceExplicit_hijacks_active_lease :
    ∃ h : HandoverGuardInput,
      leaseExpired h = false ∧
      h.endorser = none ∧
      buggyAdmitHandover h = true := by
  refine ⟨{ priorOwner := 1, nextActor := 2, endorser := none,
            liveEpoch := 1, expectedEpoch := none,
            now := 15, heartbeatAt := 10, leaseTtl := 20,
            forceExplicit := true, hasCustody := true }, ?_, rfl, rfl⟩
  decide

theorem explicitEarlyHandover_requires_nonSelf_endorsement
    (h : HandoverGuardInput)
    (hactive : leaseExpired h = false)
    (hadmit : admitHandover h = true) :
    h.forceExplicit = true ∧
    ∃ e : Nat, h.endorser = some e ∧ e ≠ h.nextActor := by
  cases h with
  | mk priorOwner nextActor endorser liveEpoch expectedEpoch now heartbeatAt leaseTtl forceExplicit hasCustody =>
    cases endorser with
    | none =>
      simp [admitHandover, hactive, nonSelfEndorsementValid] at hadmit
    | some e =>
      simp [admitHandover, hactive, nonSelfEndorsementValid] at hadmit
      exact ⟨hadmit.2.1, e, rfl, hadmit.2.2⟩

theorem staleEpochCas_rejected_by_claim_and_handover
    (h : HandoverGuardInput) (exp : Nat)
    (hexp : h.expectedEpoch = some exp)
    (hstale : exp ≠ h.liveEpoch) :
    admitHandover h = false := by
  have hcas : epochCasMatches h.liveEpoch h.expectedEpoch = false := by
    simp [epochCasMatches, hexp, hstale]
  simp [admitHandover, hcas]

end DurableWorkEngineCoreChallenge
