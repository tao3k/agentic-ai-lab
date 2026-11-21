-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.Semantics

namespace AgenticAILabProof.PooC4.UserInterface

open AgenticAILabProof.PooC4

inductive UiModule where
  | loopEngineUseCase
  | loopEngineProfile
  | loopEngineGovernor
  | lineagePolicy
  | selectorPolicy
  | resourcePolicy
  | capabilityPolicy
  | memoryPolicy
  | compressionPolicy
  | strategyPlan
  | localValidation
  | runtimeManifest
  | marlinHandoff
  | l1Report
  | scenarioMatrix
  | scenarioBenchmark
deriving Repr, DecidableEq

abbrev UiScope := Nat

def declarationScope : UiScope := 0
def profileScope : UiScope := 1
def governorScope : UiScope := 2
def policyScope : UiScope := 3
def strategyScope : UiScope := 4
def validationScope : UiScope := 5
def runtimeScope : UiScope := 6
def handoffScope : UiScope := 7
def reportScope : UiScope := 8
def benchmarkScope : UiScope := 9

def uiScopeOrder : ScopeOrder UiScope :=
  { le := Nat.le
    refl := Nat.le_refl
    trans := fun first second => Nat.le_trans first second
    antisymm := fun first second => Nat.le_antisymm first second }

structure UiState where
  activeScope : UiScope
  useCaseDeclared : Prop
  profileDeclared : Prop
  governorConfigured : Prop
  lineagePolicyDone : Prop
  selectorPolicyDone : Prop
  resourcePolicyDone : Prop
  capabilityPolicyDone : Prop
  memoryPolicyDone : Prop
  compressionPolicyDone : Prop
  strategyPlanDone : Prop
  localValidationDone : Prop
  runtimeManifestDone : Prop
  marlinHandoffDone : Prop
  l1ReportDone : Prop
  scenarioMatrixDone : Prop
  scenarioBenchmarkDone : Prop
  performanceFixtureBound : Prop

inductive UiDependsOn : UiModule -> UiModule -> Prop where
  | profileUseCase :
      UiDependsOn UiModule.loopEngineProfile UiModule.loopEngineUseCase
  | governorProfile :
      UiDependsOn UiModule.loopEngineGovernor UiModule.loopEngineProfile
  | lineageGovernor :
      UiDependsOn UiModule.lineagePolicy UiModule.loopEngineGovernor
  | selectorGovernor :
      UiDependsOn UiModule.selectorPolicy UiModule.loopEngineGovernor
  | resourceGovernor :
      UiDependsOn UiModule.resourcePolicy UiModule.loopEngineGovernor
  | capabilityGovernor :
      UiDependsOn UiModule.capabilityPolicy UiModule.loopEngineGovernor
  | memoryGovernor :
      UiDependsOn UiModule.memoryPolicy UiModule.loopEngineGovernor
  | compressionGovernor :
      UiDependsOn UiModule.compressionPolicy UiModule.loopEngineGovernor
  | strategySelector :
      UiDependsOn UiModule.strategyPlan UiModule.selectorPolicy
  | strategyResource :
      UiDependsOn UiModule.strategyPlan UiModule.resourcePolicy
  | strategyCapability :
      UiDependsOn UiModule.strategyPlan UiModule.capabilityPolicy
  | validationStrategy :
      UiDependsOn UiModule.localValidation UiModule.strategyPlan
  | runtimeStrategy :
      UiDependsOn UiModule.runtimeManifest UiModule.strategyPlan
  | runtimeValidation :
      UiDependsOn UiModule.runtimeManifest UiModule.localValidation
  | runtimeMemory :
      UiDependsOn UiModule.runtimeManifest UiModule.memoryPolicy
  | runtimeCompression :
      UiDependsOn UiModule.runtimeManifest UiModule.compressionPolicy
  | handoffRuntime :
      UiDependsOn UiModule.marlinHandoff UiModule.runtimeManifest
  | reportHandoff :
      UiDependsOn UiModule.l1Report UiModule.marlinHandoff
  | matrixUseCase :
      UiDependsOn UiModule.scenarioMatrix UiModule.loopEngineUseCase
  | matrixProfile :
      UiDependsOn UiModule.scenarioMatrix UiModule.loopEngineProfile
  | matrixStrategy :
      UiDependsOn UiModule.scenarioMatrix UiModule.strategyPlan
  | benchmarkMatrix :
      UiDependsOn UiModule.scenarioBenchmark UiModule.scenarioMatrix
  | benchmarkReport :
      UiDependsOn UiModule.scenarioBenchmark UiModule.l1Report

