-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
-- Design abstraction shared with RecoveryEvidenceInquiry; no runtime refinement.
namespace RecoveryEvidenceInquiry

inductive SupportUse where
  | r1 | r1Copy | w1 | w1v2
  deriving BEq, DecidableEq

inductive Lineage where
  | independent | indirect | unverified
  deriving BEq, DecidableEq

inductive Node where
  | r1Attribution | r1 | r1Copy | attemptCrosswalk | w1Attribution
  | w1Record | w1 | outcomeB | summaryB | w1v2
  deriving BEq, DecidableEq

def supportNode : SupportUse → Node
  | .r1 => .r1
  | .r1Copy => .r1Copy
  | .w1 => .w1
  | .w1v2 => .w1v2

def edges (lineage : Lineage) : List (Node × Node) :=
  let base := [(.r1Attribution, .r1), (.r1, .r1Copy),
    (.attemptCrosswalk, .w1Attribution), (.w1Attribution, .w1),
    (.w1Record, .w1), (.r1, .outcomeB), (.r1Copy, .outcomeB),
    (.w1, .outcomeB), (.outcomeB, .summaryB)]
  if lineage == .indirect then (.r1Attribution, .attemptCrosswalk) :: base else base

def spread (links : List (Node × Node)) : Nat → List Node → List Node
  | 0, seen => seen
  | n + 1, seen =>
    let next := (links.filter fun link => seen.contains link.1).map Prod.snd
    spread links n (seen ++ next).eraseDups

def impact (lineage : Lineage) : List Node :=
  spread (edges lineage) 9 [.r1Attribution]

def affectedUse (lineage : Lineage) (use : SupportUse) : Bool :=
  (impact lineage).contains (supportNode use)

def pendingUse (lineage : Lineage) : SupportUse → Bool
  | .w1 => decide (lineage = .unverified)
  | .r1 | .r1Copy | .w1v2 => false

def judgmentReview (lineage : Lineage) : List Node :=
  [Node.outcomeB, .summaryB].filter (impact lineage).contains

@[simp] theorem r1_affected (l : Lineage) : affectedUse l .r1 = true := by
  cases l <;> decide

@[simp] theorem copy_affected (l : Lineage) : affectedUse l .r1Copy = true := by
  cases l <;> decide

@[simp] theorem independent_w1_unaffected : affectedUse .independent .w1 = false := by
  decide

@[simp] theorem indirect_w1_affected : affectedUse .indirect .w1 = true := by
  decide

@[simp] theorem unverified_w1_unreached : affectedUse .unverified .w1 = false := by
  decide

theorem correction_reaches_judgments (l : Lineage) :
    judgmentReview l = [.outcomeB, .summaryB] := by
  cases l <;> decide

theorem correction_preserves_raw_w1_record (l : Lineage) :
    (impact l).contains .w1Record = false := by
  cases l <;> decide

structure Binding where
  id : String
  attempt : String
  effect : String
  write : String
  record : String
  deriving DecidableEq

-- These facts are supplied by Temporal's authorized evaluator.
structure Assessment where
  binding : Binding
  basisCut : Nat
  authorized : Bool
  lineageComplete : Bool
  dependsOnR1 : Bool
  committedEffect : Bool
  outcomeContested : Bool
  deriving DecidableEq

inductive ClaimKey where
  | appendCommitted | singleCommit | noReplayDispatch | oneReplayDispatch
  deriving DecidableEq

structure DispatchManifest where
  cut : Nat
  scope : String
  slots : List String
  authorized : Bool
  deriving DecidableEq

structure DispatchRow where
  slot : String
  cut : Nat
  scope : String
  authorized : Bool
  sealed : Bool
  event : String
  deriving DecidableEq

structure ClaimBasis where
  claim : ClaimKey
  digest : String
  evidence : String
  scope : String
  cut : Nat
  verified : Bool
  coverage : Bool
  count : Nat
  supports : Bool
  deriving DecidableEq

structure SummaryVersion where
  version : Nat
  parent : Nat
  cut : Nat
  reviewRevision : Nat
  assertions : List ClaimKey
  basis : List ClaimBasis
  dispatchManifests : List DispatchManifest
  dispatchRows : List DispatchRow
  withdrawn : List ClaimKey
  unresolved : List ClaimKey
  partialCoverage : Bool
  deriving DecidableEq

structure SummaryReview where
  revision : Nat := 0
  checked : List ClaimBasis := []
  drafts : List SummaryVersion := []
  published : List SummaryVersion := []
  archive : List Nat := []
  dispatchManifests : List DispatchManifest := []
  dispatchRows : List DispatchRow := []
  deriving DecidableEq

structure View where
  cut : Nat
  bytesSeen : Bool
  successUses : List SupportUse
  withdrawnUses : List SupportUse := []
  pendingUses : List SupportUse := []
  affectedJudgments : List Node := []
  w1Lineage : Lineage := .independent
  contested : Bool
  receiptCorrected : Bool := false
  admittedBasis : Option Assessment := none
  candidates : List Binding := []
  proposals : List String
  findings : List String
  priorCuts : List Nat
  successHistory : List Nat
  summary : SummaryReview := {}
  deriving DecidableEq

inductive Outcome where
  | unknown | succeeded
  deriving DecidableEq

def hasSuccess (v : View) : Bool := !v.successUses.isEmpty && !v.contested

def outcome (v : View) : Outcome :=
  if hasSuccess v then .succeeded else .unknown

-- This proposition names the original Attempt's question, not a new task.
def outcomeDuty (v : View) : Prop := outcome v = .unknown

def observeBytes (v : View) : View := { v with bytesSeen := true }
def propose (v : View) (clue : String) : View :=
  { v with proposals := clue :: v.proposals }
def findClue (v : View) (clue : String) : View :=
  { v with findings := clue :: v.findings }
def revise (v : View) (uses : List SupportUse) (conflict : Bool) : View :=
  { v with
    cut := v.cut + 1
    successUses := uses
    withdrawnUses := []
    pendingUses := []
    affectedJudgments := []
    contested := conflict
    receiptCorrected := false
    admittedBasis := none
    priorCuts := v.cut :: v.priorCuts
    successHistory := if hasSuccess v
      then v.cut :: v.successHistory else v.successHistory }

def admitSuccess (v : View) : View := revise v [.r1] false

def correctAttribution (v : View) : View :=
  let affected := affectedUse v.w1Lineage
  let pending := pendingUse v.w1Lineage
  { revise v (v.successUses.filter fun use => !affected use && !pending use)
      v.contested with
    receiptCorrected := true
    withdrawnUses := v.successUses.filter affected
    pendingUses := v.successUses.filter pending
    affectedJudgments := judgmentReview v.w1Lineage
    summary := { v.summary with archive := [1] } }

