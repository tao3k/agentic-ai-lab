-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.Semantics

namespace AgenticAILabProof.PooC4.SessionLifecycle

open AgenticAILabProof.PooC4

inductive SessionModule where
  | sessionChunk
  | sessionLineage
  | sessionPlacement
  | placementResolution
  | sessionValue
  | agentRegistration
  | subagentRegistration
  | channelAuthorization
  | messageDispatch
  | runtimeSummary
  | sessionHandoffReceipt
  | runtimeHandoff
  | handoffSummary
deriving Repr, DecidableEq

abbrev SessionScope := Nat

def chunkScope : SessionScope := 0
def lineageScope : SessionScope := 1
def placementScope : SessionScope := 2
def valueScope : SessionScope := 3
def agentScope : SessionScope := 4
def subagentScope : SessionScope := 5
def channelScope : SessionScope := 6
def messageScope : SessionScope := 7
def runtimeSummaryScope : SessionScope := 8
def receiptScope : SessionScope := 9
def runtimeScope : SessionScope := 10
def summaryScope : SessionScope := 11

def sessionScopeOrder : ScopeOrder SessionScope :=
  { le := Nat.le
    refl := Nat.le_refl
    trans := fun first second => Nat.le_trans first second
    antisymm := fun first second => Nat.le_antisymm first second }

structure SessionState where
  activeScope : SessionScope
  chunkPresent : Prop
  lineagePresent : Prop
  placementPresent : Prop
  placementResolved : Prop
  placementMissingProfile : Prop
  valuePresent : Prop
  agentRegistered : Prop
  subagentRegistered : Prop
  channelAuthorized : Prop
  messageDispatched : Prop
  runtimeSummaryPresent : Prop
  handoffReceiptPresent : Prop
  runtimeHandoffPresent : Prop
  handoffSummaryPresent : Prop
  runtimeExecutedFalse : Prop
  handoffRequiredTrue : Prop
  runtimeOwnerMarlin : Prop
  runtimeParsesSchemeSourceFalse : Prop
  schemeManufacturesRuntimeHandlersFalse : Prop

inductive SessionFact where
  | chunkPresent
  | lineagePresent
  | placementPresent
  | placementResolved
  | placementMissingProfile
  | valuePresent
  | agentRegistered
  | subagentRegistered
  | channelAuthorized
  | messageDispatched
  | runtimeSummaryPresent
  | handoffReceiptPresent
  | runtimeHandoffPresent
  | handoffSummaryPresent
  | runtimeExecutedFalse
  | handoffRequiredTrue
  | runtimeOwnerMarlin
  | runtimeParsesSchemeSourceFalse
  | schemeManufacturesRuntimeHandlersFalse
deriving Repr, DecidableEq

abbrev SessionFactEnv := SessionFact -> Prop

def sessionStateOfFacts
    (activeScope : SessionScope)
    (facts : SessionFactEnv) : SessionState :=
  { activeScope := activeScope
    chunkPresent := facts SessionFact.chunkPresent
    lineagePresent := facts SessionFact.lineagePresent
    placementPresent := facts SessionFact.placementPresent
    placementResolved := facts SessionFact.placementResolved
    placementMissingProfile := facts SessionFact.placementMissingProfile
    valuePresent := facts SessionFact.valuePresent
    agentRegistered := facts SessionFact.agentRegistered
    subagentRegistered := facts SessionFact.subagentRegistered
    channelAuthorized := facts SessionFact.channelAuthorized
    messageDispatched := facts SessionFact.messageDispatched
    runtimeSummaryPresent := facts SessionFact.runtimeSummaryPresent
    handoffReceiptPresent := facts SessionFact.handoffReceiptPresent
    runtimeHandoffPresent := facts SessionFact.runtimeHandoffPresent
    handoffSummaryPresent := facts SessionFact.handoffSummaryPresent
    runtimeExecutedFalse := facts SessionFact.runtimeExecutedFalse
    handoffRequiredTrue := facts SessionFact.handoffRequiredTrue
    runtimeOwnerMarlin := facts SessionFact.runtimeOwnerMarlin
    runtimeParsesSchemeSourceFalse :=
      facts SessionFact.runtimeParsesSchemeSourceFalse
    schemeManufacturesRuntimeHandlersFalse :=
      facts SessionFact.schemeManufacturesRuntimeHandlersFalse }

