// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

// Slice 47 — Master Composed Quint Interleaving Chain (`40..46, 48..53 -> 47`):
// Imports ALL THIRTEEN upstream Quint state machines (`s40`..`s46`, `s48`..`s53`)
// directly so `assembleAuditCapsule`, `consumeHostCasFence`, and
// `runColdForensicReplayAtCut1` synchronize and race against every upstream
// concurrent plane.
module EndToEndContextGovernanceClosure {
  import ContextGovernanceBoundary as s40 from "./40-context-governance-boundary"
  import ContextEpistemicConsolidationGovernance as s41 from "./41-epistemic-consolidation-governance"
  import MultiRepoAgentDeclassification as s42 from "./42-multi-repo-multi-agent-declassification"
  import AscentSecurityBranchOmissionRefinement as s43 from "./43-ascent-security-branch-omission-refinement"
  import TemporalCausalSurvivalMemoryQuotient as s44 from "./44-temporal-causal-survival-and-memory-quotient"
  import OrgSexprGqlCandidateExchange as s45 from "./45-org-sexpr-gql-candidate-exchange-search"
  import DurableAgendaSessionSandbox as s46 from "./46-durable-agenda-session-sandbox-governance"
  import ProgressiveDisclosureAndOrgRepair as s48 from "./48-progressive-disclosure-and-two-stage-org-repair"
  import ScopedDetourFunflowConcurrentContext as s49 from "./49-scoped-detour-funflow-concurrent-shared-context"
  import DetourTaintConfinementAndCausalAudit as s50 from "./50-literature-frontier-detour-confinement-and-causal-audit"
  import MemoryQuarantineAndKvPrefixSerialization as s51 from "./51-memory-poisoning-quarantine-and-kv-prefix-serialization"
  import FunflowCasSingleflightAndExternalSandbox as s52 from "./52-funflow-cas-singleflight-and-external-sandbox-binding"
  import YuanxuC4ProfileConvergence as s53 from "./53-yuanxu-c4-profile-convergence-and-interface-slots"

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
  action keep49 = s49::s49' = s49::s49
  action keep50 = s50::s50' = s50::s50
  action keep51 = s51::s51' = s51::s51
  action keep52 = s52::s52' = s52::s52
  action keep53 = s53::s53' = s53::s53
  action keepC = c' = c

  pure def allUpstreamPlanesReady(
    st40: s40::State,
    st41: s41::State,
    st42: s42::State,
    st43: s43::State,
    st44: s44::State,
    st45: s45::State,
    st46: s46::State,
    st48: s48::State,
    st49: s49::State,
    st50: s50::State,
    st51: s51::State,
    st52: s52::State,
    st53: s53::State
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
    not(st49.overwrittenByNonOwner) and
    not(st49.blockerDetourActive) and
    not(st50.mainlineTainted) and
    not(st50.unattestedMergeOccurred) and
    not(st51.recallableContainsPoison) and
    not(st51.kvPrefixFractured) and
    not(st52.corruptCasVisible) and
    not(st52.pinnedEntryEvictedByGc) and
    not(st52.archivedWithDroppedFinalizer) and
    not(st53.undeclaredModulePulled) and
    not(st53.silentPeerOverwrite) and
    not(st53.runtimeExpandedCompile) and
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
    s49::init,
    s50::init,
    s51::init,
    s52::init,
    s53::init,
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

  // Upstream asynchronous transitions across all 13 planes racing against Host CAS
  action stepGov40 = all { s40::step, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC }
  action stepEpistemic41 = all { s41::step, keep40, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC }
  action stepDeclassify42 = all { s42::step, keep40, keep41, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC }
  action stepBranch43 = all { s43::step, keep40, keep41, keep42, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC }
  action stepSurvival44 = all { s44::step, keep40, keep41, keep42, keep43, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC }
  action stepSearch45 = all { s45::step, keep40, keep41, keep42, keep43, keep44, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC }
  action stepSandbox46 = all { s46::step, keep40, keep41, keep42, keep43, keep44, keep45, keep48, keep49, keep50, keep51, keep52, keep53, keepC }
  action stepDisclosure48 = all { s48::step, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep49, keep50, keep51, keep52, keep53, keepC }
  action stepConcurrent49 = all { s49::step, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep50, keep51, keep52, keep53, keepC }
  action stepAbsorption50 = all { s50::step, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep51, keep52, keep53, keepC }
  action stepMemoryKv51 = all { s51::step, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep52, keep53, keepC }
  action stepFunflowCas52 = all { s52::step, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep53, keepC }
  action stepC4Convergence53 = all { s53::step, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keepC }

  action assembleAuditCapsule: bool = all {
    allUpstreamPlanesReady(s40::s40, s41::s41, s42::s42, s43::s43, s44::s44, s45::s45, s46::s46, s48::s48, s49::s49, s50::s50, s51::s51, s52::s52, s53::s53),
    keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keep53,
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
    keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keep53,
    c' = { ...c, cedarHostGrantLive: false }
  }

  action consumeHostCasFence: bool = {
    val liveNow =
      c.hotCapsulePresent and
      c.cedarHostGrantLive and
      c.hotCapsuleCut == s40::s40.sourceCut and
      c.hotCapsuleRepoCoreCut == s42::s42.repoCoreCut and
      c.hotCapsuleGen == s45::s45.temporalGen and
      allUpstreamPlanesReady(s40::s40, s41::s41, s42::s42, s43::s43, s44::s44, s45::s45, s46::s46, s48::s48, s49::s49, s50::s50, s51::s51, s52::s52, s53::s53)
    all {
      liveNow,
      not(c.hostCasConsumed),
      keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keep53,
      c' = {
        ...c,
        hostCasConsumed: true,
        planesWereLiveAtCas: liveNow
      }
    }
  }

