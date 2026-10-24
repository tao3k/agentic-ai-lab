-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Manifest

namespace AgenticAILabProof

def proofAbiVersion : UInt32 := 1
def proofAbiObligationSchemaVersion : UInt32 := 1
def tagWidthUInt32 : UInt32 := 32
def proofAbiObligationCount : UInt32 := 10
def proofAbiRequiredObligationMask : UInt32 := requiredObligationMask

def uiConfigWellFormedBit : UInt32 := 1
def uiProfilePolicyLinkedBit : UInt32 := 2
def loopStrategyPlanWellFormedBit : UInt32 := 4
def executionPolicyCapabilityBoundedBit : UInt32 := 8
def policyStrategyDeterministicBit : UInt32 := 16
def runtimeCommandInertBit : UInt32 := 32
def workflowAgreementLinkedBit : UInt32 := 64
def sandboxBoundaryLinkedBit : UInt32 := 128
def runtimeHandoffOwnerLinkedBit : UInt32 := 256
def proofCaseVectorCompleteBit : UInt32 := 512

def requiredObligationMaskFromBits : UInt32 :=
  uiConfigWellFormedBit |||
  uiProfilePolicyLinkedBit |||
  loopStrategyPlanWellFormedBit |||
  executionPolicyCapabilityBoundedBit |||
  policyStrategyDeterministicBit |||
  runtimeCommandInertBit |||
  workflowAgreementLinkedBit |||
  sandboxBoundaryLinkedBit |||
  runtimeHandoffOwnerLinkedBit |||
  proofCaseVectorCompleteBit

structure ProofAbiRaw where
  version : UInt32
  obligationSchemaVersion : UInt32
  requiredObligationMask : UInt32
  tagWidth : UInt32
  obligationCount : UInt32
deriving Repr, DecidableEq

def canonicalProofAbiRaw : ProofAbiRaw :=
  { version := proofAbiVersion
    obligationSchemaVersion := proofAbiObligationSchemaVersion
    requiredObligationMask := proofAbiRequiredObligationMask
    tagWidth := tagWidthUInt32
    obligationCount := proofAbiObligationCount }

def ProofAbiRaw.isCanonical (raw : ProofAbiRaw) : Bool :=
  (raw.version == proofAbiVersion) &&
  (raw.obligationSchemaVersion == proofAbiObligationSchemaVersion) &&
  (raw.requiredObligationMask == proofAbiRequiredObligationMask) &&
  (raw.tagWidth == tagWidthUInt32) &&
  (raw.obligationCount == proofAbiObligationCount)

def decodeProofAbi? (raw : ProofAbiRaw) : Option ProofAbi :=
  if raw.isCanonical then some canonicalProofAbi else none

theorem canonicalProofAbiRaw_decodes :
    decodeProofAbi? canonicalProofAbiRaw = some canonicalProofAbi := by
  native_decide

@[extern "agentic_ai_lab_proof_abi_version"]
opaque cAbiVersion : IO UInt32

@[extern "agentic_ai_lab_proof_obligation_schema_version"]
opaque cObligationSchemaVersion : IO UInt32

@[extern "agentic_ai_lab_proof_tag_width"]
opaque cTagWidth : IO UInt32

@[extern "agentic_ai_lab_proof_obligation_count"]
opaque cObligationCount : IO UInt32

@[extern "agentic_ai_lab_proof_required_obligation_mask"]
opaque cRequiredObligationMask : IO UInt32

@[extern "agentic_ai_lab_proof_ui_config_well_formed_bit"]
opaque cUiConfigWellFormedBit : IO UInt32

@[extern "agentic_ai_lab_proof_ui_profile_policy_linked_bit"]
opaque cUiProfilePolicyLinkedBit : IO UInt32

@[extern "agentic_ai_lab_proof_loop_strategy_plan_well_formed_bit"]
opaque cLoopStrategyPlanWellFormedBit : IO UInt32

@[extern "agentic_ai_lab_proof_execution_policy_capability_bounded_bit"]
opaque cExecutionPolicyCapabilityBoundedBit : IO UInt32

@[extern "agentic_ai_lab_proof_policy_strategy_deterministic_bit"]
opaque cPolicyStrategyDeterministicBit : IO UInt32

@[extern "agentic_ai_lab_proof_runtime_command_inert_bit"]
opaque cRuntimeCommandInertBit : IO UInt32

@[extern "agentic_ai_lab_proof_workflow_agreement_linked_bit"]
opaque cWorkflowAgreementLinkedBit : IO UInt32