structure AgentTopology (Agent : Type) where
  registered : Agent -> Prop
  subagent : Agent -> Prop
  channelAllowed : Agent -> Agent -> Prop

structure MessageDispatch
    (Agent Message : Type)
    (topology : AgentTopology Agent) where
  source : Agent
  target : Agent
  message : Message
  sourceRegistered : topology.registered source
  targetRegistered : topology.registered target
  targetIsSubagent : topology.subagent target
  channelAllowed : topology.channelAllowed source target

theorem message_dispatch_registered_pair
    {Agent Message : Type}
    {topology : AgentTopology Agent}
    (dispatch : MessageDispatch Agent Message topology) :
    topology.registered dispatch.source ∧
    topology.registered dispatch.target :=
  And.intro dispatch.sourceRegistered dispatch.targetRegistered

theorem message_dispatch_authorized_channel
    {Agent Message : Type}
    {topology : AgentTopology Agent}
    (dispatch : MessageDispatch Agent Message topology) :
    topology.channelAllowed dispatch.source dispatch.target :=
  dispatch.channelAllowed

theorem message_dispatch_target_is_subagent
    {Agent Message : Type}
    {topology : AgentTopology Agent}
    (dispatch : MessageDispatch Agent Message topology) :
    topology.subagent dispatch.target :=
  dispatch.targetIsSubagent

structure DispatchAuthority (Agent Message : Type) where
  controlOwner : Agent -> Prop
  executionOwner : Agent -> Prop
  localValidation : Message -> Prop
  policyAllows : Message -> Prop
  strategyOwnsStep : Agent -> Message -> Prop

structure AuthorizedMessageDispatch
    (Agent Message : Type)
    (topology : AgentTopology Agent)
    (authority : DispatchAuthority Agent Message) where
  dispatch : MessageDispatch Agent Message topology
  controlOwnerAuthorized : authority.controlOwner dispatch.source
  executionOwnerAuthorized : authority.executionOwner dispatch.target
  localValidationPassed : authority.localValidation dispatch.message
  policyAllowed : authority.policyAllows dispatch.message
  strategyOwnsDispatch :
    authority.strategyOwnsStep dispatch.source dispatch.message

theorem authorized_message_dispatch_sound
    {Agent Message : Type}
    {topology : AgentTopology Agent}
    {authority : DispatchAuthority Agent Message}
    (authorized :
      AuthorizedMessageDispatch Agent Message topology authority) :
    topology.registered authorized.dispatch.source ∧
    topology.registered authorized.dispatch.target ∧
    topology.channelAllowed
      authorized.dispatch.source
      authorized.dispatch.target ∧
    authority.controlOwner authorized.dispatch.source ∧
    authority.executionOwner authorized.dispatch.target ∧
    authority.localValidation authorized.dispatch.message ∧
    authority.policyAllows authorized.dispatch.message ∧
    authority.strategyOwnsStep
      authorized.dispatch.source
      authorized.dispatch.message :=
  And.intro authorized.dispatch.sourceRegistered
    (And.intro authorized.dispatch.targetRegistered
      (And.intro authorized.dispatch.channelAllowed
        (And.intro authorized.controlOwnerAuthorized
          (And.intro authorized.executionOwnerAuthorized
            (And.intro authorized.localValidationPassed
              (And.intro
                authorized.policyAllowed
                authorized.strategyOwnsDispatch))))))

theorem policy_denial_blocks_authorized_dispatch
    {Agent Message : Type}
    {topology : AgentTopology Agent}
    {authority : DispatchAuthority Agent Message}
    (policyDenied :
      ∀ message, ¬ authority.policyAllows message) :
    AuthorizedMessageDispatch
      Agent
      Message
      topology
      authority ->
    False := by
  intro authorized
  exact policyDenied authorized.dispatch.message authorized.policyAllowed

theorem strategy_ownership_denial_blocks_authorized_dispatch
    {Agent Message : Type}
    {topology : AgentTopology Agent}
    {authority : DispatchAuthority Agent Message}
    (strategyDenied :
      ∀ agent message, ¬ authority.strategyOwnsStep agent message) :
    AuthorizedMessageDispatch
      Agent
      Message
      topology
      authority ->
    False := by
  intro authorized
  exact
    strategyDenied
      authorized.dispatch.source
      authorized.dispatch.message
      authorized.strategyOwnsDispatch

