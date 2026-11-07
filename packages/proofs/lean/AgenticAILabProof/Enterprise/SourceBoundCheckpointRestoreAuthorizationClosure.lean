-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundFingerprintContentAddressClosure

namespace AgenticAILabProof.Enterprise.SourceBoundCheckpointRestoreAuthorizationClosure

open AgenticAILabProof.Enterprise.SourceBoundProgressEvidenceClosure
open AgenticAILabProof.Enterprise.SourceBoundFingerprintHistoryClosure
open AgenticAILabProof.Enterprise.SourceBoundFingerprintContentAddressClosure

/--
The current runtime frontier is an independent owner.  A content-addressed
history root does not by itself identify the runtime epoch in which a restore
may execute.
-/
structure SourceBoundCheckpointRestoreFrontier where
  frontierId : String
  canonicalRoot : CanonicalFingerprintHistoryIdentity
  latestEnvelope : SourceBoundFingerprintCheckpointEnvelope
  runtimeEpoch : Nat
  activeFenceToken : Nat
  provenanceDigest : String
  deriving Repr

/--
Ordinary v1 resume is intentionally latest-only.  Authorized rollback requires
a different explicit authority and is not smuggled into this request.
-/
structure SourceBoundLatestCheckpointRestoreRequest where
  requestId : String
  canonicalRoot : CanonicalFingerprintHistoryIdentity
  targetEnvelope : SourceBoundFingerprintCheckpointEnvelope
  runtimeEpoch : Nat
  activeFenceToken : Nat
  provenanceDigest : String
  deriving Repr

structure SourceBoundCheckpointRestoreCoordinate where
  canonicalRoot : CanonicalFingerprintHistoryIdentity
  runtimeEpoch : Nat
  activeFenceToken : Nat
  deriving Repr

def checkpointRestoreCoordinateAt
    (canonicalRoot : CanonicalFingerprintHistoryIdentity)
    (runtimeEpoch activeFenceToken : Nat) :
    SourceBoundCheckpointRestoreCoordinate :=
  { canonicalRoot := canonicalRoot
    runtimeEpoch := runtimeEpoch
    activeFenceToken := activeFenceToken }

theorem sameCanonicalRootCanCarryDifferentRuntimeEpochs
    (canonicalRoot : CanonicalFingerprintHistoryIdentity) :
    (checkpointRestoreCoordinateAt canonicalRoot 6 8).canonicalRoot =
        (checkpointRestoreCoordinateAt canonicalRoot 7 8).canonicalRoot ∧
      (checkpointRestoreCoordinateAt canonicalRoot 6 8).runtimeEpoch ≠
        (checkpointRestoreCoordinateAt canonicalRoot 7 8).runtimeEpoch := by
  constructor
  · rfl
  · simp [checkpointRestoreCoordinateAt]

theorem sameCanonicalRootAndEpochCanCarryDifferentFenceTokens
    (canonicalRoot : CanonicalFingerprintHistoryIdentity)
    (runtimeEpoch : Nat) :
    (checkpointRestoreCoordinateAt canonicalRoot runtimeEpoch 8).canonicalRoot =
        (checkpointRestoreCoordinateAt canonicalRoot runtimeEpoch 9).canonicalRoot ∧
      (checkpointRestoreCoordinateAt canonicalRoot runtimeEpoch 8).runtimeEpoch =
        (checkpointRestoreCoordinateAt canonicalRoot runtimeEpoch 9).runtimeEpoch ∧
      (checkpointRestoreCoordinateAt canonicalRoot runtimeEpoch 8).activeFenceToken ≠
        (checkpointRestoreCoordinateAt canonicalRoot runtimeEpoch 9).activeFenceToken := by
  constructor
  · rfl
  · constructor
    · rfl
    · simp [checkpointRestoreCoordinateAt]

def latestCheckpointEnvelopeInCommitment
    (commitment : SourceBoundFingerprintHistoryCommitment)
    (target : SourceBoundFingerprintCheckpointEnvelope) : Prop :=
  ∃ first middle,
    commitment.envelopes = first :: (middle ++ [target])

structure SourceBoundLatestCheckpointRestoreRequestClosed
    (commitment : SourceBoundFingerprintHistoryCommitment)
    (frontier : SourceBoundCheckpointRestoreFrontier)
    (request : SourceBoundLatestCheckpointRestoreRequest) : Prop where
  targetIsLatest :
    latestCheckpointEnvelopeInCommitment commitment request.targetEnvelope
  frontierRootMatchesCommitment :
    frontier.canonicalRoot = commitment.canonicalRoot
  requestRootMatchesFrontier :
    request.canonicalRoot = frontier.canonicalRoot
  targetMatchesFrontier :
    request.targetEnvelope = frontier.latestEnvelope
  runtimeEpochMatches :
    request.runtimeEpoch = frontier.runtimeEpoch
  activeFenceTokenMatches :
    request.activeFenceToken = frontier.activeFenceToken
  frontierIdentityPresent : frontier.frontierId ≠ ""
  frontierProvenancePresent : frontier.provenanceDigest ≠ ""
  requestIdentityPresent : request.requestId ≠ ""
  requestProvenancePresent : request.provenanceDigest ≠ ""

