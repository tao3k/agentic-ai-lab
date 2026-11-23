// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

// Slice 47 — Master Composed Quint Interleaving Chain (`40..46, 48 -> 47`):
// Imports ALL EIGHT upstream Quint state machines (`s40`..`s46`, `s48`) directly
// so `assembleAuditCapsule`, `consumeHostCasFence`, and `runColdForensicReplayAtCut1`
// synchronize and race against every upstream concurrent plane.
module EndToEndContextGovernanceClosure {
  import ContextGovernanceBoundary as s40 from "./40-context-governance-boundary"
  import ContextEpistemicConsolidationGovernance as s41 from "./41-epistemic-consolidation-governance"
  import MultiRepoAgentDeclassification as s42 from "./42-multi-repo-multi-agent-declassification"
  import AscentSecurityBranchOmissionRefinement as s43 from "./43-ascent-security-branch-omission-refinement"
  import TemporalCausalSurvivalMemoryQuotient as s44 from "./44-temporal-causal-survival-and-memory-quotient"
  import OrgSexprGqlCandidateExchange as s45 from "./45-org-sexpr-gql-candidate-exchange-search"
  import DurableAgendaSessionSandbox as s46 from "./46-durable-agenda-session-sandbox-governance"
  import ProgressiveDisclosureAndOrgRepair as s48 from "./48-progressive-disclosure-and-two-stage-org-repair"

  type CapsuleState = {
    hotCapsulePresent: bool,
    hotCapsuleCut: int,
    hotCapsuleRepoCoreCut: int,
    hotCapsuleGen: int,
    archivedCut1Capsule: bool,
    cedarHostGrantLive: bool,
    hostCasConsumed: bool,
    planesWereLiveAtCas: bool,
    coldReplayVerifiedAtCut1: bool
  }

  var c: CapsuleState

  action keep40 = s40::s40' = s40::s40
  action keep41 = s41::s41' = s41::s41
  action keep42 = s42::s42' = s42::s42
  action keep43 = s43::s43' = s43::s43
  action keep44 = s44::s44' = s44::s44
  action keep45 = s45::s45' = s45::s45
  action keep46 = s46::s46' = s46::s46
  action keep48 = s48::s48' = s48::s48
  action keepC = c' = c

  pure def allUpstreamPlanesReady(
    st40: s40::State,
    st41: s41::State,
    st42: s42::State,
    st43: s43::State,
    st44: s44::State,
    st45: s45::State,
    st46: s46::State,
    st48: s48::State
  ): bool =
    st45.published and
    st45.publishedAtGen == st45.temporalGen and
    st44.activeCitedGem and
    st44.liveStatus.get("E-cited") == "active" and
    st41.session2GrantLive and
    st42.dualBindingsVerified and
    not(st43.omissionReceiptActive) and
    st48.stageOneSyntaxHealthy and
    (not(st48.activeDefeaterPresent) or (st48.consumedPresent and st48.consumedDepth == 3)) and
    st40.consumedHandoff.present and
    st40.consumedHandoff.boundCut == st40.sourceCut and
    st40.threatPhase != "exposed" and
    st46.grantLive and
    st46.activeAttempt.outcome != "unknown"

