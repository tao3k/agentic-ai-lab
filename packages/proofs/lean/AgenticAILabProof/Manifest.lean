-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof

inductive ManifestKind where
  | loopEngineProofManifest
deriving Repr, DecidableEq

inductive ProofManifestContract where
  | v1
deriving Repr, DecidableEq

inductive ManifestSource where
  | userConfigLoopEngine
deriving Repr, DecidableEq

inductive ProofOwner where
  | lean
deriving Repr, DecidableEq

inductive ProofChecker where
  | lean
  | axle
deriving Repr, DecidableEq

inductive RuntimeOwner where
  | marlinAgentCore
deriving Repr, DecidableEq

inductive SchemeProjection where
  | loopEngineRuntimeCommandManifest
deriving Repr, DecidableEq

inductive ProofScope where
  | userInterface
  | profile
  | policy
  | strategy
  | workflow
  | sandbox
  | runtimeHandoff
deriving Repr, DecidableEq

inductive RuntimeCommandContract where
  | loopGovernorRuntimeCommandManifestV1
deriving Repr, DecidableEq

inductive ObjectFamily where
  | agentProfile
  | agentHarness
  | agentSession
  | sessionAgentGraph
  | workflowRun
  | dispatchReceipt
  | agentOperation
  | lineageReceipt
  | selectorReceipt
  | resourceDispatchReceipt
  | capabilityReceipt
  | memoryReceipt
  | compressionReceipt
  | policyExtensionReceipt
  | specEvolutionReviewItem
  | specEvolutionRuntimeManifestRow
  | runtimeCapabilityDescriptor
  | policyProfilePacket
  | runtimeActionPacket
  | runtimeReceiptBatch
  | runtimeSnapshot
deriving Repr, DecidableEq

inductive ReceiptContract where
  | lineageReceiptV1
  | selectorReceiptV1
  | sessionAgentGraphV1
  | resourceDispatchReceiptV1
  | capabilityReceiptV1
  | memoryReceiptV1
  | compressionReceiptV1
  | policyExtensionReceiptV1
  | specEvolutionReviewItemV1
  | specEvolutionRuntimeManifestRowV1
  | runtimeCapabilityDescriptorV1
  | policyProfilePacketV1
  | runtimeActionPacketV1
  | runtimeReceiptBatchV1
  | sandboxHandoffAgreementV1
deriving Repr, DecidableEq

inductive RuntimePacketContract where
  | capabilityDescriptorV1
  | policyProfilePacketV1
  | actionPacketV1
  | receiptBatchV1
deriving Repr, DecidableEq

inductive ObligationName where
  | uiConfigWellFormed
  | uiProfilePolicyLinked
  | loopStrategyPlanWellFormed
  | executionPolicyCapabilityBounded
  | policyStrategyDeterministic
  | runtimeCommandInert
  | workflowAgreementLinked
  | sandboxBoundaryLinked
  | runtimeHandoffOwnerLinked
  | proofCaseVectorComplete
deriving Repr, DecidableEq

inductive ObligationClaim where
  | allRuntimeHandoffReferencesArePresent
  | profilePolicySelectionsAreCarriedIntoProofCase
  | loopStrategyPlanHasExplicitOwnerAndContract
  | executionPolicyCapabilitiesAreBoundedByProfile
  | policyAndStrategyProjectionHasStablePrecedence
  | schemeEmitsManifestWithoutRuntimeExecution
  | workflowAgreementIsCarriedIntoRuntimeEnvelope
  | sandboxHandoffAgreementIsCarriedIntoProofScope
  | runtimeHandoffOwnerRemainsMarlinAgentCore
  | proofCaseVectorCoversRequiredUiPolicyStrategyFields
deriving Repr, DecidableEq

inductive ObligationSource where
  | schemeProjection
  | profilePolicyPacket
  | loopStrategyPlan
  | executionPolicy
  | runtimeCommandManifest
  | policyProfilePacket
  | workflowAgreement
  | sandboxHandoffAgreement
  | runtimeHandoffManifest
  | proofCaseVector
deriving Repr, DecidableEq

inductive ObligationDomain where
  | userInterface
  | profile
  | policy
  | strategy
  | workflow
  | sandbox
  | runtimeHandoff
deriving Repr, DecidableEq

inductive ObligationCaseFamily where
  | uiConfig
  | profilePolicy
  | loopStrategy
  | executionPolicy
  | workflowAgreement
  | sandboxBoundary
  | runtimeCommand
  | proofCaseVector
deriving Repr, DecidableEq

inductive EvidenceField where
  | requestId
  | artifactHandle
  | objectFamilies
  | runtimePacketContracts
  | receiptContracts
  | policyProfileRefs
  | strategyOwner
  | strategyContract
  | executionOwner
  | capabilities
  | frontier
  | cachePolicy
  | failurePolicy
  | policy
  | strategy
  | precedence
  | profile
  | runtimeCommandContract
  | runtimeExecuted
  | workflowAgreement
  | runtimeEnvelope
  | sandboxHandoffAgreement
  | proofScope
  | runtimeOwner
  | runtimeHandoff
  | obligationTags
  | obligations
  | cAbi
deriving Repr, DecidableEq

inductive LeanArtifactKind where
  | theoremStubs
deriving Repr, DecidableEq

-- A proof manifest is inert by type. There is no constructor for a manifest
-- that claims Scheme already executed runtime work.
inductive RuntimeExecution where
  | inert
deriving Repr, DecidableEq

inductive TagWidth where
  | uint32
deriving Repr, DecidableEq

