// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

// Slice 46 — Quint Nondeterministic Concurrent Interleaving Model ONLY:
// Per FormalVerificationTaxonomy in 46-durable-agenda-session-sandbox-governance.sysml,
// capability-intersection algebra, Lethal-Trifecta structural elimination and
// per-recipient frame laws live in 46-*.lean; this module explores
// nondeterministic races across:
// 1. Asynchronous Agenda wakes vs mid-preparation grant revocation;
// 2. Sandbox egress endorsement vs untrusted+private Context exposure;
// 3. Crash-after-handoff-before-receipt (`outcome == "unknown"`), late provider
//    receipt arrival, attested final no-send reconciliation, and fresh Attempt gen.
module DurableAgendaSessionSandbox {
  type AttemptState = {
    gen: int,
    consumedFence: bool,
    outcome: str,               // "none", "unknown", "accepted", "confirmed-no-send"
    wasGrantedAtFence: bool,
    egressEnabled: bool,
    blindRetryOccurred: bool,
    genStrictlyAdvanced: bool
  }

  type State = {
    wakePending: bool,
    grantLive: bool,
    hasUntrustedInput: bool,
    hasPrivateData: bool,
    egressEndorsed: bool,
    preparedEgress: Set[bool],
    nextAttemptGen: int,
    activeAttempt: AttemptState
  }

  pure val idleAttempt: AttemptState = {
    gen: 0,
    consumedFence: false,
    outcome: "none",
    wasGrantedAtFence: true,
    egressEnabled: false,
    blindRetryOccurred: false,
    genStrictlyAdvanced: true
  }

  var s46: State

