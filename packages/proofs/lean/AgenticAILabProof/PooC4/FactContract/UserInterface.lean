-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.FactContract.Target

namespace AgenticAILabProof.PooC4.FactContract

def uiScenarioSchemeFactKeys : List SchemeFactKey :=
  [ SchemeFactKey.uiScenarioUseCaseDeclared
  , SchemeFactKey.uiScenarioProfileDeclared
  , SchemeFactKey.uiScenarioGovernorConfigured
  , SchemeFactKey.uiScenarioLineagePolicyDone
  , SchemeFactKey.uiScenarioSelectorPolicyDone
  , SchemeFactKey.uiScenarioResourcePolicyDone
  , SchemeFactKey.uiScenarioCapabilityPolicyDone
  , SchemeFactKey.uiScenarioMemoryPolicyDone
  , SchemeFactKey.uiScenarioCompressionPolicyDone
  , SchemeFactKey.uiScenarioStrategyPlanDone
  , SchemeFactKey.uiScenarioLocalValidationDone
  , SchemeFactKey.uiScenarioRuntimeManifestDone
  , SchemeFactKey.uiScenarioMarlinHandoffDone
  , SchemeFactKey.uiScenarioL1ReportDone
  , SchemeFactKey.uiScenarioScenarioMatrixDone
  , SchemeFactKey.uiScenarioScenarioBenchmarkDone
  , SchemeFactKey.uiScenarioPerformanceFixtureBound
  , SchemeFactKey.uiFailureStrategyMissingSelectorPolicy
  , SchemeFactKey.uiFailureStrategyMissingResourcePolicy
  , SchemeFactKey.uiFailureStrategyMissingCapabilityPolicy
  , SchemeFactKey.uiFailureLocalValidationMissingStrategyPlan
  , SchemeFactKey.uiFailureRuntimeManifestMissingStrategyPlan
  , SchemeFactKey.uiFailureRuntimeManifestMissingLocalValidation
  , SchemeFactKey.uiFailureRuntimeManifestMissingMemoryPolicy
  , SchemeFactKey.uiFailureRuntimeManifestMissingCompressionPolicy
  , SchemeFactKey.uiFailureHandoffMissingRuntimeManifest
  , SchemeFactKey.uiFailureBenchmarkMissingScenarioMatrix
  , SchemeFactKey.uiFailureBenchmarkMissingL1Report
  , SchemeFactKey.uiFailureBenchmarkMissingPerformanceFixture
  ]

