// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

// Slice 50 — Quint Nondeterministic Concurrent Interleaving Model ONLY:
// Per FormalVerificationTaxonomy in
// 50-literature-frontier-detour-confinement-and-causal-audit.sysml,
// unbounded algebraic/structural laws live in 50-*.lean; this module exhaustively
// explores concurrent races for three mechanisms absorbed from 2025-2026 papers:
// 1. APPA-inspired Scoped Detour Taint Confinement (untrusted read inside
//    no-egress detour, bounded-schema attestation / DeclassificationCert merge
//    without polluting mainline taint).
// 2. NeuroTaint-inspired zero-LLM offline counterfactual causal dependence audit.
// 3. Deterministic stall / divergence advisory signals (zero auto-mutation).
module DetourTaintConfinementAndCausalAudit {
  type State = {
    mainlineTainted: bool,
    detourActive: bool,
    detourTainted: bool,
    detourEgressAttempted: bool,
    detourEgressWasTainted: bool,
    schemaAttested: bool,
    detourDeclassCertified: bool,
    mergedReceiptCount: int,
    unattestedMergeOccurred: bool,
    sensitiveReadOccurred: bool,
    decisionFlippedBySecret: bool,
    auditDeclassCertified: bool,
    offlineAuditExecuted: bool,
    causalLeakFlagged: bool,
    repeatedFailures: int,
    advisoryRaised: bool,
    advisoryAutoMutatedMainline: bool
  }

  var s50: State