theorem local_validation_denial_blocks_authorized_dispatch
    {Agent Message : Type}
    {topology : AgentTopology Agent}
    {authority : DispatchAuthority Agent Message}
    (validationDenied :
      ∀ message, ¬ authority.localValidation message) :
    AuthorizedMessageDispatch
      Agent
      Message
      topology
      authority ->
    False := by
  intro authorized
  exact
    validationDenied
      authorized.dispatch.message
      authorized.localValidationPassed

structure ChannelReceiptProjection where
  sourceInGraph : Prop
  targetInGraph : Prop
  sourceIsLoopEngine : Prop
  targetIsLoopEngine : Prop

def ChannelReceiptProjection.authorized
    (receipt : ChannelReceiptProjection) : Prop :=
  (receipt.sourceInGraph ∨ receipt.sourceIsLoopEngine) ∧
  (receipt.targetInGraph ∨ receipt.targetIsLoopEngine) ∧
  (receipt.sourceInGraph ∨ receipt.targetInGraph)

def ChannelReceiptsAuthorized
    (receipts : List ChannelReceiptProjection) : Prop :=
  ∀ receipt, receipt ∈ receipts -> receipt.authorized

def ChannelReceiptsPresent
    (receipts : List ChannelReceiptProjection) : Prop :=
  ∃ receipt, receipt ∈ receipts

def externalExternalReceipt : ChannelReceiptProjection :=
  { sourceInGraph := False
    targetInGraph := False
    sourceIsLoopEngine := False
    targetIsLoopEngine := False }

theorem external_external_receipt_not_authorized :
    ¬ externalExternalReceipt.authorized := by
  intro authorized
  simp [ChannelReceiptProjection.authorized, externalExternalReceipt] at authorized

theorem receipt_presence_does_not_imply_authorization :
    ∃ receipts,
      ChannelReceiptsPresent receipts ∧
      ¬ ChannelReceiptsAuthorized receipts := by
  refine ⟨[externalExternalReceipt], ?_, ?_⟩
  · exact ⟨externalExternalReceipt, by simp⟩
  · intro authorized
    exact
      external_external_receipt_not_authorized
        (authorized externalExternalReceipt (by simp))

structure StrictAgentGraphProjection where
  agentIdsPresent : Prop
  lineageEdgesPresent : Prop
  channelReceipts : List ChannelReceiptProjection

def strictSessionFactsOfAgentGraphProjection
    (graph : StrictAgentGraphProjection)
    (baseFacts : SessionFactEnv) :
    SessionFactEnv
  | SessionFact.agentRegistered =>
      graph.agentIdsPresent
  | SessionFact.subagentRegistered =>
      graph.lineageEdgesPresent
  | SessionFact.channelAuthorized =>
      ChannelReceiptsPresent graph.channelReceipts ∧
      ChannelReceiptsAuthorized graph.channelReceipts
  | fact => baseFacts fact

inductive SessionDependsOn : SessionModule -> SessionModule -> Prop where
  | lineageChunk :
      SessionDependsOn SessionModule.sessionLineage SessionModule.sessionChunk
  | placementChunk :
      SessionDependsOn SessionModule.sessionPlacement SessionModule.sessionChunk
  | resolutionLineage :
      SessionDependsOn
        SessionModule.placementResolution
        SessionModule.sessionLineage
  | resolutionPlacement :
      SessionDependsOn
        SessionModule.placementResolution
        SessionModule.sessionPlacement
  | valueChunk :
      SessionDependsOn SessionModule.sessionValue SessionModule.sessionChunk
  | valueLineage :
      SessionDependsOn SessionModule.sessionValue SessionModule.sessionLineage
  | valueResolution :
      SessionDependsOn
        SessionModule.sessionValue
        SessionModule.placementResolution
  | agentValue :
      SessionDependsOn
        SessionModule.agentRegistration
        SessionModule.sessionValue
  | subagentAgent :
      SessionDependsOn
        SessionModule.subagentRegistration
        SessionModule.agentRegistration
  | channelAgent :
      SessionDependsOn
        SessionModule.channelAuthorization
        SessionModule.agentRegistration
  | channelSubagent :
      SessionDependsOn
        SessionModule.channelAuthorization
        SessionModule.subagentRegistration
  | messageChannel :
      SessionDependsOn
        SessionModule.messageDispatch
        SessionModule.channelAuthorization
  | runtimeSummaryMessage :
      SessionDependsOn
        SessionModule.runtimeSummary
        SessionModule.messageDispatch
  | receiptRuntimeSummary :
      SessionDependsOn
        SessionModule.sessionHandoffReceipt
        SessionModule.runtimeSummary
  | handoffReceipt :
      SessionDependsOn
        SessionModule.runtimeHandoff
        SessionModule.sessionHandoffReceipt
  | summaryHandoff :
      SessionDependsOn
        SessionModule.handoffSummary
        SessionModule.runtimeHandoff

