// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// A/B -> C evidence projection. Exact attempts/revision are separate joined kernels.
module SearchEvidence {
  const BUG: str
  val nodes = Set(0,1,2)
  val parents = List(Set(),Set(),Set(0,1))
  var active: Set[int]
  var done: Set[int]
  var parentSafe: bool
  var scopeSafe: bool
  var timeSafe: bool
  var committedSafe: bool
  action init = all { active' = Set(), done' = Set(), parentSafe' = true,
    scopeSafe' = true, timeSafe' = true, committedSafe' = true }
  action issue(node: int): bool = all {
    not(active.contains(node)), not(done.contains(node)),
    parents.nth(node).forall(p => done.contains(p)),
    active' = active.union(Set(node)), done' = done,
    parentSafe' = parentSafe, scopeSafe' = scopeSafe, timeSafe' = timeSafe,
    committedSafe' = committedSafe }
  action observe(node: int, exactParents: bool, sameScope: bool,
                 ordered: bool, committed: bool): bool = all {
    active.contains(node),
    (exactParents or BUG == "ignoreParents"),
    (sameScope or BUG == "ignoreScope"),
    (ordered or BUG == "ignoreTime"),
    (committed or BUG == "ignoreCommitted"),
    active' = active.exclude(Set(node)), done' = done.union(Set(node)),
    parentSafe' = (parentSafe and exactParents), scopeSafe' = (scopeSafe and sameScope),
    timeSafe' = (timeSafe and ordered), committedSafe' = (committedSafe and committed) }
  action terminal = all {
    done == nodes, active' = active, done' = done, parentSafe' = parentSafe,
    scopeSafe' = scopeSafe, timeSafe' = timeSafe, committedSafe' = committedSafe }
  action step = {
    nondet node = nodes.oneOf()
    nondet exactParents = Set(true,false).oneOf()
    nondet sameScope = Set(true,false).oneOf()
    nondet ordered = Set(true,false).oneOf()
    nondet committed = Set(true,false).oneOf()
    any { issue(node), observe(node,exactParents,sameScope,ordered,committed), terminal }
  }
  val ExactCausalParents = parentSafe
  val ObservationScope = scopeSafe
  val TemporalOrder = timeSafe
  val CommittedEvidence = committedSafe
  val safety = ExactCausalParents and ObservationScope and TemporalOrder and CommittedEvidence
}
