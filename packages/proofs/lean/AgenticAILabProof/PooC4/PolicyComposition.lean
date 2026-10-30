-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.Semantics
import AgenticAILabProof.PooC4.StartGate
import AgenticAILabProof.PooC4.UserInterface

namespace AgenticAILabProof.PooC4.PolicyComposition

open AgenticAILabProof.PooC4

structure PolicyObject (Context : Type u) where
  allows : Context -> Prop

def PolicyObject.on
    {Context Source : Type u}
    (policy : PolicyObject Context)
    (project : Source -> Context) : PolicyObject Source :=
  { allows := fun source =>
      policy.allows (project source) }

theorem on_allows_iff
    {Context Source : Type u}
    {policy : PolicyObject Context}
    {project : Source -> Context}
    {source : Source} :
    (policy.on project).allows source ↔
      policy.allows (project source) :=
  Iff.rfl

def PolicyObject.allOf
    {Context : Type u}
    (left right : PolicyObject Context) : PolicyObject Context :=
  { allows := fun context =>
      left.allows context ∧ right.allows context }

def PolicyObject.anyOf
    {Context : Type u}
    (left right : PolicyObject Context) : PolicyObject Context :=
  { allows := fun context =>
      left.allows context ∨ right.allows context }

def PolicyObject.overrideBy
    {Context : Type u}
    (parent localPolicy : PolicyObject Context)
    (overrides : Context -> Prop) : PolicyObject Context :=
  { allows := fun context =>
      (overrides context ∧ localPolicy.allows context) ∨
      (¬ overrides context ∧ parent.allows context) }

theorem allOf_allows_iff
    {Context : Type u}
    {left right : PolicyObject Context}
    {context : Context} :
    (left.allOf right).allows context ↔
      left.allows context ∧ right.allows context :=
  Iff.rfl

theorem allOf_requires_left
    {Context : Type u}
    {left right : PolicyObject Context}
    {context : Context}
    (allows : (left.allOf right).allows context) :
    left.allows context :=
  allows.left

theorem allOf_requires_right
    {Context : Type u}
    {left right : PolicyObject Context}
    {context : Context}
    (allows : (left.allOf right).allows context) :
    right.allows context :=
  allows.right

theorem allOf_allows_of_both
    {Context : Type u}
    {left right : PolicyObject Context}
    {context : Context}
    (leftAllows : left.allows context)
    (rightAllows : right.allows context) :
    (left.allOf right).allows context :=
  And.intro leftAllows rightAllows

theorem allOf_left_denial_blocks
    {Context : Type u}
    {left right : PolicyObject Context}
    {context : Context}
    (leftDenied : ¬ left.allows context) :
    ¬ (left.allOf right).allows context := by
  intro allows
  exact leftDenied allows.left

theorem allOf_right_denial_blocks
    {Context : Type u}
    {left right : PolicyObject Context}
    {context : Context}
    (rightDenied : ¬ right.allows context) :
    ¬ (left.allOf right).allows context := by
  intro allows
  exact rightDenied allows.right

theorem anyOf_allows_iff
    {Context : Type u}
    {left right : PolicyObject Context}
    {context : Context} :
    (left.anyOf right).allows context ↔
      left.allows context ∨ right.allows context :=
  Iff.rfl

theorem anyOf_allows_left
    {Context : Type u}
    {left right : PolicyObject Context}
    {context : Context}
    (leftAllows : left.allows context) :
    (left.anyOf right).allows context :=
  Or.inl leftAllows

theorem anyOf_allows_right
    {Context : Type u}
    {left right : PolicyObject Context}
    {context : Context}
    (rightAllows : right.allows context) :
    (left.anyOf right).allows context :=
  Or.inr rightAllows

theorem anyOf_denies_iff
    {Context : Type u}
    {left right : PolicyObject Context}
    {context : Context} :
    ¬ (left.anyOf right).allows context ↔
      ¬ left.allows context ∧ ¬ right.allows context := by
  constructor
  · intro denied
    exact
      And.intro
        (fun leftAllows => denied (Or.inl leftAllows))
        (fun rightAllows => denied (Or.inr rightAllows))
  · intro denied allows
    cases allows with
    | inl leftAllows => exact denied.left leftAllows
    | inr rightAllows => exact denied.right rightAllows

