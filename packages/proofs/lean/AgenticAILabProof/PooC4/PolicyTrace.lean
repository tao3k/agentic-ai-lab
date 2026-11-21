-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.PolicyProgression

namespace AgenticAILabProof.PooC4.PolicyComposition

open AgenticAILabProof.PooC4

structure UiCompletionStep
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    (before after : UserInterface.UiState)
    (module : UserInterface.UiModule) : Prop where
  canStartBefore :
    CanStart (uiBundleSpec bundle) before module
  stateExtends : UiStateExtends before after
  completedAfter : UserInterface.uiCompleted after module

theorem ui_completion_step_records_completed
    {bundle : PolicyBundle UiPolicyContext UiPolicyFacet}
    {before after : UserInterface.UiState}
    {module : UserInterface.UiModule}
    (step : UiCompletionStep bundle before after module) :
    UserInterface.uiCompleted after module :=
  step.completedAfter

theorem ui_completion_step_preserves_prior_completed
    {bundle : PolicyBundle UiPolicyContext UiPolicyFacet}
    {before after : UserInterface.UiState}
    {started dependency : UserInterface.UiModule}
    (step : UiCompletionStep bundle before after started)
    (completedBefore : UserInterface.uiCompleted before dependency) :
    UserInterface.uiCompleted after dependency :=
  ui_completed_preserved
    step.stateExtends
    dependency
    completedBefore

theorem ui_completion_step_preserves_can_start
    {bundle : PolicyBundle UiPolicyContext UiPolicyFacet}
    {before after : UserInterface.UiState}
    {completed observed : UserInterface.UiModule}
    (step : UiCompletionStep bundle before after completed)
    (stable : UiFacetStableAt bundle before after observed)
    (canStart :
      CanStart (uiBundleSpec bundle) before observed) :
    CanStart (uiBundleSpec bundle) after observed :=
  ui_can_start_preserved_by_extension
    bundle
    step.stateExtends
    stable
    canStart

theorem ui_completion_step_started_contract_after
    {bundle : PolicyBundle UiPolicyContext UiPolicyFacet}
    {before after : UserInterface.UiState}
    {module : UserInterface.UiModule}
    (step : UiCompletionStep bundle before after module)
    (stable : UiFacetStableAt bundle before after module) :
    CanStart (uiBundleSpec bundle) after module :=
  ui_completion_step_preserves_can_start
    step
    stable
    step.canStartBefore

theorem ui_strategy_step_records_strategy_done
    {bundle : PolicyBundle UiPolicyContext UiPolicyFacet}
    {before after : UserInterface.UiState}
    (step :
      UiCompletionStep
        bundle
        before
        after
        UserInterface.UiModule.strategyPlan) :
    after.strategyPlanDone :=
  step.completedAfter

theorem ui_validation_step_records_validation_done
    {bundle : PolicyBundle UiPolicyContext UiPolicyFacet}
    {before after : UserInterface.UiState}
    (step :
      UiCompletionStep
        bundle
        before
        after
        UserInterface.UiModule.localValidation) :
    after.localValidationDone :=
  step.completedAfter

theorem ui_runtime_step_records_runtime_done
    {bundle : PolicyBundle UiPolicyContext UiPolicyFacet}
    {before after : UserInterface.UiState}
    (step :
      UiCompletionStep
        bundle
        before
        after
        UserInterface.UiModule.runtimeManifest) :
    after.runtimeManifestDone :=
  step.completedAfter

theorem ui_handoff_step_records_handoff_done
    {bundle : PolicyBundle UiPolicyContext UiPolicyFacet}
    {before after : UserInterface.UiState}
    (step :
      UiCompletionStep
        bundle
        before
        after
        UserInterface.UiModule.marlinHandoff) :
    after.marlinHandoffDone :=
  step.completedAfter

theorem ui_report_step_records_report_done
    {bundle : PolicyBundle UiPolicyContext UiPolicyFacet}
    {before after : UserInterface.UiState}
    (step :
      UiCompletionStep
        bundle
        before
        after
        UserInterface.UiModule.l1Report) :
    after.l1ReportDone :=
  step.completedAfter

theorem ui_matrix_step_records_matrix_done
    {bundle : PolicyBundle UiPolicyContext UiPolicyFacet}
    {before after : UserInterface.UiState}
    (step :
      UiCompletionStep
        bundle
        before
        after
        UserInterface.UiModule.scenarioMatrix) :
    after.scenarioMatrixDone :=
  step.completedAfter