def sessionModuleScope : SessionModule -> SessionScope
  | SessionModule.sessionChunk => chunkScope
  | SessionModule.sessionLineage => lineageScope
  | SessionModule.sessionPlacement => placementScope
  | SessionModule.placementResolution => placementScope
  | SessionModule.sessionValue => valueScope
  | SessionModule.agentRegistration => agentScope
  | SessionModule.subagentRegistration => subagentScope
  | SessionModule.channelAuthorization => channelScope
  | SessionModule.messageDispatch => messageScope
  | SessionModule.runtimeSummary => runtimeSummaryScope
  | SessionModule.sessionHandoffReceipt => receiptScope
  | SessionModule.runtimeHandoff => runtimeScope
  | SessionModule.handoffSummary => summaryScope

def sessionCompleted (state : SessionState) : SessionModule -> Prop
  | SessionModule.sessionChunk => state.chunkPresent
  | SessionModule.sessionLineage => state.lineagePresent
  | SessionModule.sessionPlacement => state.placementPresent
  | SessionModule.placementResolution => state.placementResolved
  | SessionModule.sessionValue => state.valuePresent
  | SessionModule.agentRegistration => state.agentRegistered
  | SessionModule.subagentRegistration => state.subagentRegistered
  | SessionModule.channelAuthorization => state.channelAuthorized
  | SessionModule.messageDispatch => state.messageDispatched
  | SessionModule.runtimeSummary => state.runtimeSummaryPresent
  | SessionModule.sessionHandoffReceipt => state.handoffReceiptPresent
  | SessionModule.runtimeHandoff => state.runtimeHandoffPresent
  | SessionModule.handoffSummary => state.handoffSummaryPresent

def sessionPolicyAllows (state : SessionState) : SessionModule -> Prop
  | SessionModule.sessionHandoffReceipt =>
      state.handoffRequiredTrue ∧ state.runtimeOwnerMarlin
  | SessionModule.runtimeHandoff =>
      state.handoffRequiredTrue ∧ state.runtimeOwnerMarlin
  | _ => True

def sessionPrecondition (state : SessionState) : SessionModule -> Prop
  | SessionModule.sessionChunk => True
  | SessionModule.sessionLineage => state.chunkPresent
  | SessionModule.sessionPlacement => state.chunkPresent
  | SessionModule.placementResolution =>
      state.lineagePresent ∧
      state.placementPresent ∧
      ¬ state.placementMissingProfile
  | SessionModule.sessionValue =>
      state.chunkPresent ∧
      state.lineagePresent ∧
      state.placementResolved
  | SessionModule.agentRegistration => state.valuePresent
  | SessionModule.subagentRegistration => state.agentRegistered
  | SessionModule.channelAuthorization =>
      state.agentRegistered ∧ state.subagentRegistered
  | SessionModule.messageDispatch => state.channelAuthorized
  | SessionModule.runtimeSummary => state.messageDispatched
  | SessionModule.sessionHandoffReceipt =>
      state.runtimeSummaryPresent ∧
      state.runtimeExecutedFalse ∧
      state.handoffRequiredTrue ∧
      state.runtimeOwnerMarlin ∧
      state.runtimeParsesSchemeSourceFalse ∧
      state.schemeManufacturesRuntimeHandlersFalse
  | SessionModule.runtimeHandoff => state.handoffReceiptPresent
  | SessionModule.handoffSummary => state.runtimeHandoffPresent