def uiModuleScope : UiModule -> UiScope
  | UiModule.loopEngineUseCase => declarationScope
  | UiModule.loopEngineProfile => profileScope
  | UiModule.loopEngineGovernor => governorScope
  | UiModule.lineagePolicy => policyScope
  | UiModule.selectorPolicy => policyScope
  | UiModule.resourcePolicy => policyScope
  | UiModule.capabilityPolicy => policyScope
  | UiModule.memoryPolicy => policyScope
  | UiModule.compressionPolicy => policyScope
  | UiModule.strategyPlan => strategyScope
  | UiModule.localValidation => validationScope
  | UiModule.runtimeManifest => runtimeScope
  | UiModule.marlinHandoff => handoffScope
  | UiModule.l1Report => reportScope
  | UiModule.scenarioMatrix => validationScope
  | UiModule.scenarioBenchmark => benchmarkScope

def uiCompleted (state : UiState) : UiModule -> Prop
  | UiModule.loopEngineUseCase => state.useCaseDeclared
  | UiModule.loopEngineProfile => state.profileDeclared
  | UiModule.loopEngineGovernor => state.governorConfigured
  | UiModule.lineagePolicy => state.lineagePolicyDone
  | UiModule.selectorPolicy => state.selectorPolicyDone
  | UiModule.resourcePolicy => state.resourcePolicyDone
  | UiModule.capabilityPolicy => state.capabilityPolicyDone
  | UiModule.memoryPolicy => state.memoryPolicyDone
  | UiModule.compressionPolicy => state.compressionPolicyDone
  | UiModule.strategyPlan => state.strategyPlanDone
  | UiModule.localValidation => state.localValidationDone
  | UiModule.runtimeManifest => state.runtimeManifestDone
  | UiModule.marlinHandoff => state.marlinHandoffDone
  | UiModule.l1Report => state.l1ReportDone
  | UiModule.scenarioMatrix => state.scenarioMatrixDone
  | UiModule.scenarioBenchmark => state.scenarioBenchmarkDone

def uiPolicyAllows (state : UiState) : UiModule -> Prop
  | UiModule.scenarioBenchmark => state.performanceFixtureBound
  | _ => True

def uiPrecondition (state : UiState) : UiModule -> Prop
  | UiModule.loopEngineUseCase => True
  | UiModule.loopEngineProfile => state.useCaseDeclared
  | UiModule.loopEngineGovernor => state.profileDeclared
  | UiModule.lineagePolicy => state.governorConfigured
  | UiModule.selectorPolicy => state.governorConfigured
  | UiModule.resourcePolicy => state.governorConfigured
  | UiModule.capabilityPolicy => state.governorConfigured
  | UiModule.memoryPolicy => state.governorConfigured
  | UiModule.compressionPolicy => state.governorConfigured
  | UiModule.strategyPlan =>
      state.selectorPolicyDone ∧
      state.resourcePolicyDone ∧
      state.capabilityPolicyDone
  | UiModule.localValidation => state.strategyPlanDone
  | UiModule.runtimeManifest =>
      state.strategyPlanDone ∧
      state.localValidationDone ∧
      state.memoryPolicyDone ∧
      state.compressionPolicyDone
  | UiModule.marlinHandoff => state.runtimeManifestDone
  | UiModule.l1Report => state.marlinHandoffDone
  | UiModule.scenarioMatrix =>
      state.useCaseDeclared ∧
      state.profileDeclared ∧
      state.strategyPlanDone
  | UiModule.scenarioBenchmark =>
      state.scenarioMatrixDone ∧
      state.l1ReportDone ∧
      state.performanceFixtureBound

def uiGuard (state : UiState) : UiModule -> Prop
  | UiModule.scenarioBenchmark => state.performanceFixtureBound
  | _ => True

def uiSpec : FlowSpec UiModule UiScope UiState :=
  { scopeOrder := uiScopeOrder
    moduleScope := uiModuleScope
    activeScope := UiState.activeScope
    dependsOn := UiDependsOn
    policyAllows := uiPolicyAllows
    precondition := uiPrecondition
    guard := uiGuard
    branchSibling := fun _ _ => False
    completed := uiCompleted }

