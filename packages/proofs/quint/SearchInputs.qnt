// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// One dependent request reads actual A/B evidence; revision retains branch B.
module SearchInputs {
  const BUG: str
  var parents: Set[int]
  var current: bool
  var published: bool
  var scopeSafe: bool
  var completeSafe: bool
  action init = all { parents' = Set(), current' = true, published' = false,
    scopeSafe' = true, completeSafe' = true }
  action observe(parent: int): bool = all {
    not(parents.contains(parent)), parents' = parents.union(Set(parent)),
    current' = current, published' = published,
    scopeSafe' = scopeSafe, completeSafe' = completeSafe }
  action revise = all {
    parents' = parents.exclude(Set(0)), current' = false, published' = published,
    scopeSafe' = scopeSafe, completeSafe' = completeSafe }
  action reissue = all {
    not(current), current' = true, parents' = parents, published' = published,
    scopeSafe' = scopeSafe, completeSafe' = completeSafe }
  action inputs = all {
    current or BUG == "ignoreCurrent", parents == Set(0,1) or BUG == "ignoreMissing",
    published' = true, scopeSafe' = (scopeSafe and current),
    completeSafe' = (completeSafe and parents == Set(0,1)),
    current' = current, parents' = parents }
  action step = any { observe(0), observe(1), revise, reissue, inputs }
  val CurrentInputs = scopeSafe
  val CompleteInputs = completeSafe
  val safety = CurrentInputs and CompleteInputs
}
