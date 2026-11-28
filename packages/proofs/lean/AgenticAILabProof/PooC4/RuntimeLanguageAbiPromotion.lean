-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.ProtocolPersonPromotion

namespace AgenticAILabProof.PooC4.RuntimeLanguageAbiPromotion

structure Epochs where
  bundle : Nat
  authority : Nat
  proof : Nat
  evaluator : Nat
deriving DecidableEq, Repr

structure PromotionRequest where
  idempotencyKey : String
  expectedEpochs : Epochs
  approved : Prop
  requiredCapabilitiesPresent : Prop

inductive Outcome where
  | accepted
  | materialized
  | injected
  | replayedActive
  | rejectedStaleEpoch
  | rejectedCapability
  | rolledBack
  | failed
deriving DecidableEq, Repr

structure RuntimeReceipt where
  idempotencyKey : String
  implementationId : String
  outcome : Outcome
  materializationDigest : Option String
  injectionReceiptDigest : Option String
  rollbackReceiptDigest : Option String
  causalReceiptDigest : Option String
  runtimeExecuted : Prop
  capabilityQualified : Prop

def EpochCurrent (request : PromotionRequest) (world : Epochs) : Prop :=
  request.expectedEpochs = world

def ReceiptComplete (receipt : RuntimeReceipt) : Prop :=
  match receipt.outcome with
  | .materialized => receipt.materializationDigest.isSome
  | .injected =>
      receipt.materializationDigest.isSome ∧
      receipt.injectionReceiptDigest.isSome
  | .replayedActive =>
      receipt.materializationDigest.isSome ∧
      receipt.injectionReceiptDigest.isSome ∧
      receipt.causalReceiptDigest.isSome
  | .rolledBack => receipt.rollbackReceiptDigest.isSome
  | .rejectedStaleEpoch | .rejectedCapability | .failed =>
      receipt.materializationDigest.isNone ∧
      receipt.injectionReceiptDigest.isNone ∧
      receipt.rollbackReceiptDigest.isNone
  | .accepted => True

def Active
    (request : PromotionRequest)
    (world : Epochs)
    (receipt : RuntimeReceipt) : Prop :=
  request.approved ∧
  request.requiredCapabilitiesPresent ∧
  EpochCurrent request world ∧
  receipt.idempotencyKey = request.idempotencyKey ∧
  receipt.runtimeExecuted ∧
  receipt.capabilityQualified ∧
  ReceiptComplete receipt ∧
  (receipt.outcome = .injected ∨ receipt.outcome = .replayedActive)

def CommitCount (receipts : List RuntimeReceipt) (key : String) : Nat :=
  (receipts.filter fun receipt =>
    receipt.idempotencyKey == key && receipt.outcome == .injected).length

def ExactlyOnce (receipts : List RuntimeReceipt) (key : String) : Prop :=
  CommitCount receipts key = 1

def SemanticProjection (receipt : RuntimeReceipt) :=
  (receipt.idempotencyKey,
   receipt.outcome,
   receipt.materializationDigest,
   receipt.injectionReceiptDigest,
   receipt.rollbackReceiptDigest,
   receipt.causalReceiptDigest)

theorem stale_request_cannot_be_active
    (request : PromotionRequest)
    (world : Epochs)
    (receipt : RuntimeReceipt)
    (stale : request.expectedEpochs ≠ world) :
    ¬ Active request world receipt := by
  intro active
  exact stale active.2.2.1

theorem unapproved_request_cannot_be_active
    (request : PromotionRequest)
    (world : Epochs)
    (receipt : RuntimeReceipt)
    (denied : ¬ request.approved) :
    ¬ Active request world receipt := by
  intro active
  exact denied active.1

theorem missing_capability_cannot_be_active
    (request : PromotionRequest)
    (world : Epochs)
    (receipt : RuntimeReceipt)
    (missing : ¬ request.requiredCapabilitiesPresent) :
    ¬ Active request world receipt := by
  intro active
  exact missing active.2.1

theorem injected_without_materialization_cannot_be_active
    (request : PromotionRequest)
    (world : Epochs)
    (receipt : RuntimeReceipt)
    (injected : receipt.outcome = .injected)
    (missing : receipt.materializationDigest = none) :
    ¬ Active request world receipt := by
  intro active
  have complete := active.2.2.2.2.2.2.1
  simp [ReceiptComplete, injected, missing] at complete

theorem injected_without_injection_receipt_cannot_be_active
    (request : PromotionRequest)
    (world : Epochs)
    (receipt : RuntimeReceipt)
    (injected : receipt.outcome = .injected)
    (missing : receipt.injectionReceiptDigest = none) :
    ¬ Active request world receipt := by
  intro active
  have complete := active.2.2.2.2.2.2.1
  simp [ReceiptComplete, injected, missing] at complete

theorem duplicate_commits_violate_exactly_once
    (receipts : List RuntimeReceipt)
    (key : String)
    (duplicate : 1 < CommitCount receipts key) :
    ¬ ExactlyOnce receipts key := by
  intro exactlyOnce
  have notEqual : 1 ≠ CommitCount receipts key := Nat.ne_of_lt duplicate
  exact notEqual exactlyOnce.symm

theorem implementation_identity_does_not_change_semantics
    (receipt : RuntimeReceipt)
    (implementationId : String) :
    SemanticProjection { receipt with implementationId := implementationId } =
      SemanticProjection receipt := by
  rfl

inductive SourceRepresentation where
  | json
  | astData
deriving DecidableEq, Repr

structure SourceQueryReceipt where
  sourceLanguage : String
  sourceContentId : String
  sourceVersion : String
  parserId : String
  parserVersion : String
  queryId : String
  queryVersion : String
  selectedNodeIdentities : List String
  representation : SourceRepresentation
  provenanceRoot : String
  resultDigest : String