def isW1 : SupportUse → Bool
  | .w1 => true
  | .r1 | .r1Copy | .w1v2 => false

def isW1v2 : SupportUse → Bool
  | .w1v2 => true
  | _ => false

def bindingReview (v : View) : Bool :=
  !v.successUses.any isW1v2 && (v.withdrawnUses.any isW1 || v.pendingUses.any isW1)

def frontier (v : View) : List String :=
  if v.successUses.any isW1v2 then ["review-withdrawn-uses"]
  else if outcome v = .succeeded then
    if v.receiptCorrected then ["review-withdrawn-uses"] else ["check-dependencies"]
  else if bindingReview v then
    ["inspect-crosswalk", "validate-direct-binding", "independent-effect-record"]
  else if v.receiptCorrected then ["compare-identities", "independent-effect-record"]
  else ["receipt-source", "other-writer"]

def discoverBinding (v : View) (binding : Binding) : View :=
  { v with candidates := binding :: v.candidates }

structure Qualifies (cut : Nat) (a : Assessment) : Prop where
  current : a.basisCut = cut
  attempt : a.binding.attempt = "original-attempt"
  effect : a.binding.effect = "append-effect"
  write : a.binding.write = "storage-write-42"
  record : a.binding.record = "W1-record-digest"
  authorized : a.authorized = true
  complete : a.lineageComplete = true
  independent : a.dependsOnR1 = false
  committed : a.committedEffect = true

structure AdmissionGate (v : View) (a : Assessment) : Prop where
  corrected : v.receiptCorrected = true
  freshVersion : v.admittedBasis = none
  previousUseNeedsBinding : bindingReview v = true
  candidate : a.binding ∈ v.candidates
  qualified : Qualifies v.cut a

def readmitW1 (v : View) (a : Assessment) (_gate : AdmissionGate v a) : View :=
  { v with
    cut := v.cut + 1
    admittedBasis := some a
    successUses := .w1v2 :: v.successUses
    contested := v.contested || a.outcomeContested
    priorCuts := v.cut :: v.priorCuts
    summary := { v.summary with revision := 0, checked := [], drafts := [] } }

def summaryManifest : List ClaimKey := [.appendCommitted, .singleCommit, .noReplayDispatch]

def claimBasis (claim : ClaimKey) (cut : Nat) : ClaimBasis :=
  let (digest, evidence) := match claim with
    | .appendCommitted => ("append-committed-digest", "W1-v2")
    | .singleCommit => ("single-commit-digest", "storage-commit-audit-v2")
    | .noReplayDispatch => ("no-replay-dispatch-digest", "dispatch-audit-v2")
    | .oneReplayDispatch => ("one-replay-dispatch-digest", "dispatch-audit-v2")
  let scope := match claim with
    | .appendCommitted => "original-attempt/append-effect"
    | _ => "original-attempt/append-effect/recovery-window"
  let count := if claim = .noReplayDispatch then 0 else 1
  ⟨claim, digest, evidence, scope, cut, true, true, count, true⟩

def replayRefutation (cut : Nat) : ClaimBasis :=
  { claimBasis .noReplayDispatch cut with count := 1, coverage := false, supports := false }

def summaryAvailable (v : View) : Prop :=
  hasSuccess v = true ∧ v.successUses.any isW1v2 = true ∧ Node.summaryB ∈ v.affectedJudgments

def checkedClaims (v : View) : List ClaimKey :=
  v.summary.checked.map ClaimBasis.claim

def openSummaryClaims (v : View) : List ClaimKey :=
  summaryManifest.filter fun key => !(checkedClaims v).contains key

def claimReviewOpen (v : View) (key : ClaimKey) : Prop :=
  key ∈ summaryManifest ∧ key ∉ checkedClaims v

def positiveClaims (v : View) : List ClaimKey :=
  (v.summary.checked.filter ClaimBasis.supports).map ClaimBasis.claim

def refutedClaims (v : View) : List ClaimKey :=
  (v.summary.checked.filter fun basis => !basis.supports).map ClaimBasis.claim

def dispatchScope : String := "original-attempt/append-effect/recovery-window"

def requiredDispatchSlots : List String := ["A/early", "A/late", "B/early", "B/late"]

def expectedDispatchManifest (cut : Nat) : DispatchManifest :=
  ⟨cut, dispatchScope, requiredDispatchSlots, true⟩

structure QualifiedDispatchRow (cut : Nat) (row : DispatchRow) : Prop where
  required : row.slot ∈ requiredDispatchSlots
  current : row.cut = cut
  scope : row.scope = dispatchScope
  authorized : row.authorized = true
  sealed : row.sealed = true

structure CompleteDispatchCoverage (v : View) : Prop where
  manifest : expectedDispatchManifest v.cut ∈ v.summary.dispatchManifests
  everySlot : ∀ slot ∈ requiredDispatchSlots, ∃ row ∈ v.summary.dispatchRows, row.slot = slot
  qualified : ∀ row ∈ v.summary.dispatchRows, QualifiedDispatchRow v.cut row
  unique : ∀ a ∈ v.summary.dispatchRows, ∀ b ∈ v.summary.dispatchRows, a.slot = b.slot → a = b

def replayIds (v : View) : List String :=
  (v.summary.dispatchRows.filterMap fun row =>
    if row.event = "" then none else some row.event).eraseDups

def dispatchCoverageReviewOpen (v : View) : Prop :=
  replayIds v ≠ [] ∧ ¬ CompleteDispatchCoverage v

def exactReplayReviewOpen (v : View) : Prop :=
  replayIds v ≠ [] ∧ ClaimKey.oneReplayDispatch ∉ checkedClaims v

theorem complete_coverage_closes_coverage_review (v : View)
    (covered : CompleteDispatchCoverage v) : ¬ dispatchCoverageReviewOpen v :=
  fun openReview => openReview.2 covered

def dispatchBasesAllowed (v : View) (basis : ClaimBasis) : Prop :=
  if basis.claim = .noReplayDispatch ∧ basis.supports = false then
    ∃ row ∈ v.summary.dispatchRows, QualifiedDispatchRow v.cut row ∧ row.event ≠ ""
  else if basis.claim = .noReplayDispatch ∨ basis.claim = .oneReplayDispatch then
    CompleteDispatchCoverage v ∧ (replayIds v).length = basis.count
  else True

structure ClaimGate (v : View) (basis : ClaimBasis) : Prop where
  available : summaryAvailable v
  exact : basis = claimBasis basis.claim v.cut ∨ basis = replayRefutation v.cut
  dispatchEvidence : dispatchBasesAllowed v basis
  replacementCompatible : basis.claim = .oneReplayDispatch → ClaimKey.noReplayDispatch ∉ positiveClaims v
  originalCompatible : basis.claim = .noReplayDispatch → basis.supports = true →
    ClaimKey.oneReplayDispatch ∉ checkedClaims v
  unchecked : basis.claim ∉ checkedClaims v