structure UiStateConsistent (state : UiState) : Prop where
  profileAfterUseCase : state.profileDeclared -> state.useCaseDeclared
  governorAfterProfile : state.governorConfigured -> state.profileDeclared
  selectorAfterGovernor :
    state.selectorPolicyDone -> state.governorConfigured
  resourceAfterGovernor :
    state.resourcePolicyDone -> state.governorConfigured
  capabilityAfterGovernor :
    state.capabilityPolicyDone -> state.governorConfigured
  strategyAfterSelector :
    state.strategyPlanDone -> state.selectorPolicyDone
  strategyAfterResource :
    state.strategyPlanDone -> state.resourcePolicyDone
  strategyAfterCapability :
    state.strategyPlanDone -> state.capabilityPolicyDone
  validationAfterStrategy :
    state.localValidationDone -> state.strategyPlanDone
  runtimeAfterValidation :
    state.runtimeManifestDone -> state.localValidationDone
  runtimeAfterStrategy :
    state.runtimeManifestDone -> state.strategyPlanDone
  handoffAfterRuntime :
    state.marlinHandoffDone -> state.runtimeManifestDone
  reportAfterHandoff :
    state.l1ReportDone -> state.marlinHandoffDone
  matrixAfterStrategy :
    state.scenarioMatrixDone -> state.strategyPlanDone
  benchmarkAfterMatrix :
    state.scenarioBenchmarkDone -> state.scenarioMatrixDone

def uiRank : UiModule -> Nat
  | UiModule.loopEngineUseCase => 0
  | UiModule.loopEngineProfile => 1
  | UiModule.loopEngineGovernor => 2
  | UiModule.lineagePolicy => 3
  | UiModule.selectorPolicy => 3
  | UiModule.resourcePolicy => 3
  | UiModule.capabilityPolicy => 3
  | UiModule.memoryPolicy => 3
  | UiModule.compressionPolicy => 3
  | UiModule.strategyPlan => 4
  | UiModule.localValidation => 5
  | UiModule.scenarioMatrix => 5
  | UiModule.runtimeManifest => 6
  | UiModule.marlinHandoff => 7
  | UiModule.l1Report => 8
  | UiModule.scenarioBenchmark => 9

def uiDependencyRank : DependencyRank uiSpec :=
  { rank := uiRank
    decreases := by
      intro module dependency depends
      cases depends <;> native_decide }

theorem ui_no_self_dependency
    {module : UiModule} :
    ¬ uiSpec.dependsOn module module :=
  no_self_dependency_of_rank uiDependencyRank

theorem ui_no_two_dependency_cycle
    {left right : UiModule}
    (leftDependsRight : uiSpec.dependsOn left right)
    (rightDependsLeft : uiSpec.dependsOn right left) :
    False :=
  no_two_cycle_of_rank
    uiDependencyRank
    leftDependsRight
    rightDependsLeft

theorem strategy_plan_requires_selector_policy
    {state : UiState}
    (canStart : CanStart uiSpec state UiModule.strategyPlan) :
    state.selectorPolicyDone :=
  deps_completed_of_can_start canStart UiDependsOn.strategySelector

theorem strategy_plan_requires_resource_policy
    {state : UiState}
    (canStart : CanStart uiSpec state UiModule.strategyPlan) :
    state.resourcePolicyDone :=
  deps_completed_of_can_start canStart UiDependsOn.strategyResource

theorem strategy_plan_requires_capability_policy
    {state : UiState}
    (canStart : CanStart uiSpec state UiModule.strategyPlan) :
    state.capabilityPolicyDone :=
  deps_completed_of_can_start canStart UiDependsOn.strategyCapability

theorem strategy_plan_blocks_without_selector_policy
    {state : UiState}
    (missingSelector :
      ¬ state.selectorPolicyDone) :
    ¬ CanStart uiSpec state UiModule.strategyPlan := by
  intro canStart
  exact missingSelector (strategy_plan_requires_selector_policy canStart)

theorem strategy_plan_blocks_without_resource_policy
    {state : UiState}
    (missingResource :
      ¬ state.resourcePolicyDone) :
    ¬ CanStart uiSpec state UiModule.strategyPlan := by
  intro canStart
  exact missingResource (strategy_plan_requires_resource_policy canStart)

theorem strategy_plan_blocks_without_capability_policy
    {state : UiState}
    (missingCapability :
      ¬ state.capabilityPolicyDone) :
    ¬ CanStart uiSpec state UiModule.strategyPlan := by
  intro canStart
  exact missingCapability (strategy_plan_requires_capability_policy canStart)

theorem local_validation_requires_strategy_plan
    {state : UiState}
    (canStart : CanStart uiSpec state UiModule.localValidation) :
    state.strategyPlanDone :=
  deps_completed_of_can_start canStart UiDependsOn.validationStrategy

