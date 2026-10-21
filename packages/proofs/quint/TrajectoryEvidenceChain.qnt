// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// Finite protocol model, not a model of hidden reasoning or native GC.
module TrajectoryEvidenceChain {
  const Mutation: str
  // Four content revisions bound only TLC's finite search, not an agent or runtime.
  type State = {generation: int, attempts: int, retained: int,
    attemptGeneration: int, premiseBound: bool, checkedGeneration: int,
    checked: bool, admittedGeneration: int, packetGeneration: int,
    prefixIdentity: int, packetPrefixIdentity: int,
    relation: str, resultVisible: bool, contractMatches: bool, canPropose: bool,
    prescribedChoice: int, agentChoice: int, contextRead: bool,
    contextResultVisible: bool,
    executionAuthorized: bool, lastExplore: bool, beforeExplore: int}
  var q: State
  action init = q' = {generation: 0, attempts: 0, retained: 0,
    attemptGeneration: -1, premiseBound: false, checkedGeneration: -1,
    checked: false, admittedGeneration: -1, packetGeneration: -1,
    prefixIdentity: 0, packetPrefixIdentity: -1,
    relation: "none", resultVisible: false, contractMatches: false, canPropose: true,
    prescribedChoice: -1, agentChoice: -1, contextRead: false,
    contextResultVisible: false,
    executionAuthorized: false, lastExplore: false, beforeExplore: 0}
  action AppendAttempt = {nondet bound = Set(true, false).oneOf(); all {
    q.attempts < 2, q.prefixIdentity < 4,
    q' = {...q, attempts: q.attempts + 1, retained: q.retained + 1,
      prefixIdentity: q.prefixIdentity + 1, packetPrefixIdentity: -1,
      attemptGeneration: q.generation, premiseBound: bound,
      checkedGeneration: -1, checked: false, admittedGeneration: -1,
      relation: "none", resultVisible: false, packetGeneration: -1,
      lastExplore: false}}}
  action Admit = {nondet accepted = Set(true, false).oneOf(); all {
    q.attempts > 0, q.attemptGeneration == q.generation,
    q.prefixIdentity < 4,
    q' = {...q, admittedGeneration: if (accepted) q.generation else -1,
      prefixIdentity: q.prefixIdentity + 1,
      checkedGeneration: -1, checked: false, relation: "none",
      packetGeneration: -1, packetPrefixIdentity: -1,
      resultVisible: false, lastExplore: false}}}
  action Check = {nondet supported = Set(true, false).oneOf(); all {
    q.attempts > 0, q.admittedGeneration == q.generation,
    q.prefixIdentity < 4,
    q' = {...q, checkedGeneration: q.generation, checked: supported,
      prefixIdentity: q.prefixIdentity + 1,
      relation: "none", packetGeneration: -1, packetPrefixIdentity: -1,
      resultVisible: false, lastExplore: false}}}
  action Explore = {nondet matching = Set(true, false).oneOf(); all {q.attempts > 0,
    q' = {...q,
      relation: if (q.attemptGeneration != q.generation) "historical"
        else if (q.premiseBound or Mutation == "guess-equal") "exact"
        else "unknown",
      packetGeneration: q.generation,
      packetPrefixIdentity: q.prefixIdentity,
      contractMatches: matching,
      resultVisible: q.admittedGeneration == q.generation and
        q.attemptGeneration == q.generation and
        (matching or Mutation == "wrong-contract") and
        (q.checked or Mutation == "skip-check" or Mutation == "stale-result"),
      retained: q.retained + (if (Mutation == "write") 1 else 0),
      canPropose: Mutation != "close-options",
      prescribedChoice: if (Mutation == "force-next") 0 else -1,
      executionAuthorized: Mutation == "authorize",
      beforeExplore: q.retained, lastExplore: true}}}
  action ObserveContext = q' = {...q, contextRead: true,
    packetGeneration: q.generation, packetPrefixIdentity: q.prefixIdentity,
    contextResultVisible: Mutation == "context-leaks-result" and q.attempts > 0}
  action ReplaceAtSameCount = all {Mutation == "same-count-prefix",
    q.packetGeneration >= 0, q.attempts > 0, q.prefixIdentity < 4,
    q' = {...q, prefixIdentity: q.prefixIdentity + 1}}
  action Invalidate = all {q.generation < 1,
    q' = {...q, generation: q.generation + 1,
      prefixIdentity: q.prefixIdentity + 1,
      checkedGeneration: -1, checked: false, admittedGeneration: -1,
      relation: if (Mutation == "stale-packet") q.relation else "none",
      packetGeneration: if (Mutation == "stale-packet") q.packetGeneration else -1,
      packetPrefixIdentity: if (Mutation == "stale-packet") q.packetPrefixIdentity else -1,
      resultVisible: if (Mutation == "stale-result") q.resultVisible else false,
      lastExplore: false}}
  action Resume = q' = {...q,
    retained: if (Mutation == "drop-history") 0 else q.retained,
    relation: "none", packetGeneration: -1, packetPrefixIdentity: -1,
    resultVisible: false,
    lastExplore: false}
  action Propose = {nondet choice = Set(0, 1, 2).oneOf(); all {
    q.canPropose, q.prescribedChoice == -1 or choice == q.prescribedChoice,
    q' = {...q, agentChoice: choice, lastExplore: false}}}
  action step = any {AppendAttempt, Check, Admit, ObserveContext, Explore,
    ReplaceAtSameCount, Invalidate, Resume, Propose}
  val CurrentPacket = q.packetGeneration < 0 or
    (q.packetGeneration == q.generation and
      q.packetPrefixIdentity == q.prefixIdentity)
  val BoundComparison = q.relation != "exact" or
    (q.premiseBound and q.attemptGeneration == q.generation)
  val CheckedResult = not(q.resultVisible) or
    (q.checked and q.contractMatches and q.checkedGeneration == q.generation and
      q.admittedGeneration == q.generation and q.attemptGeneration == q.generation)
  val DurableHistory = q.retained == q.attempts
  val ReadOnlyExplore = not(q.lastExplore) or q.retained == q.beforeExplore
  val AdvisoryOnly = not(q.executionAuthorized) and q.canPropose
  // 2 is a novel direction absent from the packet; no packet may prescribe 0 or 1.
  val OpenChoice = q.prescribedChoice == -1
  val ContextNoResult = not(q.contextResultVisible)
  val Safety = CurrentPacket and BoundComparison and CheckedResult and
    DurableHistory and ReadOnlyExplore and AdvisoryOnly and OpenChoice and ContextNoResult
}

module TrajectoryEvidenceChainHealthy {
  import TrajectoryEvidenceChain(Mutation = "none").*
}
module TrajectoryEvidenceChainGuessMutation {
  import TrajectoryEvidenceChain(Mutation = "guess-equal").*
}
module TrajectoryEvidenceChainCheckMutation {
  import TrajectoryEvidenceChain(Mutation = "skip-check").*
}
module TrajectoryEvidenceChainHistoryMutation {
  import TrajectoryEvidenceChain(Mutation = "drop-history").*
}
module TrajectoryEvidenceChainPacketMutation {
  import TrajectoryEvidenceChain(Mutation = "stale-packet").*
}
module TrajectoryEvidenceChainResultMutation {
  import TrajectoryEvidenceChain(Mutation = "stale-result").*
}
module TrajectoryEvidenceChainContractMutation {
  import TrajectoryEvidenceChain(Mutation = "wrong-contract").*
}
module TrajectoryEvidenceChainWriteMutation {
  import TrajectoryEvidenceChain(Mutation = "write").*
}
module TrajectoryEvidenceChainCloseMutation {
  import TrajectoryEvidenceChain(Mutation = "close-options").*
}
module TrajectoryEvidenceChainAuthorizeMutation {
  import TrajectoryEvidenceChain(Mutation = "authorize").*
}
module TrajectoryEvidenceChainForceNextMutation {
  import TrajectoryEvidenceChain(Mutation = "force-next").*
}
module TrajectoryEvidenceChainContextLeakMutation {
  import TrajectoryEvidenceChain(Mutation = "context-leaks-result").*
}
module TrajectoryEvidenceChainSameCountMutation {
  import TrajectoryEvidenceChain(Mutation = "same-count-prefix").*
}
