-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.FactContract.Failure
import AgenticAILabProof.PooC4.ScenarioProof

namespace AgenticAILabProof.PooC4.FactContract

inductive LeanFactTarget where
  | sessionFact : SessionLifecycle.SessionFact -> LeanFactTarget
  | scenarioBridgeFact : ScenarioProof.ScenarioBridgeFact -> LeanFactTarget
  | uiScenarioFact : UserInterface.UiScenarioFact -> LeanFactTarget
  | uiFailureTheorem : UiFailureTheorem -> LeanFactTarget
deriving Repr, DecidableEq

def LeanFactTarget.expectedKind : LeanFactTarget -> FactContractKind
  | sessionFact _ => FactContractKind.fact
  | scenarioBridgeFact _ => FactContractKind.fact
  | uiScenarioFact _ => FactContractKind.fact
  | uiFailureTheorem _ => FactContractKind.failureObligation

def LeanFactTarget.expectedSource : LeanFactTarget -> SchemeFactSource
  | sessionFact _ => SchemeFactSource.sessionLifecycle
  | scenarioBridgeFact _ => SchemeFactSource.scenarioBridge
  | uiScenarioFact _ => SchemeFactSource.uiScenario
  | uiFailureTheorem _ => SchemeFactSource.uiFailure

def LeanFactTarget.expectedPolarity : LeanFactTarget -> FactPolarity
  | sessionFact _ => FactPolarity.positive
  | scenarioBridgeFact _ => FactPolarity.positive
  | uiScenarioFact _ => FactPolarity.positive
  | uiFailureTheorem _ => FactPolarity.missing

