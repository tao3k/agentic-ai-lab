// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// Compose existing authority and scheduler contracts; Rust executes no proof logic.
module HybridRuntime {
  const BUG: str
  const TRACK_EVENT: bool
  import ContextRuntime(BUG = if (BUG == "receipt") "cached" else if (BUG == "terminal") "terminal" else "none") as auth from "./26-context-runtime"
  import BoundedScheduling(BUG = "none", TRACK_OP = false) as queue from "./27-bounded-scheduling"
  // Work 0=not submitted, 1=inside owner-pinned VM, 2=copied reply,
  // 3=Context result queued. Rust wait timeout does not retire the native call.
  var event: int
  var work: int
  var credit: int
  var joined: bool
  action init = all {auth::init, queue::init, work' = 0, credit' = 0, joined' = false, event' = 0}
  action mark(n: int): bool = event' = if (TRACK_EVENT) n else 0
  action keepAuth = auth::s' = auth::s
  action keepQueue = all {queue::s' = queue::s, queue::op' = queue::op}
  action keepWork = all {work' = work, credit' = credit, joined' = joined}
  action startForeign = all {mark(1), work == 0, not(joined), queue::s.p == 0,
    work' = 1, credit' = 1, joined' = joined, keepAuth, keepQueue}
  action waitTimeout = all {mark(2), work == 1, work' = work,
    credit' = if (BUG == "credit") 0 else credit, joined' = joined, keepAuth, keepQueue}
  action foreignReturn = all {mark(3), work == 1, work' = 2, credit' = 0,
    joined' = joined, keepAuth, keepQueue}
  action enqueueResult = all {mark(4), work >= 2, not(joined), queue::offerData,
    work' = 3, credit' = credit, joined' = joined, keepAuth}
  action dispatch = all {mark(5), queue::dispatch, keepAuth, keepWork}
  action resultComplete = all {mark(7), queue::s.b == 1, queue::complete,
    auth::publishResult(auth::old), keepWork}
  // Authority withdrawal becomes effective at the authoritative fence, before
  // local delivery. A full/draining queue retains the durable pending edge.
  action revoke = all {mark(6), auth::revoke, queue::offerControl, keepWork}
  action retryControl = all {mark(16), auth::s.revoked, auth::s.pending != Set(),
    queue::offerControl, keepAuth, keepWork}
  action deliverControlTo(consumer: int): bool = all {mark(if (consumer == 1) 13 else 21), queue::s.b == 2,
    auth::deliverTo(consumer), queue::complete, keepWork}
  action deliverControl = {
    nondet consumer = Set(1, 2).oneOf()
    deliverControlTo(consumer)
  }
  action acknowledge = all {mark(17), auth::acknowledge, keepQueue, keepWork}
  action cancel = all {mark(11), auth::cancel, keepQueue, keepWork}
  action observeCancellation = all {mark(18), auth::observeCancellation, keepQueue, keepWork}
  action recover = all {mark(12), auth::recover, keepQueue, keepWork}
  action takeover = all {mark(14), auth::takeover, keepQueue, keepWork}
  action replacePolicy = all {mark(10), auth::replacePolicy, keepQueue, keepWork}
  action expireOldTicket = all {mark(15), auth::expireOldTicket, keepQueue, keepWork}
  action independent = all {mark(19), auth::independentProgress, keepQueue, keepWork}
  action drain = all {mark(8), queue::drain, keepAuth, keepWork}
  action close = all {mark(9), work != 1 or BUG == "join", queue::s.p == 1,
    queue::s.d == 0, queue::s.c == 0, queue::s.b == 0, queue::close,
    work' = work, credit' = credit, joined' = true, keepAuth}
  action idle = all {mark(20), keepAuth, keepQueue, keepWork}
  action step = any {startForeign, waitTimeout, foreignReturn, enqueueResult,
    dispatch, resultComplete, revoke, retryControl, deliverControl, acknowledge,
    cancel, observeCancellation, recover, takeover, replacePolicy, expireOldTicket,
    independent, drain, close, idle}
  val NativeCredit = work != 1 or credit == 1
  val JoinQuiesces = not(joined) or (work != 1 and queue::s.p == 2)
  val safety = auth::safety and queue::safety and NativeCredit and JoinQuiesces
}