  action runColdForensicReplayAtCut1: bool = all {
    c.archivedCut1Capsule,
    keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keep53,
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
    stepConcurrent49,
    stepAbsorption50,
    stepMemoryKv51,
    stepFunflowCas52,
    stepC4Convergence53,
    assembleAuditCapsule,
    revokeCedarGrant,
    consumeHostCasFence,
    runColdForensicReplayAtCut1,
    all { keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC }
  }

  // Master composed temporal safety invariants across all 14 slices
  val hostCasRequiresCurrentCapsuleAndLiveUpstreamPlanes =
    not(c.hostCasConsumed) or c.planesWereLiveAtCas

  val coldAuditReplayPreservedWithoutReopeningStaleLiveHandoff =
    not(c.coldReplayVerifiedAtCut1) or c.archivedCut1Capsule

  val allThirteenUpstreamSliceInvariantsHold = and {
    s40::safety,
    s41::safety,
    s42::safety,
    s43::safety,
    s44::safety,
    s45::safety,
    s46::safety,
    s48::safety,
    s49::safety,
    s50::safety,
    s51::safety,
    s52::safety,
    s53::safety
  }

  val safety = and {
    hostCasRequiresCurrentCapsuleAndLiveUpstreamPlanes,
    coldAuditReplayPreservedWithoutReopeningStaleLiveHandoff,
    allThirteenUpstreamSliceInvariantsHold
  }

  // Standalone fault-injection action (outside `step`) for cross-plane drift counterexample
  action buggyConsumeStaleCapsuleIgnoringUpstreamDrift: bool = all {
    c.hotCapsulePresent,
    keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keep53,
    c' = {
      ...c,
      hostCasConsumed: true,
      planesWereLiveAtCas:
        c.cedarHostGrantLive and
        c.hotCapsuleCut == s40::s40.sourceCut and
        c.hotCapsuleRepoCoreCut == s42::s42.repoCoreCut and
        c.hotCapsuleGen == s45::s45.temporalGen and
        allUpstreamPlanesReady(s40::s40, s41::s41, s42::s42, s43::s43, s44::s44, s45::s45, s46::s46, s48::s48, s49::s49, s50::s50, s51::s51, s52::s52, s53::s53)
    }
  }

  run endToEndThirteenPlaneAssembleDriftAndColdReplaySafeTest =
    init
      .then(all { s45::submitProviderReceipt("gql", 1, true), keep40, keep41, keep42, keep43, keep44, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC })
      .then(all { s45::submitProviderReceipt("ascent", 1, true), keep40, keep41, keep42, keep43, keep44, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC })
      .then(all { s45::publishCandidateExchange, keep40, keep41, keep42, keep43, keep44, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC })
      .then(all { s44::admitCitedQuotientGem, keep40, keep41, keep42, keep43, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC })
      .then(all { s40::prepareUnpromotedData("tenantA:restricted"), keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC })
      .then(all { s40::consumeHandoffFence, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC })
      .then(all { s52::agentAAcquireSingleflight, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep53, keepC })
      .then(all { s52::stageTempArtifact, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep53, keepC })
      .then(all { s52::atomicRenamePublish, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep53, keepC })
      .then(all { s52::pinPublishedEntryToCapsule, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep53, keepC })
      .then(all { s53::admitDurableModule, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keepC })
      .then(assembleAuditCapsule)
      .expect(c.hotCapsulePresent and c.archivedCut1Capsule and safety)
      // Upstream Slice 49 opens a blocker detour, Slice 51 quarantines poison, Slice 52 runs GC, Slice 53 enters runtime detour overlay!
      .then(all { s49::spawnBlockerDetour, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep50, keep51, keep52, keep53, keepC })
      .then(all { s51::ingestPoisonedUntrustedCandidate, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep52, keep53, keepC })
      .then(all { s52::runCasGcSweep, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep53, keepC })
      .then(all { s53::enterRuntimeDetourOverlay, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keepC })
      // Cold audit replay at cut 1 succeeds (pinned CAS survived GC!) while live CAS stays blocked!
      .then(runColdForensicReplayAtCut1)
      .expect(c.coldReplayVerifiedAtCut1 and s52::s52.casPublished and not(c.hostCasConsumed) and safety)

  run crossPlaneDriftAgainstCachedCapsuleCounterexampleTest =
    init
      .then(all { s45::submitProviderReceipt("gql", 1, true), keep40, keep41, keep42, keep43, keep44, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC })
      .then(all { s45::submitProviderReceipt("ascent", 1, true), keep40, keep41, keep42, keep43, keep44, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC })
      .then(all { s45::publishCandidateExchange, keep40, keep41, keep42, keep43, keep44, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC })
      .then(all { s44::admitCitedQuotientGem, keep40, keep41, keep42, keep43, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC })
      .then(all { s40::prepareUnpromotedData("tenantA:restricted"), keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC })
      .then(all { s40::consumeHandoffFence, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep49, keep50, keep51, keep52, keep53, keepC })
      .then(assembleAuditCapsule)
      .then(all { s49::spawnBlockerDetour, keep40, keep41, keep42, keep43, keep44, keep45, keep46, keep48, keep50, keep51, keep52, keep53, keepC })
      .then(buggyConsumeStaleCapsuleIgnoringUpstreamDrift)
      .expect(not(hostCasRequiresCurrentCapsuleAndLiveUpstreamPlanes))
}