def sessionGuard (state : SessionState) : SessionModule -> Prop
  | SessionModule.placementResolution => ¬ state.placementMissingProfile
  | SessionModule.messageDispatch => state.channelAuthorized
  | SessionModule.sessionHandoffReceipt => state.handoffRequiredTrue
  | SessionModule.runtimeHandoff => state.handoffRequiredTrue
  | _ => True

def sessionSpec : FlowSpec SessionModule SessionScope SessionState :=
  { scopeOrder := sessionScopeOrder
    moduleScope := sessionModuleScope
    activeScope := SessionState.activeScope
    dependsOn := SessionDependsOn
    policyAllows := sessionPolicyAllows
    precondition := sessionPrecondition
    guard := sessionGuard
    branchSibling := fun _ _ => False
    completed := sessionCompleted }

structure SessionStateConsistent (state : SessionState) : Prop where
  lineageAfterChunk : state.lineagePresent -> state.chunkPresent
  placementAfterChunk : state.placementPresent -> state.chunkPresent
  resolutionAfterLineage : state.placementResolved -> state.lineagePresent
  resolutionAfterPlacement : state.placementResolved -> state.placementPresent
  valueAfterResolution : state.valuePresent -> state.placementResolved
  agentAfterValue : state.agentRegistered -> state.valuePresent
  subagentAfterAgent : state.subagentRegistered -> state.agentRegistered
  channelAfterAgent : state.channelAuthorized -> state.agentRegistered
  channelAfterSubagent : state.channelAuthorized -> state.subagentRegistered
  messageAfterChannel : state.messageDispatched -> state.channelAuthorized
  runtimeSummaryAfterMessage :
    state.runtimeSummaryPresent -> state.messageDispatched
  receiptAfterRuntimeSummary :
    state.handoffReceiptPresent -> state.runtimeSummaryPresent
  runtimeAfterReceipt : state.runtimeHandoffPresent -> state.handoffReceiptPresent
  summaryAfterRuntime : state.handoffSummaryPresent -> state.runtimeHandoffPresent
  resolvedNotMissingProfile :
    state.placementResolved -> ¬ state.placementMissingProfile

def sessionRank : SessionModule -> Nat
  | SessionModule.sessionChunk => 0
  | SessionModule.sessionLineage => 1
  | SessionModule.sessionPlacement => 1
  | SessionModule.placementResolution => 2
  | SessionModule.sessionValue => 3
  | SessionModule.agentRegistration => 4
  | SessionModule.subagentRegistration => 5
  | SessionModule.channelAuthorization => 6
  | SessionModule.messageDispatch => 7
  | SessionModule.runtimeSummary => 8
  | SessionModule.sessionHandoffReceipt => 9
  | SessionModule.runtimeHandoff => 10
  | SessionModule.handoffSummary => 11

def sessionDependencyRank : DependencyRank sessionSpec :=
  { rank := sessionRank
    decreases := by
      intro module dependency depends
      cases depends <;> native_decide }

theorem session_no_self_dependency
    {module : SessionModule} :
    ¬ sessionSpec.dependsOn module module :=
  no_self_dependency_of_rank sessionDependencyRank

theorem session_no_two_dependency_cycle
    {left right : SessionModule}
    (leftDependsRight : sessionSpec.dependsOn left right)
    (rightDependsLeft : sessionSpec.dependsOn right left) :
    False :=
  no_two_cycle_of_rank
    sessionDependencyRank
    leftDependsRight
    rightDependsLeft

theorem placement_resolution_requires_no_missing_profile
    {state : SessionState}
    (canStart :
      CanStart sessionSpec state SessionModule.placementResolution) :
    ¬ state.placementMissingProfile :=
  canStart.guardHolds

theorem session_value_requires_placement_resolution
    {state : SessionState}
    (canStart : CanStart sessionSpec state SessionModule.sessionValue) :
    state.placementResolved :=
  deps_completed_of_can_start canStart SessionDependsOn.valueResolution

theorem subagent_registration_requires_agent_registration
    {state : SessionState}
    (canStart :
      CanStart sessionSpec state SessionModule.subagentRegistration) :
    state.agentRegistered :=
  deps_completed_of_can_start canStart SessionDependsOn.subagentAgent

theorem channel_authorization_requires_agent_registration
    {state : SessionState}
    (canStart :
      CanStart sessionSpec state SessionModule.channelAuthorization) :
    state.agentRegistered :=
  deps_completed_of_can_start canStart SessionDependsOn.channelAgent