def assessSummaryClaim (v : View) (basis : ClaimBasis) (_gate : ClaimGate v basis) : View :=
  { v with summary := { v.summary with revision := v.summary.revision + 1
                                       checked := basis :: v.summary.checked } }

def expectedSummary (v : View) : SummaryVersion :=
  ⟨v.summary.archive.length + 1, v.summary.archive.length, v.cut, v.summary.revision,
   positiveClaims v, v.summary.checked, v.summary.dispatchManifests, v.summary.dispatchRows,
   refutedClaims v,
   openSummaryClaims v, !(openSummaryClaims v).isEmpty⟩

def proposeSummary (v : View) (draft : SummaryVersion) : View :=
  { v with summary := { v.summary with drafts := draft :: v.summary.drafts } }

structure SummaryGate (v : View) (draft : SummaryVersion) : Prop where
  available : summaryAvailable v
  proposed : draft ∈ v.summary.drafts
  exact : draft = expectedSummary v
  includesEffect : ClaimKey.appendCommitted ∈ draft.assertions
  rewriteDisclosesWithdrawal : ClaimKey.oneReplayDispatch ∈ draft.assertions →
    ClaimKey.noReplayDispatch ∈ draft.withdrawn
  newReviewRevision : ∀ p ∈ v.summary.published, p.reviewRevision ≠ draft.reviewRevision

def admitSummary (v : View) (draft : SummaryVersion) (_gate : SummaryGate v draft) : View :=
  { v with summary := { v.summary with published := draft :: v.summary.published
                                       archive := draft.version :: v.summary.archive } }

def summarySettled (v : View) : Bool :=
  (openSummaryClaims v).isEmpty &&
    v.summary.published.any (fun p => p.reviewRevision == v.summary.revision)

def keepSummaryReview (v : View) : Node → Bool
  | .outcomeB => false
  | .summaryB => !summarySettled v
  | _ => true

def currentJudgmentReview (v : View) : List Node :=
  if v.successUses.any isW1v2 && hasSuccess v then
    v.affectedJudgments.filter (keepSummaryReview v) else v.affectedJudgments

def directBinding : Binding :=
  ⟨"D1", "original-attempt", "append-effect", "storage-write-42", "W1-record-digest"⟩

def verifiedDirect (cut : Nat) : Assessment :=
  ⟨directBinding, cut, true, true, false, true, false⟩

theorem checked_direct_binding_can_admit (v : View)
    (corrected : v.receiptCorrected = true) (fresh : v.admittedBasis = none)
    (needsBinding : bindingReview v = true) :
    AdmissionGate (discoverBinding v directBinding) (verifiedDirect v.cut) := by
  refine ⟨corrected, fresh, needsBinding, ?_, ?_⟩
  · simp [discoverBinding, verifiedDirect]
  · exact ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

theorem binding_discovery_preserves_outcome (v : View) (b : Binding) :
    outcome (discoverBinding v b) = outcome v ∧
      bindingReview (discoverBinding v b) = bindingReview v :=
  ⟨rfl, rfl⟩

theorem stale_assessment_cannot_admit (v : View) (a : Assessment)
    (stale : a.basisCut ≠ v.cut) : ¬ AdmissionGate v a :=
  fun gate => stale gate.qualified.current

theorem different_write_cannot_admit (v : View) (a : Assessment)
    (different : a.binding.write ≠ "storage-write-42") : ¬ AdmissionGate v a :=
  fun gate => different gate.qualified.write

theorem dependent_binding_cannot_admit (v : View) (a : Assessment)
    (dependent : a.dependsOnR1 = true) : ¬ AdmissionGate v a := by
  intro gate
  have impossible := gate.qualified.independent
  simp [dependent] at impossible

theorem admitted_version_closes_binding_review (v : View) (a : Assessment)
    (gate : AdmissionGate v a) :
    bindingReview (readmitW1 v a gate) = false := by
  simp [readmitW1, bindingReview, isW1v2]

theorem readmission_recovers_success_when_uncontested (v : View) (a : Assessment)
    (gate : AdmissionGate v a) (before : v.contested = false)
    (current : a.outcomeContested = false) :
    outcome (readmitW1 v a gate) = .succeeded ∧ ¬ outcomeDuty (readmitW1 v a gate) := by
  simp [readmitW1, outcome, outcomeDuty, hasSuccess, before, current]

theorem readmission_keeps_outcome_open_when_contested (v : View) (a : Assessment)
    (gate : AdmissionGate v a) (conflict : a.outcomeContested = true) :
    outcomeDuty (readmitW1 v a gate) := by
  simp [readmitW1, outcomeDuty, outcome, hasSuccess, conflict]

theorem readmission_resolves_effect_review_when_uncontested
    (v : View) (a : Assessment) (gate : AdmissionGate v a)
    (before : v.contested = false) (current : a.outcomeContested = false) :
    Node.outcomeB ∉ currentJudgmentReview (readmitW1 v a gate) := by
  simp [readmitW1, currentJudgmentReview, isW1v2, hasSuccess, before,
    current, keepSummaryReview]

theorem readmission_retains_history_and_summary_review (v : View) (a : Assessment)
    (gate : AdmissionGate v a) (summary : Node.summaryB ∈ v.affectedJudgments) :
    let next := readmitW1 v a gate
    next.withdrawnUses = v.withdrawnUses ∧
      next.pendingUses = v.pendingUses ∧
      next.successHistory = v.successHistory ∧
      next.affectedJudgments = v.affectedJudgments ∧
      next.admittedBasis = some a ∧
      v.cut ∈ next.priorCuts ∧
      Node.summaryB ∈ currentJudgmentReview next := by
  simp [readmitW1, currentJudgmentReview, isW1v2, hasSuccess]
  split <;> simp [keepSummaryReview, summarySettled, openSummaryClaims,
    checkedClaims, summaryManifest, summary]

theorem w1_cannot_verify_audit_claim (v : View) (basis : ClaimBasis)
    (audit : basis.claim ≠ .appendCommitted) (source : basis.evidence = "W1-v2") :
    ¬ ClaimGate v basis := by
  intro gate
  rcases gate.exact with positive | refutes
  · have same := congrArg ClaimBasis.evidence positive
    cases key : basis.claim <;> simp [claimBasis, key, source] at audit same
  · have same := congrArg ClaimBasis.evidence refutes
    simp [replayRefutation, claimBasis, source] at same

theorem assessed_claim_closes_its_review (v : View) (basis : ClaimBasis)
    (gate : ClaimGate v basis) :
    ¬ claimReviewOpen (assessSummaryClaim v basis gate) basis.claim := by
  simp [claimReviewOpen, assessSummaryClaim, checkedClaims]

