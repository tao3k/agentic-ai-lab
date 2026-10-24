// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module EvidenceConsumption {
  import AccountingAbstraction.* from "./AccountingAbstraction"
  const Mutation: str
  var generation: int
  var reference: int
  var consumption: int
  var intentOK: bool
  var finished: bool
  var cost: str
  var first: str
  action init = all { generation' = 0, reference' = -1, consumption' = -1,
    intentOK' = false, finished' = false, cost' = "zero", first' = "unset" }
  action Evidence = all {reference' = generation, generation' = generation,
    consumption' = consumption, intentOK' = intentOK, finished' = finished, cost' = cost, first' = first}
  action Consume = {
    nondet accepted = Set(true, false).oneOf()
    val admit = reference == generation and (accepted or Mutation == "intent")
    all {generation' = generation, reference' = reference,
      consumption' = if (admit) generation else consumption,
      intentOK' = if (admit) accepted else intentOK,
      finished' = finished, cost' = cost, first' = first}}
  action Call = { nondet tokens = Set(0,1,2).oneOf()
    nondet nextCost = addSign(cost, tokens).oneOf()
    nondet nextFirst = advanceSnapshot(first, tokens).oneOf()
    all {generation' = generation, reference' = reference, consumption' = consumption,
      intentOK' = intentOK, finished' = finished,
      cost' = if (Mutation == "negative-cost") "negative" else nextCost,
      first' = if (Mutation == "future-snapshot") "after" else nextFirst}}
  action Verify = all {generation' = generation, reference' = reference,
    consumption' = consumption, intentOK' = intentOK, cost' = cost,
    finished' = (finished or consumption == generation or Mutation == "unconsumed"),
    first' = if (first == "unset" and (consumption == generation or Mutation == "unconsumed")) "equal" else first}
  action Invalidate = all {generation < 2, generation' = generation + 1,
    reference' = -1, consumption' = if (Mutation == "stale") consumption else -1,
    intentOK' = false, finished' = false, cost' = "zero", first' = "unset"}
  action step = any {Evidence, Consume, Call, Verify, Invalidate}
  val Safety = all {consumption < 0 or (consumption == generation and intentOK),
    not(finished) or consumption == generation, first != "after", cost != "negative"}
}
