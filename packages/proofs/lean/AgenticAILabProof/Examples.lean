-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Manifest

namespace AgenticAILabProof

def uiConfigWellFormed : Obligation :=
  { name := ObligationName.uiConfigWellFormed
    claim := ObligationClaim.allRuntimeHandoffReferencesArePresent
    source := ObligationSource.schemeProjection
    domain := ObligationDomain.userInterface
    caseFamily := ObligationCaseFamily.uiConfig
    evidenceFields :=
      [ EvidenceField.requestId
      , EvidenceField.artifactHandle
      , EvidenceField.objectFamilies
      , EvidenceField.runtimePacketContracts
      ]
    runtimeExecution := RuntimeExecution.inert }

def uiProfilePolicyLinked : Obligation :=
  { name := ObligationName.uiProfilePolicyLinked
    claim := ObligationClaim.profilePolicySelectionsAreCarriedIntoProofCase
    source := ObligationSource.profilePolicyPacket
    domain := ObligationDomain.profile
    caseFamily := ObligationCaseFamily.profilePolicy
    evidenceFields :=
      [ EvidenceField.objectFamilies
      , EvidenceField.receiptContracts
      , EvidenceField.policyProfileRefs
      ]
    runtimeExecution := RuntimeExecution.inert }

def loopStrategyPlanWellFormed : Obligation :=
  { name := ObligationName.loopStrategyPlanWellFormed
    claim := ObligationClaim.loopStrategyPlanHasExplicitOwnerAndContract
    source := ObligationSource.loopStrategyPlan
    domain := ObligationDomain.strategy
    caseFamily := ObligationCaseFamily.loopStrategy
    evidenceFields :=
      [ EvidenceField.strategyOwner
      , EvidenceField.strategyContract
      , EvidenceField.executionOwner
      ]
    runtimeExecution := RuntimeExecution.inert }

def executionPolicyCapabilityBounded : Obligation :=
  { name := ObligationName.executionPolicyCapabilityBounded
    claim := ObligationClaim.executionPolicyCapabilitiesAreBoundedByProfile
    source := ObligationSource.executionPolicy
    domain := ObligationDomain.policy
    caseFamily := ObligationCaseFamily.executionPolicy
    evidenceFields :=
      [ EvidenceField.capabilities
      , EvidenceField.frontier
      , EvidenceField.cachePolicy
      , EvidenceField.failurePolicy
      ]
    runtimeExecution := RuntimeExecution.inert }

def policyStrategyDeterministic : Obligation :=
  { name := ObligationName.policyStrategyDeterministic
    claim := ObligationClaim.policyAndStrategyProjectionHasStablePrecedence
    source := ObligationSource.policyProfilePacket
    domain := ObligationDomain.policy
    caseFamily := ObligationCaseFamily.executionPolicy
    evidenceFields :=
      [ EvidenceField.policy
      , EvidenceField.strategy
      , EvidenceField.precedence
      , EvidenceField.profile
      ]
    runtimeExecution := RuntimeExecution.inert }

def runtimeCommandInert : Obligation :=
  { name := ObligationName.runtimeCommandInert
    claim := ObligationClaim.schemeEmitsManifestWithoutRuntimeExecution
    source := ObligationSource.runtimeCommandManifest
    domain := ObligationDomain.runtimeHandoff
    caseFamily := ObligationCaseFamily.runtimeCommand
    evidenceFields :=
      [ EvidenceField.runtimeCommandContract
      , EvidenceField.runtimeExecuted
      ]
    runtimeExecution := RuntimeExecution.inert }

def workflowAgreementLinked : Obligation :=
  { name := ObligationName.workflowAgreementLinked
    claim := ObligationClaim.workflowAgreementIsCarriedIntoRuntimeEnvelope
    source := ObligationSource.workflowAgreement
    domain := ObligationDomain.workflow
    caseFamily := ObligationCaseFamily.workflowAgreement
    evidenceFields :=
      [ EvidenceField.workflowAgreement
      , EvidenceField.runtimeEnvelope
      ]
    runtimeExecution := RuntimeExecution.inert }

