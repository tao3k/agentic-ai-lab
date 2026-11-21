// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module OrgContextDescendants {
  // Node identities abstract qualified Orgize rows with distinct byte ranges.
  // The sibling has the same title as the root, but is outside its ancestry.
  type Node = { id: str, inRoot: bool, depth: int, start: int, end: int }
  type Receipt = { request: int, source: int, grant: int, depth: int, bound: int, rows: Set[Node] }
  type State = {
    source: int, grant: int, allowed: bool, serial: int, pending: Receipt,
    publication: Receipt, historical: Set[Receipt], completeAndScoped: bool, wasCurrent: bool, control: str
  }
  pure val elements = Set(
    { id: "paragraph", inRoot: true, depth: 1, start: 10, end: 40 },
    { id: "link", inRoot: true, depth: 2, start: 20, end: 35 },
    { id: "table", inRoot: true, depth: 1, start: 40, end: 60 },
    { id: "nested-paragraph", inRoot: true, depth: 2, start: 65, end: 90 },
    { id: "nested-link", inRoot: true, depth: 3, start: 70, end: 85 },
    { id: "same-title-sibling", inRoot: false, depth: 1, start: 105, end: 130 })
  pure def window(depth: int): Set[Node] =
    elements.filter(n => n.inRoot and n.depth <= depth and 0 <= n.start and n.end <= 100)
  pure val empty = { request: 0, source: 0, grant: 0, depth: 0, bound: 0, rows: Set() }
  var s: State
  action initWith(control: str): bool =
    s' = { source: 1, grant: 1, allowed: true, serial: 0, pending: empty,
      publication: empty, historical: Set(), completeAndScoped: true, wasCurrent: true, control: control }
  action init = initWith("guarded")
  action initIgnoreAncestry = initWith("ignore-ancestry")
  action initTruncate = initWith("truncate")
  action initIgnoreSource = initWith("ignore-source")
  action initIgnoreGrant = initWith("ignore-grant")

  val current = s.publication.request != 0 and s.publication.source == s.source and
    s.publication.grant == s.grant and s.allowed
  val completeAndScoped = s.completeAndScoped
  val admittedWhileCurrent = s.wasCurrent
  action query(depth: int, bound: int): bool = all {
    s.allowed, s.pending.request == 0,
    val expected = window(depth)
    val rows = if (s.control == "ignore-ancestry") elements.filter(n => n.depth <= depth)
      else if (s.control == "truncate") expected.filter(n => n.id == "paragraph") else expected
    if (rows.size() > bound) s' = s
    else {
      val serial = s.serial + 1
      s' = s.with("serial", serial).with("pending", {
        request: serial, source: s.source, grant: s.grant, depth: depth, bound: bound, rows: rows
      })
    }
  }
  action receive = all {
    s.pending.request != 0,
    val receipt = s.pending
    val live = receipt.source == s.source and receipt.grant == s.grant and s.allowed
    val admit = (receipt.source == s.source or s.control == "ignore-source") and
      ((receipt.grant == s.grant and s.allowed) or s.control == "ignore-grant")
    s' = s.with("pending", empty)
      .with("publication", if (admit) receipt else s.publication)
      .with("historical", if (admit) s.historical else s.historical.union(Set(receipt)))
      .with("completeAndScoped", s.completeAndScoped and
        (not(admit) or (receipt.rows == window(receipt.depth) and receipt.rows.size() <= receipt.bound)))
      .with("wasCurrent", s.wasCurrent and (not(admit) or live))
  }
  action revise = s' = s.with("source", s.source + 1)
  action changeGrant = s' = s.with("grant", s.grant + 1).with("allowed", not(s.allowed))
  action step = any { query(3, 8), query(1, 8), query(3, 2), receive, revise, changeGrant, s' = s }

  run descendantScopeTest = init.then(query(3, 8)).then(receive)
    .expect(current and s.publication.rows == window(3) and s.publication.rows.size() == 5)
  run descendantBoundsTest = init.then(query(3, 2))
    .expect(s.pending == empty and not(current)).then(query(1, 8)).then(receive)
    .expect(current and s.publication.rows == window(1) and s.publication.rows.size() == 2)
  run descendantSourceChangeTest = init.then(query(3, 8)).then(receive).then(query(3, 8)).then(revise)
    .expect(not(current)).then(receive).expect(s.historical.exists(r => r.request == 2 and r.source == 1))
    .then(query(3, 8)).then(receive).expect(current and s.publication.source == 2)
  run descendantAuthorizationTest = init.then(query(3, 8)).then(receive).then(query(3, 8)).then(changeGrant)
    .expect(not(current)).then(receive).expect(not(current) and s.historical.size() == 1)
  run includeSiblingCounterexampleTest = initIgnoreAncestry.then(query(3, 8)).then(receive)
    .expect(not(completeAndScoped))
  run truncateCounterexampleTest = initTruncate.then(query(3, 2)).then(receive)
    .expect(not(completeAndScoped))
  run ignoreDescendantSourceCounterexampleTest = initIgnoreSource.then(query(3, 8)).then(revise).then(receive)
    .expect(not(admittedWhileCurrent))
  run ignoreDescendantGrantCounterexampleTest = initIgnoreGrant.then(query(3, 8)).then(changeGrant).then(receive)
    .expect(not(admittedWhileCurrent))
}
