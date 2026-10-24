-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.FactContract.Target

namespace AgenticAILabProof.PooC4.FactContract

def sessionHandoffSchemeFactKeys : List SchemeFactKey :=
  [ SchemeFactKey.sessionLifecycleChunkPresent
  , SchemeFactKey.sessionLifecyclePlacementResolved
  , SchemeFactKey.sessionLifecyclePlacementMissingProfile
  , SchemeFactKey.sessionLifecycleRuntimeSummaryPresent
  , SchemeFactKey.sessionLifecycleHandoffReceiptPresent
  , SchemeFactKey.sessionLifecycleRuntimeExecutedFalse
  , SchemeFactKey.sessionLifecycleHandoffRequiredTrue
  , SchemeFactKey.sessionLifecycleRuntimeOwnerMarlin
  , SchemeFactKey.sessionLifecycleRuntimeParsesSchemeSourceFalse
  , SchemeFactKey.sessionLifecycleSchemeManufacturesRuntimeHandlersFalse
  , SchemeFactKey.scenarioBridgeS3HandoffReceipt
  , SchemeFactKey.scenarioBridgeS11AgentRegistered
  , SchemeFactKey.scenarioBridgeS11SubagentRegistered
  , SchemeFactKey.scenarioBridgeS11ChannelAuthorized
  , SchemeFactKey.scenarioBridgeS14PlacementMissingProfile
  ]

def sessionHandoffFactKeyContracts : List FactKeyContract :=
  [ { key := SchemeFactKey.sessionLifecycleChunkPresent
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.sessionFact
          SessionLifecycle.SessionFact.chunkPresent
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.sessionLifecyclePlacementResolved
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.sessionFact
          SessionLifecycle.SessionFact.placementResolved
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.sessionLifecyclePlacementMissingProfile
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.sessionFact
          SessionLifecycle.SessionFact.placementMissingProfile
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.sessionLifecycleRuntimeSummaryPresent
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.sessionFact
          SessionLifecycle.SessionFact.runtimeSummaryPresent
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.sessionLifecycleHandoffReceiptPresent
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.sessionFact
          SessionLifecycle.SessionFact.handoffReceiptPresent
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.sessionLifecycleRuntimeExecutedFalse
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.sessionFact
          SessionLifecycle.SessionFact.runtimeExecutedFalse
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.sessionLifecycleHandoffRequiredTrue
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.sessionFact
          SessionLifecycle.SessionFact.handoffRequiredTrue
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.sessionLifecycleRuntimeOwnerMarlin
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.sessionFact
          SessionLifecycle.SessionFact.runtimeOwnerMarlin
      polarity := FactPolarity.positive }
  , { key :=
        SchemeFactKey.sessionLifecycleRuntimeParsesSchemeSourceFalse
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.sessionFact
          SessionLifecycle.SessionFact.runtimeParsesSchemeSourceFalse
      polarity := FactPolarity.positive }
  , { key :=
        SchemeFactKey.sessionLifecycleSchemeManufacturesRuntimeHandlersFalse
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.sessionFact
          SessionLifecycle.SessionFact.schemeManufacturesRuntimeHandlersFalse
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.scenarioBridgeS3HandoffReceipt
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.scenarioBridgeFact
          ScenarioProof.ScenarioBridgeFact.s3HandoffReceipt
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.scenarioBridgeS11AgentRegistered
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.scenarioBridgeFact
          ScenarioProof.ScenarioBridgeFact.s11AgentRegistered
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.scenarioBridgeS11SubagentRegistered
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.scenarioBridgeFact
          ScenarioProof.ScenarioBridgeFact.s11SubagentRegistered
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.scenarioBridgeS11ChannelAuthorized
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.scenarioBridgeFact
          ScenarioProof.ScenarioBridgeFact.s11ChannelAuthorized
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.scenarioBridgeS14PlacementMissingProfile
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.scenarioBridgeFact
          ScenarioProof.ScenarioBridgeFact.s14PlacementMissingProfile
      polarity := FactPolarity.positive }
  ]

theorem session_handoff_contract_keys_exact :
    factKeyContractKeys sessionHandoffFactKeyContracts =
      sessionHandoffSchemeFactKeys :=
  rfl

theorem session_handoff_contracts_well_typed :
    ∀ contract,
      contract ∈ sessionHandoffFactKeyContracts ->
      contract.wellTyped := by
  intro contract member
  simp
    [ sessionHandoffFactKeyContracts
    , FactKeyContract.wellTyped
    , LeanFactTarget.expectedSource
    , LeanFactTarget.expectedKind
    , LeanFactTarget.expectedPolarity
    , SchemeFactKey.source
    ] at member ⊢
  rcases member with
    member | member | member | member | member |
    member | member | member | member | member |
    member | member | member | member | member
  <;> subst contract
  <;> native_decide

theorem session_handoff_contracts_exactly_typed :
    ∀ contract,
      contract ∈ sessionHandoffFactKeyContracts ->
      contract.exactlyTyped := by
  intro contract member
  simp
    [ sessionHandoffFactKeyContracts
    , FactKeyContract.exactlyTyped
    , FactKeyContract.exactTarget
    , FactKeyContract.wellTyped
    , SchemeFactKey.expectedTarget
    , LeanFactTarget.expectedSource
    , LeanFactTarget.expectedKind
    , LeanFactTarget.expectedPolarity
    , SchemeFactKey.source
    ] at member ⊢
  rcases member with
    member | member | member | member | member |
    member | member | member | member | member |
    member | member | member | member | member
  <;> subst contract
  <;> native_decide

end AgenticAILabProof.PooC4.FactContract
