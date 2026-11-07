// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// A/B -> C -> D. One selective revision of A/C/D; exact scope fixed.
// Parent identities and attempt admission are qualified in the separate kernels.
module SearchDag {
  const BUG: str
  val nodes = Set(0,1,2,3)
  val parents = List(Set(), Set(), Set(0,1), Set(2))
  val affected = Set(0,2,3)
  var revision: int
  var active: Set[int]
  var done: Set[int]
  var issuedRevision: List[int]
  var completedRevision: List[int]
  var dependencySafe: bool
  var retentionSafe: bool
  action init = all { revision' = 0, active' = Set(), done' = Set(),
    issuedRevision' = List(-1,-1,-1,-1), completedRevision' = List(-1,-1,-1,-1),
    dependencySafe' = true, retentionSafe' = true }
  def version(node: int): int = if (node == 1) 0 else revision
  action issue(node: int): bool = all {
    not(active.contains(node)), not(done.contains(node)),
    (parents.nth(node).forall(parent => done.contains(parent)) or BUG == "ignoreParents"),
    active' = active.union(Set(node)), done' = done,
    issuedRevision' = issuedRevision.replaceAt(node, version(node)),
    completedRevision' = completedRevision, revision' = revision,
    dependencySafe' = (dependencySafe and parents.nth(node).forall(parent => done.contains(parent))),
    retentionSafe' = retentionSafe }
  action complete(node: int, requestRevision: int): bool = all {
    active.contains(node), requestRevision == issuedRevision.nth(node),
    (requestRevision == version(node) or BUG == "ignoreFreshness"),
    done' = done.union(Set(node)), active' = active.exclude(Set(node)),
    completedRevision' = completedRevision.replaceAt(node, requestRevision),
    issuedRevision' = issuedRevision, revision' = revision,
    dependencySafe' = dependencySafe, retentionSafe' = retentionSafe }
  action revise = all {
    revision == 0, revision' = 1,
    active' = if (BUG == "ignoreFreshness") active else active.exclude(affected),
    done' = if (BUG == "clearAll") Set() else done.exclude(affected),
    issuedRevision' = issuedRevision, completedRevision' = completedRevision,
    dependencySafe' = dependencySafe,
    retentionSafe' = (retentionSafe and (not(done.contains(1)) or BUG != "clearAll")) }
  action step = {
    nondet node = nodes.oneOf()
    nondet requestRevision = Set(0,1).oneOf()
    any { issue(node), complete(node,requestRevision), revise }
  }
  val DependencyOrder = dependencySafe
  val FreshResults = done.forall(node => completedRevision.nth(node) == version(node))
  val BranchRetention = retentionSafe
  val safety = DependencyOrder and FreshResults and BranchRetention
}
