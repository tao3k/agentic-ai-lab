-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.PooC4

structure ScopeOrder (Scope : Type u) where
  le : Scope -> Scope -> Prop
  refl : (scope : Scope) -> le scope scope
  trans : {a b c : Scope} -> le a b -> le b c -> le a c
  antisymm : {a b : Scope} -> le a b -> le b a -> a = b

structure FlowSpec
    (Module Scope State : Type u) where
  scopeOrder : ScopeOrder Scope
  moduleScope : Module -> Scope
  activeScope : State -> Scope
  dependsOn : Module -> Module -> Prop
  policyAllows : State -> Module -> Prop
  precondition : State -> Module -> Prop
  guard : State -> Module -> Prop
  branchSibling : Module -> Module -> Prop
  completed : State -> Module -> Prop

structure CanStart
    {Module Scope State : Type u}
    (spec : FlowSpec Module Scope State)
    (state : State)
    (module : Module) : Prop where
  depsCompleted :
    (dependency : Module) ->
    spec.dependsOn module dependency ->
    spec.completed state dependency
  scopeAllowed :
    spec.scopeOrder.le (spec.moduleScope module) (spec.activeScope state)
  policyHolds : spec.policyAllows state module
  preconditionHolds : spec.precondition state module
  guardHolds : spec.guard state module

def DependenciesCompleted
    {Module Scope State : Type u}
    (spec : FlowSpec Module Scope State)
    (state : State)
    (module : Module) : Prop :=
  (dependency : Module) ->
    spec.dependsOn module dependency ->
    spec.completed state dependency

def RequiredConditions
    {Module Scope State : Type u}
    (spec : FlowSpec Module Scope State)
    (state : State)
    (module : Module) : Prop :=
  DependenciesCompleted spec state module ∧
  spec.scopeOrder.le (spec.moduleScope module) (spec.activeScope state) ∧
  spec.policyAllows state module ∧
  spec.precondition state module ∧
  spec.guard state module

theorem required_conditions_of_can_start
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    {state : State}
    {module : Module}
    (canStart : CanStart spec state module) :
    RequiredConditions spec state module :=
  And.intro
    canStart.depsCompleted
    (And.intro
      canStart.scopeAllowed
      (And.intro
        canStart.policyHolds
        (And.intro
          canStart.preconditionHolds
          canStart.guardHolds)))

theorem can_start_of_required_conditions
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    {state : State}
    {module : Module}
    (required : RequiredConditions spec state module) :
    CanStart spec state module :=
  { depsCompleted := required.left
    scopeAllowed := required.right.left
    policyHolds := required.right.right.left
    preconditionHolds := required.right.right.right.left
    guardHolds := required.right.right.right.right }

theorem can_start_iff_required_conditions
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    {state : State}
    {module : Module} :
    CanStart spec state module ↔
      RequiredConditions spec state module :=
  Iff.intro
    required_conditions_of_can_start
    can_start_of_required_conditions

structure Step
    {Module Scope State : Type u}
    (spec : FlowSpec Module Scope State)
    (state : State) where
  module : Module
  next : State
  canStart : CanStart spec state module

inductive Trace
    {Module Scope State : Type u}
    (spec : FlowSpec Module Scope State) :
    State -> State -> Prop where
  | nil (state : State) : Trace spec state state
  | cons
      {state next final : State}
      (step : Step spec state)
      (rest : Trace spec step.next final) :
      Trace spec state final

theorem start_sound
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    {state : State}
    (step : Step spec state) :
    CanStart spec state step.module :=
  step.canStart

theorem deps_completed_of_can_start
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    {state : State}
    {module dependency : Module}
    (canStart : CanStart spec state module)
    (depends : spec.dependsOn module dependency) :
    spec.completed state dependency :=
  canStart.depsCompleted dependency depends

theorem scope_allowed_of_can_start
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    {state : State}
    {module : Module}
    (canStart : CanStart spec state module) :
    spec.scopeOrder.le (spec.moduleScope module) (spec.activeScope state) :=
  canStart.scopeAllowed

theorem scope_allowed_transitive
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    {state : State}
    {module : Module}
    {parentScope : Scope}
    (canStart : CanStart spec state module)
    (activeWithinParent :
      spec.scopeOrder.le (spec.activeScope state) parentScope) :
    spec.scopeOrder.le (spec.moduleScope module) parentScope :=
  spec.scopeOrder.trans canStart.scopeAllowed activeWithinParent

def BranchExclusiveAt
    {Module Scope State : Type u}
    (spec : FlowSpec Module Scope State)
    (state : State) : Prop :=
  {left right : Module} ->
    spec.branchSibling left right ->
    spec.guard state left ->
    spec.guard state right ->
    False

theorem no_sibling_branch_start
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    {state : State}
    {left right : Module}
    (exclusive : BranchExclusiveAt spec state)
    (sibling : spec.branchSibling left right)
    (leftStart : CanStart spec state left)
    (rightStart : CanStart spec state right) :
    False :=
  exclusive sibling leftStart.guardHolds rightStart.guardHolds

structure Strategy
    {Module Scope State : Type u}
    (spec : FlowSpec Module Scope State) where
  choose : (state : State) -> Option (Step spec state)

theorem strategy_choice_sound
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    (strategy : Strategy spec)
    {state : State}
    {step : Step spec state}
    (_selected : strategy.choose state = some step) :
    CanStart spec state step.module :=
  step.canStart

def AppearsBefore
    {Module : Type u}
    (order : List Module)
    (before after : Module) : Prop :=
  ∃ pre mid post,
    order = pre ++ before :: mid ++ after :: post

structure Linearization
    {Module Scope State : Type u}
    (spec : FlowSpec Module Scope State) where
  order : List Module
  dependencyOrder :
    {module dependency : Module} ->
    spec.dependsOn module dependency ->
    AppearsBefore order dependency module

theorem dependency_order_of_linearization
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    (linearization : Linearization spec)
    {module dependency : Module}
    (depends : spec.dependsOn module dependency) :
    AppearsBefore linearization.order dependency module :=
  linearization.dependencyOrder depends

structure DependencyRank
    {Module Scope State : Type u}
    (spec : FlowSpec Module Scope State) where
  rank : Module -> Nat
  decreases :
    {module dependency : Module} ->
    spec.dependsOn module dependency ->
    rank dependency < rank module

theorem no_self_dependency_of_rank
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    (dependencyRank : DependencyRank spec)
    {module : Module} :
    ¬ spec.dependsOn module module := by
  intro depends
  exact Nat.lt_irrefl (dependencyRank.rank module)
    (dependencyRank.decreases depends)

theorem no_two_cycle_of_rank
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    (dependencyRank : DependencyRank spec)
    {left right : Module}
    (leftDependsRight : spec.dependsOn left right)
    (rightDependsLeft : spec.dependsOn right left) :
    False :=
  Nat.lt_asymm
    (dependencyRank.decreases leftDependsRight)
    (dependencyRank.decreases rightDependsLeft)

def Preserves
    {Module Scope State : Type u}
    (spec : FlowSpec Module Scope State)
    (invariant : State -> Prop) : Prop :=
  {state : State} ->
    invariant state ->
    (step : Step spec state) ->
    invariant step.next

theorem trace_preserves
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    {invariant : State -> Prop}
    (preserves : Preserves spec invariant)
    {start final : State}
    (trace : Trace spec start final)
    (initial : invariant start) :
    invariant final := by
  induction trace with
  | nil state =>
      exact initial
  | cons step rest ih =>
      exact ih (preserves initial step)

end AgenticAILabProof.PooC4
