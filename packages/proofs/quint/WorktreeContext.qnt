// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module WorktreeContext {
  const BUG: str
  var cut: str -> int
  var rev: str -> int
  var artifactCut: int
  var importedCut: int
  var authorized: str -> bool
  var applicable: bool
  var proposals: str -> (int,int,int,int)
  var imports: List[(int,int,int,int,int,bool,bool,bool,str)]
  var readDone: str -> bool
  var reads: List[(str,str,str,bool,int)]
  action init = all { cut' = Set("wa","wb").mapBy(w => 0), rev' = Set("wa","wb").mapBy(w => 0), artifactCut' = -1, importedCut' = -1, authorized' = Set("sa","sb").mapBy(s => true), applicable' = true, proposals' = Set("u0","u1").mapBy(w => (-1,-1,-1,-1)), imports' = List(), readDone' = Set("sa","sb").mapBy(s => false), reads' = List() }
  action publishSource = all { artifactCut == -1, rev.get("wa") < 2, cut' = cut, rev' = rev.set("wa",rev.get("wa")+1), artifactCut' = cut.get("wa"), importedCut' = importedCut, authorized' = authorized, applicable' = applicable, proposals' = proposals, imports' = imports, readDone' = readDone, reads' = reads }
  action advanceCut(w: str): bool = all { cut.get(w) == 0, cut' = cut.set(w,1), rev' = rev, artifactCut' = artifactCut, importedCut' = importedCut, authorized' = authorized, applicable' = applicable, proposals' = proposals, imports' = imports, readDone' = readDone, reads' = reads }
  action revoke(s: str): bool = all { authorized.get(s), cut' = cut, rev' = rev, artifactCut' = artifactCut, importedCut' = importedCut, authorized' = authorized.set(s,false), applicable' = applicable, proposals' = proposals, imports' = imports, readDone' = readDone, reads' = reads }
  action invalidateTarget = all { applicable, cut' = cut, rev' = rev, artifactCut' = artifactCut, importedCut' = importedCut, authorized' = authorized, applicable' = false, proposals' = proposals, imports' = imports, readDone' = readDone, reads' = reads }
  action proposeTransfer(w: str): bool = all { artifactCut != -1, proposals.get(w)._1 == -1, (importedCut != cut.get("wb") or BUG == "ignoreCAS"), rev.get("wb") < 2, cut' = cut, rev' = rev, artifactCut' = artifactCut, importedCut' = importedCut, authorized' = authorized, applicable' = applicable, proposals' = proposals.set(w,(artifactCut,rev.get("wa"),cut.get("wb"),rev.get("wb"))), imports' = imports, readDone' = readDone, reads' = reads }
  action commitTransfer(w: str): bool = all { proposals.get(w)._1 != -1, artifactCut == proposals.get(w)._1, (cut.get("wa") == proposals.get(w)._1 or BUG == "ignoreSourceCut"), rev.get("wa") == proposals.get(w)._2, (cut.get("wb") == proposals.get(w)._3 or BUG == "ignoreTargetCut"), (rev.get("wb") == proposals.get(w)._4 or BUG == "ignoreCAS"), (importedCut != cut.get("wb") or BUG == "ignoreCAS"), rev.get("wb") < 2, authorized.get("sa"), authorized.get("sb"), (applicable or BUG == "ignoreApplicable"), cut' = cut, rev' = rev.set("wb",rev.get("wb")+1), artifactCut' = artifactCut, importedCut' = cut.get("wb"), authorized' = authorized, applicable' = applicable, proposals' = proposals.set(w,(-1,-1,-1,-1)), imports' = imports.append((proposals.get(w)._1,cut.get("wa"),proposals.get(w)._3,cut.get("wb"),proposals.get(w)._4,authorized.get("sa"),authorized.get("sb"),applicable,w)), readDone' = readDone, reads' = reads }
  action read(s: str,w: str): bool = all { not(readDone.get(s)), (w == (if (s == "sa") "wa" else "wb") or BUG == "ignoreScope"), (authorized.get(s) or BUG == "ignoreReadAuth"), (if (w == "wa") artifactCut == cut.get(w) else importedCut == cut.get(w)), cut' = cut, rev' = rev, artifactCut' = artifactCut, importedCut' = importedCut, authorized' = authorized, applicable' = applicable, proposals' = proposals, imports' = imports, readDone' = readDone.set(s,true), reads' = reads.append((s,w,(if (s == "sa") "wa" else "wb"),authorized.get(s),cut.get(w))) }
  action step = { nondet s = Set("sa","sb").oneOf()
 nondet w = Set("wa","wb").oneOf()
 nondet worker = Set("u0","u1").oneOf()
 any { publishSource,invalidateTarget,advanceCut(w),revoke(s),proposeTransfer(worker),commitTransfer(worker),read(s,w) } }
  val TypeOK = Set("wa","wb").forall(w => 0.to(1).contains(cut.get(w)) and 0.to(2).contains(rev.get(w))) and Set(-1,0,1).contains(artifactCut) and Set(-1,0,1).contains(importedCut)
  val NoForeignRead = reads.foldl(true, (ok,r) => ok and (r._2 == r._3))
  val NoUnauthorizedRead = reads.foldl(true, (ok,r) => ok and (r._4))
  val NoStaleSourceImport = imports.foldl(true, (ok,r) => ok and (r._1 == r._2))
  val NoStaleTargetImport = imports.foldl(true, (ok,r) => ok and (r._3 == r._4))
  val NoDoubleImport = imports.indices().forall(i => imports.indices().forall(j => i == j or imports.nth(i)._5 != imports.nth(j)._5))
  val NoUnauthorizedImport = imports.foldl(true, (ok,r) => ok and (r._6 and r._7))
  val NoInapplicableImport = imports.foldl(true, (ok,r) => ok and (r._8))
  val safety = and { TypeOK, NoForeignRead, NoUnauthorizedRead, NoStaleSourceImport, NoStaleTargetImport, NoDoubleImport, NoUnauthorizedImport, NoInapplicableImport }
}