theorem channel_authorization_requires_subagent_registration
    {state : SessionState}
    (canStart :
      CanStart sessionSpec state SessionModule.channelAuthorization) :
    state.subagentRegistered :=
  deps_completed_of_can_start canStart SessionDependsOn.channelSubagent

theorem message_dispatch_requires_channel_authorization
    {state : SessionState}
    (canStart : CanStart sessionSpec state SessionModule.messageDispatch) :
    state.channelAuthorized :=
  deps_completed_of_can_start canStart SessionDependsOn.messageChannel

theorem strict_projection_requires_authorized_receipts_for_message_dispatch
    {graph : StrictAgentGraphProjection}
    {baseFacts : SessionFactEnv}
    {activeScope : SessionScope}
    (canStart :
      CanStart
        sessionSpec
        (sessionStateOfFacts activeScope
          (strictSessionFactsOfAgentGraphProjection graph baseFacts))
        SessionModule.messageDispatch) :
    ChannelReceiptsAuthorized graph.channelReceipts :=
  (message_dispatch_requires_channel_authorization canStart).right

theorem strict_projection_blocks_message_dispatch_without_authorized_receipts
    {graph : StrictAgentGraphProjection}
    {baseFacts : SessionFactEnv}
    {activeScope : SessionScope}
    (notAuthorized :
      ¬ ChannelReceiptsAuthorized graph.channelReceipts) :
    ¬ CanStart
      sessionSpec
      (sessionStateOfFacts activeScope
        (strictSessionFactsOfAgentGraphProjection graph baseFacts))
      SessionModule.messageDispatch := by
  intro canStart
  exact
    notAuthorized
      (strict_projection_requires_authorized_receipts_for_message_dispatch
        canStart)

theorem strict_projection_blocks_channel_authorization_when_scope_denied
    {graph : StrictAgentGraphProjection}
    {baseFacts : SessionFactEnv}
    {activeScope : SessionScope}
    (scopeDenied :
      ¬ channelScope <= activeScope) :
    ¬ CanStart
      sessionSpec
      (sessionStateOfFacts activeScope
        (strictSessionFactsOfAgentGraphProjection graph baseFacts))
      SessionModule.channelAuthorization := by
  intro canStart
  exact scopeDenied canStart.scopeAllowed

theorem strict_projection_blocks_message_dispatch_when_scope_denied
    {graph : StrictAgentGraphProjection}
    {baseFacts : SessionFactEnv}
    {activeScope : SessionScope}
    (scopeDenied :
      ¬ messageScope <= activeScope) :
    ¬ CanStart
      sessionSpec
      (sessionStateOfFacts activeScope
        (strictSessionFactsOfAgentGraphProjection graph baseFacts))
      SessionModule.messageDispatch := by
  intro canStart
  exact scopeDenied canStart.scopeAllowed

theorem runtime_summary_requires_message_dispatch
    {state : SessionState}
    (canStart : CanStart sessionSpec state SessionModule.runtimeSummary) :
    state.messageDispatched :=
  deps_completed_of_can_start canStart SessionDependsOn.runtimeSummaryMessage

theorem handoff_receipt_requires_runtime_summary
    {state : SessionState}
    (canStart :
      CanStart sessionSpec state SessionModule.sessionHandoffReceipt) :
    state.runtimeSummaryPresent :=
  deps_completed_of_can_start canStart SessionDependsOn.receiptRuntimeSummary

theorem handoff_receipt_static_runtime_boundary
    {state : SessionState}
    (canStart :
      CanStart sessionSpec state SessionModule.sessionHandoffReceipt) :
    state.runtimeExecutedFalse ∧
    state.handoffRequiredTrue ∧
    state.runtimeOwnerMarlin ∧
    state.runtimeParsesSchemeSourceFalse ∧
    state.schemeManufacturesRuntimeHandlersFalse := by
  exact canStart.preconditionHolds.right

