// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module TemporalPublicationDelivery {
  const BUG: bool
  val ids = Set(1, 2)
  var headVersion: int
  var sourceGeneration: int
  var grantActive: bool
  var now: int
  var proposals: int -> (int, int)
  var attempted: Set[int]
  var receipts: int -> int
  var outbox: Set[int]
  var acknowledged: Set[int]
  action init = all {
    headVersion' = 0, sourceGeneration' = 0, grantActive' = true, now' = 0,
    proposals' = Map(), attempted' = Set(), receipts' = Map(),
    outbox' = Set(), acknowledged' = Set()
  }
  action prepare = {
    nondet id = ids.exclude(proposals.keys()).oneOf()
    all { proposals' = proposals.put(id, (headVersion, sourceGeneration)),
      headVersion' = headVersion, sourceGeneration' = sourceGeneration,
      grantActive' = grantActive, now' = now, attempted' = attempted,
      receipts' = receipts, outbox' = outbox, acknowledged' = acknowledged }
  }
  action resolve = {
    nondet id = proposals.keys().exclude(attempted).oneOf()
    val eligible = proposals.get(id) == (headVersion, sourceGeneration) and grantActive and now < 2
    all { attempted' = attempted.union(Set(id)), proposals' = proposals,
      sourceGeneration' = sourceGeneration, grantActive' = grantActive, now' = now,
      headVersion' = if(eligible) headVersion + 1 else headVersion,
      receipts' = if(eligible) receipts.put(id, headVersion + 1) else receipts,
      outbox' = if(eligible and not(BUG)) outbox.union(Set(headVersion + 1)) else outbox,
      acknowledged' = acknowledged }
  }
  action refresh = all { sourceGeneration < 2, sourceGeneration' = sourceGeneration + 1,
    headVersion' = headVersion, grantActive' = grantActive, now' = now,
    proposals' = proposals, attempted' = attempted, receipts' = receipts,
    outbox' = outbox, acknowledged' = acknowledged }
  action retire = all { grantActive, grantActive' = false,
    headVersion' = headVersion, sourceGeneration' = sourceGeneration, now' = now,
    proposals' = proposals, attempted' = attempted, receipts' = receipts,
    outbox' = outbox, acknowledged' = acknowledged }
  action tick = all { now < 2, now' = now + 1,
    headVersion' = headVersion, sourceGeneration' = sourceGeneration, grantActive' = grantActive,
    proposals' = proposals, attempted' = attempted, receipts' = receipts,
    outbox' = outbox, acknowledged' = acknowledged }
  action acknowledge = {
    nondet revision = outbox.oneOf()
    all { acknowledged' = acknowledged.union(Set(revision)), headVersion' = headVersion,
      sourceGeneration' = sourceGeneration, grantActive' = grantActive, now' = now,
      proposals' = proposals, attempted' = attempted, receipts' = receipts, outbox' = outbox }
  }
  // Before COMMIT, death rolls back. After COMMIT, recovery/replay never revalidate
  // or emit another delivery. Native rollback is qualified independently in Rust.
  action recover = all { headVersion' = headVersion, sourceGeneration' = sourceGeneration,
    grantActive' = grantActive, now' = now, proposals' = proposals,
    attempted' = attempted, receipts' = receipts, outbox' = outbox, acknowledged' = acknowledged }
  action step = any { prepare, resolve, refresh, retire, tick, acknowledge, recover }
  val receiptVersions = receipts.keys().map(id => receipts.get(id))
  val AtomicTuple = receiptVersions == outbox and headVersion == receipts.keys().size()
  val safety = and { AtomicTuple, receiptVersions.size() == receipts.keys().size(),
    acknowledged.subseteq(outbox), attempted.subseteq(proposals.keys()),
    receipts.keys().subseteq(attempted), headVersion >= 0, headVersion <= 2 }
}
