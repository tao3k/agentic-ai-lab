// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module Trajectory {
  const Mutation: str
  type State = {generation: int, cost: int, calls: int, first: int,
    oldFirst: int, reference: int, failed: bool, repairCost: int,
    rejected: bool, beforeReject: int, known: bool, unknownSeen: bool, completed: bool}
  var q: State
  action init = q' = {generation: 0, cost: 0, calls: 0, first: -1,
    oldFirst: -1, reference: -1, failed: false, repairCost: 0,
    rejected: false, beforeReject: 0, known: true, unknownSeen: false, completed: false}
  action Call = {nondet tokens = Set(0,1,2).oneOf(); all {
    q.calls < 3,
    q' = {...q, calls: q.calls + 1, cost: q.cost + tokens,
      repairCost: q.repairCost + (if (q.failed) tokens else 0),
      oldFirst: q.first,
      first: if (Mutation == "drift" and q.first >= 0) q.cost + tokens else q.first,
      rejected: false}}}
  action Unknown = all {q.calls < 3,
    q' = {...q, calls: q.calls + 1, known: Mutation == "unknown", unknownSeen: true,
      oldFirst: q.first, rejected: false}}
  action Fail = q' = {...q, failed: true, oldFirst: q.first, rejected: false}
  action Correct = q' = {...q, first: if (q.first < 0) q.cost else q.first,
    oldFirst: q.first, failed: false, rejected: false, completed: true}
  action SubgoalCorrect = q' = {...q,
    first: if (Mutation == "premature" and q.first < 0) q.cost else q.first,
    oldFirst: q.first, failed: false, rejected: false}
  action Evidence = q' = {...q, reference: q.generation, oldFirst: q.first, rejected: false}
  action Invalidate = all {q.generation < 1,
    q' = {...q, generation: q.generation + 1, cost: 0, calls: 0, first: -1,
      oldFirst: -1, reference: if (Mutation == "stale") q.reference else -1,
      failed: false, repairCost: 0, rejected: false, known: true, unknownSeen: false, completed: false}}
  action Reject = q' = {...q, rejected: true, beforeReject: q.cost,
    cost: if (Mutation == "reject") q.cost + 1 else q.cost, oldFirst: q.first}
  action step = any {Call, Unknown, Fail, Correct, SubgoalCorrect, Evidence, Invalidate, Reject}
  val Safety = all {
    q.completed or q.first < 0,
    not(q.unknownSeen) or not(q.known),
    q.reference < 0 or q.reference == q.generation,
    q.oldFirst < 0 or q.first == q.oldFirst,
    q.first < 0 or q.first <= q.cost,
    q.repairCost <= q.cost,
    not(q.rejected) or q.cost == q.beforeReject}
}
