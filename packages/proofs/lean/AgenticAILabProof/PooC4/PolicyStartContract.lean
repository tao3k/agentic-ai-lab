-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.PolicyBundle

namespace AgenticAILabProof.PooC4.PolicyComposition

open AgenticAILabProof.PooC4

abbrev UiStrategyContext
    (state : UserInterface.UiState) : UiPolicyContext :=
  uiPolicyContext state UserInterface.UiModule.strategyPlan

abbrev UiRuntimeContext
    (state : UserInterface.UiState) : UiPolicyContext :=
  uiPolicyContext state UserInterface.UiModule.runtimeManifest

abbrev UiBenchmarkContext
    (state : UserInterface.UiState) : UiPolicyContext :=
  uiPolicyContext state UserInterface.UiModule.scenarioBenchmark

structure UiStrategyPlanStartContract
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    (state : UserInterface.UiState) : Prop where
  startFrame :
    StartFrame
      UserInterface.uiSpec
      state
      UserInterface.UiModule.strategyPlan
  selectorDependency : state.selectorPolicyDone
  resourceDependency : state.resourcePolicyDone
  capabilityDependency : state.capabilityPolicyDone
  selectorFacet :
    (bundle.policy UiPolicyFacet.selector).allows
      (UiStrategyContext state)
  resourceFacet :
    (bundle.policy UiPolicyFacet.resource).allows
      (UiStrategyContext state)
  capabilityFacet :
    (bundle.policy UiPolicyFacet.capability).allows
      (UiStrategyContext state)

structure UiRuntimeManifestStartContract
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    (state : UserInterface.UiState) : Prop where
  startFrame :
    StartFrame
      UserInterface.uiSpec
      state
      UserInterface.UiModule.runtimeManifest
  strategyDependency : state.strategyPlanDone
  validationDependency : state.localValidationDone
  memoryDependency : state.memoryPolicyDone
  compressionDependency : state.compressionPolicyDone
  memoryFacet :
    (bundle.policy UiPolicyFacet.memory).allows
      (UiRuntimeContext state)
  compressionFacet :
    (bundle.policy UiPolicyFacet.compression).allows
      (UiRuntimeContext state)

structure UiBenchmarkStartContract
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    (state : UserInterface.UiState) : Prop where
  startFrame :
    StartFrame
      UserInterface.uiSpec
      state
      UserInterface.UiModule.scenarioBenchmark
  matrixDependency : state.scenarioMatrixDone
  reportDependency : state.l1ReportDone
  fixturePolicy : state.performanceFixtureBound
  fixtureFacet :
    (bundle.policy UiPolicyFacet.performanceFixture).allows
      (UiBenchmarkContext state)

theorem ui_strategy_plan_start_contract_of_can_start
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    {state : UserInterface.UiState}
    (canStart :
      CanStart
        (uiBundleSpec bundle)
        state
        UserInterface.UiModule.strategyPlan) :
    UiStrategyPlanStartContract bundle state := by
  have facets :=
    ui_strategy_plan_bundle_requires_facets bundle canStart
  exact
    { startFrame :=
        { depsCompleted := canStart.depsCompleted
          scopeAllowed := canStart.scopeAllowed
          preconditionHolds := canStart.preconditionHolds
          guardHolds := canStart.guardHolds }
      selectorDependency :=
        canStart.depsCompleted
          UserInterface.UiModule.selectorPolicy
          UserInterface.UiDependsOn.strategySelector
      resourceDependency :=
        canStart.depsCompleted
          UserInterface.UiModule.resourcePolicy
          UserInterface.UiDependsOn.strategyResource
      capabilityDependency :=
        canStart.depsCompleted
          UserInterface.UiModule.capabilityPolicy
          UserInterface.UiDependsOn.strategyCapability
      selectorFacet := facets.left
      resourceFacet := facets.right.left
      capabilityFacet := facets.right.right }

theorem ui_runtime_manifest_start_contract_of_can_start
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    {state : UserInterface.UiState}
    (canStart :
      CanStart
        (uiBundleSpec bundle)
        state
        UserInterface.UiModule.runtimeManifest) :
    UiRuntimeManifestStartContract bundle state := by
  have facets :=
    ui_runtime_manifest_bundle_requires_facets bundle canStart
  exact
    { startFrame :=
        { depsCompleted := canStart.depsCompleted
          scopeAllowed := canStart.scopeAllowed
          preconditionHolds := canStart.preconditionHolds
          guardHolds := canStart.guardHolds }
      strategyDependency :=
        canStart.depsCompleted
          UserInterface.UiModule.strategyPlan
          UserInterface.UiDependsOn.runtimeStrategy
      validationDependency :=
        canStart.depsCompleted
          UserInterface.UiModule.localValidation
          UserInterface.UiDependsOn.runtimeValidation
      memoryDependency :=
        canStart.depsCompleted
          UserInterface.UiModule.memoryPolicy
          UserInterface.UiDependsOn.runtimeMemory
      compressionDependency :=
        canStart.depsCompleted
          UserInterface.UiModule.compressionPolicy
          UserInterface.UiDependsOn.runtimeCompression
      memoryFacet := facets.left
      compressionFacet := facets.right }