theorem local_validation_blocks_without_strategy_plan
    {state : UiState}
    (missingStrategy :
      ¬ state.strategyPlanDone) :
    ¬ CanStart uiSpec state UiModule.localValidation := by
  intro canStart
  exact missingStrategy (local_validation_requires_strategy_plan canStart)

theorem runtime_manifest_requires_strategy_plan
    {state : UiState}
    (canStart : CanStart uiSpec state UiModule.runtimeManifest) :
    state.strategyPlanDone :=
  deps_completed_of_can_start canStart UiDependsOn.runtimeStrategy

theorem runtime_manifest_requires_local_validation
    {state : UiState}
    (canStart : CanStart uiSpec state UiModule.runtimeManifest) :
    state.localValidationDone :=
  deps_completed_of_can_start canStart UiDependsOn.runtimeValidation

theorem runtime_manifest_requires_memory_policy
    {state : UiState}
    (canStart : CanStart uiSpec state UiModule.runtimeManifest) :
    state.memoryPolicyDone :=
  deps_completed_of_can_start canStart UiDependsOn.runtimeMemory

theorem runtime_manifest_requires_compression_policy
    {state : UiState}
    (canStart : CanStart uiSpec state UiModule.runtimeManifest) :
    state.compressionPolicyDone :=
  deps_completed_of_can_start canStart UiDependsOn.runtimeCompression

theorem runtime_manifest_blocks_without_strategy_plan
    {state : UiState}
    (missingStrategy :
      ¬ state.strategyPlanDone) :
    ¬ CanStart uiSpec state UiModule.runtimeManifest := by
  intro canStart
  exact missingStrategy (runtime_manifest_requires_strategy_plan canStart)

theorem runtime_manifest_blocks_without_local_validation
    {state : UiState}
    (missingValidation :
      ¬ state.localValidationDone) :
    ¬ CanStart uiSpec state UiModule.runtimeManifest := by
  intro canStart
  exact missingValidation
    (runtime_manifest_requires_local_validation canStart)

theorem runtime_manifest_blocks_without_memory_policy
    {state : UiState}
    (missingMemory :
      ¬ state.memoryPolicyDone) :
    ¬ CanStart uiSpec state UiModule.runtimeManifest := by
  intro canStart
  exact missingMemory (runtime_manifest_requires_memory_policy canStart)

theorem runtime_manifest_blocks_without_compression_policy
    {state : UiState}
    (missingCompression :
      ¬ state.compressionPolicyDone) :
    ¬ CanStart uiSpec state UiModule.runtimeManifest := by
  intro canStart
  exact missingCompression
    (runtime_manifest_requires_compression_policy canStart)

theorem marlin_handoff_requires_runtime_manifest
    {state : UiState}
    (canStart : CanStart uiSpec state UiModule.marlinHandoff) :
    state.runtimeManifestDone :=
  deps_completed_of_can_start canStart UiDependsOn.handoffRuntime

theorem marlin_handoff_blocks_without_runtime_manifest
    {state : UiState}
    (missingRuntimeManifest :
      ¬ state.runtimeManifestDone) :
    ¬ CanStart uiSpec state UiModule.marlinHandoff := by
  intro canStart
  exact missingRuntimeManifest
    (marlin_handoff_requires_runtime_manifest canStart)

theorem scenario_benchmark_requires_matrix
    {state : UiState}
    (canStart : CanStart uiSpec state UiModule.scenarioBenchmark) :
    state.scenarioMatrixDone :=
  deps_completed_of_can_start canStart UiDependsOn.benchmarkMatrix

theorem scenario_benchmark_requires_l1_report
    {state : UiState}
    (canStart : CanStart uiSpec state UiModule.scenarioBenchmark) :
    state.l1ReportDone :=
  deps_completed_of_can_start canStart UiDependsOn.benchmarkReport

theorem scenario_benchmark_requires_performance_fixture
    {state : UiState}
    (canStart : CanStart uiSpec state UiModule.scenarioBenchmark) :
    state.performanceFixtureBound :=
  canStart.guardHolds

theorem scenario_benchmark_blocks_without_matrix
    {state : UiState}
    (missingMatrix :
      ¬ state.scenarioMatrixDone) :
    ¬ CanStart uiSpec state UiModule.scenarioBenchmark := by
  intro canStart
  exact missingMatrix (scenario_benchmark_requires_matrix canStart)

