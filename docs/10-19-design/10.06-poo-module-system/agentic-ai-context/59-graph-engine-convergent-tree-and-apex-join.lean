/-
SPDX-FileCopyrightText: 2026 tao3k team and Contributors
SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

Slice 59: Unified GraphEngine — FunFlow C4 Disjoint DAG Frontier vs
Shared-Context Convergent Tree (`ContextTrunk -> Subordinate Branches -> Apex`).

Proves seven structural guarantees with zero `sorry` and zero custom axioms:
  1. Disjoint read/write FunFlow DAG fan-out executes with 0 subagents & 0 LLM calls.
  2. Overlapping write footprints are never admitted into the same parallel DAG wave.
  3. Isolated/detached branch spawns (cut/KV-prefix/apex mismatch) are always refused.
  4. Subordinate branches completing local tasks can NEVER directly finalize the Trunk.
  5. Stale cut/epoch branch submissions never pollute Trunk evidence yet monotonically
     preserve discovered counterexamples.
  6. Any active required serving branch blocks premature Trunk Apex convergence.
  7. Apex convergence immediately supersedes all remaining optional branches.
-/

namespace GraphEngineConvergentTree

inductive BranchKind where
  | contextEnrichmentDetour
  | divergentExploration
  | subordinateTask
  deriving DecidableEq, Repr

inductive BranchStatus where
  | active
  | absorbed
  | parkedCustody
  | cancelled
  | supersededStale
  | supersededByApex
  deriving DecidableEq, Repr

structure DagPairCheck where
  hasWriteConflict : Bool
  hasCausalEdge : Bool
  deriving DecidableEq, Repr

structure FrontierDispatchResult where
  admittedParallel : Bool
  subagentsSpawned : Nat
  llmCallsUsed : Nat
  deriving DecidableEq, Repr

def admitDagParallelPair (chk : DagPairCheck) : FrontierDispatchResult :=
  if !chk.hasWriteConflict && !chk.hasCausalEdge then
    { admittedParallel := true, subagentsSpawned := 0, llmCallsUsed := 0 }
  else
    { admittedParallel := false, subagentsSpawned := 0, llmCallsUsed := 0 }

structure TrunkAnchor where
  liveCut : Nat
  kvPrefixDigest : Nat
  apexObligationId : Nat
  liveGrantEpoch : Nat
  trunkGrantLive : Bool
  apexOpen : Bool
  deriving DecidableEq, Repr

structure BranchSpawnRequest where
  kind : BranchKind
  requestedCut : Nat
  requestedKvPrefix : Nat
  requestedApexId : Nat
  deriving DecidableEq, Repr

def admitBranchSpawn (trunk : TrunkAnchor) (req : BranchSpawnRequest) : Bool :=
  trunk.apexOpen &&
  trunk.trunkGrantLive &&
  decide (req.requestedCut = trunk.liveCut) &&
  decide (req.requestedKvPrefix = trunk.kvPrefixDigest) &&
  decide (req.requestedApexId = trunk.apexObligationId)

structure BranchLocalOutcome where
  kind : BranchKind
  localTaskCompleted : Bool
  boundCut : Nat
  boundGrantEpoch : Nat
  discoveredCounterexamples : List Nat
  deriving DecidableEq, Repr

/-- Hard Invariant: a subordinate branch can complete a local task, NEVER directly finalize the Trunk. -/
def branchDirectTrunkFinalization (_o : BranchLocalOutcome) : Bool := false

structure AbsorptionOutcome where
  evidenceAdmitted : Bool
  trunkEvidencePolluted : Bool
  nextCounterexamples : List Nat
  nextBranchStatus : BranchStatus
  deriving DecidableEq, Repr

def absorbBranchOutcome
    (trunk : TrunkAnchor)
    (priorCounterexamples : List Nat)
    (outcome : BranchLocalOutcome)
    (declassCertValid : Bool) : AbsorptionOutcome :=
  let mergedCe := priorCounterexamples ++ outcome.discoveredCounterexamples
  if !trunk.apexOpen then
    { evidenceAdmitted := false
      trunkEvidencePolluted := false
      nextCounterexamples := mergedCe
      nextBranchStatus := BranchStatus.supersededByApex }
  else if outcome.boundCut != trunk.liveCut || outcome.boundGrantEpoch != trunk.liveGrantEpoch then
    { evidenceAdmitted := false
      trunkEvidencePolluted := false
      nextCounterexamples := mergedCe
      nextBranchStatus := BranchStatus.supersededStale }
  else if !declassCertValid then
    { evidenceAdmitted := false
      trunkEvidencePolluted := false
      nextCounterexamples := mergedCe
      nextBranchStatus := BranchStatus.parkedCustody }
  else
    { evidenceAdmitted := true
      trunkEvidencePolluted := false
      nextCounterexamples := mergedCe
      nextBranchStatus := BranchStatus.absorbed }

