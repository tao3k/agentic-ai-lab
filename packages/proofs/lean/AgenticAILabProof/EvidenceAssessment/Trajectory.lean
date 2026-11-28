-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
/-! Trajectory observation semantics. Tokens are supplied by a trusted provider
adapter and correctness by an independent grader. These theorems neither prove
the grader nor reconstruct hidden model reasoning. -/
namespace AgenticAILabProof.Trajectory
structure Ledger where
  generation : Nat := 0
  cost : Nat := 0
  first : Option Nat := none
  usageKnown : Bool := true
  referenceGeneration : Option Nat := none
  consumptionGeneration : Option Nat := none
  deriving DecidableEq, Repr

def call (s : Ledger) (tokens : Nat) : Ledger := { s with cost := s.cost + tokens }
def unknownCall (s : Ledger) : Ledger := { s with usageKnown := false }
def verify (s : Ledger) : Ledger :=
  { s with first := match s.first with | none => some s.cost | some n => some n }
def evidence (s : Ledger) : Ledger := { s with referenceGeneration := some s.generation }
def invalidate (s : Ledger) : Ledger := { generation := s.generation + 1 }
def reusable (s : Ledger) : Prop := s.referenceGeneration = some s.generation
def verifySubgoal (s : Ledger) : Ledger := s

-- accepted is the trusted closed-query kernel verdict, not model self-report.
def consume (s : Ledger) (accepted : Bool) : Ledger :=
  if accepted ∧ s.referenceGeneration = some s.generation then
    { s with consumptionGeneration := some s.generation }
  else s
def verifyConsumed (s : Ledger) : Ledger :=
  if s.consumptionGeneration = some s.generation then verify s else s

theorem rejected_intent_is_atomic (s : Ledger) : consume s false = s := by simp [consume]
theorem consumption_does_not_charge_tokens (s : Ledger) (accepted : Bool) :
    (consume s accepted).cost = s.cost := by simp [consume]; split <;> rfl
theorem unconsumed_path_cannot_freeze (s : Ledger)
    (h : s.consumptionGeneration ≠ some s.generation) :
    verifyConsumed s = s := by simp [verifyConsumed, h]
theorem invalidation_revokes_consumption (s : Ledger) :
    (invalidate s).consumptionGeneration = none := rfl
theorem admitted_consumption_keeps_entire_prefix (s : Ledger)
    (h : s.referenceGeneration = some s.generation) (first : s.first = none) :
    (verifyConsumed (consume s true)).first = some s.cost := by
  simp [consume, verifyConsumed, verify, h, first]

theorem subgoal_does_not_freeze_task (s : Ledger) :
    (verifySubgoal s).first = s.first := rfl

theorem missing_usage_is_unknown (s : Ledger) : (unknownCall s).usageKnown = false := rfl

theorem first_freezes (s : Ledger) (n tokens : Nat) (h : s.first = some n) :
    (call s tokens).first = some n := h

theorem failures_and_repairs_charged (s : Ledger) (failed repair : Nat) :
    (call (call s failed) repair).cost = s.cost + failed + repair := rfl

theorem first_captures_all_preceding_calls (s : Ledger) (h : s.first = none)
    (failed repair : Nat) :
    (verify (call (call s failed) repair)).first = some (s.cost + failed + repair) := by
  simp [verify, call, h]

theorem later_verdict_keeps_first (s : Ledger) (n : Nat) (h : s.first = some n) :
    (verify s).first = some n := by simp [verify, h]

theorem invalidation_revokes_reference (s : Ledger) : ¬ reusable (invalidate s) := by
  simp [reusable, invalidate]

theorem invalidation_starts_new_cost_epoch (s : Ledger) :
    (invalidate s).cost = 0 ∧ (invalidate s).first = none := by simp [invalidate]

theorem current_evidence_is_reusable (s : Ledger) : reusable (evidence s) := rfl

/- The observation API carries no preferred next operation. A known comparison
   and an idea absent from the packet are both choices made by the agent. -/
inductive Observation where
  | comparable | changedPremise | unknownPremise | historical | checkedResult
  deriving DecidableEq, Repr

