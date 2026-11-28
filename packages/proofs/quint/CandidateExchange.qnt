// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module CandidateExchange {

  const BUG: bool
  val candidates = Set("c1")
  val cuts = Set("cutA","cutB")
  val verdicts = Set("valid","invalid")
  val maxGeneration = 1
  var generation: int
  var cut: str
  var covered: bool
  var gqlReceipts: Set[(int,str,str,bool)]
  var ascentReceipts: Set[(int,str,str,bool)]
  var gqlChecks: Set[(int,str,str,str)]
  var ascentChecks: Set[(int,str,str,str)]
  var contested: Set[str]
  var reviewable: Set[str]
  def uniqueReceipt(rs,c) = rs.forall(r => r._1 != generation or r._2 != cut or r._3 != c)
  def uniqueCheck(cs,c) = cs.forall(r => r._1 != generation or r._2 != cut or r._3 != c)
  def requiredComplete(c) = gqlReceipts.contains((generation,cut,c,true)) and gqlChecks.contains((generation,cut,c,"valid")) and
    ascentReceipts.contains((generation,cut,c,true)) and ascentChecks.contains((generation,cut,c,"valid"))
  action init = {  all { generation' = 0, cut' = "cutA", covered' = false, gqlReceipts' = Set(), ascentReceipts' = Set(), gqlChecks' = Set(), ascentChecks' = Set(), contested' = Set(), reviewable' = Set() } }
  action gqlCandidate = { nondet c = candidates.oneOf()
nondet complete = Set(true,false).oneOf()
 all { uniqueReceipt(gqlReceipts,c), generation' = generation, cut' = cut, covered' = covered, gqlReceipts' = gqlReceipts.union(Set((generation,cut,c,complete))), ascentReceipts' = ascentReceipts, gqlChecks' = gqlChecks, ascentChecks' = ascentChecks, contested' = contested, reviewable' = reviewable } }
  action gqlCheck = { nondet c = candidates.oneOf()
nondet verdict = verdicts.oneOf()
 all { (gqlReceipts.contains((generation,cut,c,true)) or gqlReceipts.contains((generation,cut,c,false))) and uniqueCheck(gqlChecks,c), generation' = generation, cut' = cut, covered' = covered, gqlReceipts' = gqlReceipts, ascentReceipts' = ascentReceipts, gqlChecks' = gqlChecks.union(Set((generation,cut,c,verdict))), ascentChecks' = ascentChecks, contested' = contested, reviewable' = reviewable } }
  action ascentCandidate = { nondet c = candidates.oneOf()
nondet complete = Set(true,false).oneOf()
 all { uniqueReceipt(ascentReceipts,c), generation' = generation, cut' = cut, covered' = covered, gqlReceipts' = gqlReceipts, ascentReceipts' = ascentReceipts.union(Set((generation,cut,c,complete))), gqlChecks' = gqlChecks, ascentChecks' = ascentChecks, contested' = contested, reviewable' = reviewable } }
  action ascentCheck = { nondet c = candidates.oneOf()
nondet verdict = verdicts.oneOf()
 all { (ascentReceipts.contains((generation,cut,c,true)) or ascentReceipts.contains((generation,cut,c,false))) and uniqueCheck(ascentChecks,c), generation' = generation, cut' = cut, covered' = covered, gqlReceipts' = gqlReceipts, ascentReceipts' = ascentReceipts, gqlChecks' = gqlChecks, ascentChecks' = ascentChecks.union(Set((generation,cut,c,verdict))), contested' = contested, reviewable' = reviewable } }
  action declareCoverage = {  all { not(covered), generation' = generation, cut' = cut, covered' = true, gqlReceipts' = gqlReceipts, ascentReceipts' = ascentReceipts, gqlChecks' = gqlChecks, ascentChecks' = ascentChecks, contested' = contested, reviewable' = reviewable } }
  action conflictingReceipt = { nondet c = candidates.oneOf()
 all { not(contested.contains(c)) and (gqlReceipts.union(ascentReceipts).exists(r => r._1 == generation and r._2 == cut and r._3 == c)), generation' = generation, cut' = cut, covered' = covered, gqlReceipts' = gqlReceipts, ascentReceipts' = ascentReceipts, gqlChecks' = gqlChecks, ascentChecks' = ascentChecks, contested' = contested.union(Set(c)), reviewable' = reviewable.exclude(Set(c)) } }
  action conflictingCheck = { nondet c = candidates.oneOf()
 all { not(contested.contains(c)) and (gqlChecks.contains((generation,cut,c,"valid")) or ascentChecks.contains((generation,cut,c,"valid"))), generation' = generation, cut' = cut, covered' = covered, gqlReceipts' = gqlReceipts, ascentReceipts' = ascentReceipts, gqlChecks' = gqlChecks, ascentChecks' = ascentChecks, contested' = contested.union(Set(c)), reviewable' = reviewable.exclude(Set(c)) } }
  action markReviewable = { nondet c = candidates.oneOf()
 all { not(reviewable.contains(c)) and not(contested.contains(c)) and (BUG or covered) and requiredComplete(c), generation' = generation, cut' = cut, covered' = covered, gqlReceipts' = gqlReceipts, ascentReceipts' = ascentReceipts, gqlChecks' = gqlChecks, ascentChecks' = ascentChecks, contested' = contested, reviewable' = reviewable.union(Set(c)) } }
  action revise = { nondet nextCut = cuts.oneOf()
 all { generation < maxGeneration, generation' = generation+1, cut' = nextCut, covered' = false, gqlReceipts' = gqlReceipts, ascentReceipts' = ascentReceipts, gqlChecks' = gqlChecks, ascentChecks' = ascentChecks, contested' = Set(), reviewable' = Set() } }

  action step = any { gqlCandidate, ascentCandidate, gqlCheck, ascentCheck, declareCoverage,
    conflictingReceipt, conflictingCheck, markReviewable, revise }
  val TypeInvariant = and { generation >= 0, generation <= maxGeneration, cuts.contains(cut),
    contested.subseteq(candidates), reviewable.subseteq(candidates),
    gqlReceipts.union(ascentReceipts).forall(r => r._1 >= 0 and r._1 <= maxGeneration and cuts.contains(r._2) and candidates.contains(r._3)),
    gqlChecks.union(ascentChecks).forall(r => r._1 >= 0 and r._1 <= maxGeneration and cuts.contains(r._2) and candidates.contains(r._3) and verdicts.contains(r._4)) }
  val ReviewabilityInvariant = reviewable.forall(c => covered and requiredComplete(c) and not(contested.contains(c)))
  val CoverageInvariant = not(covered) implies reviewable.size() == 0
  val ContestInvariant = contested.intersect(reviewable).size() == 0
  def receiptsUnique(rs) = rs.forall(a => rs.forall(b => (a._1 == b._1 and a._2 == b._2 and a._3 == b._3) implies a == b))
  def checksUnique(cs) = cs.forall(a => cs.forall(b => (a._1 == b._1 and a._2 == b._2 and a._3 == b._3) implies a == b))
  val ReceiptUniquenessInvariant = receiptsUnique(gqlReceipts) and receiptsUnique(ascentReceipts)
  val CheckUniquenessInvariant = checksUnique(gqlChecks) and checksUnique(ascentChecks)
  val safety = and { TypeInvariant, ReviewabilityInvariant, CoverageInvariant, ContestInvariant, ReceiptUniquenessInvariant, CheckUniquenessInvariant }

}