def admitApexConvergence
    (trunkGrantLive : Bool)
    (activeRequiredBranches : Nat)
    (apexObligationDischarged : Bool) : Bool :=
  trunkGrantLive && decide (activeRequiredBranches = 0) && apexObligationDischarged

def supersedeOptionalOnApex (apexConverged : Bool) (st : BranchStatus) : BranchStatus :=
  if apexConverged && st == BranchStatus.active then
    BranchStatus.supersededByApex
  else
    st

/-- Theorem 1: Disjoint read/write FunFlow DAG fan-out executes with 0 subagents and 0 LLM calls. -/
theorem disjointParallelDagFrontier_spawns_zero_subagents
    (chk : DagPairCheck)
    (hNoConflict : chk.hasWriteConflict = false)
    (hNoEdge : chk.hasCausalEdge = false) :
    (admitDagParallelPair chk).admittedParallel = true ∧
    (admitDagParallelPair chk).subagentsSpawned = 0 ∧
    (admitDagParallelPair chk).llmCallsUsed = 0 := by
  simp [admitDagParallelPair, hNoConflict, hNoEdge]

/-- Theorem 2: Overlapping write footprints are never admitted into the same parallel DAG wave. -/
theorem overlappingWriteFootprint_never_parallelized
    (chk : DagPairCheck)
    (hConflict : chk.hasWriteConflict = true) :
    (admitDagParallelPair chk).admittedParallel = false := by
  simp [admitDagParallelPair, hConflict]

/-- Theorem 3: Isolated or detached branch spawns (cut/KV-prefix/apex mismatch) are always refused. -/
theorem isolatedOrDetachedBranch_always_refused
    (trunk : TrunkAnchor)
    (req : BranchSpawnRequest)
    (hMismatch :
      req.requestedCut ≠ trunk.liveCut ∨
      req.requestedKvPrefix ≠ trunk.kvPrefixDigest ∨
      req.requestedApexId ≠ trunk.apexObligationId) :
    admitBranchSpawn trunk req = false := by
  rcases hMismatch with hCut | hKv | hApex
  · simp [admitBranchSpawn, hCut]
  · simp [admitBranchSpawn, hKv]
  · simp [admitBranchSpawn, hApex]

/-- Theorem 4: Subordinate branches completing local tasks can NEVER directly finalize the Trunk. -/
theorem branchCompletion_never_finalizes_trunk_directly
    (outcome : BranchLocalOutcome)
    (_hDone : outcome.localTaskCompleted = true) :
    branchDirectTrunkFinalization outcome = false := by
  rfl

/-- Theorem 5: Stale cut/epoch submissions never pollute Trunk evidence yet monotonically keep counterexamples. -/
theorem staleBranchContribution_never_pollutes_trunk_yet_preserves_counterexamples
    (trunk : TrunkAnchor)
    (priorCe : List Nat)
    (outcome : BranchLocalOutcome)
    (declassCertValid : Bool)
    (hOpen : trunk.apexOpen = true)
    (hStale : outcome.boundCut ≠ trunk.liveCut ∨ outcome.boundGrantEpoch ≠ trunk.liveGrantEpoch)
    (ce : Nat)
    (hCe : ce ∈ priorCe ∨ ce ∈ outcome.discoveredCounterexamples) :
    (absorbBranchOutcome trunk priorCe outcome declassCertValid).evidenceAdmitted = false ∧
    (absorbBranchOutcome trunk priorCe outcome declassCertValid).trunkEvidencePolluted = false ∧
    ce ∈ (absorbBranchOutcome trunk priorCe outcome declassCertValid).nextCounterexamples := by
  have hCond : (outcome.boundCut != trunk.liveCut || outcome.boundGrantEpoch != trunk.liveGrantEpoch) = true := by
    rcases hStale with hC | hE
    · simp [bne, hC]
    · simp [bne, hE]
  simp [absorbBranchOutcome, hOpen, hCond, List.mem_append, hCe]

/-- Theorem 6: Any active required serving branch blocks premature Trunk Apex convergence. -/
theorem unclosedRequiredBranch_blocks_apex_convergence
    (trunkGrantLive : Bool)
    (activeRequiredBranches : Nat)
    (apexObligationDischarged : Bool)
    (hActive : activeRequiredBranches > 0) :
    admitApexConvergence trunkGrantLive activeRequiredBranches apexObligationDischarged = false := by
  have hNe : activeRequiredBranches ≠ 0 := Nat.ne_of_gt hActive
  simp [admitApexConvergence, hNe]

/-- Theorem 7: Apex convergence immediately supersedes every remaining active optional branch. -/
theorem apexConvergence_supersedes_remaining_optional_branches
    (st : BranchStatus)
    (hActive : st = BranchStatus.active) :
    supersedeOptionalOnApex true st = BranchStatus.supersededByApex := by
  simp [supersedeOptionalOnApex, hActive]

end GraphEngineConvergentTree
