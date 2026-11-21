-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.UserInterface
import AgenticAILabProof.PooC4.Profile
import AgenticAILabProof.PooC4.Sandbox
import AgenticAILabProof.PooC4.FunctionalFlow
import AgenticAILabProof.PooC4.SessionLifecycle

namespace AgenticAILabProof.PooC4.ScenarioProof

open AgenticAILabProof.PooC4

inductive ScenarioBridgeFact where
  | s3HandoffReceipt
  | s11AgentRegistered
  | s11SubagentRegistered
  | s11ChannelAuthorized
  | s14PlacementMissingProfile
deriving Repr, DecidableEq

abbrev ScenarioBridgeFactEnv := ScenarioBridgeFact -> Prop

def scenarioBridgeFactsOfSessionFacts
    (facts : SessionLifecycle.SessionFactEnv) : ScenarioBridgeFactEnv
  | ScenarioBridgeFact.s3HandoffReceipt =>
      facts SessionLifecycle.SessionFact.handoffReceiptPresent
  | ScenarioBridgeFact.s11AgentRegistered =>
      facts SessionLifecycle.SessionFact.agentRegistered
  | ScenarioBridgeFact.s11SubagentRegistered =>
      facts SessionLifecycle.SessionFact.subagentRegistered
  | ScenarioBridgeFact.s11ChannelAuthorized =>
      facts SessionLifecycle.SessionFact.channelAuthorized
  | ScenarioBridgeFact.s14PlacementMissingProfile =>
      facts SessionLifecycle.SessionFact.placementMissingProfile

structure AgentGraphProjection where
  agentIdsPresent : Prop
  lineageEdgesPresent : Prop
  channelReceiptsAuthorized : Prop

def sessionFactsOfAgentGraphProjection
    (graph : AgentGraphProjection)
    (baseFacts : SessionLifecycle.SessionFactEnv) :
    SessionLifecycle.SessionFactEnv
  | SessionLifecycle.SessionFact.agentRegistered =>
      graph.agentIdsPresent
  | SessionLifecycle.SessionFact.subagentRegistered =>
      graph.lineageEdgesPresent
  | SessionLifecycle.SessionFact.channelAuthorized =>
      graph.channelReceiptsAuthorized
  | fact => baseFacts fact

def scenarioBridgeFactsOfAgentGraphProjection
    (graph : AgentGraphProjection)
    (baseFacts : SessionLifecycle.SessionFactEnv) :
    ScenarioBridgeFactEnv :=
  scenarioBridgeFactsOfSessionFacts
    (sessionFactsOfAgentGraphProjection graph baseFacts)

abbrev ChannelReceiptProjection :=
  SessionLifecycle.ChannelReceiptProjection

abbrev ChannelReceiptsAuthorized :=
  SessionLifecycle.ChannelReceiptsAuthorized

abbrev ChannelReceiptsPresent :=
  SessionLifecycle.ChannelReceiptsPresent

abbrev StrictAgentGraphProjection :=
  SessionLifecycle.StrictAgentGraphProjection

abbrev strictSessionFactsOfAgentGraphProjection :=
  SessionLifecycle.strictSessionFactsOfAgentGraphProjection

abbrev externalExternalReceipt :=
  SessionLifecycle.externalExternalReceipt

theorem external_external_receipt_not_authorized :
    ¬ externalExternalReceipt.authorized :=
  SessionLifecycle.external_external_receipt_not_authorized

theorem receipt_presence_does_not_imply_authorization :
    ∃ receipts,
      ChannelReceiptsPresent receipts ∧
      ¬ ChannelReceiptsAuthorized receipts :=
  SessionLifecycle.receipt_presence_does_not_imply_authorization

theorem strict_projection_requires_authorized_receipts_for_message_dispatch
    {graph : StrictAgentGraphProjection}
    {baseFacts : SessionLifecycle.SessionFactEnv}
    {activeScope : SessionLifecycle.SessionScope}
    (canStart :
      CanStart
        SessionLifecycle.sessionSpec
        (SessionLifecycle.sessionStateOfFacts activeScope
          (strictSessionFactsOfAgentGraphProjection graph baseFacts))
        SessionLifecycle.SessionModule.messageDispatch) :
    ChannelReceiptsAuthorized graph.channelReceipts :=
  SessionLifecycle.strict_projection_requires_authorized_receipts_for_message_dispatch
    canStart

theorem strict_projection_blocks_message_dispatch_without_authorized_receipts
    {graph : StrictAgentGraphProjection}
    {baseFacts : SessionLifecycle.SessionFactEnv}
    {activeScope : SessionLifecycle.SessionScope}
    (notAuthorized :
      ¬ ChannelReceiptsAuthorized graph.channelReceipts) :
    ¬ CanStart
      SessionLifecycle.sessionSpec
      (SessionLifecycle.sessionStateOfFacts activeScope
        (strictSessionFactsOfAgentGraphProjection graph baseFacts))
      SessionLifecycle.SessionModule.messageDispatch :=
  SessionLifecycle.strict_projection_blocks_message_dispatch_without_authorized_receipts
    notAuthorized

