-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.FactContract.Base
import AgenticAILabProof.PooC4.UserInterface

namespace AgenticAILabProof.PooC4.FactContract

open AgenticAILabProof.PooC4

inductive UiFailureTheorem where
  | strategyMissingSelectorPolicy
  | strategyMissingResourcePolicy
  | strategyMissingCapabilityPolicy
  | localValidationMissingStrategyPlan
  | runtimeManifestMissingStrategyPlan
  | runtimeManifestMissingLocalValidation
  | runtimeManifestMissingMemoryPolicy
  | runtimeManifestMissingCompressionPolicy
  | handoffMissingRuntimeManifest
  | benchmarkMissingScenarioMatrix
  | benchmarkMissingL1Report
  | benchmarkMissingPerformanceFixture
deriving Repr, DecidableEq

def UiFailureTheorem.contractKey : UiFailureTheorem -> SchemeFactKey
  | strategyMissingSelectorPolicy =>
      SchemeFactKey.uiFailureStrategyMissingSelectorPolicy
  | strategyMissingResourcePolicy =>
      SchemeFactKey.uiFailureStrategyMissingResourcePolicy
  | strategyMissingCapabilityPolicy =>
      SchemeFactKey.uiFailureStrategyMissingCapabilityPolicy
  | localValidationMissingStrategyPlan =>
      SchemeFactKey.uiFailureLocalValidationMissingStrategyPlan
  | runtimeManifestMissingStrategyPlan =>
      SchemeFactKey.uiFailureRuntimeManifestMissingStrategyPlan
  | runtimeManifestMissingLocalValidation =>
      SchemeFactKey.uiFailureRuntimeManifestMissingLocalValidation
  | runtimeManifestMissingMemoryPolicy =>
      SchemeFactKey.uiFailureRuntimeManifestMissingMemoryPolicy
  | runtimeManifestMissingCompressionPolicy =>
      SchemeFactKey.uiFailureRuntimeManifestMissingCompressionPolicy
  | handoffMissingRuntimeManifest =>
      SchemeFactKey.uiFailureHandoffMissingRuntimeManifest
  | benchmarkMissingScenarioMatrix =>
      SchemeFactKey.uiFailureBenchmarkMissingScenarioMatrix
  | benchmarkMissingL1Report =>
      SchemeFactKey.uiFailureBenchmarkMissingL1Report
  | benchmarkMissingPerformanceFixture =>
      SchemeFactKey.uiFailureBenchmarkMissingPerformanceFixture

def UiFailureTheorem.missingFact :
    UiFailureTheorem -> UserInterface.UiScenarioFact
  | strategyMissingSelectorPolicy =>
      UserInterface.UiScenarioFact.selectorPolicyDone
  | strategyMissingResourcePolicy =>
      UserInterface.UiScenarioFact.resourcePolicyDone
  | strategyMissingCapabilityPolicy =>
      UserInterface.UiScenarioFact.capabilityPolicyDone
  | localValidationMissingStrategyPlan =>
      UserInterface.UiScenarioFact.strategyPlanDone
  | runtimeManifestMissingStrategyPlan =>
      UserInterface.UiScenarioFact.strategyPlanDone
  | runtimeManifestMissingLocalValidation =>
      UserInterface.UiScenarioFact.localValidationDone
  | runtimeManifestMissingMemoryPolicy =>
      UserInterface.UiScenarioFact.memoryPolicyDone
  | runtimeManifestMissingCompressionPolicy =>
      UserInterface.UiScenarioFact.compressionPolicyDone
  | handoffMissingRuntimeManifest =>
      UserInterface.UiScenarioFact.runtimeManifestDone
  | benchmarkMissingScenarioMatrix =>
      UserInterface.UiScenarioFact.scenarioMatrixDone
  | benchmarkMissingL1Report =>
      UserInterface.UiScenarioFact.l1ReportDone
  | benchmarkMissingPerformanceFixture =>
      UserInterface.UiScenarioFact.performanceFixtureBound

