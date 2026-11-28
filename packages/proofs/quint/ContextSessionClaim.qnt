// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module ContextSessionClaim {
  const BUG: str
  var cut: int
  var revision: int
  var active: bool
  var pending: bool
  var scope: int
  var grantGeneration: int
  var grantEnabled: bool
  var expired: bool
  var claims: List[(int,int,int,int,int,bool,bool)]
  var refreshes: List[(bool,bool,int,int)]
  // Cuts 0/1 have a selected unique ID; cut 2 removes that ID and blocks the Task.
  pure def anchorAvailable(c: int): bool = c < 2
  action init = all { cut' = 0, revision' = 0, active' = false, pending' = false,
    scope' = 0, grantGeneration' = 1, grantEnabled' = true, expired' = false,
    claims' = List(), refreshes' = List() }
  action claim(expectedRevision: int, expectedCut: int): bool = all {
    not(active), not(pending), revision < 3, claims.length() < 1, anchorAvailable(cut),
    (expectedRevision == revision or BUG == "ignoreOwner"),
    (expectedCut == cut or BUG == "ignoreSource"),
    (grantGeneration == 1 or BUG == "ignoreGrantGeneration"),
    (grantEnabled or BUG == "ignoreRevocation"), (not(expired) or BUG == "ignoreClock"),
    claims' = claims.append((expectedRevision,revision,expectedCut,cut,grantGeneration,grantEnabled,expired)),
    revision' = revision + 1, active' = true, pending' = pending, cut' = cut,
    scope' = scope, grantGeneration' = grantGeneration, grantEnabled' = grantEnabled,
    expired' = expired, refreshes' = refreshes
  }
  action refresh(targetScope: int): bool = all {
    cut < 2, revision < 3, (targetScope == scope or BUG == "ignoreScope"),
    cut' = cut + 1, scope' = targetScope,
    revision' = if (active) revision + 1 else revision, active' = false,
    pending' = if (BUG == "dropObligation") false else active or pending,
    refreshes' = refreshes.append((active or pending,
      if (BUG == "dropObligation") false else active or pending,scope,targetScope)),
    grantGeneration' = grantGeneration, grantEnabled' = grantEnabled, expired' = expired, claims' = claims
  }
  action rotateGrant = all {
    grantGeneration == 1, grantGeneration' = 2,
    cut' = cut, revision' = revision, active' = active, pending' = pending,
    scope' = scope, grantEnabled' = grantEnabled, expired' = expired, claims' = claims, refreshes' = refreshes
  }
  action revoke = all {
    grantEnabled, grantEnabled' = false, grantGeneration' = grantGeneration,
    cut' = cut, revision' = revision, active' = active, pending' = pending,
    scope' = scope, expired' = expired, claims' = claims, refreshes' = refreshes
  }
  action expire = all {
    not(expired), expired' = true, grantGeneration' = grantGeneration,
    cut' = cut, revision' = revision, active' = active, pending' = pending,
    scope' = scope, grantEnabled' = grantEnabled, claims' = claims, refreshes' = refreshes
  }
  action step = {
    nondet requestedRevision = Set(0,1,2,3).oneOf()
    nondet requestedCut = Set(0,1,2).oneOf()
    nondet requestedScope = Set(0,1).oneOf()
    any { claim(requestedRevision,requestedCut), refresh(requestedScope), rotateGrant, revoke, expire }
  }
  val ExactOwner = claims.foldl(true, (ok,r) => ok and r._1 == r._2)
  val ExactSource = claims.foldl(true, (ok,r) => ok and r._3 == r._4)
  val CurrentGrant = claims.foldl(true, (ok,r) => ok and r._5 == 1)
  val EnabledGrant = claims.foldl(true, (ok,r) => ok and r._6)
  val EffectiveClock = claims.foldl(true, (ok,r) => ok and not(r._7))
  val CurrentAnchor = claims.foldl(true, (ok,r) => ok and anchorAvailable(r._4))
  val PendingPreserved = refreshes.foldl(true, (ok,r) => ok and (not(r._1) or r._2))
  val FixedScope = refreshes.foldl(true, (ok,r) => ok and r._3 == r._4)
  val safety = ExactOwner and ExactSource and CurrentGrant and EnabledGrant and EffectiveClock and
               CurrentAnchor and PendingPreserved and FixedScope
}
