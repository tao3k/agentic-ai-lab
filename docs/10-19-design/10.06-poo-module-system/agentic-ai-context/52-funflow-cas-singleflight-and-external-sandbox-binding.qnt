// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

// Slice 52 — Quint Nondeterministic Concurrent Interleaving Model ONLY:
// Challenges and verifies the concurrent boundaries behind BUG-F1..BUG-F5 in
// modules/funflow/{durable-dag,store,control-plane/*}.ss:
// 1. Two-agent lookupOrWait singleflight deduplication (at most 1 active compute).
// 2. Atomic temp-write-then-rename publication barrier under mid-write crashes.
// 3. AuditCapsule-pinned CAS GC preserving historical forensic entries.
// 4. FencedEffect at-most-once execution + order-independent after-start finalizer
//    scheduling (never silently dropped by topological ordering).
module FunflowCasSingleflightAndExternalSandbox {
  type State = {
    // Singleflight & crash-atomic CAS publication
    agentAState: str,          // "idle" | "computing" | "done"
    agentBState: str,          // "idle" | "waiting" | "computing" | "done"
    activeComputeCount: int,
    tempStaged: bool,
    casPublished: bool,
    casPremiseGen: int,
    livePremiseGen: int,
    corruptCasVisible: bool,
    // AuditCapsule-pinned CAS GC
    capsulePinned: bool,
    pinnedEntryEvictedByGc: bool,
    gcSweeps: int,
    // FencedEffect & after-start finalizer safety
    fencedExecCount: int,
    fencedFailed: bool,
    pendingFinalizerRecorded: bool,
    finalizerCompleted: bool,
    archivedWorkflow: bool,
    archivedWithDroppedFinalizer: bool
  }

  var s52: State

