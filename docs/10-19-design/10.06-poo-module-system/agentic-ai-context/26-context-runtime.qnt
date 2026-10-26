// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module ContextRuntime {
  const BUG: str
  // A and B depend on the same authority; C is an independent shard.
  // Epoch/source CAS is an abstract linearizable service requirement, not
  // an assertion that today's local SQLite adapter implements a cluster.
  type Result = {attempt: int, owner: int, source: int, policy: int}
  type State = {
    owner: int, source: int, policy: int, revoked: bool, partitioned: bool,
    aValid: bool, bValid: bool, pending: Set[int], revokeAck: bool,
    active: int, recovered: bool, cancelRequested: bool, fresh: Result, terminals: int -> int,
    expired: int, badOwner: bool, badUse: bool, badRevival: bool,
    cValid: bool, cDone: bool, staleLock: bool, successorWrite: bool
  }
  var s: State
  pure val old = {attempt: 0, owner: 1, source: 1, policy: 1}
  action init = all {
    s' = {owner: 1, source: 1, policy: 1, revoked: false, partitioned: false,
      aValid: true, bValid: true, pending: Set(), revokeAck: false,
      active: 0, recovered: false, cancelRequested: false, fresh: old, terminals: Map(0 -> 0, 1 -> 0),
      expired: 0, badOwner: false, badUse: false, badRevival: false,
      cValid: true, cDone: false, staleLock: false, successorWrite: false}
  }
  action takeover = all {s.owner == 1, s' = s.with("owner", 2)}
  action recover = all {
    not(s.recovered), (s.owner == 2 or s.cancelRequested),
    s' = s.with("recovered", true).with("active", 1)
      .with("fresh", {attempt: 1, owner: s.owner, source: s.source, policy: s.policy})
  }
  action revoke = all {
    not(s.revoked),
    s' = s.with("source", 2).with("revoked", true).with("pending", Set(1, 2))
  }
  // The journal outbox survives restart. Delivery may repeat and reorder;
  // acknowledgement waits for all affected consumers, including other Sessions.
  action deliverTo(consumer: int): bool = {
    all {s.revoked, not(s.partitioned),
      s' = s.with("aValid", s.aValid and consumer != 1)
        .with("bValid", s.bValid and consumer != 2)
        .with("pending", s.pending.exclude(Set(consumer)))}
  }
  action deliver = {
    nondet consumer = Set(1, 2).oneOf()
    deliverTo(consumer)
  }
  action acknowledge = all {
    s.revoked, s.pending == Set(), s' = s.with("revokeAck", true)
  }
  action partition = all {s' = s.with("partitioned", not(s.partitioned))}
  action replacePolicy = all {s.policy == 1, s' = s.with("policy", 2)}
  action expireOldTicket = all {
    s' = if (s.policy == 1 or BUG == "ticket") s.with("expired", s.policy) else s
  }
  action publishResult(result: Result): bool = {
    val ownerOk = result.owner == s.owner
    val cutOk = not(s.revoked) and result.source == s.source
    val attemptOk = result.attempt == s.active
    val allowed = (ownerOk or BUG == "owner")
      and (if (BUG == "cached") s.aValid else (cutOk and not(s.partitioned)))
      and (attemptOk or BUG == "revival")
      and result.policy == s.policy and s.expired != result.policy
    val count = s.terminals.get(result.attempt)
    all {
      s' = if (allowed and (count == 0 or BUG == "terminal"))
        s.with("terminals", s.terminals.set(result.attempt, count + 1))
          .with("badOwner", s.badOwner or not(ownerOk))
          .with("badUse", s.badUse or not(cutOk))
          .with("badRevival", s.badRevival or not(attemptOk))
        else s
    }
  }
  action publish = {
    nondet result = (if (s.recovered) Set(old, s.fresh) else Set(old)).oneOf()
    publishResult(result)
  }
  // Cancellation request and endpoint observation are separate. A recovery
  // can precede the old worker's observation; its result still cannot revive.
  action cancel = all {
    s.active == 0, s' = s.with("cancelRequested", true)
  }
  action observeCancellation = all {
    s.cancelRequested,
    s' = if (s.terminals.get(0) == 0)
      s.with("terminals", s.terminals.set(0, 1)) else s
  }
  // A rejected old-owner write must release its short transaction's lock.
  action staleEvidenceWrite = all {
    s.owner == 2, s' = s.with("staleLock", BUG == "lock")
  }
  action successorWrite = all {
    s.owner == 2, not(s.staleLock), s' = s.with("successorWrite", true)
  }
  // C has no dependency edge to the revoked source. A's partition must not
  // become a global scheduler/authority lock for unrelated shards.
  action independentProgress = all {s' = s.with("cDone", true)}
  action step = any {takeover, recover, revoke, deliver, acknowledge, partition,
    replacePolicy, expireOldTicket, publish, cancel, observeCancellation, staleEvidenceWrite,
    successorWrite, independentProgress}
  val OneTerminal = Set(0, 1).forall(attempt => s.terminals.get(attempt) <= 1)
  val OwnerFence = not(s.badOwner)
  val NoStaleUse = not(s.badUse) and not(s.badRevival)
  val TicketFence = s.expired != 2
  val UnaffectedConsumer = s.cValid
  val PropagationBarrier = not(s.revokeAck) or (not(s.aValid) and not(s.bValid))
  val RefusalReleasesLock = not(s.staleLock)
  val safety = OneTerminal and OwnerFence and NoStaleUse and TicketFence
    and UnaffectedConsumer and PropagationBarrier and RefusalReleasesLock
  val IndependentProgress = s.partitioned and s.cDone
}
