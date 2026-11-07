// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module EvidenceLineage {

  const BUG: bool
  import EvidenceSemantics(EVIDENCE = Set("ePrimary","eDistractor"), CLAIMS = Set("cFinding","cReport"),
    USES = Set(("ePrimary","cFinding"),("eDistractor","cFinding")), DEPS = Set(("cFinding","cReport"))).* from "./EvidenceSemantics"
  var soundUses: Set[(str,str)]
  var retrieved: Set[str]
  var cited: Set[(str,str)]
  var checked: Set[(str,str)]
  var rejected: Set[(str,str)]
  var active: Set[str]
  var corrected: Set[str]
  def localSupport(c) = useOf(c).intersect(cited).size() > 0 and useOf(c).intersect(cited).subseteq(checked)
  def parentSupport(c) = active.exists(p => DEPS.contains((p,c)))
  action init = { nondet s = USES.powerset().oneOf()
 all { soundUses' = s, retrieved' = Set(), cited' = Set(), checked' = Set(), rejected' = Set(), active' = Set(), corrected' = Set() } }
  action retrieve = { nondet e = EVIDENCE.oneOf()
 all { not(retrieved.union(corrected).contains(e)), soundUses' = soundUses, retrieved' = retrieved.union(Set(e)), cited' = cited, checked' = checked, rejected' = rejected, active' = active, corrected' = corrected } }
  action citeUse = { nondet u = USES.oneOf()
 all { not(cited.contains(u)) and retrieved.exclude(corrected).contains(u._1), soundUses' = soundUses, retrieved' = retrieved, cited' = cited.union(Set(u)), checked' = checked, rejected' = rejected, active' = active.exclude(closure(Set(u._2))), corrected' = corrected } }
  action checkUse = { nondet u = USES.oneOf()
 all { cited.exclude(checked.union(rejected)).contains(u) and not(corrected.contains(u._1)), soundUses' = soundUses, retrieved' = retrieved, cited' = cited, checked' = if(soundUses.contains(u)) checked.union(Set(u)) else checked, rejected' = if(soundUses.contains(u)) rejected else rejected.union(Set(u)), active' = active, corrected' = corrected } }
  action admitClaim = { nondet c = CLAIMS.oneOf()
 all { not(active.contains(c)) and (localSupport(c) or parentSupport(c)) and useOf(c).intersect(cited).subseteq(checked), soundUses' = soundUses, retrieved' = retrieved, cited' = cited, checked' = checked, rejected' = rejected, active' = active.union(Set(c)), corrected' = corrected } }
  action correct = { nondet e = EVIDENCE.oneOf()
 all { retrieved.exclude(corrected).contains(e), soundUses' = soundUses, retrieved' = retrieved, cited' = cited, checked' = checked.exclude(usesOf(e)), rejected' = rejected, active' = if(BUG) active else active.exclude(affected(e,cited)), corrected' = corrected.union(Set(e)) } }

  action step = any { retrieve, citeUse, checkUse, admitClaim, correct }
  val TypeInvariant = and { dataWellFormed, soundUses.subseteq(USES), retrieved.subseteq(EVIDENCE),
    corrected.subseteq(retrieved), cited.subseteq(USES), checked.subseteq(cited), rejected.subseteq(cited), active.subseteq(CLAIMS) }
  val UsePartitionInvariant = checked.intersect(rejected).size() == 0
  val CheckedUseInvariant = checked.forall(u => soundUses.contains(u) and not(corrected.contains(u._1)))
  val ActiveSupportInvariant = active.forall(c => useOf(c).intersect(cited).subseteq(checked) and (localSupport(c) or parentSupport(c)))
  val CorrectionInvariant = corrected.forall(e => active.intersect(affected(e,cited)).size() == 0)
  val safety = and { TypeInvariant, UsePartitionInvariant, CheckedUseInvariant, ActiveSupportInvariant, CorrectionInvariant }

}
