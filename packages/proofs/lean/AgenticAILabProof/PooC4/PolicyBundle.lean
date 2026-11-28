-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.PolicyComposition

namespace AgenticAILabProof.PooC4.PolicyComposition

open AgenticAILabProof.PooC4

structure PolicyBundle (Context : Type u) (Facet : Type v) where
  policy : Facet -> PolicyObject Context

def PolicyBundle.on
    {Context Source : Type u}
    {Facet : Type v}
    (bundle : PolicyBundle Context Facet)
    (project : Source -> Context) : PolicyBundle Source Facet :=
  { policy := fun facet =>
      (bundle.policy facet).on project }

def PolicyBundle.allOf
    {Context : Type u}
    {Facet : Type v}
    (left right : PolicyBundle Context Facet) :
    PolicyBundle Context Facet :=
  { policy := fun facet =>
      (left.policy facet).allOf (right.policy facet) }

def PolicyBundle.anyOf
    {Context : Type u}
    {Facet : Type v}
    (left right : PolicyBundle Context Facet) :
    PolicyBundle Context Facet :=
  { policy := fun facet =>
      (left.policy facet).anyOf (right.policy facet) }

def PolicyBundle.overrideFacet
    {Context : Type u}
    {Facet : Type v}
    [DecidableEq Facet]
    (parent localPolicy : PolicyBundle Context Facet)
    (target : Facet)
    (overrides : Context -> Prop) : PolicyBundle Context Facet :=
  { policy := fun facet =>
      if facet = target then
        (parent.policy facet).overrideBy (localPolicy.policy facet) overrides
      else
        parent.policy facet }

def PolicyBundle.requiresAt
    {Context : Type u}
    {Facet : Type v}
    (bundle : PolicyBundle Context Facet)
    (required : Context -> Facet -> Prop)
    (context : Context) : Prop :=
  (facet : Facet) ->
    required context facet ->
    (bundle.policy facet).allows context

def PolicyBundle.requirementsPolicy
    {Context : Type u}
    {Facet : Type v}
    (bundle : PolicyBundle Context Facet)
    (required : Context -> Facet -> Prop) : PolicyObject Context :=
  { allows := fun context =>
      bundle.requiresAt required context }

theorem requirementsPolicy_allows_iff
    {Context : Type u}
    {Facet : Type v}
    {bundle : PolicyBundle Context Facet}
    {required : Context -> Facet -> Prop}
    {context : Context} :
    (bundle.requirementsPolicy required).allows context ↔
      bundle.requiresAt required context :=
  Iff.rfl

theorem bundle_allOf_requires_left
    {Context : Type u}
    {Facet : Type v}
    {left right : PolicyBundle Context Facet}
    {facet : Facet}
    {context : Context}
    (allows : ((left.allOf right).policy facet).allows context) :
    (left.policy facet).allows context :=
  allows.left

theorem bundle_allOf_requires_right
    {Context : Type u}
    {Facet : Type v}
    {left right : PolicyBundle Context Facet}
    {facet : Facet}
    {context : Context}
    (allows : ((left.allOf right).policy facet).allows context) :
    (right.policy facet).allows context :=
  allows.right

theorem bundle_allOf_requirements_iff
    {Context : Type u}
    {Facet : Type v}
    {left right : PolicyBundle Context Facet}
    {required : Context -> Facet -> Prop}
    {context : Context} :
    ((left.allOf right).requirementsPolicy required).allows context ↔
      (left.requirementsPolicy required).allows context ∧
      (right.requirementsPolicy required).allows context := by
  constructor
  · intro allows
    exact
      And.intro
        (fun facet requiredFacet =>
          (allows facet requiredFacet).left)
        (fun facet requiredFacet =>
          (allows facet requiredFacet).right)
  · intro allows
    intro facet requiredFacet
    exact
      And.intro
        (allows.left facet requiredFacet)
        (allows.right facet requiredFacet)

