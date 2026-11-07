// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module EvidenceSemantics {

  const EVIDENCE: Set[str]
  const CLAIMS: Set[str]
  const USES: Set[(str,str)]
  const DEPS: Set[(str,str)]
  def usesOf(e) = USES.filter(u => u._1 == e)
  def useOf(c) = USES.filter(u => u._2 == c)
  def grow(cs) = cs.union(CLAIMS.filter(c => cs.exists(p => DEPS.contains((p,c)))))
  def closure(cs) = 1.to(CLAIMS.size()).fold(cs, (s,_i) => grow(s))
  def affected(e, uses) = closure(usesOf(e).intersect(uses).map(u => u._2))
  val dataWellFormed = and { EVIDENCE.size() > 0, CLAIMS.size() > 0,
    USES.forall(u => EVIDENCE.contains(u._1) and CLAIMS.contains(u._2)),
    DEPS.forall(d => CLAIMS.contains(d._1) and CLAIMS.contains(d._2) and d._1 != d._2) }

}