def UiFailureTheorem.blockedModule :
    UiFailureTheorem -> UserInterface.UiModule
  | strategyMissingSelectorPolicy => UserInterface.UiModule.strategyPlan
  | strategyMissingResourcePolicy => UserInterface.UiModule.strategyPlan
  | strategyMissingCapabilityPolicy => UserInterface.UiModule.strategyPlan
  | localValidationMissingStrategyPlan =>
      UserInterface.UiModule.localValidation
  | runtimeManifestMissingStrategyPlan =>
      UserInterface.UiModule.runtimeManifest
  | runtimeManifestMissingLocalValidation =>
      UserInterface.UiModule.runtimeManifest
  | runtimeManifestMissingMemoryPolicy =>
      UserInterface.UiModule.runtimeManifest
  | runtimeManifestMissingCompressionPolicy =>
      UserInterface.UiModule.runtimeManifest
  | handoffMissingRuntimeManifest => UserInterface.UiModule.marlinHandoff
  | benchmarkMissingScenarioMatrix =>
      UserInterface.UiModule.scenarioBenchmark
  | benchmarkMissingL1Report => UserInterface.UiModule.scenarioBenchmark
  | benchmarkMissingPerformanceFixture =>
      UserInterface.UiModule.scenarioBenchmark

def uiScenarioFactCompletedModule :
    UserInterface.UiScenarioFact -> Option UserInterface.UiModule
  | UserInterface.UiScenarioFact.useCaseDeclared =>
      some UserInterface.UiModule.loopEngineUseCase
  | UserInterface.UiScenarioFact.profileDeclared =>
      some UserInterface.UiModule.loopEngineProfile
  | UserInterface.UiScenarioFact.governorConfigured =>
      some UserInterface.UiModule.loopEngineGovernor
  | UserInterface.UiScenarioFact.lineagePolicyDone =>
      some UserInterface.UiModule.lineagePolicy
  | UserInterface.UiScenarioFact.selectorPolicyDone =>
      some UserInterface.UiModule.selectorPolicy
  | UserInterface.UiScenarioFact.resourcePolicyDone =>
      some UserInterface.UiModule.resourcePolicy
  | UserInterface.UiScenarioFact.capabilityPolicyDone =>
      some UserInterface.UiModule.capabilityPolicy
  | UserInterface.UiScenarioFact.memoryPolicyDone =>
      some UserInterface.UiModule.memoryPolicy
  | UserInterface.UiScenarioFact.compressionPolicyDone =>
      some UserInterface.UiModule.compressionPolicy
  | UserInterface.UiScenarioFact.strategyPlanDone =>
      some UserInterface.UiModule.strategyPlan
  | UserInterface.UiScenarioFact.localValidationDone =>
      some UserInterface.UiModule.localValidation
  | UserInterface.UiScenarioFact.runtimeManifestDone =>
      some UserInterface.UiModule.runtimeManifest
  | UserInterface.UiScenarioFact.marlinHandoffDone =>
      some UserInterface.UiModule.marlinHandoff
  | UserInterface.UiScenarioFact.l1ReportDone =>
      some UserInterface.UiModule.l1Report
  | UserInterface.UiScenarioFact.scenarioMatrixDone =>
      some UserInterface.UiModule.scenarioMatrix
  | UserInterface.UiScenarioFact.scenarioBenchmarkDone =>
      some UserInterface.UiModule.scenarioBenchmark
  | UserInterface.UiScenarioFact.performanceFixtureBound => none

def UiFailureTheorem.missingModule? :
    UiFailureTheorem -> Option UserInterface.UiModule :=
  fun theoremName => uiScenarioFactCompletedModule theoremName.missingFact