theorem handoff_receipt_can_start_of_projection_facts
    {facts : SessionFactEnv}
    {activeScope : SessionScope}
    (scopeAllowed : receiptScope <= activeScope)
    (runtimeSummaryPresent :
      facts SessionFact.runtimeSummaryPresent)
    (runtimeExecutedFalse :
      facts SessionFact.runtimeExecutedFalse)
    (handoffRequiredTrue :
      facts SessionFact.handoffRequiredTrue)
    (runtimeOwnerMarlin :
      facts SessionFact.runtimeOwnerMarlin)
    (runtimeParsesSchemeSourceFalse :
      facts SessionFact.runtimeParsesSchemeSourceFalse)
    (schemeManufacturesRuntimeHandlersFalse :
      facts SessionFact.schemeManufacturesRuntimeHandlersFalse) :
    CanStart
      sessionSpec
      (sessionStateOfFacts activeScope facts)
      SessionModule.sessionHandoffReceipt :=
  { depsCompleted := by
      intro dependency depends
      cases depends
      exact runtimeSummaryPresent
    scopeAllowed := scopeAllowed
    policyHolds :=
      And.intro handoffRequiredTrue runtimeOwnerMarlin
    preconditionHolds :=
      And.intro runtimeSummaryPresent
        (And.intro runtimeExecutedFalse
          (And.intro handoffRequiredTrue
            (And.intro runtimeOwnerMarlin
              (And.intro
                runtimeParsesSchemeSourceFalse
                schemeManufacturesRuntimeHandlersFalse))))
    guardHolds := handoffRequiredTrue }

theorem projection_missing_profile_blocks_placement_resolution
    {facts : SessionFactEnv}
    {activeScope : SessionScope}
    (missingProfile : facts SessionFact.placementMissingProfile) :
    ¬ CanStart
      sessionSpec
      (sessionStateOfFacts activeScope facts)
      SessionModule.placementResolution := by
  intro canStart
  exact canStart.guardHolds missingProfile

theorem projection_without_runtime_summary_blocks_handoff_receipt
    {facts : SessionFactEnv}
    {activeScope : SessionScope}
    (missingRuntimeSummary :
      ¬ facts SessionFact.runtimeSummaryPresent) :
    ¬ CanStart
      sessionSpec
      (sessionStateOfFacts activeScope facts)
      SessionModule.sessionHandoffReceipt := by
  intro canStart
  exact missingRuntimeSummary
    (deps_completed_of_can_start
      canStart
      SessionDependsOn.receiptRuntimeSummary)

theorem projection_without_handoff_required_blocks_handoff_receipt
    {facts : SessionFactEnv}
    {activeScope : SessionScope}
    (handoffNotRequired :
      ¬ facts SessionFact.handoffRequiredTrue) :
    ¬ CanStart
      sessionSpec
      (sessionStateOfFacts activeScope facts)
      SessionModule.sessionHandoffReceipt := by
  intro canStart
  exact handoffNotRequired canStart.guardHolds

theorem projection_without_runtime_owner_blocks_handoff_receipt
    {facts : SessionFactEnv}
    {activeScope : SessionScope}
    (notMarlinOwner :
      ¬ facts SessionFact.runtimeOwnerMarlin) :
    ¬ CanStart
      sessionSpec
      (sessionStateOfFacts activeScope facts)
      SessionModule.sessionHandoffReceipt := by
  intro canStart
  exact notMarlinOwner canStart.policyHolds.right

theorem strict_projection_blocks_handoff_receipt_without_runtime_summary
    {graph : StrictAgentGraphProjection}
    {baseFacts : SessionFactEnv}
    {activeScope : SessionScope}
    (missingRuntimeSummary :
      ¬ baseFacts SessionFact.runtimeSummaryPresent) :
    ¬ CanStart
      sessionSpec
      (sessionStateOfFacts activeScope
        (strictSessionFactsOfAgentGraphProjection graph baseFacts))
      SessionModule.sessionHandoffReceipt :=
  projection_without_runtime_summary_blocks_handoff_receipt
    (facts := strictSessionFactsOfAgentGraphProjection graph baseFacts)
    missingRuntimeSummary

theorem strict_projection_blocks_handoff_receipt_without_runtime_owner
    {graph : StrictAgentGraphProjection}
    {baseFacts : SessionFactEnv}
    {activeScope : SessionScope}
    (missingRuntimeOwner :
      ¬ baseFacts SessionFact.runtimeOwnerMarlin) :
    ¬ CanStart
      sessionSpec
      (sessionStateOfFacts activeScope
        (strictSessionFactsOfAgentGraphProjection graph baseFacts))
      SessionModule.sessionHandoffReceipt :=
  projection_without_runtime_owner_blocks_handoff_receipt
    (facts := strictSessionFactsOfAgentGraphProjection graph baseFacts)
    missingRuntimeOwner

