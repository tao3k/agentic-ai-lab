// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// Finite projection of the pure per-stage Scheme attempt kernel.
module SearchAttempt {
  const BUG: str
  var revision: int
  var nextAttempt: int
  var active: int
  var retired: bool
  var lostNew: bool
  var accepted: List[(int,int,int,int,bool)]
  action init = all { revision' = 0, nextAttempt' = 0, active' = -1,
    retired' = false, lostNew' = false, accepted' = List() }
  action issue = all { not(retired), active == -1, nextAttempt < 3,
    active' = nextAttempt, nextAttempt' = nextAttempt + 1,
    revision' = revision, retired' = retired, accepted' = accepted, lostNew' = lostNew }
  action settle(requestRevision: int, attempt: int): bool = all {
    (not(retired) or BUG == "ignoreRetired"), active >= 0,
    (requestRevision == revision or BUG == "ignoreRevision"),
    (attempt == active or BUG == "ignoreAttempt"), accepted.length() < 2,
    accepted' = accepted.append((requestRevision, revision, attempt, active, retired)),
    active' = -1, nextAttempt' = nextAttempt, revision' = revision, retired' = retired, lostNew' = lostNew
  }
  action revise = all { not(retired), revision < 1,
    revision' = revision + 1, active' = -1, nextAttempt' = nextAttempt,
    retired' = retired, accepted' = accepted, lostNew' = lostNew }
  action retire = all { not(retired), retired' = true,
    revision' = revision, active' = active, nextAttempt' = nextAttempt, accepted' = accepted, lostNew' = lostNew }
  action cancel(requestRevision: int, attempt: int): bool = all {
    not(retired), revision < 2, active >= 0,
    ((requestRevision == revision and attempt == active) or BUG == "cancelAny"),
    revision' = revision + 1, active' = -1, nextAttempt' = nextAttempt,
    retired' = retired, accepted' = accepted,
    lostNew' = (lostNew or (requestRevision != revision or attempt != active))
  }
  action step = {
    nondet r = Set(0,1,2).oneOf()
    nondet a = Set(0,1,2).oneOf()
    any { issue, settle(r,a), cancel(r,a), revise, retire }
  }
  val CurrentRevision = accepted.foldl(true, (ok,r) => ok and r._1 == r._2)
  val ExactAttempt = accepted.foldl(true, (ok,r) => ok and r._3 == r._4)
  val NoRetiredAdmission = accepted.foldl(true, (ok,r) => ok and not(r._5))
  val OncePerAttempt = accepted.indices().forall(i => accepted.indices().forall(j => i == j or accepted.nth(i)._3 != accepted.nth(j)._3))
  val NoStaleCancellation = not(lostNew)
  val safety = NoStaleCancellation and CurrentRevision and ExactAttempt and NoRetiredAdmission and OncePerAttempt
}
