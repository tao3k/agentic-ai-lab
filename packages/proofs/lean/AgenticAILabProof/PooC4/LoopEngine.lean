-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.Semantics

namespace AgenticAILabProof.PooC4.LoopEngine

open AgenticAILabProof.PooC4

inductive LoopModule where
  | readProfile
  | resolvePolicy
  | chooseStrategy
  | cacheHitBranch
  | cacheMissBranch
  | prepareWorkflow
  | enforceSandbox
  | runtimeHandoff
deriving Repr, DecidableEq

abbrev LoopScope := Nat

def uiScope : LoopScope := 0
def profileScope : LoopScope := 1
def policyScope : LoopScope := 2
def strategyScope : LoopScope := 3
def workflowScope : LoopScope := 4
def sandboxScope : LoopScope := 5
def runtimeScope : LoopScope := 6

def loopScopeOrder : ScopeOrder LoopScope :=
  { le := Nat.le
    refl := Nat.le_refl
    trans := fun first second => Nat.le_trans first second
    antisymm := fun first second => Nat.le_antisymm first second }

structure LoopState where
  activeScope : LoopScope
  profileDone : Prop
  policyDone : Prop
  strategyDone : Prop
  cacheHit : Prop
  cacheMiss : Prop
  workflowDone : Prop
  sandboxDone : Prop

inductive LoopDependsOn : LoopModule -> LoopModule -> Prop where
  | policyProfile :
      LoopDependsOn LoopModule.resolvePolicy LoopModule.readProfile
  | strategyPolicy :
      LoopDependsOn LoopModule.chooseStrategy LoopModule.resolvePolicy
  | cacheHitStrategy :
      LoopDependsOn LoopModule.cacheHitBranch LoopModule.chooseStrategy
  | cacheMissStrategy :
      LoopDependsOn LoopModule.cacheMissBranch LoopModule.chooseStrategy
  | workflowStrategy :
      LoopDependsOn LoopModule.prepareWorkflow LoopModule.chooseStrategy
  | sandboxWorkflow :
      LoopDependsOn LoopModule.enforceSandbox LoopModule.prepareWorkflow
  | runtimeSandbox :
      LoopDependsOn LoopModule.runtimeHandoff LoopModule.enforceSandbox

inductive LoopBranchSibling : LoopModule -> LoopModule -> Prop where
  | hitMiss :
      LoopBranchSibling LoopModule.cacheHitBranch LoopModule.cacheMissBranch
  | missHit :
      LoopBranchSibling LoopModule.cacheMissBranch LoopModule.cacheHitBranch

def loopModuleScope : LoopModule -> LoopScope
  | LoopModule.readProfile => profileScope
  | LoopModule.resolvePolicy => policyScope
  | LoopModule.chooseStrategy => strategyScope
  | LoopModule.cacheHitBranch => strategyScope
  | LoopModule.cacheMissBranch => strategyScope
  | LoopModule.prepareWorkflow => workflowScope
  | LoopModule.enforceSandbox => sandboxScope
  | LoopModule.runtimeHandoff => runtimeScope

def loopCompleted (state : LoopState) : LoopModule -> Prop
  | LoopModule.readProfile => state.profileDone
  | LoopModule.resolvePolicy => state.policyDone
  | LoopModule.chooseStrategy => state.strategyDone
  | LoopModule.cacheHitBranch => state.cacheHit
  | LoopModule.cacheMissBranch => state.cacheMiss
  | LoopModule.prepareWorkflow => state.workflowDone
  | LoopModule.enforceSandbox => state.sandboxDone
  | LoopModule.runtimeHandoff => False

def loopPolicyAllows (state : LoopState) : LoopModule -> Prop
  | LoopModule.readProfile => True
  | LoopModule.resolvePolicy => state.profileDone
  | LoopModule.chooseStrategy => state.policyDone
  | LoopModule.cacheHitBranch => state.strategyDone
  | LoopModule.cacheMissBranch => state.strategyDone
  | LoopModule.prepareWorkflow => state.strategyDone
  | LoopModule.enforceSandbox => state.workflowDone
  | LoopModule.runtimeHandoff => state.sandboxDone

