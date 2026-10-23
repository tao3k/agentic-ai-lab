-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof

structure ScenarioGapFacts where
  p0Count : Nat
  p1Count : Nat
  p2Count : Nat
  hasReducer : Bool
  hasCommand : Bool
  hasFanout : Bool
  hasBarrier : Bool
  hasCheckpointBefore : Bool
  hasCheckpointCadence : Bool
  hasSubgraphNode : Bool
  hasSubagentNode : Bool
  hasStream : Bool
  hasRetry : Bool
  hasTimeout : Bool
  hasErrorRoute : Bool
  hasReplayFork : Bool
  hasStoreScope : Bool
  hasObservability : Bool
  hasStateVersion : Bool
deriving Repr, DecidableEq

def scenarioGapComplete (facts : ScenarioGapFacts) : Prop :=
  facts.p0Count > 0
  ∧ facts.p1Count > 0
  ∧ facts.p2Count > 0
  ∧ facts.hasReducer = true
  ∧ facts.hasCommand = true
  ∧ facts.hasFanout = true
  ∧ facts.hasBarrier = true
  ∧ facts.hasCheckpointBefore = true
  ∧ facts.hasCheckpointCadence = true
  ∧ facts.hasSubgraphNode = true
  ∧ facts.hasSubagentNode = true
  ∧ facts.hasStream = true
  ∧ facts.hasRetry = true
  ∧ facts.hasTimeout = true
  ∧ facts.hasErrorRoute = true
  ∧ facts.hasReplayFork = true
  ∧ facts.hasStoreScope = true
  ∧ facts.hasObservability = true
  ∧ facts.hasStateVersion = true

def langGraphScenarioGapFacts : ScenarioGapFacts :=
  { p0Count := 8
    p1Count := 7
    p2Count := 1
    hasReducer := true
    hasCommand := true
    hasFanout := true
    hasBarrier := true
    hasCheckpointBefore := true
    hasCheckpointCadence := true
    hasSubgraphNode := true
    hasSubagentNode := true
    hasStream := true
    hasRetry := true
    hasTimeout := true
    hasErrorRoute := true
    hasReplayFork := true
    hasStoreScope := true
    hasObservability := true
    hasStateVersion := true }

theorem langGraphScenarioGapComplete :
    scenarioGapComplete langGraphScenarioGapFacts := by
  unfold scenarioGapComplete langGraphScenarioGapFacts
  decide

inductive RuntimeBoundary
  | schemeOwned
  | runtimeOwnedSchemeDeclared
  | productionHardening
deriving Repr, DecidableEq

def scenarioGapBoundary (priority : Nat) : RuntimeBoundary :=
  if priority = 0 then
    RuntimeBoundary.schemeOwned
  else if priority = 1 then
    RuntimeBoundary.runtimeOwnedSchemeDeclared
  else
    RuntimeBoundary.productionHardening

theorem p0BelongsToSchemeSrc :
    scenarioGapBoundary 0 = RuntimeBoundary.schemeOwned := by
  rfl

theorem p1IsRuntimeOwnedButSchemeDeclared :
    scenarioGapBoundary 1 = RuntimeBoundary.runtimeOwnedSchemeDeclared := by
  rfl

theorem p2IsProductionHardening :
    scenarioGapBoundary 2 = RuntimeBoundary.productionHardening := by
  rfl

structure ScenarioRuntimeRowFacts where
  planOk : Bool
  rejectionsOk : Bool
  acceptedOk : Bool
deriving Repr, DecidableEq

def runtimeRowMatchesPlan (facts : ScenarioRuntimeRowFacts) : Prop :=
  facts.planOk = true
  ∧ facts.rejectionsOk = true
  ∧ facts.acceptedOk = true

def langGraphScenarioRuntimeRowFacts : ScenarioRuntimeRowFacts :=
  { planOk := true
    rejectionsOk := true
    acceptedOk := true }

theorem langGraphScenarioRuntimeRowMatches :
    runtimeRowMatchesPlan langGraphScenarioRuntimeRowFacts := by
  unfold runtimeRowMatchesPlan langGraphScenarioRuntimeRowFacts
  decide

def langGraphScenarioMissingKindRowFacts : ScenarioRuntimeRowFacts :=
  { planOk := true
    rejectionsOk := true
    acceptedOk := false }

def langGraphScenarioWrongPlanRowFacts : ScenarioRuntimeRowFacts :=
  { planOk := false
    rejectionsOk := true
    acceptedOk := true }

def langGraphScenarioRejectedKindRowFacts : ScenarioRuntimeRowFacts :=
  { planOk := true
    rejectionsOk := false
    acceptedOk := true }

theorem langGraphScenarioMissingKindRejected :
    ¬ runtimeRowMatchesPlan langGraphScenarioMissingKindRowFacts := by
  unfold runtimeRowMatchesPlan langGraphScenarioMissingKindRowFacts
  decide

theorem langGraphScenarioWrongPlanRejected :
    ¬ runtimeRowMatchesPlan langGraphScenarioWrongPlanRowFacts := by
  unfold runtimeRowMatchesPlan langGraphScenarioWrongPlanRowFacts
  decide

theorem langGraphScenarioRejectedKindRejected :
    ¬ runtimeRowMatchesPlan langGraphScenarioRejectedKindRowFacts := by
  unfold runtimeRowMatchesPlan langGraphScenarioRejectedKindRowFacts
  decide

end AgenticAILabProof