theorem strict_projection_blocks_handoff_receipt_when_handoff_not_required
    {graph : StrictAgentGraphProjection}
    {baseFacts : SessionFactEnv}
    {activeScope : SessionScope}
    (handoffNotRequired :
      ¬ baseFacts SessionFact.handoffRequiredTrue) :
    ¬ CanStart
      sessionSpec
      (sessionStateOfFacts activeScope
        (strictSessionFactsOfAgentGraphProjection graph baseFacts))
      SessionModule.sessionHandoffReceipt :=
  projection_without_handoff_required_blocks_handoff_receipt
    (facts := strictSessionFactsOfAgentGraphProjection graph baseFacts)
    handoffNotRequired

theorem runtime_handoff_requires_handoff_receipt
    {state : SessionState}
    (canStart : CanStart sessionSpec state SessionModule.runtimeHandoff) :
    state.handoffReceiptPresent :=
  deps_completed_of_can_start canStart SessionDependsOn.handoffReceipt

theorem handoff_summary_requires_runtime_handoff
    {state : SessionState}
    (canStart : CanStart sessionSpec state SessionModule.handoffSummary) :
    state.runtimeHandoffPresent :=
  deps_completed_of_can_start canStart SessionDependsOn.summaryHandoff

theorem message_dispatch_requires_registered_pair
    {state : SessionState}
    (consistent : SessionStateConsistent state)
    (canStart : CanStart sessionSpec state SessionModule.messageDispatch) :
    state.agentRegistered ∧
    state.subagentRegistered ∧
    state.channelAuthorized := by
  let channelDone := message_dispatch_requires_channel_authorization canStart
  let agentDone := consistent.channelAfterAgent channelDone
  let subagentDone := consistent.channelAfterSubagent channelDone
  exact And.intro agentDone (And.intro subagentDone channelDone)

theorem handoff_summary_requires_complete_lifecycle
    {state : SessionState}
    (consistent : SessionStateConsistent state)
    (canStart : CanStart sessionSpec state SessionModule.handoffSummary) :
    state.chunkPresent ∧
    state.lineagePresent ∧
    state.placementPresent ∧
    state.placementResolved ∧
    state.valuePresent ∧
    state.agentRegistered ∧
    state.subagentRegistered ∧
    state.channelAuthorized ∧
    state.messageDispatched ∧
    state.runtimeSummaryPresent ∧
    state.handoffReceiptPresent ∧
    state.runtimeHandoffPresent := by
  let runtimeDone := handoff_summary_requires_runtime_handoff canStart
  let receiptDone := consistent.runtimeAfterReceipt runtimeDone
  let runtimeSummaryDone := consistent.receiptAfterRuntimeSummary receiptDone
  let messageDone := consistent.runtimeSummaryAfterMessage runtimeSummaryDone
  let channelDone := consistent.messageAfterChannel messageDone
  let agentDone := consistent.channelAfterAgent channelDone
  let subagentDone := consistent.channelAfterSubagent channelDone
  let valueDone := consistent.agentAfterValue agentDone
  let placementResolved := consistent.valueAfterResolution valueDone
  let placementDone := consistent.resolutionAfterPlacement placementResolved
  let lineageDone := consistent.resolutionAfterLineage placementResolved
  let chunkDone := consistent.lineageAfterChunk lineageDone
  exact
    And.intro chunkDone
      (And.intro lineageDone
        (And.intro placementDone
          (And.intro placementResolved
            (And.intro valueDone
              (And.intro agentDone
                (And.intro subagentDone
                  (And.intro channelDone
                    (And.intro messageDone
                      (And.intro runtimeSummaryDone
                        (And.intro receiptDone runtimeDone))))))))))

theorem handoff_summary_required_conditions
    {state : SessionState}
    (canStart : CanStart sessionSpec state SessionModule.handoffSummary) :
    RequiredConditions sessionSpec state SessionModule.handoffSummary :=
  required_conditions_of_can_start canStart

end AgenticAILabProof.PooC4.SessionLifecycle
