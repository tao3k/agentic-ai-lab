-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundFingerprintHistoryClosure

namespace AgenticAILabProof.Enterprise.SourceBoundFingerprintContentAddressClosure

open AgenticAILabProof.Enterprise.SourceBoundFingerprintHistoryClosure
open AgenticAILabProof.Enterprise.SourceBoundProgressEvidenceClosure

structure CanonicalFingerprintCheckpointPayload where
  checkpoint : SourceBoundSemanticFingerprintCheckpoint
  deriving DecidableEq, Repr

def canonicalFingerprintCheckpointPayload
    (checkpoint : SourceBoundSemanticFingerprintCheckpoint) :
    CanonicalFingerprintCheckpointPayload :=
  { checkpoint := checkpoint }

/--
The canonical identity is a pure recursive object.  Constructor equality gives
Lean a collision-free logical model without claiming that an external digest
algorithm is mathematically collision-free.
-/
inductive CanonicalFingerprintCheckpointIdentity where
  | genesis (payload : CanonicalFingerprintCheckpointPayload)
  | successor
      (previous : CanonicalFingerprintCheckpointIdentity)
      (payload : CanonicalFingerprintCheckpointPayload)
  deriving DecidableEq, Repr

theorem canonicalSuccessorBindsPreviousIdentity
    {leftPrevious rightPrevious : CanonicalFingerprintCheckpointIdentity}
    {payload : CanonicalFingerprintCheckpointPayload}
    (previousIdentityDiffers : leftPrevious ≠ rightPrevious) :
    CanonicalFingerprintCheckpointIdentity.successor leftPrevious payload ≠
      CanonicalFingerprintCheckpointIdentity.successor rightPrevious payload := by
  intro identitiesEqual
  injection identitiesEqual with previousIdentitiesEqual
  exact previousIdentityDiffers previousIdentitiesEqual

theorem canonicalSuccessorBindsCheckpointPayload
    {previous : CanonicalFingerprintCheckpointIdentity}
    {leftPayload rightPayload : CanonicalFingerprintCheckpointPayload}
    (checkpointPayloadDiffers : leftPayload ≠ rightPayload) :
    CanonicalFingerprintCheckpointIdentity.successor previous leftPayload ≠
      CanonicalFingerprintCheckpointIdentity.successor previous rightPayload := by
  intro identitiesEqual
  injection identitiesEqual with _ checkpointPayloadsEqual
  exact checkpointPayloadDiffers checkpointPayloadsEqual

structure SourceBoundFingerprintCheckpointEnvelope where
  checkpoint : SourceBoundSemanticFingerprintCheckpoint
  canonicalIdentity : CanonicalFingerprintCheckpointIdentity
  deriving Repr

def canonicalCheckpointEnvelopeChainFrom
    (previous : SourceBoundFingerprintCheckpointEnvelope) :
    List SourceBoundFingerprintCheckpointEnvelope → Prop
  | [] => True
  | current :: rest =>
      current.canonicalIdentity =
          .successor previous.canonicalIdentity
            (canonicalFingerprintCheckpointPayload current.checkpoint) ∧
        canonicalCheckpointEnvelopeChainFrom current rest

def canonicalCheckpointEnvelopeChainClosed :
    List SourceBoundFingerprintCheckpointEnvelope → Prop
  | [] => False
  | first :: rest =>
      first.canonicalIdentity =
          .genesis (canonicalFingerprintCheckpointPayload first.checkpoint) ∧
        canonicalCheckpointEnvelopeChainFrom first rest

structure CanonicalFingerprintHistoryIdentity where
  historyId : FingerprintHistoryId
  chainTip : CanonicalFingerprintCheckpointIdentity
  deriving DecidableEq, Repr

structure SourceBoundFingerprintHistoryCommitment where
  historyId : FingerprintHistoryId
  envelopes : List SourceBoundFingerprintCheckpointEnvelope
  canonicalRoot : CanonicalFingerprintHistoryIdentity
  deriving Repr