structure SourceBoundCheckpointRestoreAuthorizationReceipt where
  authorizationId : String
  requestId : String
  policyEngineIdentity : String
  canonicalRoot : CanonicalFingerprintHistoryIdentity
  targetCanonicalIdentity : CanonicalFingerprintCheckpointIdentity
  runtimeEpoch : Nat
  activeFenceToken : Nat
  decisionAllows : Bool
  policyDecisionDigest : String
  evidenceDigest : String
  deriving Repr

def SourceBoundCheckpointRestoreAuthorizationReceiptValid :=
  SourceBoundCheckpointRestoreAuthorizationReceipt → Prop

def denyEveryCheckpointRestoreAuthorization :
    SourceBoundCheckpointRestoreAuthorizationReceiptValid :=
  fun _authorization => False

theorem integrityAndRestoreAuthorityRemainIndependent
    {integrityClosed : Prop}
    (integrity : integrityClosed)
    (authorization : SourceBoundCheckpointRestoreAuthorizationReceipt) :
    integrityClosed ∧
      ¬ denyEveryCheckpointRestoreAuthorization authorization := by
  constructor
  · exact integrity
  · simp [denyEveryCheckpointRestoreAuthorization]

structure SourceBoundCheckpointRestoreAuthorizationClosed
    (authorizationValid :
      SourceBoundCheckpointRestoreAuthorizationReceiptValid)
    (request : SourceBoundLatestCheckpointRestoreRequest)
    (authorization : SourceBoundCheckpointRestoreAuthorizationReceipt) : Prop where
  authorizationValidates : authorizationValid authorization
  decisionAllows : authorization.decisionAllows = true
  requestIdentityMatches :
    authorization.requestId = request.requestId
  canonicalRootMatches :
    authorization.canonicalRoot = request.canonicalRoot
  targetIdentityMatches :
    authorization.targetCanonicalIdentity =
      request.targetEnvelope.canonicalIdentity
  runtimeEpochMatches :
    authorization.runtimeEpoch = request.runtimeEpoch
  activeFenceTokenMatches :
    authorization.activeFenceToken = request.activeFenceToken
  authorizationIdentityPresent : authorization.authorizationId ≠ ""
  policyEngineIdentityPresent : authorization.policyEngineIdentity ≠ ""
  policyDecisionPresent : authorization.policyDecisionDigest ≠ ""
  evidencePresent : authorization.evidenceDigest ≠ ""

/--
Restore closure composes three independently owned facts:

1. history and content-address integrity;
2. latest-target/current-epoch binding;
3. policy authorization for that exact request.
-/
structure SourceBoundCheckpointRestoreEvidenceClosed
    (digestValid : SourceBoundFingerprintHistoryDigestReceiptValid)
    (authorizationValid :
      SourceBoundCheckpointRestoreAuthorizationReceiptValid)
    (progress : SourceBoundProgressReceipt)
    (evidence : SubjectProgressEvidence)
    (history : SourceBoundSemanticFingerprintHistory)
    (commitment : SourceBoundFingerprintHistoryCommitment)
    (digestReceipt : SourceBoundFingerprintHistoryDigestReceipt)
    (frontier : SourceBoundCheckpointRestoreFrontier)
    (request : SourceBoundLatestCheckpointRestoreRequest)
    (authorization : SourceBoundCheckpointRestoreAuthorizationReceipt) : Prop where
  contentAddressCloses :
    SourceBoundFingerprintHistoryContentAddressEvidenceClosed
      digestValid progress evidence history commitment digestReceipt
  restoreRequestCloses :
    SourceBoundLatestCheckpointRestoreRequestClosed
      commitment frontier request
  restoreAuthorizationCloses :
    SourceBoundCheckpointRestoreAuthorizationClosed
      authorizationValid request authorization

theorem closedRestoreRequestBindsCurrentRuntimeEpoch
    {commitment : SourceBoundFingerprintHistoryCommitment}
    {frontier : SourceBoundCheckpointRestoreFrontier}
    {request : SourceBoundLatestCheckpointRestoreRequest}
    (closed :
      SourceBoundLatestCheckpointRestoreRequestClosed
        commitment frontier request) :
    request.runtimeEpoch = frontier.runtimeEpoch :=
  closed.runtimeEpochMatches

