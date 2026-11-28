// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

// Slice 48 — Quint Nondeterministic Concurrent Interleaving Model ONLY:
// Per FormalVerificationTaxonomy in 48-progressive-disclosure-and-two-stage-org-repair.sysml,
// DisclosureDepth join-semilattice and Stage-1 deterministic repair idempotence
// live in 48-*.lean; this module explores nondeterministic races between:
// 1. Preparing a folded L0/L1/L2 disclosure projection while an active defeater
//    arrives asynchronously (requiring mandatory escalation to L3 before consume);
// 2. Stage-1 AST failure escalating to a bounded Stage-2 Flash repair request
//    racing against concurrent source-cut advances and Orgize re-parse verification.
module ProgressiveDisclosureAndOrgRepair {
  type State = {
    sourceCut: int,
    activeDefeaterPresent: bool,
    preparedDepth: int,            // 0=L0, 1=L1, 2=L2, 3=L3
    preparedCut: int,
    consumedDepth: int,
    consumedPresent: bool,
    defeaterWasActiveAtConsume: bool,
    stageOneSyntaxHealthy: bool,
    stageTwoPendingCut: int,       // 0 = none
    stageTwoPatchReParsed: bool,
    publishedStageTwoCut: int,     // 0 = none
    stageTwoWasValidAtPublish: bool
  }

  var s48: State

  action init: bool =
    s48' = {
      sourceCut: 1,
      activeDefeaterPresent: false,
      preparedDepth: 0,
      preparedCut: 0,
      consumedDepth: 0,
      consumedPresent: false,
      defeaterWasActiveAtConsume: false,
      stageOneSyntaxHealthy: true,
      stageTwoPendingCut: 0,
      stageTwoPatchReParsed: false,
      publishedStageTwoCut: 0,
      stageTwoWasValidAtPublish: true
    }

  action prepareDisclosure(depth: int): bool = all {
    Set(0, 1, 2, 3).contains(depth),
    not(s48.activeDefeaterPresent) or depth == 3,
    s48' = {
      ...s48,
      preparedDepth: depth,
      preparedCut: s48.sourceCut
    }
  }

  // Asynchronous arrival of an active defeater invalidates folded L0..L2 views.
  action arriveActiveDefeater: bool = all {
    not(s48.activeDefeaterPresent),
    s48' = {
      ...s48,
      activeDefeaterPresent: true,
      consumedPresent: if (s48.consumedDepth == 3) s48.consumedPresent else false
    }
  }

  // Atomic consumption fence rechecks cut & forces L3 whenever a defeater is live.
  action consumeDisclosureFence: bool = all {
    s48.preparedCut == s48.sourceCut,
    not(s48.activeDefeaterPresent) or s48.preparedDepth == 3,
    s48' = {
      ...s48,
      consumedPresent: true,
      consumedDepth: s48.preparedDepth,
      defeaterWasActiveAtConsume: s48.activeDefeaterPresent
    }
  }

  // Stage-1 deterministic AST repair cannot fix semantic break -> emit bounded Stage-2 request.
  action escalateToStageTwoFlash: bool = all {
    s48.stageTwoPendingCut == 0,
    s48' = {
      ...s48,
      stageOneSyntaxHealthy: false,
      stageTwoPendingCut: s48.sourceCut,
      stageTwoPatchReParsed: false
    }
  }

  // Orgize re-parses and validates the Stage-2 Flash patch at the exact live cut.
  action reParseStageTwoCandidate: bool = all {
    s48.stageTwoPendingCut == s48.sourceCut,
    not(s48.stageTwoPatchReParsed),
    s48' = { ...s48, stageTwoPatchReParsed: true }
  }

  action publishStageTwoPatchFence: bool = all {
    s48.stageTwoPendingCut == s48.sourceCut,
    s48.stageTwoPatchReParsed,
    s48.publishedStageTwoCut == 0,
    s48' = {
      ...s48,
      stageOneSyntaxHealthy: true,
      stageTwoPendingCut: 0,
      publishedStageTwoCut: s48.sourceCut,
      stageTwoWasValidAtPublish:
        s48.stageTwoPendingCut == s48.sourceCut and s48.stageTwoPatchReParsed
    }
  }

  // Concurrent source edit advances cut, invalidating pending Stage-2 candidates & folded cache.
  action advanceSourceCut: bool = all {
    s48.sourceCut < 2,
    s48' = {
      ...s48,
      sourceCut: s48.sourceCut + 1,
      consumedPresent: false,
      stageTwoPatchReParsed: false
    }
  }

  action step = any {
    { nondet d = Set(0, 1, 2, 3).oneOf()
      prepareDisclosure(d) },
    arriveActiveDefeater,
    consumeDisclosureFence,
    escalateToStageTwoFlash,
    reParseStageTwoCandidate,
    publishStageTwoPatchFence,
    advanceSourceCut,
    s48' = s48
  }

  // Temporal safety invariants
  val activeDefeaterNeverConsumedFolded =
    not(s48.consumedPresent) or (
      (not(s48.defeaterWasActiveAtConsume) or s48.consumedDepth == 3) and
      (not(s48.activeDefeaterPresent) or s48.consumedDepth == 3)
    )

  val stageTwoPatchRequiresCurrentCutAndReParse =
    (s48.publishedStageTwoCut == 0) or s48.stageTwoWasValidAtPublish

  val safety = and {
    activeDefeaterNeverConsumedFolded,
    stageTwoPatchRequiresCurrentCutAndReParse
  }

  // Standalone fault-injection actions (outside `step`) for race counterexamples
  action buggyConsumeFoldedIgnoringDefeater: bool = all {
    s48.preparedCut == s48.sourceCut,
    s48' = {
      ...s48,
      consumedPresent: true,
      consumedDepth: s48.preparedDepth,
      defeaterWasActiveAtConsume: s48.activeDefeaterPresent
    }
  }

  action buggyPublishUnparsedOrStaleStageTwo: bool = all {
    s48.stageTwoPendingCut != 0,
    s48' = {
      ...s48,
      publishedStageTwoCut: s48.sourceCut,
      stageTwoWasValidAtPublish:
        s48.stageTwoPendingCut == s48.sourceCut and s48.stageTwoPatchReParsed
    }
  }

  run defeaterEscalatesToL3AndReparsedStageTwoSafeTest =
    init
      .then(prepareDisclosure(2))
      .then(arriveActiveDefeater)
      .then(prepareDisclosure(3))
      .then(consumeDisclosureFence)
      .expect(s48.consumedPresent and s48.consumedDepth == 3 and safety)
      .then(escalateToStageTwoFlash)
      .then(reParseStageTwoCandidate)
      .then(publishStageTwoPatchFence)
      .expect(s48.publishedStageTwoCut == 1 and safety)

  run foldedL2ConsumedAfterDefeaterArrivalCounterexampleTest =
    init
      .then(prepareDisclosure(2))
      .then(arriveActiveDefeater)
      .then(buggyConsumeFoldedIgnoringDefeater)
      .expect(not(activeDefeaterNeverConsumedFolded))

  run staleStageTwoPatchAfterCutAdvanceCounterexampleTest =
    init
      .then(escalateToStageTwoFlash)
      .then(reParseStageTwoCandidate)
      .then(advanceSourceCut)
      .then(buggyPublishUnparsedOrStaleStageTwo)
      .expect(not(stageTwoPatchRequiresCurrentCutAndReParse))
}
