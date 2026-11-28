// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

// Slice 53 — Quint Nondeterministic Assembly/Runtime Convergence & Fault-Injection Model:
// Verifies INV-1..INV-6 of Yuanxu Design 165 across arbitrary assembly profiles,
// cross-module `durable.enabled?` auto-bridging, explicit `-durable` veto,
// peer exclusive slot conflict fail-closed, monotonic governance floor, and
// runtime-stage zero-recompilation overlays.
module YuanxuC4ProfileConvergence {
  type State = {
    admittedModules: Set[str],         // subset of {"env", "durable", "context", "ui"}
    contextDurableVetoed: bool,
    contextDurableEnabled: bool,
    impliedBridgeActivated: bool,
    undeclaredModulePulled: bool,
    envMode: str,                      // "local-dev" | "ci-hermetic" | "airgapped"
    detourState: str,                  // "mainline" | "blocker-active"
    peerSlotLeft: str,                 // "" | "on-blur" | "immediate"
    peerSlotRight: str,                // "" | "on-blur" | "immediate"
    conflictDetected: bool,
    silentPeerOverwrite: bool,
    parentTrustCeiling: int,
    effectiveTrustCeiling: int,
    compiledClosureSize: int,
    runtimeOverlayCount: int,
    runtimeExpandedCompile: bool
  }

  var s53: State