def loopPrecondition (state : LoopState) : LoopModule -> Prop
  | LoopModule.readProfile => True
  | LoopModule.resolvePolicy => state.profileDone
  | LoopModule.chooseStrategy => state.policyDone
  | LoopModule.cacheHitBranch => state.strategyDone ∧ state.cacheHit
  | LoopModule.cacheMissBranch => state.strategyDone ∧ state.cacheMiss
  | LoopModule.prepareWorkflow => state.strategyDone
  | LoopModule.enforceSandbox => state.workflowDone
  | LoopModule.runtimeHandoff => state.sandboxDone

def loopGuard (state : LoopState) : LoopModule -> Prop
  | LoopModule.cacheHitBranch => state.cacheHit
  | LoopModule.cacheMissBranch => state.cacheMiss
  | _ => True

def loopSpec : FlowSpec LoopModule LoopScope LoopState :=
  { scopeOrder := loopScopeOrder
    moduleScope := loopModuleScope
    activeScope := LoopState.activeScope
    dependsOn := LoopDependsOn
    policyAllows := loopPolicyAllows
    precondition := loopPrecondition
    guard := loopGuard
    branchSibling := LoopBranchSibling
    completed := loopCompleted }

structure LoopStateConsistent (state : LoopState) : Prop where
  policyAfterProfile : state.policyDone -> state.profileDone
  strategyAfterPolicy : state.strategyDone -> state.policyDone
  workflowAfterStrategy : state.workflowDone -> state.strategyDone
  sandboxAfterWorkflow : state.sandboxDone -> state.workflowDone
  cacheExclusive : state.cacheHit -> state.cacheMiss -> False

def loopRank : LoopModule -> Nat
  | LoopModule.readProfile => 0
  | LoopModule.resolvePolicy => 1
  | LoopModule.chooseStrategy => 2
  | LoopModule.cacheHitBranch => 3
  | LoopModule.cacheMissBranch => 3
  | LoopModule.prepareWorkflow => 4
  | LoopModule.enforceSandbox => 5
  | LoopModule.runtimeHandoff => 6

def loopDependencyRank : DependencyRank loopSpec :=
  { rank := loopRank
    decreases := by
      intro module dependency depends
      cases depends <;> native_decide }

theorem loop_no_self_dependency
    {module : LoopModule} :
    ¬ loopSpec.dependsOn module module :=
  no_self_dependency_of_rank loopDependencyRank

theorem loop_no_two_dependency_cycle
    {left right : LoopModule}
    (leftDependsRight : loopSpec.dependsOn left right)
    (rightDependsLeft : loopSpec.dependsOn right left) :
    False :=
  no_two_cycle_of_rank
    loopDependencyRank
    leftDependsRight
    rightDependsLeft

theorem resolve_policy_requires_profile
    {state : LoopState}
    (canStart :
      CanStart loopSpec state LoopModule.resolvePolicy) :
    state.profileDone :=
  deps_completed_of_can_start canStart LoopDependsOn.policyProfile

theorem choose_strategy_requires_policy
    {state : LoopState}
    (canStart :
      CanStart loopSpec state LoopModule.chooseStrategy) :
    loopCompleted state LoopModule.resolvePolicy :=
  deps_completed_of_can_start canStart LoopDependsOn.strategyPolicy

theorem cache_hit_requires_strategy_and_hit
    {state : LoopState}
    (canStart :
      CanStart loopSpec state LoopModule.cacheHitBranch) :
    state.strategyDone ∧ state.cacheHit :=
  canStart.preconditionHolds

