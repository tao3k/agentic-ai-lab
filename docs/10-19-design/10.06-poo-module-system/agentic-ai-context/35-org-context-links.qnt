// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module OrgContextLinks {
  type End = { source: str, anchor: str, version: int, grant: int }
  type Receipt = { request: int, link: str, origin: End, target: End }
  type State = {
    target: End, pin: int, readable: bool, inWindow: bool, issued: int,
    pending: Receipt, superseded: Receipt, published: Receipt, lastHistorical: Receipt,
    soundBindings: bool, currentAtAdmission: bool, control: str
  }
  pure val origin = { source: "findings.org", anchor: "evidence", version: 1, grant: 1 }
  pure val target = { source: "design.org", anchor: "evidence", version: 1, grant: 1 }
  pure val empty = { request: 0, link: "", origin: origin, target: target }
  var s: State
  action initWith(control: str): bool =
    s' = { target: target, pin: 1, readable: true, inWindow: true, issued: 0,
      pending: empty, superseded: empty, published: empty, lastHistorical: empty,
      soundBindings: true, currentAtAdmission: true, control: control }
  action init = initWith("guarded")
  action initIgnoreVersion = initWith("ignore-version")
  action initIgnoreAuthority = initWith("ignore-authority")
  action initIgnoreIdentity = initWith("ignore-identity")
  action initIgnoreWindow = initWith("ignore-window")

  pure def correctTarget(candidate: End): bool =
    candidate.source == target.source and candidate.anchor == target.anchor
  val current = s.published.request != 0 and s.readable and s.inWindow and
    s.published.target == s.target and s.published.target.version == s.pin
  val linkBindingsAreSound = s.soundBindings
  val acceptedWithCurrentTarget = s.currentAtAdmission
  val canStart = (correctTarget(s.target) or s.control == "ignore-identity") and
    (s.target.version == s.pin or s.control == "ignore-version") and
    (s.inWindow or s.control == "ignore-window") and s.readable and
    (s.pending.request == 0 or s.pending.target != s.target)
  action start = all {
    canStart,
    val serial = s.issued + 1
    s' = s.with("issued", serial)
      .with("superseded", if (s.pending.request == 0) s.superseded else s.pending)
      .with("pending", { request: serial, link: "file:design.org::#evidence", origin: origin, target: s.target })
  }
  action receive = all {
    s.pending.request != 0,
    val receipt = s.pending
    val versionsAgree = receipt.target.version == s.target.version and receipt.target.version == s.pin
    val granted = s.readable and receipt.target.grant == s.target.grant
    val admit = (versionsAgree or s.control == "ignore-version") and
      (granted or s.control == "ignore-authority") and
      (correctTarget(receipt.target) and receipt.target.source == s.target.source or s.control == "ignore-identity") and
      (s.inWindow or s.control == "ignore-window")
    s' = s.with("pending", empty)
      .with("published", if (admit) receipt else s.published)
      .with("lastHistorical", if (admit) s.lastHistorical else receipt)
      .with("soundBindings", s.soundBindings and
        (not(admit) or (correctTarget(receipt.target) and receipt.origin == origin and s.inWindow)))
      .with("currentAtAdmission", s.currentAtAdmission and (not(admit) or (granted and versionsAgree)))
  }
  action receiveSuperseded = all {
    s.superseded.request != 0,
    s' = s.with("lastHistorical", s.superseded).with("superseded", empty)
  }
  action revise = s' = s.with("target", s.target.with("version", s.target.version + 1))
  action repin = s' = s.with("pin", s.target.version)
  action changeAuthority = s' = s.with("readable", not(s.readable))
    .with("target", s.target.with("grant", s.target.grant + 1))
  action substitute = s' = s.with("target", s.target.with("source", "other-design.org"))
  action moveOutsideWindow = s' = s.with("inWindow", false)
  action step = any {
    start, receive, receiveSuperseded, revise, repin, changeAuthority, substitute, moveOutsideWindow, s' = s
  }

  run linkTargetVersionTest = init.then(start).then(receive).then(start).then(revise)
    .expect(not(current) and not(canStart)).then(repin).then(start).then(receiveSuperseded)
    .expect(s.lastHistorical.target.version == 1 and s.pending.target.version == 2)
    .then(receive).expect(current and s.published.target.version == 2)
  run linkTargetAuthorityTest = init.then(changeAuthority).expect(not(canStart))
    .then(changeAuthority).then(start).then(receive).then(start).then(changeAuthority)
    .expect(not(current) and not(canStart)).then(receive)
    .expect(s.lastHistorical.target.grant != s.target.grant)
  run linkTargetSubstitutionTest = init.then(substitute).expect(not(canStart) and not(current))
  run linkOutsideWindowTest = init.then(moveOutsideWindow).expect(not(canStart) and not(current))
  run ignoreLinkTargetVersionCounterexampleTest = initIgnoreVersion.then(start).then(revise).then(receive)
    .expect(not(acceptedWithCurrentTarget))
  run ignoreLinkTargetAuthorityCounterexampleTest = initIgnoreAuthority.then(start).then(changeAuthority).then(receive)
    .expect(not(acceptedWithCurrentTarget))
  run ignoreLinkTargetIdentityCounterexampleTest = initIgnoreIdentity.then(substitute).then(start).then(receive)
    .expect(not(linkBindingsAreSound))
  run ignoreLinkWindowCounterexampleTest = initIgnoreWindow.then(moveOutsideWindow).then(start).then(receive)
    .expect(not(linkBindingsAreSound))
}