theorem scenario_benchmark_blocks_without_l1_report
    {state : UiState}
    (missingReport :
      ¬ state.l1ReportDone) :
    ¬ CanStart uiSpec state UiModule.scenarioBenchmark := by
  intro canStart
  exact missingReport (scenario_benchmark_requires_l1_report canStart)

theorem scenario_benchmark_blocks_without_performance_fixture
    {state : UiState}
    (missingFixture :
      ¬ state.performanceFixtureBound) :
    ¬ CanStart uiSpec state UiModule.scenarioBenchmark := by
  intro canStart
  exact missingFixture
    (scenario_benchmark_requires_performance_fixture canStart)

structure UiScenarioFailureMatrix where
  strategyRequiresSelector :
    ∀ {state : UiState},
      (¬ state.selectorPolicyDone) ->
      ¬ CanStart uiSpec state UiModule.strategyPlan
  strategyRequiresResource :
    ∀ {state : UiState},
      (¬ state.resourcePolicyDone) ->
      ¬ CanStart uiSpec state UiModule.strategyPlan
  strategyRequiresCapability :
    ∀ {state : UiState},
      (¬ state.capabilityPolicyDone) ->
      ¬ CanStart uiSpec state UiModule.strategyPlan
  validationRequiresStrategy :
    ∀ {state : UiState},
      (¬ state.strategyPlanDone) ->
      ¬ CanStart uiSpec state UiModule.localValidation
  runtimeManifestRequiresStrategy :
    ∀ {state : UiState},
      (¬ state.strategyPlanDone) ->
      ¬ CanStart uiSpec state UiModule.runtimeManifest
  runtimeManifestRequiresValidation :
    ∀ {state : UiState},
      (¬ state.localValidationDone) ->
      ¬ CanStart uiSpec state UiModule.runtimeManifest
  runtimeManifestRequiresMemory :
    ∀ {state : UiState},
      (¬ state.memoryPolicyDone) ->
      ¬ CanStart uiSpec state UiModule.runtimeManifest
  runtimeManifestRequiresCompression :
    ∀ {state : UiState},
      (¬ state.compressionPolicyDone) ->
      ¬ CanStart uiSpec state UiModule.runtimeManifest
  handoffRequiresRuntimeManifest :
    ∀ {state : UiState},
      (¬ state.runtimeManifestDone) ->
      ¬ CanStart uiSpec state UiModule.marlinHandoff
  benchmarkRequiresMatrix :
    ∀ {state : UiState},
      (¬ state.scenarioMatrixDone) ->
      ¬ CanStart uiSpec state UiModule.scenarioBenchmark
  benchmarkRequiresReport :
    ∀ {state : UiState},
      (¬ state.l1ReportDone) ->
      ¬ CanStart uiSpec state UiModule.scenarioBenchmark
  benchmarkRequiresFixture :
    ∀ {state : UiState},
      (¬ state.performanceFixtureBound) ->
      ¬ CanStart uiSpec state UiModule.scenarioBenchmark

def uiScenarioFailureMatrix : UiScenarioFailureMatrix :=
  { strategyRequiresSelector :=
      strategy_plan_blocks_without_selector_policy
    strategyRequiresResource :=
      strategy_plan_blocks_without_resource_policy
    strategyRequiresCapability :=
      strategy_plan_blocks_without_capability_policy
    validationRequiresStrategy :=
      local_validation_blocks_without_strategy_plan
    runtimeManifestRequiresStrategy :=
      runtime_manifest_blocks_without_strategy_plan
    runtimeManifestRequiresValidation :=
      runtime_manifest_blocks_without_local_validation
    runtimeManifestRequiresMemory :=
      runtime_manifest_blocks_without_memory_policy
    runtimeManifestRequiresCompression :=
      runtime_manifest_blocks_without_compression_policy
    handoffRequiresRuntimeManifest :=
      marlin_handoff_blocks_without_runtime_manifest
    benchmarkRequiresMatrix :=
      scenario_benchmark_blocks_without_matrix
    benchmarkRequiresReport :=
      scenario_benchmark_blocks_without_l1_report
    benchmarkRequiresFixture :=
      scenario_benchmark_blocks_without_performance_fixture }

theorem scenario_benchmark_required_conditions
    {state : UiState}
    (canStart : CanStart uiSpec state UiModule.scenarioBenchmark) :
    RequiredConditions uiSpec state UiModule.scenarioBenchmark :=
  required_conditions_of_can_start canStart