inductive AgentChoice where
  | revisit (attempt : Nat)
  | novel (identity : String)
  deriving DecidableEq, Repr

structure ReasoningState where
  observations : List Observation := []
  agentChoice : Option AgentChoice := none
  deriving DecidableEq, Repr

def observe (s : ReasoningState) (fact : Observation) : ReasoningState :=
  { s with observations := fact :: s.observations }

def choose (s : ReasoningState) (choice : AgentChoice) : ReasoningState :=
  { s with agentChoice := some choice }

theorem observation_does_not_choose (s : ReasoningState) (fact : Observation) :
    (observe s fact).agentChoice = s.agentChoice := rfl

theorem any_choice_remains_available (s : ReasoningState)
    (fact : Observation) (choice : AgentChoice) :
    (choose (observe s fact) choice).agentChoice = some choice := rfl

theorem observation_cannot_override_choice (s : ReasoningState)
    (fact : Observation) (choice : AgentChoice) :
    (observe (choose s choice) fact).agentChoice = some choice := rfl

structure PrefixBinding where
  eventCount : Nat
  contentIdentity : String
  snapshotIdentity : String
  deriving DecidableEq, Repr

def prefixCurrent (packet : PrefixBinding) (count : Nat)
    (contentIdentity snapshotIdentity : String) : Bool :=
  packet.eventCount == count && packet.contentIdentity == contentIdentity &&
    packet.snapshotIdentity == snapshotIdentity

theorem current_prefix_requires_content_identity (packet : PrefixBinding)
    (count : Nat) (contentIdentity snapshotIdentity : String)
    (h : prefixCurrent packet count contentIdentity snapshotIdentity = true) :
    packet.contentIdentity = contentIdentity := by
  simp [prefixCurrent] at h
  exact h.1.2

theorem current_prefix_requires_snapshot_identity (packet : PrefixBinding)
    (count : Nat) (contentIdentity snapshotIdentity : String)
    (h : prefixCurrent packet count contentIdentity snapshotIdentity = true) :
    packet.snapshotIdentity = snapshotIdentity := by
  simp [prefixCurrent] at h
  exact h.2

example : prefixCurrent ⟨1, "old-content", "snapshot"⟩ 1 "new-content" "snapshot" = false := by decide
example : prefixCurrent ⟨1, "content", "old-snapshot"⟩ 1 "content" "new-snapshot" = false := by decide

/- A revised comparison rule has its own evidence lifecycle. An independent
   reviewer supplies `supported`; this type does not grade the rule itself. -/
structure Counterexample where
  id : Nat
  digest : String
  deriving DecidableEq, Repr

structure RuleRevision where
  source : Nat := 0
  counterexamples : List Counterexample := []
  draftSource : Option Nat := none
  ruleRevision : Nat := 0
  reviewedRevision : Option Nat := none
  reviewedExamples : Option (List Counterexample) := none
  supported : Bool := false
  published : Bool := false
  deriving DecidableEq, Repr

def recordCounterexample (s : RuleRevision) (item : Counterexample) : RuleRevision :=
  { s with counterexamples := s.counterexamples ++ [item], published := false }

def draftRule (s : RuleRevision) : RuleRevision :=
  { s with draftSource := some s.source, ruleRevision := s.ruleRevision + 1, reviewedRevision := none, reviewedExamples := none, supported := false, published := false }

def reviewRule (s : RuleRevision) (supported : Bool) : RuleRevision :=
  { s with reviewedRevision := some s.ruleRevision, reviewedExamples := some s.counterexamples, supported := supported, published := false }

def publishRule (s : RuleRevision) : RuleRevision :=
  if s.draftSource == some s.source ∧
     s.reviewedRevision == some s.ruleRevision ∧
     s.reviewedExamples == some s.counterexamples ∧ s.supported then
    { s with published := true }
  else { s with published := false }

def invalidateRule (s : RuleRevision) : RuleRevision :=
  { s with source := s.source + 1, published := false }

