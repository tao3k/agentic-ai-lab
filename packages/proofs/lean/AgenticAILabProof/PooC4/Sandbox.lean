-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.NatScope

namespace AgenticAILabProof.PooC4.Sandbox

open AgenticAILabProof.PooC4

inductive SandboxModule where
  | profile
  | toolPolicy
  | resourcePolicy
  | capabilityPolicy
  | executionGrant
deriving Repr, DecidableEq

abbrev SandboxScope := Nat

def profileScope : SandboxScope := 1
def policyScope : SandboxScope := 2
def executionScope : SandboxScope := 3

structure SandboxState where
  activeScope : SandboxScope
  profileDeclared : Prop
  toolPolicyDeclared : Prop
  resourcePolicyDeclared : Prop
  capabilityPolicyDeclared : Prop
  executionGrantIssued : Prop

inductive SandboxFact where
  | profileDeclared
  | toolPolicyDeclared
  | resourcePolicyDeclared
  | capabilityPolicyDeclared
  | executionGrantIssued
deriving Repr, DecidableEq

abbrev SandboxFactEnv := SandboxFact -> Prop

def sandboxStateOfFacts
    (activeScope : SandboxScope)
    (facts : SandboxFactEnv) :
    SandboxState :=
  { activeScope := activeScope
    profileDeclared := facts SandboxFact.profileDeclared
    toolPolicyDeclared := facts SandboxFact.toolPolicyDeclared
    resourcePolicyDeclared := facts SandboxFact.resourcePolicyDeclared
    capabilityPolicyDeclared := facts SandboxFact.capabilityPolicyDeclared
    executionGrantIssued := facts SandboxFact.executionGrantIssued }

inductive SandboxDependsOn : SandboxModule -> SandboxModule -> Prop where
  | toolProfile :
      SandboxDependsOn SandboxModule.toolPolicy SandboxModule.profile
  | resourceProfile :
      SandboxDependsOn SandboxModule.resourcePolicy SandboxModule.profile
  | capabilityProfile :
      SandboxDependsOn SandboxModule.capabilityPolicy SandboxModule.profile
  | executionTool :
      SandboxDependsOn SandboxModule.executionGrant SandboxModule.toolPolicy
  | executionResource :
      SandboxDependsOn SandboxModule.executionGrant SandboxModule.resourcePolicy
  | executionCapability :
      SandboxDependsOn SandboxModule.executionGrant SandboxModule.capabilityPolicy

def sandboxModuleScope : SandboxModule -> SandboxScope
  | SandboxModule.profile => profileScope
  | SandboxModule.toolPolicy => policyScope
  | SandboxModule.resourcePolicy => policyScope
  | SandboxModule.capabilityPolicy => policyScope
  | SandboxModule.executionGrant => executionScope

def sandboxCompleted (state : SandboxState) : SandboxModule -> Prop
  | SandboxModule.profile => state.profileDeclared
  | SandboxModule.toolPolicy => state.toolPolicyDeclared
  | SandboxModule.resourcePolicy => state.resourcePolicyDeclared
  | SandboxModule.capabilityPolicy => state.capabilityPolicyDeclared
  | SandboxModule.executionGrant => state.executionGrantIssued

def sandboxPrecondition (state : SandboxState) : SandboxModule -> Prop
  | SandboxModule.profile => True
  | SandboxModule.toolPolicy => state.profileDeclared
  | SandboxModule.resourcePolicy => state.profileDeclared
  | SandboxModule.capabilityPolicy => state.profileDeclared
  | SandboxModule.executionGrant =>
      state.toolPolicyDeclared ∧
      state.resourcePolicyDeclared ∧
      state.capabilityPolicyDeclared

def sandboxSpec : FlowSpec SandboxModule SandboxScope SandboxState :=
  { scopeOrder := natScopeOrder
    moduleScope := sandboxModuleScope
    activeScope := SandboxState.activeScope
    dependsOn := SandboxDependsOn
    policyAllows := fun _ _ => True
    precondition := sandboxPrecondition
    guard := fun _ _ => True
    branchSibling := fun _ _ => False
    completed := sandboxCompleted }

theorem execution_grant_requires_tool_policy
    {state : SandboxState}
    (canStart : CanStart sandboxSpec state SandboxModule.executionGrant) :
    state.toolPolicyDeclared :=
  deps_completed_of_can_start canStart SandboxDependsOn.executionTool

theorem execution_grant_requires_resource_policy
    {state : SandboxState}
    (canStart : CanStart sandboxSpec state SandboxModule.executionGrant) :
    state.resourcePolicyDeclared :=
  deps_completed_of_can_start canStart SandboxDependsOn.executionResource

theorem execution_grant_requires_capability_policy
    {state : SandboxState}
    (canStart : CanStart sandboxSpec state SandboxModule.executionGrant) :
    state.capabilityPolicyDeclared :=
  deps_completed_of_can_start canStart SandboxDependsOn.executionCapability

theorem execution_grant_blocks_without_tool_policy
    {state : SandboxState}
    (missingToolPolicy : ¬ state.toolPolicyDeclared) :
    ¬ CanStart sandboxSpec state SandboxModule.executionGrant := by
  intro canStart
  exact missingToolPolicy (execution_grant_requires_tool_policy canStart)

theorem execution_grant_blocks_without_resource_policy
    {state : SandboxState}
    (missingResourcePolicy : ¬ state.resourcePolicyDeclared) :
    ¬ CanStart sandboxSpec state SandboxModule.executionGrant := by
  intro canStart
  exact missingResourcePolicy
    (execution_grant_requires_resource_policy canStart)

theorem execution_grant_blocks_without_capability_policy
    {state : SandboxState}
    (missingCapabilityPolicy : ¬ state.capabilityPolicyDeclared) :
    ¬ CanStart sandboxSpec state SandboxModule.executionGrant := by
  intro canStart
  exact missingCapabilityPolicy
    (execution_grant_requires_capability_policy canStart)

end AgenticAILabProof.PooC4.Sandbox