theorem bundle_anyOf_requirements_of_left
    {Context : Type u}
    {Facet : Type v}
    {left right : PolicyBundle Context Facet}
    {required : Context -> Facet -> Prop}
    {context : Context}
    (leftAllows : (left.requirementsPolicy required).allows context) :
    ((left.anyOf right).requirementsPolicy required).allows context := by
  intro facet requiredFacet
  exact Or.inl (leftAllows facet requiredFacet)

theorem bundle_anyOf_requirements_of_right
    {Context : Type u}
    {Facet : Type v}
    {left right : PolicyBundle Context Facet}
    {required : Context -> Facet -> Prop}
    {context : Context}
    (rightAllows : (right.requirementsPolicy required).allows context) :
    ((left.anyOf right).requirementsPolicy required).allows context := by
  intro facet requiredFacet
  exact Or.inr (rightAllows facet requiredFacet)

theorem overrideFacet_target_allows_iff
    {Context : Type u}
    {Facet : Type v}
    [DecidableEq Facet]
    {parent localPolicy : PolicyBundle Context Facet}
    {target : Facet}
    {overrides : Context -> Prop}
    {context : Context}
    (isOverride : overrides context) :
    ((parent.overrideFacet localPolicy target overrides).policy target).allows
        context ↔
      (localPolicy.policy target).allows context := by
  simpa [PolicyBundle.overrideFacet] using
    (override_when_overridden_iff
      (parent := parent.policy target)
      (localPolicy := localPolicy.policy target)
      (overrides := overrides)
      (context := context)
      isOverride)

theorem overrideFacet_target_denies_iff
    {Context : Type u}
    {Facet : Type v}
    [DecidableEq Facet]
    {parent localPolicy : PolicyBundle Context Facet}
    {target : Facet}
    {overrides : Context -> Prop}
    {context : Context}
    (isOverride : overrides context) :
    ¬ ((parent.overrideFacet localPolicy target overrides).policy target).allows
        context ↔
      ¬ (localPolicy.policy target).allows context := by
  simpa [PolicyBundle.overrideFacet] using
    (override_denies_when_overridden_iff
      (parent := parent.policy target)
      (localPolicy := localPolicy.policy target)
      (overrides := overrides)
      (context := context)
      isOverride)

theorem overrideFacet_preserves_other
    {Context : Type u}
    {Facet : Type v}
    [DecidableEq Facet]
    {parent localPolicy : PolicyBundle Context Facet}
    {target facet : Facet}
    {overrides : Context -> Prop}
    {context : Context}
    (notTarget : facet ≠ target) :
    ((parent.overrideFacet localPolicy target overrides).policy facet).allows
        context ↔
      (parent.policy facet).allows context := by
  simp [PolicyBundle.overrideFacet, notTarget]

theorem overrideFacet_requires_local_target_when_overridden
    {Context : Type u}
    {Facet : Type v}
    [DecidableEq Facet]
    {parent localPolicy : PolicyBundle Context Facet}
    {required : Context -> Facet -> Prop}
    {target : Facet}
    {overrides : Context -> Prop}
    {context : Context}
    (requiredTarget : required context target)
    (isOverride : overrides context)
    (allows :
      (PolicyBundle.requirementsPolicy
        (parent.overrideFacet localPolicy target overrides)
        required).allows context) :
    (localPolicy.policy target).allows context :=
  (overrideFacet_target_allows_iff
    (parent := parent)
    (localPolicy := localPolicy)
    (target := target)
    (overrides := overrides)
    (context := context)
    isOverride).mp
    (allows target requiredTarget)

theorem can_start_with_bundle_requires_facet
    {Module Scope State Context : Type u}
    {Facet : Type v}
    {spec : FlowSpec Module Scope State}
    {contextOf : State -> Module -> Context}
    {bundle : PolicyBundle Context Facet}
    {required : Context -> Facet -> Prop}
    {state : State}
    {module : Module}
    {facet : Facet}
    (requiredFacet : required (contextOf state module) facet)
    (canStart :
      CanStart
        (flowSpecWithPolicyObject spec contextOf
          (bundle.requirementsPolicy required))
        state
        module) :
    (bundle.policy facet).allows (contextOf state module) :=
  canStart.policyHolds facet requiredFacet

