-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Examples
import AgenticAILabProof.UiCase

namespace AgenticAILabProof.Generated.LoopEngine

open AgenticAILabProof

def generatedObligations : List Obligation :=
  requiredObligations

def generatedUiProofCase : UiLoopProofCase :=
  { requestId := "loop-engine/current-system-build-loop/request"
    artifactHandle := "loop-engine/current-system-build-loop/artifact"
    profile := UiProfileRef.currentSystemBuildLoop
    policy := UiPolicyRef.currentSystemBuildPolicy
    strategy := UiStrategyRef.deterministicLoopStrategy
    profilePolicyProfile := UiProfileRef.currentSystemBuildLoop
    profilePolicyPolicy := UiPolicyRef.currentSystemBuildPolicy
    strategyProfile := UiProfileRef.currentSystemBuildLoop
    strategyPolicy := UiPolicyRef.currentSystemBuildPolicy
    strategyOwner := RuntimeOwner.marlinAgentCore
    strategyContract :=
      RuntimeCommandContract.loopGovernorRuntimeCommandManifestV1
    allowedCapabilities :=
      [ RuntimeCapability.projectRead
      , RuntimeCapability.artifactWrite
      , RuntimeCapability.cacheRead
      , RuntimeCapability.cacheWrite
      ]
    requestedCapabilities :=
      [ RuntimeCapability.projectRead
      , RuntimeCapability.artifactWrite
      , RuntimeCapability.cacheRead
      ]
    precedence := PolicyStrategyPrecedence.profilePolicyStrategy
    workflowAgreement := UiWorkflowAgreementRef.runtimeEnvelopeAgreement
    sandboxAgreement := UiSandboxAgreementRef.sandboxHandoffAgreement
    proofScope := requiredProofScopes
    objectFamilies := [ObjectFamily.agentProfile, ObjectFamily.runtimeSnapshot]
    receiptContracts := [ReceiptContract.lineageReceiptV1]
    runtimePacketContracts := [RuntimePacketContract.actionPacketV1]
    cAbi := canonicalProofAbi
    obligations := generatedObligations
    evidenceFields := requiredUiCaseEvidenceFields
    runtimeExecution := RuntimeExecution.inert }

def generatedManifest : ProofManifest :=
  generatedUiProofCase.toManifest

theorem generatedManifest_runtime_inert :
    generatedManifest.runtimeExecution = RuntimeExecution.inert :=
  ProofManifest.runtime_inert_by_type generatedManifest

theorem generatedManifest_has_required_obligations :
    generatedManifest.hasAllRequiredObligations = true := by
  native_decide

theorem generatedManifest_has_required_scopes :
    generatedManifest.hasAllRequiredProofScopes = true := by
  native_decide

theorem generatedManifest_obligations_runtime_inert :
    generatedManifest.allObligationsRuntimeInert = true := by
  native_decide

theorem generatedManifest_valid : generatedManifest.Valid where
  abiMatches := by native_decide
  hasRequiredObligations := generatedManifest_has_required_obligations
  hasRequiredProofScopes := generatedManifest_has_required_scopes
  obligationsRuntimeInert := generatedManifest_obligations_runtime_inert

theorem generatedManifest_proof_case_vector_complete :
    generatedManifest.proofCaseVectorComplete = true :=
  ProofManifest.proof_case_vector_complete_of_valid generatedManifest_valid

theorem generatedUiProofCase_profile_policy_linked :
    generatedUiProofCase.profilePolicyLinked = true := by
  native_decide

theorem generatedUiProofCase_strategy_linked :
    generatedUiProofCase.strategyLinked = true := by
  native_decide

theorem generatedUiProofCase_capabilities_bounded :
    generatedUiProofCase.capabilitiesBounded = true := by
  native_decide

theorem generatedUiProofCase_policy_strategy_deterministic :
    generatedUiProofCase.policyStrategyDeterministic = true := by
  native_decide

theorem generatedUiProofCase_workflow_agreement_linked :
    generatedUiProofCase.workflowAgreementLinked = true := by
  native_decide

theorem generatedUiProofCase_sandbox_agreement_linked :
    generatedUiProofCase.sandboxAgreementLinked = true := by
  native_decide

theorem generatedUiProofCase_runtime_handoff_owned :
    generatedUiProofCase.runtimeHandoffOwned = true := by
  native_decide

theorem generatedUiProofCase_covers_required_evidence_fields :
    generatedUiProofCase.coversRequiredEvidenceFields = true := by
  native_decide

theorem generatedUiProofCase_valid : generatedUiProofCase.Valid where
  manifestValid := generatedManifest_valid
  profilePolicyLinked := generatedUiProofCase_profile_policy_linked
  strategyLinked := generatedUiProofCase_strategy_linked
  capabilitiesBounded := generatedUiProofCase_capabilities_bounded
  policyStrategyDeterministic :=
    generatedUiProofCase_policy_strategy_deterministic
  workflowAgreementLinked := generatedUiProofCase_workflow_agreement_linked
  sandboxAgreementLinked := generatedUiProofCase_sandbox_agreement_linked
  runtimeHandoffOwned := generatedUiProofCase_runtime_handoff_owned
  coversRequiredEvidenceFields :=
    generatedUiProofCase_covers_required_evidence_fields

theorem generatedUiProofCase_proof_case_vector_complete :
    generatedUiProofCase.proofCaseVectorComplete = true :=
  UiLoopProofCase.proof_case_vector_complete_of_valid
    generatedUiProofCase_valid

end AgenticAILabProof.Generated.LoopEngine