structure UiRuntimeReadyAfterStrategyStep
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    (before after : UserInterface.UiState) : Prop where
  strategyStep :
    UiCompletionStep
      bundle
      before
      after
      UserInterface.UiModule.strategyPlan
  validationDone : after.localValidationDone
  memoryDone : after.memoryPolicyDone
  compressionDone : after.compressionPolicyDone
  runtimeScope :
    UserInterface.uiScopeOrder.le
      (UserInterface.uiModuleScope UserInterface.UiModule.runtimeManifest)
      after.activeScope
  runtimeUiPolicy : UserInterface.uiPolicyAllows
    after
    UserInterface.UiModule.runtimeManifest
  runtimeMemoryFacet :
    (bundle.policy UiPolicyFacet.memory).allows
      (UiRuntimeContext after)
  runtimeCompressionFacet :
    (bundle.policy UiPolicyFacet.compression).allows
      (UiRuntimeContext after)

theorem ui_runtime_can_start_after_strategy_step
    {bundle : PolicyBundle UiPolicyContext UiPolicyFacet}
    {before after : UserInterface.UiState}
    (ready : UiRuntimeReadyAfterStrategyStep bundle before after) :
    CanStart
      (uiBundleSpec bundle)
      after
      UserInterface.UiModule.runtimeManifest :=
  { depsCompleted := by
      intro dependency depends
      cases depends
      · exact ui_strategy_step_records_strategy_done ready.strategyStep
      · exact ready.validationDone
      · exact ready.memoryDone
      · exact ready.compressionDone
    scopeAllowed := ready.runtimeScope
    policyHolds :=
      And.intro
        ready.runtimeUiPolicy
        (by
          intro facet requiredFacet
          cases facet <;> cases requiredFacet
          · exact ready.runtimeMemoryFacet
          · exact ready.runtimeCompressionFacet)
    preconditionHolds :=
      And.intro
        (ui_strategy_step_records_strategy_done ready.strategyStep)
        (And.intro
          ready.validationDone
          (And.intro
            ready.memoryDone
            ready.compressionDone))
    guardHolds := trivial }

theorem ui_benchmark_blocked_after_strategy_without_matrix
    {bundle : PolicyBundle UiPolicyContext UiPolicyFacet}
    {before after : UserInterface.UiState}
    (_step :
      UiCompletionStep
        bundle
        before
        after
        UserInterface.UiModule.strategyPlan)
    (missingMatrix : ¬ after.scenarioMatrixDone) :
    ¬ CanStart
      (uiBundleSpec bundle)
      after
      UserInterface.UiModule.scenarioBenchmark := by
  intro canStart
  exact
    missingMatrix
      (canStart.depsCompleted
        UserInterface.UiModule.scenarioMatrix
        UserInterface.UiDependsOn.benchmarkMatrix)

structure UiBenchmarkReadyAfterReportAndMatrix
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    (after : UserInterface.UiState) : Prop where
  matrixDone : after.scenarioMatrixDone
  reportDone : after.l1ReportDone
  fixtureBound : after.performanceFixtureBound
  benchmarkScope :
    UserInterface.uiScopeOrder.le
      (UserInterface.uiModuleScope UserInterface.UiModule.scenarioBenchmark)
      after.activeScope
  fixtureFacet :
    (bundle.policy UiPolicyFacet.performanceFixture).allows
      (UiBenchmarkContext after)

theorem ui_benchmark_can_start_when_report_matrix_and_fixture_ready
    {bundle : PolicyBundle UiPolicyContext UiPolicyFacet}
    {after : UserInterface.UiState}
    (ready : UiBenchmarkReadyAfterReportAndMatrix bundle after) :
    CanStart
      (uiBundleSpec bundle)
      after
      UserInterface.UiModule.scenarioBenchmark :=
  { depsCompleted := by
      intro dependency depends
      cases depends
      · exact ready.matrixDone
      · exact ready.reportDone
    scopeAllowed := ready.benchmarkScope
    policyHolds :=
      And.intro
        ready.fixtureBound
        (by
          intro facet requiredFacet
          cases facet <;> cases requiredFacet
          exact ready.fixtureFacet)
    preconditionHolds :=
      And.intro
        ready.matrixDone
        (And.intro
          ready.reportDone
          ready.fixtureBound)
    guardHolds := ready.fixtureBound }

theorem ui_safe_selector_override_step_preserved_as_parent_step
    (parent localPolicy : PolicyBundle UiPolicyContext UiPolicyFacet)
    (overrides : UiPolicyContext -> Prop)
    {before after : UserInterface.UiState}
    {module : UserInterface.UiModule}
    (localRefinesParentSelector :
      (context : UiPolicyContext) ->
        (localPolicy.policy UiPolicyFacet.selector).allows context ->
        (parent.policy UiPolicyFacet.selector).allows context)
    (step :
      UiCompletionStep
        (parent.overrideFacet
          localPolicy
          UiPolicyFacet.selector
          overrides)
        before
        after
        module) :
    UiCompletionStep parent before after module :=
  { canStartBefore :=
      ui_selector_override_can_start_refines_parent
        parent
        localPolicy
        overrides
        localRefinesParentSelector
        step.canStartBefore
    stateExtends := step.stateExtends
    completedAfter := step.completedAfter }

end AgenticAILabProof.PooC4.PolicyComposition