def canonicalHistoryRootClosed
    (commitment : SourceBoundFingerprintHistoryCommitment) : Prop :=
  ∃ first middle final,
    commitment.envelopes = first :: (middle ++ [final]) ∧
      commitment.canonicalRoot =
        { historyId := commitment.historyId
          chainTip := final.canonicalIdentity }

structure SourceBoundFingerprintCanonicalCommitmentClosed
    (history : SourceBoundSemanticFingerprintHistory)
    (commitment : SourceBoundFingerprintHistoryCommitment) : Prop where
  historyIdentityMatches : commitment.historyId = history.historyId
  checkpointProjectionMatches :
    commitment.envelopes.map (·.checkpoint) = history.checkpoints
  checkpointChainCloses :
    canonicalCheckpointEnvelopeChainClosed commitment.envelopes
  historyRootCloses : canonicalHistoryRootClosed commitment

structure SourceBoundFingerprintHistoryDigestReceipt where
  receiptId : String
  providerIdentity : String
  canonicalRoot : CanonicalFingerprintHistoryIdentity
  digest : String
  provenanceDigest : String
  deriving Repr

def SourceBoundFingerprintHistoryDigestReceiptValid :=
  SourceBoundFingerprintHistoryDigestReceipt → Prop

/--
Lean binds the provider receipt to the canonical root.  Cryptographic digest
correctness remains an explicit provider-owned validation predicate.
-/
structure SourceBoundFingerprintHistoryDigestEvidenceClosed
    (digestValid : SourceBoundFingerprintHistoryDigestReceiptValid)
    (history : SourceBoundSemanticFingerprintHistory)
    (commitment : SourceBoundFingerprintHistoryCommitment)
    (receipt : SourceBoundFingerprintHistoryDigestReceipt) : Prop where
  canonicalCommitmentCloses :
    SourceBoundFingerprintCanonicalCommitmentClosed history commitment
  digestReceiptValidates : digestValid receipt
  canonicalRootMatches : receipt.canonicalRoot = commitment.canonicalRoot
  receiptIdentityPresent : receipt.receiptId ≠ ""
  providerIdentityPresent : receipt.providerIdentity ≠ ""
  digestPresent : receipt.digest ≠ ""
  provenancePresent : receipt.provenanceDigest ≠ ""

theorem closedDigestEvidenceBindsCanonicalRoot
    {digestValid : SourceBoundFingerprintHistoryDigestReceiptValid}
    {history : SourceBoundSemanticFingerprintHistory}
    {commitment : SourceBoundFingerprintHistoryCommitment}
    {receipt : SourceBoundFingerprintHistoryDigestReceipt}
    (closed :
      SourceBoundFingerprintHistoryDigestEvidenceClosed
        digestValid history commitment receipt) :
    receipt.canonicalRoot = commitment.canonicalRoot :=
  closed.canonicalRootMatches

structure SourceBoundFingerprintHistoryContentAddressEvidenceClosed
    (digestValid : SourceBoundFingerprintHistoryDigestReceiptValid)
    (progress : SourceBoundProgressReceipt)
    (evidence : SubjectProgressEvidence)
    (history : SourceBoundSemanticFingerprintHistory)
    (commitment : SourceBoundFingerprintHistoryCommitment)
    (receipt : SourceBoundFingerprintHistoryDigestReceipt) : Prop where
  fingerprintHistoryCloses :
    SourceBoundFingerprintHistoryEvidenceClosed
      progress evidence history
  contentAddressCloses :
    SourceBoundFingerprintHistoryDigestEvidenceClosed
      digestValid history commitment receipt

