-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.PolicyRefinement

namespace AgenticAILabProof.PooC4.PolicyComposition

open AgenticAILabProof.PooC4

structure UiStateExtends
    (before after : UserInterface.UiState) : Prop where
  activeScopeGrows :
    UserInterface.uiScopeOrder.le before.activeScope after.activeScope
  useCaseDeclared :
    before.useCaseDeclared -> after.useCaseDeclared
  profileDeclared :
    before.profileDeclared -> after.profileDeclared
  governorConfigured :
    before.governorConfigured -> after.governorConfigured
  lineagePolicyDone :
    before.lineagePolicyDone -> after.lineagePolicyDone
  selectorPolicyDone :
    before.selectorPolicyDone -> after.selectorPolicyDone
  resourcePolicyDone :
    before.resourcePolicyDone -> after.resourcePolicyDone
  capabilityPolicyDone :
    before.capabilityPolicyDone -> after.capabilityPolicyDone
  memoryPolicyDone :
    before.memoryPolicyDone -> after.memoryPolicyDone
  compressionPolicyDone :
    before.compressionPolicyDone -> after.compressionPolicyDone
  strategyPlanDone :
    before.strategyPlanDone -> after.strategyPlanDone
  localValidationDone :
    before.localValidationDone -> after.localValidationDone
  runtimeManifestDone :
    before.runtimeManifestDone -> after.runtimeManifestDone
  marlinHandoffDone :
    before.marlinHandoffDone -> after.marlinHandoffDone
  l1ReportDone :
    before.l1ReportDone -> after.l1ReportDone
  scenarioMatrixDone :
    before.scenarioMatrixDone -> after.scenarioMatrixDone
  scenarioBenchmarkDone :
    before.scenarioBenchmarkDone -> after.scenarioBenchmarkDone
  performanceFixtureBound :
    before.performanceFixtureBound -> after.performanceFixtureBound

theorem ui_state_extends_refl
    (state : UserInterface.UiState) :
    UiStateExtends state state :=
  { activeScopeGrows := Nat.le_refl state.activeScope
    useCaseDeclared := fun fact => fact
    profileDeclared := fun fact => fact
    governorConfigured := fun fact => fact
    lineagePolicyDone := fun fact => fact
    selectorPolicyDone := fun fact => fact
    resourcePolicyDone := fun fact => fact
    capabilityPolicyDone := fun fact => fact
    memoryPolicyDone := fun fact => fact
    compressionPolicyDone := fun fact => fact
    strategyPlanDone := fun fact => fact
    localValidationDone := fun fact => fact
    runtimeManifestDone := fun fact => fact
    marlinHandoffDone := fun fact => fact
    l1ReportDone := fun fact => fact
    scenarioMatrixDone := fun fact => fact
    scenarioBenchmarkDone := fun fact => fact
    performanceFixtureBound := fun fact => fact }