theorem cache_miss_requires_strategy_and_miss
    {state : LoopState}
    (canStart :
      CanStart loopSpec state LoopModule.cacheMissBranch) :
    state.strategyDone ∧ state.cacheMiss :=
  canStart.preconditionHolds

theorem prepare_workflow_requires_strategy
    {state : LoopState}
    (canStart :
      CanStart loopSpec state LoopModule.prepareWorkflow) :
    state.strategyDone :=
  deps_completed_of_can_start canStart LoopDependsOn.workflowStrategy

theorem enforce_sandbox_requires_workflow
    {state : LoopState}
    (canStart :
      CanStart loopSpec state LoopModule.enforceSandbox) :
    state.workflowDone :=
  deps_completed_of_can_start canStart LoopDependsOn.sandboxWorkflow

theorem runtime_handoff_requires_sandbox
    {state : LoopState}
    (canStart :
      CanStart loopSpec state LoopModule.runtimeHandoff) :
    loopCompleted state LoopModule.enforceSandbox :=
  deps_completed_of_can_start canStart LoopDependsOn.runtimeSandbox

theorem runtime_handoff_scope_allowed
    {state : LoopState}
    (canStart :
      CanStart loopSpec state LoopModule.runtimeHandoff) :
    runtimeScope <= state.activeScope :=
  canStart.scopeAllowed

theorem runtime_handoff_required_conditions
    {state : LoopState}
    (canStart :
      CanStart loopSpec state LoopModule.runtimeHandoff) :
    RequiredConditions loopSpec state LoopModule.runtimeHandoff :=
  required_conditions_of_can_start canStart

theorem runtime_handoff_requires_full_chain
    {state : LoopState}
    (consistent : LoopStateConsistent state)
    (canStart :
      CanStart loopSpec state LoopModule.runtimeHandoff) :
    state.profileDone ∧
    state.policyDone ∧
    state.strategyDone ∧
    state.workflowDone ∧
    state.sandboxDone := by
  let sandboxDone := runtime_handoff_requires_sandbox canStart
  let workflowDone := consistent.sandboxAfterWorkflow sandboxDone
  let strategyDone := consistent.workflowAfterStrategy workflowDone
  let policyDone := consistent.strategyAfterPolicy strategyDone
  let profileDone := consistent.policyAfterProfile policyDone
  exact
    And.intro profileDone
      (And.intro policyDone
        (And.intro strategyDone
          (And.intro workflowDone sandboxDone)))

def afterStrategyCacheHit : LoopState :=
  { activeScope := runtimeScope
    profileDone := True
    policyDone := True
    strategyDone := True
    cacheHit := True
    cacheMiss := False
    workflowDone := False
    sandboxDone := False }

def cacheHitCanStart :
    CanStart loopSpec afterStrategyCacheHit LoopModule.cacheHitBranch :=
  { depsCompleted := by
      intro dependency depends
      cases depends
      exact True.intro
    scopeAllowed := by
      change 3 <= 6
      exact
        Nat.succ_le_succ
          (Nat.succ_le_succ
            (Nat.succ_le_succ (Nat.zero_le 3)))
    policyHolds := True.intro
    preconditionHolds := And.intro True.intro True.intro
    guardHolds := True.intro }

theorem cache_miss_guard_false :
    ¬ loopGuard afterStrategyCacheHit LoopModule.cacheMissBranch := by
  intro guard
  exact guard

theorem cache_branch_exclusive_at_after_strategy :
    BranchExclusiveAt loopSpec afterStrategyCacheHit := by
  intro left right sibling leftGuard rightGuard
  cases sibling
  · exact rightGuard
  · exact leftGuard

theorem cache_branch_exclusive_of_consistent
    {state : LoopState}
    (consistent : LoopStateConsistent state) :
    BranchExclusiveAt loopSpec state := by
  intro left right sibling leftGuard rightGuard
  cases sibling
  · exact consistent.cacheExclusive leftGuard rightGuard
  · exact consistent.cacheExclusive rightGuard leftGuard