  action init: bool = all {
    s40::init,
    s41::init,
    s42::init,
    s43::init,
    s44::init,
    s45::init,
    s46::init,
    s48::init,
    c' = {
      hotCapsulePresent: false,
      hotCapsuleCut: 0,
      hotCapsuleRepoCoreCut: 0,
      hotCapsuleGen: 0,
      archivedCut1Capsule: false,
      cedarHostGrantLive: true,
      hostCasConsumed: false,
      planesWereLiveAtCas: true,
      coldReplayVerifiedAtCut1: false
    }
  }

  // Upstream asynchronous transitions across all 8 planes racing against Host CAS
  action stepGov40 = all { s40::step, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keepC }
  action stepEpistemic41 = all { s41::step, keep40, keep42, keep43, keep44, keep45, keep46, keep48, keepC }
  action stepDeclassify42 = all { s42::step, keep40, keep41, keep43, keep44, keep45, keep46, keep48, keepC }
  action stepBranch43 = all { s43::step, keep40, keep41, keep42, keep44, keep45, keep46, keep48, keepC }
  action stepSurvival44 = all { s44::step, keep40, keep41, keep42, keep43, keep45, keep46, keep48, keepC }
  action stepSearch45 = all { s45::step, keep40, keep41, keep42, keep43, keep44, keep46, keep48, keepC }
  action stepSandbox46 = all { s46::step, keep40, keep41, keep42, keep43, keep44, keep45, keep48, keepC }
  action stepDisclosure48 = all { s48::step, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keepC }

  action assembleAuditCapsule: bool = all {
    allUpstreamPlanesReady(s40::s40, s41::s41, s42::s42, s43::s43, s44::s44, s45::s45, s46::s46, s48::s48),
    keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48,
    c' = {
      ...c,
      hotCapsulePresent: true,
      hotCapsuleCut: s40::s40.sourceCut,
      hotCapsuleRepoCoreCut: s42::s42.repoCoreCut,
      hotCapsuleGen: s45::s45.temporalGen,
      archivedCut1Capsule: c.archivedCut1Capsule or (s40::s40.sourceCut == 1)
    }
  }

  action revokeCedarGrant: bool = all {
    keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48,
    c' = { ...c, cedarHostGrantLive: false }
  }

  action consumeHostCasFence: bool = {
    val liveNow =
      c.hotCapsulePresent and
      c.cedarHostGrantLive and
      c.hotCapsuleCut == s40::s40.sourceCut and
      c.hotCapsuleRepoCoreCut == s42::s42.repoCoreCut and
      c.hotCapsuleGen == s45::s45.temporalGen and
      allUpstreamPlanesReady(s40::s40, s41::s41, s42::s42, s43::s43, s44::s44, s45::s45, s46::s46, s48::s48)
    all {
      liveNow,
      not(c.hostCasConsumed),
      keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48,
      c' = {
        ...c,
        hostCasConsumed: true,
        planesWereLiveAtCas: liveNow
      }
    }
  }

  action runColdForensicReplayAtCut1: bool = all {
    c.archivedCut1Capsule,
    keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48,
    c' = { ...c, coldReplayVerifiedAtCut1: true }
  }

  action step = any {
    stepGov40,
    stepEpistemic41,
    stepDeclassify42,
    stepBranch43,
    stepSurvival44,
    stepSearch45,
    stepSandbox46,
    stepDisclosure48,
    assembleAuditCapsule,
    revokeCedarGrant,
    consumeHostCasFence,
    runColdForensicReplayAtCut1,
    all { keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keepC }
  }

  // Master composed temporal safety invariants across all 9 slices
  val hostCasRequiresCurrentCapsuleAndLiveUpstreamPlanes =
    not(c.hostCasConsumed) or c.planesWereLiveAtCas

  val coldAuditReplayPreservedWithoutReopeningStaleLiveHandoff =
    not(c.coldReplayVerifiedAtCut1) or c.archivedCut1Capsule

  val allEightUpstreamSliceInvariantsHold = and {
    s40::safety,
    s41::safety,
    s42::safety,
    s43::safety,
    s44::safety,
    s45::safety,
    s46::safety,
    s48::safety
  }

  val safety = and {
    hostCasRequiresCurrentCapsuleAndLiveUpstreamPlanes,
    coldAuditReplayPreservedWithoutReopeningStaleLiveHandoff,
    allEightUpstreamSliceInvariantsHold
  }

  // Standalone fault-injection action (outside `step`) for cross-plane drift counterexample
  action buggyConsumeStaleCapsuleIgnoringUpstreamDrift: bool = all {
    c.hotCapsulePresent,
    keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48,
    c' = {
      ...c,
      hostCasConsumed: true,
      planesWereLiveAtCas:
        c.cedarHostGrantLive and
        c.hotCapsuleCut == s40::s40.sourceCut and
        c.hotCapsuleRepoCoreCut == s42::s42.repoCoreCut and
        c.hotCapsuleGen == s45::s45.temporalGen and
        allUpstreamPlanesReady(s40::s40, s41::s41, s42::s42, s43::s43, s44::s44, s45::s45, s46::s46, s48::s48)
    }
  }

  run endToEndEightPlaneAssembleDriftAndColdReplaySafeTest =
    init
      .then(all { s45::submitProviderReceipt("gql", 1, true), keep40, keep41, keep42, keep43, keep44, keep46, keep48, keepC })
      .then(all { s45::submitProviderReceipt("ascent", 1, true), keep40, keep41, keep42, keep43, keep44, keep46, keep48, keepC })
      .then(all { s45::publishCandidateExchange, keep40, keep41, keep42, keep43, keep44, keep46, keep48, keepC })
      .then(all { s44::admitCitedQuotientGem, keep40, keep41, keep42, keep43, keep45, keep46, keep48, keepC })
      .then(all { s40::prepareUnpromotedData("tenantA:restricted"), keep41, keep42, keep43, keep44, keep45, keep46, keep48, keepC })
      .then(all { s40::consumeHandoffFence, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keepC })
      .then(assembleAuditCapsule)
      .expect(c.hotCapsulePresent and c.archivedCut1Capsule and safety)
      // Upstream Slice 48 receives an active defeater AND Slice 42 advances Repo-Core cut!
      .then(all { s48::arriveActiveDefeater, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keepC })
      .then(all { s42::advanceRepoCoreCut, keep40, keep41, keep43, keep44, keep45, keep46, keep48, keepC })
      // Cold audit replay at cut 1 succeeds while live CAS stays blocked!
      .then(runColdForensicReplayAtCut1)
      .expect(c.coldReplayVerifiedAtCut1 and not(c.hostCasConsumed) and safety)

  run crossPlaneDriftAgainstCachedCapsuleCounterexampleTest =
    init
      .then(all { s45::submitProviderReceipt("gql", 1, true), keep40, keep41, keep42, keep43, keep44, keep46, keep48, keepC })
      .then(all { s45::submitProviderReceipt("ascent", 1, true), keep40, keep41, keep42, keep43, keep44, keep46, keep48, keepC })
      .then(all { s45::publishCandidateExchange, keep40, keep41, keep42, keep43, keep44, keep46, keep48, keepC })
      .then(all { s44::admitCitedQuotientGem, keep40, keep41, keep42, keep43, keep45, keep46, keep48, keepC })
      .then(all { s40::prepareUnpromotedData("tenantA:restricted"), keep41, keep42, keep43, keep44, keep45, keep46, keep48, keepC })
      .then(all { s40::consumeHandoffFence, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keepC })
      .then(assembleAuditCapsule)
      .then(all { s48::arriveActiveDefeater, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keepC })
      .then(buggyConsumeStaleCapsuleIgnoringUpstreamDrift)
      .expect(not(hostCasRequiresCurrentCapsuleAndLiveUpstreamPlanes))
}
