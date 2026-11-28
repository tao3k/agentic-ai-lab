/-
SPDX-FileCopyrightText: 2026 tao3k team and Contributors
SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

Slice 60: Unified GraphEngine — Tarjan SCC Cyclic Feedback Subgraphs &
Durable SQLite WAL Crash/Restart Recovery Fencing.

Proves seven structural guarantees with zero `sorry` and zero custom axioms:
  1. Ungoverned cyclic SCCs (missing `CycleTerminationContract`) are always refused.
  2. Repeated state digests (`A -> B -> A` oscillation) immediately halt fail-closed.
  3. Exhausted cycle iteration budgets halt fail-closed.
  4. Revoked Cedar grants block both acyclic DAG nodes and cyclic SCCs.
  5. Superseded SQLite journal owner epochs are rejected fail-closed (no zombie writes).
  6. Tampered journal hash chains unconditionally refuse crash recovery.
  7. Recovered unclosed required serving branches block premature post-crash Apex.
-/

namespace UnifiedCyclicSccAndDurableRecovery

inductive CycleStepVerdict where
  | converged
  | continueStep
  | haltedOscillation
  | haltedBudget
  deriving DecidableEq, Repr

structure SccAdmissionInput where
  isCyclic : Bool
  hasContract : Bool
  cedarGrantLive : Bool
  deriving DecidableEq, Repr

def admitSccExecution (inp : SccAdmissionInput) : Bool :=
  inp.cedarGrantLive && (!inp.isCyclic || inp.hasContract)

def evaluateCycleStep
    (stateDigest : Nat)
    (visitedDigests : List Nat)
    (exitDischarged : Bool)
    (iteration : Nat)
    (maxIterations : Nat) : CycleStepVerdict :=
  if decide (stateDigest ∈ visitedDigests) then
    CycleStepVerdict.haltedOscillation
  else if exitDischarged then
    CycleStepVerdict.converged
  else if iteration >= maxIterations then
    CycleStepVerdict.haltedBudget
  else
    CycleStepVerdict.continueStep

def admitDurableCommit (handleEpoch liveOwnerEpoch : Nat) : Bool :=
  decide (handleEpoch = liveOwnerEpoch)

def admitCrashRecovery (hashChainVerified snapshotPresent : Bool) : Bool :=
  hashChainVerified && snapshotPresent

def admitPostCrashApex
    (hashChainVerified : Bool)
    (recoveredOpenRequiredBranches : Nat)
    (apexDischarged : Bool) : Bool :=
  hashChainVerified && decide (recoveredOpenRequiredBranches = 0) && apexDischarged

/-- Theorem 1: Ungoverned cyclic SCCs without a CycleTerminationContract are always refused. -/
theorem ungovernedCyclicScc_always_refused
    (inp : SccAdmissionInput)
    (hCyc : inp.isCyclic = true)
    (hNoContract : inp.hasContract = false) :
    admitSccExecution inp = false := by
  simp [admitSccExecution, hCyc, hNoContract]

/-- Theorem 2: Repeated state digests (exact repeat or oscillation) immediately halt fail-closed. -/
theorem repeatedStateDigest_immediately_halts_oscillation
    (sd : Nat)
    (visited : List Nat)
    (exitDischarged : Bool)
    (iter maxIter : Nat)
    (hSeen : sd ∈ visited) :
    evaluateCycleStep sd visited exitDischarged iter maxIter = CycleStepVerdict.haltedOscillation := by
  simp [evaluateCycleStep, hSeen]

/-- Theorem 3: Non-convergent cycles halt fail-closed when iteration reaches maxIterations. -/
theorem budgetExhaustedCycle_halts_fail_closed
    (sd : Nat)
    (visited : List Nat)
    (iter maxIter : Nat)
    (hFresh : sd ∉ visited)
    (hExhausted : iter >= maxIter) :
    evaluateCycleStep sd visited false iter maxIter = CycleStepVerdict.haltedBudget := by
  simp [evaluateCycleStep, hFresh, hExhausted]

/-- Theorem 4: Revoked Cedar grants unconditionally block unified graph execution. -/
theorem revokedCedarGrant_blocks_unified_graph
    (inp : SccAdmissionInput)
    (hRevoked : inp.cedarGrantLive = false) :
    admitSccExecution inp = false := by
  simp [admitSccExecution, hRevoked]

/-- Theorem 5: Superseded SQLite journal owner epochs are rejected fail-closed (no zombie writes). -/
theorem supersededJournalEpoch_rejected_fail_closed
    (handleEpoch liveOwnerEpoch : Nat)
    (hStale : handleEpoch ≠ liveOwnerEpoch) :
    admitDurableCommit handleEpoch liveOwnerEpoch = false := by
  simp [admitDurableCommit, hStale]

/-- Theorem 6: Tampered journal hash chains unconditionally refuse crash recovery. -/
theorem tamperedJournalHashChain_refuses_recovery
    (snapshotPresent : Bool) :
    admitCrashRecovery false snapshotPresent = false := by
  simp [admitCrashRecovery]

/-- Theorem 7: Recovered open required serving branches block premature post-crash Apex. -/
theorem recoveredOpenRequiredBranches_block_premature_apex
    (hashChainVerified : Bool)
    (openRequired : Nat)
    (apexDischarged : Bool)
    (hOpen : openRequired > 0) :
    admitPostCrashApex hashChainVerified openRequired apexDischarged = false := by
  have hNe : openRequired ≠ 0 := Nat.ne_of_gt hOpen
  simp [admitPostCrashApex, hNe]

end UnifiedCyclicSccAndDurableRecovery