theorem cache_hit_and_cache_miss_cannot_both_start
    (hitStart :
      CanStart loopSpec afterStrategyCacheHit LoopModule.cacheHitBranch)
    (missStart :
      CanStart loopSpec afterStrategyCacheHit LoopModule.cacheMissBranch) :
    False :=
  no_sibling_branch_start
    cache_branch_exclusive_at_after_strategy
    LoopBranchSibling.hitMiss
    hitStart
    missStart

theorem cache_hit_and_cache_miss_cannot_both_start_of_consistent
    {state : LoopState}
    (consistent : LoopStateConsistent state)
    (hitStart : CanStart loopSpec state LoopModule.cacheHitBranch)
    (missStart : CanStart loopSpec state LoopModule.cacheMissBranch) :
    False :=
  no_sibling_branch_start
    (cache_branch_exclusive_of_consistent consistent)
    LoopBranchSibling.hitMiss
    hitStart
    missStart

def loopLinearization : Linearization loopSpec :=
  { order :=
      [ LoopModule.readProfile
      , LoopModule.resolvePolicy
      , LoopModule.chooseStrategy
      , LoopModule.cacheHitBranch
      , LoopModule.cacheMissBranch
      , LoopModule.prepareWorkflow
      , LoopModule.enforceSandbox
      , LoopModule.runtimeHandoff
      ]
    dependencyOrder := by
      intro module dependency depends
      cases depends
      · exact ⟨[], [], [ LoopModule.chooseStrategy
                       , LoopModule.cacheHitBranch
                       , LoopModule.cacheMissBranch
                       , LoopModule.prepareWorkflow
                       , LoopModule.enforceSandbox
                       , LoopModule.runtimeHandoff
                       ], rfl⟩
      · exact ⟨[LoopModule.readProfile], [], [ LoopModule.cacheHitBranch
                                             , LoopModule.cacheMissBranch
                                             , LoopModule.prepareWorkflow
                                             , LoopModule.enforceSandbox
                                             , LoopModule.runtimeHandoff
                                             ], rfl⟩
      · exact ⟨[ LoopModule.readProfile
                , LoopModule.resolvePolicy
                ], [], [ LoopModule.cacheMissBranch
                       , LoopModule.prepareWorkflow
                       , LoopModule.enforceSandbox
                       , LoopModule.runtimeHandoff
                       ], rfl⟩
      · exact ⟨[ LoopModule.readProfile
                , LoopModule.resolvePolicy
                ], [LoopModule.cacheHitBranch], [ LoopModule.prepareWorkflow
                                                , LoopModule.enforceSandbox
                                                , LoopModule.runtimeHandoff
                                                ], rfl⟩
      · exact ⟨[ LoopModule.readProfile
                , LoopModule.resolvePolicy
                ], [ LoopModule.cacheHitBranch
                   , LoopModule.cacheMissBranch
                   ], [ LoopModule.enforceSandbox
                      , LoopModule.runtimeHandoff
                      ], rfl⟩
      · exact ⟨[ LoopModule.readProfile
                , LoopModule.resolvePolicy
                , LoopModule.chooseStrategy
                , LoopModule.cacheHitBranch
                , LoopModule.cacheMissBranch
                ], [], [LoopModule.runtimeHandoff], rfl⟩
      · exact ⟨[ LoopModule.readProfile
                , LoopModule.resolvePolicy
                , LoopModule.chooseStrategy
                , LoopModule.cacheHitBranch
                , LoopModule.cacheMissBranch
                , LoopModule.prepareWorkflow
                ], [], [], rfl⟩ }

theorem loop_dependency_order
    {module dependency : LoopModule}
    (depends : loopSpec.dependsOn module dependency) :
    AppearsBefore loopLinearization.order dependency module :=
  dependency_order_of_linearization loopLinearization depends

end AgenticAILabProof.PooC4.LoopEngine
