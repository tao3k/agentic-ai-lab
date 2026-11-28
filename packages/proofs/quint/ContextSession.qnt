// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module ContextSession {
  const BUG: str
  var status: str -> str
  var rev: str -> int
  var nextTurn: str -> int
  var pending: str -> int
  var sourceCut: int
  var authorized: str -> bool
  var validatedCut: str -> int
  var proposals: str -> (str,int,int,int)
  var receipts: List[(str,int,int,int,int,bool,str)]
  var closedEver: Set[str]
  action init = all { status' = Set("s0","s1").mapBy(s => "absent"), rev' = Set("s0","s1").mapBy(s => 0), nextTurn' = Set("s0","s1").mapBy(s => 0), pending' = Set("s0","s1").mapBy(s => -1), authorized' = Set("s0","s1").mapBy(s => true), validatedCut' = Set("s0","s1").mapBy(s => -1), sourceCut' = 0, proposals' = Set("w0","w1").mapBy(w => ("",-1,-1,-1)), receipts' = List(), closedEver' = Set() }
  action create(s: str): bool = all { status.get(s) == "absent", status' = status.set(s,"active"), rev' = rev.set(s,rev.get(s)+1), nextTurn' = nextTurn, pending' = pending, sourceCut' = sourceCut, authorized' = authorized, validatedCut' = validatedCut, proposals' = proposals, receipts' = receipts, closedEver' = closedEver }
  action beginTurn(s: str): bool = all { status.get(s) == "active", pending.get(s) == -1, nextTurn.get(s) < 1, rev.get(s) < 4, status' = status, rev' = rev.set(s,rev.get(s)+1), nextTurn' = nextTurn.set(s,nextTurn.get(s)+1), pending' = pending.set(s,nextTurn.get(s)), sourceCut' = sourceCut, authorized' = authorized, validatedCut' = validatedCut, proposals' = proposals, receipts' = receipts, closedEver' = closedEver }
  action validate(s: str): bool = all { status.get(s) == "suspended", authorized.get(s), validatedCut.get(s) != sourceCut, status' = status, rev' = rev, nextTurn' = nextTurn, pending' = pending, sourceCut' = sourceCut, authorized' = authorized, validatedCut' = validatedCut.set(s,sourceCut), proposals' = proposals, receipts' = receipts, closedEver' = closedEver }
  action propose(w: str,s: str): bool = all { status.get(s) == "active", pending.get(s) != -1, proposals.get(w)._1 == "", status' = status, rev' = rev, nextTurn' = nextTurn, pending' = pending, sourceCut' = sourceCut, authorized' = authorized, validatedCut' = validatedCut, proposals' = proposals.set(w,(s,rev.get(s),pending.get(s),sourceCut)), receipts' = receipts, closedEver' = closedEver }
  action commit(w: str): bool = all { proposals.get(w)._1 != "", status.get(proposals.get(w)._1) == "active", (pending.get(proposals.get(w)._1) == proposals.get(w)._3 or BUG == "ignoreCAS"), (rev.get(proposals.get(w)._1) == proposals.get(w)._2 or BUG == "ignoreCAS"), (authorized.get(proposals.get(w)._1) or BUG == "ignoreAuth"), (sourceCut == proposals.get(w)._4 or BUG == "ignoreCut"), rev.get(proposals.get(w)._1) < 4, status' = status, rev' = rev.set(proposals.get(w)._1,rev.get(proposals.get(w)._1)+1), nextTurn' = nextTurn, pending' = pending.set(proposals.get(w)._1,-1), sourceCut' = sourceCut, authorized' = authorized, validatedCut' = validatedCut, proposals' = proposals.set(w,("",-1,-1,-1)), receipts' = receipts.append((proposals.get(w)._1,proposals.get(w)._2,proposals.get(w)._3,proposals.get(w)._4,sourceCut,authorized.get(proposals.get(w)._1),w)), closedEver' = closedEver }
  action advanceCut = all { sourceCut == 0, status' = status, rev' = rev, nextTurn' = nextTurn, pending' = pending, sourceCut' = 1, authorized' = authorized, validatedCut' = validatedCut, proposals' = proposals, receipts' = receipts, closedEver' = closedEver }
  action revoke(s: str): bool = all { Set("active","suspended").contains(status.get(s)), authorized.get(s), status' = status, rev' = rev, nextTurn' = nextTurn, pending' = pending, sourceCut' = sourceCut, authorized' = authorized.set(s,false), validatedCut' = validatedCut, proposals' = proposals, receipts' = receipts, closedEver' = closedEver }
  action suspend(s: str): bool = all { status.get(s) == "active", pending.get(s) == -1, rev.get(s) < 4, status' = status.set(s,"suspended"), rev' = rev.set(s,rev.get(s)+1), nextTurn' = nextTurn, pending' = pending, sourceCut' = sourceCut, authorized' = authorized, validatedCut' = validatedCut, proposals' = proposals, receipts' = receipts, closedEver' = closedEver }
  action resume(s: str): bool = all { (status.get(s) == "suspended" or (BUG == "resurrect" and status.get(s) == "closed")), authorized.get(s), validatedCut.get(s) == sourceCut, rev.get(s) < 4, status' = status.set(s,"active"), rev' = rev.set(s,rev.get(s)+1), nextTurn' = nextTurn, pending' = pending, sourceCut' = sourceCut, authorized' = authorized, validatedCut' = validatedCut, proposals' = proposals, receipts' = receipts, closedEver' = closedEver }
  action close(s: str): bool = all { Set("active","suspended").contains(status.get(s)), pending.get(s) == -1, rev.get(s) < 4, status' = status.set(s,"closed"), rev' = rev.set(s,rev.get(s)+1), nextTurn' = nextTurn, pending' = pending, sourceCut' = sourceCut, authorized' = authorized, validatedCut' = validatedCut, proposals' = proposals, receipts' = receipts, closedEver' = closedEver.union(Set(s)) }
  action step = { nondet s = Set("s0","s1").oneOf()
 nondet w = Set("w0","w1").oneOf()
 any { create(s),beginTurn(s),validate(s),revoke(s),suspend(s),resume(s),close(s),propose(w,s),commit(w),advanceCut } }
  val TypeOK = Set("s0","s1").forall(s => Set("absent","active","suspended","closed").contains(status.get(s)) and 0.to(4).contains(rev.get(s)) and 0.to(1).contains(nextTurn.get(s)) and Set(-1,0).contains(pending.get(s)) and Set(-1,0,1).contains(validatedCut.get(s))) and Set(0,1).contains(sourceCut) and closedEver.subseteq(Set("s0","s1"))
  val NoDoubleCommit = receipts.indices().forall(i => receipts.indices().forall(j => i == j or receipts.nth(i)._1 != receipts.nth(j)._1 or receipts.nth(i)._2 != receipts.nth(j)._2))
  val NoUnauthorizedCommit = receipts.foldl(true, (ok,r) => ok and (r._6))
  val NoMixedCut = receipts.foldl(true, (ok,r) => ok and (r._4 == r._5))
  val NoClosedResume = closedEver.forall(s => status.get(s) == "closed")
  val ExactTurn = receipts.foldl(true, (ok,r) => ok and (Set("s0","s1").contains(r._1) and r._3 < nextTurn.get(r._1)))
  val safety = and { TypeOK, NoDoubleCommit, NoUnauthorizedCommit, NoMixedCut, NoClosedResume, ExactTurn }
}
