// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
//
// Slice 60: Unified GraphEngine — Tarjan SCC Cyclic Feedback Subgraphs &
// Durable SQLite WAL Crash/Restart Recovery Fencing.
module UnifiedCyclicSccAndDurableRecovery {
  type State = {
    liveJournalEpoch: int,
    staleHandleEpoch: int,
    chainHealthy: bool,
    openRequiredBranches: int,
    cyclicSccHasContract: bool,
    sccIterations: int,
    sccConverged: bool,
    downstreamReleased: bool,
    apexConverged: bool,
    ungovernedCycleExecuted: bool,
    oscillationContinued: bool,
    staleEpochWriteAdmitted: bool,
    recoveredApexWithOpenBranch: bool,
  }

  var s60: State

  action init = all {
    s60' = {
      liveJournalEpoch: 1,
      staleHandleEpoch: 1,
      chainHealthy: true,
      openRequiredBranches: 1,
      cyclicSccHasContract: true,
      sccIterations: 0,
      sccConverged: false,
      downstreamReleased: false,
      apexConverged: false,
      ungovernedCycleExecuted: false,
      oscillationContinued: false,
      staleEpochWriteAdmitted: false,
      recoveredApexWithOpenBranch: false,
    }
  }

  // 1. Governed cyclic SCC advances one bounded iteration
  action stepGovernedCyclicScc = all {
    s60.cyclicSccHasContract,
    not(s60.sccConverged),
    s60.sccIterations < 2,
    s60' = { ...s60, sccIterations: s60.sccIterations + 1 }
  }

  // 2. Governed cyclic SCC converges & collapses into Condensation DAG receipt
  action convergeGovernedCyclicScc = all {
    s60.cyclicSccHasContract,
    not(s60.sccConverged),
    s60.sccIterations >= 1,
    s60' = { ...s60, sccConverged: true }
  }

  // 3. Downstream acyclic DAG node releases ONLY after upstream SCC converges
  action releaseDownstreamAcyclicNode = all {
    s60.sccConverged,
    not(s60.downstreamReleased),
    s60' = { ...s60, downstreamReleased: true }
  }

  // 4. Crash & restart: SQLite WAL reopen increments liveJournalEpoch (fencing old handle)
  action crashAndRestartJournalTakeover = all {
    s60.liveJournalEpoch < 2,
    s60' = { ...s60, liveJournalEpoch: s60.liveJournalEpoch + 1 }
  }

  // 5. Post-crash branch reconciliation absorbs open required branch
  action reconcileRecoveredBranch = all {
    s60.chainHealthy,
    s60.openRequiredBranches > 0,
    s60' = { ...s60, openRequiredBranches: s60.openRequiredBranches - 1 }
  }

  // 6. Converge post-crash Apex ONLY when chainHealthy & openRequiredBranches == 0
  action convergeRecoveredApex = all {
    s60.chainHealthy,
    s60.openRequiredBranches == 0,
    s60.downstreamReleased,
    not(s60.apexConverged),
    s60' = { ...s60, apexConverged: true }
  }

  action step = any {
    stepGovernedCyclicScc,
    convergeGovernedCyclicScc,
    releaseDownstreamAcyclicNode,
    crashAndRestartJournalTakeover,
    reconcileRecoveredBranch,
    convergeRecoveredApex,
  }

  // Negative-control fault injections
  action buggyExecuteUngovernedCycle = all {
    s60' = { ...s60, ungovernedCycleExecuted: true }
  }

  action buggyContinuePastOscillation = all {
    s60' = { ...s60, oscillationContinued: true }
  }

  action buggyStaleEpochZombieWrite = all {
    s60.staleHandleEpoch < s60.liveJournalEpoch,
    s60' = { ...s60, staleEpochWriteAdmitted: true }
  }

  action buggyPostCrashPrematureApex = all {
    s60.openRequiredBranches > 0,
    s60' = { ...s60, recoveredApexWithOpenBranch: true, apexConverged: true }
  }

  // Four bidirectional safety invariants mapped in SysML
  val ungovernedCycleNeverExecutes =
    not(s60.ungovernedCycleExecuted)

  val oscillatingCycleNeverContinues =
    not(s60.oscillationContinued)

  val supersededEpochNeverWritesJournal =
    not(s60.staleEpochWriteAdmitted)

  val postCrashApexRequiresZeroOpenBranchesAndConvergedScc =
    not(s60.recoveredApexWithOpenBranch) and
    (not(s60.apexConverged) or (s60.openRequiredBranches == 0 and s60.sccConverged))

  val safety = and {
    ungovernedCycleNeverExecutes,
    oscillatingCycleNeverContinues,
    supersededEpochNeverWritesJournal,
    postCrashApexRequiresZeroOpenBranchesAndConvergedScc,
  }

  // Positive witnesses
  run safeGovernedCycleAndCrashRecoveryApexTest =
    init
      .then(stepGovernedCyclicScc)
      .then(convergeGovernedCyclicScc)
      .then(releaseDownstreamAcyclicNode)
      .then(crashAndRestartJournalTakeover)
      .then(reconcileRecoveredBranch)
      .then(convergeRecoveredApex)
      .expect(safety and s60.apexConverged and s60.liveJournalEpoch == 2)

  // Negative-control counterexamples
  run ungovernedCycleCounterexampleTest =
    init
      .then(buggyExecuteUngovernedCycle)
      .expect(not(ungovernedCycleNeverExecutes))

  run oscillationCycleCounterexampleTest =
    init
      .then(buggyContinuePastOscillation)
      .expect(not(oscillatingCycleNeverContinues))

  run staleEpochZombieWriteCounterexampleTest =
    init
      .then(crashAndRestartJournalTakeover)
      .then(buggyStaleEpochZombieWrite)
      .expect(not(supersededEpochNeverWritesJournal))

  run prematurePostCrashApexCounterexampleTest =
    init
      .then(crashAndRestartJournalTakeover)
      .then(buggyPostCrashPrematureApex)
      .expect(not(postCrashApexRequiresZeroOpenBranchesAndConvergedScc))
}
