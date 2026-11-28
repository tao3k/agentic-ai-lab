// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
//
// Slice 59: Unified GraphEngine — FunFlow C4 Disjoint DAG Frontier vs
// Shared-Context Convergent Tree (`ContextTrunk -> Subordinate Branches -> Apex`).
module GraphEngineConvergentTree {
  type State = {
    trunkCut: int,
    dagDisjointExecs: int,
    subagentsFromDag: int,
    requiredBranchActive: bool,
    requiredBranchCut: int,
    optionalBranchActive: bool,
    branchLocalTaskDone: bool,
    absorbedContributions: int,
    counterexampleCount: int,
    apexConverged: bool,
    isolatedBranchSpawned: bool,
    branchDirectlyFinalizedTrunk: bool,
    convergedWithActiveRequiredBranch: bool,
  }

  var s59: State

  action init = all {
    s59' = {
      trunkCut: 1,
      dagDisjointExecs: 0,
      subagentsFromDag: 0,
      requiredBranchActive: false,
      requiredBranchCut: 0,
      optionalBranchActive: true,
      branchLocalTaskDone: false,
      absorbedContributions: 0,
      counterexampleCount: 0,
      apexConverged: false,
      isolatedBranchSpawned: false,
      branchDirectlyFinalizedTrunk: false,
      convergedWithActiveRequiredBranch: false,
    }
  }

  // 1. Disjoint read/write FunFlow C4 DAG fan-out: 0 subagents spawned!
  action dispatchDisjointParallelDag = all {
    not(s59.apexConverged),
    s59.dagDisjointExecs < 2,
    s59' = { ...s59, dagDisjointExecs: s59.dagDisjointExecs + 1 }
  }

  // 2. Spawn subordinate branch anchored strictly to Trunk liveCut (0 isolated subagents)
  action spawnSharedContextBranch = all {
    not(s59.apexConverged),
    not(s59.requiredBranchActive),
    s59.absorbedContributions < 2,
    s59' = {
      ...s59,
      requiredBranchActive: true,
      requiredBranchCut: s59.trunkCut,
      branchLocalTaskDone: false,
    }
  }

  // 3. Subordinate branch completes its local task (NEVER finalizes Trunk!)
  action completeSubordinateBranchTask = all {
    s59.requiredBranchActive,
    not(s59.branchLocalTaskDone),
    s59.requiredBranchCut == s59.trunkCut,
    s59' = { ...s59, branchLocalTaskDone: true }
  }

  // 4. Absorb branch contribution at live cut & monotonically preserve counterexamples
  action absorbContributionAtLiveCut = all {
    s59.requiredBranchActive,
    s59.branchLocalTaskDone,
    s59.requiredBranchCut == s59.trunkCut,
    s59' = {
      ...s59,
      requiredBranchActive: false,
      branchLocalTaskDone: false,
      absorbedContributions: s59.absorbedContributions + 1,
      counterexampleCount: s59.counterexampleCount + 1,
    }
  }

  // 5. Trunk advances cut -> immediately supersedes active branch while keeping counterexamples
  action advanceTrunkCutAndSupersede = all {
    not(s59.apexConverged),
    s59.trunkCut < 2,
    s59' = {
      ...s59,
      trunkCut: s59.trunkCut + 1,
      requiredBranchActive: false,
      branchLocalTaskDone: false,
      counterexampleCount: if (s59.requiredBranchActive) s59.counterexampleCount + 1 else s59.counterexampleCount,
    }
  }

  // 6. Converge Trunk to Apex (requires 0 active required branches, cancels optional branches)
  action convergeTrunkToApex = all {
    not(s59.apexConverged),
    not(s59.requiredBranchActive),
    s59.absorbedContributions >= 1,
    s59' = {
      ...s59,
      apexConverged: true,
      optionalBranchActive: false,
    }
  }

  action step = any {
    dispatchDisjointParallelDag,
    spawnSharedContextBranch,
    completeSubordinateBranchTask,
    absorbContributionAtLiveCut,
    advanceTrunkCutAndSupersede,
    convergeTrunkToApex,
  }

  // Negative-control fault injections
  action buggyParallelDagSpawnsSubagent = all {
    not(s59.apexConverged),
    s59' = { ...s59, subagentsFromDag: s59.subagentsFromDag + 1 }
  }

  action buggySpawnIsolatedBranch = all {
    not(s59.apexConverged),
    s59' = { ...s59, isolatedBranchSpawned: true }
  }

  action buggyBranchDirectFinalizeTrunk = all {
    s59.requiredBranchActive,
    s59.branchLocalTaskDone,
    s59' = { ...s59, branchDirectlyFinalizedTrunk: true, apexConverged: true }
  }

  action buggyConvergeWithActiveRequiredBranch = all {
    s59.requiredBranchActive,
    s59' = { ...s59, convergedWithActiveRequiredBranch: true, apexConverged: true }
  }

  // Four bidirectional safety invariants mapped in SysML
  val parallelDagNeverSpawnsSubagents =
    s59.subagentsFromDag == 0

  val noIsolatedUnsharedSubagentSpawned =
    not(s59.isolatedBranchSpawned)

  val subordinateBranchNeverDirectlyFinalizesTrunk =
    not(s59.branchDirectlyFinalizedTrunk)

  val apexConvergenceClearsOptionalAndRequiresZeroActiveBranches =
    not(s59.convergedWithActiveRequiredBranch) and
    (not(s59.apexConverged) or (not(s59.requiredBranchActive) and not(s59.optionalBranchActive)))

  val safety = and {
    parallelDagNeverSpawnsSubagents,
    noIsolatedUnsharedSubagentSpawned,
    subordinateBranchNeverDirectlyFinalizesTrunk,
    apexConvergenceClearsOptionalAndRequiresZeroActiveBranches,
  }

  // Positive witnesses
  run safeDagAndTreeApexConvergenceTest =
    init
      .then(dispatchDisjointParallelDag)
      .then(spawnSharedContextBranch)
      .then(completeSubordinateBranchTask)
      .then(absorbContributionAtLiveCut)
      .then(convergeTrunkToApex)
      .expect(safety and s59.apexConverged and not(s59.optionalBranchActive) and s59.subagentsFromDag == 0)

  run safeCutAdvanceSupersedesAndRecoversTest =
    init
      .then(spawnSharedContextBranch)
      .then(advanceTrunkCutAndSupersede)
      .then(spawnSharedContextBranch)
      .then(completeSubordinateBranchTask)
      .then(absorbContributionAtLiveCut)
      .then(convergeTrunkToApex)
      .expect(safety and s59.apexConverged and s59.counterexampleCount == 2)

  // Negative-control counterexamples
  run parallelDagSubagentLeakCounterexampleTest =
    init
      .then(buggyParallelDagSpawnsSubagent)
      .expect(not(parallelDagNeverSpawnsSubagents))

  run isolatedBranchCounterexampleTest =
    init
      .then(buggySpawnIsolatedBranch)
      .expect(not(noIsolatedUnsharedSubagentSpawned))

  run branchDirectFinalizeCounterexampleTest =
    init
      .then(spawnSharedContextBranch)
      .then(completeSubordinateBranchTask)
      .then(buggyBranchDirectFinalizeTrunk)
      .expect(not(subordinateBranchNeverDirectlyFinalizesTrunk))

  run prematureApexConvergenceCounterexampleTest =
    init
      .then(spawnSharedContextBranch)
      .then(buggyConvergeWithActiveRequiredBranch)
      .expect(not(apexConvergenceClearsOptionalAndRequiresZeroActiveBranches))
}
