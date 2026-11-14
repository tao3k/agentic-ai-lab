// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// Two predecessor slots; generation zero; each can revise once.
// Exact request identity is abstracted by (parent slot, generation, revision).
module SearchReadiness {
  const BUG: str
  var revisions: List[int]
  var completedRevision: List[int]
  var completedGeneration: List[int]
  var admission: List[(bool,bool,bool)]
  action init = all { revisions' = List(0,0),
    completedRevision' = List(-1,-1), completedGeneration' = List(-1,-1),
    admission' = List() }
  action complete(parent: int, generation: int): bool = all {
    completedRevision' = completedRevision.replaceAt(parent, revisions.nth(parent)),
    completedGeneration' = completedGeneration.replaceAt(parent, generation),
    revisions' = revisions, admission' = admission }
  action revise(parent: int): bool = all { revisions.nth(parent) == 0,
    revisions' = revisions.replaceAt(parent, 1),
    completedRevision' = completedRevision, completedGeneration' = completedGeneration,
    admission' = admission }
  val present = Set(0,1).forall(i => completedRevision.nth(i) >= 0)
  val current = Set(0,1).forall(i => completedRevision.nth(i) < 0 or completedRevision.nth(i) == revisions.nth(i))
  val scoped = Set(0,1).forall(i => completedRevision.nth(i) < 0 or completedGeneration.nth(i) == 0)
  action issue = all { admission.length() == 0,
    (present or BUG == "ignoreMissing"),
    (current or BUG == "ignoreRevision"),
    (scoped or BUG == "ignoreScope"),
    admission' = List((present,current,scoped)),
    revisions' = revisions, completedRevision' = completedRevision,
    completedGeneration' = completedGeneration }
  action step = {
    nondet parent = Set(0,1).oneOf()
    nondet generation = Set(0,1).oneOf()
    any { complete(parent,generation), revise(parent), issue }
  }
  val AllPrerequisites = admission.foldl(true, (ok,r) => ok and r._1)
  val CurrentPrerequisites = admission.foldl(true, (ok,r) => ok and r._2)
  val ScopeIsolation = admission.foldl(true, (ok,r) => ok and r._3)
  val safety = AllPrerequisites and CurrentPrerequisites and ScopeIsolation
}