def uiScenarioFactKeyContracts : List FactKeyContract :=
  [ { key := SchemeFactKey.uiScenarioUseCaseDeclared
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.uiScenarioFact
          UserInterface.UiScenarioFact.useCaseDeclared
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.uiScenarioProfileDeclared
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.uiScenarioFact
          UserInterface.UiScenarioFact.profileDeclared
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.uiScenarioGovernorConfigured
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.uiScenarioFact
          UserInterface.UiScenarioFact.governorConfigured
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.uiScenarioLineagePolicyDone
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.uiScenarioFact
          UserInterface.UiScenarioFact.lineagePolicyDone
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.uiScenarioSelectorPolicyDone
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.uiScenarioFact
          UserInterface.UiScenarioFact.selectorPolicyDone
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.uiScenarioResourcePolicyDone
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.uiScenarioFact
          UserInterface.UiScenarioFact.resourcePolicyDone
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.uiScenarioCapabilityPolicyDone
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.uiScenarioFact
          UserInterface.UiScenarioFact.capabilityPolicyDone
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.uiScenarioMemoryPolicyDone
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.uiScenarioFact
          UserInterface.UiScenarioFact.memoryPolicyDone
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.uiScenarioCompressionPolicyDone
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.uiScenarioFact
          UserInterface.UiScenarioFact.compressionPolicyDone
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.uiScenarioStrategyPlanDone
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.uiScenarioFact
          UserInterface.UiScenarioFact.strategyPlanDone
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.uiScenarioLocalValidationDone
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.uiScenarioFact
          UserInterface.UiScenarioFact.localValidationDone
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.uiScenarioRuntimeManifestDone
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.uiScenarioFact
          UserInterface.UiScenarioFact.runtimeManifestDone
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.uiScenarioMarlinHandoffDone
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.uiScenarioFact
          UserInterface.UiScenarioFact.marlinHandoffDone
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.uiScenarioL1ReportDone
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.uiScenarioFact
          UserInterface.UiScenarioFact.l1ReportDone
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.uiScenarioScenarioMatrixDone
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.uiScenarioFact
          UserInterface.UiScenarioFact.scenarioMatrixDone
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.uiScenarioScenarioBenchmarkDone
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.uiScenarioFact
          UserInterface.UiScenarioFact.scenarioBenchmarkDone
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.uiScenarioPerformanceFixtureBound
      kind := FactContractKind.fact
      target :=
        LeanFactTarget.uiScenarioFact
          UserInterface.UiScenarioFact.performanceFixtureBound
      polarity := FactPolarity.positive }
  , { key := SchemeFactKey.uiFailureStrategyMissingSelectorPolicy
      kind := FactContractKind.failureObligation
      target :=
        LeanFactTarget.uiFailureTheorem
          UiFailureTheorem.strategyMissingSelectorPolicy
      polarity := FactPolarity.missing }
  , { key := SchemeFactKey.uiFailureStrategyMissingResourcePolicy
      kind := FactContractKind.failureObligation
      target :=
        LeanFactTarget.uiFailureTheorem
          UiFailureTheorem.strategyMissingResourcePolicy
      polarity := FactPolarity.missing }
  , { key := SchemeFactKey.uiFailureStrategyMissingCapabilityPolicy
      kind := FactContractKind.failureObligation
      target :=
        LeanFactTarget.uiFailureTheorem
          UiFailureTheorem.strategyMissingCapabilityPolicy
      polarity := FactPolarity.missing }
  , { key := SchemeFactKey.uiFailureLocalValidationMissingStrategyPlan
      kind := FactContractKind.failureObligation
      target :=
        LeanFactTarget.uiFailureTheorem
          UiFailureTheorem.localValidationMissingStrategyPlan
      polarity := FactPolarity.missing }
  , { key := SchemeFactKey.uiFailureRuntimeManifestMissingStrategyPlan
      kind := FactContractKind.failureObligation
      target :=
        LeanFactTarget.uiFailureTheorem
          UiFailureTheorem.runtimeManifestMissingStrategyPlan
      polarity := FactPolarity.missing }
  , { key :=
        SchemeFactKey.uiFailureRuntimeManifestMissingLocalValidation
      kind := FactContractKind.failureObligation
      target :=
        LeanFactTarget.uiFailureTheorem
          UiFailureTheorem.runtimeManifestMissingLocalValidation
      polarity := FactPolarity.missing }
  , { key := SchemeFactKey.uiFailureRuntimeManifestMissingMemoryPolicy
      kind := FactContractKind.failureObligation
      target :=
        LeanFactTarget.uiFailureTheorem
          UiFailureTheorem.runtimeManifestMissingMemoryPolicy
      polarity := FactPolarity.missing }
  , { key :=
        SchemeFactKey.uiFailureRuntimeManifestMissingCompressionPolicy
      kind := FactContractKind.failureObligation
      target :=
        LeanFactTarget.uiFailureTheorem
          UiFailureTheorem.runtimeManifestMissingCompressionPolicy
      polarity := FactPolarity.missing }
  , { key := SchemeFactKey.uiFailureHandoffMissingRuntimeManifest
      kind := FactContractKind.failureObligation
      target :=
        LeanFactTarget.uiFailureTheorem
          UiFailureTheorem.handoffMissingRuntimeManifest
      polarity := FactPolarity.missing }
  , { key := SchemeFactKey.uiFailureBenchmarkMissingScenarioMatrix
      kind := FactContractKind.failureObligation
      target :=
        LeanFactTarget.uiFailureTheorem
          UiFailureTheorem.benchmarkMissingScenarioMatrix
      polarity := FactPolarity.missing }
  , { key := SchemeFactKey.uiFailureBenchmarkMissingL1Report
      kind := FactContractKind.failureObligation
      target :=
        LeanFactTarget.uiFailureTheorem
          UiFailureTheorem.benchmarkMissingL1Report
      polarity := FactPolarity.missing }
  , { key := SchemeFactKey.uiFailureBenchmarkMissingPerformanceFixture
      kind := FactContractKind.failureObligation
      target :=
        LeanFactTarget.uiFailureTheorem
          UiFailureTheorem.benchmarkMissingPerformanceFixture
      polarity := FactPolarity.missing }
  ]

theorem ui_scenario_contract_keys_exact :
    factKeyContractKeys uiScenarioFactKeyContracts =
      uiScenarioSchemeFactKeys :=
  rfl

theorem ui_scenario_contracts_well_typed :
    ∀ contract,
      contract ∈ uiScenarioFactKeyContracts ->
      contract.wellTyped := by
  intro contract member
  simp
    [ uiScenarioFactKeyContracts
    , FactKeyContract.wellTyped
    , LeanFactTarget.expectedSource
    , LeanFactTarget.expectedKind
    , LeanFactTarget.expectedPolarity
    , SchemeFactKey.source
    ] at member ⊢
  rcases member with
    member | member | member | member | member |
    member | member | member | member | member |
    member | member | member | member | member |
    member | member | member | member | member |
    member | member | member | member | member |
    member | member | member | member
  <;> subst contract
  <;> native_decide

theorem ui_scenario_contracts_exactly_typed :
    ∀ contract,
      contract ∈ uiScenarioFactKeyContracts ->
      contract.exactlyTyped := by
  intro contract member
  simp
    [ uiScenarioFactKeyContracts
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
    member | member | member | member | member |
    member | member | member | member | member |
    member | member | member | member | member |
    member | member | member | member
  <;> subst contract
  <;> native_decide

end AgenticAILabProof.PooC4.FactContract