theorem can_start_with_bundle_iff_startFrame_and_facets
    {Module Scope State Context : Type u}
    {Facet : Type v}
    {spec : FlowSpec Module Scope State}
    {contextOf : State -> Module -> Context}
    {bundle : PolicyBundle Context Facet}
    {required : Context -> Facet -> Prop}
    {state : State}
    {module : Module} :
    CanStart
        (flowSpecWithPolicyObject spec contextOf
          (bundle.requirementsPolicy required))
        state
        module ↔
      StartFrame spec state module ∧
        ((facet : Facet) ->
          required (contextOf state module) facet ->
          (bundle.policy facet).allows (contextOf state module)) :=
  can_start_with_policy_object_iff_startFrame_and_policy

inductive UiPolicyFacet where
  | lineage
  | selector
  | resource
  | capability
  | memory
  | compression
  | performanceFixture
deriving Repr, DecidableEq

def uiModuleRequiresFacet :
    UserInterface.UiModule -> UiPolicyFacet -> Prop
  | UserInterface.UiModule.lineagePolicy, UiPolicyFacet.lineage => True
  | UserInterface.UiModule.strategyPlan, UiPolicyFacet.selector => True
  | UserInterface.UiModule.strategyPlan, UiPolicyFacet.resource => True
  | UserInterface.UiModule.strategyPlan, UiPolicyFacet.capability => True
  | UserInterface.UiModule.runtimeManifest, UiPolicyFacet.memory => True
  | UserInterface.UiModule.runtimeManifest, UiPolicyFacet.compression => True
  | UserInterface.UiModule.scenarioBenchmark,
    UiPolicyFacet.performanceFixture => True
  | _, _ => False

def uiFacetRequirements :
    UiPolicyContext -> UiPolicyFacet -> Prop :=
  fun context facet =>
    uiModuleRequiresFacet context.2 facet

def uiFacetRequirementPolicy
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet) :
    PolicyObject UiPolicyContext :=
  bundle.requirementsPolicy uiFacetRequirements

def uiBundleSpec
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet) :
    FlowSpec
      UserInterface.UiModule
      UserInterface.UiScope
      UserInterface.UiState :=
  flowSpecWithPolicyObject
    UserInterface.uiSpec
    uiPolicyContext
    (uiPolicyObject.allOf (uiFacetRequirementPolicy bundle))

theorem ui_strategy_plan_bundle_requires_facets
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    {state : UserInterface.UiState}
    (canStart :
      CanStart
        (uiBundleSpec bundle)
        state
        UserInterface.UiModule.strategyPlan) :
    (bundle.policy UiPolicyFacet.selector).allows
        (uiPolicyContext state UserInterface.UiModule.strategyPlan) ∧
      (bundle.policy UiPolicyFacet.resource).allows
        (uiPolicyContext state UserInterface.UiModule.strategyPlan) ∧
      (bundle.policy UiPolicyFacet.capability).allows
        (uiPolicyContext state UserInterface.UiModule.strategyPlan) := by
  have bundleAllows :
      (uiFacetRequirementPolicy bundle).allows
        (uiPolicyContext state UserInterface.UiModule.strategyPlan) :=
    (can_start_allOf_requires_policies canStart).right
  exact
    And.intro
      (bundleAllows UiPolicyFacet.selector True.intro)
      (And.intro
        (bundleAllows UiPolicyFacet.resource True.intro)
        (bundleAllows UiPolicyFacet.capability True.intro))

