// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

// Slice 51 — Quint Nondeterministic Concurrent Interleaving Model ONLY:
// Per FormalVerificationTaxonomy in
// 51-memory-poisoning-quarantine-and-kv-prefix-serialization.sysml,
// unbounded algebraic/list-prefix laws live in 51-*.lean; this module exhaustively
// explores concurrent races for:
// 1. MemoryGraft / MINJA untrusted experience ingestion into Quarantine vs
//    independent endorsement/rejection vs production recall.
// 2. Rolling detour open/fold operations strictly in the Dynamic Suffix while
//    keeping the Frozen Canonical KV Prefix intact (zero radix fracturing).
module MemoryQuarantineAndKvPrefixSerialization {
  type State = {
    quarantinedPoisonPresent: bool,
    quarantinedCleanPresent: bool,
    cleanEndorsed: bool,
    recallableContainsPoison: bool,
    recallableContainsClean: bool,
    recalledCount: int,
    recalledPoisonedOrQuarantined: bool,
    untrustedAutoPromoted: bool,
    frozenPrefixEpoch: int,
    dynamicSuffixDepth: int,
    kvPrefixFractured: bool
  }

  var s51: State

  action init: bool =
    s51' = {
      quarantinedPoisonPresent: false,
      quarantinedCleanPresent: false,
      cleanEndorsed: false,
      recallableContainsPoison: false,
      recallableContainsClean: false,
      recalledCount: 0,
      recalledPoisonedOrQuarantined: false,
      untrustedAutoPromoted: false,
      frozenPrefixEpoch: 1,
      dynamicSuffixDepth: 0,
      kvPrefixFractured: false
    }

  // MemoryGraft / MINJA: untrusted artifact induces a self-claimed "successful" experience candidate.
  // It MUST land strictly in Quarantine, never directly in recallable store.
  action ingestPoisonedUntrustedCandidate: bool = all {
    not(s51.quarantinedPoisonPresent),
    s51' = { ...s51, quarantinedPoisonPresent: true }
  }

  action ingestCleanUntrustedCandidate: bool = all {
    not(s51.quarantinedCleanPresent),
    not(s51.recallableContainsClean),
    s51' = { ...s51, quarantinedCleanPresent: true }
  }

  // Independent reviewer endorses ONLY verified non-poisoned candidate.
  action endorseCleanCandidate: bool = all {
    s51.quarantinedCleanPresent,
    not(s51.cleanEndorsed),
    s51' = { ...s51, cleanEndorsed: true }
  }

  action promoteEndorsedCleanCandidate: bool = all {
    s51.quarantinedCleanPresent,
    s51.cleanEndorsed,
    s51' = {
      ...s51,
      quarantinedCleanPresent: false,
      recallableContainsClean: true
    }
  }

  action rejectQuarantinedPoison: bool = all {
    s51.quarantinedPoisonPresent,
    s51' = { ...s51, quarantinedPoisonPresent: false }
  }

  // Production recall reads ONLY recallable tier (never quarantined items).
  action runProductionRecall: bool = all {
    s51.recallableContainsClean,
    s51.recalledCount < 2,
    s51' = {
      ...s51,
      recalledCount: s51.recalledCount + 1,
      recalledPoisonedOrQuarantined:
        s51.recalledPoisonedOrQuarantined or s51.recallableContainsPoison
    }
  }

  // Rolling detour open / fold happens strictly in Dynamic Suffix, preserving Frozen KV Prefix.
  action pushDynamicDetourSuffix: bool = all {
    s51.dynamicSuffixDepth < 2,
    s51' = { ...s51, dynamicSuffixDepth: s51.dynamicSuffixDepth + 1 }
  }

  action foldDynamicDetourSuffix: bool = all {
    s51.dynamicSuffixDepth > 0,
    s51' = { ...s51, dynamicSuffixDepth: s51.dynamicSuffixDepth - 1 }
  }

  action step = any {
    ingestPoisonedUntrustedCandidate,
    ingestCleanUntrustedCandidate,
    endorseCleanCandidate,
    promoteEndorsedCleanCandidate,
    rejectQuarantinedPoison,
    runProductionRecall,
    pushDynamicDetourSuffix,
    foldDynamicDetourSuffix,
    s51' = s51
  }

  // Temporal safety invariants
  val productionRecallNeverContainsQuarantinedOrPoisoned =
    not(s51.recalledPoisonedOrQuarantined) and not(s51.recallableContainsPoison)

  val untrustedExperienceNeverAutoPromotes =
    not(s51.untrustedAutoPromoted)

  val rollingDetourSuffixNeverFracturesFrozenKvPrefix =
    not(s51.kvPrefixFractured) and s51.frozenPrefixEpoch == 1

  val safety = and {
    productionRecallNeverContainsQuarantinedOrPoisoned,
    untrustedExperienceNeverAutoPromotes,
    rollingDetourSuffixNeverFracturesFrozenKvPrefix
  }

  // Standalone fault-injection actions (outside `step`) for negative-control verification
  action buggyAutoPromoteMemoryGraft: bool = all {
    s51.quarantinedPoisonPresent,
    s51' = {
      ...s51,
      quarantinedPoisonPresent: false,
      recallableContainsPoison: true,
      untrustedAutoPromoted: true
    }
  }

  action buggyRecallQuarantinedPoison: bool = all {
    s51.quarantinedPoisonPresent,
    s51' = {
      ...s51,
      recalledCount: s51.recalledCount + 1,
      recalledPoisonedOrQuarantined: true
    }
  }

  action buggyMidPrefixMutationFracturesKv: bool = all {
    s51.dynamicSuffixDepth > 0,
    s51' = {
      ...s51,
      kvPrefixFractured: true
    }
  }

  run quarantineRejectAndPrefixStableRecallSafeTest =
    init
      .then(ingestPoisonedUntrustedCandidate)
      .then(ingestCleanUntrustedCandidate)
      .then(rejectQuarantinedPoison)
      .then(endorseCleanCandidate)
      .then(promoteEndorsedCleanCandidate)
      .then(pushDynamicDetourSuffix)
      .then(runProductionRecall)
      .then(foldDynamicDetourSuffix)
      .expect(
        s51.recalledCount == 1 and
        not(s51.recalledPoisonedOrQuarantined) and
        not(s51.kvPrefixFractured) and
        safety
      )

  run buggyMemoryGraftAutoPromoteCounterexampleTest =
    init
      .then(ingestPoisonedUntrustedCandidate)
      .then(buggyAutoPromoteMemoryGraft)
      .expect(not(untrustedExperienceNeverAutoPromotes) and not(productionRecallNeverContainsQuarantinedOrPoisoned))

  run buggyRecallQuarantinedCounterexampleTest =
    init
      .then(ingestPoisonedUntrustedCandidate)
      .then(buggyRecallQuarantinedPoison)
      .expect(not(productionRecallNeverContainsQuarantinedOrPoisoned))

  run buggyMidPrefixFractureCounterexampleTest =
    init
      .then(pushDynamicDetourSuffix)
      .then(buggyMidPrefixMutationFracturesKv)
      .expect(not(rollingDetourSuffixNeverFracturesFrozenKvPrefix))
}
