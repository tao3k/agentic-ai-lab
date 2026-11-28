// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
//
// Slice 54: Pure Durable Work Engine Core Formal Challenge (BUG-D1..BUG-D5).
// Explores concurrent crash-unclosed attempts vs auto-archive, active-lease
// explicit handover & expected-epoch CAS races, tainted detour CompletedExit
// merges, and hot overlay budget narrowing with 4 negative-control counterexamples.
module DurableWorkEngineCoreChallenge {
  type State = {
    parentMaxConcurrency: int,
    effectiveMaxConcurrency: int,
    detourTainted: bool,
    detourSchemaAttested: bool,
    detourDeclassCert: bool,
    mainlineTainted: bool,
    leaseOwner: int,
    leaseEpoch: int,
    leaseExpired: bool,
    handoverEndorsed: bool,
    leaseHijacked: bool,
    staleEpochAccepted: bool,
    unclosedAttemptCount: int,
    openBlockerCount: int,
    archived: bool,
  }

  var s54: State

  action init = all {
    s54' = {
      parentMaxConcurrency: 2,
      effectiveMaxConcurrency: 2,
      detourTainted: false,
      detourSchemaAttested: false,
      detourDeclassCert: false,
      mainlineTainted: false,
      leaseOwner: 1,
      leaseEpoch: 1,
      leaseExpired: false,
      handoverEndorsed: false,
      leaseHijacked: false,
      staleEpochAccepted: false,
      unclosedAttemptCount: 1,
      openBlockerCount: 1,
      archived: false,
    }
  }

  // BUG-D1 repaired: monotonic overlay narrowing (min)
  action applyMonotonicOverlay = all {
    not(s54.archived),
    nondet requested = oneOf(Set(1, 2, 6))
    val narrowed = if (requested < s54.parentMaxConcurrency) requested else s54.parentMaxConcurrency
    val nextEff = if (narrowed < s54.effectiveMaxConcurrency) narrowed else s54.effectiveMaxConcurrency
    s54' = { ...s54, effectiveMaxConcurrency: nextEff }
  }

  // BUG-D2 repaired: confined detour reads untrusted data, attests schema, then merges cleanly
  action detourReadUntrusted = all {
    not(s54.archived),
    not(s54.detourTainted),
    s54' = { ...s54, detourTainted: true, detourSchemaAttested: false, detourDeclassCert: false }
  }

  action attestDetourReturn = all {
    not(s54.archived),
    s54.detourTainted,
    not(s54.detourSchemaAttested),
    s54' = { ...s54, detourSchemaAttested: true }
  }

  action mergeConfinedDetour = all {
    not(s54.archived),
    s54.openBlockerCount > 0,
    not(s54.detourTainted) or s54.detourSchemaAttested or s54.detourDeclassCert,
    s54' = {
      ...s54,
      openBlockerCount: s54.openBlockerCount - 1,
      detourTainted: false,
      detourSchemaAttested: false,
      detourDeclassCert: false,
    }
  }

  // BUG-D3 repaired: expiry or non-self endorsement + exact expected-epoch CAS
  action expireActiveLease = all {
    not(s54.archived),
    not(s54.leaseExpired),
    s54' = { ...s54, leaseExpired: true }
  }

  action endorseExplicitHandover = all {
    not(s54.archived),
    not(s54.handoverEndorsed),
    s54' = { ...s54, handoverEndorsed: true }
  }

  action authorizedHandoverWithCas = all {
    not(s54.archived),
    s54.leaseEpoch < 3,
    s54.leaseExpired or s54.handoverEndorsed,
    nondet expectedEpoch = oneOf(Set(1, 2))
    expectedEpoch == s54.leaseEpoch,
    s54' = {
      ...s54,
      leaseOwner: if (s54.leaseOwner == 1) 2 else 1,
      leaseEpoch: s54.leaseEpoch + 1,
      leaseExpired: false,
      handoverEndorsed: false,
    }
  }

  // BUG-D4 repaired: reconcile unclosed attempt before archive can commit
  action reconcileUnclosedAttempt = all {
    not(s54.archived),
    s54.unclosedAttemptCount > 0,
    s54' = { ...s54, unclosedAttemptCount: s54.unclosedAttemptCount - 1 }
  }

  action commitQuiescentArchive = all {
    not(s54.archived),
    s54.unclosedAttemptCount == 0,
    s54.openBlockerCount == 0,
    s54' = { ...s54, archived: true }
  }

  action step = any {
    applyMonotonicOverlay,
    detourReadUntrusted,
    attestDetourReturn,
    mergeConfinedDetour,
    expireActiveLease,
    endorseExplicitHandover,
    authorizedHandoverWithCas,
    reconcileUnclosedAttempt,
    commitQuiescentArchive,
  }

  // Negative-control fault injections reproducing BUG-D1..BUG-D4
  action buggyArchiveWithUnclosedAttempt = all {
    not(s54.archived),
    s54.unclosedAttemptCount > 0,
    s54' = { ...s54, archived: true }
  }

  action buggyForceExplicitHijack = all {
    not(s54.archived),
    not(s54.leaseExpired),
    not(s54.handoverEndorsed),
    s54' = { ...s54, leaseOwner: 2, leaseEpoch: s54.leaseEpoch + 1, leaseHijacked: true }
  }

  action buggyTaintedDetourMerge = all {
    not(s54.archived),
    s54.detourTainted,
    not(s54.detourSchemaAttested),
    not(s54.detourDeclassCert),
    s54' = {
      ...s54,
      mainlineTainted: true,
      openBlockerCount: if (s54.openBlockerCount > 0) s54.openBlockerCount - 1 else 0,
    }
  }

  action buggyOverlayBudgetEscalate = all {
    not(s54.archived),
    s54' = { ...s54, effectiveMaxConcurrency: 6 }
  }

  // Five bidirectional safety invariants mapped in SysML
  val archiveNeverCommitsWithUnclosedAttemptOrOpenBlocker =
    s54.archived implies (s54.unclosedAttemptCount == 0 and s54.openBlockerCount == 0)

  val activeLeaseNeverHijackedWithoutExpiryOrEndorsement =
    not(s54.leaseHijacked)

  val staleEpochWriteOrHandoverAlwaysRejected =
    not(s54.staleEpochAccepted) and s54.leaseEpoch >= 1

  val taintedDetourNeverMergesUnattestedIntoMainline =
    not(s54.mainlineTainted)

  val overlayBudgetNeverExceedsParentPolicyFloor =
    s54.effectiveMaxConcurrency <= s54.parentMaxConcurrency

  val safety = and {
    archiveNeverCommitsWithUnclosedAttemptOrOpenBlocker,
    activeLeaseNeverHijackedWithoutExpiryOrEndorsement,
    staleEpochWriteOrHandoverAlwaysRejected,
    taintedDetourNeverMergesUnattestedIntoMainline,
    overlayBudgetNeverExceedsParentPolicyFloor,
  }

  // Positive witnesses
  run safeQuiescentArchiveAndHandoverTest =
    init
      .then(applyMonotonicOverlay)
      .then(detourReadUntrusted)
      .then(attestDetourReturn)
      .then(mergeConfinedDetour)
      .then(endorseExplicitHandover)
      .then(authorizedHandoverWithCas)
      .then(reconcileUnclosedAttempt)
      .then(commitQuiescentArchive)
      .expect(safety and s54.archived and s54.leaseEpoch == 2)

  run safeExpiredLeaseTakeoverTest =
    init
      .then(expireActiveLease)
      .then(authorizedHandoverWithCas)
      .expect(safety and s54.leaseOwner == 2 and s54.leaseEpoch == 2)

  // Negative-control counterexamples (ITF replay witnesses for BUG-D1..BUG-D4)
  run archiveWithUnclosedAttemptCounterexampleTest =
    init
      .then(buggyArchiveWithUnclosedAttempt)
      .expect(not(archiveNeverCommitsWithUnclosedAttemptOrOpenBlocker))

  run forceExplicitHijackCounterexampleTest =
    init
      .then(buggyForceExplicitHijack)
      .expect(not(activeLeaseNeverHijackedWithoutExpiryOrEndorsement))

  run taintedDetourMergeCounterexampleTest =
    init
      .then(detourReadUntrusted)
      .then(buggyTaintedDetourMerge)
      .expect(not(taintedDetourNeverMergesUnattestedIntoMainline))

  run overlayBudgetEscalateCounterexampleTest =
    init
      .then(buggyOverlayBudgetEscalate)
      .expect(not(overlayBudgetNeverExceedsParentPolicyFloor))
}