theorem strict_projection_blocks_channel_authorization_when_scope_denied
    {graph : StrictAgentGraphProjection}
    {baseFacts : SessionLifecycle.SessionFactEnv}
    {activeScope : SessionLifecycle.SessionScope}
    (scopeDenied :
      ¬ SessionLifecycle.channelScope <= activeScope) :
    ¬ CanStart
      SessionLifecycle.sessionSpec
      (SessionLifecycle.sessionStateOfFacts activeScope
        (strictSessionFactsOfAgentGraphProjection graph baseFacts))
      SessionLifecycle.SessionModule.channelAuthorization :=
  SessionLifecycle.strict_projection_blocks_channel_authorization_when_scope_denied
    scopeDenied

theorem strict_projection_blocks_message_dispatch_when_scope_denied
    {graph : StrictAgentGraphProjection}
    {baseFacts : SessionLifecycle.SessionFactEnv}
    {activeScope : SessionLifecycle.SessionScope}
    (scopeDenied :
      ¬ SessionLifecycle.messageScope <= activeScope) :
    ¬ CanStart
      SessionLifecycle.sessionSpec
      (SessionLifecycle.sessionStateOfFacts activeScope
        (strictSessionFactsOfAgentGraphProjection graph baseFacts))
      SessionLifecycle.SessionModule.messageDispatch :=
  SessionLifecycle.strict_projection_blocks_message_dispatch_when_scope_denied
    scopeDenied

theorem strict_projection_blocks_handoff_receipt_without_runtime_summary
    {graph : StrictAgentGraphProjection}
    {baseFacts : SessionLifecycle.SessionFactEnv}
    {activeScope : SessionLifecycle.SessionScope}
    (missingRuntimeSummary :
      ¬ baseFacts SessionLifecycle.SessionFact.runtimeSummaryPresent) :
    ¬ CanStart
      SessionLifecycle.sessionSpec
      (SessionLifecycle.sessionStateOfFacts activeScope
        (strictSessionFactsOfAgentGraphProjection graph baseFacts))
      SessionLifecycle.SessionModule.sessionHandoffReceipt :=
  SessionLifecycle.strict_projection_blocks_handoff_receipt_without_runtime_summary
    missingRuntimeSummary

theorem strict_projection_blocks_handoff_receipt_without_runtime_owner
    {graph : StrictAgentGraphProjection}
    {baseFacts : SessionLifecycle.SessionFactEnv}
    {activeScope : SessionLifecycle.SessionScope}
    (missingRuntimeOwner :
      ¬ baseFacts SessionLifecycle.SessionFact.runtimeOwnerMarlin) :
    ¬ CanStart
      SessionLifecycle.sessionSpec
      (SessionLifecycle.sessionStateOfFacts activeScope
        (strictSessionFactsOfAgentGraphProjection graph baseFacts))
      SessionLifecycle.SessionModule.sessionHandoffReceipt :=
  SessionLifecycle.strict_projection_blocks_handoff_receipt_without_runtime_owner
    missingRuntimeOwner

theorem strict_projection_blocks_handoff_receipt_when_handoff_not_required
    {graph : StrictAgentGraphProjection}
    {baseFacts : SessionLifecycle.SessionFactEnv}
    {activeScope : SessionLifecycle.SessionScope}
    (handoffNotRequired :
      ¬ baseFacts SessionLifecycle.SessionFact.handoffRequiredTrue) :
    ¬ CanStart
      SessionLifecycle.sessionSpec
      (SessionLifecycle.sessionStateOfFacts activeScope
        (strictSessionFactsOfAgentGraphProjection graph baseFacts))
      SessionLifecycle.SessionModule.sessionHandoffReceipt :=
  SessionLifecycle.strict_projection_blocks_handoff_receipt_when_handoff_not_required
    handoffNotRequired

theorem policy_denial_blocks_authorized_dispatch
    {Agent Message : Type}
    {topology : SessionLifecycle.AgentTopology Agent}
    {authority : SessionLifecycle.DispatchAuthority Agent Message}
    (policyDenied :
      ∀ message, ¬ authority.policyAllows message) :
    SessionLifecycle.AuthorizedMessageDispatch
      Agent
      Message
      topology
      authority ->
    False :=
  SessionLifecycle.policy_denial_blocks_authorized_dispatch
    policyDenied

theorem strategy_ownership_denial_blocks_authorized_dispatch
    {Agent Message : Type}
    {topology : SessionLifecycle.AgentTopology Agent}
    {authority : SessionLifecycle.DispatchAuthority Agent Message}
    (strategyDenied :
      ∀ agent message, ¬ authority.strategyOwnsStep agent message) :
    SessionLifecycle.AuthorizedMessageDispatch
      Agent
      Message
      topology
      authority ->
    False :=
  SessionLifecycle.strategy_ownership_denial_blocks_authorized_dispatch
    strategyDenied

theorem local_validation_denial_blocks_authorized_dispatch
    {Agent Message : Type}
    {topology : SessionLifecycle.AgentTopology Agent}
    {authority : SessionLifecycle.DispatchAuthority Agent Message}
    (validationDenied :
      ∀ message, ¬ authority.localValidation message) :
    SessionLifecycle.AuthorizedMessageDispatch
      Agent
      Message
      topology
      authority ->
    False :=
  SessionLifecycle.local_validation_denial_blocks_authorized_dispatch
    validationDenied

