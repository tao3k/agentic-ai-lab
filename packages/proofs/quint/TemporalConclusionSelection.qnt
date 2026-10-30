// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module TemporalConclusionSelection {

  const BUG: bool
  val revisions = Set("c1","c2","c3")
  val proposals = Set(("c2","c1",7,"proof-2"),("c3","c1",7,"proof-3"))
  val ids = proposals.map(p => p._1)
  var selected: str
  var version: int
  var attempted: Set[str]
  var committed: Set[str]
  var conflicted: Set[str]
  action init = all { selected' = "c1", version' = 7, attempted' = Set(), committed' = Set(), conflicted' = Set() }
  def canCommit(p) = not(attempted.contains(p._1)) and (BUG or (selected == p._2 and version == p._3))
  action resolve = {
    nondet p = proposals.filter(p => not(attempted.contains(p._1))).oneOf()
    all { attempted' = attempted.union(Set(p._1)),
      selected' = if(canCommit(p)) p._1 else selected,
      version' = if(canCommit(p)) version + 1 else version,
      committed' = if(canCommit(p)) committed.union(Set(p._1)) else committed,
      conflicted' = if(canCommit(p)) conflicted else conflicted.union(Set(p._1)) }
  }
  val terminal = attempted == ids
  action finish = all { terminal, selected' = selected, version' = version, attempted' = attempted,
    committed' = committed, conflicted' = conflicted }
  action step = any { resolve, finish }
  val InputInvariant = proposals.forall(p => revisions.contains(p._1) and p._1 != "c1" and p._2 == "c1" and p._3 == 7 and p._4 != "")
  val PartitionInvariant = attempted == committed.union(conflicted) and committed.intersect(conflicted).size() == 0 and attempted.subseteq(ids)
  val AtMostOneCommit = committed.size() <= 1
  val VersionInvariant = version == 7 + committed.size()
  val SelectionInvariant = if(committed.size() == 0) selected == "c1" else committed.contains(selected)
  val StaleProposalConflicts = terminal implies conflicted == ids.exclude(committed)
  val safety = and { InputInvariant, PartitionInvariant, AtMostOneCommit, VersionInvariant, SelectionInvariant, StaleProposalConflicts }
  temporal eventuallyResolved = resolve.weakFair((selected,version,attempted,committed,conflicted)) implies terminal.eventually()

}