theorem closedRestoreRequestBindsCurrentFenceToken
    {commitment : SourceBoundFingerprintHistoryCommitment}
    {frontier : SourceBoundCheckpointRestoreFrontier}
    {request : SourceBoundLatestCheckpointRestoreRequest}
    (closed :
      SourceBoundLatestCheckpointRestoreRequestClosed
        commitment frontier request) :
    request.activeFenceToken = frontier.activeFenceToken :=
  closed.activeFenceTokenMatches

theorem closedRestoreAuthorizationBindsExactRequest
    {authorizationValid :
      SourceBoundCheckpointRestoreAuthorizationReceiptValid}
    {request : SourceBoundLatestCheckpointRestoreRequest}
    {authorization : SourceBoundCheckpointRestoreAuthorizationReceipt}
    (closed :
      SourceBoundCheckpointRestoreAuthorizationClosed
        authorizationValid request authorization) :
    authorization.requestId = request.requestId ∧
      authorization.canonicalRoot = request.canonicalRoot ∧
      authorization.targetCanonicalIdentity =
        request.targetEnvelope.canonicalIdentity ∧
      authorization.runtimeEpoch = request.runtimeEpoch ∧
      authorization.activeFenceToken = request.activeFenceToken :=
  ⟨closed.requestIdentityMatches,
    closed.canonicalRootMatches,
    closed.targetIdentityMatches,
    closed.runtimeEpochMatches,
    closed.activeFenceTokenMatches⟩

theorem closedRestoreEvidenceCarriesAllOwners
    {digestValid : SourceBoundFingerprintHistoryDigestReceiptValid}
    {authorizationValid :
      SourceBoundCheckpointRestoreAuthorizationReceiptValid}
    {progress : SourceBoundProgressReceipt}
    {evidence : SubjectProgressEvidence}
    {history : SourceBoundSemanticFingerprintHistory}
    {commitment : SourceBoundFingerprintHistoryCommitment}
    {digestReceipt : SourceBoundFingerprintHistoryDigestReceipt}
    {frontier : SourceBoundCheckpointRestoreFrontier}
    {request : SourceBoundLatestCheckpointRestoreRequest}
    {authorization : SourceBoundCheckpointRestoreAuthorizationReceipt}
    (closed :
      SourceBoundCheckpointRestoreEvidenceClosed
        digestValid authorizationValid progress evidence history commitment
        digestReceipt frontier request authorization) :
    SourceBoundFingerprintHistoryContentAddressEvidenceClosed
        digestValid progress evidence history commitment digestReceipt ∧
      SourceBoundLatestCheckpointRestoreRequestClosed
        commitment frontier request ∧
      SourceBoundCheckpointRestoreAuthorizationClosed
        authorizationValid request authorization :=
  ⟨closed.contentAddressCloses,
    closed.restoreRequestCloses,
    closed.restoreAuthorizationCloses⟩

theorem independentlyClosedRestoreOwnersCompose
    {contentClosure requestClosure authorizationClosure : Prop}
    (contentClosed : contentClosure)
    (requestClosed : requestClosure)
    (authorizationClosed : authorizationClosure) :
    contentClosure ∧ requestClosure ∧ authorizationClosure :=
  ⟨contentClosed, requestClosed, authorizationClosed⟩

def sourceBoundCheckpointRestoreFrontierA :
    SourceBoundCheckpointRestoreFrontier :=
  { frontierId := "source-bound-checkpoint-restore-frontier-a"
    canonicalRoot := sourceBoundFingerprintHistoryCommitmentA.canonicalRoot
    latestEnvelope := sourceBoundCurrentCheckpointEnvelopeA
    runtimeEpoch := 7
    activeFenceToken := 8
    provenanceDigest := "source-bound-checkpoint-restore-frontier-provenance-a" }

def staleSourceBoundLatestCheckpointRestoreRequestA :
    SourceBoundLatestCheckpointRestoreRequest :=
  { requestId := "stale-source-bound-latest-checkpoint-restore-request-a"
    canonicalRoot := sourceBoundCheckpointRestoreFrontierA.canonicalRoot
    targetEnvelope := sourceBoundCheckpointRestoreFrontierA.latestEnvelope
    runtimeEpoch := 6
    activeFenceToken := sourceBoundCheckpointRestoreFrontierA.activeFenceToken
    provenanceDigest := "stale-source-bound-checkpoint-restore-request-a" }

theorem matchingCanonicalRootDoesNotProveCurrentRuntimeEpoch :
    staleSourceBoundLatestCheckpointRestoreRequestA.canonicalRoot =
        sourceBoundCheckpointRestoreFrontierA.canonicalRoot ∧
      staleSourceBoundLatestCheckpointRestoreRequestA.runtimeEpoch ≠
        sourceBoundCheckpointRestoreFrontierA.runtimeEpoch := by
  constructor
  · rfl
  · decide