theorem session_branch_conflict_blocks_dual_start
    {state : SessionLifecycle.SessionState}
    {left right : SessionLifecycle.SessionModule}
    (exclusive :
      BranchExclusiveAt SessionLifecycle.sessionSpec state)
    (sibling :
      SessionLifecycle.sessionSpec.branchSibling left right) :
    ¬ (CanStart SessionLifecycle.sessionSpec state left ∧
       CanStart SessionLifecycle.sessionSpec state right) := by
  intro starts
  exact
    no_sibling_branch_start
      exclusive
      sibling
      starts.left
      starts.right

structure ScenarioFailureMatrix where
  receiptPresenceIsNotAuthorization :
    ∃ receipts,
      ChannelReceiptsPresent receipts ∧
      ¬ ChannelReceiptsAuthorized receipts
  dispatchRequiresAuthorizedReceipts :
    ∀ {graph : StrictAgentGraphProjection}
      {baseFacts : SessionLifecycle.SessionFactEnv}
      {activeScope : SessionLifecycle.SessionScope},
      (¬ ChannelReceiptsAuthorized graph.channelReceipts) ->
      ¬ CanStart
        SessionLifecycle.sessionSpec
        (SessionLifecycle.sessionStateOfFacts activeScope
          (strictSessionFactsOfAgentGraphProjection graph baseFacts))
        SessionLifecycle.SessionModule.messageDispatch
  channelScopeBlocksStart :
    ∀ {graph : StrictAgentGraphProjection}
      {baseFacts : SessionLifecycle.SessionFactEnv}
      {activeScope : SessionLifecycle.SessionScope},
      (¬ SessionLifecycle.channelScope <= activeScope) ->
      ¬ CanStart
        SessionLifecycle.sessionSpec
        (SessionLifecycle.sessionStateOfFacts activeScope
          (strictSessionFactsOfAgentGraphProjection graph baseFacts))
        SessionLifecycle.SessionModule.channelAuthorization
  messageScopeBlocksStart :
    ∀ {graph : StrictAgentGraphProjection}
      {baseFacts : SessionLifecycle.SessionFactEnv}
      {activeScope : SessionLifecycle.SessionScope},
      (¬ SessionLifecycle.messageScope <= activeScope) ->
      ¬ CanStart
        SessionLifecycle.sessionSpec
        (SessionLifecycle.sessionStateOfFacts activeScope
          (strictSessionFactsOfAgentGraphProjection graph baseFacts))
        SessionLifecycle.SessionModule.messageDispatch
  policyDenialBlocksDispatch :
    ∀ {Agent Message : Type}
      {topology : SessionLifecycle.AgentTopology Agent}
      {authority : SessionLifecycle.DispatchAuthority Agent Message},
      (∀ message, ¬ authority.policyAllows message) ->
      SessionLifecycle.AuthorizedMessageDispatch
        Agent
        Message
        topology
        authority ->
      False
  strategyDenialBlocksDispatch :
    ∀ {Agent Message : Type}
      {topology : SessionLifecycle.AgentTopology Agent}
      {authority : SessionLifecycle.DispatchAuthority Agent Message},
      (∀ agent message, ¬ authority.strategyOwnsStep agent message) ->
      SessionLifecycle.AuthorizedMessageDispatch
        Agent
        Message
        topology
        authority ->
      False
  handoffRequiresRuntimeSummary :
    ∀ {graph : StrictAgentGraphProjection}
      {baseFacts : SessionLifecycle.SessionFactEnv}
      {activeScope : SessionLifecycle.SessionScope},
      (¬ baseFacts SessionLifecycle.SessionFact.runtimeSummaryPresent) ->
      ¬ CanStart
        SessionLifecycle.sessionSpec
        (SessionLifecycle.sessionStateOfFacts activeScope
          (strictSessionFactsOfAgentGraphProjection graph baseFacts))
        SessionLifecycle.SessionModule.sessionHandoffReceipt
  handoffRequiresRuntimeOwner :
    ∀ {graph : StrictAgentGraphProjection}
      {baseFacts : SessionLifecycle.SessionFactEnv}
      {activeScope : SessionLifecycle.SessionScope},
      (¬ baseFacts SessionLifecycle.SessionFact.runtimeOwnerMarlin) ->
      ¬ CanStart
        SessionLifecycle.sessionSpec
        (SessionLifecycle.sessionStateOfFacts activeScope
          (strictSessionFactsOfAgentGraphProjection graph baseFacts))
        SessionLifecycle.SessionModule.sessionHandoffReceipt

def scenarioFailureMatrix : ScenarioFailureMatrix :=
  { receiptPresenceIsNotAuthorization :=
      receipt_presence_does_not_imply_authorization
    dispatchRequiresAuthorizedReceipts :=
      strict_projection_blocks_message_dispatch_without_authorized_receipts
    channelScopeBlocksStart :=
      strict_projection_blocks_channel_authorization_when_scope_denied
    messageScopeBlocksStart :=
      strict_projection_blocks_message_dispatch_when_scope_denied
    policyDenialBlocksDispatch :=
      fun {Agent} {Message} {topology} {authority} =>
        policy_denial_blocks_authorized_dispatch
          (Agent := Agent)
          (Message := Message)
          (topology := topology)
          (authority := authority)
    strategyDenialBlocksDispatch :=
      fun {Agent} {Message} {topology} {authority} =>
        strategy_ownership_denial_blocks_authorized_dispatch
          (Agent := Agent)
          (Message := Message)
          (topology := topology)
          (authority := authority)
    handoffRequiresRuntimeSummary :=
      strict_projection_blocks_handoff_receipt_without_runtime_summary
    handoffRequiresRuntimeOwner :=
      strict_projection_blocks_handoff_receipt_without_runtime_owner }