theorem ui_state_extends_trans
    {first second third : UserInterface.UiState}
    (firstSecond : UiStateExtends first second)
    (secondThird : UiStateExtends second third) :
    UiStateExtends first third :=
  { activeScopeGrows :=
      UserInterface.uiScopeOrder.trans
        firstSecond.activeScopeGrows
        secondThird.activeScopeGrows
    useCaseDeclared :=
      fun fact => secondThird.useCaseDeclared
        (firstSecond.useCaseDeclared fact)
    profileDeclared :=
      fun fact => secondThird.profileDeclared
        (firstSecond.profileDeclared fact)
    governorConfigured :=
      fun fact => secondThird.governorConfigured
        (firstSecond.governorConfigured fact)
    lineagePolicyDone :=
      fun fact => secondThird.lineagePolicyDone
        (firstSecond.lineagePolicyDone fact)
    selectorPolicyDone :=
      fun fact => secondThird.selectorPolicyDone
        (firstSecond.selectorPolicyDone fact)
    resourcePolicyDone :=
      fun fact => secondThird.resourcePolicyDone
        (firstSecond.resourcePolicyDone fact)
    capabilityPolicyDone :=
      fun fact => secondThird.capabilityPolicyDone
        (firstSecond.capabilityPolicyDone fact)
    memoryPolicyDone :=
      fun fact => secondThird.memoryPolicyDone
        (firstSecond.memoryPolicyDone fact)
    compressionPolicyDone :=
      fun fact => secondThird.compressionPolicyDone
        (firstSecond.compressionPolicyDone fact)
    strategyPlanDone :=
      fun fact => secondThird.strategyPlanDone
        (firstSecond.strategyPlanDone fact)
    localValidationDone :=
      fun fact => secondThird.localValidationDone
        (firstSecond.localValidationDone fact)
    runtimeManifestDone :=
      fun fact => secondThird.runtimeManifestDone
        (firstSecond.runtimeManifestDone fact)
    marlinHandoffDone :=
      fun fact => secondThird.marlinHandoffDone
        (firstSecond.marlinHandoffDone fact)
    l1ReportDone :=
      fun fact => secondThird.l1ReportDone
        (firstSecond.l1ReportDone fact)
    scenarioMatrixDone :=
      fun fact => secondThird.scenarioMatrixDone
        (firstSecond.scenarioMatrixDone fact)
    scenarioBenchmarkDone :=
      fun fact => secondThird.scenarioBenchmarkDone
        (firstSecond.scenarioBenchmarkDone fact)
    performanceFixtureBound :=
      fun fact => secondThird.performanceFixtureBound
        (firstSecond.performanceFixtureBound fact) }

theorem ui_completed_preserved
    {before after : UserInterface.UiState}
    (stateExt : UiStateExtends before after)
    (module : UserInterface.UiModule) :
    UserInterface.uiCompleted before module ->
      UserInterface.uiCompleted after module := by
  cases module <;>
    simp [UserInterface.uiCompleted]
  · exact stateExt.useCaseDeclared
  · exact stateExt.profileDeclared
  · exact stateExt.governorConfigured
  · exact stateExt.lineagePolicyDone
  · exact stateExt.selectorPolicyDone
  · exact stateExt.resourcePolicyDone
  · exact stateExt.capabilityPolicyDone
  · exact stateExt.memoryPolicyDone
  · exact stateExt.compressionPolicyDone
  · exact stateExt.strategyPlanDone
  · exact stateExt.localValidationDone
  · exact stateExt.runtimeManifestDone
  · exact stateExt.marlinHandoffDone
  · exact stateExt.l1ReportDone
  · exact stateExt.scenarioMatrixDone
  · exact stateExt.scenarioBenchmarkDone

theorem ui_precondition_preserved
    {before after : UserInterface.UiState}
    (stateExt : UiStateExtends before after)
    (module : UserInterface.UiModule) :
    UserInterface.uiPrecondition before module ->
      UserInterface.uiPrecondition after module := by
  cases module
  · intro _
    trivial
  · simpa [UserInterface.uiPrecondition] using stateExt.useCaseDeclared
  · simpa [UserInterface.uiPrecondition] using stateExt.profileDeclared
  · simpa [UserInterface.uiPrecondition] using stateExt.governorConfigured
  · simpa [UserInterface.uiPrecondition] using stateExt.governorConfigured
  · simpa [UserInterface.uiPrecondition] using stateExt.governorConfigured
  · simpa [UserInterface.uiPrecondition] using stateExt.governorConfigured
  · simpa [UserInterface.uiPrecondition] using stateExt.governorConfigured
  · simpa [UserInterface.uiPrecondition] using stateExt.governorConfigured
  · intro facts
    exact
      And.intro
        (stateExt.selectorPolicyDone facts.left)
        (And.intro
          (stateExt.resourcePolicyDone facts.right.left)
          (stateExt.capabilityPolicyDone facts.right.right))
  · simpa [UserInterface.uiPrecondition] using stateExt.strategyPlanDone
  · intro facts
    exact
      And.intro
        (stateExt.strategyPlanDone facts.left)
        (And.intro
          (stateExt.localValidationDone facts.right.left)
          (And.intro
            (stateExt.memoryPolicyDone facts.right.right.left)
            (stateExt.compressionPolicyDone facts.right.right.right)))
  · simpa [UserInterface.uiPrecondition] using stateExt.runtimeManifestDone
  · simpa [UserInterface.uiPrecondition] using stateExt.marlinHandoffDone
  · intro facts
    exact
      And.intro
        (stateExt.useCaseDeclared facts.left)
        (And.intro
          (stateExt.profileDeclared facts.right.left)
          (stateExt.strategyPlanDone facts.right.right))
  · intro facts
    exact
      And.intro
        (stateExt.scenarioMatrixDone facts.left)
        (And.intro
          (stateExt.l1ReportDone facts.right.left)
          (stateExt.performanceFixtureBound facts.right.right))