theorem other_claim_review_unchanged (v : View) (basis : ClaimBasis)
    (gate : ClaimGate v basis) (other : ClaimKey) (distinct : other ≠ basis.claim) :
    claimReviewOpen (assessSummaryClaim v basis gate) other ↔ claimReviewOpen v other := by
  simp [claimReviewOpen, assessSummaryClaim, checkedClaims, distinct]

theorem scoped_summary_can_admit (v : View) (available : summaryAvailable v)
    (effect : ClaimKey.appendCommitted ∈ positiveClaims v)
    (rewrite : ClaimKey.oneReplayDispatch ∈ positiveClaims v → ClaimKey.noReplayDispatch ∈ refutedClaims v)
    (fresh : ∀ p ∈ v.summary.published, p.reviewRevision ≠ v.summary.revision) :
    SummaryGate (proposeSummary v (expectedSummary v)) (expectedSummary v) :=
  ⟨available, List.mem_cons_self, rfl, effect, rewrite, fresh⟩

theorem stale_summary_review_cannot_admit (v : View) (draft : SummaryVersion)
    (stale : draft.reviewRevision ≠ v.summary.revision) : ¬ SummaryGate v draft := by
  intro gate
  exact stale (congrArg SummaryVersion.reviewRevision gate.exact)

theorem admitted_summary_assertions_and_open_items_exact (v : View) (draft : SummaryVersion)
    (gate : SummaryGate v draft) :
    draft.assertions = positiveClaims v ∧ draft.basis = v.summary.checked ∧
      draft.withdrawn = refutedClaims v ∧
      draft.unresolved = openSummaryClaims v ∧ draft.partialCoverage = !(draft.unresolved.isEmpty) := by
  rw [gate.exact]
  exact ⟨rfl, rfl, rfl, rfl, rfl⟩

theorem replay_refutation_closes_review_and_records_withdrawal (v : View)
    (gate : ClaimGate v (replayRefutation v.cut)) :
    let reviewed := assessSummaryClaim v (replayRefutation v.cut) gate
    ¬ claimReviewOpen reviewed .noReplayDispatch ∧
      ClaimKey.noReplayDispatch ∈ (expectedSummary reviewed).withdrawn ∧
      ClaimKey.noReplayDispatch ∉ (expectedSummary reviewed).assertions := by
  have unchecked : ClaimKey.noReplayDispatch ∉ checkedClaims v := gate.unchecked
  refine ⟨assessed_claim_closes_its_review v (replayRefutation v.cut) gate, ?_, ?_⟩
  · simp [expectedSummary, refutedClaims, assessSummaryClaim, replayRefutation, claimBasis]
  · intro asserted
    simp [expectedSummary, positiveClaims, assessSummaryClaim, replayRefutation, claimBasis] at asserted
    rcases asserted with ⟨basis, ⟨present, _⟩, eq⟩
    exact unchecked (List.mem_map.mpr ⟨basis, present, eq⟩)

theorem exact_replay_rewrite_requires_complete_coverage (v : View) (basis : ClaimBasis)
    (replacement : basis.claim = .oneReplayDispatch) (gate : ClaimGate v basis) :
    basis.coverage = true := by
  rcases gate.exact with exact | refutes
  · calc
      basis.coverage = (claimBasis basis.claim v.cut).coverage :=
        congrArg ClaimBasis.coverage exact
      _ = true := by simp [claimBasis, replacement]
  · have wrongKey := congrArg ClaimBasis.claim refutes
    simp [replayRefutation, claimBasis, replacement] at wrongKey

theorem witnessed_replay_refutes_without_full_coverage (v : View) (row : DispatchRow)
    (available : summaryAvailable v)
    (unchecked : ClaimKey.noReplayDispatch ∉ checkedClaims v)
    (inLog : row ∈ v.summary.dispatchRows) (qualified : QualifiedDispatchRow v.cut row)
    (observed : row.event ≠ "") :
    ClaimGate v (replayRefutation v.cut) := by
  refine ⟨available, Or.inr rfl, ?_, ?_, ?_, unchecked⟩
  · exact ⟨row, inLog, qualified, observed⟩
  · simp [replayRefutation, claimBasis]
  · simp [replayRefutation]

theorem missing_b_late_blocks_exact_replay (v : View)
    (missing : ∀ row ∈ v.summary.dispatchRows, row.slot ≠ "B/late") :
    ¬ ClaimGate v (claimBasis .oneReplayDispatch v.cut) := by
  intro gate
  have exact := gate.dispatchEvidence
  change CompleteDispatchCoverage v ∧ (replayIds v).length = 1 at exact
  obtain ⟨row, present, eq⟩ := exact.1.everySlot "B/late" (by simp [requiredDispatchSlots])
  exact missing row present eq

theorem complete_coverage_and_one_id_allow_exact_replay (v : View)
    (available : summaryAvailable v)
    (coverage : CompleteDispatchCoverage v) (one : (replayIds v).length = 1)
    (compatible : ClaimKey.noReplayDispatch ∉ positiveClaims v)
    (unchecked : ClaimKey.oneReplayDispatch ∉ checkedClaims v) :
    ClaimGate v (claimBasis .oneReplayDispatch v.cut) := by
  refine ⟨available, Or.inl rfl, ?_, ?_, ?_, unchecked⟩
  · exact ⟨coverage, one⟩
  · intro _
    exact compatible
  · simp [claimBasis]

theorem two_distinct_replays_block_exact_one (v : View)
    (two : (replayIds v).length = 2) :
    ¬ ClaimGate v (claimBasis .oneReplayDispatch v.cut) := by
  intro gate
  have exact := gate.dispatchEvidence
  change CompleteDispatchCoverage v ∧ (replayIds v).length = 1 at exact
  have impossible : (2 : Nat) = 1 := two.symm.trans exact.2
  exact (by decide : (2 : Nat) ≠ 1) impossible

theorem exact_assessment_closes_count_review (v : View)
    (gate : ClaimGate v (claimBasis .oneReplayDispatch v.cut)) :
    ¬ exactReplayReviewOpen (assessSummaryClaim v (claimBasis .oneReplayDispatch v.cut) gate) := by
  simp [exactReplayReviewOpen, assessSummaryClaim, checkedClaims, claimBasis]

theorem exact_replay_publication_retains_coverage_basis (v : View) (draft : SummaryVersion)
    (gate : SummaryGate v draft) :
    draft.dispatchManifests = v.summary.dispatchManifests ∧
      draft.dispatchRows = v.summary.dispatchRows := by
  rw [gate.exact]
  exact ⟨rfl, rfl⟩