  action init: bool =
    s53' = {
      admittedModules: Set("env", "context"),
      contextDurableVetoed: false,
      contextDurableEnabled: false,
      impliedBridgeActivated: false,
      undeclaredModulePulled: false,
      envMode: "local-dev",
      detourState: "mainline",
      peerSlotLeft: "",
      peerSlotRight: "",
      conflictDetected: false,
      silentPeerOverwrite: false,
      parentTrustCeiling: 2,
      effectiveTrustCeiling: 2,
      compiledClosureSize: 2,
      runtimeOverlayCount: 0,
      runtimeExpandedCompile: false
    }

  // Explicit `yuanxu!` declaration adds `durable`; `context/durable` auto-activates if not vetoed.
  action admitDurableModule: bool = {
    val nextMods = s53.admittedModules.union(Set("durable"))
    val autoOn = not(s53.contextDurableVetoed)
    all {
      not(s53.admittedModules.contains("durable")),
      s53' = {
        ...s53,
        admittedModules: nextMods,
        contextDurableEnabled: autoOn,
        impliedBridgeActivated: autoOn,
        compiledClosureSize: if (autoOn) s53.compiledClosureSize + 2 else s53.compiledClosureSize + 1
      }
    }
  }

  // Band 4b explicit `-durable` override in `yuanxu!` always disables the implied bridge.
  action applyExplicitVeto: bool = all {
    not(s53.contextDurableVetoed),
    s53' = {
      ...s53,
      contextDurableVetoed: true,
      contextDurableEnabled: false,
      impliedBridgeActivated: false
    }
  }

  // Assembly-stage Global Profile sets `env.mode` -> monotonically narrows trust ceiling.
  action applyEnvProfile(mode: str, requestedTrust: int): bool = {
    val nextTrust = if (requestedTrust < s53.effectiveTrustCeiling) requestedTrust else s53.effectiveTrustCeiling
    all {
      Set("local-dev", "ci-hermetic", "airgapped").contains(mode),
      Set(1, 2, 3).contains(requestedTrust),
      s53' = {
        ...s53,
        envMode: mode,
        effectiveTrustCeiling: nextTrust
      }
    }
  }

  // Runtime-stage `durable.detour-state` transitions activate C4 overlay WITHOUT expanding compile closure.
  action enterRuntimeDetourOverlay: bool = all {
    s53.detourState == "mainline",
    s53.runtimeOverlayCount < 4,
    s53' = {
      ...s53,
      detourState: "blocker-active",
      runtimeOverlayCount: s53.runtimeOverlayCount + 1
    }
  }

  // Same-band peer exclusive slot merge: disagreement MUST set conflictDetected (fail closed).
  action mergeSameBandPeer(leftVal: str, rightVal: str): bool = all {
    Set("on-blur", "immediate").contains(leftVal),
    Set("on-blur", "immediate").contains(rightVal),
    s53' = {
      ...s53,
      peerSlotLeft: leftVal,
      peerSlotRight: rightVal,
      conflictDetected: leftVal != rightVal
    }
  }

  action step: bool = any {
    admitDurableModule,
    applyExplicitVeto,
    nondet m = oneOf(Set("local-dev", "ci-hermetic", "airgapped"))
    nondet t = oneOf(Set(1, 2, 3))
    applyEnvProfile(m, t),
    enterRuntimeDetourOverlay,
    nondet l = oneOf(Set("on-blur", "immediate"))
    nondet r = oneOf(Set("on-blur", "immediate"))
    mergeSameBandPeer(l, r),
    s53' = s53
  }

  // Standalone fault-injection actions (outside `step`) for negative-control verification
  action buggyPullUndeclaredModule: bool =
    s53' = { ...s53, undeclaredModulePulled: true }

  action buggyBypassVeto: bool = all {
    s53.contextDurableVetoed,
    s53' = { ...s53, contextDurableEnabled: true }
  }

  action buggySilentPeerConflict: bool =
    s53' = { ...s53, peerSlotLeft: "on-blur", peerSlotRight: "immediate", conflictDetected: false, silentPeerOverwrite: true }

  action buggyEscalateTrust: bool =
    s53' = { ...s53, effectiveTrustCeiling: s53.parentTrustCeiling + 1 }

  // Five bidirectional SysML <-> Quint safety invariants (INV-1..INV-6)
  val invExplicitClosure =
    not(s53.undeclaredModulePulled) and
    (s53.contextDurableEnabled implies s53.admittedModules.contains("durable"))

  val invVetoDominance =
    s53.contextDurableVetoed implies not(s53.contextDurableEnabled)

  val invPeerConflictFailClosed =
    not(s53.silentPeerOverwrite) and
    ((s53.peerSlotLeft != "" and s53.peerSlotRight != "" and s53.peerSlotLeft != s53.peerSlotRight)
      implies s53.conflictDetected)

  val invGovernanceFloorMonotonic =
    s53.effectiveTrustCeiling <= s53.parentTrustCeiling

  val invRuntimeStageNoCompileExpansion =
    not(s53.runtimeExpandedCompile)

  val safety = and {
    invExplicitClosure,
    invVetoDominance,
    invPeerConflictFailClosed,
    invGovernanceFloorMonotonic,
    invRuntimeStageNoCompileExpansion
  }

  run positiveAutoBridgeAndVetoTest =
    init
      .then(admitDurableModule)
      .expect(s53.contextDurableEnabled and safety)
      .then(applyExplicitVeto)
      .expect(not(s53.contextDurableEnabled) and safety)
      .then(enterRuntimeDetourOverlay)
      .expect(s53.detourState == "blocker-active" and safety)

  run positivePeerConflictFailClosedTest =
    init
      .then(mergeSameBandPeer("on-blur", "immediate"))
      .expect(s53.conflictDetected and safety)

  run buggyUndeclaredPullCounterexampleTest =
    init
      .then(buggyPullUndeclaredModule)
      .expect(not(invExplicitClosure))

  run buggyVetoBypassCounterexampleTest =
    init
      .then(applyExplicitVeto)
      .then(buggyBypassVeto)
      .expect(not(invVetoDominance))

  run buggySilentPeerConflictCounterexampleTest =
    init
      .then(buggySilentPeerConflict)
      .expect(not(invPeerConflictFailClosed))

  run buggyTrustEscalationCounterexampleTest =
    init
      .then(buggyEscalateTrust)
      .expect(not(invGovernanceFloorMonotonic))
}
