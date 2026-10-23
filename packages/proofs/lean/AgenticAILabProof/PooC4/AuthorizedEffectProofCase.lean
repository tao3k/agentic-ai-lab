-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Generated.ProofCaseVector

namespace AgenticAILabProof.PooC4.AuthorizedEffectProofCase

open AgenticAILabProof.Generated.ProofCaseVector

deriving instance DecidableEq for Except

inductive DecodeError where
  | abiVersionMismatch
  | schemaFingerprintMismatch
  | unsupportedCaseKind
  | unsupportedMediationOutcome
  | unsupportedDurabilityProfile
  | unsupportedObligation
  | malformedDigest
  | malformedEvidence
deriving Repr, DecidableEq

inductive CaseKind where
  | authorizedEffectToken
deriving Repr, DecidableEq

inductive MediationOutcome where
  | allow
  | deny
  | invalidToken
deriving Repr, DecidableEq

inductive DurabilityProfile where
  | strict
  | batched
  | diagnostic
deriving Repr, DecidableEq

structure Digest32 where
  bytes : List UInt8
  size_eq : bytes.length = 32
deriving Repr, DecidableEq

instance : Nonempty Digest32 :=
  ⟨{ bytes := List.replicate 32 0, size_eq := by simp }⟩

def Digest32.NonZero (digest : Digest32) : Prop :=
  digest.bytes ≠ List.replicate 32 0

structure RawProofCaseVector where
  abiVersion : UInt32
  caseKind : UInt32
  schemaFingerprintHex : String
  tokenDigest : List UInt8
  policyRevision : List UInt8
  effectDigest : List UInt8
  semanticRoot : List UInt8
  executionRoot : List UInt8
  batchRoot : List UInt8
  subjectBinding : List UInt8
  resourceBinding : List UInt8
  actionBinding : List UInt8
  previousEvidenceRoot : List UInt8
  nonce : UInt64
  epoch : UInt64
  sequence : UInt64
  requiredObligationMask : UInt64
  presentObligationMask : UInt64
  obligationCount : UInt32
  mediationOutcome : UInt32
  durabilityProfile : UInt32
  reservedZero : Bool
deriving Repr, DecidableEq

structure ProofCaseVector where
  caseKind : CaseKind
  tokenDigest : Digest32
  policyRevision : Digest32
  effectDigest : Digest32
  semanticRoot : Digest32
  executionRoot : Digest32
  batchRoot : Digest32
  subjectBinding : Digest32
  resourceBinding : Digest32
  actionBinding : Digest32
  previousEvidenceRoot : Digest32
  nonce : UInt64
  epoch : UInt64
  sequence : UInt64
  requiredObligationMask : UInt64
  presentObligationMask : UInt64
  obligationCount : UInt32
  mediationOutcome : MediationOutcome
  durabilityProfile : DurabilityProfile
deriving Repr, DecidableEq

def decodeDigest (bytes : List UInt8) : Except DecodeError Digest32 :=
  if h : bytes.length = 32 then
    .ok { bytes := bytes, size_eq := h }
  else
    .error .malformedDigest

def decodeCaseKind (tag : UInt32) : Except DecodeError CaseKind :=
  if tag = caseKindAuthorizedEffectToken then
    .ok .authorizedEffectToken
  else
    .error .unsupportedCaseKind

def decodeMediationOutcome
    (tag : UInt32) : Except DecodeError MediationOutcome :=
  if tag = mediationAllow then
    .ok .allow
  else if tag = mediationDeny then
    .ok .deny
  else if tag = mediationInvalidToken then
    .ok .invalidToken
  else
    .error .unsupportedMediationOutcome

def decodeDurabilityProfile
    (tag : UInt32) : Except DecodeError DurabilityProfile :=
  if tag = durabilityStrict then
    .ok .strict
  else if tag = durabilityBatched then
    .ok .batched
  else if tag = durabilityDiagnostic then
    .ok .diagnostic
  else
    .error .unsupportedDurabilityProfile

def decode (raw : RawProofCaseVector) : Except DecodeError ProofCaseVector := do
  if raw.abiVersion ≠ abiVersion then
    throw .abiVersionMismatch
  if raw.schemaFingerprintHex ≠ schemaFingerprintHex then
    throw .schemaFingerprintMismatch
  if raw.requiredObligationMask > requiredObligationMask ||
      raw.presentObligationMask > requiredObligationMask then
    throw .unsupportedObligation
  if raw.obligationCount > 8 || !raw.reservedZero then
    throw .malformedEvidence
  let caseKind ← decodeCaseKind raw.caseKind
  let mediationOutcome ← decodeMediationOutcome raw.mediationOutcome
  let durabilityProfile ← decodeDurabilityProfile raw.durabilityProfile
  let tokenDigest ← decodeDigest raw.tokenDigest
  let policyRevision ← decodeDigest raw.policyRevision
  let effectDigest ← decodeDigest raw.effectDigest
  let semanticRoot ← decodeDigest raw.semanticRoot
  let executionRoot ← decodeDigest raw.executionRoot
  let batchRoot ← decodeDigest raw.batchRoot
  let subjectBinding ← decodeDigest raw.subjectBinding
  let resourceBinding ← decodeDigest raw.resourceBinding
  let actionBinding ← decodeDigest raw.actionBinding
  let previousEvidenceRoot ← decodeDigest raw.previousEvidenceRoot
  pure {
    caseKind := caseKind
    tokenDigest := tokenDigest
    policyRevision := policyRevision
    effectDigest := effectDigest
    semanticRoot := semanticRoot
    executionRoot := executionRoot
    batchRoot := batchRoot
    subjectBinding := subjectBinding
    resourceBinding := resourceBinding
    actionBinding := actionBinding
    previousEvidenceRoot := previousEvidenceRoot
    nonce := raw.nonce
    epoch := raw.epoch
    sequence := raw.sequence
    requiredObligationMask := raw.requiredObligationMask
    presentObligationMask := raw.presentObligationMask
    obligationCount := raw.obligationCount
    mediationOutcome := mediationOutcome
    durabilityProfile := durabilityProfile
  }

