// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module ContextDelta {
  const BUG: str
  var cut: int
  var rev: int
  var grant: bool
  var proposals: str -> (int,int,int)
  var selected: int
  var publications: List[(int,int,int,int)]
  var uses: List[(int,int,bool)]
  // Independent full target fixture: cut 0 has [10,20], cut 1 deletes 10 and inserts 30.
  pure def full(c: int): List[int] = if (c == 0) List(10,20) else List(20,30)
  def reconstruct(c: int): List[int] = if (c == 0) List(10,20) else
    if (BUG == "ignoreDelete") List(10,20,30) else List(20,30)
  action init = all {
    cut' = 0, rev' = 0, grant' = true, selected' = -1,
    proposals' = Set("w0","w1").mapBy(w => (-1,-1,-1)),
    publications' = List(), uses' = List()
  }
  action prepare(w: str): bool = all {
    proposals.get(w)._1 == -1, rev < 2,
    proposals' = proposals.set(w,(rev,cut,cut)),
    cut' = cut, rev' = rev, grant' = grant, selected' = selected,
    publications' = publications, uses' = uses
  }
  action advance = all {
    cut == 0, cut' = 1, rev' = rev, grant' = grant, selected' = selected,
    proposals' = proposals, publications' = publications, uses' = uses
  }
  action publish(w: str): bool = all {
    proposals.get(w)._1 >= 0, rev < 2,
    (proposals.get(w)._1 == rev or BUG == "ignoreCAS"),
    (proposals.get(w)._2 == cut or BUG == "ignoreCut"),
    (reconstruct(proposals.get(w)._3) == full(proposals.get(w)._3) or BUG == "ignoreDelete"),
    publications' = publications.append((proposals.get(w)._1, proposals.get(w)._2, cut,
      if (reconstruct(proposals.get(w)._3) == full(proposals.get(w)._3)) 1 else 0)),
    selected' = proposals.get(w)._3, rev' = rev + 1,
    proposals' = proposals.set(w,(-1,-1,-1)), cut' = cut, grant' = grant, uses' = uses
  }
  action revoke = all {
    grant, grant' = false, cut' = cut, rev' = rev, selected' = selected,
    proposals' = proposals, publications' = publications, uses' = uses
  }
  action consume = all {
    selected >= 0, uses.length() < 2,
    (selected == cut or BUG == "ignoreUseCut"), (grant or BUG == "ignoreGrant"),
    uses' = uses.append((selected,cut,grant)), cut' = cut, rev' = rev,
    selected' = selected, grant' = grant, proposals' = proposals, publications' = publications
  }
  action step = {
    nondet w = Set("w0","w1").oneOf()
    any { prepare(w), advance, publish(w), revoke, consume }
  }
  val ExactTargetCut = publications.foldl(true, (ok,r) => ok and r._2 == r._3)
  val ExactReconstruction = publications.foldl(true, (ok,r) => ok and r._4 == 1)
  val OnePublication = publications.indices().forall(i => publications.indices().forall(j =>
    i == j or publications.nth(i)._1 != publications.nth(j)._1))
  val CurrentConsumption = uses.foldl(true, (ok,r) => ok and r._1 == r._2)
  val AuthorizedConsumption = uses.foldl(true, (ok,r) => ok and r._3)
  val safety = ExactTargetCut and ExactReconstruction and OnePublication and CurrentConsumption and AuthorizedConsumption
}
