// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module SessionAttempt {
  const BUG: str
  var generation: int
  var active: int
  var pending: int
  var everClosed: bool
  var closed: bool
  var routed: List[(int,int)]
  var recoveries: List[(int,int)]
  action init = all { generation' = 0, active' = -1, pending' = -1,
    closed' = false, everClosed' = false, routed' = List(), recoveries' = List() }
  action claim = all {
    not(closed), active == -1, pending == -1, generation < 3,
    generation' = generation + 1, active' = generation + 1,
    pending' = pending, closed' = closed, everClosed' = everClosed, routed' = routed, recoveries' = recoveries
  }
  action complete(requestGeneration: int): bool = all {
    active >= 0, routed.length() < 2,
    (requestGeneration == active or BUG == "ignoreGeneration"),
    routed' = routed.append((requestGeneration,active)), active' = -1,
    generation' = generation, pending' = pending, closed' = closed, everClosed' = everClosed, recoveries' = recoveries
  }
  action recover = all {
    (not(closed) or BUG == "resumeClosed"), generation < 3, recoveries.length() < 2,
    generation' = generation + 1, active' = -1, closed' = false, everClosed' = everClosed,
    pending' = if (BUG == "dropObligation") -1 else if (active >= 0) active else pending,
    recoveries' = recoveries.append((if (active >= 0) active else pending,
      if (BUG == "dropObligation") -1 else if (active >= 0) active else pending)),
    routed' = routed
  }
  action reconcile = all {
    pending >= 0, pending' = -1, active' = active, generation' = generation,
    closed' = closed, everClosed' = everClosed, routed' = routed, recoveries' = recoveries
  }
  action close = all {
    not(closed), active == -1, pending == -1, closed' = true, everClosed' = true,
    generation' = generation, active' = active, pending' = pending,
    routed' = routed, recoveries' = recoveries
  }
  action step = {
    nondet requestGeneration = Set(0,1,2,3).oneOf()
    any { claim, complete(requestGeneration), recover, reconcile, close }
  }
  val ExactAttempt = routed.foldl(true, (ok,r) => ok and r._1 == r._2)
  val RecoveryPreservesObligation = recoveries.foldl(true, (ok,r) => ok and (r._1 < 0 or r._1 == r._2))
  val ClosedIsTerminal = not(everClosed) or closed
  val safety = ExactAttempt and RecoveryPreservesObligation and ClosedIsTerminal
}