theorem ui_runtime_manifest_bundle_requires_facets
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    {state : UserInterface.UiState}
    (canStart :
      CanStart
        (uiBundleSpec bundle)
        state
        UserInterface.UiModule.runtimeManifest) :
    (bundle.policy UiPolicyFacet.memory).allows
        (uiPolicyContext state UserInterface.UiModule.runtimeManifest) ∧
      (bundle.policy UiPolicyFacet.compression).allows
        (uiPolicyContext state UserInterface.UiModule.runtimeManifest) := by
  have bundleAllows :
      (uiFacetRequirementPolicy bundle).allows
        (uiPolicyContext state UserInterface.UiModule.runtimeManifest) :=
    (can_start_allOf_requires_policies canStart).right
  exact
    And.intro
      (bundleAllows UiPolicyFacet.memory True.intro)
      (bundleAllows UiPolicyFacet.compression True.intro)

theorem ui_benchmark_bundle_requires_performance_fixture
    (bundle : PolicyBundle UiPolicyContext UiPolicyFacet)
    {state : UserInterface.UiState}
    (canStart :
      CanStart
        (uiBundleSpec bundle)
        state
        UserInterface.UiModule.scenarioBenchmark) :
    (bundle.policy UiPolicyFacet.performanceFixture).allows
      (uiPolicyContext state UserInterface.UiModule.scenarioBenchmark) := by
  have bundleAllows :
      (uiFacetRequirementPolicy bundle).allows
        (uiPolicyContext state UserInterface.UiModule.scenarioBenchmark) :=
    (can_start_allOf_requires_policies canStart).right
  exact bundleAllows UiPolicyFacet.performanceFixture True.intro

theorem ui_override_selector_local_denial_blocks_strategy
    (parent localPolicy : PolicyBundle UiPolicyContext UiPolicyFacet)
    (overrides : UiPolicyContext -> Prop)
    {state : UserInterface.UiState}
    (isOverride :
      overrides
        (uiPolicyContext state UserInterface.UiModule.strategyPlan))
    (localDenied :
      ¬ (localPolicy.policy UiPolicyFacet.selector).allows
          (uiPolicyContext state UserInterface.UiModule.strategyPlan)) :
    ¬ CanStart
      (uiBundleSpec
        (parent.overrideFacet
          localPolicy
          UiPolicyFacet.selector
          overrides))
      state
      UserInterface.UiModule.strategyPlan := by
  intro canStart
  have selectedFacet :
      ((parent.overrideFacet
          localPolicy
          UiPolicyFacet.selector
          overrides).policy UiPolicyFacet.selector).allows
        (uiPolicyContext state UserInterface.UiModule.strategyPlan) :=
    (ui_strategy_plan_bundle_requires_facets
      (parent.overrideFacet
        localPolicy
        UiPolicyFacet.selector
        overrides)
      canStart).left
  exact
    localDenied
      ((overrideFacet_target_allows_iff
        (parent := parent)
        (localPolicy := localPolicy)
        (target := UiPolicyFacet.selector)
        (overrides := overrides)
        (context :=
          uiPolicyContext state UserInterface.UiModule.strategyPlan)
        isOverride).mp selectedFacet)

theorem ui_override_selector_preserves_runtime_memory_requirement
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
    (parent.policy UiPolicyFacet.memory).allows
      (uiPolicyContext state UserInterface.UiModule.runtimeManifest) := by
  have memoryFacet :
      ((parent.overrideFacet
          localPolicy
          UiPolicyFacet.selector
          overrides).policy UiPolicyFacet.memory).allows
        (uiPolicyContext state UserInterface.UiModule.runtimeManifest) :=
    (ui_runtime_manifest_bundle_requires_facets
      (parent.overrideFacet
        localPolicy
        UiPolicyFacet.selector
        overrides)
      canStart).left
  exact
    ((overrideFacet_preserves_other
      (parent := parent)
      (localPolicy := localPolicy)
      (target := UiPolicyFacet.selector)
      (facet := UiPolicyFacet.memory)
      (overrides := overrides)
      (context :=
        uiPolicyContext state UserInterface.UiModule.runtimeManifest)
      (by decide)).mp memoryFacet)

end AgenticAILabProof.PooC4.PolicyComposition
