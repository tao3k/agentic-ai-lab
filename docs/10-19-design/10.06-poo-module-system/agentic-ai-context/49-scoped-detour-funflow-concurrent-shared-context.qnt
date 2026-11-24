// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

// Slice 49 — Quint Nondeterministic Concurrent Interleaving Model ONLY:
// Per FormalVerificationTaxonomy in
// 49-scoped-detour-funflow-concurrent-shared-context.sysml,
// unbounded algebraic/structural laws live in 49-*.lean; this module explores
// nondeterministic concurrent races among Humans and peer Agents operating on
// ONE Shared Org Context (Zero SubAgent silos):
// 1. Per-`:ID:` `:OWNER_ACTOR:` / `:CLAIM_LEASE_EPOCH:` ownership claims vs
//    disjoint child extensions (Extend-Never-Overwrite) and custody handovers.
// 2. Scoped Detours (blocker / side-quest) completing, parking to GitOps custody,
//    or cancelling while preserving Counterexample Core defeaters.
// 3. Premise-cut advances invalidating stale CAS nodes and racing against
//    asymmetric `FencedEffect` admission (`claimsExhaustive` + token + endorsement)
//    and atomic Auto-Archive.
module ScopedDetourFunflowConcurrentContext {
  type State = {
    nodeOwner: str,                // "" | "human" | "agentA" | "agentB"
    claimEpoch: int,
    policyClock: int,
    heartbeatAt: int,
    leaseTtl: int,
    staleEpochWriteBlocked: bool,
    overwrittenByNonOwner: bool,
    peerExtensionCount: int,
    custodySnapshots: int,
    blockerDetourActive: bool,
    sideQuestActive: bool,
    mainlineInvariantsMet: bool,
    discoveredDefeaters: int,
    defeatersRetained: int,
    premiseCut: int,
    preparedEffectCut: int,
    claimsExhaustive: bool,
    hasAuthorizedToken: bool,
    hasEndorsement: bool,
    fencedEffectCommitted: bool,
    fencedEffectWasSafe: bool,
    archived: bool,
    archivedWhileUnsafe: bool
  }

  var s49: State