theorem strategy_plan_requires_selector_policy
    {state : UserInterface.UiState}
    (canStart :
      CanStart
        UserInterface.uiSpec
        state
        UserInterface.UiModule.strategyPlan) :
    state.selectorPolicyDone :=
  UserInterface.strategy_plan_requires_selector_policy canStart

theorem strategy_plan_requires_resource_policy
    {state : UserInterface.UiState}
    (canStart :
      CanStart
        UserInterface.uiSpec
        state
        UserInterface.UiModule.strategyPlan) :
    state.resourcePolicyDone :=
  UserInterface.strategy_plan_requires_resource_policy canStart

theorem strategy_plan_requires_capability_policy
    {state : UserInterface.UiState}
    (canStart :
      CanStart
        UserInterface.uiSpec
        state
        UserInterface.UiModule.strategyPlan) :
    state.capabilityPolicyDone :=
  UserInterface.strategy_plan_requires_capability_policy canStart

theorem strategy_plan_blocks_without_selector_policy
    {state : UserInterface.UiState}
    (missingSelector :
      ¬ state.selectorPolicyDone) :
    ¬ CanStart
      UserInterface.uiSpec
      state
      UserInterface.UiModule.strategyPlan :=
  UserInterface.strategy_plan_blocks_without_selector_policy missingSelector

theorem strategy_plan_blocks_without_resource_policy
    {state : UserInterface.UiState}
    (missingResource :
      ¬ state.resourcePolicyDone) :
    ¬ CanStart
      UserInterface.uiSpec
      state
      UserInterface.UiModule.strategyPlan :=
  UserInterface.strategy_plan_blocks_without_resource_policy missingResource

theorem strategy_plan_blocks_without_capability_policy
    {state : UserInterface.UiState}
    (missingCapability :
      ¬ state.capabilityPolicyDone) :
    ¬ CanStart
      UserInterface.uiSpec
      state
      UserInterface.UiModule.strategyPlan :=
  UserInterface.strategy_plan_blocks_without_capability_policy
    missingCapability

theorem local_validation_requires_strategy_plan
    {state : UserInterface.UiState}
    (canStart :
      CanStart
        UserInterface.uiSpec
        state
        UserInterface.UiModule.localValidation) :
    state.strategyPlanDone :=
  UserInterface.local_validation_requires_strategy_plan canStart

theorem local_validation_blocks_without_strategy_plan
    {state : UserInterface.UiState}
    (missingStrategy :
      ¬ state.strategyPlanDone) :
    ¬ CanStart
      UserInterface.uiSpec
      state
      UserInterface.UiModule.localValidation :=
  UserInterface.local_validation_blocks_without_strategy_plan missingStrategy

theorem runtime_manifest_requires_strategy_plan
    {state : UserInterface.UiState}
    (canStart :
      CanStart
        UserInterface.uiSpec
        state
        UserInterface.UiModule.runtimeManifest) :
    state.strategyPlanDone :=
  UserInterface.runtime_manifest_requires_strategy_plan canStart

theorem runtime_manifest_requires_local_validation
    {state : UserInterface.UiState}
    (canStart :
      CanStart
        UserInterface.uiSpec
        state
        UserInterface.UiModule.runtimeManifest) :
    state.localValidationDone :=
  UserInterface.runtime_manifest_requires_local_validation canStart

theorem runtime_manifest_requires_memory_policy
    {state : UserInterface.UiState}
    (canStart :
      CanStart
        UserInterface.uiSpec
        state
        UserInterface.UiModule.runtimeManifest) :
    state.memoryPolicyDone :=
  UserInterface.runtime_manifest_requires_memory_policy canStart

theorem runtime_manifest_requires_compression_policy
    {state : UserInterface.UiState}
    (canStart :
      CanStart
        UserInterface.uiSpec
        state
        UserInterface.UiModule.runtimeManifest) :
    state.compressionPolicyDone :=
  UserInterface.runtime_manifest_requires_compression_policy canStart

theorem runtime_manifest_blocks_without_strategy_plan
    {state : UserInterface.UiState}
    (missingStrategy :
      ¬ state.strategyPlanDone) :
    ¬ CanStart
      UserInterface.uiSpec
      state
      UserInterface.UiModule.runtimeManifest :=
  UserInterface.runtime_manifest_blocks_without_strategy_plan
    missingStrategy

theorem runtime_manifest_blocks_without_local_validation
    {state : UserInterface.UiState}
    (missingValidation :
      ¬ state.localValidationDone) :
    ¬ CanStart
      UserInterface.uiSpec
      state
      UserInterface.UiModule.runtimeManifest :=
  UserInterface.runtime_manifest_blocks_without_local_validation
    missingValidation