theorem ui_benchmark_start_contract_of_can_start
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    {state : UserInterface.UiState}
    (canStart :
      CanStart
        (uiBundleSpec bundle)
        state
        UserInterface.UiModule.scenarioBenchmark) :
    UiBenchmarkStartContract bundle state := by
  exact
    { startFrame :=
        { depsCompleted := canStart.depsCompleted
          scopeAllowed := canStart.scopeAllowed
          preconditionHolds := canStart.preconditionHolds
          guardHolds := canStart.guardHolds }
      matrixDependency :=
        canStart.depsCompleted
          UserInterface.UiModule.scenarioMatrix
          UserInterface.UiDependsOn.benchmarkMatrix
      reportDependency :=
        canStart.depsCompleted
          UserInterface.UiModule.l1Report
          UserInterface.UiDependsOn.benchmarkReport
      fixturePolicy := canStart.policyHolds.left
      fixtureFacet :=
        ui_benchmark_bundle_requires_performance_fixture bundle canStart }

theorem ui_strategy_plan_blocks_without_selector_facet
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    {state : UserInterface.UiState}
    (denied :
      ¬ (bundle.policy UiPolicyFacet.selector).allows
          (UiStrategyContext state)) :
    ¬ CanStart
      (uiBundleSpec bundle)
      state
      UserInterface.UiModule.strategyPlan := by
  intro canStart
  exact
    denied
      (ui_strategy_plan_start_contract_of_can_start
        bundle
        canStart).selectorFacet

theorem ui_strategy_plan_blocks_without_resource_facet
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    {state : UserInterface.UiState}
    (denied :
      ¬ (bundle.policy UiPolicyFacet.resource).allows
          (UiStrategyContext state)) :
    ¬ CanStart
      (uiBundleSpec bundle)
      state
      UserInterface.UiModule.strategyPlan := by
  intro canStart
  exact
    denied
      (ui_strategy_plan_start_contract_of_can_start
        bundle
        canStart).resourceFacet

theorem ui_strategy_plan_blocks_without_capability_facet
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    {state : UserInterface.UiState}
    (denied :
      ¬ (bundle.policy UiPolicyFacet.capability).allows
          (UiStrategyContext state)) :
    ¬ CanStart
      (uiBundleSpec bundle)
      state
      UserInterface.UiModule.strategyPlan := by
  intro canStart
  exact
    denied
      (ui_strategy_plan_start_contract_of_can_start
        bundle
        canStart).capabilityFacet

theorem ui_runtime_manifest_blocks_without_memory_facet
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    {state : UserInterface.UiState}
    (denied :
      ¬ (bundle.policy UiPolicyFacet.memory).allows
          (UiRuntimeContext state)) :
    ¬ CanStart
      (uiBundleSpec bundle)
      state
      UserInterface.UiModule.runtimeManifest := by
  intro canStart
  exact
    denied
      (ui_runtime_manifest_start_contract_of_can_start
        bundle
        canStart).memoryFacet

theorem ui_runtime_manifest_blocks_without_compression_facet
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    {state : UserInterface.UiState}
    (denied :
      ¬ (bundle.policy UiPolicyFacet.compression).allows
          (UiRuntimeContext state)) :
    ¬ CanStart
      (uiBundleSpec bundle)
      state
      UserInterface.UiModule.runtimeManifest := by
  intro canStart
  exact
    denied
      (ui_runtime_manifest_start_contract_of_can_start
        bundle
        canStart).compressionFacet

theorem ui_benchmark_blocks_without_fixture_facet
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    {state : UserInterface.UiState}
    (denied :
      ¬ (bundle.policy UiPolicyFacet.performanceFixture).allows
          (UiBenchmarkContext state)) :
    ¬ CanStart
      (uiBundleSpec bundle)
      state
      UserInterface.UiModule.scenarioBenchmark := by
  intro canStart
  exact
    denied
      (ui_benchmark_start_contract_of_can_start
        bundle
        canStart).fixtureFacet

