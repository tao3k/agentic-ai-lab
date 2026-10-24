-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.AuthorizedEffectProofCase

namespace AgenticAILabProof.Generated.AuthorizedEffectProofCase

open AgenticAILabProof.Generated.ProofCaseVector
open AgenticAILabProof.PooC4.AuthorizedEffectProofCase

def digest (value : UInt8) : Digest32 :=
  { bytes := List.replicate 32 value, size_eq := by simp }

def validVector : ProofCaseVector where
  caseKind := .authorizedEffectToken
  tokenDigest := digest 0x11
  policyRevision := digest 0x22
  effectDigest := digest 0x33
  semanticRoot := digest 0x44
  executionRoot := digest 0x55
  batchRoot := digest 0x00
  subjectBinding := digest 0x66
  resourceBinding := digest 0x77
  actionBinding := digest 0x88
  previousEvidenceRoot := digest 0x99
  nonce := 11
  epoch := 4
  sequence := 19
  requiredObligationMask := requiredObligationMask
  presentObligationMask := requiredObligationMask
  obligationCount := 8
  mediationOutcome := .allow
  durabilityProfile := .strict

theorem validVectorComplete : CompleteAuthorizedEffect validVector := by
  native_decide

def validRaw : RawProofCaseVector where
  abiVersion := abiVersion
  caseKind := caseKindAuthorizedEffectToken
  schemaFingerprintHex := schemaFingerprintHex
  tokenDigest := (digest 0x11).bytes
  policyRevision := (digest 0x22).bytes
  effectDigest := (digest 0x33).bytes
  semanticRoot := (digest 0x44).bytes
  executionRoot := (digest 0x55).bytes
  batchRoot := (digest 0x00).bytes
  subjectBinding := (digest 0x66).bytes
  resourceBinding := (digest 0x77).bytes
  actionBinding := (digest 0x88).bytes
  previousEvidenceRoot := (digest 0x99).bytes
  nonce := 11
  epoch := 4
  sequence := 19
  requiredObligationMask := requiredObligationMask
  presentObligationMask := requiredObligationMask
  obligationCount := 8
  mediationOutcome := mediationAllow
  durabilityProfile := durabilityStrict
  reservedZero := true

theorem validRawDecodes : decode validRaw = .ok validVector := by
  native_decide

def invalidSchemaRaw : RawProofCaseVector :=
  { validRaw with schemaFingerprintHex := "invalid" }

theorem invalidSchemaRejected :
    decode invalidSchemaRaw = .error .schemaFingerprintMismatch := by
  native_decide

def unsupportedObligationRaw : RawProofCaseVector :=
  { validRaw with requiredObligationMask := 0x100 }

theorem unsupportedObligationRejected :
    decode unsupportedObligationRaw = .error .unsupportedObligation := by
  native_decide

def malformedDigestRaw : RawProofCaseVector :=
  { validRaw with semanticRoot := List.replicate 31 4 }

theorem malformedDigestRejected :
    decode malformedDigestRaw = .error .malformedDigest := by
  native_decide

def malformedSubjectBindingRaw : RawProofCaseVector :=
  { validRaw with subjectBinding := List.replicate 31 7 }

theorem malformedSubjectBindingRejected :
    decode malformedSubjectBindingRaw = .error .malformedDigest := by
  native_decide

def diagnosticVector : ProofCaseVector :=
  { validVector with durabilityProfile := .diagnostic }

theorem diagnosticVectorRejected :
    ¬ CompleteAuthorizedEffect diagnosticVector :=
  diagnosticRejectsComplete diagnosticVector rfl

def missingObligationVector : ProofCaseVector :=
  { validVector with presentObligationMask := 0x7f }

theorem missingObligationVectorRejected :
    ¬ CompleteAuthorizedEffect missingObligationVector :=
  missingObligationRejectsComplete missingObligationVector (by native_decide)

noncomputable def validProofReceipt : ProofReceipt :=
  verifiedProofReceipt validVector validVectorComplete

theorem validVectorHasCanonicalSize :
    (encodeProofCaseVector validVector).length = vectorSize := by
  native_decide

theorem validVectorMatchesCanonicalPositiveBytes :
    encodeProofCaseVector validVector = canonicalPositiveVectorBytes := by
  native_decide

theorem validReceiptDerivesVectorDigest :
    validProofReceipt.vectorDigest = proofVectorDigest validVector := rfl

theorem validReceiptDerivesTheoremSetDigest :
    validProofReceipt.theoremSetDigest = authorizedEffectTheoremSetDigest := rfl

theorem validReceiptBindsSemanticRoot :
    validProofReceipt.semanticRoot = validVector.semanticRoot := rfl

theorem validReceiptBindsExecutionRoot :
    validProofReceipt.executionRoot = validVector.executionRoot := rfl

theorem validDecodeBindsSubject :
    (decode validRaw).map (fun vector => vector.subjectBinding) =
      .ok validVector.subjectBinding := by
  native_decide

theorem validDecodeBindsResource :
    (decode validRaw).map (fun vector => vector.resourceBinding) =
      .ok validVector.resourceBinding := by
  native_decide

theorem validDecodeBindsAction :
    (decode validRaw).map (fun vector => vector.actionBinding) =
      .ok validVector.actionBinding := by
  native_decide

end AgenticAILabProof.Generated.AuthorizedEffectProofCase
