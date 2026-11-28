// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

// Slice 43 — Quint Nondeterministic Concurrent Interleaving Model ONLY:
// Per FormalVerificationTaxonomy in 43-ascent-security-branch-omission-refinement.sysml,
// unbounded Branch x Hypothesis matrix antitonicity and heuristic-invariance
// laws live in 43-*.lean; this module explores nondeterministic races between:
// 1. Dynamic ASCENT discovery of competing undefeated hypotheses ("H3") under
//    a finite 2-hypothesis projection budget (emitting OmittedAlternativesReceipt);
// 2. Prepared destructive remediation vs read-only discriminating probes racing
//    against hypothesis discovery, probe-driven refutation, and grant revocations.
module AscentSecurityBranchOmissionRefinement {
  type State = {
    liveUndefeated: Set[str],
    projectedSet: Set[str],
    omissionReceiptActive: bool,
    readGrantLive: bool,
    remediationGrantLive: bool,
    preparedReadProbe: bool,
    preparedDestructiveRemediation: bool,
    dispatchedReadProbes: int,
    dispatchedDestructiveRemediation: bool,
    omissionWasActiveAtRemediation: bool,
    readGrantWasLiveAtProbe: bool
  }

  pure val projectionCapacity = 2

  var s43: State

  action init: bool =
    s43' = {
      liveUndefeated: Set("H1", "H2"),
      projectedSet: Set("H1", "H2"),
      omissionReceiptActive: false,
      readGrantLive: true,
      remediationGrantLive: true,
      preparedReadProbe: false,
      preparedDestructiveRemediation: false,
      dispatchedReadProbes: 0,
      dispatchedDestructiveRemediation: false,
      omissionWasActiveAtRemediation: false,
      readGrantWasLiveAtProbe: true
    }

  // ASCENT dynamically surfaces a 3rd undefeated hypothesis exceeding budget 2.
  action discoverThirdCompetingHypothesis: bool = all {
    not(s43.liveUndefeated.contains("H3")),
    s43' = {
      ...s43,
      liveUndefeated: s43.liveUndefeated.union(Set("H3")),
      // Budget cap = 2 keeps projectedSet at {"H1", "H2"} and raises omission receipt!
      omissionReceiptActive: true
    }
  }

  action prepareReadDiscriminator: bool = all {
    s43.readGrantLive,
    s43' = { ...s43, preparedReadProbe: true }
  }

  action prepareDestructiveRemediation: bool = all {
    s43.remediationGrantLive,
    not(s43.omissionReceiptActive),
    s43.liveUndefeated.subseteq(s43.projectedSet),
    s43' = { ...s43, preparedDestructiveRemediation: true }
  }

  // Read-only discriminator remains admissible even when omissionReceiptActive == true!
  action consumeReadProbeAndRefuteOmitted: bool = all {
    s43.preparedReadProbe,
    s43.readGrantLive,
    s43.dispatchedReadProbes < 2,
    s43' = {
      ...s43,
      preparedReadProbe: false,
      dispatchedReadProbes: s43.dispatchedReadProbes + 1,
      readGrantWasLiveAtProbe: s43.readGrantLive,
      // Probe observation refutes H3, restoring exhaustive 2-hypothesis coverage!
      liveUndefeated: s43.liveUndefeated.exclude(Set("H3")),
      omissionReceiptActive: false
    }
  }

  // Destructive remediation re-checks at consumption that zero live competitors are omitted!
  action consumeDestructiveRemediationFence: bool = all {
    s43.preparedDestructiveRemediation,
    s43.remediationGrantLive,
    not(s43.omissionReceiptActive),
    s43.liveUndefeated.subseteq(s43.projectedSet),
    s43' = {
      ...s43,
      preparedDestructiveRemediation: false,
      dispatchedDestructiveRemediation: true,
      omissionWasActiveAtRemediation:
        s43.omissionReceiptActive or not(s43.liveUndefeated.subseteq(s43.projectedSet))
    }
  }

  action revokeReadGrant: bool =
    s43' = { ...s43, readGrantLive: false }

  action revokeRemediationGrant: bool =
    s43' = { ...s43, remediationGrantLive: false }

  action step = any {
    discoverThirdCompetingHypothesis,
    prepareReadDiscriminator,
    prepareDestructiveRemediation,
    consumeReadProbeAndRefuteOmitted,
    consumeDestructiveRemediationFence,
    revokeReadGrant,
    revokeRemediationGrant,
    s43' = s43
  }

  // Temporal safety invariants
  val destructiveRemediationBlockedUnderOmittedCompetitors =
    not(s43.dispatchedDestructiveRemediation) or not(s43.omissionWasActiveAtRemediation)

  val readProbePermittedUnderOmissionWithLiveReadGrant =
    (s43.dispatchedReadProbes == 0) or s43.readGrantWasLiveAtProbe

  val omissionReceiptAccuratelyTracksUnprojectedCompetitors =
    s43.liveUndefeated.subseteq(s43.projectedSet) or s43.omissionReceiptActive

  val safety = and {
    destructiveRemediationBlockedUnderOmittedCompetitors,
    readProbePermittedUnderOmissionWithLiveReadGrant,
    omissionReceiptAccuratelyTracksUnprojectedCompetitors
  }

  // Standalone fault-injection action (outside `step`) for race counterexample
  action buggyConsumePreparedRemediationIgnoringNewCompetitor: bool = all {
    s43.preparedDestructiveRemediation,
    s43' = {
      ...s43,
      dispatchedDestructiveRemediation: true,
      omissionWasActiveAtRemediation:
        s43.omissionReceiptActive or not(s43.liveUndefeated.subseteq(s43.projectedSet))
    }
  }

  run probeResolvesLateCompetitorBeforeRemediationSafeTest =
    init
      .then(prepareDestructiveRemediation)
      .then(discoverThirdCompetingHypothesis)
      .expect(s43.omissionReceiptActive and safety)
      .then(prepareReadDiscriminator)
      .then(consumeReadProbeAndRefuteOmitted)
      .expect(not(s43.omissionReceiptActive) and s43.dispatchedReadProbes == 1 and safety)
      .then(consumeDestructiveRemediationFence)
      .expect(s43.dispatchedDestructiveRemediation and safety)

  run lateCompetitorRaceAgainstPreparedRemediationCounterexampleTest =
    init
      .then(prepareDestructiveRemediation)
      .then(discoverThirdCompetingHypothesis)
      .then(buggyConsumePreparedRemediationIgnoringNewCompetitor)
      .expect(not(destructiveRemediationBlockedUnderOmittedCompetitors))
}
