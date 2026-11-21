// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module WorktreeGitOps {
  import GitOpsLibrary.* from "./38-gitops-library"
  // Bounded protocol abstraction of agentic-ai-lab.gitops.create revision 4.
  // Physical execution belongs to an arbitrary downstream Provider. The model
  // checks its assumed contract; it does not implement a particular adapter.
  const BUG: str
  // 0 = unavailable/denied, 1 = GitWorktree, 2 = Worktrunk.
  pure def selectProvider(git: bool, wt: bool, prefer: bool): int =
    selectCapability(Set(1, 2), git, wt, if (prefer) 2 else 1)
  // Finite abstraction of higher order POO specialization. A derived policy
  // restricts its input policy's capability set; preference never grants one.
  pure def specialize(base: Set[int], local: Set[int]): Set[int] =
    if (BUG == "widen") base.union(local) else restrictCapabilities(base, local)
  var s: {
    phase: int, source: int, policy: int, grant: bool,
    capturedSource: int, capturedPolicy: int, provider: int,
    git: bool, wt: bool, prefer: bool, allowed: Set[int],
    executed: bool, badDispatch: bool, receipt: bool,
    foreign: bool, receiptProvider: int, outcome: int, actualPath: int, boundPath: int,
    accepted: bool, acceptCount: int, badResult: bool, event: str, evidence: Evidence
  }
  action initWith(profile: int): bool = {
    s' = { phase: 0, source: 0, policy: 0, grant: true,
      capturedSource: 0, capturedPolicy: 0, provider: 0,
      git: profile != 3 and profile != 4, wt: profile != 2 and profile != 4, prefer: true,
      // profile 1: parent permits Git only, local requests either capability.
      allowed: if (profile == 1) Set(1) else Set(1, 2),
      executed: false, badDispatch: false, receipt: false,
      foreign: false, receiptProvider: 0, outcome: 0, actualPath: 0, boundPath: 0,
      accepted: false, acceptCount: 0, badResult: false, event: "init", evidence: empty }
  }
  action init = { nondet profile = 0.to(4).oneOf(); initWith(profile) }
  val current = s.grant and s.policy == s.capturedPolicy and s.source == s.capturedSource
  val retention: RetainFacts = {
    accepted: s.evidence.accepted, activePolicy: s.evidence.activePolicy == 1,
    activeRequest: s.evidence.activeRequest == 1, activeProvider: s.evidence.activeProvider == s.provider,
    authorized: s.grant, fence: current, source: s.source == s.capturedSource,
    policy: s.policy == s.capturedPolicy
  }
  val admission: AdmitFacts = {
    authorized: s.grant or BUG == "result", fence: current or BUG == "result",
    source: s.source == s.capturedSource or BUG == "result",
    policy: s.policy == s.capturedPolicy or BUG == "result",
    receiptSource: true, receiptPolicy: true, anchor: true, fresh: s.acceptCount == 0,
    request: not(s.foreign) or BUG == "foreign", custody: not(s.foreign) or BUG == "foreign",
    executed: s.executed, provider: (s.receiptProvider == s.provider or BUG == "provider")
      and s.allowed.contains(s.receiptProvider), applied: s.outcome == 1, binding: s.actualPath > 0
  }
  val nextEvidence = receive(s.evidence, admission, retention, 1, 1, s.receiptProvider, s.actualPath, 0)
  action composePolicy = all {
    s.phase == 0,
    val derived = specialize(s.allowed, Set(1, 2))
    val selected = selectProvider(s.git and derived.contains(1), s.wt and derived.contains(2), s.prefer)
    // The consumer captured this invocation before composition; it is immutable.
    s' = s.with("phase", 1).with("provider", selected).with("event", "policy-compose")
  }
  action project = all {
    s.phase == 1, s.provider != 0,
    s' = s.with("phase", 2).with("event", "consumer-project")
  }
  action deny = all {
    s.phase == 1, s.provider == 0,
    s' = s.with("phase", 6).with("event", "no-provider")
  }
  // Logical admission and actual effect are separate transitions to expose races.
  action admit = all {
    s.phase == 2, current,
    s' = s.with("phase", 3).with("event", "owner-admit")
  }
  action refuse = all {
    (s.phase == 2 or s.phase == 3), not(current),
    s' = s.with("phase", 6).with("event", "owner-refuse-stale")
  }
  action execute = all {
    s.phase == 3, (current or BUG == "dispatch"),
    s' = s.with("phase", 4).with("executed", true)
      .with("badDispatch", not(current) or not(s.allowed.contains(s.provider)))
      .with("event", "provider-execute")
  }
  // The provider may succeed at a DIFFERENT actual path, fail, or leave an
  // ambiguous outcome. A foreign envelope is an adversarial delivery input.
  action returnProviderReceipt(foreign: bool, outcome: int, actual: int, provider: int): bool = all {
    s.phase == 4,
    s' = s.with("phase", 5).with("receipt", true).with("foreign", foreign)
      .with("receiptProvider", provider).with("outcome", outcome)
      .with("actualPath", actual).with("event", "owner-return")
  }
  action returnReceipt(foreign: bool, outcome: int, actual: int): bool =
    returnProviderReceipt(foreign, outcome, actual, s.provider)
  action returnOtherProvider = returnProviderReceipt(false, 1, 11, if (s.provider == 1) 2 else 1)
  action consume = all {
    s.phase == 5, s.receipt, nextEvidence.admitted,
    s' = s.with("phase", 6).with("accepted", nextEvidence.accepted)
      .with("acceptCount", nextEvidence.spent.length()).with("evidence", nextEvidence)
      .with("boundPath", if (BUG == "intent") 10 else nextEvidence.binding)
      .with("badResult", not(current) or s.foreign or s.receiptProvider != s.provider)
      .with("event", "context-accept")
  }
  action retainOnly = all {
    s.phase == 5, not(nextEvidence.admitted),
    s' = s.with("phase", 6).with("evidence", nextEvidence)
      .with("accepted", nextEvidence.accepted).with("event", "context-retain-unaccepted")
  }
  action duplicate = all {
    // Finite protocol bound: one original delivery plus one redelivery.
    s.phase == 6, s.acceptCount == 1, s.evidence.receipts.length() < 2,
    s' = s.with("acceptCount", if (BUG == "duplicate") 2 else 1)
      .with("evidence", nextEvidence).with("accepted", nextEvidence.accepted)
      .with("event", "duplicate-delivery")
  }
  action changeSource = all {
    s.source == 0,
    s' = s.with("source", 1).with("accepted", false)
      .with("evidence", refresh(s.evidence, retention.with("source", false))).with("event", "source-change")
  }
  action changePolicy = all {
    s.policy == 0,
    s' = s.with("policy", 1).with("accepted", false)
      .with("evidence", refresh(s.evidence, retention.with("policy", false))).with("event", "policy-change")
  }
  action revoke = all {
    s.grant,
    s' = s.with("grant", false).with("accepted", false)
      .with("evidence", refresh(s.evidence, retention.with("authorized", false))).with("event", "revoke")
  }
  action idle = s' = s.with("event", "idle")
  action step = any {
    composePolicy, project, deny, admit, refuse, execute,
    returnReceipt(false, 1, 10), returnReceipt(false, 1, 11),
    returnReceipt(false, 2, 10), returnReceipt(false, 3, 10),
    returnReceipt(true, 1, 11), returnOtherProvider, consume, retainOnly, duplicate,
    changeSource, changePolicy, revoke, idle
  }
  val dispatchSafety = not(s.badDispatch)
  val resultSafety = not(s.badResult) and (s.accepted implies
    (current and s.receipt and s.executed and not(s.foreign) and s.outcome == 1
      and s.receiptProvider == s.provider))
  val actualBinding = s.acceptCount > 0 implies s.boundPath == s.actualPath
  val onceOnly = s.acceptCount <= 1
  val libraryProjection = s.accepted == s.evidence.accepted
    and s.acceptCount == s.evidence.spent.length()
    and (s.accepted implies s.boundPath == s.evidence.binding)
  val safety = dispatchSafety and resultSafety and actualBinding and onceOnly and libraryProjection
}