def CompleteAuthorizedEffect (vector : ProofCaseVector) : Prop :=
  vector.caseKind = .authorizedEffectToken ∧
  vector.requiredObligationMask = requiredObligationMask ∧
  vector.presentObligationMask = requiredObligationMask ∧
  vector.obligationCount = 8 ∧
  vector.mediationOutcome = .allow ∧
  vector.durabilityProfile ≠ .diagnostic ∧
  vector.tokenDigest.NonZero ∧
  vector.policyRevision.NonZero ∧
  vector.effectDigest.NonZero ∧
  vector.semanticRoot.NonZero ∧
  vector.executionRoot.NonZero

instance (vector : ProofCaseVector) : Decidable (CompleteAuthorizedEffect vector) := by
  unfold CompleteAuthorizedEffect Digest32.NonZero
  infer_instance

theorem completeByVerifiedBindings
    (vector : ProofCaseVector)
    (hkind : vector.caseKind = .authorizedEffectToken)
    (hrequired : vector.requiredObligationMask = requiredObligationMask)
    (hpresent : vector.presentObligationMask = requiredObligationMask)
    (hcount : vector.obligationCount = 8)
    (hmediation : vector.mediationOutcome = .allow)
    (hdurability : vector.durabilityProfile ≠ .diagnostic)
    (htoken : vector.tokenDigest.NonZero)
    (hpolicy : vector.policyRevision.NonZero)
    (heffect : vector.effectDigest.NonZero)
    (hsemantic : vector.semanticRoot.NonZero)
    (hexecution : vector.executionRoot.NonZero) :
    CompleteAuthorizedEffect vector := by
  exact ⟨hkind, hrequired, hpresent, hcount, hmediation, hdurability,
    htoken, hpolicy, heffect, hsemantic, hexecution⟩

theorem missingObligationRejectsComplete
    (vector : ProofCaseVector)
    (hmissing : vector.presentObligationMask ≠ requiredObligationMask) :
    ¬ CompleteAuthorizedEffect vector := by
  intro complete
  exact hmissing complete.2.2.1

theorem diagnosticRejectsComplete
    (vector : ProofCaseVector)
    (hdiagnostic : vector.durabilityProfile = .diagnostic) :
    ¬ CompleteAuthorizedEffect vector := by
  intro complete
  exact complete.2.2.2.2.2.1 hdiagnostic

theorem deniedMediationRejectsComplete
    (vector : ProofCaseVector)
    (hdenied : vector.mediationOutcome = .deny) :
    ¬ CompleteAuthorizedEffect vector := by
  intro complete
  have hallow := complete.2.2.2.2.1
  rw [hdenied] at hallow
  cases hallow

theorem zeroSemanticRootRejectsComplete
    (vector : ProofCaseVector)
    (hzero : vector.semanticRoot.bytes = List.replicate 32 0) :
    ¬ CompleteAuthorizedEffect vector := by
  intro complete
  exact complete.2.2.2.2.2.2.2.2.2.1 hzero

def uint32LE (value : UInt32) : List UInt8 :=
  [value.toUInt8, (value >>> 8).toUInt8, (value >>> 16).toUInt8,
    (value >>> 24).toUInt8]

def uint64LE (value : UInt64) : List UInt8 :=
  [value.toUInt8, (value >>> 8).toUInt8, (value >>> 16).toUInt8,
    (value >>> 24).toUInt8, (value >>> 32).toUInt8,
    (value >>> 40).toUInt8, (value >>> 48).toUInt8,
    (value >>> 56).toUInt8]

def caseKindTag : CaseKind → UInt32
  | .authorizedEffectToken => caseKindAuthorizedEffectToken

def mediationOutcomeTag : MediationOutcome → UInt32
  | .allow => mediationAllow
  | .deny => mediationDeny
  | .invalidToken => mediationInvalidToken

def durabilityProfileTag : DurabilityProfile → UInt32
  | .strict => durabilityStrict
  | .batched => durabilityBatched
  | .diagnostic => durabilityDiagnostic