theorem closedContentAddressEvidenceCarriesHistoryAndDigestOwners
    {digestValid : SourceBoundFingerprintHistoryDigestReceiptValid}
    {progress : SourceBoundProgressReceipt}
    {evidence : SubjectProgressEvidence}
    {history : SourceBoundSemanticFingerprintHistory}
    {commitment : SourceBoundFingerprintHistoryCommitment}
    {receipt : SourceBoundFingerprintHistoryDigestReceipt}
    (closed :
      SourceBoundFingerprintHistoryContentAddressEvidenceClosed
        digestValid progress evidence history commitment receipt) :
    SourceBoundFingerprintHistoryEvidenceClosed
        progress evidence history ∧
      SourceBoundFingerprintHistoryDigestEvidenceClosed
        digestValid history commitment receipt :=
  ⟨closed.fingerprintHistoryCloses, closed.contentAddressCloses⟩

def alteredSourceBoundProgressCurrentCheckpointA :
    SourceBoundSemanticFingerprintCheckpoint :=
  { sourceBoundProgressCurrentCheckpointA with
    semanticFingerprint := "sha256:tampered-current" }

theorem nonemptyProvenanceDoesNotBindCheckpointContent :
    alteredSourceBoundProgressCurrentCheckpointA.provenanceDigest =
        sourceBoundProgressCurrentCheckpointA.provenanceDigest ∧
      alteredSourceBoundProgressCurrentCheckpointA ≠
        sourceBoundProgressCurrentCheckpointA := by
  constructor
  · rfl
  · simp [
      alteredSourceBoundProgressCurrentCheckpointA,
      sourceBoundProgressCurrentCheckpointA,
      progressEvidenceA
    ]

def originalCurrentCanonicalIdentity :
    CanonicalFingerprintCheckpointIdentity :=
  .genesis
    (canonicalFingerprintCheckpointPayload
      sourceBoundProgressCurrentCheckpointA)

def alteredCurrentCanonicalIdentity :
    CanonicalFingerprintCheckpointIdentity :=
  .genesis
    (canonicalFingerprintCheckpointPayload
      alteredSourceBoundProgressCurrentCheckpointA)

def originalCanonicalHistoryRoot : CanonicalFingerprintHistoryIdentity :=
  { historyId := "content-address-root"
    chainTip := originalCurrentCanonicalIdentity }

def alteredCanonicalHistoryRoot : CanonicalFingerprintHistoryIdentity :=
  { historyId := "content-address-root"
    chainTip := alteredCurrentCanonicalIdentity }

def constantExternalDigest
    (_root : CanonicalFingerprintHistoryIdentity) : String :=
  "sha256:constant"

theorem arbitraryExternalDigestDoesNotDetermineCanonicalRoot :
    originalCanonicalHistoryRoot ≠ alteredCanonicalHistoryRoot ∧
      constantExternalDigest originalCanonicalHistoryRoot =
        constantExternalDigest alteredCanonicalHistoryRoot := by
  constructor
  · simp [
      originalCanonicalHistoryRoot,
      alteredCanonicalHistoryRoot,
      originalCurrentCanonicalIdentity,
      alteredCurrentCanonicalIdentity,
      canonicalFingerprintCheckpointPayload,
      alteredSourceBoundProgressCurrentCheckpointA,
      sourceBoundProgressCurrentCheckpointA,
      progressEvidenceA
    ]
  · rfl

def sourceBoundPreviousCheckpointEnvelopeA :
    SourceBoundFingerprintCheckpointEnvelope :=
  { checkpoint := sourceBoundProgressPreviousCheckpointA
    canonicalIdentity :=
      .genesis
        (canonicalFingerprintCheckpointPayload
          sourceBoundProgressPreviousCheckpointA) }

def sourceBoundCurrentCheckpointEnvelopeA :
    SourceBoundFingerprintCheckpointEnvelope :=
  { checkpoint := sourceBoundProgressCurrentCheckpointA
    canonicalIdentity :=
      .successor
        sourceBoundPreviousCheckpointEnvelopeA.canonicalIdentity
        (canonicalFingerprintCheckpointPayload
          sourceBoundProgressCurrentCheckpointA) }

