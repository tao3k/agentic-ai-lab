-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
  Slice 57: Post-ReAct Declarative Obligation-Fixpoint Reconciler
  (ASCENT × FunFlow × POO × Temporal Causality × Stateless Typed SynthesisOracle).

  Replaces the ReAct paradigm (`LLM drives linear turn loop`) with a declarative
  Datalog/fixed-point obligation reconciler:
  1. Control flow lives in `gerbil-ascent`, NOT in LLM token streams.
  2. Deterministic FunFlow frontier strictly dominates LLM oracle invocation
     (`0 LLM calls` while any deterministic task is ready).
  3. `(holeId, premiseDigest)` relational idempotence makes re-firing on
     unchanged premises a mathematical no-op in Datalog.
  4. LLM `SynthesisOracle` is a stateless typed leaf strictly forbidden from
     emitting raw single-step tool calls; only typed FunFlow DAG patches or
     bounded competing hypothesis branches are admitted.
  5. Competing unrefuted hypotheses are preserved (never collapsed to one greedy path).
  6. Bitemporal premise retraction invalidates ONLY causally dependent obligations.
  7. Finite monotonic hole-premise consumption guarantees quiescent fixed-point
     termination by structural induction.
-/

namespace AscentObligationFixpointReconciler

-- ===========================================================================
-- 1. Relational `(holeId, premiseDigest)` Idempotence & Deterministic-First Frontier
-- ===========================================================================

structure HoleKey where
  holeId : Nat
  premiseDigest : Nat
  deriving DecidableEq, Repr

/-- A synthesis hole is ready ONLY if its `(holeId, premiseDigest)` tuple has
    not already been recorded in the persistent `attemptedHoles` relation AND
    no deterministic FunFlow tasks are pending AND governance is healthy. -/
def isReadySynthesisHole
    (attemptedHoles : List HoleKey)
    (readyDetTaskCount : Nat)
    (governanceHealthy : Bool)
    (hk : HoleKey) : Bool :=
  governanceHealthy && (readyDetTaskCount == 0) && !(decide (hk ∈ attemptedHoles))

theorem attemptedHole_idempotent_on_unchanged_premises
    (attemptedHoles : List HoleKey)
    (readyDetTaskCount : Nat)
    (governanceHealthy : Bool)
    (hk : HoleKey) :
    isReadySynthesisHole (hk :: attemptedHoles) readyDetTaskCount governanceHealthy hk = false := by
  simp [isReadySynthesisHole]

inductive FrontierAction where
  | dispatchDeterministicFunflow (taskCount : Nat) (llmCallsUsed : Nat)
  | invokeTypedSynthesisOracle (hole : HoleKey)
  | quiescentFixedPoint
  | blockedOnGovernanceOrHuman
  deriving DecidableEq, Repr

def selectNextFrontier
    (governanceHealthy : Bool)
    (readyDetTaskCount : Nat)
    (readyHoles : List HoleKey) : FrontierAction :=
  if !governanceHealthy then
    .blockedOnGovernanceOrHuman
  else if readyDetTaskCount > 0 then
    .dispatchDeterministicFunflow readyDetTaskCount 0
  else
    match readyHoles with
    | hk :: _ => .invokeTypedSynthesisOracle hk
    | [] => .quiescentFixedPoint

theorem deterministicFrontier_takes_strict_precedence_over_llm
    (readyDetTaskCount : Nat)
    (readyHoles : List HoleKey)
    (hPos : readyDetTaskCount > 0) :
    selectNextFrontier true readyDetTaskCount readyHoles =
      .dispatchDeterministicFunflow readyDetTaskCount 0 := by
  simp [selectNextFrontier, hPos]

-- ===========================================================================
-- 2. Epistemic Soundness: Defeated Hypotheses & Preserving Competing Hypotheses
-- ===========================================================================

structure HypothesisRecord where
  hypothesisId : Nat
  hasCounterEvidence : Bool
  hasActiveDefeater : Bool
  deriving DecidableEq, Repr

def hypothesisUnrefuted (h : HypothesisRecord) : Bool :=
  !h.hasCounterEvidence && !h.hasActiveDefeater

def obligationDischargedByHypothesis (h : HypothesisRecord) (evidenceMet : Bool) : Bool :=
  evidenceMet && hypothesisUnrefuted h

theorem refutedHypothesis_never_discharges_obligation
    (h : HypothesisRecord)
    (evidenceMet : Bool)
    (hRefuted : h.hasCounterEvidence = true ∨ h.hasActiveDefeater = true) :
    obligationDischargedByHypothesis h evidenceMet = false := by
  unfold obligationDischargedByHypothesis hypothesisUnrefuted
  rcases hRefuted with hc | hd
  · simp [hc]
  · simp [hd]

inductive EpistemicCompetitionStatus where
  | noneActive
  | singleUnrefuted (hid : Nat)
  | openCompetition (activeIds : List Nat)
  deriving DecidableEq, Repr

