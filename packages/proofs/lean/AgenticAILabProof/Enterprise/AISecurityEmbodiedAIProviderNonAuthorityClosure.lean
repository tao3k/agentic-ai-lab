-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.AISecurityFourAuthorityLayerClosure

namespace AgenticAILabProof.Enterprise.AISecurityEmbodiedAIProviderNonAuthorityClosure

inductive IssuerKind where
  | aiProvider
  | humanAuthority
  | organizationalAuthority
  deriving DecidableEq, Repr

inductive AuthorityRole where
  | effectAuthorization
  | verificationDischarge
  | residualRiskAcceptance
  deriving DecidableEq, Repr

structure AuthorityEnvelope where
  issuerKind : IssuerKind
  grants : AuthorityRole → Bool

def roleOnlyAdmission
    (envelope : AuthorityEnvelope)
    (role : AuthorityRole) : Prop :=
  envelope.grants role = true

def admittedFor
    (envelope : AuthorityEnvelope)
    (role : AuthorityRole) : Prop :=
  envelope.issuerKind ≠ .aiProvider ∧ envelope.grants role = true

def forgedProviderEnvelope : AuthorityEnvelope where
  issuerKind := .aiProvider
  grants := fun role => decide (role = .effectAuthorization)

theorem roleOnlyAdmissionAcceptsForgedProvider :
    roleOnlyAdmission forgedProviderEnvelope .effectAuthorization := by
  simp [roleOnlyAdmission, forgedProviderEnvelope]

theorem issuerAwareAdmissionRejectsForgedProvider :
    ¬ admittedFor forgedProviderEnvelope .effectAuthorization := by
  simp [admittedFor, forgedProviderEnvelope]

theorem aiProviderCannotAuthorizeEffect
    (envelope : AuthorityEnvelope)
    (issuer : envelope.issuerKind = .aiProvider) :
    ¬ admittedFor envelope .effectAuthorization := by
  intro admitted
  exact admitted.1 issuer

theorem aiProviderCannotDischargeVerification
    (envelope : AuthorityEnvelope)
    (issuer : envelope.issuerKind = .aiProvider) :
    ¬ admittedFor envelope .verificationDischarge := by
  intro admitted
  exact admitted.1 issuer

theorem aiProviderCannotAcceptResidualRisk
    (envelope : AuthorityEnvelope)
    (issuer : envelope.issuerKind = .aiProvider) :
    ¬ admittedFor envelope .residualRiskAcceptance := by
  intro admitted
  exact admitted.1 issuer

def EASE005FormalBound : Prop :=
  ∀ envelope : AuthorityEnvelope,
    envelope.issuerKind = .aiProvider →
      ¬ admittedFor envelope .effectAuthorization ∧
      ¬ admittedFor envelope .verificationDischarge ∧
      ¬ admittedFor envelope .residualRiskAcceptance

theorem ease005FormalBound : EASE005FormalBound := by
  intro envelope issuer
  exact ⟨
    aiProviderCannotAuthorizeEffect envelope issuer,
    aiProviderCannotDischargeVerification envelope issuer,
    aiProviderCannotAcceptResidualRisk envelope issuer
  ⟩

end AgenticAILabProof.Enterprise.AISecurityEmbodiedAIProviderNonAuthorityClosure