theorem runtime_manifest_blocks_without_memory_policy
    {state : UserInterface.UiState}
    (missingMemory :
      ¬ state.memoryPolicyDone) :
    ¬ CanStart
      UserInterface.uiSpec
      state
      UserInterface.UiModule.runtimeManifest :=
  UserInterface.runtime_manifest_blocks_without_memory_policy missingMemory

theorem runtime_manifest_blocks_without_compression_policy
    {state : UserInterface.UiState}
    (missingCompression :
      ¬ state.compressionPolicyDone) :
    ¬ CanStart
      UserInterface.uiSpec
      state
      UserInterface.UiModule.runtimeManifest :=
  UserInterface.runtime_manifest_blocks_without_compression_policy
    missingCompression

theorem marlin_handoff_blocks_without_runtime_manifest
    {state : UserInterface.UiState}
    (missingRuntimeManifest :
      ¬ state.runtimeManifestDone) :
    ¬ CanStart
      UserInterface.uiSpec
      state
      UserInterface.UiModule.marlinHandoff :=
  UserInterface.marlin_handoff_blocks_without_runtime_manifest
    missingRuntimeManifest

theorem scenario_benchmark_blocks_without_matrix
    {state : UserInterface.UiState}
    (missingMatrix :
      ¬ state.scenarioMatrixDone) :
    ¬ CanStart
      UserInterface.uiSpec
      state
      UserInterface.UiModule.scenarioBenchmark :=
  UserInterface.scenario_benchmark_blocks_without_matrix missingMatrix

theorem scenario_benchmark_blocks_without_l1_report
    {state : UserInterface.UiState}
    (missingReport :
      ¬ state.l1ReportDone) :
    ¬ CanStart
      UserInterface.uiSpec
      state
      UserInterface.UiModule.scenarioBenchmark :=
  UserInterface.scenario_benchmark_blocks_without_l1_report missingReport

theorem scenario_benchmark_blocks_without_performance_fixture
    {state : UserInterface.UiState}
    (missingFixture :
      ¬ state.performanceFixtureBound) :
    ¬ CanStart
      UserInterface.uiSpec
      state
      UserInterface.UiModule.scenarioBenchmark :=
  UserInterface.scenario_benchmark_blocks_without_performance_fixture
    missingFixture

abbrev UiScenarioFailureMatrix :=
  UserInterface.UiScenarioFailureMatrix

abbrev uiScenarioFailureMatrix :=
  UserInterface.uiScenarioFailureMatrix

abbrev UiScenarioFact :=
  UserInterface.UiScenarioFact

abbrev UiScenarioFactEnv :=
  UserInterface.UiScenarioFactEnv

abbrev uiScenarioStateOfFacts :=
  UserInterface.uiScenarioStateOfFacts

theorem ui_projection_blocks_strategy_without_selector_policy
    {facts : UiScenarioFactEnv}
    {activeScope : UserInterface.UiScope}
    (missingSelector :
      ¬ facts UserInterface.UiScenarioFact.selectorPolicyDone) :
    ¬ CanStart
      UserInterface.uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UserInterface.UiModule.strategyPlan :=
  UserInterface.ui_projection_blocks_strategy_without_selector_policy
    missingSelector

theorem ui_projection_blocks_strategy_without_resource_policy
    {facts : UiScenarioFactEnv}
    {activeScope : UserInterface.UiScope}
    (missingResource :
      ¬ facts UserInterface.UiScenarioFact.resourcePolicyDone) :
    ¬ CanStart
      UserInterface.uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UserInterface.UiModule.strategyPlan :=
  UserInterface.ui_projection_blocks_strategy_without_resource_policy
    missingResource

theorem ui_projection_blocks_strategy_without_capability_policy
    {facts : UiScenarioFactEnv}
    {activeScope : UserInterface.UiScope}
    (missingCapability :
      ¬ facts UserInterface.UiScenarioFact.capabilityPolicyDone) :
    ¬ CanStart
      UserInterface.uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UserInterface.UiModule.strategyPlan :=
  UserInterface.ui_projection_blocks_strategy_without_capability_policy
    missingCapability

theorem ui_projection_blocks_local_validation_without_strategy_plan
    {facts : UiScenarioFactEnv}
    {activeScope : UserInterface.UiScope}
    (missingStrategy :
      ¬ facts UserInterface.UiScenarioFact.strategyPlanDone) :
    ¬ CanStart
      UserInterface.uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UserInterface.UiModule.localValidation :=
  UserInterface.ui_projection_blocks_local_validation_without_strategy_plan
    missingStrategy

theorem ui_projection_blocks_runtime_manifest_without_strategy_plan
    {facts : UiScenarioFactEnv}
    {activeScope : UserInterface.UiScope}
    (missingStrategy :
      ¬ facts UserInterface.UiScenarioFact.strategyPlanDone) :
    ¬ CanStart
      UserInterface.uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UserInterface.UiModule.runtimeManifest :=
  UserInterface.ui_projection_blocks_runtime_manifest_without_strategy_plan
    missingStrategy

theorem ui_projection_blocks_runtime_manifest_without_memory_policy
    {facts : UiScenarioFactEnv}
    {activeScope : UserInterface.UiScope}
    (missingMemory :
      ¬ facts UserInterface.UiScenarioFact.memoryPolicyDone) :
    ¬ CanStart
      UserInterface.uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UserInterface.UiModule.runtimeManifest :=
  UserInterface.ui_projection_blocks_runtime_manifest_without_memory_policy
    missingMemory