  action init: bool =
    s52' = {
      agentAState: "idle",
      agentBState: "idle",
      activeComputeCount: 0,
      tempStaged: false,
      casPublished: false,
      casPremiseGen: 0,
      livePremiseGen: 1,
      corruptCasVisible: false,
      capsulePinned: false,
      pinnedEntryEvictedByGc: false,
      gcSweeps: 0,
      fencedExecCount: 0,
      fencedFailed: false,
      pendingFinalizerRecorded: false,
      finalizerCompleted: false,
      archivedWorkflow: false,
      archivedWithDroppedFinalizer: false
    }

  // Agent A performs lookupOrWait on uncached CAS key: acquires singleflight lock.
  action agentAAcquireSingleflight: bool = all {
    s52.agentAState == "idle",
    not(s52.casPublished),
    s52.activeComputeCount == 0,
    s52' = {
      ...s52,
      agentAState: "computing",
      activeComputeCount: 1
    }
  }

  // Agent B arrives concurrently while Agent A holds the singleflight lock -> waits.
  action agentBJoinSingleflightWait: bool = all {
    s52.agentBState == "idle",
    s52.activeComputeCount == 1,
    not(s52.casPublished),
    s52' = { ...s52, agentBState: "waiting" }
  }

  // Computing agent writes output to private temporary staging path (invisible to CAS readers).
  action stageTempArtifact: bool = all {
    s52.activeComputeCount == 1,
    not(s52.tempStaged),
    not(s52.casPublished),
    s52' = { ...s52, tempStaged: true }
  }

  // Crash before atomic rename: temp file discarded, CAS stays unpublished & clean, lock released.
  action crashBeforeAtomicRename: bool = all {
    s52.agentAState == "computing",
    s52.activeComputeCount == 1,
    not(s52.casPublished),
    s52' = {
      ...s52,
      agentAState: "idle",
      activeComputeCount: 0,
      tempStaged: false
    }
  }

  // Waiting Agent B takes over singleflight cleanly after Agent A crashed.
  action agentBTakeoverAfterCrash: bool = all {
    s52.agentBState == "waiting",
    s52.activeComputeCount == 0,
    not(s52.casPublished),
    s52' = {
      ...s52,
      agentBState: "computing",
      activeComputeCount: 1
    }
  }

  // Atomic rename publishes staged artifact to CAS and wakes any singleflight waiter.
  action atomicRenamePublish: bool = all {
    s52.activeComputeCount == 1,
    s52.tempStaged,
    not(s52.casPublished),
    s52' = {
      ...s52,
      agentAState: if (s52.agentAState == "computing") "done" else s52.agentAState,
      agentBState: if (s52.agentBState == "computing" or s52.agentBState == "waiting") "done" else s52.agentBState,
      activeComputeCount: 0,
      tempStaged: false,
      casPublished: true,
      casPremiseGen: s52.livePremiseGen
    }
  }

  // Agent B hits already-published CAS entry at matching live premise generation.
  action agentBHitLiveCas: bool = all {
    s52.agentBState == "idle",
    s52.casPublished,
    s52.casPremiseGen == s52.livePremiseGen,
    s52' = { ...s52, agentBState: "done" }
  }

  // Seal AuditCapsule pinning the published forensic CAS artifact (cut 1).
  action pinPublishedEntryToCapsule: bool = all {
    s52.casPublished,
    not(s52.capsulePinned),
    s52' = { ...s52, capsulePinned: true }
  }

  // Premise retraction / epoch advance (g: 1 -> 2) invalidates live VerifiedEpistemic reuse.
  action advanceOrRetractPremise: bool = all {
    s52.livePremiseGen < 2,
    s52' = { ...s52, livePremiseGen: s52.livePremiseGen + 1 }
  }

  // CAS GC sweep: may reclaim unpinned stale entries, MUST NEVER evict capsulePinned entry.
  action runCasGcSweep: bool = all {
    s52.gcSweeps < 2,
    s52' = {
      ...s52,
      gcSweeps: s52.gcSweeps + 1,
      casPublished: if (s52.capsulePinned) s52.casPublished else false
    }
  }

  // FencedEffect executes at most once under an idempotency token (never bypassed by plain CAS).
  action executeFencedEffectSucceed: bool = all {
    s52.fencedExecCount == 0,
    not(s52.archivedWorkflow),
    s52' = { ...s52, fencedExecCount: 1 }
  }

  // FencedEffect fails -> two-pass / after-start-ordered planner ALWAYS records pending finalizer.
  action executeFencedEffectFailAndRecordFinalizer: bool = all {
    s52.fencedExecCount == 0,
    not(s52.archivedWorkflow),
    s52' = {
      ...s52,
      fencedExecCount: 1,
      fencedFailed: true,
      pendingFinalizerRecorded: true
    }
  }

  // Pending after-start finalizer executes and settles cleanup before archive is allowed.
  action completePendingFinalizer: bool = all {
    s52.fencedFailed,
    s52.pendingFinalizerRecorded,
    not(s52.finalizerCompleted),
    s52' = {
      ...s52,
      pendingFinalizerRecorded: false,
      finalizerCompleted: true
    }
  }

  // Archive guard requires no pending finalizer and completed cleanup on failure.
  action archiveWorkflowSafe: bool = all {
    not(s52.archivedWorkflow),
    s52.fencedExecCount == 1,
    not(s52.pendingFinalizerRecorded),
    (not(s52.fencedFailed) or s52.finalizerCompleted),
    s52' = { ...s52, archivedWorkflow: true }
  }

  action step = any {
    agentAAcquireSingleflight,
    agentBJoinSingleflightWait,
    stageTempArtifact,
    crashBeforeAtomicRename,
    agentBTakeoverAfterCrash,
    atomicRenamePublish,
    agentBHitLiveCas,
    pinPublishedEntryToCapsule,
    advanceOrRetractPremise,
    runCasGcSweep,
    executeFencedEffectSucceed,
    executeFencedEffectFailAndRecordFinalizer,
    completePendingFinalizer,
    archiveWorkflowSafe,
    s52' = s52
  }

  // Four bidirectional SysML <-> Quint safety invariants
  val singleflightAtMostOneActiveComputePerKey =
    s52.activeComputeCount <= 1

  val atomicPublishNeverExposesPartialEntryOnCrash =
    not(s52.corruptCasVisible)

  val gcNeverEvictsCapsulePinnedForensicEntry =
    not(s52.pinnedEntryEvictedByGc) and (not(s52.capsulePinned) or s52.casPublished)

  val fencedEffectExecutesAtMostOnceAndFinalizerNeverDropped =
    s52.fencedExecCount <= 1 and
    not(s52.archivedWithDroppedFinalizer) and
    (not(s52.archivedWorkflow and s52.fencedFailed) or s52.finalizerCompleted)

  val safety = and {
    singleflightAtMostOneActiveComputePerKey,
    atomicPublishNeverExposesPartialEntryOnCrash,
    gcNeverEvictsCapsulePinnedForensicEntry,
    fencedEffectExecutesAtMostOnceAndFinalizerNeverDropped
  }

  // Standalone fault-injection actions (outside `step`) reproducing BUG-F1..BUG-F5
  action buggyBypassSingleflightDoubleCompute: bool = all {
    s52.agentAState == "computing",
    s52.agentBState == "idle",
    s52' = {
      ...s52,
      agentBState: "computing",
      activeComputeCount: s52.activeComputeCount + 1
    }
  }

  action buggyNonAtomicWriteCrashExposesPartialCas: bool = all {
    s52.agentAState == "computing",
    s52' = {
      ...s52,
      agentAState: "idle",
      activeComputeCount: 0,
      casPublished: true,
      corruptCasVisible: true
    }
  }

  action buggyGcEvictsPinnedAuditCapsuleEntry: bool = all {
    s52.capsulePinned,
    s52.casPublished,
    s52' = {
      ...s52,
      casPublished: false,
      pinnedEntryEvictedByGc: true
    }
  }

  // Reproduces BUG-F1 (finalizer dropped by misordered topo pass) + BUG-F3 (FencedEffect double exec)
  action buggyDropFinalizerOnMisorderedTopoAndArchive: bool = all {
    s52.fencedExecCount == 0,
    s52' = {
      ...s52,
      fencedExecCount: 2,
      fencedFailed: true,
      pendingFinalizerRecorded: false,
      finalizerCompleted: false,
      archivedWorkflow: true,
      archivedWithDroppedFinalizer: true
    }
  }

  // Positive witness: crash-takeover singleflight + pinned GC survival + failed fenced effect with finalizer
  run singleflightCrashTakeoverPinnedGcAndFinalizerSafeTest =
    init
      .then(agentAAcquireSingleflight)
      .then(agentBJoinSingleflightWait)
      .then(stageTempArtifact)
      .then(crashBeforeAtomicRename)
      .then(agentBTakeoverAfterCrash)
      .then(stageTempArtifact)
      .then(atomicRenamePublish)
      .then(pinPublishedEntryToCapsule)
      .then(advanceOrRetractPremise)
      .then(runCasGcSweep)
      .then(executeFencedEffectFailAndRecordFinalizer)
      .then(completePendingFinalizer)
      .then(archiveWorkflowSafe)
      .expect(
        s52.casPublished and
        s52.capsulePinned and
        not(s52.corruptCasVisible) and
        not(s52.pinnedEntryEvictedByGc) and
        s52.finalizerCompleted and
        s52.archivedWorkflow and
        safety
      )

  run buggySingleflightDoubleComputeCounterexampleTest =
    init
      .then(agentAAcquireSingleflight)
      .then(buggyBypassSingleflightDoubleCompute)
      .expect(not(singleflightAtMostOneActiveComputePerKey))

  run buggyNonAtomicCrashCorruptCasCounterexampleTest =
    init
      .then(agentAAcquireSingleflight)
      .then(buggyNonAtomicWriteCrashExposesPartialCas)
      .expect(not(atomicPublishNeverExposesPartialEntryOnCrash))

  run buggyGcEvictsPinnedCapsuleCounterexampleTest =
    init
      .then(agentAAcquireSingleflight)
      .then(stageTempArtifact)
      .then(atomicRenamePublish)
      .then(pinPublishedEntryToCapsule)
      .then(buggyGcEvictsPinnedAuditCapsuleEntry)
      .expect(not(gcNeverEvictsCapsulePinnedForensicEntry))

  run buggyMisorderedFinalizerAndDoubleFencedCounterexampleTest =
    init
      .then(buggyDropFinalizerOnMisorderedTopoAndArchive)
      .expect(not(fencedEffectExecutesAtMostOnceAndFinalizerNeverDropped))
}