structure RuntimeAdmissionReceipt where
  sourceQueryResultDigest : String
  contractId : String
  contractVersion : String
  adapterId : String
  adapterVersion : String
  targetLanguage : String
  normalizedSemanticDigest : Option String
  admitted : Prop

def SourceQueryComplete (receipt : SourceQueryReceipt) : Prop :=
  receipt.sourceLanguage ≠ "" ∧
  receipt.sourceContentId ≠ "" ∧
  receipt.sourceVersion ≠ "" ∧
  receipt.parserId ≠ "" ∧
  receipt.parserVersion ≠ "" ∧
  receipt.queryId ≠ "" ∧
  receipt.queryVersion ≠ "" ∧
  receipt.selectedNodeIdentities ≠ [] ∧
  receipt.provenanceRoot ≠ "" ∧
  receipt.resultDigest ≠ ""

def RuntimeAdmitted
    (expectedContractId : String)
    (query : SourceQueryReceipt)
    (admission : RuntimeAdmissionReceipt) : Prop :=
  SourceQueryComplete query ∧
  admission.sourceQueryResultDigest = query.resultDigest ∧
  admission.contractId = expectedContractId ∧
  admission.contractVersion ≠ "" ∧
  admission.adapterId ≠ "" ∧
  admission.adapterVersion ≠ "" ∧
  admission.targetLanguage ≠ "" ∧
  admission.normalizedSemanticDigest.isSome ∧
  admission.admitted

def SourceQueryIdentity (receipt : SourceQueryReceipt) :=
  (receipt.sourceLanguage,
   receipt.sourceContentId,
   receipt.sourceVersion,
   receipt.parserId,
   receipt.parserVersion,
   receipt.queryId,
   receipt.queryVersion,
   receipt.selectedNodeIdentities,
   receipt.provenanceRoot,
   receipt.resultDigest)

def RuntimeAdmissionSemanticIdentity (receipt : RuntimeAdmissionReceipt) :=
  (receipt.sourceQueryResultDigest,
   receipt.contractId,
   receipt.contractVersion,
   receipt.normalizedSemanticDigest)

theorem wrong_contract_cannot_admit_projection
    (expectedContractId : String)
    (query : SourceQueryReceipt)
    (admission : RuntimeAdmissionReceipt)
    (wrongContract : admission.contractId ≠ expectedContractId) :
    ¬ RuntimeAdmitted expectedContractId query admission := by
  intro admitted
  exact wrongContract admitted.2.2.1

theorem missing_semantic_digest_cannot_admit_projection
    (expectedContractId : String)
    (query : SourceQueryReceipt)
    (admission : RuntimeAdmissionReceipt)
    (missing : admission.normalizedSemanticDigest = none) :
    ¬ RuntimeAdmitted expectedContractId query admission := by
  intro admitted
  have digestPresent := admitted.2.2.2.2.2.2.2.1
  simp [missing] at digestPresent

theorem source_representation_does_not_change_query_identity
    (receipt : SourceQueryReceipt)
    (representation : SourceRepresentation) :
    SourceQueryIdentity { receipt with representation := representation } =
      SourceQueryIdentity receipt := by
  rfl

theorem adapter_identity_does_not_change_projection_semantics
    (receipt : RuntimeAdmissionReceipt)
    (adapterId adapterVersion targetLanguage : String) :
    RuntimeAdmissionSemanticIdentity
        { receipt with
          adapterId := adapterId
          adapterVersion := adapterVersion
          targetLanguage := targetLanguage } =
      RuntimeAdmissionSemanticIdentity receipt := by
  rfl

inductive ArtifactKind where
  | abiVector
  | cHeader
  | jsonSchema
  | pythonType
  | rustType
  | gerbilPoo
  | leanProposition
deriving DecidableEq, Repr

structure ContractArtifactProjectionReceipt where
  projectionId : String
  contractId : String
  contractVersion : String
  sourceContractDigest : String
  projectorId : String
  projectorVersion : String
  artifactKind : ArtifactKind
  artifactId : String
  outputDigest : String

def ArtifactProjectionComplete
    (receipt : ContractArtifactProjectionReceipt) : Prop :=
  receipt.projectionId ≠ "" ∧
  receipt.contractId ≠ "" ∧
  receipt.contractVersion ≠ "" ∧
  receipt.sourceContractDigest ≠ "" ∧
  receipt.projectorId ≠ "" ∧
  receipt.projectorVersion ≠ "" ∧
  receipt.artifactId ≠ "" ∧
  receipt.outputDigest ≠ ""

def ArtifactSemanticSourceIdentity
    (receipt : ContractArtifactProjectionReceipt) :=
  (receipt.contractId,
   receipt.contractVersion,
   receipt.sourceContractDigest)

theorem artifact_without_output_digest_is_incomplete
    (receipt : ContractArtifactProjectionReceipt)
    (missing : receipt.outputDigest = "") :
    ¬ ArtifactProjectionComplete receipt := by
  intro complete
  exact complete.2.2.2.2.2.2.2 missing

theorem projector_identity_does_not_change_artifact_semantic_source
    (receipt : ContractArtifactProjectionReceipt)
    (projectorId projectorVersion artifactId outputDigest : String) :
    ArtifactSemanticSourceIdentity
        { receipt with
          projectorId := projectorId
          projectorVersion := projectorVersion
          artifactId := artifactId
          outputDigest := outputDigest } =
      ArtifactSemanticSourceIdentity receipt := by
  rfl

end AgenticAILabProof.PooC4.RuntimeLanguageAbiPromotion