theorem counterexample_is_retained (s : RuleRevision) (item : Counterexample) :
    (recordCounterexample s item).counterexamples = s.counterexamples ++ [item] := rfl

theorem counterexample_revokes_publication (s : RuleRevision) (item : Counterexample) :
    (recordCounterexample s item).published = false := rfl

theorem invalidation_revokes_rule (s : RuleRevision) :
    (invalidateRule s).published = false := rfl

theorem publication_requires_current_review (s : RuleRevision)
    (h : (publishRule s).published = true) :
    s.draftSource = some s.source ∧
    s.reviewedRevision = some s.ruleRevision ∧
    s.reviewedExamples = some s.counterexamples ∧ s.supported = true := by
  unfold publishRule at h
  split at h <;> simp_all

example : (publishRule ({ source := 1, draftSource := some 1, ruleRevision := 1, reviewedRevision := some 1, counterexamples := [{ id := 7, digest := "new" }], reviewedExamples := some [{ id := 7, digest := "old" }], supported := true } : RuleRevision)).published = false := by decide

example : (verify (call (call {} 80) 30)).first = some 110 := by decide
example : (call (verify (call (call {} 80) 30)) 50).first = some 110 := by decide

/- A progressive read binds its complete view identity. These laws constrain
   admission of observations, not which hypothesis an Agent may investigate. -/
structure ProgressiveView where
  owner : String
  source : String
  prefixId : String
  receipt : Option String
  deriving DecidableEq, Repr

def sameView (observed current : ProgressiveView) : Bool :=
  observed.owner == current.owner && observed.source == current.source &&
    observed.prefixId == current.prefixId

def currentResult (observed current : ProgressiveView)
    (receiptAvailable independentlyReviewed : Bool) : Bool :=
  sameView observed current && observed.receipt.isSome &&
    observed.receipt == current.receipt &&
    receiptAvailable && independentlyReviewed

theorem current_result_requires_same_view (observed current : ProgressiveView)
    (available reviewed : Bool)
    (h : currentResult observed current available reviewed = true) :
    sameView observed current = true := by
  simp [currentResult] at h
  exact h.1.1.1.1

theorem missing_receipt_cannot_be_current (observed current : ProgressiveView)
    (reviewed : Bool) :
    currentResult observed current false reviewed = false := by
  simp [currentResult]

theorem absent_receipt_identity_cannot_be_current
    (observed current : ProgressiveView) (available reviewed : Bool)
    (h : observed.receipt = none) :
    currentResult observed current available reviewed = false := by
  simp [currentResult, h]

theorem unreviewed_receipt_cannot_be_current (observed current : ProgressiveView)
    (available : Bool) :
    currentResult observed current available false = false := by
  simp [currentResult]

theorem same_count_changed_content_is_stale (owner source oldContent newContent : String)
    (h : oldContent ≠ newContent) :
    sameView ⟨owner, source, oldContent, none⟩
      ⟨owner, source, newContent, none⟩ = false := by
  simp [sameView, h]

structure ProgressiveAccess where
  focusAvailable : Bool := true
  exactAvailable : Bool := true
  selected : Option AgentChoice := none
  deriving DecidableEq, Repr

def briefAccess (s : ProgressiveAccess) : ProgressiveAccess := s
def focusRead (s : ProgressiveAccess) : ProgressiveAccess := s
def exactRead (s : ProgressiveAccess) : ProgressiveAccess := s
def clueQueryRead (s : ProgressiveAccess) : ProgressiveAccess := s

theorem brief_keeps_open_reads (s : ProgressiveAccess) :
    (briefAccess s).focusAvailable = s.focusAvailable ∧
    (briefAccess s).exactAvailable = s.exactAvailable := by
  simp [briefAccess]

theorem reads_do_not_select (s : ProgressiveAccess) :
    (briefAccess s).selected = s.selected ∧
    (focusRead s).selected = s.selected ∧
    (exactRead s).selected = s.selected := by
  simp [briefAccess, focusRead, exactRead]