module OrgContextLinkChains {
  type Key = (str, str)
  type End = { key: Key, version: int, grant: int }
  type Hop = { from: End, to: End }
  type Receipt = { request: int, hops: List[Hop] }
  type State = {
    middle: End, leaf: End, pin: int, middleReadable: bool, leafReadable: bool,
    backEdge: bool, sharedLeaf: bool, issued: int, pending: Receipt, superseded: Receipt,
    published: Receipt, lastHistorical: Receipt, sound: bool, fresh: bool, control: str
  }

  pure val root = { key: ("A/worktree.org", "owner-evidence"), version: 1, grant: 1 }
  pure val design = { key: ("A/design.org", "design-record"), version: 1, grant: 1 }
  pure val reference = { key: ("A/reference.org", "reference-record"), version: 1, grant: 1 }
  pure val anchors = Set(root.key, design.key, reference.key)
  pure val empty = { request: 0, hops: List() }
  var s: State

  action initWith(control: str, cycle: bool, sharedLeaf: bool, granted: bool): bool =
    s' = { middle: design, leaf: reference, pin: 1, middleReadable: granted, leafReadable: granted,
      backEdge: cycle, sharedLeaf: sharedLeaf, issued: 0, pending: empty, superseded: empty,
      published: empty, lastHistorical: empty, sound: true, fresh: true, control: control }
  action init = nondet topology = Set("chain", "cycle", "shared").oneOf()
    initWith("guarded", topology == "cycle", topology == "shared", true)

  pure def hasEdge(hops: List[Hop], fromKey: Key, toKey: Key): bool =
    hops.foldl(false, (found, hop) => found or (hop.from.key == fromKey and hop.to.key == toKey))

  // A simple cycle in this three-anchor graph has at most three edges.
  pure def acyclic(hops: List[Hop]): bool = anchors.forall(a =>
    not(hasEdge(hops, a, a)) and anchors.forall(b =>
      not(hasEdge(hops, a, b) and hasEdge(hops, b, a)) and anchors.forall(c =>
        not(hasEdge(hops, a, b) and hasEdge(hops, b, c) and hasEdge(hops, c, a)))))

  val chain = List({ from: root, to: s.middle }, { from: s.middle, to: s.leaf })
  val selectedHops = if (s.backEdge) chain.append({ from: s.leaf, to: root })
    else if (s.sharedLeaf) chain.append({ from: root, to: s.leaf }) else chain
  val readable = s.middleReadable and s.leafReadable
  val current = s.published.request != 0 and readable and s.middle.version == s.pin and
    s.published.hops == selectedHops and acyclic(selectedHops)
  val linkChainsAreAcyclic = s.sound
  val acceptedWithCurrentChain = s.fresh
  val canStart = readable and s.middle.version == s.pin and
    (acyclic(selectedHops) or s.control == "ignore-cycle") and
    (s.pending.request == 0 or s.pending.hops != selectedHops)

  action start = all {
    canStart,
    val serial = s.issued + 1
    s' = s.with("issued", serial)
      .with("superseded", if (s.pending.request == 0) s.superseded else s.pending)
      .with("pending", { request: serial, hops: selectedHops })
  }
  action receive = all {
    s.pending.request != 0,
    val hops = s.pending.hops
    val incoming = hops.nth(0)
    val outgoing = hops.nth(1)
    val versionsAgree = incoming.to.version == s.middle.version and
      outgoing.from.version == s.middle.version and s.middle.version == s.pin
    val grantsAgree = readable and incoming.to.grant == s.middle.grant and
      outgoing.from.grant == s.middle.grant and outgoing.to.grant == s.leaf.grant
    val sound = acyclic(hops) and incoming.to == outgoing.from
    val admit = (sound or s.control == "ignore-cycle") and
      (versionsAgree or s.control == "ignore-middle-version") and
      (grantsAgree or s.control == "ignore-middle-authority")
    s' = s.with("pending", empty)
      .with("published", if (admit) s.pending else s.published)
      .with("lastHistorical", if (admit) s.lastHistorical else s.pending)
      .with("sound", s.sound and (not(admit) or sound))
      .with("fresh", s.fresh and (not(admit) or (versionsAgree and grantsAgree)))
  }
  action receiveSuperseded = all {
    s.superseded.request != 0,
    s' = s.with("lastHistorical", s.superseded).with("superseded", empty)
  }
  action revise = s' = s.with("middle", s.middle.with("version", s.middle.version + 1))
  action repin = s' = s.with("pin", s.middle.version)
  action revokeMiddle = all {
    s.middleReadable,
    s' = s.with("middleReadable", false)
  }
  // The Module must bind a fresh grant identity after revocation.
  action adoptMiddleGrant = all {
    not(s.middleReadable),
    s' = s.with("middleReadable", true).with("middle", s.middle.with("grant", s.middle.grant + 1))
  }
  action changeLeafAuthority = s' = s.with("leafReadable", not(s.leafReadable))
    .with("leaf", s.leaf.with("grant", s.leaf.grant + 1))
  action step = any {
    start, receive, receiveSuperseded, revise, repin, revokeMiddle, adoptMiddleGrant, changeLeafAuthority, s' = s
  }

  run linkConvergingPathsTest = initWith("guarded", false, true, true).then(start).then(receive)
    .expect(current and s.published.hops == chain.append({ from: root, to: reference }))
  run linkCycleTest = initWith("guarded", true, false, true).expect(not(canStart) and not(current))
  run linkIntermediateVersionTest = initWith("guarded", false, false, true).then(start).then(receive).then(start)
    .then(revise).expect(not(canStart) and not(current)).then(repin).then(start).then(receiveSuperseded)
    .expect(s.lastHistorical.hops.nth(0).to.version == 1 and s.lastHistorical.hops.nth(1).from.version == 1)
    .then(receive).expect(current and s.published.hops.nth(0).to.version == 2 and
      s.published.hops.nth(1).from.version == 2)
  run linkIntermediateAuthorityTest = initWith("guarded", false, false, false)
    .expect(not(canStart)).then(adoptMiddleGrant).expect(not(canStart)).then(changeLeafAuthority)
    .then(start).then(receive).then(start).then(revokeMiddle)
    .expect(not(canStart) and not(current)).then(receive)
    .expect(s.lastHistorical.request != 0 and not(s.middleReadable))
    .then(adoptMiddleGrant).then(start).then(receive).expect(current and
      s.lastHistorical.hops.nth(0).to.grant != s.published.hops.nth(0).to.grant)
  run ignoreLinkCycleCounterexampleTest = initWith("ignore-cycle", true, false, true).then(start).then(receive)
    .expect(not(linkChainsAreAcyclic))
  run ignoreLinkIntermediateVersionCounterexampleTest = initWith("ignore-middle-version", false, false, true)
    .then(start).then(revise).then(receive).expect(not(acceptedWithCurrentChain))
  run ignoreLinkIntermediateAuthorityCounterexampleTest = initWith("ignore-middle-authority", false, false, true)
    .then(start).then(revokeMiddle).then(receive).expect(not(acceptedWithCurrentChain))
}