theorem replay_rewrite_requires_disclosed_withdrawal (v : View) (draft : SummaryVersion)
    (gate : SummaryGate v draft) (rewritten : ClaimKey.oneReplayDispatch ∈ draft.assertions) :
    ClaimKey.noReplayDispatch ∈ draft.withdrawn :=
  gate.rewriteDisclosesWithdrawal rewritten

theorem summary_admission_preserves_prior_versions_and_claim_review (v : View)
    (draft : SummaryVersion) (gate : SummaryGate v draft) :
    (∀ id ∈ v.summary.archive, id ∈ (admitSummary v draft gate).summary.archive) ∧
      (∀ p ∈ v.summary.published, p ∈ (admitSummary v draft gate).summary.published) ∧
      (∀ key, claimReviewOpen (admitSummary v draft gate) key ↔ claimReviewOpen v key) := by
  exact ⟨fun _ h => List.mem_cons_of_mem _ h,
    fun _ h => List.mem_cons_of_mem _ h, fun _ => Iff.rfl⟩

theorem partial_summary_leaves_aggregate_review_open (v : View)
    (draft : SummaryVersion) (gate : SummaryGate v draft)
    (openItems : openSummaryClaims v ≠ []) :
    summarySettled (admitSummary v draft gate) = false := by
  cases items : openSummaryClaims v with
  | nil => exact False.elim (openItems items)
  | cons key rest =>
    change ((openSummaryClaims v).isEmpty && _) = false
    simp [items]

theorem full_summary_admission_settles_aggregate_review (v : View)
    (draft : SummaryVersion) (gate : SummaryGate v draft)
    (allChecked : openSummaryClaims v = []) :
    summarySettled (admitSummary v draft gate) = true := by
  have fresh := congrArg SummaryVersion.reviewRevision gate.exact
  change draft.reviewRevision = v.summary.revision at fresh
  change ((openSummaryClaims v).isEmpty &&
    (draft :: v.summary.published).any (fun p => p.reviewRevision == v.summary.revision)) = true
  simp [allChecked, fresh]

theorem admitted_success_resolves (v : View) :
    outcome (admitSuccess v) = .succeeded ∧
    ¬ outcomeDuty (admitSuccess v) ∧
    frontier (admitSuccess v) = ["check-dependencies"] := by
  simp [admitSuccess, revise, hasSuccess, outcome, outcomeDuty, frontier, isW1v2]

theorem attributed_success_then_correction (v : View) :
    let accepted := admitSuccess v
    let corrected := correctAttribution accepted
    outcome corrected = .unknown ∧ outcomeDuty corrected ∧
      accepted.cut ∈ corrected.priorCuts ∧
      accepted.cut ∈ corrected.successHistory ∧
      corrected.bytesSeen = accepted.bytesSeen ∧
      frontier corrected = ["compare-identities", "independent-effect-record"] := by
  simp [correctAttribution, admitSuccess, revise, pendingUse, hasSuccess,
    outcome, outcomeDuty, frontier, bindingReview, isW1]

theorem copied_support_cannot_survive (v : View) :
    let corrected := correctAttribution (revise v [.r1, .r1Copy] false)
    corrected.successUses = [] ∧ corrected.withdrawnUses = [.r1, .r1Copy] ∧
      outcomeDuty corrected := by
  simp [correctAttribution, revise, pendingUse, hasSuccess, outcome, outcomeDuty]

theorem independent_support_keeps_outcome_resolved (v : View) :
    let accepted := revise { v with w1Lineage := .independent } [.r1, .r1Copy, .w1] false
    let corrected := correctAttribution accepted
    corrected.successUses = [.w1] ∧ corrected.withdrawnUses = [.r1, .r1Copy] ∧
      outcome corrected = .succeeded ∧ ¬ outcomeDuty corrected ∧
      accepted.cut ∈ corrected.successHistory ∧
      frontier corrected = ["review-withdrawn-uses"] := by
  simp [correctAttribution, revise, pendingUse, hasSuccess, outcome, outcomeDuty, frontier, isW1v2] <;> rfl

theorem correction_preserves_independent_use (v : View)
    (independent : v.w1Lineage = .independent) :
    SupportUse.w1 ∈ (correctAttribution v).successUses ↔
      SupportUse.w1 ∈ v.successUses := by
  simp [correctAttribution, revise, pendingUse, independent]

theorem indirect_binding_reopens_outcome (v : View) :
    let accepted := revise { v with w1Lineage := .indirect } [.r1, .w1] false
    let corrected := correctAttribution accepted
    corrected.successUses = [] ∧ corrected.withdrawnUses = [.r1, .w1] ∧
      corrected.affectedJudgments = [.outcomeB, .summaryB] ∧
      outcomeDuty corrected ∧ bindingReview corrected = true ∧
      accepted.cut ∈ corrected.successHistory := by
  simp [correctAttribution, revise, pendingUse, correction_reaches_judgments,
    hasSuccess, outcome, outcomeDuty, bindingReview, isW1] <;> rfl

theorem missing_lineage_cannot_supply_success (v : View) :
    let accepted := revise { v with w1Lineage := .unverified } [.r1, .w1] false
    let corrected := correctAttribution accepted
    corrected.successUses = [] ∧ corrected.withdrawnUses = [.r1] ∧
      corrected.pendingUses = [.w1] ∧ outcomeDuty corrected ∧
      bindingReview corrected = true := by
  simp [correctAttribution, revise, pendingUse, hasSuccess, outcome,
    outcomeDuty, bindingReview, isW1] <;> rfl

theorem appearance_preserves_outcome (v : View) :
    outcome (observeBytes v) = outcome v := rfl

theorem proposals_preserve_outcome (v : View) (clue : String) :
    outcome (propose v clue) = outcome v := rfl

theorem candidate_findings_preserve_outcome (v : View) (clue : String) :
    outcome (findClue v clue) = outcome v := rfl

theorem no_admission_no_success (v : View) (h : v.successUses = []) :
    outcome v = .unknown := by simp [outcome, hasSuccess, h]

theorem conflict_keeps_question_open (v : View) (h : v.contested = true) :
    outcomeDuty v := by simp [outcomeDuty, outcome, hasSuccess, h]

theorem correction_reopens_question (v : View) :
    outcomeDuty (revise v [] false) := by
  simp [outcomeDuty, outcome, hasSuccess, revise]

theorem revision_retains_previous_cut (v : View) (s : List SupportUse) (c : Bool) :
    v.cut ∈ (revise v s c).priorCuts := by simp [revise]

theorem revision_retains_history (v : View) (s : List SupportUse) (c : Bool) (old : Nat)
    (h : old ∈ v.priorCuts) : old ∈ (revise v s c).priorCuts := by
  simp [revise, h]

