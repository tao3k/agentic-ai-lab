// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module TrajectoryExploration {
  const Mutation: str
  type State = {generation: int, priorGeneration: int, hasPrior: bool,
    priorBound: bool, candidateBound: bool, identitiesEqual: bool,
    hasResult: bool, relation: str, exposed: bool, writes: int,
    authorized: bool}
  var q: State
  action init = q' = {generation: 0, priorGeneration: 0, hasPrior: false,
    priorBound: false, candidateBound: false, identitiesEqual: false,
    hasResult: false, relation: "none", exposed: false, writes: 0,
    authorized: false}
  action Record = {nondet bound = Set(true, false).oneOf();
    nondet result = Set(true, false).oneOf();
    all {not(q.hasPrior), q' = {...q, hasPrior: true,
      priorGeneration: q.generation, priorBound: bound, hasResult: result}}}
  action Candidate = {nondet bound = Set(true, false).oneOf();
    nondet same = Set(true, false).oneOf();
    all {q.hasPrior, q' = {...q, candidateBound: bound, identitiesEqual: same,
      relation: "none", exposed: false}}}
  action Invalidate = all {q.hasPrior, q.generation < 1,
    q' = {...q, generation: q.generation + 1, relation: "none", exposed: false}}
  action Explore = all {q.hasPrior,
    q' = {...q,
      relation: if (q.priorGeneration != q.generation) "historical"
        else if (not(q.priorBound and q.candidateBound) and Mutation != "unknown") "unknown"
        else if (q.identitiesEqual) "exact" else "changed",
      exposed: q.hasResult and q.identitiesEqual and
        (q.priorGeneration == q.generation or Mutation == "stale"),
      writes: q.writes + (if (Mutation == "write") 1 else 0),
      authorized: Mutation == "authorize"}}
  action step = any {Record, Candidate, Invalidate, Explore}
  val Safety = all {
    q.relation != "exact" or (q.hasPrior and q.priorBound and
      q.candidateBound and q.identitiesEqual and q.priorGeneration == q.generation),
    not(q.exposed) or (q.hasPrior and q.hasResult and q.priorGeneration == q.generation),
    q.writes == 0,
    not(q.authorized)}
}

module TrajectoryExplorationHealthy {
  import TrajectoryExploration(Mutation = "none").*
}

module TrajectoryExplorationUnknownMutation {
  import TrajectoryExploration(Mutation = "unknown").*
}

module TrajectoryExplorationStaleMutation {
  import TrajectoryExploration(Mutation = "stale").*
}

module TrajectoryExplorationWriteMutation {
  import TrajectoryExploration(Mutation = "write").*
}

module TrajectoryExplorationAuthorizeMutation {
  import TrajectoryExploration(Mutation = "authorize").*
}