theorem ui_guard_preserved
    {before after : UserInterface.UiState}
    (stateExt : UiStateExtends before after)
    (module : UserInterface.UiModule) :
    UserInterface.uiGuard before module ->
      UserInterface.uiGuard after module := by
  cases module <;>
    try (intro _; trivial)
  · simpa [UserInterface.uiGuard] using stateExt.performanceFixtureBound

theorem ui_policy_allows_preserved
    {before after : UserInterface.UiState}
    (stateExt : UiStateExtends before after)
    (module : UserInterface.UiModule) :
    UserInterface.uiPolicyAllows before module ->
      UserInterface.uiPolicyAllows after module := by
  cases module <;>
    try (intro _; trivial)
  · simpa [UserInterface.uiPolicyAllows] using stateExt.performanceFixtureBound

theorem ui_startFrame_preserved
    {before after : UserInterface.UiState}
    (stateExt : UiStateExtends before after)
    {module : UserInterface.UiModule}
    (frame :
      StartFrame UserInterface.uiSpec before module) :
    StartFrame UserInterface.uiSpec after module :=
  { depsCompleted :=
      fun dependency depends =>
        ui_completed_preserved stateExt dependency
          (frame.depsCompleted dependency depends)
    scopeAllowed :=
      UserInterface.uiScopeOrder.trans
        frame.scopeAllowed
        stateExt.activeScopeGrows
    preconditionHolds :=
      ui_precondition_preserved stateExt module
        frame.preconditionHolds
    guardHolds :=
      ui_guard_preserved stateExt module
        frame.guardHolds }

def UiFacetStableAt
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    (before after : UserInterface.UiState)
    (module : UserInterface.UiModule) : Prop :=
  (facet : UiPolicyFacet) ->
    uiFacetRequirements (uiPolicyContext after module) facet ->
    (bundle.policy facet).allows (uiPolicyContext before module) ->
    (bundle.policy facet).allows (uiPolicyContext after module)

theorem ui_facet_requirements_preserved
    {bundle : PolicyBundle UiPolicyContext UiPolicyFacet}
    {before after : UserInterface.UiState}
    {module : UserInterface.UiModule}
    (stable : UiFacetStableAt bundle before after module)
    (allows :
      (uiFacetRequirementPolicy bundle).allows
        (uiPolicyContext before module)) :
    (uiFacetRequirementPolicy bundle).allows
      (uiPolicyContext after module) := by
  intro facet requiredFacet
  exact stable facet requiredFacet (allows facet requiredFacet)

theorem ui_can_start_preserved_by_extension
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    {before after : UserInterface.UiState}
    {module : UserInterface.UiModule}
    (stateExt : UiStateExtends before after)
    (stable : UiFacetStableAt bundle before after module)
    (canStart :
      CanStart
        (uiBundleSpec bundle)
        before
        module) :
    CanStart
      (uiBundleSpec bundle)
      after
      module :=
  { depsCompleted :=
      fun dependency depends =>
        ui_completed_preserved stateExt dependency
          (canStart.depsCompleted dependency depends)
    scopeAllowed :=
      UserInterface.uiScopeOrder.trans
        canStart.scopeAllowed
        stateExt.activeScopeGrows
    policyHolds :=
      And.intro
        (ui_policy_allows_preserved stateExt module
          canStart.policyHolds.left)
        (ui_facet_requirements_preserved stable
          canStart.policyHolds.right)
    preconditionHolds :=
      ui_precondition_preserved stateExt module
        canStart.preconditionHolds
    guardHolds :=
      ui_guard_preserved stateExt module
        canStart.guardHolds }

