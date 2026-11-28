// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module GitOpsRefinement {
  import GitOpsLibrary.* from "./38-gitops-library"
  pure def bit(mask: int, weight: int): bool = (mask / weight) % 2 == 1
  pure def admitFacts(mask: int): AdmitFacts = {
    authorized: bit(mask, 1), fence: bit(mask, 2), source: bit(mask, 4),
    policy: bit(mask, 8), receiptSource: bit(mask, 16), receiptPolicy: bit(mask, 32),
    anchor: bit(mask, 64), fresh: bit(mask, 128), request: bit(mask, 256),
    custody: bit(mask, 512), executed: bit(mask, 1024), provider: bit(mask, 2048),
    applied: bit(mask, 4096), binding: bit(mask, 8192)
  }
  pure def seeded: Evidence = {
    receipts: List(-1), spent: List(1), activePolicy: 1, activeRequest: 1,
    activeProvider: 2, binding: 10, admitted: true, accepted: true
  }
  pure def admissionCase(mask: int): Evidence = {
    val f = admitFacts(mask)
    val before = if (f.fresh) empty else seeded
    val r = {accepted: before.accepted, activePolicy: before.activePolicy == 1,
      activeRequest: before.activeRequest == (if (f.request) 1 else 2),
      activeProvider: before.activeProvider == 2, authorized: f.authorized, fence: f.fence,
      source: f.source, policy: f.policy}
    receive(before, f, r, 1, 1, if (f.provider) 2 else 1,
      if (f.binding) 11 else 0, mask)
  }
  // Occupied/retired states realize fresh r2 while retaining spent r1. This
  // includes a refused new receipt that must preserve the old current binding.
  pure def occupiedCase(mask: int, retired: bool): Evidence = {
    val f = admitFacts(mask)
    val before = if (retired) seeded.with("admitted", false).with("accepted", false).with("binding", 0) else seeded
    val receiptRequest = if (f.fresh) 2 else 1
    val currentRequest = if (f.request) receiptRequest else if (receiptRequest == 1) 2 else 1
    val r = {accepted: before.accepted, activePolicy: true, activeRequest: currentRequest == 1,
      activeProvider: true, authorized: f.authorized, fence: f.fence, source: f.source, policy: f.policy}
    receive(before, f, r, 1, receiptRequest, if (f.provider) 2 else 1,
      if (f.binding) 11 else 0, mask)
  }
  pure def refreshFacts(mask: int): RetainFacts = {
    accepted: bit(mask, 1), activePolicy: bit(mask, 2), activeRequest: bit(mask, 4),
    activeProvider: bit(mask, 8), authorized: bit(mask, 16), fence: bit(mask, 32),
    source: bit(mask, 64), policy: bit(mask, 128)
  }
  pure def refreshCase(mask: int): Evidence = {
    val f = refreshFacts(mask)
    val before = seeded.with("accepted", f.accepted)
      .with("admitted", f.accepted).with("binding", if (f.accepted) 10 else 0)
    refresh(before, f)
  }
  pure def sourceCase(mask: int): Evidence = {
    val f = admitFacts(16383).with("source", mask >= 32 or mask == 31)
      .with("receiptSource", mask < 32 or mask == 63)
    receive(empty, f, refreshFacts(0), 1, 1, 2, 11, mask)
  }
  pure def providerCase(id: int): Evidence =
    receive(empty, admitFacts(16383).with("provider", id == 0), refreshFacts(0),
      if (id == 3) 3 else 1, 1, if (id == 1) 1 else if (id == 2) 3 else 2, 11, id)
  pure def duplicateState: Evidence = receive(seeded,
    admitFacts(16383).with("fresh", false), refreshFacts(255), 1, 1, 2, 11, 1)
  pure def withdrawState: Evidence = refresh(duplicateState, refreshFacts(255).with("authorized", false))
  pure def restoredState: Evidence = refresh(withdrawState, refreshFacts(255).with("accepted", false))
  pure def lateState: Evidence = receive(restoredState, admitFacts(16383).with("fresh", false),
    refreshFacts(255).with("accepted", false), 1, 1, 2, 11, 4)
  pure def secondState: Evidence = receive(lateState, admitFacts(16383),
    refreshFacts(255).with("accepted", false).with("activeRequest", false).with("activeProvider", false), 1, 2, 1, 11, 5)
  pure def replacedPolicyState: Evidence = refresh(secondState, refreshFacts(255).with("activePolicy", false))
  pure def restoredPolicyState: Evidence = refresh(replacedPolicyState, refreshFacts(255).with("accepted", false))
  pure def historyCase(id: int): Evidence =
    if (id == 0) seeded else if (id == 1) duplicateState else if (id == 2) withdrawState
    else if (id == 3) restoredState else if (id == 4) lateState else if (id == 5) secondState
    else if (id == 6) replacedPolicyState
    else if (id == 7) restoredPolicyState
    else receive(restoredPolicyState, admitFacts(16383).with("fresh", false),
      refreshFacts(255).with("accepted", false), 1, 2, 1, 10, 8)
  pure def originalPolicy: Policy = {allowed: Set(1, 2), preferred: 2, selector: 0, source: 0, anchor: 1, revision: 1}
  pure def replacementPolicy: Policy = bindPolicy(originalPolicy.with("allowed", Set(1)).with("selector", 1), Set(1, 2), 0, 1, 2, 2)
  pure def reboundPolicy: Policy = bindPolicy(replacementPolicy, Set(1), 1, 1, 3, 1)
  pure def replacedUse: Evidence = refresh(seeded,
    refreshFacts(255).with("activePolicy", false).with("activeProvider", false))
  pure def oldPending: Evidence = receive(replacedUse,
    admitFacts(16383).with("receiptPolicy", false), refreshFacts(0), 4, 2, 1, 11, 2)
  pure def replacementAccepted: Evidence = receive(oldPending,
    admitFacts(16383), refreshFacts(0), 4, 3, 1, 11, 3)
  pure def reboundUse: Evidence = refresh(replacementAccepted, refreshFacts(255).with("activePolicy", false))
  pure def oldSourcePending: Evidence = receive(reboundUse,
    admitFacts(16383).with("receiptSource", false).with("receiptPolicy", false), refreshFacts(0), 5, 4, 1, 11, 5)
  pure def replacementCase(id: int): Evidence =
    if (id == 0) seeded else if (id == 1) replacedUse else if (id == 2) oldPending
    else if (id == 3) replacementAccepted else if (id == 4) reboundUse else if (id == 5) oldSourcePending
    else receive(oldSourcePending, admitFacts(16383), refreshFacts(0), 5, 5, 1, 11, 6)
  pure def parentAllowed(mask: int): Set[int] = Set(1, 2).filter(p => if (p == 1) bit(mask, 1) else bit(mask, 2))
  pure def localAllowed(mask: int): Set[int] =
    if ((mask / 4) % 4 == 0) Set(1) else if ((mask / 4) % 4 == 1) Set(2) else Set(1, 2)
  pure def selectionCase(mask: int): {id: int, allowed: Set[int], selected: int} = {
    val allowed = restrictCapabilities(parentAllowed(mask), localAllowed(mask))
    val preferred = if ((mask / 4) % 2 == 0) 1 else 2
    {id: mask, allowed: allowed, selected: selectCapability(allowed, bit(mask, 16), bit(mask, 32), preferred)}
  }
  type Witness = {id: int, expected: Evidence}
  // Masks already identify the rows. Use an ordered list so the evaluator
  // does not hash each nested Evidence record to establish set membership.
  pure def witnesses(count, expected) =
    range(0, count).foldl(List(), (rows, id) => rows.append({id: id, expected: expected(id)}))
  var cases: List[Witness]
  var origin: Evidence
  var choices: Set[{id: int, allowed: Set[int], selected: int}]
  var identity: str
  var revision: int
  var policies: List[Policy]
  action metadata = all { identity' = identity, revision' = revision, origin' = origin, policies' = policies }
  action init = all { cases' = List(), choices' = Set(), origin' = seeded,
    identity' = contractIdentity, revision' = contractRevision, policies' = List(originalPolicy, replacementPolicy, reboundPolicy) }
  action admissions = all { cases' = witnesses(16384, admissionCase), choices' = choices, metadata }
  action occupied = all { cases' = witnesses(16384, mask => occupiedCase(mask, false)), choices' = choices, metadata }
  action retired = all { cases' = witnesses(16384, mask => occupiedCase(mask, true)), choices' = choices, metadata }
  action refreshes = all { cases' = witnesses(256, refreshCase), choices' = choices, metadata }
  action sources = all { cases' = witnesses(64, sourceCase), choices' = choices, metadata }
  action providers = all { cases' = witnesses(4, providerCase), choices' = choices, metadata }
  action histories = all { cases' = witnesses(9, historyCase), choices' = choices, metadata }
  action replacements = all { cases' = witnesses(7, replacementCase), choices' = choices, metadata }
  action selections = all { choices' = 0.to(63).map(selectionCase), cases' = cases, metadata }
  run admissionTest = init.then(admissions).expect(cases.length() == 16384)
  run occupiedTest = init.then(occupied).expect(cases.length() == 16384)
  run retiredTest = init.then(retired).expect(cases.length() == 16384)
  run refreshTest = init.then(refreshes).expect(cases.length() == 256)
  run sourceTest = init.then(sources).expect(cases.length() == 64)
  run providerTest = init.then(providers).expect(cases.length() == 4)
  run historyTest = init.then(histories).expect(cases.length() == 9)
  run replacementTest = init.then(replacements).expect(cases.length() == 7)
  run selectionTest = init.then(selections).expect(choices.size() == 64)
}