def UiFailureTheorem.requiredBySpec
    (theoremName : UiFailureTheorem) : Prop :=
  match theoremName.missingModule? with
  | some dependency =>
      UserInterface.UiDependsOn theoremName.blockedModule dependency
  | none =>
      theoremName.blockedModule =
        UserInterface.UiModule.scenarioBenchmark ∧
      theoremName.missingFact =
        UserInterface.UiScenarioFact.performanceFixtureBound

theorem UiFailureTheorem.missing_fact_required_by_spec
    (theoremName : UiFailureTheorem) :
    theoremName.requiredBySpec := by
  cases theoremName
  · exact UserInterface.UiDependsOn.strategySelector
  · exact UserInterface.UiDependsOn.strategyResource
  · exact UserInterface.UiDependsOn.strategyCapability
  · exact UserInterface.UiDependsOn.validationStrategy
  · exact UserInterface.UiDependsOn.runtimeStrategy
  · exact UserInterface.UiDependsOn.runtimeValidation
  · exact UserInterface.UiDependsOn.runtimeMemory
  · exact UserInterface.UiDependsOn.runtimeCompression
  · exact UserInterface.UiDependsOn.handoffRuntime
  · exact UserInterface.UiDependsOn.benchmarkMatrix
  · exact UserInterface.UiDependsOn.benchmarkReport
  · exact And.intro rfl rfl

theorem UiFailureTheorem.benchmark_fixture_guard_reflects_missing_fact
    {facts : UserInterface.UiScenarioFactEnv}
    {activeScope : UserInterface.UiScope}
    (missingFixture :
      ¬ facts UserInterface.UiScenarioFact.performanceFixtureBound) :
    ¬ UserInterface.uiGuard
      (UserInterface.uiScenarioStateOfFacts activeScope facts)
      UserInterface.UiModule.scenarioBenchmark :=
  missingFixture

def UiFailureTheorem.statement
    (theoremName : UiFailureTheorem) : Prop :=
  ∀ {facts : UserInterface.UiScenarioFactEnv}
    {activeScope : UserInterface.UiScope},
    (¬ facts theoremName.missingFact) ->
    ¬ CanStart
      UserInterface.uiSpec
      (UserInterface.uiScenarioStateOfFacts activeScope facts)
      theoremName.blockedModule

theorem UiFailureTheorem.required_fact_of_can_start
    (theoremName : UiFailureTheorem)
    {facts : UserInterface.UiScenarioFactEnv}
    {activeScope : UserInterface.UiScope}
    (canStart :
      CanStart
        UserInterface.uiSpec
        (UserInterface.uiScenarioStateOfFacts activeScope facts)
        theoremName.blockedModule) :
    facts theoremName.missingFact := by
  cases theoremName
  · exact
      UserInterface.strategy_plan_requires_selector_policy canStart
  · exact
      UserInterface.strategy_plan_requires_resource_policy canStart
  · exact
      UserInterface.strategy_plan_requires_capability_policy canStart
  · exact
      UserInterface.local_validation_requires_strategy_plan canStart
  · exact
      UserInterface.runtime_manifest_requires_strategy_plan canStart
  · exact
      UserInterface.runtime_manifest_requires_local_validation canStart
  · exact
      UserInterface.runtime_manifest_requires_memory_policy canStart
  · exact
      UserInterface.runtime_manifest_requires_compression_policy canStart
  · exact
      UserInterface.marlin_handoff_requires_runtime_manifest canStart
  · exact
      UserInterface.scenario_benchmark_requires_matrix canStart
  · exact
      UserInterface.scenario_benchmark_requires_l1_report canStart
  · exact
      UserInterface.scenario_benchmark_requires_performance_fixture canStart

def UiFailureTheorem.proof :
    (theoremName : UiFailureTheorem) ->
      theoremName.statement
  | theoremName => by
      intro missingFact canStart
      exact
        missingFact
          (theoremName.required_fact_of_can_start canStart)

theorem UiFailureTheorem.blocks_missing_fact
    (theoremName : UiFailureTheorem) :
    theoremName.statement :=
  theoremName.proof

end AgenticAILabProof.PooC4.FactContract
