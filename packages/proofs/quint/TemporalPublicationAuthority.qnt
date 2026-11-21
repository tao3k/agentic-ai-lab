// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module TemporalPublicationAuthority {
  const BUG: str
  var generation: int
  var captured: int
  var retired: bool
  var attempted: bool
  var committed: bool
  var unauthorized: bool
  var replayed: bool
  action init = all {
    generation' = 0, captured' = -1, retired' = false, attempted' = false,
    committed' = false, unauthorized' = false, replayed' = false
  }
  // Same bytes may return after two rotations. Identity still includes generation.
  action rotate = all {
    not(retired), generation < 2, generation' = generation + 1,
    captured' = captured, retired' = retired, attempted' = attempted,
    committed' = committed, unauthorized' = unauthorized, replayed' = replayed
  }
  action prepare = all {
    not(retired), captured == -1, captured' = generation,
    generation' = generation, retired' = retired, attempted' = attempted,
    committed' = committed, unauthorized' = unauthorized, replayed' = replayed
  }
  action retire = all {
    not(retired), retired' = true,
    generation' = generation, captured' = captured, attempted' = attempted,
    committed' = committed, unauthorized' = unauthorized, replayed' = replayed
  }
  action resolve = {
    val valid = not(retired) and captured == generation
    val sameCommitment = captured % 2 == generation % 2
    val accepted = sameCommitment and (not(retired) or BUG == "ignoreRetirement") and
                   (captured == generation or BUG == "ignoreGeneration")
    all {
      captured >= 0, not(attempted), attempted' = true,
      committed' = accepted, unauthorized' = (accepted and not(valid)),
      generation' = generation, captured' = captured, retired' = retired,
      replayed' = replayed
    }
  }
  // Historical retry after retirement has no new permission decision or effect.
  action replay = all {
    committed, replayed' = true,
    generation' = generation, captured' = captured, retired' = retired,
    attempted' = attempted, committed' = committed, unauthorized' = unauthorized
  }
  action step = any { rotate, prepare, retire, resolve, replay }
  val NoUnauthorizedCommit = not(unauthorized)
  val safety = and { NoUnauthorizedCommit, committed implies attempted,
    replayed implies committed, generation >= 0, generation <= 2,
    captured >= -1, captured <= generation }
}
