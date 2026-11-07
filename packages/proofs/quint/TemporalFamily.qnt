// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module TemporalFamily {

  const OBS: Set[(str, str, int, str, str)]
  const LIMIT: int
  const EXPECTED: Set[str]
  const BUG: bool
  const CONSTRAINTS: Set[(str,str,str,str,str)]
  val hypotheses = Set(("via-a", "source-a", "result"), ("via-b", "source-b", "result"))
  val constraints = CONSTRAINTS
  val ids = hypotheses.map(h => h._1)
  val domains = Set("timeline")
  val observationIds = OBS.map(o => o._1)
  def observation(id) = OBS.filter(o => o._1 == id).fold(("","",0,"",""), (_a,o) => o)
  def order(left: str, right: str, relation: str): str = {
    val a = observation(left)
    val b = observation(right)
    if (not(observationIds.contains(left) and observationIds.contains(right)) or
        a._5 != "observed" or b._5 != "observed" or a._2 != b._2) "unknown"
    else if ((relation == "before" and a._3 < b._3) or
             (relation == "not-after" and a._3 <= b._3)) "admitted" else "refuted"
  }
  def status(id: str): str = {
    val h = hypotheses.filter(h => h._1 == id).fold(("","",""), (_a,h) => h)
    val statuses = constraints.filter(c => c._2 == h._1).map(c => order(c._4,c._5,c._3))
      .union(Set(order(h._2,h._3,"before")))
    if (statuses.contains("refuted")) "refuted"
    else if (statuses.contains("unknown")) "unknown" else "admitted"
  }
  val effectiveLimit = if (LIMIT == 0) ids.size() else LIMIT
  var remaining: Set[str]
  var admitted: Set[str]
  var refuted: Set[str]
  var unknown: Set[str]
  val explored = admitted.union(refuted).union(unknown)
  action init = all { remaining' = ids, admitted' = Set(), refuted' = Set(), unknown' = Set() }
  action explore = {
    nondet id = remaining.oneOf()
    all { explored.size() < effectiveLimit, remaining' = remaining.exclude(Set(id)),
      admitted' = if (status(id) == "admitted") admitted.union(Set(id)) else admitted,
      refuted' = if (status(id) == "refuted") refuted.union(Set(id)) else refuted,
      unknown' = if (status(id) == "unknown") unknown.union(Set(id)) else unknown }
  }
  val terminal = remaining.size() == 0 or explored.size() == effectiveLimit
  action finish = all { terminal, remaining' = remaining, admitted' = admitted,
    refuted' = refuted, unknown' = unknown }
  action step = any { explore, finish }
  val classification = if (refuted.contains("via-a")) "refuted"
    else if (admitted.contains("via-a")) {
      if (BUG or (remaining.size() == 0 and unknown.size() == 0 and admitted.size() == 1))
        "necessary" else "possible"
    } else "unknown"
  val InputInvariant = and { hypotheses.size() > 0, ids.size() == hypotheses.size(),
    observationIds.size() == OBS.size(), OBS.forall(o => domains.contains(o._2)),
    observationIds.exists(effect => hypotheses.forall(h => h._3 == effect)), LIMIT >= 0,
    constraints.forall(c => ids.contains(c._2) and Set("before","not-after").contains(c._3)),
    EXPECTED.subseteq(Set("possible","necessary","refuted","unknown")) }
  val PartitionInvariant = and { remaining.union(explored) == ids,
    remaining.intersect(explored).size() == 0, admitted.intersect(refuted).size() == 0,
    admitted.intersect(unknown).size() == 0, refuted.intersect(unknown).size() == 0 }
  val StatusInvariant = and { admitted.forall(id => status(id) == "admitted"),
    refuted.forall(id => status(id) == "refuted"), unknown.forall(id => status(id) == "unknown") }
  val BoundInvariant = explored.size() <= effectiveLimit
  val TerminalAgreement = terminal implies EXPECTED.contains(classification)
  val safety = and { InputInvariant, PartitionInvariant, StatusInvariant, BoundInvariant, TerminalAgreement }
  temporal eventuallyTerminal = explore.weakFair((remaining,admitted,refuted,unknown)) implies terminal.eventually()

}
