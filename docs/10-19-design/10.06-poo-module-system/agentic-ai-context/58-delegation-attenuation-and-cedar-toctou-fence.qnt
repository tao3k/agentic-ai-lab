// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
//
// Slice 58: Multi-Agent Delegated Obligation Capability Attenuation &
// Concurrent Cedar Revocation TOCTOU Fence.
module DelegationAttenuationAndCedarToctou {
  type State = {
    liveCut: int,
    liveGrantEpoch: int,
    parentGrantLive: bool,
    parentDeniesBash: bool,
    childDelegated: bool,
    childBoundCut: int,
    childBoundGrantEpoch: int,
    childAttemptOpen: bool,
    childBypassedDeny: bool,
    childExecutedAfterRevokeOrDrift: bool,
    parentCompletedWithUnclosedChild: bool,
    safeChildExecutions: int,
  }

  var s58: State

  action init = all {
    s58' = {
      liveCut: 1,
      liveGrantEpoch: 1,
      parentGrantLive: true,
      parentDeniesBash: true,
      childDelegated: false,
      childBoundCut: 0,
      childBoundGrantEpoch: 0,
      childAttemptOpen: false,
      childBypassedDeny: false,
      childExecutedAfterRevokeOrDrift: false,
      parentCompletedWithUnclosedChild: false,
      safeChildExecutions: 0,
    }
  }

  // Parent delegates an attenuated obligation bound to current live cut & grant epoch
  action delegateAttenuatedChild = all {
    s58.parentGrantLive,
    not(s58.childDelegated),
    s58' = {
      ...s58,
      childDelegated: true,
      childBoundCut: s58.liveCut,
      childBoundGrantEpoch: s58.liveGrantEpoch,
      childAttemptOpen: true,
    }
  }

  // Atomic TOCTOU fence: child executes ONLY if parent grant live, cut & epoch match!
  action executeFencedChildAction = all {
    s58.childDelegated,
    s58.childAttemptOpen,
    s58.parentGrantLive,
    s58.childBoundCut == s58.liveCut,
    s58.childBoundGrantEpoch == s58.liveGrantEpoch,
    s58.safeChildExecutions < 2,
    s58' = {
      ...s58,
      childAttemptOpen: false,
      safeChildExecutions: s58.safeChildExecutions + 1,
    }
  }

  // Concurrent asynchronous Cedar revocation / epoch advance
  action revokeParentCedarGrant = all {
    s58.parentGrantLive,
    s58' = {
      ...s58,
      parentGrantLive: false,
      liveGrantEpoch: s58.liveGrantEpoch + 1,
    }
  }

  // Concurrent workspace cut transition (models Claude #107019 path/git state change)
  action advanceWorkspaceCut = all {
    s58.liveCut < 2,
    s58' = { ...s58, liveCut: s58.liveCut + 1 }
  }

  // Explicit recovery reconciliation of an interrupted/paused child attempt (prevents Codex #34043)
  action reconcileInterruptedChild = all {
    s58.childAttemptOpen,
    not(s58.parentGrantLive) or (s58.childBoundCut != s58.liveCut),
    s58' = { ...s58, childAttemptOpen: false, childDelegated: false }
  }

  action step = any {
    delegateAttenuatedChild,
    executeFencedChildAction,
    revokeParentCedarGrant,
    advanceWorkspaceCut,
    reconcileInterruptedChild,
  }

  // Negative-control fault injections reproducing real Claude Code & Codex bugs
  action buggyChildBypassParentDeny = all {
    s58.childDelegated,
    s58.parentDeniesBash,
    s58' = { ...s58, childBypassedDeny: true }
  }

  action buggyChildExecuteAfterParentRevoke = all {
    s58.childDelegated,
    not(s58.parentGrantLive),
    s58' = { ...s58, childExecutedAfterRevokeOrDrift: true }
  }

  action buggyChildExecuteOnStaleCut = all {
    s58.childDelegated,
    s58.childBoundCut != s58.liveCut,
    s58' = { ...s58, childExecutedAfterRevokeOrDrift: true }
  }

  action buggyParentCompleteWithUnclosedChild = all {
    s58.childAttemptOpen,
    s58' = { ...s58, parentCompletedWithUnclosedChild: true }
  }

  // Four bidirectional safety invariants mapped in SysML
  val delegatedChildNeverBypassesParentDenylist =
    not(s58.childBypassedDeny)

  val revokedGrantOrStaleCutNeverAdmitsChildToctou =
    not(s58.childExecutedAfterRevokeOrDrift)

  val parentNeverCompletesWhileChildAttemptUnclosed =
    not(s58.parentCompletedWithUnclosedChild)

  val childBoundEpochNeverExceedsLiveGrantEpoch =
    s58.childBoundGrantEpoch <= s58.liveGrantEpoch

  val safety = and {
    delegatedChildNeverBypassesParentDenylist,
    revokedGrantOrStaleCutNeverAdmitsChildToctou,
    parentNeverCompletesWhileChildAttemptUnclosed,
    childBoundEpochNeverExceedsLiveGrantEpoch,
  }

  // Positive witnesses
  run safeDelegatedFencedExecutionTest =
    init
      .then(delegateAttenuatedChild)
      .then(executeFencedChildAction)
      .expect(safety and s58.safeChildExecutions == 1 and not(s58.childAttemptOpen))

  run safeRevocationAndRecoveryTest =
    init
      .then(delegateAttenuatedChild)
      .then(revokeParentCedarGrant)
      .then(reconcileInterruptedChild)
      .expect(safety and not(s58.childAttemptOpen) and s58.safeChildExecutions == 0)

  // Negative-control counterexamples reproducing real Claude Code / Codex issues
  run subagentDenyBypassCounterexampleTest =
    init
      .then(delegateAttenuatedChild)
      .then(buggyChildBypassParentDeny)
      .expect(not(delegatedChildNeverBypassesParentDenylist))

  run cedarRevokeToctouCounterexampleTest =
    init
      .then(delegateAttenuatedChild)
      .then(revokeParentCedarGrant)
      .then(buggyChildExecuteAfterParentRevoke)
      .expect(not(revokedGrantOrStaleCutNeverAdmitsChildToctou))

  run staleChildCutCounterexampleTest =
    init
      .then(delegateAttenuatedChild)
      .then(advanceWorkspaceCut)
      .then(buggyChildExecuteOnStaleCut)
      .expect(not(revokedGrantOrStaleCutNeverAdmitsChildToctou))

  run unclosedChildResumeDeadlockCounterexampleTest =
    init
      .then(delegateAttenuatedChild)
      .then(buggyParentCompleteWithUnclosedChild)
      .expect(not(parentNeverCompletesWhileChildAttemptUnclosed))
}
