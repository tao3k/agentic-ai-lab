-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.PolicyStartContract

namespace AgenticAILabProof.PooC4.PolicyComposition

open AgenticAILabProof.PooC4

def PolicyObject.refines
    {Context : Type u}
    (strict broad : PolicyObject Context) : Prop :=
  (context : Context) ->
    strict.allows context ->
    broad.allows context

theorem PolicyObject.refines_refl
    {Context : Type u}
    (policy : PolicyObject Context) :
    policy.refines policy :=
  fun _ allows => allows

theorem PolicyObject.refines_trans
    {Context : Type u}
    {strict middle broad : PolicyObject Context}
    (strictMiddle : strict.refines middle)
    (middleBroad : middle.refines broad) :
    strict.refines broad :=
  fun context allows =>
    middleBroad context (strictMiddle context allows)

theorem allOf_refines_left
    {Context : Type u}
    (left right : PolicyObject Context) :
    (left.allOf right).refines left :=
  fun _ allows => allows.left

theorem allOf_refines_right
    {Context : Type u}
    (left right : PolicyObject Context) :
    (left.allOf right).refines right :=
  fun _ allows => allows.right

theorem allOf_refines_of_right_refines
    {Context : Type u}
    {left strictRight broadRight : PolicyObject Context}
    (rightRefines : strictRight.refines broadRight) :
    (left.allOf strictRight).refines (left.allOf broadRight) :=
  fun context allows =>
    And.intro
      allows.left
      (rightRefines context allows.right)

theorem can_start_policy_refines
    {Module Scope State Context : Type u}
    {spec : FlowSpec Module Scope State}
    {contextOf : State -> Module -> Context}
    {strict broad : PolicyObject Context}
    {state : State}
    {module : Module}
    (refines : strict.refines broad)
    (canStart :
      CanStart
        (flowSpecWithPolicyObject spec contextOf strict)
        state
        module) :
    CanStart
      (flowSpecWithPolicyObject spec contextOf broad)
      state
      module :=
  { depsCompleted := canStart.depsCompleted
    scopeAllowed := canStart.scopeAllowed
    policyHolds := refines (contextOf state module) canStart.policyHolds
    preconditionHolds := canStart.preconditionHolds
    guardHolds := canStart.guardHolds }

def PolicyBundle.refines
    {Context : Type u}
    {Facet : Type v}
    (strict broad : PolicyBundle Context Facet) : Prop :=
  (facet : Facet) ->
    (context : Context) ->
    (strict.policy facet).allows context ->
    (broad.policy facet).allows context

theorem PolicyBundle.refines_refl
    {Context : Type u}
    {Facet : Type v}
    (bundle : PolicyBundle Context Facet) :
    bundle.refines bundle :=
  fun _ _ allows => allows

theorem PolicyBundle.refines_trans
    {Context : Type u}
    {Facet : Type v}
    {strict middle broad : PolicyBundle Context Facet}
    (strictMiddle : strict.refines middle)
    (middleBroad : middle.refines broad) :
    strict.refines broad :=
  fun facet context allows =>
    middleBroad facet context
      (strictMiddle facet context allows)

theorem requirementsPolicy_refines
    {Context : Type u}
    {Facet : Type v}
    {strict broad : PolicyBundle Context Facet}
    {required : Context -> Facet -> Prop}
    (refines : strict.refines broad) :
    (strict.requirementsPolicy required).refines
      (broad.requirementsPolicy required) :=
  fun context strictAllows facet requiredFacet =>
    refines facet context (strictAllows facet requiredFacet)

theorem bundle_allOf_refines_left
    {Context : Type u}
    {Facet : Type v}
    (left right : PolicyBundle Context Facet) :
    (left.allOf right).refines left :=
  fun _ _ allows => allows.left

theorem bundle_allOf_refines_right
    {Context : Type u}
    {Facet : Type v}
    (left right : PolicyBundle Context Facet) :
    (left.allOf right).refines right :=
  fun _ _ allows => allows.right

theorem can_start_bundle_refines
    {Module Scope State Context : Type u}
    {Facet : Type v}
    {spec : FlowSpec Module Scope State}
    {contextOf : State -> Module -> Context}
    {strict broad : PolicyBundle Context Facet}
    {required : Context -> Facet -> Prop}
    {state : State}
    {module : Module}
    (refines : strict.refines broad)
    (canStart :
      CanStart
        (flowSpecWithPolicyObject spec contextOf
          (strict.requirementsPolicy required))
        state
        module) :
    CanStart
      (flowSpecWithPolicyObject spec contextOf
        (broad.requirementsPolicy required))
      state
      module :=
  can_start_policy_refines
    (requirementsPolicy_refines refines)
    canStart

