-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Manifest

namespace AgenticAILabProof

inductive UiProfileRef where
  | currentSystemBuildLoop
deriving Repr, DecidableEq

inductive UiPolicyRef where
  | currentSystemBuildPolicy
deriving Repr, DecidableEq

inductive UiStrategyRef where
  | deterministicLoopStrategy
deriving Repr, DecidableEq

inductive UiWorkflowAgreementRef where
  | runtimeEnvelopeAgreement
deriving Repr, DecidableEq

inductive UiSandboxAgreementRef where
  | sandboxHandoffAgreement
deriving Repr, DecidableEq

inductive RuntimeCapability where
  | projectRead
  | artifactWrite
  | cacheRead
  | cacheWrite
deriving Repr, DecidableEq

inductive PolicyStrategyPrecedence where
  | profilePolicyStrategy
deriving Repr, DecidableEq

def hasRuntimeCapability
    (capabilities : List RuntimeCapability)
    (capability : RuntimeCapability) : Bool :=
  capabilities.any (fun actual => actual == capability)

def requestedCapabilitiesBounded
    (allowed requested : List RuntimeCapability) : Bool :=
  requested.all (hasRuntimeCapability allowed ·)

def hasEvidenceField
    (evidenceFields : List EvidenceField)
    (field : EvidenceField) : Bool :=
  evidenceFields.any (fun actual => actual == field)

def requiredUiCaseEvidenceFields : List EvidenceField :=
  [ EvidenceField.requestId
  , EvidenceField.artifactHandle
  , EvidenceField.objectFamilies
  , EvidenceField.runtimePacketContracts
  , EvidenceField.receiptContracts
  , EvidenceField.policyProfileRefs
  , EvidenceField.strategyOwner
  , EvidenceField.strategyContract
  , EvidenceField.executionOwner
  , EvidenceField.capabilities
  , EvidenceField.frontier
  , EvidenceField.cachePolicy
  , EvidenceField.failurePolicy
  , EvidenceField.policy
  , EvidenceField.strategy
  , EvidenceField.precedence
  , EvidenceField.profile
  , EvidenceField.runtimeCommandContract
  , EvidenceField.runtimeExecuted
  , EvidenceField.workflowAgreement
  , EvidenceField.runtimeEnvelope
  , EvidenceField.sandboxHandoffAgreement
  , EvidenceField.proofScope
  , EvidenceField.runtimeOwner
  , EvidenceField.runtimeHandoff
  , EvidenceField.obligationTags
  , EvidenceField.obligations
  , EvidenceField.cAbi
  ]

structure UiLoopProofCase where
  requestId : String
  artifactHandle : String
  profile : UiProfileRef
  policy : UiPolicyRef
  strategy : UiStrategyRef
  profilePolicyProfile : UiProfileRef
  profilePolicyPolicy : UiPolicyRef
  strategyProfile : UiProfileRef
  strategyPolicy : UiPolicyRef
  strategyOwner : RuntimeOwner
  strategyContract : RuntimeCommandContract
  allowedCapabilities : List RuntimeCapability
  requestedCapabilities : List RuntimeCapability
  precedence : PolicyStrategyPrecedence
  workflowAgreement : UiWorkflowAgreementRef
  sandboxAgreement : UiSandboxAgreementRef
  proofScope : List ProofScope
  objectFamilies : List ObjectFamily
  receiptContracts : List ReceiptContract
  runtimePacketContracts : List RuntimePacketContract
  cAbi : ProofAbi
  obligations : List Obligation
  evidenceFields : List EvidenceField
  runtimeExecution : RuntimeExecution
deriving Repr, DecidableEq

def UiLoopProofCase.toManifest (proofCase : UiLoopProofCase) : ProofManifest :=
  { kind := ManifestKind.loopEngineProofManifest
    contract := ProofManifestContract.v1
    source := ManifestSource.userConfigLoopEngine
    proofOwner := ProofOwner.lean
    proofChecker := ProofChecker.axle
    runtimeOwner := RuntimeOwner.marlinAgentCore
    schemeProjection := SchemeProjection.loopEngineRuntimeCommandManifest
    proofScope := proofCase.proofScope
    requestId := proofCase.requestId
    artifactHandle := proofCase.artifactHandle
    runtimeCommandContract :=
      RuntimeCommandContract.loopGovernorRuntimeCommandManifestV1
    objectFamilies := proofCase.objectFamilies
    receiptContracts := proofCase.receiptContracts
    runtimePacketContracts := proofCase.runtimePacketContracts
    cAbi := proofCase.cAbi
    obligations := proofCase.obligations
    leanArtifactKind := LeanArtifactKind.theoremStubs
    runtimeExecution := proofCase.runtimeExecution }