theorem focused_clue_read_does_not_select (s : ProgressiveAccess) :
    (clueQueryRead (focusRead s)).selected = s.selected := by
  simp [clueQueryRead, focusRead]

/- Agent clues remain distinct from admitted observations. Scope changes what
   is queried, not which hypotheses the Agent is permitted to formulate. -/
inductive ClueRole where
  | observation
  | hypothesis
  deriving DecidableEq, Repr

structure ScopedClue where
  role : ClueRole
  admitted : Bool
  receiptAvailable : Bool
  contentIdentity : String
  receiptContentIdentity : String
  near : Bool
  deriving DecidableEq, Repr

inductive QueryScope where
  | narrow
  | wide
  deriving DecidableEq, Repr

def clueSupports (clue : ScopedClue) (scope : QueryScope) : Bool :=
  (clue.role == .observation) && clue.admitted && clue.receiptAvailable &&
    (clue.contentIdentity == clue.receiptContentIdentity) &&
    (clue.near || scope == .wide)

inductive IdentityScope where
  | clueSource
  | catalog
  | context
  deriving DecidableEq, Repr

structure SourceBoundClue where
  clue : ScopedClue
  identityScope : IdentityScope := .clueSource
  sourceIdentity : String
  deriving DecidableEq, Repr

def sourceBoundSupport (clue : SourceBoundClue) (currentSource : String)
    (scope : QueryScope) : Bool :=
  (clue.identityScope == .clueSource) &&
    (clue.sourceIdentity == currentSource) && clueSupports clue.clue scope

theorem catalog_digest_is_not_source_support (clue : SourceBoundClue)
    (currentSource : String) (scope : QueryScope)
    (h : clue.identityScope = .catalog) :
    sourceBoundSupport clue currentSource scope = false := by
  simp [sourceBoundSupport, h]

theorem context_digest_is_not_source_support (clue : SourceBoundClue)
    (currentSource : String) (scope : QueryScope)
    (h : clue.identityScope = .context) :
    sourceBoundSupport clue currentSource scope = false := by
  simp [sourceBoundSupport, h]

theorem replaced_source_cannot_inherit_clue_support (clue : SourceBoundClue)
    (currentSource : String) (scope : QueryScope)
    (h : clue.sourceIdentity ≠ currentSource) :
    sourceBoundSupport clue currentSource scope = false := by
  simp [sourceBoundSupport, h]

theorem hypothesis_is_not_admitted_support (clue : ScopedClue)
    (h : clue.role = .hypothesis) (scope : QueryScope) :
    clueSupports clue scope = false := by
  simp [clueSupports, h]

theorem lost_receipt_is_not_current_support (clue : ScopedClue)
    (h : clue.receiptAvailable = false) (scope : QueryScope) :
    clueSupports clue scope = false := by
  simp [clueSupports, h]

theorem changed_content_cannot_inherit_receipt (clue : ScopedClue)
    (h : clue.contentIdentity ≠ clue.receiptContentIdentity)
    (scope : QueryScope) : clueSupports clue scope = false := by
  simp [clueSupports, h]

theorem widening_preserves_positive_support (clue : ScopedClue)
    (h : clueSupports clue .narrow = true) :
    clueSupports clue .wide = true := by
  simp [clueSupports] at h ⊢
  exact h.1

structure ConflictPair where
  positive : ScopedClue
  negative : ScopedClue
  deriving DecidableEq, Repr

def conflictView (pair : ConflictPair) (scope : QueryScope) : Bool × Bool :=
  (clueSupports pair.positive scope, clueSupports pair.negative scope)

theorem widening_retains_both_sides (pair : ConflictPair)
    (h : conflictView pair .narrow = (true, true)) :
    conflictView pair .wide = (true, true) := by
  have hp : clueSupports pair.positive .narrow = true := by
    simpa [conflictView] using congrArg Prod.fst h
  have hn : clueSupports pair.negative .narrow = true := by
    simpa [conflictView] using congrArg Prod.snd h
  simp [conflictView, widening_preserves_positive_support pair.positive hp,
    widening_preserves_positive_support pair.negative hn]
end AgenticAILabProof.Trajectory