theorem scenario_benchmark_requires_governed_strategy_chain
    {state : UiState}
    (consistent : UiStateConsistent state)
    (canStart : CanStart uiSpec state UiModule.scenarioBenchmark) :
    state.useCaseDeclared ∧
    state.profileDeclared ∧
    state.governorConfigured ∧
    state.selectorPolicyDone ∧
    state.resourcePolicyDone ∧
    state.capabilityPolicyDone ∧
    state.strategyPlanDone ∧
    state.scenarioMatrixDone ∧
    state.l1ReportDone ∧
    state.performanceFixtureBound := by
  let matrixDone := scenario_benchmark_requires_matrix canStart
  let reportDone := scenario_benchmark_requires_l1_report canStart
  let fixtureBound := scenario_benchmark_requires_performance_fixture canStart
  let strategyDone := consistent.matrixAfterStrategy matrixDone
  let selectorDone := consistent.strategyAfterSelector strategyDone
  let resourceDone := consistent.strategyAfterResource strategyDone
  let capabilityDone := consistent.strategyAfterCapability strategyDone
  let governorDone := consistent.selectorAfterGovernor selectorDone
  let profileDone := consistent.governorAfterProfile governorDone
  let useCaseDone := consistent.profileAfterUseCase profileDone
  exact
    And.intro useCaseDone
      (And.intro profileDone
        (And.intro governorDone
          (And.intro selectorDone
            (And.intro resourceDone
              (And.intro capabilityDone
                (And.intro strategyDone
                  (And.intro matrixDone
                    (And.intro reportDone fixtureBound))))))))

inductive UiScenarioFact where
  | useCaseDeclared
  | profileDeclared
  | governorConfigured
  | lineagePolicyDone
  | selectorPolicyDone
  | resourcePolicyDone
  | capabilityPolicyDone
  | memoryPolicyDone
  | compressionPolicyDone
  | strategyPlanDone
  | localValidationDone
  | runtimeManifestDone
  | marlinHandoffDone
  | l1ReportDone
  | scenarioMatrixDone
  | scenarioBenchmarkDone
  | performanceFixtureBound
deriving Repr, DecidableEq

abbrev UiScenarioFactEnv := UiScenarioFact -> Prop

def uiScenarioStateOfFacts
    (activeScope : UiScope)
    (facts : UiScenarioFactEnv) :
    UiState :=
  { activeScope := activeScope
    useCaseDeclared := facts UiScenarioFact.useCaseDeclared
    profileDeclared := facts UiScenarioFact.profileDeclared
    governorConfigured := facts UiScenarioFact.governorConfigured
    lineagePolicyDone := facts UiScenarioFact.lineagePolicyDone
    selectorPolicyDone := facts UiScenarioFact.selectorPolicyDone
    resourcePolicyDone := facts UiScenarioFact.resourcePolicyDone
    capabilityPolicyDone := facts UiScenarioFact.capabilityPolicyDone
    memoryPolicyDone := facts UiScenarioFact.memoryPolicyDone
    compressionPolicyDone := facts UiScenarioFact.compressionPolicyDone
    strategyPlanDone := facts UiScenarioFact.strategyPlanDone
    localValidationDone := facts UiScenarioFact.localValidationDone
    runtimeManifestDone := facts UiScenarioFact.runtimeManifestDone
    marlinHandoffDone := facts UiScenarioFact.marlinHandoffDone
    l1ReportDone := facts UiScenarioFact.l1ReportDone
    scenarioMatrixDone := facts UiScenarioFact.scenarioMatrixDone
    scenarioBenchmarkDone := facts UiScenarioFact.scenarioBenchmarkDone
    performanceFixtureBound := facts UiScenarioFact.performanceFixtureBound }

theorem ui_projection_blocks_strategy_without_selector_policy
    {facts : UiScenarioFactEnv}
    {activeScope : UiScope}
    (missingSelector :
      ¬ facts UiScenarioFact.selectorPolicyDone) :
    ¬ CanStart
      uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UiModule.strategyPlan :=
  strategy_plan_blocks_without_selector_policy missingSelector

theorem ui_projection_blocks_strategy_without_resource_policy
    {facts : UiScenarioFactEnv}
    {activeScope : UiScope}
    (missingResource :
      ¬ facts UiScenarioFact.resourcePolicyDone) :
    ¬ CanStart
      uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UiModule.strategyPlan :=
  strategy_plan_blocks_without_resource_policy missingResource

theorem ui_projection_blocks_strategy_without_capability_policy
    {facts : UiScenarioFactEnv}
    {activeScope : UiScope}
    (missingCapability :
      ¬ facts UiScenarioFact.capabilityPolicyDone) :
    ¬ CanStart
      uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UiModule.strategyPlan :=
  strategy_plan_blocks_without_capability_policy missingCapability