@[extern "agentic_ai_lab_proof_sandbox_boundary_linked_bit"]
opaque cSandboxBoundaryLinkedBit : IO UInt32

@[extern "agentic_ai_lab_proof_runtime_handoff_owner_linked_bit"]
opaque cRuntimeHandoffOwnerLinkedBit : IO UInt32

@[extern "agentic_ai_lab_proof_proof_case_vector_complete_bit"]
opaque cProofCaseVectorCompleteBit : IO UInt32

def cProofAbiRaw : IO ProofAbiRaw := do
  pure
    { version := (← cAbiVersion)
      obligationSchemaVersion := (← cObligationSchemaVersion)
      requiredObligationMask := (← cRequiredObligationMask)
      tagWidth := (← cTagWidth)
      obligationCount := (← cObligationCount) }

def cMaskMatchesRequired : IO Bool := do
  pure ((← cRequiredObligationMask) == proofAbiRequiredObligationMask)

def cBridgeMatchesCanonical : IO Bool := do
  let raw ← cProofAbiRaw
  let uiConfigWellFormed ← cUiConfigWellFormedBit
  let uiProfilePolicyLinked ← cUiProfilePolicyLinkedBit
  let loopStrategyPlanWellFormed ← cLoopStrategyPlanWellFormedBit
  let executionPolicyCapabilityBounded ← cExecutionPolicyCapabilityBoundedBit
  let policyStrategyDeterministic ← cPolicyStrategyDeterministicBit
  let runtimeCommandInert ← cRuntimeCommandInertBit
  let workflowAgreementLinked ← cWorkflowAgreementLinkedBit
  let sandboxBoundaryLinked ← cSandboxBoundaryLinkedBit
  let runtimeHandoffOwnerLinked ← cRuntimeHandoffOwnerLinkedBit
  let proofCaseVectorComplete ← cProofCaseVectorCompleteBit
  pure
    ((decodeProofAbi? raw == some canonicalProofAbi) &&
     (uiConfigWellFormed == uiConfigWellFormedBit) &&
     (uiProfilePolicyLinked == uiProfilePolicyLinkedBit) &&
     (loopStrategyPlanWellFormed == loopStrategyPlanWellFormedBit) &&
     (executionPolicyCapabilityBounded ==
      executionPolicyCapabilityBoundedBit) &&
     (policyStrategyDeterministic == policyStrategyDeterministicBit) &&
     (runtimeCommandInert == runtimeCommandInertBit) &&
     (workflowAgreementLinked == workflowAgreementLinkedBit) &&
     (sandboxBoundaryLinked == sandboxBoundaryLinkedBit) &&
     (runtimeHandoffOwnerLinked == runtimeHandoffOwnerLinkedBit) &&
     (proofCaseVectorComplete == proofCaseVectorCompleteBit) &&
     (requiredObligationMaskFromBits == proofAbiRequiredObligationMask))

def obligationNamesFromMask (mask : UInt32) : List ObligationName :=
  let addIf (bit : UInt32) (name : ObligationName) (names : List ObligationName) :=
    if mask &&& bit == bit then name :: names else names
  []
    |> addIf proofCaseVectorCompleteBit ObligationName.proofCaseVectorComplete
    |> addIf runtimeHandoffOwnerLinkedBit ObligationName.runtimeHandoffOwnerLinked
    |> addIf sandboxBoundaryLinkedBit ObligationName.sandboxBoundaryLinked
    |> addIf workflowAgreementLinkedBit ObligationName.workflowAgreementLinked
    |> addIf runtimeCommandInertBit ObligationName.runtimeCommandInert
    |> addIf policyStrategyDeterministicBit ObligationName.policyStrategyDeterministic
    |> addIf executionPolicyCapabilityBoundedBit ObligationName.executionPolicyCapabilityBounded
    |> addIf loopStrategyPlanWellFormedBit ObligationName.loopStrategyPlanWellFormed
    |> addIf uiProfilePolicyLinkedBit ObligationName.uiProfilePolicyLinked
    |> addIf uiConfigWellFormedBit ObligationName.uiConfigWellFormed

theorem requiredObligationMask_decodes_required_names :
    obligationNamesFromMask requiredObligationMask = requiredObligationNames := by
  native_decide

theorem requiredObligationMaskFromBits_matches_manifest_mask :
    requiredObligationMaskFromBits = proofAbiRequiredObligationMask := by
  native_decide

end AgenticAILabProof