  action init: bool =
    s46' = {
      wakePending: false,
      grantLive: true,
      hasUntrustedInput: true,
      hasPrivateData: true,
      egressEndorsed: false,
      preparedEgress: Set(),
      nextAttemptGen: 1,
      activeAttempt: idleAttempt
    }

  action fireAgendaWake: bool =
    s46' = { ...s46, wakePending: true }

  action prepareSandboxDispatch(requestEgress: bool): bool = all {
    s46.wakePending,
    s46.grantLive,
    not(s46.hasUntrustedInput and s46.hasPrivateData and requestEgress and not(s46.egressEndorsed)),
    s46' = { ...s46, preparedEgress: Set(requestEgress) }
  }

  action endorseSanitizedEgress: bool =
    s46' = { ...s46, egressEndorsed: true }

  action revokeGrantMidFlight: bool =
    s46' = { ...s46, grantLive: false }

  action consumeSandboxHandoffFence(reqEgress: bool): bool = all {
    s46.preparedEgress.contains(reqEgress),
    s46.wakePending,
    s46.grantLive,
    not(s46.hasUntrustedInput and s46.hasPrivateData and reqEgress and not(s46.egressEndorsed)),
    s46.activeAttempt.outcome == "none" or s46.activeAttempt.outcome == "confirmed-no-send",
    s46.nextAttemptGen <= 3,
    s46' = {
      ...s46,
      preparedEgress: Set(),
      nextAttemptGen: s46.nextAttemptGen + 1,
      activeAttempt: {
        gen: s46.nextAttemptGen,
        consumedFence: true,
        outcome: "accepted",
        wasGrantedAtFence: s46.grantLive,
        egressEnabled: reqEgress,
        blindRetryOccurred: s46.activeAttempt.outcome == "unknown",
        genStrictlyAdvanced: s46.nextAttemptGen > s46.activeAttempt.gen
      }
    }
  }

  action crashAfterHandoffBeforeReceipt: bool = all {
    s46.activeAttempt.consumedFence,
    s46.activeAttempt.outcome == "accepted",
    s46' = {
      ...s46,
      activeAttempt: { ...s46.activeAttempt, outcome: "unknown" }
    }
  }

  action arriveLateProviderReceipt: bool = all {
    s46.activeAttempt.outcome == "unknown",
    s46' = {
      ...s46,
      activeAttempt: { ...s46.activeAttempt, outcome: "accepted" }
    }
  }

  action reconcileConfirmedNoSendFence: bool = all {
    s46.activeAttempt.outcome == "unknown",
    s46.grantLive,
    s46' = {
      ...s46,
      activeAttempt: { ...s46.activeAttempt, outcome: "confirmed-no-send" }
    }
  }

  action step = any {
    fireAgendaWake,
    { nondet eg = Set(true, false).oneOf()
      prepareSandboxDispatch(eg) },
    endorseSanitizedEgress,
    revokeGrantMidFlight,
    { nondet reqEgress = s46.preparedEgress.oneOf()
      consumeSandboxHandoffFence(reqEgress) },
    crashAfterHandoffBeforeReceipt,
    arriveLateProviderReceipt,
    reconcileConfirmedNoSendFence,
    s46' = s46
  }

  // Temporal safety invariants
  val wakeNeverDispatchesWithoutLiveGrant =
    not(s46.activeAttempt.consumedFence) or s46.activeAttempt.wasGrantedAtFence

  val lethalTrifectaExcludedAtFence =
    not(s46.activeAttempt.consumedFence and s46.activeAttempt.egressEnabled) or
      not(s46.hasUntrustedInput and s46.hasPrivateData and not(s46.egressEndorsed))

  val crashAmbiguityBlocksBlindRetryAndAdvancesGen =
    not(s46.activeAttempt.consumedFence) or (
      not(s46.activeAttempt.blindRetryOccurred) and
      s46.activeAttempt.genStrictlyAdvanced
    )

  val safety = and {
    wakeNeverDispatchesWithoutLiveGrant,
    lethalTrifectaExcludedAtFence,
    crashAmbiguityBlocksBlindRetryAndAdvancesGen
  }

  // Standalone fault-injection actions (outside `step`) for race counterexamples
  action buggyConsumeAfterMidFlightRevocation: bool = all {
    s46.wakePending,
    s46' = {
      ...s46,
      activeAttempt: {
        ...s46.activeAttempt,
        gen: s46.nextAttemptGen,
        consumedFence: true,
        outcome: "accepted",
        wasGrantedAtFence: s46.grantLive
      }
    }
  }

  action buggyBlindRetryDuringCrashAmbiguity: bool = all {
    s46.activeAttempt.outcome == "unknown",
    s46' = {
      ...s46,
      activeAttempt: {
        ...s46.activeAttempt,
        gen: s46.nextAttemptGen,
        outcome: "accepted",
        blindRetryOccurred: s46.activeAttempt.outcome == "unknown"
      }
    }
  }

  run wakeCrashReconcileAndFreshRetrySafeTest =
    init
      .then(fireAgendaWake)
      .then(prepareSandboxDispatch(false))
      .then(consumeSandboxHandoffFence(false))
      .expect(s46.activeAttempt.gen == 1 and safety)
      .then(crashAfterHandoffBeforeReceipt)
      .expect(s46.activeAttempt.outcome == "unknown" and safety)
      .then(reconcileConfirmedNoSendFence)
      .then(prepareSandboxDispatch(false))
      .then(consumeSandboxHandoffFence(false))
      .expect(s46.activeAttempt.gen == 2 and safety)

  run midFlightGrantRevocationRaceCounterexampleTest =
    init
      .then(fireAgendaWake)
      .then(prepareSandboxDispatch(false))
      .then(revokeGrantMidFlight)
      .then(buggyConsumeAfterMidFlightRevocation)
      .expect(not(wakeNeverDispatchesWithoutLiveGrant))

  run blindRetryOnCrashAmbiguityCounterexampleTest =
    init
      .then(fireAgendaWake)
      .then(prepareSandboxDispatch(false))
      .then(consumeSandboxHandoffFence(false))
      .then(crashAfterHandoffBeforeReceipt)
      .then(buggyBlindRetryDuringCrashAmbiguity)
      .expect(not(crashAmbiguityBlocksBlindRetryAndAdvancesGen))
}
