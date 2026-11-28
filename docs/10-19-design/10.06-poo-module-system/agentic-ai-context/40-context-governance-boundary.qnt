// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

// Slice 40 — Quint Nondeterministic Concurrent Interleaving Model ONLY:
// Per FormalVerificationTaxonomy in 40-context-governance-boundary.sysml,
// pure lattice/semilattice algebra lives in 40-*.lean; this module explores
// nondeterministic races between endorsement arrivals, source-cut advances,
// threat exposure/residual-acceptance transitions, grant revocation, and
// prepare-vs-consume handoff / KV-reuse fences.
module ContextGovernanceBoundary {
  type Endorsement = {
    proposer: str,
    endorser: str,
    boundCut: int,
    targetRank: int
  }

  type PreparedSlice = {
    present: bool,
    proposer: str,
    boundCut: int,
    grantEpoch: int,
    originRank: int,
    effectiveRank: int,
    endorser: str,
    endorsementCut: int,
    domain: str
  }

  type State = {
    sourceCut: int,
    grantEpoch: int,
    grantActive: bool,
    threatPhase: str,      // "latent", "exposed", "mitigated", "accepted"
    residualCut: int,
    endorsementInbox: Set[Endorsement],
    prepared: PreparedSlice,
    consumedHandoff: PreparedSlice,
    kvCachedDomain: str,
    kvCachedCut: int,
    kvReuseAdmitted: bool
  }

  pure val emptySlice: PreparedSlice = {
    present: false,
    proposer: "",
    boundCut: 0,
    grantEpoch: 0,
    originRank: 0,
    effectiveRank: 0,
    endorser: "",
    endorsementCut: 0,
    domain: ""
  }

  pure val actors = Set("agent-1", "reviewer-1")
  pure val domains = Set("tenantA:restricted", "tenantB:public")

  pure def validEndorsementAt(p: PreparedSlice, liveCut: int): bool =
    p.endorser != "" and p.endorser != p.proposer and p.endorsementCut == liveCut

  var s40: State