  action init: bool =
    s50' = {
      mainlineTainted: false,
      detourActive: false,
      detourTainted: false,
      detourEgressAttempted: false,
      detourEgressWasTainted: false,
      schemaAttested: false,
      detourDeclassCertified: false,
      mergedReceiptCount: 0,
      unattestedMergeOccurred: false,
      sensitiveReadOccurred: false,
      decisionFlippedBySecret: false,
      auditDeclassCertified: false,
      offlineAuditExecuted: false,
      causalLeakFlagged: false,
      repeatedFailures: 0,
      advisoryRaised: false,
      advisoryAutoMutatedMainline: false
    }

  action openConfinedDetour: bool = all {
    not(s50.detourActive),
    s50.mergedReceiptCount < 2,
    s50' = {
      ...s50,
      detourActive: true,
      detourTainted: false,
      schemaAttested: false,
      detourDeclassCertified: false
    }
  }

  // APPA trajectory confinement: untrusted read taints ONLY the detour, never mainline.
  action readUntrustedInDetour: bool = all {
    s50.detourActive,
    not(s50.detourTainted),
    s50' = { ...s50, detourTainted: true }
  }

  action attestBoundedSchema: bool = all {
    s50.detourActive,
    not(s50.schemaAttested),
    s50' = { ...s50, schemaAttested: true }
  }

  action issueDetourDeclassCert: bool = all {
    s50.detourActive,
    not(s50.detourDeclassCertified),
    s50' = { ...s50, detourDeclassCertified: true }
  }

  // Confined detour egress is admitted ONLY while detour is untainted.
  action attemptCleanDetourEgress: bool = all {
    s50.detourActive,
    not(s50.detourTainted),
    not(s50.detourEgressAttempted),
    s50' = {
      ...s50,
      detourEgressAttempted: true,
      detourEgressWasTainted: s50.detourTainted
    }
  }

  // Merging detour return to mainline requires untainted detour OR bounded-schema OR declass cert.
  action mergeConfinedDetourToMainline: bool = all {
    s50.detourActive,
    s50.mergedReceiptCount < 2,
    not(s50.detourTainted) or s50.schemaAttested or s50.detourDeclassCertified,
    s50' = {
      ...s50,
      detourActive: false,
      detourTainted: false,
      schemaAttested: false,
      detourDeclassCertified: false,
      mergedReceiptCount: s50.mergedReceiptCount + 1,
      unattestedMergeOccurred:
        s50.unattestedMergeOccurred or
        (s50.detourTainted and not(s50.schemaAttested) and not(s50.detourDeclassCertified))
    }
  }

  // NeuroTaint-inspired sensitive read + counterfactual branch flip observation
  action observeSensitiveBranchFlip(certified: bool): bool = all {
    not(s50.sensitiveReadOccurred),
    s50' = {
      ...s50,
      sensitiveReadOccurred: true,
      decisionFlippedBySecret: true,
      auditDeclassCertified: certified,
      offlineAuditExecuted: false
    }
  }

  action runOfflineCausalAudit: bool = all {
    s50.sensitiveReadOccurred,
    not(s50.offlineAuditExecuted),
    s50' = {
      ...s50,
      offlineAuditExecuted: true,
      causalLeakFlagged: s50.decisionFlippedBySecret and not(s50.auditDeclassCertified)
    }
  }

  // Deterministic stall / failure-signature advisory (never auto-mutates mainline!)
  action recordRepeatedFailure: bool = all {
    s50.repeatedFailures < 2,
    s50' = {
      ...s50,
      repeatedFailures: s50.repeatedFailures + 1,
      advisoryRaised: (s50.repeatedFailures + 1) >= 2
    }
  }

  action step = any {
    openConfinedDetour,
    readUntrustedInDetour,
    attestBoundedSchema,
    issueDetourDeclassCert,
    attemptCleanDetourEgress,
    mergeConfinedDetourToMainline,
    { nondet cert = Set(false, true).oneOf()
      observeSensitiveBranchFlip(cert) },
    runOfflineCausalAudit,
    recordRepeatedFailure,
    s50' = s50
  }

  // Temporal safety invariants
  val confinedDetourNeverLeaksUnattestedToMainline =
    not(s50.unattestedMergeOccurred) and not(s50.mainlineTainted)

  val taintedConfinedDetourNeverEgresses =
    not(s50.detourEgressAttempted) or not(s50.detourEgressWasTainted)

  val unendorsedCausalFlipAlwaysFlaggedByAudit =
    not(s50.offlineAuditExecuted) or
    not(s50.decisionFlippedBySecret and not(s50.auditDeclassCertified)) or
    s50.causalLeakFlagged

  val stallAdvisoryNeverAutoMutatesMainline =
    not(s50.advisoryAutoMutatedMainline)

  val safety = and {
    confinedDetourNeverLeaksUnattestedToMainline,
    taintedConfinedDetourNeverEgresses,
    unendorsedCausalFlipAlwaysFlaggedByAudit,
    stallAdvisoryNeverAutoMutatesMainline
  }

  // Standalone fault-injection actions (outside `step`) for negative-control verification
  action buggyMergeUnattestedTaintedDetour: bool = all {
    s50.detourActive,
    s50.detourTainted,
    not(s50.schemaAttested),
    not(s50.detourDeclassCertified),
    s50' = {
      ...s50,
      detourActive: false,
      mainlineTainted: true,
      unattestedMergeOccurred: true,
      mergedReceiptCount: s50.mergedReceiptCount + 1
    }
  }

  action buggyDetourEgressWhileTainted: bool = all {
    s50.detourActive,
    s50.detourTainted,
    s50' = {
      ...s50,
      detourEgressAttempted: true,
      detourEgressWasTainted: true
    }
  }

  action buggySuppressCausalLeakFlag: bool = all {
    s50.sensitiveReadOccurred,
    s50.decisionFlippedBySecret,
    not(s50.auditDeclassCertified),
    s50' = {
      ...s50,
      offlineAuditExecuted: true,
      causalLeakFlagged: false
    }
  }

  run confinedDetourAttestedReturnAndCausalAuditSafeTest =
    init
      .then(openConfinedDetour)
      .then(readUntrustedInDetour)
      .then(attestBoundedSchema)
      .then(mergeConfinedDetourToMainline)
      .then(observeSensitiveBranchFlip(false))
      .then(runOfflineCausalAudit)
      .then(recordRepeatedFailure)
      .then(recordRepeatedFailure)
      .expect(
        s50.mergedReceiptCount == 1 and
        not(s50.mainlineTainted) and
        s50.causalLeakFlagged and
        s50.advisoryRaised and
        safety
      )

  run buggyUnattestedMergeCounterexampleTest =
    init
      .then(openConfinedDetour)
      .then(readUntrustedInDetour)
      .then(buggyMergeUnattestedTaintedDetour)
      .expect(not(confinedDetourNeverLeaksUnattestedToMainline))

  run buggyTaintedEgressCounterexampleTest =
    init
      .then(openConfinedDetour)
      .then(readUntrustedInDetour)
      .then(buggyDetourEgressWhileTainted)
      .expect(not(taintedConfinedDetourNeverEgresses))

  run buggySuppressedCausalAuditCounterexampleTest =
    init
      .then(observeSensitiveBranchFlip(false))
      .then(buggySuppressCausalLeakFlag)
      .expect(not(unendorsedCausalFlipAlwaysFlaggedByAudit))
}
