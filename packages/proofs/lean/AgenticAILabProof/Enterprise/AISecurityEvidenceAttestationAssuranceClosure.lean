-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.AISecurityExternalFrameworkMappingBundleClosure

namespace AgenticAILabProof.Enterprise

/-!
Digest integrity and semantic replay are necessary but insufficient for
enterprise admission.  This file keeps artifact integrity, typed statement
binding, issuer authentication, and transparency inclusion as separate
assurance facts.
-/

structure EvidenceSubject where
  artifactName : String
  artifactDigest : String
  deriving DecidableEq, Repr

structure TypedEvidenceStatement where
  subject : EvidenceSubject
  predicateType : String
  predicateDigest : String
  owner : String
  deriving DecidableEq, Repr

def TypedEvidenceStatement.subjectPredicateBinding
    (statement : TypedEvidenceStatement) :
    String × String × String :=
  (
    statement.subject.artifactDigest,
    statement.predicateType,
    statement.predicateDigest
  )

theorem EvidenceStatementBindsSubjectAndPredicate
    (statement : TypedEvidenceStatement) :
    statement.subjectPredicateBinding =
      (
        statement.subject.artifactDigest,
        statement.predicateType,
        statement.predicateDigest
      ) := by
  rfl

structure AuthenticatedEvidenceEnvelope where
  statementDigest : String
  issuerIdentity : String
  signatureEvidenceRoot : String
  deriving DecidableEq, Repr

def AuthenticatedEvidenceEnvelope.issuerStatementBinding
    (envelope : AuthenticatedEvidenceEnvelope) :
    String × String :=
  (envelope.issuerIdentity, envelope.statementDigest)

theorem EvidenceEnvelopeBindsIssuerAndStatement
    (envelope : AuthenticatedEvidenceEnvelope) :
    envelope.issuerStatementBinding =
      (envelope.issuerIdentity, envelope.statementDigest) := by
  rfl

structure TransparentEvidenceReceipt where
  envelopeDigest : String
  transparencyServiceIdentity : String
  inclusionProofRoot : String
  registrationPolicyVersion : String
  deriving DecidableEq, Repr

def TransparentEvidenceReceipt.envelopeLogBinding
    (receipt : TransparentEvidenceReceipt) :
    String × String × String :=
  (
    receipt.envelopeDigest,
    receipt.transparencyServiceIdentity,
    receipt.inclusionProofRoot
  )

theorem TransparencyReceiptBindsEnvelopeAndLog
    (receipt : TransparentEvidenceReceipt) :
    receipt.envelopeLogBinding =
      (
        receipt.envelopeDigest,
        receipt.transparencyServiceIdentity,
        receipt.inclusionProofRoot
      ) := by
  rfl

structure EnterpriseArtifactAssuranceFacts where
  digestIntegrityVerified : Bool
  schemaSemanticReplayVerified : Bool
  issuerAuthenticated : Bool
  transparencyInclusionVerified : Bool
  deriving DecidableEq, Repr

def enterpriseArtifactAdmitted
    (facts : EnterpriseArtifactAssuranceFacts) : Bool :=
  facts.digestIntegrityVerified &&
    facts.schemaSemanticReplayVerified &&
    facts.issuerAuthenticated &&
    facts.transparencyInclusionVerified

def asrFrameworkMapping005CurrentAssurance :
    EnterpriseArtifactAssuranceFacts :=
  {
    digestIntegrityVerified := true
    schemaSemanticReplayVerified := false
    issuerAuthenticated := false
    transparencyInclusionVerified := false
  }

theorem DigestIntegrityAloneCannotAuthorizeEnterpriseAdmission :
    enterpriseArtifactAdmitted
      {
        digestIntegrityVerified := true
        schemaSemanticReplayVerified := false
        issuerAuthenticated := false
        transparencyInclusionVerified := false
      } = false := by
  rfl

theorem SemanticReplayWithoutIssuerCannotAuthorizeEnterpriseAdmission :
    enterpriseArtifactAdmitted
      {
        digestIntegrityVerified := true
        schemaSemanticReplayVerified := true
        issuerAuthenticated := false
        transparencyInclusionVerified := false
      } = false := by
  rfl

theorem AuthenticatedReceiptWithoutTransparencyCannotCloseFullAssurance :
    enterpriseArtifactAdmitted
      {
        digestIntegrityVerified := true
        schemaSemanticReplayVerified := true
        issuerAuthenticated := true
        transparencyInclusionVerified := false
      } = false := by
  rfl

theorem CompleteAttestationChainCanEnterEnterpriseAdmission :
    enterpriseArtifactAdmitted
      {
        digestIntegrityVerified := true
        schemaSemanticReplayVerified := true
        issuerAuthenticated := true
        transparencyInclusionVerified := true
      } = true := by
  rfl

theorem ASRFrameworkMapping005RemainsFailClosed :
    enterpriseArtifactAdmitted
      asrFrameworkMapping005CurrentAssurance = false := by
  rfl

end AgenticAILabProof.Enterprise
