-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.Semantics

namespace AgenticAILabProof.PooC4

structure StartFrame
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
  preconditionHolds : spec.precondition state module
  guardHolds : spec.guard state module

theorem canStart_iff_startFrame_and_policy
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    {state : State}
    {module : Module} :
    CanStart spec state module ↔
      StartFrame spec state module ∧ spec.policyAllows state module := by
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

theorem can_start_requires_completed_dependency
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    {state : State}
    {module dependency : Module}
    (canStart : CanStart spec state module)
    (depends : spec.dependsOn module dependency) :
    spec.completed state dependency :=
  canStart.depsCompleted dependency depends

theorem can_start_requires_scope_allowed
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    {state : State}
    {module : Module}
    (canStart : CanStart spec state module) :
    spec.scopeOrder.le (spec.moduleScope module) (spec.activeScope state) :=
  canStart.scopeAllowed

theorem can_start_requires_precondition
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    {state : State}
    {module : Module}
    (canStart : CanStart spec state module) :
    spec.precondition state module :=
  canStart.preconditionHolds

theorem can_start_requires_guard
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    {state : State}
    {module : Module}
    (canStart : CanStart spec state module) :
    spec.guard state module :=
  canStart.guardHolds

def flowSpecWithBranchSibling
    {Module Scope State : Type u}
    (spec : FlowSpec Module Scope State)
    (branchSibling : Module -> Module -> Prop) :
    FlowSpec Module Scope State :=
  { spec with branchSibling := branchSibling }

theorem can_start_ignores_branch_sibling
    {Module Scope State : Type u}
    {spec : FlowSpec Module Scope State}
    {branchSibling : Module -> Module -> Prop}
    {state : State}
    {module : Module} :
    CanStart (flowSpecWithBranchSibling spec branchSibling) state module ↔
      CanStart spec state module := by
  constructor
  · intro canStart
    exact
      { depsCompleted := canStart.depsCompleted
        scopeAllowed := canStart.scopeAllowed
        policyHolds := canStart.policyHolds
        preconditionHolds := canStart.preconditionHolds
        guardHolds := canStart.guardHolds }
  · intro canStart
    exact
      { depsCompleted := canStart.depsCompleted
        scopeAllowed := canStart.scopeAllowed
        policyHolds := canStart.policyHolds
        preconditionHolds := canStart.preconditionHolds
        guardHolds := canStart.guardHolds }

end AgenticAILabProof.PooC4