theorem ui_projection_blocks_runtime_manifest_without_compression_policy
    {facts : UiScenarioFactEnv}
    {activeScope : UserInterface.UiScope}
    (missingCompression :
      ¬ facts UserInterface.UiScenarioFact.compressionPolicyDone) :
    ¬ CanStart
      UserInterface.uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UserInterface.UiModule.runtimeManifest :=
  UserInterface.ui_projection_blocks_runtime_manifest_without_compression_policy
    missingCompression

theorem ui_projection_blocks_runtime_manifest_without_local_validation
    {facts : UiScenarioFactEnv}
    {activeScope : UserInterface.UiScope}
    (missingValidation :
      ¬ facts UserInterface.UiScenarioFact.localValidationDone) :
    ¬ CanStart
      UserInterface.uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UserInterface.UiModule.runtimeManifest :=
  UserInterface.ui_projection_blocks_runtime_manifest_without_local_validation
    missingValidation

theorem ui_projection_blocks_handoff_without_runtime_manifest
    {facts : UiScenarioFactEnv}
    {activeScope : UserInterface.UiScope}
    (missingRuntimeManifest :
      ¬ facts UserInterface.UiScenarioFact.runtimeManifestDone) :
    ¬ CanStart
      UserInterface.uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UserInterface.UiModule.marlinHandoff :=
  UserInterface.ui_projection_blocks_handoff_without_runtime_manifest
    missingRuntimeManifest

theorem ui_projection_blocks_benchmark_without_matrix
    {facts : UiScenarioFactEnv}
    {activeScope : UserInterface.UiScope}
    (missingMatrix :
      ¬ facts UserInterface.UiScenarioFact.scenarioMatrixDone) :
    ¬ CanStart
      UserInterface.uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UserInterface.UiModule.scenarioBenchmark :=
  UserInterface.ui_projection_blocks_benchmark_without_matrix
    missingMatrix

theorem ui_projection_blocks_benchmark_without_l1_report
    {facts : UiScenarioFactEnv}
    {activeScope : UserInterface.UiScope}
    (missingReport :
      ¬ facts UserInterface.UiScenarioFact.l1ReportDone) :
    ¬ CanStart
      UserInterface.uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UserInterface.UiModule.scenarioBenchmark :=
  UserInterface.ui_projection_blocks_benchmark_without_l1_report
    missingReport

theorem ui_projection_blocks_benchmark_without_performance_fixture
    {facts : UiScenarioFactEnv}
    {activeScope : UserInterface.UiScope}
    (missingFixture :
      ¬ facts UserInterface.UiScenarioFact.performanceFixtureBound) :
    ¬ CanStart
      UserInterface.uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UserInterface.UiModule.scenarioBenchmark :=
  UserInterface.ui_projection_blocks_benchmark_without_performance_fixture
    missingFixture

abbrev UiScenarioProjectionFailureMatrix :=
  UserInterface.UiScenarioProjectionFailureMatrix

abbrev uiScenarioProjectionFailureMatrix :=
  UserInterface.uiScenarioProjectionFailureMatrix

structure ScenarioBridge
    (ui : UserInterface.UiState)
    (session : SessionLifecycle.SessionState) where
  s2ProfileSession :
    ui.profileDeclared ->
      session.chunkPresent ∧ session.lineagePresent
  s3HandoffReceipt :
    ui.marlinHandoffDone -> session.handoffReceiptPresent
  s4RuntimePolicySummary :
    ui.memoryPolicyDone ->
    ui.compressionPolicyDone ->
      session.runtimeSummaryPresent
  s7StrategyDispatch :
    ui.strategyPlanDone -> session.messageDispatched
  s11Topology :
    ui.scenarioMatrixDone ->
      session.agentRegistered ∧
      session.subagentRegistered ∧
      session.channelAuthorized
  s18RuntimeManifest :
    ui.runtimeManifestDone -> session.runtimeSummaryPresent

theorem s11_bridge_authorizes_session_topology
    {ui : UserInterface.UiState}
    {session : SessionLifecycle.SessionState}
    (bridge : ScenarioBridge ui session)
    (scenarioMatrixDone : ui.scenarioMatrixDone) :
    session.agentRegistered ∧
    session.subagentRegistered ∧
    session.channelAuthorized :=
  bridge.s11Topology scenarioMatrixDone

theorem s3_bridge_produces_handoff_receipt
    {ui : UserInterface.UiState}
    {session : SessionLifecycle.SessionState}
    (bridge : ScenarioBridge ui session)
    (marlinHandoffDone : ui.marlinHandoffDone) :
    session.handoffReceiptPresent :=
  bridge.s3HandoffReceipt marlinHandoffDone

theorem generated_s3_bridge_fact_produces_handoff_receipt
    {facts : SessionLifecycle.SessionFactEnv}
    {activeScope : SessionLifecycle.SessionScope}
    {ui : UserInterface.UiState}
    (_marlinHandoffDone : ui.marlinHandoffDone)
    (bridgeFacts :
      scenarioBridgeFactsOfSessionFacts facts
        ScenarioBridgeFact.s3HandoffReceipt) :
    (SessionLifecycle.sessionStateOfFacts activeScope facts).handoffReceiptPresent :=
  bridgeFacts