theorem ui_strategy_contract_preserved_by_extension
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    {before after : UserInterface.UiState}
    (stateExt : UiStateExtends before after)
    (stable : UiFacetStableAt
      bundle
      before
      after
      UserInterface.UiModule.strategyPlan)
    (contract : UiStrategyPlanStartContract bundle before) :
    UiStrategyPlanStartContract bundle after :=
  { startFrame :=
      ui_startFrame_preserved stateExt contract.startFrame
    selectorDependency :=
      stateExt.selectorPolicyDone contract.selectorDependency
    resourceDependency :=
      stateExt.resourcePolicyDone contract.resourceDependency
    capabilityDependency :=
      stateExt.capabilityPolicyDone contract.capabilityDependency
    selectorFacet :=
      stable UiPolicyFacet.selector True.intro contract.selectorFacet
    resourceFacet :=
      stable UiPolicyFacet.resource True.intro contract.resourceFacet
    capabilityFacet :=
      stable UiPolicyFacet.capability True.intro contract.capabilityFacet }

theorem ui_runtime_contract_preserved_by_extension
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    {before after : UserInterface.UiState}
    (stateExt : UiStateExtends before after)
    (stable : UiFacetStableAt
      bundle
      before
      after
      UserInterface.UiModule.runtimeManifest)
    (contract : UiRuntimeManifestStartContract bundle before) :
    UiRuntimeManifestStartContract bundle after :=
  { startFrame :=
      ui_startFrame_preserved stateExt contract.startFrame
    strategyDependency :=
      stateExt.strategyPlanDone contract.strategyDependency
    validationDependency :=
      stateExt.localValidationDone contract.validationDependency
    memoryDependency :=
      stateExt.memoryPolicyDone contract.memoryDependency
    compressionDependency :=
      stateExt.compressionPolicyDone contract.compressionDependency
    memoryFacet :=
      stable UiPolicyFacet.memory True.intro contract.memoryFacet
    compressionFacet :=
      stable UiPolicyFacet.compression True.intro contract.compressionFacet }

theorem ui_benchmark_contract_preserved_by_extension
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    {before after : UserInterface.UiState}
    (stateExt : UiStateExtends before after)
    (stable : UiFacetStableAt
      bundle
      before
      after
      UserInterface.UiModule.scenarioBenchmark)
    (contract : UiBenchmarkStartContract bundle before) :
    UiBenchmarkStartContract bundle after :=
  { startFrame :=
      ui_startFrame_preserved stateExt contract.startFrame
    matrixDependency :=
      stateExt.scenarioMatrixDone contract.matrixDependency
    reportDependency :=
      stateExt.l1ReportDone contract.reportDependency
    fixturePolicy :=
      stateExt.performanceFixtureBound contract.fixturePolicy
    fixtureFacet :=
      stable
        UiPolicyFacet.performanceFixture
        True.intro
        contract.fixtureFacet }

theorem ui_safe_selector_override_can_start_preserved_as_parent
    (parent localPolicy : PolicyBundle UiPolicyContext UiPolicyFacet)
    (overrides : UiPolicyContext -> Prop)
    {before after : UserInterface.UiState}
    {module : UserInterface.UiModule}
    (stateExt : UiStateExtends before after)
    (stable :
      UiFacetStableAt
        (parent.overrideFacet
          localPolicy
          UiPolicyFacet.selector
          overrides)
        before
        after
        module)
    (localRefinesParentSelector :
      (context : UiPolicyContext) ->
        (localPolicy.policy UiPolicyFacet.selector).allows context ->
        (parent.policy UiPolicyFacet.selector).allows context)
    (canStart :
      CanStart
        (uiBundleSpec
          (parent.overrideFacet
            localPolicy
            UiPolicyFacet.selector
            overrides))
        before
        module) :
    CanStart
      (uiBundleSpec parent)
      after
      module :=
  ui_selector_override_can_start_refines_parent
    parent
    localPolicy
    overrides
    localRefinesParentSelector
    (ui_can_start_preserved_by_extension
      (parent.overrideFacet
        localPolicy
        UiPolicyFacet.selector
        overrides)
      stateExt
      stable
      canStart)

end AgenticAILabProof.PooC4.PolicyComposition
