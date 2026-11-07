// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// Projection of context.scheduling-contract.v1, semantic revision 1.
module BoundedScheduling {
  const BUG: str
  // Replay-only operation labels have no influence on scheduling decisions.
  const TRACK_OP: bool
  type State = {d: int, c: int, b: int, burst: int, p: int, bad: bool}
  var s: State
  var op: int
  pure val initial = {d: 0, c: 0, b: 0, burst: 0, p: 0, bad: false}
  action init = all {s' = initial, op' = 0}
  // Credits include active work: b=1 data, b=2 control. p=0/1/2
  // denotes open/draining/closed. One non-preemptive worker per instance.
  action offerData = all {
    s' = if (s.p == 0 and (s.d + (if (s.b == 1) 1 else 0) < 2 or BUG == "capacity"))
      s.with("d", s.d + 1) else s,
    op' = if (TRACK_OP) 1 else 0
  }
  action offerControl = all {
    s' = if (s.p == 0 and s.c + (if (s.b == 2) 1 else 0) < 1)
      s.with("c", s.c + 1) else s,
    op' = if (TRACK_OP) 2 else 0
  }
  action dispatch = {
    val preferControl = s.c > 0 and (s.d == 0 or s.burst < 2)
    val chooseControl = (preferControl or (BUG == "burst" and s.c > 0))
      and (BUG != "priority" or s.d == 0)
    all {
      s' = if (s.p != 2 and s.b == 0)
        (if (chooseControl)
          s.with("c", s.c - 1).with("b", 2).with("burst", if (s.burst < 2) s.burst + 1 else 2)
            .with("bad", s.bad or (s.d > 0 and s.burst >= 2))
        else if (s.d > 0)
          s.with("d", s.d - 1).with("b", 1).with("burst", 0)
            .with("bad", s.bad or preferControl)
        else s) else s,
      op' = if (TRACK_OP) 3 else 0
    }
  }
  action complete = all {s' = s.with("b", 0), op' = if (TRACK_OP) 4 else 0}
  action drain = all {s' = if (s.p == 0) s.with("p", 1) else s, op' = if (TRACK_OP) 5 else 0}
  action close = all {
    s' = if (s.p == 1 and ((s.d == 0 and s.c == 0 and s.b == 0) or BUG == "close"))
      s.with("p", 2) else s, op' = if (TRACK_OP) 6 else 0
  }
  // Idle explicitly represents an owner waiting, including its closed state.
  // Deadlock checking is retained. This is no fairness/liveness proof.
  action idle = all {s' = s, op' = if (TRACK_OP) 7 else 0}
  action step = any {offerData, offerControl, dispatch, complete, drain, close, idle}
  val Credits = s.d + (if (s.b == 1) 1 else 0) <= 2
    and s.c + (if (s.b == 2) 1 else 0) <= 1 and s.d >= 0 and s.c >= 0
  val CloseDrains = s.p != 2 or (s.d == 0 and s.c == 0 and s.b == 0)
  val ControlSelection = not(s.bad) and s.burst >= 0 and s.burst <= 2
  val safety = Credits and CloseDrains and ControlSelection
}