theorem ui_can_start_bundle_refines
    {strict broad : PolicyBundle UiPolicyContext UiPolicyFacet}
    {state : UserInterface.UiState}
    {module : UserInterface.UiModule}
    (refines : strict.refines broad)
    (canStart :
      CanStart
        (uiBundleSpec strict)
        state
        module) :
    CanStart
      (uiBundleSpec broad)
      state
      module :=
  can_start_policy_refines
    (allOf_refines_of_right_refines
      (requirementsPolicy_refines refines))
    canStart

theorem ui_can_start_allOf_bundle_refines_left
    (left right : PolicyBundle UiPolicyContext UiPolicyFacet)
    {state : UserInterface.UiState}
    {module : UserInterface.UiModule}
    (canStart :
      CanStart
        (uiBundleSpec (left.allOf right))
        state
        module) :
    CanStart
      (uiBundleSpec left)
      state
      module :=
  ui_can_start_bundle_refines
    (bundle_allOf_refines_left left right)
    canStart

theorem ui_can_start_allOf_bundle_refines_right
    (left right : PolicyBundle UiPolicyContext UiPolicyFacet)
    {state : UserInterface.UiState}
    {module : UserInterface.UiModule}
    (canStart :
      CanStart
        (uiBundleSpec (left.allOf right))
        state
        module) :
    CanStart
      (uiBundleSpec right)
      state
      module :=
  ui_can_start_bundle_refines
    (bundle_allOf_refines_right left right)
    canStart

theorem overrideFacet_refines_parent_when_local_refines_target
    {Context : Type u}
    {Facet : Type v}
    [DecidableEq Facet]
    {parent localPolicy : PolicyBundle Context Facet}
    {target : Facet}
    {overrides : Context -> Prop}
    (localRefinesParent :
      (context : Context) ->
        (localPolicy.policy target).allows context ->
        (parent.policy target).allows context) :
    (parent.overrideFacet localPolicy target overrides).refines parent := by
  intro facet context allows
  by_cases isTarget : facet = target
  · subst facet
    by_cases isOverride : overrides context
    · exact
        localRefinesParent context
          ((overrideFacet_target_allows_iff
            (parent := parent)
            (localPolicy := localPolicy)
            (target := target)
            (overrides := overrides)
            (context := context)
            isOverride).mp allows)
    · have allowsTarget :
          ((parent.policy target).overrideBy
            (localPolicy.policy target)
            overrides).allows context := by
        simpa [PolicyBundle.overrideFacet] using allows
      exact
        (override_when_not_overridden_iff
          (parent := parent.policy target)
          (localPolicy := localPolicy.policy target)
          (overrides := overrides)
          (context := context)
          isOverride).mp allowsTarget
  · exact
      (overrideFacet_preserves_other
        (parent := parent)
        (localPolicy := localPolicy)
        (target := target)
        (facet := facet)
        (overrides := overrides)
        (context := context)
        isTarget).mp allows

theorem ui_selector_override_can_start_refines_parent
    (parent localPolicy : PolicyBundle UiPolicyContext UiPolicyFacet)
    (overrides : UiPolicyContext -> Prop)
    {state : UserInterface.UiState}
    {module : UserInterface.UiModule}
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
        state
        module) :
    CanStart
      (uiBundleSpec parent)
      state
      module :=
  ui_can_start_bundle_refines
    (overrideFacet_refines_parent_when_local_refines_target
      (parent := parent)
      (localPolicy := localPolicy)
      (target := UiPolicyFacet.selector)
      (overrides := overrides)
      localRefinesParentSelector)
    canStart

theorem ui_strategy_selector_override_parent_contract_of_safe_can_start
    (parent localPolicy : PolicyBundle UiPolicyContext UiPolicyFacet)
    (overrides : UiPolicyContext -> Prop)
    {state : UserInterface.UiState}
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
        state
        UserInterface.UiModule.strategyPlan) :
    UiStrategyPlanStartContract parent state :=
  ui_strategy_plan_start_contract_of_can_start
    parent
    (ui_selector_override_can_start_refines_parent
      parent
      localPolicy
      overrides
      localRefinesParentSelector
      canStart)

theorem ui_runtime_selector_override_parent_contract_of_safe_can_start
    (parent localPolicy : PolicyBundle UiPolicyContext UiPolicyFacet)
    (overrides : UiPolicyContext -> Prop)
    {state : UserInterface.UiState}
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
        state
        UserInterface.UiModule.runtimeManifest) :
    UiRuntimeManifestStartContract parent state :=
  ui_runtime_manifest_start_contract_of_can_start
    parent
    (ui_selector_override_can_start_refines_parent
      parent
      localPolicy
      overrides
      localRefinesParentSelector
      canStart)

end AgenticAILabProof.PooC4.PolicyComposition