  action init: bool =
    s49' = {
      nodeOwner: "",
      claimEpoch: 0,
      policyClock: 0,
      heartbeatAt: 0,
      leaseTtl: 2,
      staleEpochWriteBlocked: true,
      overwrittenByNonOwner: false,
      peerExtensionCount: 0,
      custodySnapshots: 0,
      blockerDetourActive: false,
      sideQuestActive: false,
      mainlineInvariantsMet: false,
      discoveredDefeaters: 0,
      defeatersRetained: 0,
      premiseCut: 1,
      preparedEffectCut: 0,
      claimsExhaustive: true,
      hasAuthorizedToken: false,
      hasEndorsement: false,
      fencedEffectCommitted: false,
      fencedEffectWasSafe: true,
      archived: false,
      archivedWhileUnsafe: false
    }

  // Actor claims an unclaimed `:ID:` by recording `:OWNER_ACTOR:` in Shared Org `:PROPERTIES:`.
  action claimNode(actor: str): bool = all {
    Set("human", "agentA", "agentB").contains(actor),
    s49.nodeOwner == "",
    not(s49.archived),
    s49.claimEpoch < 3,
    s49' = {
      ...s49,
      nodeOwner: actor,
      claimEpoch: s49.claimEpoch + 1,
      heartbeatAt: s49.policyClock
    }
  }

  action tickPolicyClock: bool = all {
    s49.policyClock < 6,
    not(s49.archived),
    s49' = { ...s49, policyClock: s49.policyClock + 1 }
  }

  action refreshHeartbeat: bool = all {
    s49.nodeOwner != "",
    not(s49.archived),
    s49' = { ...s49, heartbeatAt: s49.policyClock }
  }

  // Heartbeat-expiry fenced takeover: only allowed when policyClock >= heartbeatAt + leaseTtl.
  action expiredLeaseCustodyTakeover(nextActor: str): bool = all {
    Set("human", "agentA", "agentB").contains(nextActor),
    s49.nodeOwner != "",
    nextActor != s49.nodeOwner,
    not(s49.archived),
    s49.claimEpoch < 3,
    s49.policyClock >= s49.heartbeatAt + s49.leaseTtl,
    s49' = {
      ...s49,
      nodeOwner: nextActor,
      claimEpoch: s49.claimEpoch + 1,
      heartbeatAt: s49.policyClock,
      custodySnapshots: s49.custodySnapshots + 1,
      hasAuthorizedToken: false
    }
  }

  // Peer actor perceives `:OWNER_ACTOR:` in Shared Context and EXTENDS via disjoint `:ID:` child.
  action extendByPeer(peer: str): bool = all {
    Set("human", "agentA", "agentB").contains(peer),
    s49.nodeOwner != "",
    peer != s49.nodeOwner,
    not(s49.archived),
    s49.peerExtensionCount < 3,
    s49' = {
      ...s49,
      peerExtensionCount: s49.peerExtensionCount + 1
    }
  }

  // Explicit fenced handover increments `:CLAIM_LEASE_EPOCH:` and snapshots dirty work to custody.
  action handoverWithCustody(nextActor: str): bool = all {
    Set("human", "agentA", "agentB").contains(nextActor),
    s49.nodeOwner != "",
    nextActor != s49.nodeOwner,
    not(s49.archived),
    s49.claimEpoch < 3,
    s49' = {
      ...s49,
      nodeOwner: nextActor,
      claimEpoch: s49.claimEpoch + 1,
      custodySnapshots: s49.custodySnapshots + 1,
      hasAuthorizedToken: false
    }
  }

  action spawnBlockerDetour: bool = all {
    not(s49.blockerDetourActive),
    not(s49.archived),
    s49' = {
      ...s49,
      blockerDetourActive: true,
      claimsExhaustive: false
    }
  }

  action completeBlockerDetourAndReanchor: bool = all {
    s49.blockerDetourActive,
    s49' = {
      ...s49,
      blockerDetourActive: false,
      claimsExhaustive: true,
      mainlineInvariantsMet: true
    }
  }

  // Parking a detour snapshots dirty work into GitOps custody and leaves mainline clean.
  action parkSideQuestToCustody: bool = all {
    s49.sideQuestActive,
    s49' = {
      ...s49,
      sideQuestActive: false,
      custodySnapshots: s49.custodySnapshots + 1
    }
  }

  action spawnSideQuest: bool = all {
    not(s49.sideQuestActive),
    not(s49.archived),
    s49' = { ...s49, sideQuestActive: true }
  }

  // Cancelling a dead-end detour MUST preserve newly discovered defeat-conditions in Counterexample Core.
  action cancelBlockerDetourPreserveDefeaters: bool = all {
    s49.blockerDetourActive,
    s49.discoveredDefeaters < 2,
    s49' = {
      ...s49,
      blockerDetourActive: false,
      discoveredDefeaters: s49.discoveredDefeaters + 1,
      defeatersRetained: s49.defeatersRetained + 1,
      claimsExhaustive: true
    }
  }

  action advancePremiseCut: bool = all {
    s49.premiseCut < 2,
    not(s49.archived),
    s49' = {
      ...s49,
      premiseCut: s49.premiseCut + 1,
      hasEndorsement: false,
      hasAuthorizedToken: false
    }
  }

  action prepareVerifiedEffect: bool = all {
    not(s49.archived),
    s49' = {
      ...s49,
      preparedEffectCut: s49.premiseCut,
      hasEndorsement: true,
      hasAuthorizedToken: true
    }
  }

  // FencedEffect commits ONLY when claimsExhaustive, token, endorsement, and live premiseCut all hold.
  action commitFencedEffectFence: bool = all {
    not(s49.fencedEffectCommitted),
    not(s49.archived),
    s49.claimsExhaustive,
    s49.hasAuthorizedToken,
    s49.hasEndorsement,
    s49.preparedEffectCut == s49.premiseCut,
    s49' = {
      ...s49,
      fencedEffectCommitted: true,
      fencedEffectWasSafe:
        s49.claimsExhaustive and s49.hasAuthorizedToken and s49.hasEndorsement
        and s49.preparedEffectCut == s49.premiseCut,
      hasAuthorizedToken: false
    }
  }

  // Atomic Auto-Archive requires zero open blocker detours and all mainline invariants satisfied.
  action commitAutoArchiveFence: bool = all {
    not(s49.archived),
    not(s49.blockerDetourActive),
    s49.mainlineInvariantsMet,
    s49' = {
      ...s49,
      archived: true,
      archivedWhileUnsafe: s49.blockerDetourActive or not(s49.mainlineInvariantsMet)
    }
  }

  action step = any {
    { nondet a = Set("human", "agentA", "agentB").oneOf()
      claimNode(a) },
    { nondet p = Set("human", "agentA", "agentB").oneOf()
      extendByPeer(p) },
    { nondet n = Set("human", "agentA", "agentB").oneOf()
      handoverWithCustody(n) },
    tickPolicyClock,
    refreshHeartbeat,
    { nondet t = Set("human", "agentA", "agentB").oneOf()
      expiredLeaseCustodyTakeover(t) },
    spawnBlockerDetour,
    completeBlockerDetourAndReanchor,
    spawnSideQuest,
    parkSideQuestToCustody,
    cancelBlockerDetourPreserveDefeaters,
    advancePremiseCut,
    prepareVerifiedEffect,
    commitFencedEffectFence,
    commitAutoArchiveFence,
    s49' = s49
  }

  // Temporal safety invariants
  val noNonOwnerOverwrite = not(s49.overwrittenByNonOwner)

  val fencedEffectRequiresExhaustiveAndValidPremise =
    not(s49.fencedEffectCommitted) or s49.fencedEffectWasSafe

  val autoArchiveRequiresNoBlockerAndAllInvariants =
    not(s49.archived) or not(s49.archivedWhileUnsafe)

  val cancelledDetourNeverDropsDefeaters =
    s49.defeatersRetained >= s49.discoveredDefeaters

  val safety = and {
    noNonOwnerOverwrite,
    fencedEffectRequiresExhaustiveAndValidPremise,
    autoArchiveRequiresNoBlockerAndAllInvariants,
    cancelledDetourNeverDropsDefeaters
  }

  // Standalone fault-injection actions (outside `step`) for negative-control verification
  action buggyNonOwnerOverwrite(peer: str): bool = all {
    s49.nodeOwner != "",
    peer != s49.nodeOwner,
    s49' = { ...s49, overwrittenByNonOwner: true }
  }

  action buggyFencedEffectIgnoringExhaustiveness: bool = all {
    not(s49.claimsExhaustive),
    s49' = {
      ...s49,
      fencedEffectCommitted: true,
      fencedEffectWasSafe: false
    }
  }

  action buggyArchiveWithOpenBlockerDetour: bool = all {
    s49.blockerDetourActive,
    s49' = {
      ...s49,
      archived: true,
      archivedWhileUnsafe: true
    }
  }

  run peerExtendDetourReanchorSafeTest =
    init
      .then(claimNode("agentA"))
      .then(extendByPeer("human"))
      .then(spawnBlockerDetour)
      .then(cancelBlockerDetourPreserveDefeaters)
      .then(spawnBlockerDetour)
      .then(completeBlockerDetourAndReanchor)
      .then(prepareVerifiedEffect)
      .then(commitFencedEffectFence)
      .then(commitAutoArchiveFence)
      .expect(s49.archived and s49.peerExtensionCount == 1 and s49.defeatersRetained == 1 and safety)

  run buggyNonOwnerOverwriteCounterexampleTest =
    init
      .then(claimNode("agentA"))
      .then(buggyNonOwnerOverwrite("agentB"))
      .expect(not(noNonOwnerOverwrite))

  run buggyFencedEffectWithoutExhaustiveCounterexampleTest =
    init
      .then(claimNode("agentA"))
      .then(spawnBlockerDetour)
      .then(buggyFencedEffectIgnoringExhaustiveness)
      .expect(not(fencedEffectRequiresExhaustiveAndValidPremise))

  run heartbeatExpiryTakeoverSafeTest =
    init
      .then(claimNode("agentA"))
      .then(tickPolicyClock)
      .then(tickPolicyClock)
      .then(expiredLeaseCustodyTakeover("agentB"))
      .expect(s49.nodeOwner == "agentB" and s49.claimEpoch == 2 and s49.custodySnapshots == 1 and safety)

  run buggyArchiveWithOpenBlockerCounterexampleTest =
    init
      .then(claimNode("agentA"))
      .then(spawnBlockerDetour)
      .then(buggyArchiveWithOpenBlockerDetour)
      .expect(not(autoArchiveRequiresNoBlockerAndAllInvariants))
}