-- Independent guards remain separate from evidence admission and exploration.
def eligible (v : View) (binding permission repeatSafe proposal : Bool) : Prop :=
  binding = true ∧ permission = true ∧ repeatSafe = true ∧ proposal = true ∧
  outcome v ≠ .succeeded

theorem successful_effect_veto (v : View) (b p r q : Bool)
    (h : outcome v = .succeeded) : ¬ eligible v b p r q := by
  intro e
  exact e.2.2.2.2 h

theorem eligibility_requires_both_guards (v : View) (b p r q : Bool)
    (h : eligible v b p r q) : p = true ∧ r = true :=
  ⟨h.2.1, h.2.2.1⟩

-- Arbitrarily many observations/proposals cannot manufacture completion.
inductive InquiryStep : View → View → Prop where
  | observe (v) : InquiryStep v (observeBytes v)
  | propose (v) (clue) : InquiryStep v (propose v clue)
  | find (v) (clue) : InquiryStep v (findClue v clue)
  | wait (v) : InquiryStep v v

theorem inquiry_preserves_outcome {a b : View} (h : InquiryStep a b) :
    outcome b = outcome a := by cases h <;> rfl

inductive InquiryTrace : View → View → Prop where
  | refl (v) : InquiryTrace v v
  | next {a b c} : InquiryTrace a b → InquiryStep b c → InquiryTrace a c

theorem inquiry_trace_preserves_unknown {a b : View}
    (trace : InquiryTrace a b) (h : outcomeDuty a) : outcomeDuty b := by
  induction trace with
  | refl => exact h
  | next prior step ih =>
    unfold outcomeDuty at *
    exact (inquiry_preserves_outcome step).trans ih

end RecoveryEvidenceInquiry

namespace DispatchSealRevision

open RecoveryEvidenceInquiry

inductive ReplayClaim where
  | atLeastOne
  | atLeastTwo | exactOne | exactTwo
  deriving DecidableEq

structure DispatchIdentity where
  id : String
  slot : String
  attempt : String
  effect : String
  time : Nat
  cut : Nat
  authorized : Bool
  replay : Bool
  deriving DecidableEq

structure ExactTwoBasis where
  cut : Nat
  manifests : List DispatchManifest
  rows : List DispatchRow
  first : DispatchIdentity
  second : DispatchIdentity
  deriving DecidableEq

structure AliasCorrection where
  target : ExactTwoBasis
  scope : String
  authorized : Bool
  deriving DecidableEq

structure LateDiscovery where
  prior : DispatchIdentity
  discovered : DispatchIdentity
  deriving DecidableEq

structure CopyObservation where
  record : String
  canonical : DispatchIdentity
  attested : Bool
  deriving DecidableEq

structure Snapshot where
  cut : Nat
  claim : ReplayClaim
  manifests : List DispatchManifest
  rows : List DispatchRow
  identityBasis : Option ExactTwoBasis
  correction : Option AliasCorrection := none
  late : Option LateDiscovery := none
  deriving DecidableEq

structure Revision where
  cut : Nat
  manifests : List DispatchManifest
  rows : List DispatchRow
  exactAssessed : Bool
  exactTwoBasis : Option ExactTwoBasis := none
  selected : Option Snapshot
  history : List Snapshot
  correction : Option AliasCorrection := none
  late : Option LateDiscovery := none
  copies : List CopyObservation := []

-- The projection reads dispatch evidence at its own cut. The effect owner's
-- View supplies the rest of the context and is not updated by this projection.
def coverageView (v : View) (d : Revision) : View :=
  { v with cut := d.cut
           summary := { v.summary with dispatchManifests := d.manifests, dispatchRows := d.rows } }

def correctSeal (d : Revision) : Revision :=
  { d with cut := d.cut + 1, manifests := [], rows := [], exactAssessed := false, exactTwoBasis := none, selected := none, late := none }

def qualifyRange (d : Revision) (row : DispatchRow)
    (_qualified : QualifiedDispatchRow d.cut row)
    (_freshSlot : ∀ prior ∈ d.rows, prior.slot ≠ row.slot) : Revision :=
  { d with rows := row :: d.rows }

def correctedExactOne (v : View) (d : Revision) (c : AliasCorrection) : Prop :=
  c.target.cut + 1 = d.cut ∧ c.authorized = true ∧ c.scope = dispatchScope ∧
    replayIds (coverageView v d) = [c.target.first.id] ∧
    (∃ r ∈ d.rows, r.slot = c.target.first.slot ∧ r.event = c.target.first.id) ∧
    (∃ r ∈ d.rows, r.slot = c.target.second.slot ∧ r.event = "")

def exactBasis (v : View) (d : Revision) : Prop :=
  CompleteDispatchCoverage (coverageView v d) ∧ (replayIds (coverageView v d)).length = 1 ∧
    (match d.correction with
     | some c => correctedExactOne v d c
     | none => d.cut < 2) ∧ d.late = none

def assessExact (v : View) (d : Revision) (_basis : exactBasis v d) : Revision :=
  { d with exactAssessed := true }

structure ScopedReplay (cut : Nat) (x : DispatchIdentity) : Prop where
  current : x.cut = cut
  authorized : x.authorized = true
  replay : x.replay = true
  nonempty : x.id ≠ ""
  attempt : x.attempt = "original-attempt"
  effect : x.effect = "append-effect"
  opens : 10 ≤ x.time
  closes : x.time < 20

structure QualifiedIdentity (cut : Nat) (rows : List DispatchRow) (x : DispatchIdentity) : Prop where
  scope : ScopedReplay cut x
  included : ∃ r ∈ rows, QualifiedDispatchRow cut r ∧ r.slot = x.slot ∧ r.event = x.id

structure KnownCopy (d : Revision) (copy : CopyObservation) : Prop where
  attested : copy.attested = true
  recordPresent : copy.record ≠ ""
  canonicalKnown : QualifiedIdentity d.cut d.rows copy.canonical
  consistent : ∀ old ∈ d.copies, old.record = copy.record → old = copy

def observeKnownCopy (d : Revision) (copy : CopyObservation) (_known : KnownCopy d copy) : Revision :=
  { d with copies := if copy ∈ d.copies then d.copies else copy :: d.copies }

theorem copy_keeps_count_and_selection (v : View) (d : Revision)
    (copy : CopyObservation) (known : KnownCopy d copy) :
    let next := observeKnownCopy d copy known
    next.cut = d.cut ∧ coverageView v next = coverageView v d ∧
      next.exactAssessed = d.exactAssessed ∧ next.exactTwoBasis = d.exactTwoBasis ∧
      next.selected = d.selected ∧ next.history = d.history :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