theorem s14_missing_profile_blocks_resolution
    {session : SessionLifecycle.SessionState}
    (missingProfile : session.placementMissingProfile) :
    ¬ CanStart
      SessionLifecycle.sessionSpec
      session
      SessionLifecycle.SessionModule.placementResolution := by
  intro canStart
  exact
    (SessionLifecycle.placement_resolution_requires_no_missing_profile
      canStart)
      missingProfile

theorem generated_s14_bridge_fact_blocks_resolution
    {facts : SessionLifecycle.SessionFactEnv}
    {activeScope : SessionLifecycle.SessionScope}
    (bridgeFacts :
      scenarioBridgeFactsOfSessionFacts facts
        ScenarioBridgeFact.s14PlacementMissingProfile) :
    ¬ CanStart
      SessionLifecycle.sessionSpec
      (SessionLifecycle.sessionStateOfFacts activeScope facts)
      SessionLifecycle.SessionModule.placementResolution :=
  SessionLifecycle.projection_missing_profile_blocks_placement_resolution
    bridgeFacts

theorem generated_s11_bridge_facts_authorize_topology
    {facts : SessionLifecycle.SessionFactEnv}
    {activeScope : SessionLifecycle.SessionScope}
    (agentRegistered :
      scenarioBridgeFactsOfSessionFacts facts
        ScenarioBridgeFact.s11AgentRegistered)
    (subagentRegistered :
      scenarioBridgeFactsOfSessionFacts facts
        ScenarioBridgeFact.s11SubagentRegistered)
    (channelAuthorized :
      scenarioBridgeFactsOfSessionFacts facts
        ScenarioBridgeFact.s11ChannelAuthorized) :
    (SessionLifecycle.sessionStateOfFacts activeScope facts).agentRegistered ∧
    (SessionLifecycle.sessionStateOfFacts activeScope facts).subagentRegistered ∧
    (SessionLifecycle.sessionStateOfFacts activeScope facts).channelAuthorized :=
  And.intro agentRegistered
    (And.intro subagentRegistered channelAuthorized)

theorem generated_s11_bridge_facts_start_dispatch_chain
    {facts : SessionLifecycle.SessionFactEnv}
    {activeScope : SessionLifecycle.SessionScope}
    (channelScopeAllowed :
      SessionLifecycle.channelScope <= activeScope)
    (messageScopeAllowed :
      SessionLifecycle.messageScope <= activeScope)
    (agentRegistered :
      scenarioBridgeFactsOfSessionFacts facts
        ScenarioBridgeFact.s11AgentRegistered)
    (subagentRegistered :
      scenarioBridgeFactsOfSessionFacts facts
        ScenarioBridgeFact.s11SubagentRegistered)
    (channelAuthorized :
      scenarioBridgeFactsOfSessionFacts facts
        ScenarioBridgeFact.s11ChannelAuthorized) :
    CanStart
      SessionLifecycle.sessionSpec
      (SessionLifecycle.sessionStateOfFacts activeScope facts)
      SessionLifecycle.SessionModule.channelAuthorization ∧
    CanStart
      SessionLifecycle.sessionSpec
      (SessionLifecycle.sessionStateOfFacts activeScope facts)
      SessionLifecycle.SessionModule.messageDispatch := by
  constructor
  · exact
      { depsCompleted := by
          intro dependency depends
          cases depends
          · exact agentRegistered
          · exact subagentRegistered
        scopeAllowed := channelScopeAllowed
        policyHolds := trivial
        preconditionHolds :=
          And.intro agentRegistered subagentRegistered
        guardHolds := trivial }
  · exact
      { depsCompleted := by
          intro dependency depends
          cases depends
          exact channelAuthorized
        scopeAllowed := messageScopeAllowed
        policyHolds := trivial
        preconditionHolds := channelAuthorized
        guardHolds := channelAuthorized }

theorem agent_graph_projection_generates_s11_bridge_facts
    {graph : AgentGraphProjection}
    {baseFacts : SessionLifecycle.SessionFactEnv}
    (agentIdsPresent : graph.agentIdsPresent)
    (lineageEdgesPresent : graph.lineageEdgesPresent)
    (channelReceiptsAuthorized : graph.channelReceiptsAuthorized) :
    scenarioBridgeFactsOfAgentGraphProjection
      graph
      baseFacts
      ScenarioBridgeFact.s11AgentRegistered ∧
    scenarioBridgeFactsOfAgentGraphProjection
      graph
      baseFacts
      ScenarioBridgeFact.s11SubagentRegistered ∧
    scenarioBridgeFactsOfAgentGraphProjection
      graph
      baseFacts
      ScenarioBridgeFact.s11ChannelAuthorized :=
  And.intro agentIdsPresent
    (And.intro lineageEdgesPresent channelReceiptsAuthorized)

