// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module GitOpsLibrary {
  pure def contractIdentity: str = "agentic-ai-lab.gitops.create"
  pure def contractRevision: int = 4
  // Named finite projection of agentic-ai-lab.gitops.create revision 4.
  // Identities are equality classes, not repository observations or authority.
  type AdmitFacts = {
    authorized: bool, fence: bool, source: bool, policy: bool,
    receiptSource: bool, receiptPolicy: bool, anchor: bool, fresh: bool,
    request: bool, custody: bool, executed: bool, provider: bool,
    applied: bool, binding: bool
  }
  type RetainFacts = {
    accepted: bool, activePolicy: bool, activeRequest: bool, activeProvider: bool,
    authorized: bool, fence: bool, source: bool, policy: bool
  }
  type Evidence = {
    receipts: List[int], spent: List[int], activePolicy: int,
    activeRequest: int, activeProvider: int, binding: int,
    admitted: bool, accepted: bool
  }
  // Selector is an opaque identity for a named higher-order behavior. Binding
  // inherits that behavior; the consumer chooses replacements explicitly.
  type Policy = {allowed: Set[int], preferred: int, selector: int,
                 source: int, anchor: int, revision: int}
  pure def bindPolicy(parent: Policy, local: Set[int], source: int,
                      anchor: int, revision: int, preferred: int): Policy =
    parent.with("allowed", restrictCapabilities(parent.allowed, local))
      .with("source", source).with("anchor", anchor).with("revision", revision)
      .with("preferred", preferred)
  pure def restrictCapabilities(parent: Set[int], local: Set[int]): Set[int] = parent.intersect(local)
  pure def selectCapability(allowed: Set[int], git: bool, wt: bool, preferred: int): int = {
    val gitAvailable = git and allowed.contains(1)
    val wtAvailable = wt and allowed.contains(2)
    if (preferred == 2 and wtAvailable) 2 else if (gitAvailable) 1 else if (wtAvailable) 2 else 0
  }
  pure def empty: Evidence = {
    receipts: List(), spent: List(), activePolicy: 0, activeRequest: 0,
    activeProvider: 0, binding: 0, admitted: false, accepted: false
  }
  pure def semanticAdmit(f: AdmitFacts): bool =
    f.authorized and f.fence and f.source and f.policy and f.receiptSource
      and f.receiptPolicy and f.anchor and f.fresh and f.request and f.custody
      and f.executed and f.provider and f.applied and f.binding
  pure def retainCurrent(f: RetainFacts): bool =
    f.accepted and f.activePolicy and f.activeRequest and f.activeProvider
      and f.authorized and f.fence and f.source and f.policy
  pure def refresh(before: Evidence, f: RetainFacts): Evidence = {
    val keep = retainCurrent(f)
    before.with("admitted", false).with("accepted", keep)
      .with("binding", if (keep) before.binding else 0)
  }
  pure def receive(before: Evidence, f: AdmitFacts, r: RetainFacts,
                   selectedPolicy: int, request: int, provider: int,
                   actualBinding: int, receipt: int): Evidence = {
    val newAcceptance = semanticAdmit(f)
    val keep = retainCurrent(r)
    {
      receipts: List(receipt).concat(before.receipts),
      spent: if (newAcceptance) List(request).concat(before.spent) else before.spent,
      activePolicy: if (newAcceptance) selectedPolicy else before.activePolicy,
      activeRequest: if (newAcceptance) request else before.activeRequest,
      activeProvider: if (newAcceptance) provider else before.activeProvider,
      binding: if (newAcceptance) actualBinding else if (keep) before.binding else 0,
      admitted: newAcceptance, accepted: newAcceptance or keep
    }
  }
}
