// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// Three finite requirements: producer 0, its dependent 1, independent 2.
// This is not a host worker limit or a twelve-milestone progress counter.
module EvidenceCheckpoint {
  const Mutation: str
  val requirements = Set(0, 1, 2)
  type State = {history: Set[int], gaps: Set[int], invalid: Set[int],
    material: Set[int], quiet: Set[int], prefix: int, readPrefix: int,
    visible: Set[int], reuse: Set[int], projecting: bool,
    authority: bool, choice: int, observedChoice: int,
    observedGaps: Set[int],
    runPrefix: int, terminalPrefix: int, completedUnits: Set[int], reportedProgress: int,
    declaredMembers: Set[int], suppliedMembers: Set[int], declarationScope: int,
    witnessScope: int, witnessed: bool, inventoryAdmitted: bool}
  var q: State
  pure def closure(gaps: Set[int]): Set[int] =
    gaps.union(if (gaps.contains(0)) Set(1) else Set())
  pure def expected(gaps: Set[int]): Set[int] = requirements.exclude(closure(gaps))
  action init = q' = {history: requirements, gaps: Set(), invalid: Set(),
    material: requirements, quiet: requirements, prefix: 0, readPrefix: -1,
    visible: Set(), reuse: Set(), projecting: false, authority: false, choice: -1, observedChoice: -1,
    observedGaps: Set(), runPrefix: 0, terminalPrefix: -1,
    completedUnits: Set(), reportedProgress: 0,
    declaredMembers: Set(0, 1), suppliedMembers: Set(0, 1), declarationScope: 0,
    witnessScope: 0, witnessed: true, inventoryAdmitted: true}
  // Admission-equivalence classes: nonempty, omission, explicit empty,
  // missing witness, wrong scope. No independent irrelevant identity values.
  action ObserveInventory = {nondet kind = Set(0, 1, 2, 3, 4).oneOf();
    q' = {...q, declaredMembers: if (kind == 2) Set() else Set(0),
      suppliedMembers: if (kind == 1 or kind == 2) Set() else Set(0),
      declarationScope: 0, witnessScope: if (kind == 4) 1 else 0,
      witnessed: kind != 3, inventoryAdmitted: false,
      readPrefix: -1, projecting: false}}
  action AdmitInventory = q' = {...q, inventoryAdmitted:
    (q.witnessed or Mutation == "invent-enumeration") and
    (q.declarationScope == q.witnessScope or Mutation == "ignore-enumeration-scope") and
    (q.declaredMembers == q.suppliedMembers or Mutation == "omit-enumeration-member"),
    readPrefix: -1, projecting: false}
  action ObserveCompletion = {nondet unit = Set(0, 1).oneOf(); all {
    q.reportedProgress < 3,
    val completed = q.completedUnits.union(Set(unit))
    q' = {...q, completedUnits: completed,
      reportedProgress: if (Mutation == "count-duplicate-progress") q.reportedProgress + 1 else completed.size()}}}
  action Heartbeat = all {Mutation == "heartbeat-progress", q.reportedProgress < 3,
    q' = {...q, reportedProgress: q.reportedProgress + 1}}
  action AppendRecord = all {q.runPrefix < 2,
    q.terminalPrefix < 0 or Mutation == "extend-terminal",
    q' = {...q, runPrefix: q.runPrefix + 1}}
  action CloseRun = all {q.terminalPrefix < 0,
    q' = {...q, terminalPrefix: q.runPrefix}}
  // A current support projection can lose a required input or command witness;
  // this does not rewrite an immutable historical receipt.
  action MissingBinding = {nondet r = requirements.oneOf(); all {q.prefix < 2,
    q' = {...q, gaps: q.gaps.union(Set(r)),
      observedGaps: if (Mutation == "ignore-missing-binding") q.observedGaps else q.observedGaps.union(Set(r)), prefix: q.prefix + 1,
      readPrefix: -1, projecting: false}}}
  action MissingCommand = {nondet r = requirements.oneOf(); all {q.prefix < 2,
    q' = {...q, gaps: q.gaps.union(Set(r)),
      observedGaps: if (Mutation == "ignore-command") q.observedGaps else q.observedGaps.union(Set(r)), prefix: q.prefix + 1,
      readPrefix: -1, projecting: false}}}
  action ChangeSupport = { nondet r = requirements.oneOf(); all {
    q.prefix < 2,
    q' = {...q, gaps: q.gaps.union(Set(r)), observedGaps: q.observedGaps.union(Set(r)), prefix: q.prefix + 1,
      readPrefix: if (Mutation == "stale-cut") q.prefix + 1 else -1,
      projecting: false} } }
  action RestoreSupport = all {q.prefix < 2, q.gaps != Set(),
    q' = {...q, gaps: Set(), observedGaps: Set(), prefix: q.prefix + 1, readPrefix: -1, projecting: false}}
  action Clean = q' = {...q, material: Set(), readPrefix: -1,
    projecting: false, history: if (Mutation == "erase-history") Set() else q.history}
  action Interrupt = q' = {...q, quiet: Set(), readPrefix: -1, projecting: false}
  action Recover = q' = {...q, readPrefix: -1, projecting: false,
    authority: Mutation == "recovery-authorizes"}
  // Applicability consumes the union of gap causes. Keep truth and transported
  // observations separate, rather than multiplying equivalent cause subsets.
  action Begin = q' = {...q, invalid: q.observedGaps
    .union(if (q.inventoryAdmitted) Set() else requirements)
    ,
    readPrefix: -1, projecting: true}
  action Propagate = all {q.projecting, q.invalid.contains(0), not(q.invalid.contains(1)),
    q' = {...q, invalid: q.invalid.union(Set(1))}}
  action Publish = all {q.projecting,
    Mutation == "skip-closure" or not(q.invalid.contains(0)) or q.invalid.contains(1),
    val support = q.history.exclude(q.invalid)
    q' = {...q, visible: support,
      reuse: support.intersect(q.material).intersect(
        if (Mutation == "guess-exit") requirements else q.quiet),
      readPrefix: q.prefix, projecting: false,
      choice: if (Mutation == "force-choice") 0 else q.choice}}
  action Choose = {nondet c = Set(-1, 0, 1, 2, 3).oneOf();
    q' = {...q, choice: c, observedChoice: c}}
  action step = any {ChangeSupport, RestoreSupport, Clean, Interrupt,
    Recover, Begin, Propagate, Publish, Choose, MissingBinding, MissingCommand, AppendRecord, CloseRun,
    ObserveCompletion, Heartbeat, ObserveInventory, AdmitInventory}
  val Current = q.readPrefix == q.prefix
  val History = q.history == requirements
  val direct = q.gaps
    .union(if (q.inventoryAdmitted) Set() else requirements)
  val EnumerationGrounded = not(q.inventoryAdmitted) or
    (q.witnessed and q.declarationScope == q.witnessScope and q.declaredMembers == q.suppliedMembers)
  val ExactSupport = not(Current) or q.visible == expected(direct)
  val AvailableAndSettled = not(Current) or
    q.reuse == q.visible.intersect(q.material).intersect(q.quiet)
  val Independent = not(Current) or
    (not(direct.contains(2)) implies q.visible.contains(2))
  val NoAuthority = not(q.authority)
  val OpenChoice = q.choice == q.observedChoice
  val TerminalImmutable = q.terminalPrefix < 0 or q.runPrefix == q.terminalPrefix
  val ProgressIsCompletionCount = q.reportedProgress == q.completedUnits.size()
  // Choosing 3 is outside all supplied requirement identities and remains legal.
  val Safety = History and ExactSupport and AvailableAndSettled and Independent and NoAuthority and OpenChoice and TerminalImmutable and ProgressIsCompletionCount and EnumerationGrounded
  run openChoiceTest = init.then(Choose).then(Begin).then(Publish).expect(Safety)
}