theorem generated_s11_graph_projection_start_dispatch_chain
    {graph : AgentGraphProjection}
    {baseFacts : SessionLifecycle.SessionFactEnv}
    {activeScope : SessionLifecycle.SessionScope}
    (channelScopeAllowed :
      SessionLifecycle.channelScope <= activeScope)
    (messageScopeAllowed :
      SessionLifecycle.messageScope <= activeScope)
    (agentIdsPresent : graph.agentIdsPresent)
    (lineageEdgesPresent : graph.lineageEdgesPresent)
    (channelReceiptsAuthorized : graph.channelReceiptsAuthorized) :
    CanStart
      SessionLifecycle.sessionSpec
      (SessionLifecycle.sessionStateOfFacts activeScope
        (sessionFactsOfAgentGraphProjection graph baseFacts))
      SessionLifecycle.SessionModule.channelAuthorization ∧
    CanStart
      SessionLifecycle.sessionSpec
      (SessionLifecycle.sessionStateOfFacts activeScope
        (sessionFactsOfAgentGraphProjection graph baseFacts))
      SessionLifecycle.SessionModule.messageDispatch :=
  generated_s11_bridge_facts_start_dispatch_chain
    channelScopeAllowed
    messageScopeAllowed
    agentIdsPresent
    lineageEdgesPresent
    channelReceiptsAuthorized

structure ScenarioProjectionPacket where
  graph : AgentGraphProjection
  baseFacts : SessionLifecycle.SessionFactEnv
  activeScope : SessionLifecycle.SessionScope
  channelScopeAllowed :
    SessionLifecycle.channelScope <= activeScope
  messageScopeAllowed :
    SessionLifecycle.messageScope <= activeScope
  agentIdsPresent : graph.agentIdsPresent
  lineageEdgesPresent : graph.lineageEdgesPresent
  channelReceiptsAuthorized : graph.channelReceiptsAuthorized
  handoffReceiptPresent :
    baseFacts SessionLifecycle.SessionFact.handoffReceiptPresent

def ScenarioProjectionPacket.sessionFacts
    (packet : ScenarioProjectionPacket) :
    SessionLifecycle.SessionFactEnv :=
  sessionFactsOfAgentGraphProjection packet.graph packet.baseFacts

def ScenarioProjectionPacket.sessionState
    (packet : ScenarioProjectionPacket) :
    SessionLifecycle.SessionState :=
  SessionLifecycle.sessionStateOfFacts
    packet.activeScope
    packet.sessionFacts

theorem scenario_projection_packet_dispatch_and_handoff
    (packet : ScenarioProjectionPacket) :
    CanStart
      SessionLifecycle.sessionSpec
      packet.sessionState
      SessionLifecycle.SessionModule.channelAuthorization ∧
    CanStart
      SessionLifecycle.sessionSpec
      packet.sessionState
      SessionLifecycle.SessionModule.messageDispatch ∧
    packet.sessionState.handoffReceiptPresent := by
  let dispatchChain :=
    generated_s11_graph_projection_start_dispatch_chain
      (graph := packet.graph)
      (baseFacts := packet.baseFacts)
      (activeScope := packet.activeScope)
      packet.channelScopeAllowed
      packet.messageScopeAllowed
      packet.agentIdsPresent
      packet.lineageEdgesPresent
      packet.channelReceiptsAuthorized
  exact
    And.intro dispatchChain.left
      (And.intro dispatchChain.right packet.handoffReceiptPresent)

theorem scenario_projection_packet_missing_profile_blocks_resolution
    (packet : ScenarioProjectionPacket)
    (missingProfilePresent :
      packet.baseFacts
        SessionLifecycle.SessionFact.placementMissingProfile) :
    ¬ CanStart
      SessionLifecycle.sessionSpec
      packet.sessionState
      SessionLifecycle.SessionModule.placementResolution :=
  SessionLifecycle.projection_missing_profile_blocks_placement_resolution
    missingProfilePresent

theorem scenario_benchmark_links_to_session_boundary
    {ui : UserInterface.UiState}
    {session : SessionLifecycle.SessionState}
    (uiConsistent : UserInterface.UiStateConsistent ui)
    (bridge : ScenarioBridge ui session)
    (canStart :
      CanStart
        UserInterface.uiSpec
        ui
        UserInterface.UiModule.scenarioBenchmark) :
    session.agentRegistered ∧
    session.subagentRegistered ∧
    session.channelAuthorized ∧
    session.handoffReceiptPresent ∧
    ui.performanceFixtureBound := by
  let matrixDone :=
    UserInterface.scenario_benchmark_requires_matrix canStart
  let topologyDone := bridge.s11Topology matrixDone
  let reportDone :=
    UserInterface.scenario_benchmark_requires_l1_report canStart
  let marlinHandoffDone := uiConsistent.reportAfterHandoff reportDone
  let handoffReceiptDone := bridge.s3HandoffReceipt marlinHandoffDone
  let fixtureBound :=
    UserInterface.scenario_benchmark_requires_performance_fixture canStart
  exact
    And.intro topologyDone.left
      (And.intro topologyDone.right.left
        (And.intro topologyDone.right.right
          (And.intro handoffReceiptDone fixtureBound)))

theorem scenario_runtime_manifest_links_to_session_summary
    {ui : UserInterface.UiState}
    {session : SessionLifecycle.SessionState}
    (bridge : ScenarioBridge ui session)
    (canStart :
      CanStart
        UserInterface.uiSpec
        ui
        UserInterface.UiModule.marlinHandoff) :
    session.runtimeSummaryPresent :=
  bridge.s18RuntimeManifest
    (UserInterface.marlin_handoff_requires_runtime_manifest canStart)

end AgenticAILabProof.PooC4.ScenarioProof