def deriveEpistemicStatus (hs : List HypothesisRecord) : EpistemicCompetitionStatus :=
  let live := (hs.filter hypothesisUnrefuted).map (fun h => h.hypothesisId)
  match live with
  | [] => .noneActive
  | [x] => .singleUnrefuted x
  | x :: y :: rest => .openCompetition (x :: y :: rest)

theorem competingHypotheses_preserved_without_greedy_collapse
    (h1 h2 : HypothesisRecord)
    (h1Ok : hypothesisUnrefuted h1 = true)
    (h2Ok : hypothesisUnrefuted h2 = true) :
    deriveEpistemicStatus [h1, h2] = .openCompetition [h1.hypothesisId, h2.hypothesisId] := by
  simp [deriveEpistemicStatus, h1Ok, h2Ok]

-- ===========================================================================
-- 3. Stateless Typed SynthesisOracle Boundary (Zero Raw Single-Step Tool Calls)
-- ===========================================================================

inductive OracleProposalKind where
  | rawSingleStepToolCall
  | typedFunflowDagPatch
  | boundedCompetingBranches
  deriving DecidableEq, Repr

structure OracleProposal where
  kind : OracleProposalKind
  contractValid : Bool
  camelAndMcpSafe : Bool
  branchCount : Nat
  maxBranches : Nat
  deriving DecidableEq, Repr

def admitOracleProposal (p : OracleProposal) : Bool :=
  match p.kind with
  | .rawSingleStepToolCall => false
  | .typedFunflowDagPatch => p.contractValid && p.camelAndMcpSafe
  | .boundedCompetingBranches =>
      p.contractValid && p.camelAndMcpSafe && decide (p.branchCount > 0 ∧ p.branchCount ≤ p.maxBranches)

theorem rawToolCallOracleOutput_rejected_fail_closed (p : OracleProposal)
    (hRaw : p.kind = .rawSingleStepToolCall) :
    admitOracleProposal p = false := by
  simp [admitOracleProposal, hRaw]

-- ===========================================================================
-- 4. Bitemporal Premise Retraction & Incremental Re-Convergence
-- ===========================================================================

structure DischargedNode where
  nodeId : Nat
  premiseDigests : List Nat
  deriving DecidableEq, Repr

def survivesRetraction (retractedPremise : Nat) (n : DischargedNode) : Bool :=
  !(decide (retractedPremise ∈ n.premiseDigests))

theorem premiseRetraction_preserves_independent_nodes
    (retractedPremise : Nat)
    (n : DischargedNode)
    (hIndep : retractedPremise ∉ n.premiseDigests) :
    survivesRetraction retractedPremise n = true := by
  simp [survivesRetraction, hIndep]

-- ===========================================================================
-- 5. Universal Fixed-Point Quiescence Termination by Structural Induction
-- ===========================================================================

/-- Reconciling a finite list of candidate synthesis holes strictly consumes
    at least one unattempted hole per step and reaches quiescence unconditionally
    (zero infinite loops by construction). -/
def reconcileHoleQueue (attempted : List HoleKey) : List HoleKey → List HoleKey
  | [] => attempted
  | hk :: rest =>
      if hk ∈ attempted then
        reconcileHoleQueue attempted rest
      else
        reconcileHoleQueue (hk :: attempted) rest

theorem reconcileHoleQueue_contains_prior
    (attempted queue : List HoleKey)
    (x : HoleKey)
    (hx : x ∈ attempted) :
    x ∈ reconcileHoleQueue attempted queue := by
  induction queue generalizing attempted with
  | nil => exact hx
  | cons hk rest ih =>
    unfold reconcileHoleQueue
    by_cases hIn : hk ∈ attempted
    · simp only [hIn, ite_true]
      exact ih attempted hx
    · simp only [hIn, ite_false]
      exact ih (hk :: attempted) (List.mem_cons_of_mem hk hx)

theorem reconciler_reaches_quiescent_fixed_point_on_all_holes
    (attempted queue : List HoleKey) :
    ∀ hk ∈ queue,
      isReadySynthesisHole (reconcileHoleQueue attempted queue) 0 true hk = false := by
  induction queue generalizing attempted with
  | nil =>
    intro hk hMem
    cases hMem
  | cons hd tl ih =>
    intro hk hMem
    cases hMem with
    | head =>
      unfold reconcileHoleQueue
      by_cases hIn : hd ∈ attempted
      · simp only [hIn, ite_true]
        have hFinal : hd ∈ reconcileHoleQueue attempted tl :=
          reconcileHoleQueue_contains_prior attempted tl hd hIn
        simp [isReadySynthesisHole, hFinal]
      · simp only [hIn, ite_false]
        have hFinal : hd ∈ reconcileHoleQueue (hd :: attempted) tl :=
          reconcileHoleQueue_contains_prior (hd :: attempted) tl hd List.mem_cons_self
        simp [isReadySynthesisHole, hFinal]
    | tail _ hInTl =>
      unfold reconcileHoleQueue
      by_cases hIn : hd ∈ attempted
      · simp only [hIn, ite_true]
        exact ih attempted hk hInTl
      · simp only [hIn, ite_false]
        exact ih (hd :: attempted) hk hInTl

end AscentObligationFixpointReconciler