def SchemeFactKey.expectedTarget : SchemeFactKey -> LeanFactTarget
  | sessionLifecycleChunkPresent =>
      LeanFactTarget.sessionFact
        SessionLifecycle.SessionFact.chunkPresent
  | sessionLifecyclePlacementResolved =>
      LeanFactTarget.sessionFact
        SessionLifecycle.SessionFact.placementResolved
  | sessionLifecyclePlacementMissingProfile =>
      LeanFactTarget.sessionFact
        SessionLifecycle.SessionFact.placementMissingProfile
  | sessionLifecycleRuntimeSummaryPresent =>
      LeanFactTarget.sessionFact
        SessionLifecycle.SessionFact.runtimeSummaryPresent
  | sessionLifecycleHandoffReceiptPresent =>
      LeanFactTarget.sessionFact
        SessionLifecycle.SessionFact.handoffReceiptPresent
  | sessionLifecycleRuntimeExecutedFalse =>
      LeanFactTarget.sessionFact
        SessionLifecycle.SessionFact.runtimeExecutedFalse
  | sessionLifecycleHandoffRequiredTrue =>
      LeanFactTarget.sessionFact
        SessionLifecycle.SessionFact.handoffRequiredTrue
  | sessionLifecycleRuntimeOwnerMarlin =>
      LeanFactTarget.sessionFact
        SessionLifecycle.SessionFact.runtimeOwnerMarlin
  | sessionLifecycleRuntimeParsesSchemeSourceFalse =>
      LeanFactTarget.sessionFact
        SessionLifecycle.SessionFact.runtimeParsesSchemeSourceFalse
  | sessionLifecycleSchemeManufacturesRuntimeHandlersFalse =>
      LeanFactTarget.sessionFact
        SessionLifecycle.SessionFact.schemeManufacturesRuntimeHandlersFalse
  | scenarioBridgeS3HandoffReceipt =>
      LeanFactTarget.scenarioBridgeFact
        ScenarioProof.ScenarioBridgeFact.s3HandoffReceipt
  | scenarioBridgeS11AgentRegistered =>
      LeanFactTarget.scenarioBridgeFact
        ScenarioProof.ScenarioBridgeFact.s11AgentRegistered
  | scenarioBridgeS11SubagentRegistered =>
      LeanFactTarget.scenarioBridgeFact
        ScenarioProof.ScenarioBridgeFact.s11SubagentRegistered
  | scenarioBridgeS11ChannelAuthorized =>
      LeanFactTarget.scenarioBridgeFact
        ScenarioProof.ScenarioBridgeFact.s11ChannelAuthorized
  | scenarioBridgeS14PlacementMissingProfile =>
      LeanFactTarget.scenarioBridgeFact
        ScenarioProof.ScenarioBridgeFact.s14PlacementMissingProfile
  | uiScenarioUseCaseDeclared =>
      LeanFactTarget.uiScenarioFact
        UserInterface.UiScenarioFact.useCaseDeclared
  | uiScenarioProfileDeclared =>
      LeanFactTarget.uiScenarioFact
        UserInterface.UiScenarioFact.profileDeclared
  | uiScenarioGovernorConfigured =>
      LeanFactTarget.uiScenarioFact
        UserInterface.UiScenarioFact.governorConfigured
  | uiScenarioLineagePolicyDone =>
      LeanFactTarget.uiScenarioFact
        UserInterface.UiScenarioFact.lineagePolicyDone
  | uiScenarioSelectorPolicyDone =>
      LeanFactTarget.uiScenarioFact
        UserInterface.UiScenarioFact.selectorPolicyDone
  | uiScenarioResourcePolicyDone =>
      LeanFactTarget.uiScenarioFact
        UserInterface.UiScenarioFact.resourcePolicyDone
  | uiScenarioCapabilityPolicyDone =>
      LeanFactTarget.uiScenarioFact
        UserInterface.UiScenarioFact.capabilityPolicyDone
  | uiScenarioMemoryPolicyDone =>
      LeanFactTarget.uiScenarioFact
        UserInterface.UiScenarioFact.memoryPolicyDone
  | uiScenarioCompressionPolicyDone =>
      LeanFactTarget.uiScenarioFact
        UserInterface.UiScenarioFact.compressionPolicyDone
  | uiScenarioStrategyPlanDone =>
      LeanFactTarget.uiScenarioFact
        UserInterface.UiScenarioFact.strategyPlanDone
  | uiScenarioLocalValidationDone =>
      LeanFactTarget.uiScenarioFact
        UserInterface.UiScenarioFact.localValidationDone
  | uiScenarioRuntimeManifestDone =>
      LeanFactTarget.uiScenarioFact
        UserInterface.UiScenarioFact.runtimeManifestDone
  | uiScenarioMarlinHandoffDone =>
      LeanFactTarget.uiScenarioFact
        UserInterface.UiScenarioFact.marlinHandoffDone
  | uiScenarioL1ReportDone =>
      LeanFactTarget.uiScenarioFact
        UserInterface.UiScenarioFact.l1ReportDone
  | uiScenarioScenarioMatrixDone =>
      LeanFactTarget.uiScenarioFact
        UserInterface.UiScenarioFact.scenarioMatrixDone
  | uiScenarioScenarioBenchmarkDone =>
      LeanFactTarget.uiScenarioFact
        UserInterface.UiScenarioFact.scenarioBenchmarkDone
  | uiScenarioPerformanceFixtureBound =>
      LeanFactTarget.uiScenarioFact
        UserInterface.UiScenarioFact.performanceFixtureBound
  | uiFailureStrategyMissingSelectorPolicy =>
      LeanFactTarget.uiFailureTheorem
        UiFailureTheorem.strategyMissingSelectorPolicy
  | uiFailureStrategyMissingResourcePolicy =>
      LeanFactTarget.uiFailureTheorem
        UiFailureTheorem.strategyMissingResourcePolicy
  | uiFailureStrategyMissingCapabilityPolicy =>
      LeanFactTarget.uiFailureTheorem
        UiFailureTheorem.strategyMissingCapabilityPolicy
  | uiFailureLocalValidationMissingStrategyPlan =>
      LeanFactTarget.uiFailureTheorem
        UiFailureTheorem.localValidationMissingStrategyPlan
  | uiFailureRuntimeManifestMissingStrategyPlan =>
      LeanFactTarget.uiFailureTheorem
        UiFailureTheorem.runtimeManifestMissingStrategyPlan
  | uiFailureRuntimeManifestMissingLocalValidation =>
      LeanFactTarget.uiFailureTheorem
        UiFailureTheorem.runtimeManifestMissingLocalValidation
  | uiFailureRuntimeManifestMissingMemoryPolicy =>
      LeanFactTarget.uiFailureTheorem
        UiFailureTheorem.runtimeManifestMissingMemoryPolicy
  | uiFailureRuntimeManifestMissingCompressionPolicy =>
      LeanFactTarget.uiFailureTheorem
        UiFailureTheorem.runtimeManifestMissingCompressionPolicy
  | uiFailureHandoffMissingRuntimeManifest =>
      LeanFactTarget.uiFailureTheorem
        UiFailureTheorem.handoffMissingRuntimeManifest
  | uiFailureBenchmarkMissingScenarioMatrix =>
      LeanFactTarget.uiFailureTheorem
        UiFailureTheorem.benchmarkMissingScenarioMatrix
  | uiFailureBenchmarkMissingL1Report =>
      LeanFactTarget.uiFailureTheorem
        UiFailureTheorem.benchmarkMissingL1Report
  | uiFailureBenchmarkMissingPerformanceFixture =>
      LeanFactTarget.uiFailureTheorem
        UiFailureTheorem.benchmarkMissingPerformanceFixture

theorem UiFailureTheorem.contract_key_expected_target
    (theoremName : UiFailureTheorem) :
    theoremName.contractKey.expectedTarget =
      LeanFactTarget.uiFailureTheorem theoremName := by
  cases theoremName <;> rfl

structure FactKeyContract where
  key : SchemeFactKey
  kind : FactContractKind
  target : LeanFactTarget
  polarity : FactPolarity
deriving Repr, DecidableEq

def FactKeyContract.wellTyped
    (contract : FactKeyContract) : Prop :=
  contract.key.source = contract.target.expectedSource ∧
  contract.kind = contract.target.expectedKind ∧
  contract.polarity = contract.target.expectedPolarity

def FactKeyContract.exactTarget
    (contract : FactKeyContract) : Prop :=
  contract.target = contract.key.expectedTarget

def FactKeyContract.exactlyTyped
    (contract : FactKeyContract) : Prop :=
  contract.exactTarget ∧ contract.wellTyped

def factKeyContractKeys
    (contracts : List FactKeyContract) : List SchemeFactKey :=
  contracts.map (fun contract => contract.key)

end AgenticAILabProof.PooC4.FactContract