private theorem uint32LE_length (value : UInt32) : (uint32LE value).length = 4 := rfl
private theorem uint64LE_length (value : UInt64) : (uint64LE value).length = 8 := rfl
private theorem fingerprint_length : schemaFingerprintBytes.length = 32 := rfl

def encodeProofCaseVector (vector : ProofCaseVector) : List UInt8 :=
  List.flatten [
    uint32LE abiVersion,
    uint32LE (caseKindTag vector.caseKind),
    schemaFingerprintBytes,
    vector.tokenDigest.bytes,
    vector.policyRevision.bytes,
    vector.effectDigest.bytes,
    vector.semanticRoot.bytes,
    vector.executionRoot.bytes,
    vector.batchRoot.bytes,
    vector.subjectBinding.bytes,
    vector.resourceBinding.bytes,
    vector.actionBinding.bytes,
    vector.previousEvidenceRoot.bytes,
    uint64LE vector.nonce,
    uint64LE vector.epoch,
    uint64LE vector.sequence,
    uint64LE vector.requiredObligationMask,
    uint64LE vector.presentObligationMask,
    uint32LE vector.obligationCount,
    uint32LE (mediationOutcomeTag vector.mediationOutcome),
    uint32LE (durabilityProfileTag vector.durabilityProfile),
    List.replicate 12 0]

/-- The chunk representation preserves the original ABI byte order for every vector. -/
theorem encodeProofCaseVector_byte_order (vector : ProofCaseVector) :
    encodeProofCaseVector vector =
  uint32LE abiVersion ++
  uint32LE (caseKindTag vector.caseKind) ++
  schemaFingerprintBytes ++
  vector.tokenDigest.bytes ++
  vector.policyRevision.bytes ++
  vector.effectDigest.bytes ++
  vector.semanticRoot.bytes ++
  vector.executionRoot.bytes ++
  vector.batchRoot.bytes ++
  vector.subjectBinding.bytes ++
  vector.resourceBinding.bytes ++
  vector.actionBinding.bytes ++
  vector.previousEvidenceRoot.bytes ++
  uint64LE vector.nonce ++
  uint64LE vector.epoch ++
  uint64LE vector.sequence ++
  uint64LE vector.requiredObligationMask ++
  uint64LE vector.presentObligationMask ++
  uint32LE vector.obligationCount ++
  uint32LE (mediationOutcomeTag vector.mediationOutcome) ++
  uint32LE (durabilityProfileTag vector.durabilityProfile) ++
  List.replicate 12 0 := by
  simp only [encodeProofCaseVector, List.flatten_cons, List.flatten_nil, List.append_nil,
    List.append_assoc]

theorem encodeProofCaseVector_size (vector : ProofCaseVector) :
    (encodeProofCaseVector vector).length = vectorSize := by
  simp only [encodeProofCaseVector, List.length_flatten, List.map_cons, List.map_nil,
    List.sum_cons, List.sum_nil, List.length_replicate,
    uint32LE_length, uint64LE_length, fingerprint_length,
    vector.tokenDigest.size_eq, vector.policyRevision.size_eq, vector.effectDigest.size_eq,
    vector.semanticRoot.size_eq, vector.executionRoot.size_eq, vector.batchRoot.size_eq,
    vector.subjectBinding.size_eq, vector.resourceBinding.size_eq,
    vector.actionBinding.size_eq, vector.previousEvidenceRoot.size_eq] <;> rfl

def domainSeparatedPayload (domain : String) (payload : List UInt8) : List UInt8 :=
  domain.toUTF8.toList ++ [0] ++ payload

def authorizedEffectTheoremSetPayload : List UInt8 :=
  domainSeparatedPayload theoremSetDigestDomain
    (String.intercalate "\n" authorizedEffectTheoremNames).toUTF8.toList

noncomputable section

/-- Trusted SHA-256 primitive. Executable runtimes discharge this boundary
    through their native digest provider and differential gates. -/
opaque sha256Digest (payload : List UInt8) : Digest32

def proofVectorDigest (vector : ProofCaseVector) : Digest32 :=
  sha256Digest (domainSeparatedPayload vectorDigestDomain
    (encodeProofCaseVector vector))

def authorizedEffectTheoremSetDigest : Digest32 :=
  sha256Digest authorizedEffectTheoremSetPayload

structure ProofReceipt where
  vectorDigest : Digest32
  theoremSetDigest : Digest32
  semanticRoot : Digest32
  executionRoot : Digest32
  batchRoot : Digest32
  nonce : UInt64
  epoch : UInt64
deriving Repr, DecidableEq

def verifiedProofReceipt
    (vector : ProofCaseVector)
    (_verified : CompleteAuthorizedEffect vector) : ProofReceipt :=
  {
    vectorDigest := proofVectorDigest vector
    theoremSetDigest := authorizedEffectTheoremSetDigest
    semanticRoot := vector.semanticRoot
    executionRoot := vector.executionRoot
    batchRoot := vector.batchRoot
    nonce := vector.nonce
    epoch := vector.epoch
  }

end

end AgenticAILabProof.PooC4.AuthorizedEffectProofCase