def UiLoopProofCase.profilePolicyLinked
    (proofCase : UiLoopProofCase) : Bool :=
  (proofCase.profilePolicyProfile == proofCase.profile) &&
  (proofCase.profilePolicyPolicy == proofCase.policy)

def UiLoopProofCase.strategyLinked
    (proofCase : UiLoopProofCase) : Bool :=
  (proofCase.strategyProfile == proofCase.profile) &&
  (proofCase.strategyPolicy == proofCase.policy) &&
  (proofCase.strategyOwner == RuntimeOwner.marlinAgentCore) &&
  (proofCase.strategyContract ==
   RuntimeCommandContract.loopGovernorRuntimeCommandManifestV1)

def UiLoopProofCase.capabilitiesBounded
    (proofCase : UiLoopProofCase) : Bool :=
  requestedCapabilitiesBounded
    proofCase.allowedCapabilities
    proofCase.requestedCapabilities

def UiLoopProofCase.policyStrategyDeterministic
    (proofCase : UiLoopProofCase) : Bool :=
  proofCase.precedence == PolicyStrategyPrecedence.profilePolicyStrategy

def UiLoopProofCase.workflowAgreementLinked
    (proofCase : UiLoopProofCase) : Bool :=
  proofCase.workflowAgreement ==
  UiWorkflowAgreementRef.runtimeEnvelopeAgreement

def UiLoopProofCase.sandboxAgreementLinked
    (proofCase : UiLoopProofCase) : Bool :=
  proofCase.sandboxAgreement ==
  UiSandboxAgreementRef.sandboxHandoffAgreement

def UiLoopProofCase.runtimeHandoffOwned
    (proofCase : UiLoopProofCase) : Bool :=
  (proofCase.strategyOwner == RuntimeOwner.marlinAgentCore) &&
  (proofCase.runtimeExecution == RuntimeExecution.inert)

def UiLoopProofCase.coversRequiredEvidenceFields
    (proofCase : UiLoopProofCase) : Bool :=
  requiredUiCaseEvidenceFields.all (hasEvidenceField proofCase.evidenceFields ·)

def UiLoopProofCase.proofCaseVectorComplete
    (proofCase : UiLoopProofCase) : Bool :=
  proofCase.toManifest.proofCaseVectorComplete &&
  proofCase.profilePolicyLinked &&
  proofCase.strategyLinked &&
  proofCase.capabilitiesBounded &&
  proofCase.policyStrategyDeterministic &&
  proofCase.workflowAgreementLinked &&
  proofCase.sandboxAgreementLinked &&
  proofCase.runtimeHandoffOwned &&
  proofCase.coversRequiredEvidenceFields

structure UiLoopProofCase.Valid (proofCase : UiLoopProofCase) : Prop where
  manifestValid : proofCase.toManifest.Valid
  profilePolicyLinked : proofCase.profilePolicyLinked = true
  strategyLinked : proofCase.strategyLinked = true
  capabilitiesBounded : proofCase.capabilitiesBounded = true
  policyStrategyDeterministic :
    proofCase.policyStrategyDeterministic = true
  workflowAgreementLinked : proofCase.workflowAgreementLinked = true
  sandboxAgreementLinked : proofCase.sandboxAgreementLinked = true
  runtimeHandoffOwned : proofCase.runtimeHandoffOwned = true
  coversRequiredEvidenceFields :
    proofCase.coversRequiredEvidenceFields = true

theorem UiLoopProofCase.manifest_proof_case_vector_complete_of_valid
    {proofCase : UiLoopProofCase}
    (valid : proofCase.Valid) :
    proofCase.toManifest.proofCaseVectorComplete = true :=
  ProofManifest.proof_case_vector_complete_of_valid valid.manifestValid

theorem UiLoopProofCase.proof_case_vector_complete_of_valid
    {proofCase : UiLoopProofCase}
    (valid : proofCase.Valid) :
    proofCase.proofCaseVectorComplete = true := by
  simp [ UiLoopProofCase.proofCaseVectorComplete
       , UiLoopProofCase.manifest_proof_case_vector_complete_of_valid valid
       , valid.profilePolicyLinked
       , valid.strategyLinked
       , valid.capabilitiesBounded
       , valid.policyStrategyDeterministic
       , valid.workflowAgreementLinked
       , valid.sandboxAgreementLinked
       , valid.runtimeHandoffOwned
       , valid.coversRequiredEvidenceFields
       ]

end AgenticAILabProof