theorem repeated_copy_is_idempotent (d : Revision) (copy : CopyObservation)
    (known : KnownCopy d copy) (seen : copy ∈ d.copies) :
    observeKnownCopy d copy known = d := by
  simp [observeKnownCopy, seen]

def sameDispatch (current earlier : DispatchIdentity) : Prop :=
  current.id = earlier.id ∧ current.slot = earlier.slot ∧ current.time = earlier.time

def lowerBoundTwo (d : Revision) : Prop :=
  ∃ l, d.late = some l ∧ l.prior.cut + 1 = d.cut ∧
    ScopedReplay l.prior.cut l.prior ∧ ScopedReplay l.prior.cut l.discovered ∧
    l.prior.id ≠ l.discovered.id

def carriesDiscovery (d : Revision) (first second : DispatchIdentity) : Prop :=
  ∀ l, d.late = some l →
    l.prior.cut + 1 = d.cut ∧ sameDispatch first l.prior ∧ sameDispatch second l.discovered ∧
      ∀ c, d.correction = some c → ∃ r ∈ d.rows, r.slot = c.target.second.slot ∧ r.event = ""

structure ValidExactTwo (v : View) (d : Revision) (first second : DispatchIdentity) : Prop where
  coverage : CompleteDispatchCoverage (coverageView v d)
  firstQualified : QualifiedIdentity d.cut d.rows first
  secondQualified : QualifiedIdentity d.cut d.rows second
  distinct : first.id ≠ second.id
  discovery : d.correction = none ∨ lowerBoundTwo d
  lineage : carriesDiscovery d first second
  exhaustive : ∀ id, id ∈ replayIds (coverageView v d) ↔ id = first.id ∨ id = second.id

def assessExactTwo (v : View) (d : Revision) (first second : DispatchIdentity)
    (_gate : ValidExactTwo v d first second) : Revision :=
  { d with exactTwoBasis := some ⟨d.cut, d.manifests, d.rows, first, second⟩ }

def currentExactTwo (v : View) (d : Revision) (b : ExactTwoBasis) : Prop :=
  b.cut = d.cut ∧ b.manifests = d.manifests ∧ b.rows = d.rows ∧ ValidExactTwo v d b.first b.second

def countReviewOpen (d : Revision) : Prop :=
  d.exactAssessed = false ∧ d.exactTwoBasis = none

def selectionGate (v : View) (d : Revision) : ReplayClaim → Prop
  | .exactOne => d.exactAssessed = true ∧ exactBasis v d
  | .atLeastOne => replayIds (coverageView v d) ≠ [] ∧ d.exactAssessed = false ∧
      d.exactTwoBasis = none ∧ d.late = none
  | .atLeastTwo => lowerBoundTwo d ∧ countReviewOpen d
  | .exactTwo => ∃ b, d.exactTwoBasis = some b ∧ currentExactTwo v d b

def publicationBasis (d : Revision) (claim : ReplayClaim) : Snapshot :=
  let basis := match claim with
    | .exactTwo => d.exactTwoBasis
    | _ => none
  ⟨d.cut, claim, d.manifests, d.rows, basis, d.correction, d.late⟩

def select (v : View) (d : Revision) (claim : ReplayClaim)
    (_gate : selectionGate v d claim) : Revision :=
  let snapshot := publicationBasis d claim
  { d with
    selected := some snapshot
    history := if snapshot ∈ d.history then d.history else snapshot :: d.history }

theorem same_basis_does_not_append_history (v : View) (d : Revision) (claim : ReplayClaim)
    (gate : selectionGate v d claim) (seen : publicationBasis d claim ∈ d.history) :
    (select v d claim gate).history = d.history := by
  simp [select, seen]

theorem correction_retires_selection_and_preserves_history (d : Revision) :
    (correctSeal d).selected = none ∧ (correctSeal d).history = d.history :=
  ⟨rfl, rfl⟩

theorem old_row_cannot_be_carried_without_current_qualification (d : Revision) (r : DispatchRow)
    (old : r.cut = d.cut) :
    ¬ QualifiedDispatchRow (correctSeal d).cut r := by
  intro fresh
  exact Nat.succ_ne_self d.cut (fresh.current.symm.trans old)

theorem witness_can_support_lower_bound_while_exact_is_blocked (v : View) (d : Revision)
    (seen : replayIds (coverageView v d) ≠ []) (pending : countReviewOpen d) (noLate : d.late = none)
    (gap : ¬ CompleteDispatchCoverage (coverageView v d)) :
    selectionGate v d .atLeastOne ∧ ¬ selectionGate v d .exactOne :=
  ⟨⟨seen, pending.1, pending.2, noLate⟩, fun gate => gap gate.2.1⟩

theorem reseal_with_two_distinct_ids_blocks_exact_one (v : View) (d : Revision)
    (two : (replayIds (coverageView v d)).length = 2) :
    ¬ exactBasis v d := by
  intro exact
  exact (by decide : (2 : Nat) ≠ 1) (two.symm.trans exact.2.1)

theorem fresh_assessment_allows_selection (v : View) (d : Revision) (basis : exactBasis v d) :
    selectionGate v (assessExact v d basis) .exactOne :=
  ⟨rfl, basis⟩

theorem reselection_appends_history (v : View) (d : Revision) (claim : ReplayClaim)
    (gate : selectionGate v d claim) (old : Snapshot) (retained : old ∈ d.history) :
    old ∈ (select v d claim gate).history := by
  change old ∈ (if publicationBasis d claim ∈ d.history then d.history
    else publicationBasis d claim :: d.history)
  split
  · exact retained
  · exact List.mem_cons_of_mem _ retained

theorem same_canonical_id_blocks_exact_two (v : View) (d : Revision)
    (first second : DispatchIdentity) (alias : first.id = second.id) :
    ¬ ValidExactTwo v d first second :=
  fun gate => gate.distinct alias

theorem different_attempt_blocks_exact_two (v : View) (d : Revision)
    (first second : DispatchIdentity) (different : second.attempt ≠ "original-attempt") :
    ¬ ValidExactTwo v d first second :=
  fun gate => different gate.secondQualified.scope.attempt

theorem terminal_window_boundary_blocks_exact_two (v : View) (d : Revision)
    (first second : DispatchIdentity) (terminal : second.time = 20) :
    ¬ ValidExactTwo v d first second := by
  intro gate
  have outside := gate.secondQualified.scope.closes
  rw [terminal] at outside
  exact Nat.lt_irrefl _ outside

theorem exact_two_assessment_closes_count_and_enables_selection (v : View) (d : Revision)
    (first second : DispatchIdentity) (gate : ValidExactTwo v d first second) :
    let assessed := assessExactTwo v d first second gate
    ¬ countReviewOpen assessed ∧ selectionGate v assessed .exactTwo := by
  refine ⟨?_, ⟨⟨d.cut, d.manifests, d.rows, first, second⟩, rfl, rfl, rfl, rfl, ?_⟩⟩
  · simp [countReviewOpen, assessExactTwo]
  · exact ⟨gate.coverage, gate.firstQualified, gate.secondQualified, gate.distinct, gate.discovery, gate.lineage, gate.exhaustive⟩