def sandboxBoundaryLinked : Obligation :=
  { name := ObligationName.sandboxBoundaryLinked
    claim := ObligationClaim.sandboxHandoffAgreementIsCarriedIntoProofScope
    source := ObligationSource.sandboxHandoffAgreement
    domain := ObligationDomain.sandbox
    caseFamily := ObligationCaseFamily.sandboxBoundary
    evidenceFields :=
      [ EvidenceField.sandboxHandoffAgreement
      , EvidenceField.proofScope
      ]
    runtimeExecution := RuntimeExecution.inert }

def runtimeHandoffOwnerLinked : Obligation :=
  { name := ObligationName.runtimeHandoffOwnerLinked
    claim := ObligationClaim.runtimeHandoffOwnerRemainsMarlinAgentCore
    source := ObligationSource.runtimeHandoffManifest
    domain := ObligationDomain.runtimeHandoff
    caseFamily := ObligationCaseFamily.runtimeCommand
    evidenceFields :=
      [ EvidenceField.runtimeOwner
      , EvidenceField.runtimeHandoff
      , EvidenceField.runtimeExecuted
      ]
    runtimeExecution := RuntimeExecution.inert }

def proofCaseVectorComplete : Obligation :=
  { name := ObligationName.proofCaseVectorComplete
    claim := ObligationClaim.proofCaseVectorCoversRequiredUiPolicyStrategyFields
    source := ObligationSource.proofCaseVector
    domain := ObligationDomain.userInterface
    caseFamily := ObligationCaseFamily.proofCaseVector
    evidenceFields :=
      [ EvidenceField.obligationTags
      , EvidenceField.obligations
      , EvidenceField.proofScope
      , EvidenceField.cAbi
      ]
    runtimeExecution := RuntimeExecution.inert }

def requiredObligations : List Obligation :=
  [ uiConfigWellFormed
  , uiProfilePolicyLinked
  , loopStrategyPlanWellFormed
  , executionPolicyCapabilityBounded
  , policyStrategyDeterministic
  , runtimeCommandInert
  , workflowAgreementLinked
  , sandboxBoundaryLinked
  , runtimeHandoffOwnerLinked
  , proofCaseVectorComplete
  ]

def exampleManifest : ProofManifest :=
  { kind := ManifestKind.loopEngineProofManifest
    contract := ProofManifestContract.v1
    source := ManifestSource.userConfigLoopEngine
    proofOwner := ProofOwner.lean
    proofChecker := ProofChecker.axle
    runtimeOwner := RuntimeOwner.marlinAgentCore
    schemeProjection := SchemeProjection.loopEngineRuntimeCommandManifest
    proofScope := requiredProofScopes
    requestId := "loop-engine/current-system-build-loop/request"
    artifactHandle := "loop-engine/current-system-build-loop/artifact"
    runtimeCommandContract := RuntimeCommandContract.loopGovernorRuntimeCommandManifestV1
    objectFamilies := [ObjectFamily.agentProfile, ObjectFamily.runtimeSnapshot]
    receiptContracts := [ReceiptContract.lineageReceiptV1]
    runtimePacketContracts := [RuntimePacketContract.actionPacketV1]
    cAbi := canonicalProofAbi
    obligations := requiredObligations
    leanArtifactKind := LeanArtifactKind.theoremStubs
    runtimeExecution := RuntimeExecution.inert }

theorem exampleManifest_runtime_inert :
    exampleManifest.runtimeExecution = RuntimeExecution.inert :=
  ProofManifest.runtime_inert_by_type exampleManifest

theorem exampleManifest_has_required_obligations :
    exampleManifest.hasAllRequiredObligations = true := by
  native_decide

theorem exampleManifest_has_required_scopes :
    exampleManifest.hasAllRequiredProofScopes = true := by
  native_decide

theorem exampleManifest_obligations_runtime_inert :
    exampleManifest.allObligationsRuntimeInert = true := by
  native_decide

theorem exampleManifest_valid : exampleManifest.Valid where
  abiMatches := by native_decide
  hasRequiredObligations := exampleManifest_has_required_obligations
  hasRequiredProofScopes := exampleManifest_has_required_scopes
  obligationsRuntimeInert := exampleManifest_obligations_runtime_inert

theorem exampleManifest_proof_case_vector_complete :
    exampleManifest.proofCaseVectorComplete = true :=
  ProofManifest.proof_case_vector_complete_of_valid exampleManifest_valid

end AgenticAILabProof
