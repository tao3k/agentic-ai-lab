// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module TemporalRevision {

  val revisions = Set(("r1","subject","assert","",10,1,5),
    ("r2","subject","correct","r1",20,2,6),("r3","subject","correct","r1",22,2,6),
    ("r4","subject","retract","r2",30,0,0))
  val ids = revisions.map(r => r._1)
  def revision(id) = revisions.filter(r => r._1 == id).fold(("","","","",0,0,0), (_a,r) => r)
  def heads(selected) = selected.filter(id => not(selected.exists(child => revision(child)._4 == id)))
  def subjectHeads(selected, subject) = heads(selected).filter(id => revision(id)._2 == subject)
  def activeAt(selected, subject, validAt) = {
    val hs = subjectHeads(selected, subject)
    if (hs.size() == 1) hs.filter(id => revision(id)._3 != "retract" and
      revision(id)._6 <= validAt and validAt < revision(id)._7) else Set()
  }
  var admitted: Set[str]
  val historicalCut = admitted.filter(id => revision(id)._5 <= 15)
  val currentHeads = subjectHeads(admitted,"subject")
  val currentActive = activeAt(admitted,"subject",3)
  val terminal = admitted == ids
  action init = admitted' = Set()
  action admitRevision = {
    nondet id = ids.exclude(admitted).oneOf()
    all { revision(id)._4 == "" or admitted.contains(revision(id)._4), admitted' = admitted.union(Set(id)) }
  }
  action finish = all { terminal, admitted' = admitted }
  action step = any { admitRevision, finish }
  val InputInvariant = and { revisions.size() > 0, ids.size() == revisions.size(),
    revisions.forall(r => r._5 >= 0 and Set("assert","correct","retract").contains(r._3) and
      (if (r._3 == "assert") r._4 == "" and r._6 >= 0 and r._6 < r._7
       else ids.contains(r._4) and revision(r._4)._2 == r._2 and revision(r._4)._3 != "retract" and
         revision(r._4)._5 < r._5 and (if(r._3 == "retract") r._6 == 0 and r._7 == 0 else r._6 >= 0 and r._6 < r._7))),
    ids.contains("r1"), revision("r1")._5 <= 15,
    ids.exclude(Set("r1")).forall(id => revision(id)._5 > 15) }
  val HistoryInvariant = admitted.subseteq(ids)
  val HistoricalCutInvariant = admitted.contains("r1") implies historicalCut == Set("r1")
  val NoSilentWinner = currentHeads.size() > 1 implies currentActive.size() == 0
  val ActiveIsHead = currentActive.subseteq(currentHeads)
  val safety = and { InputInvariant, HistoryInvariant, HistoricalCutInvariant, NoSilentWinner, ActiveIsHead }
  temporal eventuallyComplete = admitRevision.weakFair(admitted) implies terminal.eventually()

}