def sourceBoundLatestCheckpointRestoreRequestA :
    SourceBoundLatestCheckpointRestoreRequest :=
  { requestId := "source-bound-latest-checkpoint-restore-request-a"
    canonicalRoot := sourceBoundCheckpointRestoreFrontierA.canonicalRoot
    targetEnvelope := sourceBoundCheckpointRestoreFrontierA.latestEnvelope
    runtimeEpoch := sourceBoundCheckpointRestoreFrontierA.runtimeEpoch
    activeFenceToken := sourceBoundCheckpointRestoreFrontierA.activeFenceToken
    provenanceDigest := "source-bound-checkpoint-restore-request-provenance-a" }

theorem sourceBoundLatestCheckpointRestoreRequestACloses :
    SourceBoundLatestCheckpointRestoreRequestClosed
      sourceBoundFingerprintHistoryCommitmentA
      sourceBoundCheckpointRestoreFrontierA
      sourceBoundLatestCheckpointRestoreRequestA := by
  constructor
  · refine ⟨sourceBoundPreviousCheckpointEnvelopeA, [], ?_⟩
    simp [
      sourceBoundFingerprintHistoryCommitmentA,
      sourceBoundLatestCheckpointRestoreRequestA,
      sourceBoundCheckpointRestoreFrontierA
    ]
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · decide
  · decide
  · decide
  · decide

def sourceBoundCheckpointRestoreAuthorizationReceiptA :
    SourceBoundCheckpointRestoreAuthorizationReceipt :=
  { authorizationId := "source-bound-checkpoint-restore-authorization-a"
    requestId := sourceBoundLatestCheckpointRestoreRequestA.requestId
    policyEngineIdentity := "cedadr-dual-engine"
    canonicalRoot := sourceBoundLatestCheckpointRestoreRequestA.canonicalRoot
    targetCanonicalIdentity :=
      sourceBoundLatestCheckpointRestoreRequestA.targetEnvelope.canonicalIdentity
    runtimeEpoch := sourceBoundLatestCheckpointRestoreRequestA.runtimeEpoch
    activeFenceToken :=
      sourceBoundLatestCheckpointRestoreRequestA.activeFenceToken
    decisionAllows := true
    policyDecisionDigest := "cedadr-policy-decision-a"
    evidenceDigest := "source-bound-checkpoint-restore-authorization-evidence-a" }

def sourceBoundCheckpointRestoreAuthorizationReceiptValidA :
    SourceBoundCheckpointRestoreAuthorizationReceiptValid :=
  fun authorization =>
    authorization = sourceBoundCheckpointRestoreAuthorizationReceiptA

theorem contentAddressClosureDoesNotProvideRestoreAuthorization :
    SourceBoundFingerprintHistoryContentAddressEvidenceClosed
        sourceBoundFingerprintHistoryDigestReceiptValidA
        sourceBoundCycleProgressReceipt
        progressEvidenceA
        sourceBoundProgressHistoryA
        sourceBoundFingerprintHistoryCommitmentA
        sourceBoundFingerprintHistoryDigestReceiptA ∧
      ¬ denyEveryCheckpointRestoreAuthorization
        sourceBoundCheckpointRestoreAuthorizationReceiptA := by
  constructor
  · exact sourceBoundFingerprintHistoryContentAddressEvidenceACloses
  · simp [denyEveryCheckpointRestoreAuthorization]

theorem sourceBoundCheckpointRestoreAuthorizationACloses :
    SourceBoundCheckpointRestoreAuthorizationClosed
      sourceBoundCheckpointRestoreAuthorizationReceiptValidA
      sourceBoundLatestCheckpointRestoreRequestA
      sourceBoundCheckpointRestoreAuthorizationReceiptA := by
  constructor
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · decide
  · decide
  · decide
  · decide

theorem sourceBoundCheckpointRestoreEvidenceACloses :
    SourceBoundCheckpointRestoreEvidenceClosed
      sourceBoundFingerprintHistoryDigestReceiptValidA
      sourceBoundCheckpointRestoreAuthorizationReceiptValidA
      sourceBoundCycleProgressReceipt
      progressEvidenceA
      sourceBoundProgressHistoryA
      sourceBoundFingerprintHistoryCommitmentA
      sourceBoundFingerprintHistoryDigestReceiptA
      sourceBoundCheckpointRestoreFrontierA
      sourceBoundLatestCheckpointRestoreRequestA
      sourceBoundCheckpointRestoreAuthorizationReceiptA :=
  ⟨sourceBoundFingerprintHistoryContentAddressEvidenceACloses,
    sourceBoundLatestCheckpointRestoreRequestACloses,
    sourceBoundCheckpointRestoreAuthorizationACloses⟩

end AgenticAILabProof.Enterprise.SourceBoundCheckpointRestoreAuthorizationClosure
