// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module ContextCoverage {
  const BUG: str
  // -1 absent, 0 present/nonmatching, 1 present/matching. Complete domain {0,1}.
  var old: int -> int
  var current: int -> int
  var result: Set[int]
  var rebuilt: bool
  pure def full(s: int -> int): Set[int] = Set(0,1).filter(k => s.get(k) == 1)
  action init = {
    nondet a = Set(-1,0,1).oneOf()
    nondet b = Set(-1,0,1).oneOf()
    all { old' = Map(0 -> a,1 -> b), current' = Map(0 -> a,1 -> b),
          result' = Set(), rebuilt' = false }
  }
  action rebuild = {
    nondet a = Set(-1,0,1).oneOf()
    nondet b = Set(-1,0,1).oneOf()
    val targetInputs = Map(0 -> a,1 -> b)
    all { not(rebuilt), current' = targetInputs, old' = old,
      result' = Set(0,1).filter(k =>
        if (old.get(k) != targetInputs.get(k) and
            not (BUG == "omitInsertion" and old.get(k) == -1) and
            not (BUG == "omitRemoval" and targetInputs.get(k) == -1) and
            not (BUG == "omitNegative" and old.get(k) == 0)) targetInputs.get(k) == 1
        else old.get(k) == 1), rebuilt' = true }
  }
  action step = rebuild
  val IncrementalEqualsFull = not(rebuilt) or result == full(current)
  val safety = IncrementalEqualsFull
}
