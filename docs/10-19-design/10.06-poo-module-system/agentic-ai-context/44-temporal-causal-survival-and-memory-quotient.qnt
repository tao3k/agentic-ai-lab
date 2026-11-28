// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

// Slice 44 — Quint Nondeterministic Concurrent Interleaving Model ONLY:
// Per FormalVerificationTaxonomy in 44-temporal-causal-survival-and-memory-quotient.sysml,
// unbounded bitemporal journal cut algebra and citation frame laws live in 44-*.lean;
// this module explores nondeterministic races between:
// 1. SourceWatermark closure vs ASCENT `Why-Not` quotient admission;
// 2. Out-of-order late valid-time fact arrivals advancing admission cut `a`
//    without mutating historical snapshot `cut1Snapshot`;
// 3. Concurrent mutations on uncited exploratory evidence ("E-unused") vs cited
//    evidence ("E-cited") racing against active prompt selection and cold archival.
module TemporalCausalSurvivalMemoryQuotient {
  type State = {
    admissionCut: int,
    watermarkClosed: bool,
    liveStatus: str -> str,       // "active" | "retracted"
    cut1SnapshotCitedStatus: str, // frozen snapshot at admissionCut == 1
    activeWhyNotGem: bool,
    watermarkWasClosedAtWhyNot: bool,
    activeCitedGem: bool,
    coldArchivedGem: bool,
    unusedChurnCount: int
  }

  var s44: State

  action init: bool =
    s44' = {
      admissionCut: 1,
      watermarkClosed: false,
      liveStatus: Map("E-cited" -> "active", "E-unused" -> "active"),
      cut1SnapshotCitedStatus: "active",
      activeWhyNotGem: false,
      watermarkWasClosedAtWhyNot: true,
      activeCitedGem: false,
      coldArchivedGem: false,
      unusedChurnCount: 0
    }

  action closeSourceWatermark: bool =
    s44' = { ...s44, watermarkClosed: true }

  action admitCitedQuotientGem: bool = all {
    s44.liveStatus.get("E-cited") == "active",
    s44' = { ...s44, activeCitedGem: true }
  }

  action admitAscentWhyNotGem: bool = all {
    s44.watermarkClosed,
    s44.liveStatus.get("E-cited") == "active",
    s44' = {
      ...s44,
      activeWhyNotGem: true,
      watermarkWasClosedAtWhyNot: s44.watermarkClosed
    }
  }

  // Mutating retrieved-but-uncited evidence never evicts active gems!
  action churnUncitedExploratoryEvidence: bool = all {
    s44.unusedChurnCount < 2,
    s44' = {
      ...s44,
      liveStatus: s44.liveStatus.set("E-unused", "retracted"),
      unusedChurnCount: s44.unusedChurnCount + 1
    }
  }

  // Out-of-order late valid-time retraction of cited evidence advances admissionCut
  // and evicts active gems to cold history while preserving cut1SnapshotCitedStatus!
  action arriveLateRetractionOfCitedEvidence: bool = all {
    s44.admissionCut < 2,
    s44' = {
      ...s44,
      admissionCut: s44.admissionCut + 1,
      liveStatus: s44.liveStatus.set("E-cited", "retracted"),
      coldArchivedGem: s44.coldArchivedGem or s44.activeCitedGem or s44.activeWhyNotGem,
      activeCitedGem: false,
      activeWhyNotGem: false
    }
  }

  action step = any {
    closeSourceWatermark,
    admitCitedQuotientGem,
    admitAscentWhyNotGem,
    churnUncitedExploratoryEvidence,
    arriveLateRetractionOfCitedEvidence,
    s44' = s44
  }

  // Temporal safety invariants
  val whyNotMemoryRequiresClosedWatermark =
    not(s44.activeWhyNotGem) or s44.watermarkWasClosedAtWhyNot

  val historicalCutImmutableUnderLateValidTimeArrival =
    s44.cut1SnapshotCitedStatus == "active"

  val activeGemEvictsOnCitedRetractionAndIgnoresUncitedChurn =
    not(s44.activeCitedGem or s44.activeWhyNotGem) or
      s44.liveStatus.get("E-cited") == "active"

  val safety = and {
    whyNotMemoryRequiresClosedWatermark,
    historicalCutImmutableUnderLateValidTimeArrival,
    activeGemEvictsOnCitedRetractionAndIgnoresUncitedChurn
  }

  // Standalone fault-injection actions (outside `step`) for race counterexamples
  action buggyAdmitWhyNotBeforeWatermark: bool =
    s44' = {
      ...s44,
      activeWhyNotGem: true,
      watermarkWasClosedAtWhyNot: s44.watermarkClosed
    }

  action buggyKeepActiveGemAfterCitedRetraction: bool = all {
    s44.admissionCut < 2,
    s44' = {
      ...s44,
      admissionCut: s44.admissionCut + 1,
      liveStatus: s44.liveStatus.set("E-cited", "retracted")
    }
  }

  run uncitedChurnAndCitedRetractionArchivalSafeTest =
    init
      .then(closeSourceWatermark)
      .then(admitCitedQuotientGem)
      .then(admitAscentWhyNotGem)
      .then(churnUncitedExploratoryEvidence)
      .expect(s44.activeCitedGem and s44.activeWhyNotGem and safety)
      .then(arriveLateRetractionOfCitedEvidence)
      .expect(
        not(s44.activeCitedGem) and
        s44.coldArchivedGem and
        s44.cut1SnapshotCitedStatus == "active" and
        safety
      )

  run prematureWhyNotBeforeWatermarkCounterexampleTest =
    init
      .then(buggyAdmitWhyNotBeforeWatermark)
      .expect(not(whyNotMemoryRequiresClosedWatermark))

  run missedEvictionOnCitedRetractionCounterexampleTest =
    init
      .then(admitCitedQuotientGem)
      .then(buggyKeepActiveGemAfterCitedRetraction)
      .expect(not(activeGemEvictsOnCitedRetractionAndIgnoresUncitedChurn))
}
