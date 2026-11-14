// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// Prospective joint lifecycle protocol, not a delivered provider/Data runtime.
module ContextTemporalLifecycle {
  const BUG: str
  var sourceVersion: int
  var temporalVersion: int
  var policyVersion: int
  var prepared: bool
  var preparedCut: (int,int,int)
  var supported: bool
  var retired: bool
  var wasRetired: bool
  var now: int
  var clockDomain: int
  var uncertain: bool
  var committed: bool
  var pending: bool
  var commitRows: List[((int,int,int),(int,int,int),int,int,bool,bool,bool)]
  var recoveryRows: List[(bool,bool)]
  action init = all {
    sourceVersion' = 0, temporalVersion' = 0, policyVersion' = 0,
    prepared' = false, preparedCut' = (0,0,0), supported' = true,
    retired' = false, wasRetired' = false, now' = 0, clockDomain' = 0,
    uncertain' = false, committed' = false, pending' = false,
    commitRows' = List(), recoveryRows' = List()
  }
  val currentCut = (sourceVersion,temporalVersion,policyVersion)
  pure def withinWindow(t: int, spread: bool): bool = t + (if (spread) 1 else 0) < 2
  action prepare = all {
    not(retired), not(committed), not(pending), not(prepared),
    prepared' = true, preparedCut' = currentCut,
    sourceVersion' = sourceVersion, temporalVersion' = temporalVersion, policyVersion' = policyVersion,
    supported' = supported, retired' = retired, wasRetired' = wasRetired,
    now' = now, clockDomain' = clockDomain, uncertain' = uncertain,
    committed' = committed, pending' = pending, commitRows' = commitRows, recoveryRows' = recoveryRows
  }
  action commit = all {
    prepared, not(committed), not(pending), not(retired),
    (preparedCut._1 == sourceVersion or BUG == "ignoreSource"),
    (preparedCut._2 == temporalVersion or BUG == "ignoreTemporal"),
    (preparedCut._3 == policyVersion or BUG == "ignorePolicy"),
    (supported or BUG == "ignoreEvidence"),
    (clockDomain == 0 or BUG == "ignoreDomain"),
    (withinWindow(now,uncertain) or (BUG == "ignoreUncertainty" and now < 2)),
    commitRows' = commitRows.append((preparedCut,currentCut,now,clockDomain,uncertain,supported,retired)),
    committed' = true, prepared' = false, pending' = pending,
    preparedCut' = preparedCut, sourceVersion' = sourceVersion, temporalVersion' = temporalVersion,
    policyVersion' = policyVersion, supported' = supported, retired' = retired, wasRetired' = wasRetired,
    now' = now, clockDomain' = clockDomain, uncertain' = uncertain, recoveryRows' = recoveryRows
  }
  action revise(which: int, refuted: bool): bool = all {
    which.in(Set(0,1,2)),
    if (which == 0) sourceVersion == 0 else if (which == 1) temporalVersion == 0 else policyVersion == 0,
    sourceVersion' = if (which == 0) 1 else sourceVersion,
    temporalVersion' = if (which == 1) 1 else temporalVersion,
    policyVersion' = if (which == 2) 1 else policyVersion,
    supported' = if (which == 1 and refuted) false else supported,
    pending' = ((committed and (recoveryRows.length() == 0 or BUG == "reviveObligation")) or pending),
    prepared' = prepared, preparedCut' = preparedCut, retired' = retired, wasRetired' = wasRetired,
    now' = now, clockDomain' = clockDomain, uncertain' = uncertain,
    committed' = committed, commitRows' = commitRows, recoveryRows' = recoveryRows
  }
  action observe(which: int): bool = all {
    which.in(Set(0,1,2)),
    if (which == 0) now < 2 else if (which == 1) clockDomain == 0 else not(uncertain),
    now' = if (which == 0) now + 1 else now,
    clockDomain' = if (which == 1) 1 else clockDomain,
    uncertain' = if (which == 2) true else uncertain,
    sourceVersion' = sourceVersion, temporalVersion' = temporalVersion, policyVersion' = policyVersion,
    prepared' = prepared, preparedCut' = preparedCut, supported' = supported,
    retired' = retired, wasRetired' = wasRetired, committed' = committed, pending' = pending,
    commitRows' = commitRows, recoveryRows' = recoveryRows
  }
  action retire = all {
    not(retired), retired' = true, wasRetired' = true, pending' = ((committed and (recoveryRows.length() == 0 or BUG == "reviveObligation")) or pending),
    sourceVersion' = sourceVersion, temporalVersion' = temporalVersion, policyVersion' = policyVersion,
    prepared' = prepared, preparedCut' = preparedCut, supported' = supported,
    now' = now, clockDomain' = clockDomain, uncertain' = uncertain, committed' = committed,
    commitRows' = commitRows, recoveryRows' = recoveryRows
  }
  action recover(hasMatchingReceipt: bool): bool = all {
    pending, recoveryRows.length() < 1, (hasMatchingReceipt or BUG == "ignoreTerminalReceipt"),
    recoveryRows' = recoveryRows.append((pending,hasMatchingReceipt)), pending' = false,
    sourceVersion' = sourceVersion, temporalVersion' = temporalVersion, policyVersion' = policyVersion,
    prepared' = prepared, preparedCut' = preparedCut, supported' = supported,
    retired' = retired, wasRetired' = wasRetired, now' = now, clockDomain' = clockDomain,
    uncertain' = uncertain, committed' = committed, commitRows' = commitRows
  }
  action resurrect = all {
    BUG == "resurrect", retired, retired' = false, wasRetired' = wasRetired,
    sourceVersion' = sourceVersion, temporalVersion' = temporalVersion, policyVersion' = policyVersion,
    prepared' = prepared, preparedCut' = preparedCut, supported' = supported,
    now' = now, clockDomain' = clockDomain, uncertain' = uncertain, committed' = committed,
    pending' = pending, commitRows' = commitRows, recoveryRows' = recoveryRows
  }
  action step = {
    nondet dimension = Set(0,1,2).oneOf()
    nondet receipt = Set(false,true).oneOf()
    any { prepare, commit, revise(dimension,receipt), observe(dimension), retire, recover(receipt), resurrect }
  }
  val ExactSource = commitRows.foldl(true, (ok,r) => ok and r._1._1 == r._2._1)
  val ExactTemporal = commitRows.foldl(true, (ok,r) => ok and r._1._2 == r._2._2)
  val ExactPolicy = commitRows.foldl(true, (ok,r) => ok and r._1._3 == r._2._3)
  val CurrentEvidence = commitRows.foldl(true, (ok,r) => ok and r._6)
  val ComparableClock = commitRows.foldl(true, (ok,r) => ok and r._4 == 0)
  val ConservativeWindow = commitRows.foldl(true, (ok,r) => ok and withinWindow(r._3,r._5))
  val TerminalReceipt = recoveryRows.foldl(true, (ok,r) => ok and r._2)
  val NoObligationResurrection = recoveryRows.length() == 0 or not(pending)
  val NoResurrection = not(wasRetired) or retired
  val safety = ExactSource and ExactTemporal and ExactPolicy and CurrentEvidence and ComparableClock and
               ConservativeWindow and TerminalReceipt and NoResurrection and NoObligationResurrection
}
