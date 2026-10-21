// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// Rule review is evidence governance, never a model-action policy.
module TrajectoryRuleEvolution {
  const Mutation: str
  type State = {source: int, events: int, prefix: int, packetThrough: int,
    snapshotIdentity: int, capturedSnapshotIdentity: int,
    reviewedSnapshotIdentity: int,
    counterexamples: int, retained: int, historyIdentity: int,
    reviewedIdentity: int, draft: bool, draftSource: int,
    ruleRevision: int, reviewedRevision: int,
    reviewed: bool, supported: bool, reviewedCounterexamples: int,
    published: bool, selectedAction: bool}
  var q: State
  action init = q' = {source: 0, events: 0, prefix: -1, packetThrough: -1,
    snapshotIdentity: 0, capturedSnapshotIdentity: -1,
    reviewedSnapshotIdentity: -1,
    counterexamples: 0, retained: 0, historyIdentity: 0,
    reviewedIdentity: -1, draft: false, draftSource: -1,
    ruleRevision: 0, reviewedRevision: -1,
    reviewed: false, supported: false, reviewedCounterexamples: -1,
    published: false, selectedAction: false}
  action CapturePrefix = all {q.prefix < 0,
    q' = {...q, prefix: q.events,
      capturedSnapshotIdentity: q.snapshotIdentity,
      packetThrough: q.events + (if (Mutation == "future-leak") 1 else 0)}}
  action ObserveCounterexample = all {q.events < 2,
    q' = {...q, events: q.events + 1,
      snapshotIdentity: q.snapshotIdentity + 1,
      counterexamples: q.counterexamples + 1,
      historyIdentity: q.historyIdentity + 1,
      retained: q.retained + (if (Mutation == "erase-counterexample") 0 else 1),
      published: false}}
  action Draft = all {q.counterexamples > 0, not(q.draft),
    q' = {...q, draft: true, draftSource: q.source, ruleRevision: 1}}
  action ReviseAgain = all {q.draft, q.ruleRevision == 1,
    q' = {...q, ruleRevision: 2, published: false}}
  action ShadowCheck = {nondet independent = Set(true, false).oneOf(); all {
    q.draft, q.prefix >= 0,
    q' = {...q, reviewed: true, supported: independent, published: false,
      reviewedSnapshotIdentity:
        if (Mutation == "late-snapshot") q.snapshotIdentity
        else q.capturedSnapshotIdentity,
      reviewedCounterexamples: q.counterexamples,
      reviewedIdentity: q.historyIdentity,
      reviewedRevision: q.ruleRevision}}}
  action ReplaceAtSameCount = all {Mutation == "same-count-replacement",
    q.reviewed, q.counterexamples > 0,
    q' = {...q, historyIdentity: q.historyIdentity + 1, published: false}}
  action Invalidate = all {q.source == 0,
    q' = {...q, source: 1, snapshotIdentity: q.snapshotIdentity + 1,
      published: false}}
  action Publish = all {q.draft,
    q.reviewed or Mutation == "publish-unreviewed",
    q.supported or Mutation == "publish-unreviewed",
    q.draftSource == q.source or Mutation == "publish-stale",
    q.reviewedRevision == q.ruleRevision or Mutation == "ignore-rule-revision" or
      Mutation == "publish-unreviewed",
    q.reviewedCounterexamples == q.counterexamples or
      Mutation == "ignore-counterexample" or Mutation == "publish-unreviewed",
    q.reviewedIdentity == q.historyIdentity or
      Mutation == "same-count-replacement" or
      Mutation == "ignore-counterexample" or Mutation == "publish-unreviewed",
    q' = {...q, published: true,
      selectedAction: Mutation == "select-action"}}
  action step = any {CapturePrefix, ObserveCounterexample, Draft, ReviseAgain,
    ShadowCheck, ReplaceAtSameCount, Invalidate, Publish}
  val PrefixIsolation = q.packetThrough < 0 or q.packetThrough <= q.prefix
  val SnapshotIsolation = not(q.reviewed) or
    q.reviewedSnapshotIdentity == q.capturedSnapshotIdentity
  val DurableCounterexamples = q.retained == q.counterexamples
  val ReviewedPublication = not(q.published) or
    (q.reviewed and q.supported and q.draftSource == q.source and
      q.reviewedRevision == q.ruleRevision and
      q.reviewedCounterexamples == q.counterexamples and
      q.reviewedIdentity == q.historyIdentity)
  val NoActionSelection = not(q.selectedAction)
  val Safety = PrefixIsolation and SnapshotIsolation and DurableCounterexamples and
    ReviewedPublication and NoActionSelection
}

module TrajectoryRuleEvolutionHealthy {
  import TrajectoryRuleEvolution(Mutation = "none").*
}
module TrajectoryRuleEvolutionFutureMutation {
  import TrajectoryRuleEvolution(Mutation = "future-leak").*
}
module TrajectoryRuleEvolutionEraseMutation {
  import TrajectoryRuleEvolution(Mutation = "erase-counterexample").*
}
module TrajectoryRuleEvolutionReviewMutation {
  import TrajectoryRuleEvolution(Mutation = "publish-unreviewed").*
}
module TrajectoryRuleEvolutionStaleMutation {
  import TrajectoryRuleEvolution(Mutation = "publish-stale").*
}
module TrajectoryRuleEvolutionIgnoreMutation {
  import TrajectoryRuleEvolution(Mutation = "ignore-counterexample").*
}
module TrajectoryRuleEvolutionSelectMutation {
  import TrajectoryRuleEvolution(Mutation = "select-action").*
}
module TrajectoryRuleEvolutionRuleDriftMutation {
  import TrajectoryRuleEvolution(Mutation = "ignore-rule-revision").*
}
module TrajectoryRuleEvolutionSameCountMutation {
  import TrajectoryRuleEvolution(Mutation = "same-count-replacement").*
}
module TrajectoryRuleEvolutionLateSnapshotMutation {
  import TrajectoryRuleEvolution(Mutation = "late-snapshot").*
}