theorem stale_exact_two_basis_cannot_select (v : View) (d : Revision)
    (b : ExactTwoBasis) (stored : d.exactTwoBasis = some b) (stale : b.cut ≠ d.cut) :
    ¬ selectionGate v d .exactTwo := by
  intro gate
  obtain ⟨candidate, eq, valid⟩ := gate
  have same : b = candidate := Option.some.inj (stored.symm.trans eq)
  exact stale (same ▸ valid.1)

theorem published_exact_two_retains_identity_basis (v : View) (d : Revision)
    (gate : selectionGate v d .exactTwo) :
    (select v d .exactTwo gate).selected =
      some ⟨d.cut, .exactTwo, d.manifests, d.rows, d.exactTwoBasis, d.correction, d.late⟩ := rfl

-- The correction is a scoped authority attestation that the second binding
-- observes the first dispatch. It can displace only the selected basis it names.
structure AdmissibleAlias (v : View) (d : Revision) (c : AliasCorrection) : Prop where
  authorized : c.authorized = true
  scope : c.scope = dispatchScope
  current : currentExactTwo v d c.target
  assessed : d.exactTwoBasis = some c.target
  selected : ∃ old, d.selected = some old ∧ old.cut = d.cut ∧ old.claim = .exactTwo ∧
    old.identityBasis = some c.target ∧ old ∈ d.history

def admitAliasCorrection (v : View) (d : Revision) (c : AliasCorrection)
    (_admitted : AdmissibleAlias v d c) : Revision :=
  { correctSeal d with correction := some c }

theorem alias_withdraws_selection_and_reopens_count (v : View) (d : Revision)
    (c : AliasCorrection) (h : AdmissibleAlias v d c) :
    let next := admitAliasCorrection v d c h
    next.selected = none ∧ countReviewOpen next ∧ next.history = d.history := by
  exact ⟨rfl, ⟨rfl, rfl⟩, rfl⟩

theorem incomplete_corrected_cut_blocks_exact_one (v : View) (d : Revision)
    (gap : ¬ CompleteDispatchCoverage (coverageView v d)) :
    ¬ selectionGate v d .exactOne :=
  fun h => gap h.2.1

theorem correction_alone_cannot_publish_exact_one (v : View) (d : Revision)
    (c : AliasCorrection) (h : AdmissibleAlias v d c) :
    ¬ selectionGate v (admitAliasCorrection v d c h) .exactOne := by
  intro gate
  exact Bool.noConfusion gate.1

theorem corrected_selection_requires_singleton_basis (v : View) (d : Revision)
    (c : AliasCorrection) (stored : d.correction = some c)
    (gate : selectionGate v d .exactOne) : correctedExactOne v d c :=
  by simpa only [stored] using gate.2.2.2.1

theorem corrected_reselection_retains_both (v : View) (d : Revision)
    (v3 v4 : Snapshot) (v3Saved : v3 ∈ d.history) (v4Saved : v4 ∈ d.history)
    (gate : selectionGate v d .exactOne) :
    let next := select v d .exactOne gate
    v3 ∈ next.history ∧ v4 ∈ next.history ∧
      next.selected = some ⟨d.cut, .exactOne, d.manifests, d.rows, none, d.correction, d.late⟩ :=
  ⟨reselection_appends_history v d .exactOne gate v3 v3Saved,
    reselection_appends_history v d .exactOne gate v4 v4Saved, rfl⟩

-- A late, authenticated occurrence challenges the old seal. It need not
-- already be a member of a replacement sealed range.
structure AdmissibleDiscovery (v : View) (d : Revision) (l : LateDiscovery) : Prop where
  selected : ∃ old, d.selected = some old ∧ old.cut = d.cut ∧ old.claim = .exactOne ∧
    old.manifests = d.manifests ∧ old.rows = d.rows ∧ old ∈ d.history
  exactOne : selectionGate v d .exactOne
  aliasRetained : d.correction ≠ none
  prior : QualifiedIdentity d.cut d.rows l.prior
  discovered : ScopedReplay d.cut l.discovered
  independent : l.prior.id ≠ l.discovered.id
  contradictedRange : ∃ r ∈ d.rows, r.slot = l.discovered.slot ∧ r.event = ""

def admitLateDiscovery (v : View) (d : Revision) (l : LateDiscovery)
    (_gate : AdmissibleDiscovery v d l) : Revision :=
  { correctSeal d with late := some l }

theorem independent_witness_refutes_a_singleton (l : LateDiscovery)
    (independent : l.prior.id ≠ l.discovered.id) :
    l.discovered.id ∉ [l.prior.id] := by
  simpa [eq_comm] using independent

theorem discovery_retracts_and_reopens_with_lower_bound (v : View) (d : Revision)
    (l : LateDiscovery) (gate : AdmissibleDiscovery v d l) :
    let next := admitLateDiscovery v d l gate
    next.selected = none ∧ next.history = d.history ∧ countReviewOpen next ∧
      selectionGate v next .atLeastTwo ∧ ¬ selectionGate v next .exactOne := by
  refine ⟨rfl, rfl, ⟨rfl, rfl⟩, ⟨?_, ⟨rfl, rfl⟩⟩, ?_⟩
  · refine ⟨l, rfl, ?_, ?_, ?_, gate.independent⟩
    · exact congrArg (· + 1) gate.prior.scope.current
    · simpa only [gate.prior.scope.current] using gate.prior.scope
    · simpa only [gate.prior.scope.current] using gate.discovered
  · intro h
    exact Bool.noConfusion h.1

theorem open_coverage_blocks_exact_two (v : View) (d : Revision)
    (missing : ¬ CompleteDispatchCoverage (coverageView v d)) :
    ¬ selectionGate v d .exactTwo := by
  rintro ⟨_, _, _, _, _, gate⟩
  exact missing gate.coverage

theorem discovery_selection_keeps_all_prior_versions (v : View) (d : Revision)
    (gate : selectionGate v d .exactTwo) (l : LateDiscovery) (stored : d.late = some l) :
    let next := select v d .exactTwo gate
    (∀ old ∈ d.history, old ∈ next.history) ∧
      next.selected = some ⟨d.cut, .exactTwo, d.manifests, d.rows, d.exactTwoBasis,
        d.correction, some l⟩ := by
  refine ⟨fun old h => reselection_appends_history v d .exactTwo gate old h, ?_⟩
  simp [select, publicationBasis, stored]

end DispatchSealRevision