theorem override_allows_local
    {Context : Type u}
    {parent localPolicy : PolicyObject Context}
    {overrides : Context -> Prop}
    {context : Context}
    (isOverride : overrides context)
    (localAllows : localPolicy.allows context) :
    (parent.overrideBy localPolicy overrides).allows context :=
  Or.inl (And.intro isOverride localAllows)

theorem override_allows_parent_fallback
    {Context : Type u}
    {parent localPolicy : PolicyObject Context}
    {overrides : Context -> Prop}
    {context : Context}
    (notOverride : ¬ overrides context)
    (parentAllows : parent.allows context) :
    (parent.overrideBy localPolicy overrides).allows context :=
  Or.inr (And.intro notOverride parentAllows)

theorem override_requires_local_when_overridden
    {Context : Type u}
    {parent localPolicy : PolicyObject Context}
    {overrides : Context -> Prop}
    {context : Context}
    (isOverride : overrides context)
    (allows : (parent.overrideBy localPolicy overrides).allows context) :
    localPolicy.allows context := by
  cases allows with
  | inl localCase => exact localCase.right
  | inr parentCase =>
      exact False.elim (parentCase.left isOverride)

theorem override_requires_parent_when_not_overridden
    {Context : Type u}
    {parent localPolicy : PolicyObject Context}
    {overrides : Context -> Prop}
    {context : Context}
    (notOverride : ¬ overrides context)
    (allows : (parent.overrideBy localPolicy overrides).allows context) :
    parent.allows context := by
  cases allows with
  | inl localCase =>
      exact False.elim (notOverride localCase.left)
  | inr parentCase => exact parentCase.right

theorem override_local_denial_blocks
    {Context : Type u}
    {parent localPolicy : PolicyObject Context}
    {overrides : Context -> Prop}
    {context : Context}
    (isOverride : overrides context)
    (localDenied : ¬ localPolicy.allows context) :
    ¬ (parent.overrideBy localPolicy overrides).allows context := by
  intro allows
  exact
    localDenied
      (override_requires_local_when_overridden
        isOverride
        allows)

theorem override_when_overridden_iff
    {Context : Type u}
    {parent localPolicy : PolicyObject Context}
    {overrides : Context -> Prop}
    {context : Context}
    (isOverride : overrides context) :
    (parent.overrideBy localPolicy overrides).allows context ↔
      localPolicy.allows context := by
  constructor
  · intro allows
    exact override_requires_local_when_overridden isOverride allows
  · intro localAllows
    exact override_allows_local isOverride localAllows

theorem override_when_not_overridden_iff
    {Context : Type u}
    {parent localPolicy : PolicyObject Context}
    {overrides : Context -> Prop}
    {context : Context}
    (notOverride : ¬ overrides context) :
    (parent.overrideBy localPolicy overrides).allows context ↔
      parent.allows context := by
  constructor
  · intro allows
    exact override_requires_parent_when_not_overridden notOverride allows
  · intro parentAllows
    exact override_allows_parent_fallback notOverride parentAllows

theorem override_denies_when_overridden_iff
    {Context : Type u}
    {parent localPolicy : PolicyObject Context}
    {overrides : Context -> Prop}
    {context : Context}
    (isOverride : overrides context) :
    ¬ (parent.overrideBy localPolicy overrides).allows context ↔
      ¬ localPolicy.allows context := by
  constructor
  · intro denied localAllows
    exact denied (override_allows_local isOverride localAllows)
  · intro localDenied
    exact override_local_denial_blocks isOverride localDenied

def flowSpecWithPolicyObject
    {Module Scope State Context : Type u}
    (spec : FlowSpec Module Scope State)
    (contextOf : State -> Module -> Context)
    (policy : PolicyObject Context) :
    FlowSpec Module Scope State :=
  { spec with
    policyAllows := fun state module =>
      policy.allows (contextOf state module) }

theorem can_start_requires_policy_object
    {Module Scope State Context : Type u}
    {spec : FlowSpec Module Scope State}
    {contextOf : State -> Module -> Context}
    {policy : PolicyObject Context}
    {state : State}
    {module : Module}
    (canStart :
      CanStart
        (flowSpecWithPolicyObject spec contextOf policy)
        state
        module) :
    policy.allows (contextOf state module) :=
  canStart.policyHolds