structure UiStrategySelectorOverrideContract
    (parent localPolicy : PolicyBundle UiPolicyContext UiPolicyFacet)
    (state : UserInterface.UiState) : Prop where
  startFrame :
    StartFrame
      UserInterface.uiSpec
      state
      UserInterface.UiModule.strategyPlan
  localSelectorFacet :
    (localPolicy.policy UiPolicyFacet.selector).allows
      (UiStrategyContext state)
  parentResourceFacet :
    (parent.policy UiPolicyFacet.resource).allows
      (UiStrategyContext state)
  parentCapabilityFacet :
    (parent.policy UiPolicyFacet.capability).allows
      (UiStrategyContext state)

theorem ui_strategy_selector_override_contract_of_can_start
    (parent localPolicy : PolicyBundle UiPolicyContext UiPolicyFacet)
    (overrides : UiPolicyContext -> Prop)
    {state : UserInterface.UiState}
    (isOverride : overrides (UiStrategyContext state))
    (canStart :
      CanStart
        (uiBundleSpec
          (parent.overrideFacet
            localPolicy
            UiPolicyFacet.selector
            overrides))
        state
        UserInterface.UiModule.strategyPlan) :
    UiStrategySelectorOverrideContract parent localPolicy state := by
  have contract :=
    ui_strategy_plan_start_contract_of_can_start
      (parent.overrideFacet
        localPolicy
        UiPolicyFacet.selector
        overrides)
      canStart
  exact
    { startFrame := contract.startFrame
      localSelectorFacet :=
        (overrideFacet_target_allows_iff
          (parent := parent)
          (localPolicy := localPolicy)
          (target := UiPolicyFacet.selector)
          (overrides := overrides)
          (context := UiStrategyContext state)
          isOverride).mp
          contract.selectorFacet
      parentResourceFacet :=
        (overrideFacet_preserves_other
          (parent := parent)
          (localPolicy := localPolicy)
          (target := UiPolicyFacet.selector)
          (facet := UiPolicyFacet.resource)
          (overrides := overrides)
          (context := UiStrategyContext state)
          (by decide)).mp
          contract.resourceFacet
      parentCapabilityFacet :=
        (overrideFacet_preserves_other
          (parent := parent)
          (localPolicy := localPolicy)
          (target := UiPolicyFacet.selector)
          (facet := UiPolicyFacet.capability)
          (overrides := overrides)
          (context := UiStrategyContext state)
          (by decide)).mp
          contract.capabilityFacet }

structure UiRuntimeSelectorOverrideContract
    (parent : PolicyBundle UiPolicyContext UiPolicyFacet)
    (state : UserInterface.UiState) : Prop where
  startFrame :
    StartFrame
      UserInterface.uiSpec
      state
      UserInterface.UiModule.runtimeManifest
  parentMemoryFacet :
    (parent.policy UiPolicyFacet.memory).allows
      (UiRuntimeContext state)
  parentCompressionFacet :
    (parent.policy UiPolicyFacet.compression).allows
      (UiRuntimeContext state)

theorem ui_runtime_selector_override_contract_of_can_start
    (parent localPolicy : PolicyBundle UiPolicyContext UiPolicyFacet)
    (overrides : UiPolicyContext -> Prop)
    {state : UserInterface.UiState}
    (canStart :
      CanStart
        (uiBundleSpec
          (parent.overrideFacet
            localPolicy
            UiPolicyFacet.selector
            overrides))
        state
        UserInterface.UiModule.runtimeManifest) :
    UiRuntimeSelectorOverrideContract parent state := by
  have contract :=
    ui_runtime_manifest_start_contract_of_can_start
      (parent.overrideFacet
        localPolicy
        UiPolicyFacet.selector
        overrides)
      canStart
  exact
    { startFrame := contract.startFrame
      parentMemoryFacet :=
        (overrideFacet_preserves_other
          (parent := parent)
          (localPolicy := localPolicy)
          (target := UiPolicyFacet.selector)
          (facet := UiPolicyFacet.memory)
          (overrides := overrides)
          (context := UiRuntimeContext state)
          (by decide)).mp
          contract.memoryFacet
      parentCompressionFacet :=
        (overrideFacet_preserves_other
          (parent := parent)
          (localPolicy := localPolicy)
          (target := UiPolicyFacet.selector)
          (facet := UiPolicyFacet.compression)
          (overrides := overrides)
          (context := UiRuntimeContext state)
          (by decide)).mp
          contract.compressionFacet }

end AgenticAILabProof.PooC4.PolicyComposition
