// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
//
// Slice 55: MCP Tool Poisoning, Post-Approval Rug-Pull Manifest Pinning,
// Cross-Server Tool Shadowing Isolation, CaMeL Capability-Provenance Flow,
// and MindGuard Zero-LLM Decision-Dependence Auditing.
module McpToolPoisoningAndCamelCapabilityFlow {
  type State = {
    pinnedDigest: int,
    liveDigest: int,
    rugPullOccurred: bool,
    rugPullInvoked: bool,
    trustedOwnerServer: int,
    shadowDispatched: bool,
    argFromUntrustedOrigin: bool,
    hasDeclassCert: bool,
    sensitiveSinkAcceptedUntrusted: bool,
    metadataFlippedDecision: bool,
    offlineAuditExecuted: bool,
    decisionHijackFlagged: bool,
    safeInvocationCount: int,
  }

  var s55: State

  action init = all {
    s55' = {
      pinnedDigest: 1,
      liveDigest: 1,
      rugPullOccurred: false,
      rugPullInvoked: false,
      trustedOwnerServer: 1,
      shadowDispatched: false,
      argFromUntrustedOrigin: false,
      hasDeclassCert: false,
      sensitiveSinkAcceptedUntrusted: false,
      metadataFlippedDecision: false,
      offlineAuditExecuted: false,
      decisionHijackFlagged: false,
      safeInvocationCount: 0,
    }
  }

  // Adversarial server performs a post-approval rug-pull mutation on tool metadata
  action serverMutatesToolRugPull = all {
    not(s55.rugPullOccurred),
    s55' = { ...s55, liveDigest: 2, rugPullOccurred: true }
  }

  // Re-pin after human review (restores manifest agreement)
  action reviewAndRepinManifest = all {
    s55.rugPullOccurred,
    s55.pinnedDigest != s55.liveDigest,
    s55' = { ...s55, pinnedDigest: s55.liveDigest, rugPullOccurred: false }
  }

  // Receive an untrusted argument vs user-intent argument
  action receiveUntrustedArg = all {
    not(s55.argFromUntrustedOrigin),
    s55' = { ...s55, argFromUntrustedOrigin: true, hasDeclassCert: false }
  }

  action issueDeclassificationCert = all {
    s55.argFromUntrustedOrigin,
    not(s55.hasDeclassCert),
    s55' = { ...s55, hasDeclassCert: true }
  }

  // Guarded sensitive sink invocation: requires manifest pin match AND (trusted origin or cert)
  action invokeGuardedSensitiveSink = all {
    s55.safeInvocationCount < 2,
    s55.pinnedDigest == s55.liveDigest,
    not(s55.argFromUntrustedOrigin) or s55.hasDeclassCert,
    s55' = { ...s55, safeInvocationCount: s55.safeInvocationCount + 1 }
  }

  // MindGuard offline counterfactual decision-dependence audit
  action observeMetadataDecisionFlip = all {
    not(s55.metadataFlippedDecision),
    not(s55.offlineAuditExecuted),
    s55' = { ...s55, metadataFlippedDecision: true }
  }

  action runOfflineDecisionDependenceAudit = all {
    not(s55.offlineAuditExecuted),
    s55' = {
      ...s55,
      offlineAuditExecuted: true,
      decisionHijackFlagged: s55.metadataFlippedDecision,
    }
  }

  action step = any {
    serverMutatesToolRugPull,
    reviewAndRepinManifest,
    receiveUntrustedArg,
    issueDeclassificationCert,
    invokeGuardedSensitiveSink,
    observeMetadataDecisionFlip,
    runOfflineDecisionDependenceAudit,
  }

  // Negative-control fault injections reproducing all 4 MCP/CaMeL attacks
  action buggyInvokeAfterRugPull = all {
    s55.pinnedDigest != s55.liveDigest,
    s55' = { ...s55, rugPullInvoked: true }
  }

  action buggyShadowTrustedTool = all {
    s55.trustedOwnerServer == 1,
    s55' = { ...s55, shadowDispatched: true }
  }

  action buggyPassUntrustedArgToSink = all {
    s55.argFromUntrustedOrigin,
    not(s55.hasDeclassCert),
    s55' = { ...s55, sensitiveSinkAcceptedUntrusted: true }
  }

  action buggySkipDecisionDependenceAudit = all {
    s55.metadataFlippedDecision,
    s55' = { ...s55, offlineAuditExecuted: true, decisionHijackFlagged: false }
  }

  // Four bidirectional safety invariants mapped in SysML
  val rugPullMutatedToolNeverInvoked =
    not(s55.rugPullInvoked)

  val crossServerShadowedToolNeverDispatched =
    not(s55.shadowDispatched)

  val sensitiveSinkNeverAcceptsUntrustedOriginWithoutCert =
    not(s55.sensitiveSinkAcceptedUntrusted)

  val poisonedMetadataDecisionHijackAlwaysFlaggedOffline =
    (s55.offlineAuditExecuted and s55.metadataFlippedDecision) implies s55.decisionHijackFlagged

  val safety = and {
    rugPullMutatedToolNeverInvoked,
    crossServerShadowedToolNeverDispatched,
    sensitiveSinkNeverAcceptsUntrustedOriginWithoutCert,
    poisonedMetadataDecisionHijackAlwaysFlaggedOffline,
  }

  // Positive witnesses
  run safePinnedSinkAndAuditTest =
    init
      .then(invokeGuardedSensitiveSink)
      .then(receiveUntrustedArg)
      .then(issueDeclassificationCert)
      .then(invokeGuardedSensitiveSink)
      .then(observeMetadataDecisionFlip)
      .then(runOfflineDecisionDependenceAudit)
      .expect(safety and s55.safeInvocationCount == 2 and s55.decisionHijackFlagged)

  run safeRugPullRepinRecoveryTest =
    init
      .then(serverMutatesToolRugPull)
      .then(reviewAndRepinManifest)
      .then(invokeGuardedSensitiveSink)
      .expect(safety and s55.safeInvocationCount == 1)

  // Negative-control counterexamples (ITF replay witnesses)
  run rugPullInvocationCounterexampleTest =
    init
      .then(serverMutatesToolRugPull)
      .then(buggyInvokeAfterRugPull)
      .expect(not(rugPullMutatedToolNeverInvoked))

  run crossServerShadowingCounterexampleTest =
    init
      .then(buggyShadowTrustedTool)
      .expect(not(crossServerShadowedToolNeverDispatched))

  run untrustedSinkExfilCounterexampleTest =
    init
      .then(receiveUntrustedArg)
      .then(buggyPassUntrustedArgToSink)
      .expect(not(sensitiveSinkNeverAcceptsUntrustedOriginWithoutCert))

  run metadataDecisionHijackCounterexampleTest =
    init
      .then(observeMetadataDecisionFlip)
      .then(buggySkipDecisionDependenceAudit)
      .expect(not(poisonedMetadataDecisionHijackAlwaysFlaggedOffline))
}
