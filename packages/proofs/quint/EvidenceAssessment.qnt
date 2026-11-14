// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module EvidenceAssessment {

  const BUG: bool
  import EvidenceSemantics(EVIDENCE = Set("source"), CLAIMS = Set("finding","report"),
    USES = Set(("source","finding")), DEPS = Set(("finding","report"))).* from "./EvidenceSemantics"
  val reviewers = Set("reviewerA","reviewerB")
  val verdicts = Set("supports","refutes","uncertain")
  var cited: Set[(str,str)]
  var reviews: Set[((str,str),str,str)]
  var active: Set[str]
  var withdrawn: Set[str]
  def assessment(u) = {
    val vs = reviews.filter(r => r._1 == u).map(r => r._3)
    if(withdrawn.contains(u._1)) "stale"
    else if(vs.size() == 0) "unreviewed"
    else if(vs.contains("supports") and vs.contains("refutes")) "contested"
    else if(vs.contains("uncertain")) "uncertain"
    else if(vs.contains("refutes")) "refuted" else "supported"
  }
  def localSupport(c) = useOf(c).intersect(cited).size() > 0 and useOf(c).intersect(cited).forall(u => assessment(u) == "supported")
  def parentSupport(c) = active.exists(p => DEPS.contains((p,c)))
  action init = {  all { cited' = Set(), reviews' = Set(), active' = Set(), withdrawn' = Set() } }
  action citeUse = { nondet u = USES.oneOf()
 all { not(cited.contains(u)) and not(withdrawn.contains(u._1)), cited' = cited.union(Set(u)), reviews' = reviews, active' = active.exclude(closure(Set(u._2))), withdrawn' = withdrawn } }
  action review = { nondet u = USES.oneOf()
nondet reviewer = reviewers.oneOf()
nondet verdict = verdicts.oneOf()
 all { cited.contains(u) and not(withdrawn.contains(u._1)) and not(reviews.exists(r => r._1 == u and r._2 == reviewer)), cited' = cited, reviews' = reviews.union(Set((u,reviewer,verdict))), active' = if(BUG) active else active.exclude(closure(Set(u._2))), withdrawn' = withdrawn } }
  action admitClaim = { nondet c = CLAIMS.oneOf()
 all { not(active.contains(c)) and (localSupport(c) or parentSupport(c)) and useOf(c).intersect(cited).forall(u => assessment(u) == "supported"), cited' = cited, reviews' = reviews, active' = active.union(Set(c)), withdrawn' = withdrawn } }
  action withdraw = { nondet e = EVIDENCE.oneOf()
 all { not(withdrawn.contains(e)), cited' = cited, reviews' = reviews, active' = active.exclude(affected(e,cited)), withdrawn' = withdrawn.union(Set(e)) } }

  action step = any { citeUse, review, admitClaim, withdraw }
  val TypeInvariant = and { dataWellFormed, reviewers.size() > 0, cited.subseteq(USES), active.subseteq(CLAIMS), withdrawn.subseteq(EVIDENCE),
    reviews.forall(r => USES.contains(r._1) and reviewers.contains(r._2) and verdicts.contains(r._3)) }
  val ActiveAssessmentInvariant = active.forall(c => useOf(c).intersect(cited).forall(u => assessment(u) == "supported") and (localSupport(c) or parentSupport(c)))
  val WithdrawnSourceInvariant = withdrawn.forall(e => active.intersect(affected(e,cited)).size() == 0)
  val safety = and { TypeInvariant, ActiveAssessmentInvariant, WithdrawnSourceInvariant }

}
