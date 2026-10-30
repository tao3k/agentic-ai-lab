// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// One stage, two revisions, finite event identities; request scope is modeled separately.
module SearchEvidenceHistory {
  const BUG: str
  var revision: int
  var active: bool
  var done: bool
  var used: Set[int]
  var admitted: List[int]
  action init = all { revision' = 0, active' = false, done' = false,
    used' = Set(), admitted' = List() }
  action issue = all { not(active), not(done),
    active' = true, done' = done, revision' = revision, used' = used, admitted' = admitted }
  action observe(identity: int): bool = all {
    active, admitted.length() < 2,
    (not(used.contains(identity)) or BUG == "ignoreUsed"),
    active' = false, done' = true, revision' = revision,
    used' = used.union(Set(identity)), admitted' = admitted.append(identity) }
  action revise = all { revision == 0, revision' = 1, active' = false, done' = false,
    used' = if (BUG == "clearHistory") Set() else used, admitted' = admitted }
  action terminal = all { done, revision == 1, active' = active, done' = done,
    revision' = revision, used' = used, admitted' = admitted }
  action step = {
    nondet identity = Set(0,1).oneOf()
    any { issue, observe(identity), revise, terminal }
  }
  val UniqueEventAdmission = admitted.indices().forall(i =>
    admitted.indices().forall(j => i == j or admitted.nth(i) != admitted.nth(j)))
  val HistoryRetention = admitted.indices().forall(i => used.contains(admitted.nth(i)))
  val safety = UniqueEventAdmission and HistoryRetention
}
