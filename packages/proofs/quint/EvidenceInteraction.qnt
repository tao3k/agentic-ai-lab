// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module EvidenceInteraction {
  import AccountingAbstraction.* from "./AccountingAbstraction"
  const Mutation: str
  // Evidence Chain owns current support and completion. Trajectory owns
  // exposed observations and cost. Observation cannot admit new evidence.
  var generation: int
  var evidenceGeneration: int
  var supported: bool
  var allConditions: bool
  var complete: bool
  var verdict: str
  var cost: str
  var events: str
  action init = all {generation' = 0, evidenceGeneration' = -1,
    supported' = false, allConditions' = false, complete' = false, verdict' = "unknown", cost' = "zero", events' = "zero"}
  action Check = {
    nondet left = Set(true,false).oneOf()
    nondet right = Set(true,false).oneOf()
    val required = left and right
    val positive = required or (Mutation == "missing-condition" and left)
    nondet closed = Set(true,false).oneOf()
    all {generation' = generation, evidenceGeneration' = generation,
      supported' = positive, allConditions' = required, complete' = closed,
      verdict' = if (positive) "supported" else if (closed or Mutation == "unknown") "contradicted" else "unknown",
      cost' = cost, events' = events}}
  action Observe = {nondet tokens = Set(0,1,2).oneOf()
    nondet nextCost = addSign(cost, tokens).oneOf()
    nondet nextEvents = addSign(events, 1).oneOf()
    all {generation' = generation, evidenceGeneration' = evidenceGeneration,
      supported' = supported, allConditions' = allConditions, complete' = complete,
      verdict' = if (Mutation == "observation") "supported" else verdict,
      cost' = if (Mutation == "negative-cost") "negative" else nextCost,
      events' = if (Mutation == "negative-events") "negative" else nextEvents}}
  action Invalidate = all {generation < 2, generation' = generation + 1,
    evidenceGeneration' = -1, supported' = false, allConditions' = false, complete' = false,
    verdict' = if (Mutation == "stale") verdict else "unknown", cost' = cost, events' = events}
  action Reuse = {nondet nextEvents = addSign(events, 1).oneOf()
    all {generation' = generation, evidenceGeneration' = evidenceGeneration,
    supported' = supported, allConditions' = allConditions, complete' = complete,
    verdict' = if (Mutation == "reuse-stale") "supported"
               else if (evidenceGeneration != generation) "unknown"
               else if (supported) "supported" else if (complete) "contradicted" else "unknown",
    cost' = cost, events' = nextEvents}}
  action Extend = {nondet additional = Set(true,false).oneOf()
    nondet nextEvents = addSign(events, 1).oneOf()
    val combined = supported and additional and evidenceGeneration == generation
    all {generation' = generation, evidenceGeneration' = evidenceGeneration,
      supported' = if (Mutation == "drop-parent") additional else combined,
      allConditions' = (allConditions and additional),
      complete' = complete,
      verdict' = if (Mutation == "drop-parent" and additional) "supported"
                 else if (evidenceGeneration != generation) "unknown"
                 else if (combined) "supported" else if (complete) "contradicted" else "unknown",
      cost' = cost, events' = nextEvents}}
  action step = any {Check, Observe, Invalidate, Reuse, Extend}
  val Safety = all {verdict != "supported" or (supported and allConditions and evidenceGeneration == generation),
    verdict != "contradicted" or (complete and not(supported) and evidenceGeneration == generation),
    cost != "negative", events != "negative"}
}