def sourceBoundFingerprintHistoryCommitmentA :
    SourceBoundFingerprintHistoryCommitment :=
  { historyId := sourceBoundProgressHistoryA.historyId
    envelopes :=
      [sourceBoundPreviousCheckpointEnvelopeA,
        sourceBoundCurrentCheckpointEnvelopeA]
    canonicalRoot :=
      { historyId := sourceBoundProgressHistoryA.historyId
        chainTip := sourceBoundCurrentCheckpointEnvelopeA.canonicalIdentity } }

theorem sourceBoundFingerprintHistoryCommitmentACloses :
    SourceBoundFingerprintCanonicalCommitmentClosed
      sourceBoundProgressHistoryA sourceBoundFingerprintHistoryCommitmentA := by
  constructor
  · rfl
  · simp [
      sourceBoundFingerprintHistoryCommitmentA,
      sourceBoundPreviousCheckpointEnvelopeA,
      sourceBoundCurrentCheckpointEnvelopeA,
      sourceBoundProgressHistoryA
    ]
  · simp [
      canonicalCheckpointEnvelopeChainClosed,
      canonicalCheckpointEnvelopeChainFrom,
      sourceBoundFingerprintHistoryCommitmentA,
      sourceBoundPreviousCheckpointEnvelopeA,
      sourceBoundCurrentCheckpointEnvelopeA
    ]
  · refine ⟨sourceBoundPreviousCheckpointEnvelopeA, [],
    sourceBoundCurrentCheckpointEnvelopeA, ?_⟩
    simp [
      sourceBoundFingerprintHistoryCommitmentA
    ]

def sourceBoundFingerprintHistoryDigestReceiptA :
    SourceBoundFingerprintHistoryDigestReceipt :=
  { receiptId := "source-bound-fingerprint-history-digest-a"
    providerIdentity := "agent-semantic-content-identity"
    canonicalRoot := sourceBoundFingerprintHistoryCommitmentA.canonicalRoot
    digest := "sha256:source-bound-fingerprint-history-a"
    provenanceDigest := "source-bound-fingerprint-history-digest-provenance-a" }

def sourceBoundFingerprintHistoryDigestReceiptValidA :
    SourceBoundFingerprintHistoryDigestReceiptValid :=
  fun receipt =>
    receipt = sourceBoundFingerprintHistoryDigestReceiptA

theorem sourceBoundFingerprintHistoryDigestEvidenceACloses :
    SourceBoundFingerprintHistoryDigestEvidenceClosed
      sourceBoundFingerprintHistoryDigestReceiptValidA
      sourceBoundProgressHistoryA
      sourceBoundFingerprintHistoryCommitmentA
      sourceBoundFingerprintHistoryDigestReceiptA := by
  constructor
  · exact sourceBoundFingerprintHistoryCommitmentACloses
  · rfl
  · rfl
  · decide
  · decide
  · decide
  · decide

theorem sourceBoundFingerprintHistoryContentAddressEvidenceACloses :
    SourceBoundFingerprintHistoryContentAddressEvidenceClosed
      sourceBoundFingerprintHistoryDigestReceiptValidA
      sourceBoundCycleProgressReceipt
      progressEvidenceA
      sourceBoundProgressHistoryA
      sourceBoundFingerprintHistoryCommitmentA
      sourceBoundFingerprintHistoryDigestReceiptA :=
  ⟨sourceBoundProgressHistoryACloses,
    sourceBoundFingerprintHistoryDigestEvidenceACloses⟩

theorem independentlyClosedHistoryAndContentAddressOwnersCompose
    {historyClosure contentAddressClosure : Prop}
    (historyClosed : historyClosure)
    (contentAddressClosed : contentAddressClosure) :
    historyClosure ∧ contentAddressClosure :=
  ⟨historyClosed, contentAddressClosed⟩

end AgenticAILabProof.Enterprise.SourceBoundFingerprintContentAddressClosure
