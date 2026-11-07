// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module DomainEvidence {
  pure def graphUpdate(expected:int,observed:int,before:int,removed:int,after:int):bool =
    expected == observed and after == before-removed and removed <= before
  pure val graphConformance = List(0,1).foldl(List(),(a,expected) =>
    List(0,1).foldl(a,(b,observed) => List(0,1,2,3,4).foldl(b,(c,before) =>
      List(0,1,2,3,4).foldl(c,(d,removed) => List(0,1,2,3,4).foldl(d,(f,after) =>
        f.append(List(expected,observed,before,removed,after,
          if(expected == observed) 1 else 0,if(after == before-removed) 1 else 0,
          if(removed <= before) 1 else 0)))))))
  pure def keep(m:int,n:int,p:int,e:int):bool =
    if(n > 0) e*n+m < p*n else e*n+m > p*n
  pure val conformance = List(-2,-1,0,1,2).foldl(List(),(a,m) =>
    List(-2,-1,1,2).foldl(a,(b,n) => List(0,1,2,3).foldl(b,(c,p) =>
      List(-2,-1,0,1,2).foldl(c,(d,e) => List(-1,0,1).foldl(d,(f,delta) =>
        List(0,1).foldl(f,(g,included) => g.append(List(m,n,p,e,delta,included,
          if(delta == 0) 1 else 0, if((included == 1) == keep(m,n,p,e)) 1 else 0))))))))
  var snapshot:int
  var cachedSnapshot:int
  var checker:int
  var cachedChecker:int
  var available:bool
  var lawAvailable:bool
  var lawChecker:int
  action init = all { snapshot'=0, cachedSnapshot'=0, checker'=0, cachedChecker'=0, available'=false,lawAvailable'=false,lawChecker'=0 }
  action observe = all { cachedSnapshot'=snapshot, cachedChecker'=checker, available'=true,
    snapshot'=snapshot, checker'=checker,lawAvailable'=true,lawChecker'=checker }
  action replace = all {snapshot'=snapshot+1, checker'=checker, cachedSnapshot'=cachedSnapshot,
    cachedChecker'=cachedChecker, available'=false,lawAvailable'=lawAvailable,lawChecker'=lawChecker}
  action upgrade = all {checker'=checker+1, snapshot'=snapshot, cachedSnapshot'=cachedSnapshot,
    cachedChecker'=cachedChecker, available'=false,lawAvailable'=false,lawChecker'=lawChecker}
  action step = any {observe,replace,upgrade}
  val BoundEvidence = (available implies (snapshot == cachedSnapshot and checker == cachedChecker))
    and (lawAvailable implies checker == lawChecker)
}
