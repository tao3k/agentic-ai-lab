-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.NatScope

namespace AgenticAILabProof.PooC4.FunctionalFlow

open AgenticAILabProof.PooC4

inductive FlowModule where
  | input
  | transform
  | validation
  | runtimeHandoff
  | receipt
deriving Repr, DecidableEq

abbrev FlowScope := Nat

def inputScope : FlowScope := 1
def transformScope : FlowScope := 2
def validationScope : FlowScope := 3
def handoffScope : FlowScope := 4
def receiptScope : FlowScope := 5

structure FlowState where
  activeScope : FlowScope
  inputPresent : Prop
  transformPure : Prop
  validationPassed : Prop
  runtimeHandoffReady : Prop
  receiptProduced : Prop

inductive FlowFact where
  | inputPresent
  | transformPure
  | validationPassed
  | runtimeHandoffReady
  | receiptProduced
deriving Repr, DecidableEq

abbrev FlowFactEnv := FlowFact -> Prop

def flowStateOfFacts
    (activeScope : FlowScope)
    (facts : FlowFactEnv) :
    FlowState :=
  { activeScope := activeScope
    inputPresent := facts FlowFact.inputPresent
    transformPure := facts FlowFact.transformPure
    validationPassed := facts FlowFact.validationPassed
    runtimeHandoffReady := facts FlowFact.runtimeHandoffReady
    receiptProduced := facts FlowFact.receiptProduced }

inductive FlowDependsOn : FlowModule -> FlowModule -> Prop where
  | transformInput :
      FlowDependsOn FlowModule.transform FlowModule.input
  | validationTransform :
      FlowDependsOn FlowModule.validation FlowModule.transform
  | handoffValidation :
      FlowDependsOn FlowModule.runtimeHandoff FlowModule.validation
  | receiptHandoff :
      FlowDependsOn FlowModule.receipt FlowModule.runtimeHandoff

def flowModuleScope : FlowModule -> FlowScope
  | FlowModule.input => inputScope
  | FlowModule.transform => transformScope
  | FlowModule.validation => validationScope
  | FlowModule.runtimeHandoff => handoffScope
  | FlowModule.receipt => receiptScope

def flowCompleted (state : FlowState) : FlowModule -> Prop
  | FlowModule.input => state.inputPresent
  | FlowModule.transform => state.transformPure
  | FlowModule.validation => state.validationPassed
  | FlowModule.runtimeHandoff => state.runtimeHandoffReady
  | FlowModule.receipt => state.receiptProduced

def flowPrecondition (state : FlowState) : FlowModule -> Prop
  | FlowModule.input => True
  | FlowModule.transform => state.inputPresent
  | FlowModule.validation => state.transformPure
  | FlowModule.runtimeHandoff => state.validationPassed
  | FlowModule.receipt => state.runtimeHandoffReady

def flowSpec : FlowSpec FlowModule FlowScope FlowState :=
  { scopeOrder := natScopeOrder
    moduleScope := flowModuleScope
    activeScope := FlowState.activeScope
    dependsOn := FlowDependsOn
    policyAllows := fun _ _ => True
    precondition := flowPrecondition
    guard := fun _ _ => True
    branchSibling := fun _ _ => False
    completed := flowCompleted }

theorem transform_requires_input
    {state : FlowState}
    (canStart : CanStart flowSpec state FlowModule.transform) :
    state.inputPresent :=
  deps_completed_of_can_start canStart FlowDependsOn.transformInput

theorem validation_requires_pure_transform
    {state : FlowState}
    (canStart : CanStart flowSpec state FlowModule.validation) :
    state.transformPure :=
  deps_completed_of_can_start canStart FlowDependsOn.validationTransform

theorem handoff_requires_validation
    {state : FlowState}
    (canStart : CanStart flowSpec state FlowModule.runtimeHandoff) :
    state.validationPassed :=
  deps_completed_of_can_start canStart FlowDependsOn.handoffValidation

theorem receipt_requires_handoff
    {state : FlowState}
    (canStart : CanStart flowSpec state FlowModule.receipt) :
    state.runtimeHandoffReady :=
  deps_completed_of_can_start canStart FlowDependsOn.receiptHandoff

theorem transform_blocks_without_input
    {state : FlowState}
    (missingInput : ¬ state.inputPresent) :
    ¬ CanStart flowSpec state FlowModule.transform := by
  intro canStart
  exact missingInput (transform_requires_input canStart)

theorem validation_blocks_without_pure_transform
    {state : FlowState}
    (missingPureTransform : ¬ state.transformPure) :
    ¬ CanStart flowSpec state FlowModule.validation := by
  intro canStart
  exact missingPureTransform (validation_requires_pure_transform canStart)

theorem handoff_blocks_without_validation
    {state : FlowState}
    (missingValidation : ¬ state.validationPassed) :
    ¬ CanStart flowSpec state FlowModule.runtimeHandoff := by
  intro canStart
  exact missingValidation (handoff_requires_validation canStart)

theorem receipt_blocks_without_handoff
    {state : FlowState}
    (missingHandoff : ¬ state.runtimeHandoffReady) :
    ¬ CanStart flowSpec state FlowModule.receipt := by
  intro canStart
  exact missingHandoff (receipt_requires_handoff canStart)

end AgenticAILabProof.PooC4.FunctionalFlow