theorem can_start_with_policy_object_iff_startFrame_and_policy
    {Module Scope State Context : Type u}
    {spec : FlowSpec Module Scope State}
    {contextOf : State -> Module -> Context}
    {policy : PolicyObject Context}
    {state : State}
    {module : Module} :
    CanStart
        (flowSpecWithPolicyObject spec contextOf policy)
        state
        module ↔
      StartFrame spec state module ∧
        policy.allows (contextOf state module) := by
  constructor
  · intro canStart
    exact
      And.intro
        { depsCompleted := canStart.depsCompleted
          scopeAllowed := canStart.scopeAllowed
          preconditionHolds := canStart.preconditionHolds
          guardHolds := canStart.guardHolds }
        canStart.policyHolds
  · intro startFacts
    exact
      { depsCompleted := startFacts.left.depsCompleted
        scopeAllowed := startFacts.left.scopeAllowed
        policyHolds := startFacts.right
        preconditionHolds := startFacts.left.preconditionHolds
        guardHolds := startFacts.left.guardHolds }

theorem can_start_allOf_iff_startFrame_and_policies
    {Module Scope State Context : Type u}
    {spec : FlowSpec Module Scope State}
    {contextOf : State -> Module -> Context}
    {left right : PolicyObject Context}
    {state : State}
    {module : Module} :
    CanStart
        (flowSpecWithPolicyObject spec contextOf (left.allOf right))
        state
        module ↔
      StartFrame spec state module ∧
        left.allows (contextOf state module) ∧
        right.allows (contextOf state module) :=
  can_start_with_policy_object_iff_startFrame_and_policy

theorem can_start_anyOf_iff_startFrame_and_policy_branch
    {Module Scope State Context : Type u}
    {spec : FlowSpec Module Scope State}
    {contextOf : State -> Module -> Context}
    {left right : PolicyObject Context}
    {state : State}
    {module : Module} :
    CanStart
        (flowSpecWithPolicyObject spec contextOf (left.anyOf right))
        state
        module ↔
      StartFrame spec state module ∧
        (left.allows (contextOf state module) ∨
          right.allows (contextOf state module)) :=
  can_start_with_policy_object_iff_startFrame_and_policy

theorem can_start_override_iff_startFrame_and_policy_branch
    {Module Scope State Context : Type u}
    {spec : FlowSpec Module Scope State}
    {contextOf : State -> Module -> Context}
    {parent localPolicy : PolicyObject Context}
    {overrides : Context -> Prop}
    {state : State}
    {module : Module} :
    CanStart
        (flowSpecWithPolicyObject spec contextOf
          (parent.overrideBy localPolicy overrides))
        state
        module ↔
      StartFrame spec state module ∧
        ((overrides (contextOf state module) ∧
            localPolicy.allows (contextOf state module)) ∨
          (¬ overrides (contextOf state module) ∧
            parent.allows (contextOf state module))) :=
  can_start_with_policy_object_iff_startFrame_and_policy

theorem can_start_allOf_requires_policies
    {Module Scope State Context : Type u}
    {spec : FlowSpec Module Scope State}
    {contextOf : State -> Module -> Context}
    {left right : PolicyObject Context}
    {state : State}
    {module : Module}
    (canStart :
      CanStart
        (flowSpecWithPolicyObject spec contextOf (left.allOf right))
        state
        module) :
    left.allows (contextOf state module) ∧
    right.allows (contextOf state module) :=
  canStart.policyHolds

theorem can_start_override_requires_local_when_overridden
    {Module Scope State Context : Type u}
    {spec : FlowSpec Module Scope State}
    {contextOf : State -> Module -> Context}
    {parent localPolicy : PolicyObject Context}
    {overrides : Context -> Prop}
    {state : State}
    {module : Module}
    (isOverride : overrides (contextOf state module))
    (canStart :
      CanStart
        (flowSpecWithPolicyObject spec contextOf
          (parent.overrideBy localPolicy overrides))
        state
        module) :
    localPolicy.allows (contextOf state module) :=
  override_requires_local_when_overridden
    isOverride
    canStart.policyHolds

theorem can_start_override_requires_parent_when_not_overridden
    {Module Scope State Context : Type u}
    {spec : FlowSpec Module Scope State}
    {contextOf : State -> Module -> Context}
    {parent localPolicy : PolicyObject Context}
    {overrides : Context -> Prop}
    {state : State}
    {module : Module}
    (notOverride : ¬ overrides (contextOf state module))
    (canStart :
      CanStart
        (flowSpecWithPolicyObject spec contextOf
          (parent.overrideBy localPolicy overrides))
        state
        module) :
    parent.allows (contextOf state module) :=
  override_requires_parent_when_not_overridden
    notOverride
    canStart.policyHolds