theorem ui_projection_blocks_local_validation_without_strategy_plan
    {facts : UiScenarioFactEnv}
    {activeScope : UiScope}
    (missingStrategy :
      ¬ facts UiScenarioFact.strategyPlanDone) :
    ¬ CanStart
      uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UiModule.localValidation :=
  local_validation_blocks_without_strategy_plan missingStrategy

theorem ui_projection_blocks_runtime_manifest_without_strategy_plan
    {facts : UiScenarioFactEnv}
    {activeScope : UiScope}
    (missingStrategy :
      ¬ facts UiScenarioFact.strategyPlanDone) :
    ¬ CanStart
      uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UiModule.runtimeManifest :=
  runtime_manifest_blocks_without_strategy_plan missingStrategy

theorem ui_projection_blocks_runtime_manifest_without_memory_policy
    {facts : UiScenarioFactEnv}
    {activeScope : UiScope}
    (missingMemory :
      ¬ facts UiScenarioFact.memoryPolicyDone) :
    ¬ CanStart
      uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UiModule.runtimeManifest :=
  runtime_manifest_blocks_without_memory_policy missingMemory

theorem ui_projection_blocks_runtime_manifest_without_compression_policy
    {facts : UiScenarioFactEnv}
    {activeScope : UiScope}
    (missingCompression :
      ¬ facts UiScenarioFact.compressionPolicyDone) :
    ¬ CanStart
      uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UiModule.runtimeManifest :=
  runtime_manifest_blocks_without_compression_policy missingCompression

theorem ui_projection_blocks_runtime_manifest_without_local_validation
    {facts : UiScenarioFactEnv}
    {activeScope : UiScope}
    (missingValidation :
      ¬ facts UiScenarioFact.localValidationDone) :
    ¬ CanStart
      uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UiModule.runtimeManifest :=
  runtime_manifest_blocks_without_local_validation missingValidation

theorem ui_projection_blocks_handoff_without_runtime_manifest
    {facts : UiScenarioFactEnv}
    {activeScope : UiScope}
    (missingRuntimeManifest :
      ¬ facts UiScenarioFact.runtimeManifestDone) :
    ¬ CanStart
      uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UiModule.marlinHandoff :=
  marlin_handoff_blocks_without_runtime_manifest
    missingRuntimeManifest

theorem ui_projection_blocks_benchmark_without_matrix
    {facts : UiScenarioFactEnv}
    {activeScope : UiScope}
    (missingMatrix :
      ¬ facts UiScenarioFact.scenarioMatrixDone) :
    ¬ CanStart
      uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UiModule.scenarioBenchmark :=
  scenario_benchmark_blocks_without_matrix missingMatrix

theorem ui_projection_blocks_benchmark_without_l1_report
    {facts : UiScenarioFactEnv}
    {activeScope : UiScope}
    (missingReport :
      ¬ facts UiScenarioFact.l1ReportDone) :
    ¬ CanStart
      uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UiModule.scenarioBenchmark :=
  scenario_benchmark_blocks_without_l1_report missingReport

theorem ui_projection_blocks_benchmark_without_performance_fixture
    {facts : UiScenarioFactEnv}
    {activeScope : UiScope}
    (missingFixture :
      ¬ facts UiScenarioFact.performanceFixtureBound) :
    ¬ CanStart
      uiSpec
      (uiScenarioStateOfFacts activeScope facts)
      UiModule.scenarioBenchmark :=
  scenario_benchmark_blocks_without_performance_fixture
    missingFixture