structure ProofAbi where
  version : Nat
  obligationSchemaVersion : Nat
  requiredObligationMask : UInt32
  tagWidth : TagWidth
  obligationCount : Nat
deriving Repr, DecidableEq

structure Obligation where
  name : ObligationName
  claim : ObligationClaim
  source : ObligationSource
  domain : ObligationDomain
  caseFamily : ObligationCaseFamily
  evidenceFields : List EvidenceField
  runtimeExecution : RuntimeExecution
deriving Repr, DecidableEq

structure ProofManifest where
  kind : ManifestKind
  contract : ProofManifestContract
  source : ManifestSource
  proofOwner : ProofOwner
  proofChecker : ProofChecker
  runtimeOwner : RuntimeOwner
  schemeProjection : SchemeProjection
  proofScope : List ProofScope
  requestId : String
  artifactHandle : String
  runtimeCommandContract : RuntimeCommandContract
  objectFamilies : List ObjectFamily
  receiptContracts : List ReceiptContract
  runtimePacketContracts : List RuntimePacketContract
  cAbi : ProofAbi
  obligations : List Obligation
  leanArtifactKind : LeanArtifactKind
  runtimeExecution : RuntimeExecution
deriving Repr, DecidableEq

def requiredObligationNames : List ObligationName :=
  [ ObligationName.uiConfigWellFormed
  , ObligationName.uiProfilePolicyLinked
  , ObligationName.loopStrategyPlanWellFormed
  , ObligationName.executionPolicyCapabilityBounded
  , ObligationName.policyStrategyDeterministic
  , ObligationName.runtimeCommandInert
  , ObligationName.workflowAgreementLinked
  , ObligationName.sandboxBoundaryLinked
  , ObligationName.runtimeHandoffOwnerLinked
  , ObligationName.proofCaseVectorComplete
  ]

def requiredProofScopes : List ProofScope :=
  [ ProofScope.userInterface
  , ProofScope.profile
  , ProofScope.policy
  , ProofScope.strategy
  , ProofScope.workflow
  , ProofScope.sandbox
  , ProofScope.runtimeHandoff
  ]

def requiredObligationMask : UInt32 := 1023

def canonicalProofAbi : ProofAbi :=
  { version := 1
    obligationSchemaVersion := 1
    requiredObligationMask := requiredObligationMask
    tagWidth := TagWidth.uint32
    obligationCount := 10 }

def ProofManifest.hasObligationName
    (manifest : ProofManifest)
    (name : ObligationName) : Bool :=
  manifest.obligations.any (fun obligation => obligation.name == name)

def ProofManifest.hasAllRequiredObligations
    (manifest : ProofManifest) : Bool :=
  requiredObligationNames.all (manifest.hasObligationName ·)

def ProofManifest.hasProofScope
    (manifest : ProofManifest)
    (scope : ProofScope) : Bool :=
  manifest.proofScope.any (fun actual => actual == scope)

def ProofManifest.hasAllRequiredProofScopes
    (manifest : ProofManifest) : Bool :=
  requiredProofScopes.all (manifest.hasProofScope ·)

def Obligation.isRuntimeInert (obligation : Obligation) : Bool :=
  obligation.runtimeExecution == RuntimeExecution.inert

def ProofManifest.allObligationsRuntimeInert
    (manifest : ProofManifest) : Bool :=
  manifest.obligations.all (fun obligation => obligation.isRuntimeInert)

def ProofManifest.proofCaseVectorComplete
    (manifest : ProofManifest) : Bool :=
  manifest.hasAllRequiredObligations &&
  manifest.hasAllRequiredProofScopes &&
  manifest.allObligationsRuntimeInert

structure ProofManifest.Valid (manifest : ProofManifest) : Prop where
  abiMatches : manifest.cAbi = canonicalProofAbi
  hasRequiredObligations : manifest.hasAllRequiredObligations = true
  hasRequiredProofScopes : manifest.hasAllRequiredProofScopes = true
  obligationsRuntimeInert : manifest.allObligationsRuntimeInert = true

theorem ProofManifest.runtime_inert_by_type
    (manifest : ProofManifest) :
    manifest.runtimeExecution = RuntimeExecution.inert := by
  cases manifest.runtimeExecution
  rfl

theorem ProofManifest.has_required_obligations_of_valid
    {manifest : ProofManifest}
    (valid : manifest.Valid) :
    manifest.hasAllRequiredObligations = true :=
  valid.hasRequiredObligations

theorem ProofManifest.has_required_scopes_of_valid
    {manifest : ProofManifest}
    (valid : manifest.Valid) :
    manifest.hasAllRequiredProofScopes = true :=
  valid.hasRequiredProofScopes

theorem ProofManifest.obligations_runtime_inert_of_valid
    {manifest : ProofManifest}
    (valid : manifest.Valid) :
    manifest.allObligationsRuntimeInert = true :=
  valid.obligationsRuntimeInert

theorem ProofManifest.abi_matches_of_valid
    {manifest : ProofManifest}
    (valid : manifest.Valid) :
    manifest.cAbi = canonicalProofAbi :=
  valid.abiMatches

theorem ProofManifest.proof_case_vector_complete_of_valid
    {manifest : ProofManifest}
    (valid : manifest.Valid) :
    manifest.proofCaseVectorComplete = true := by
  simp [ ProofManifest.proofCaseVectorComplete
       , valid.hasRequiredObligations
       , valid.hasRequiredProofScopes
       , valid.obligationsRuntimeInert
       ]

end AgenticAILabProof