theorem can_start_override_local_denial_blocks
    {Module Scope State Context : Type u}
    {spec : FlowSpec Module Scope State}
    {contextOf : State -> Module -> Context}
    {parent localPolicy : PolicyObject Context}
    {overrides : Context -> Prop}
    {state : State}
    {module : Module}
    (isOverride : overrides (contextOf state module))
    (localDenied : ¬ localPolicy.allows (contextOf state module)) :
    ¬ CanStart
      (flowSpecWithPolicyObject spec contextOf
        (parent.overrideBy localPolicy overrides))
      state
      module := by
  intro canStart
  exact
    localDenied
      (can_start_override_requires_local_when_overridden
        isOverride
        canStart)

abbrev UiPolicyContext :=
  UserInterface.UiState × UserInterface.UiModule

def uiPolicyContext
    (state : UserInterface.UiState)
    (module : UserInterface.UiModule) : UiPolicyContext :=
  (state, module)

def uiPolicyObject : PolicyObject UiPolicyContext :=
  { allows := fun context =>
      UserInterface.uiPolicyAllows context.1 context.2 }

theorem ui_policy_object_matches_spec
    {state : UserInterface.UiState}
    {module : UserInterface.UiModule} :
    uiPolicyObject.allows (uiPolicyContext state module) =
      UserInterface.uiPolicyAllows state module :=
  rfl

theorem ui_can_start_with_policy_object_requires_policy
    {state : UserInterface.UiState}
    {module : UserInterface.UiModule}
    (canStart :
      CanStart
        (flowSpecWithPolicyObject UserInterface.uiSpec
          uiPolicyContext
          uiPolicyObject)
        state
        module) :
    UserInterface.uiPolicyAllows state module :=
  canStart.policyHolds

theorem ui_can_start_with_policy_object_iff_startFrame_and_policy
    {state : UserInterface.UiState}
    {module : UserInterface.UiModule} :
    CanStart
        (flowSpecWithPolicyObject UserInterface.uiSpec
          uiPolicyContext
          uiPolicyObject)
        state
        module ↔
      StartFrame UserInterface.uiSpec state module ∧
        UserInterface.uiPolicyAllows state module :=
  can_start_with_policy_object_iff_startFrame_and_policy

theorem ui_benchmark_policy_object_requires_fixture
    {state : UserInterface.UiState}
    (canStart :
      CanStart
        (flowSpecWithPolicyObject UserInterface.uiSpec
          uiPolicyContext
          uiPolicyObject)
        state
        UserInterface.UiModule.scenarioBenchmark) :
    state.performanceFixtureBound :=
  canStart.policyHolds

theorem ui_benchmark_policy_object_start_iff
    {state : UserInterface.UiState} :
    CanStart
        (flowSpecWithPolicyObject UserInterface.uiSpec
          uiPolicyContext
          uiPolicyObject)
        state
        UserInterface.UiModule.scenarioBenchmark ↔
      StartFrame
        UserInterface.uiSpec
        state
        UserInterface.UiModule.scenarioBenchmark ∧
        state.performanceFixtureBound :=
  can_start_with_policy_object_iff_startFrame_and_policy

theorem ui_allOf_policy_can_start_requires_extra_policy
    (extraPolicy : PolicyObject UiPolicyContext)
    {state : UserInterface.UiState}
    {module : UserInterface.UiModule}
    (canStart :
      CanStart
        (flowSpecWithPolicyObject UserInterface.uiSpec
          uiPolicyContext
          (uiPolicyObject.allOf extraPolicy))
        state
        module) :
    UserInterface.uiPolicyAllows state module ∧
    extraPolicy.allows (uiPolicyContext state module) :=
  canStart.policyHolds

theorem ui_override_policy_local_denial_blocks_start
    (parent localPolicy : PolicyObject UiPolicyContext)
    (overrides : UiPolicyContext -> Prop)
    {state : UserInterface.UiState}
    {module : UserInterface.UiModule}
    (isOverride : overrides (uiPolicyContext state module))
    (localDenied :
      ¬ localPolicy.allows (uiPolicyContext state module)) :
    ¬ CanStart
      (flowSpecWithPolicyObject UserInterface.uiSpec
        uiPolicyContext
        (parent.overrideBy localPolicy overrides))
      state
      module :=
  can_start_override_local_denial_blocks
    isOverride
    localDenied

end AgenticAILabProof.PooC4.PolicyComposition