structure UiScenarioProjectionFailureMatrix where
  strategyRequiresSelector :
    ∀ {facts : UiScenarioFactEnv}
      {activeScope : UiScope},
      (¬ facts UiScenarioFact.selectorPolicyDone) ->
      ¬ CanStart
        uiSpec
        (uiScenarioStateOfFacts activeScope facts)
        UiModule.strategyPlan
  strategyRequiresResource :
    ∀ {facts : UiScenarioFactEnv}
      {activeScope : UiScope},
      (¬ facts UiScenarioFact.resourcePolicyDone) ->
      ¬ CanStart
        uiSpec
        (uiScenarioStateOfFacts activeScope facts)
        UiModule.strategyPlan
  strategyRequiresCapability :
    ∀ {facts : UiScenarioFactEnv}
      {activeScope : UiScope},
      (¬ facts UiScenarioFact.capabilityPolicyDone) ->
      ¬ CanStart
        uiSpec
        (uiScenarioStateOfFacts activeScope facts)
        UiModule.strategyPlan
  validationRequiresStrategy :
    ∀ {facts : UiScenarioFactEnv}
      {activeScope : UiScope},
      (¬ facts UiScenarioFact.strategyPlanDone) ->
      ¬ CanStart
        uiSpec
        (uiScenarioStateOfFacts activeScope facts)
        UiModule.localValidation
  runtimeRequiresStrategy :
    ∀ {facts : UiScenarioFactEnv}
      {activeScope : UiScope},
      (¬ facts UiScenarioFact.strategyPlanDone) ->
      ¬ CanStart
        uiSpec
        (uiScenarioStateOfFacts activeScope facts)
        UiModule.runtimeManifest
  runtimeRequiresMemory :
    ∀ {facts : UiScenarioFactEnv}
      {activeScope : UiScope},
      (¬ facts UiScenarioFact.memoryPolicyDone) ->
      ¬ CanStart
        uiSpec
        (uiScenarioStateOfFacts activeScope facts)
        UiModule.runtimeManifest
  runtimeRequiresCompression :
    ∀ {facts : UiScenarioFactEnv}
      {activeScope : UiScope},
      (¬ facts UiScenarioFact.compressionPolicyDone) ->
      ¬ CanStart
        uiSpec
        (uiScenarioStateOfFacts activeScope facts)
        UiModule.runtimeManifest
  runtimeRequiresValidation :
    ∀ {facts : UiScenarioFactEnv}
      {activeScope : UiScope},
      (¬ facts UiScenarioFact.localValidationDone) ->
      ¬ CanStart
        uiSpec
        (uiScenarioStateOfFacts activeScope facts)
        UiModule.runtimeManifest
  handoffRequiresRuntime :
    ∀ {facts : UiScenarioFactEnv}
      {activeScope : UiScope},
      (¬ facts UiScenarioFact.runtimeManifestDone) ->
      ¬ CanStart
        uiSpec
        (uiScenarioStateOfFacts activeScope facts)
        UiModule.marlinHandoff
  benchmarkRequiresMatrix :
    ∀ {facts : UiScenarioFactEnv}
      {activeScope : UiScope},
      (¬ facts UiScenarioFact.scenarioMatrixDone) ->
      ¬ CanStart
        uiSpec
        (uiScenarioStateOfFacts activeScope facts)
        UiModule.scenarioBenchmark
  benchmarkRequiresReport :
    ∀ {facts : UiScenarioFactEnv}
      {activeScope : UiScope},
      (¬ facts UiScenarioFact.l1ReportDone) ->
      ¬ CanStart
        uiSpec
        (uiScenarioStateOfFacts activeScope facts)
        UiModule.scenarioBenchmark
  benchmarkRequiresFixture :
    ∀ {facts : UiScenarioFactEnv}
      {activeScope : UiScope},
      (¬ facts UiScenarioFact.performanceFixtureBound) ->
      ¬ CanStart
        uiSpec
        (uiScenarioStateOfFacts activeScope facts)
        UiModule.scenarioBenchmark

def uiScenarioProjectionFailureMatrix :
    UiScenarioProjectionFailureMatrix :=
  { strategyRequiresSelector :=
      ui_projection_blocks_strategy_without_selector_policy
    strategyRequiresResource :=
      ui_projection_blocks_strategy_without_resource_policy
    strategyRequiresCapability :=
      ui_projection_blocks_strategy_without_capability_policy
    validationRequiresStrategy :=
      ui_projection_blocks_local_validation_without_strategy_plan
    runtimeRequiresStrategy :=
      ui_projection_blocks_runtime_manifest_without_strategy_plan
    runtimeRequiresMemory :=
      ui_projection_blocks_runtime_manifest_without_memory_policy
    runtimeRequiresCompression :=
      ui_projection_blocks_runtime_manifest_without_compression_policy
    runtimeRequiresValidation :=
      ui_projection_blocks_runtime_manifest_without_local_validation
    handoffRequiresRuntime :=
      ui_projection_blocks_handoff_without_runtime_manifest
    benchmarkRequiresMatrix :=
      ui_projection_blocks_benchmark_without_matrix
    benchmarkRequiresReport :=
      ui_projection_blocks_benchmark_without_l1_report
    benchmarkRequiresFixture :=
      ui_projection_blocks_benchmark_without_performance_fixture }

end AgenticAILabProof.PooC4.UserInterface