  action init: bool =
    s40' = {
      sourceCut: 1,
      grantEpoch: 1,
      grantActive: true,
      threatPhase: "latent",
      residualCut: 0,
      endorsementInbox: Set(),
      prepared: emptySlice,
      consumedHandoff: emptySlice,
      kvCachedDomain: "tenantA:restricted",
      kvCachedCut: 1,
      kvReuseAdmitted: false
    }

  // Asynchronous arrival of an endorsement (including potential self-endorsement).
  action arriveEndorsement(endorser: str, cut: int): bool =
    s40' = {
      ...s40,
      endorsementInbox: s40.endorsementInbox.union(Set({
        proposer: "agent-1",
        endorser: endorser,
        boundCut: cut,
        targetRank: 3
      }))
    }

  action prepareUnpromotedData(dom: str): bool =
    s40' = {
      ...s40,
      kvReuseAdmitted: false,
      prepared: {
        present: true,
        proposer: "agent-1",
        boundCut: s40.sourceCut,
        grantEpoch: s40.grantEpoch,
        originRank: 0,
        effectiveRank: 0,
        endorser: "",
        endorsementCut: 0,
        domain: dom
      }
    }

  action prepareEndorsedPromotion(e: Endorsement): bool = all {
    s40.endorsementInbox.contains(e),
    e.endorser != e.proposer,
    e.boundCut == s40.sourceCut,
    s40' = {
      ...s40,
      kvReuseAdmitted: false,
      prepared: {
        present: true,
        proposer: e.proposer,
        boundCut: s40.sourceCut,
        grantEpoch: s40.grantEpoch,
        originRank: 0,
        effectiveRank: e.targetRank,
        endorser: e.endorser,
        endorsementCut: e.boundCut,
        domain: "tenantA:restricted"
      }
    }
  }

  // Concurrent environment transitions racing against prepared state
  action advanceSourceCut: bool = all {
    s40.sourceCut < 2,
    s40' = {
      ...s40,
      sourceCut: s40.sourceCut + 1,
      consumedHandoff: emptySlice,
      kvReuseAdmitted: false
    }
  }

  action exposeCriticalThreat: bool =
    s40' = {
      ...s40,
      threatPhase: "exposed",
      consumedHandoff: emptySlice
    }

  action mitigateCriticalThreat: bool = all {
    s40.threatPhase == "exposed",
    s40' = { ...s40, threatPhase: "mitigated" }
  }

  action acceptResidualAtCurrentCut: bool = all {
    s40.threatPhase == "exposed",
    s40' = {
      ...s40,
      threatPhase: "accepted",
      residualCut: s40.sourceCut
    }
  }

  action revokeGrant: bool = all {
    s40.grantActive,
    s40' = {
      ...s40,
      grantEpoch: s40.grantEpoch + 1,
      grantActive: false,
      consumedHandoff: emptySlice,
      kvReuseAdmitted: false
    }
  }

  // Guarded atomic consumption fence
  action consumeHandoffFence: bool = {
    val p = s40.prepared
    all {
      p.present,
      s40.grantActive,
      p.boundCut == s40.sourceCut,
      p.grantEpoch == s40.grantEpoch,
      p.effectiveRank <= p.originRank or validEndorsementAt(p, s40.sourceCut),
      s40.threatPhase != "exposed",
      s40.threatPhase != "accepted" or s40.residualCut == s40.sourceCut,
      s40' = { ...s40, consumedHandoff: p }
    }
  }

  action admitKvPrefixReuse: bool = all {
    s40.prepared.present,
    s40.grantActive,
    s40.prepared.domain == s40.kvCachedDomain,
    s40.prepared.boundCut == s40.sourceCut,
    s40.kvCachedCut == s40.sourceCut,
    s40' = { ...s40, kvReuseAdmitted: true }
  }

  // Genuine nondeterministic protocol exploration (zero static bypass flags)
  action step = any {
    { nondet actor = actors.oneOf()
      nondet cut = Set(1, 2).oneOf()
      arriveEndorsement(actor, cut) },
    { nondet dom = domains.oneOf()
      prepareUnpromotedData(dom) },
    { nondet e = s40.endorsementInbox.oneOf()
      prepareEndorsedPromotion(e) },
    advanceSourceCut,
    exposeCriticalThreat,
    mitigateCriticalThreat,
    acceptResidualAtCurrentCut,
    revokeGrant,
    consumeHandoffFence,
    admitKvPrefixReuse,
    s40' = s40
  }

  // Temporal safety invariants over concurrent interleavings
  val noUnendorsedOrStaleEscalation =
    not(s40.consumedHandoff.present) or
      s40.consumedHandoff.effectiveRank <= s40.consumedHandoff.originRank or
      validEndorsementAt(s40.consumedHandoff, s40.sourceCut)

  val handoffFencedAgainstThreatAndCutRaces =
    not(s40.consumedHandoff.present) or (
      s40.grantActive and
      s40.consumedHandoff.boundCut == s40.sourceCut and
      s40.consumedHandoff.grantEpoch == s40.grantEpoch and
      s40.threatPhase != "exposed" and
      (s40.threatPhase != "accepted" or s40.residualCut == s40.sourceCut)
    )

  val kvReuseFencedAgainstRevocation =
    not(s40.kvReuseAdmitted) or (
      s40.grantActive and
      s40.prepared.domain == s40.kvCachedDomain and
      s40.prepared.boundCut == s40.sourceCut and
      s40.kvCachedCut == s40.sourceCut
    )

  val safety = and {
    noUnendorsedOrStaleEscalation,
    handoffFencedAgainstThreatAndCutRaces,
    kvReuseFencedAgainstRevocation
  }

  // Standalone fault-injection actions (outside `step`) to verify invariant sensitivity
  action buggyConsumeWithoutRecheckingCutOrThreat: bool = all {
    s40.prepared.present,
    s40' = { ...s40, consumedHandoff: s40.prepared }
  }

  action buggyPrepareSelfEndorsed(e: Endorsement): bool = all {
    s40.endorsementInbox.contains(e),
    s40' = {
      ...s40,
      prepared: {
        present: true,
        proposer: e.proposer,
        boundCut: s40.sourceCut,
        grantEpoch: s40.grantEpoch,
        originRank: 0,
        effectiveRank: e.targetRank,
        endorser: e.endorser,
        endorsementCut: e.boundCut,
        domain: "tenantA:restricted"
      }
    }
  }

  run endorsedHandoffAndCutAdvanceRaceSafeTest =
    init
      .then(arriveEndorsement("reviewer-1", 1))
      .then(prepareEndorsedPromotion({ proposer: "agent-1", endorser: "reviewer-1", boundCut: 1, targetRank: 3 }))
      .then(consumeHandoffFence)
      .expect(s40.consumedHandoff.present and safety)
      .then(advanceSourceCut)
      .expect(not(s40.consumedHandoff.present) and safety)

  run residualThreatInvalidatedByCutRaceSafeTest =
    init
      .then(prepareUnpromotedData("tenantA:restricted"))
      .then(exposeCriticalThreat)
      .then(acceptResidualAtCurrentCut)
      .then(consumeHandoffFence)
      .expect(s40.consumedHandoff.present and safety)
      .then(advanceSourceCut)
      .expect(not(s40.consumedHandoff.present) and safety)

  run stalePreparedConsumedAfterCutAdvanceCounterexampleTest =
    init
      .then(arriveEndorsement("reviewer-1", 1))
      .then(prepareEndorsedPromotion({ proposer: "agent-1", endorser: "reviewer-1", boundCut: 1, targetRank: 3 }))
      .then(advanceSourceCut)
      .then(buggyConsumeWithoutRecheckingCutOrThreat)
      .expect(not(noUnendorsedOrStaleEscalation) and not(handoffFencedAgainstThreatAndCutRaces))

  run concurrentThreatExposureRaceCounterexampleTest =
    init
      .then(prepareUnpromotedData("tenantA:restricted"))
      .then(exposeCriticalThreat)
      .then(buggyConsumeWithoutRecheckingCutOrThreat)
      .expect(not(handoffFencedAgainstThreatAndCutRaces))

  run selfEndorsementRaceCounterexampleTest =
    init
      .then(arriveEndorsement("agent-1", 1))
      .then(buggyPrepareSelfEndorsed({ proposer: "agent-1", endorser: "agent-1", boundCut: 1, targetRank: 3 }))
      .then(buggyConsumeWithoutRecheckingCutOrThreat)
      .expect(not(noUnendorsedOrStaleEscalation))
}
