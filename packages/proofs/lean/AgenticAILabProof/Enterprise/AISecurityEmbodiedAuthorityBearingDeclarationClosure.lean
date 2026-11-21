-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.CedarDualEngineAuthorization
import AgenticAILabProof.Enterprise.HumanAuthorityAccountability

namespace AgenticAILabProof.Enterprise.AISecurityEmbodiedAuthorityBearingDeclarationClosure

abbrev AuthorizationSubject :=
  AgenticAILabProof.Enterprise.CedarDualEngineAuthorization.AuthorizationSubject

/-- The three decisions that EASE-002 treats as separate authority acts. -/
inductive AuthorityAct where
  | executionAuthorization
  | verificationDischarge
  | residualRiskAcceptance
  deriving DecidableEq, Repr

/-- A provider may produce analysis, but it is not an authority issuer. -/
inductive IssuerKind where
  | humanAuthority
  | cedarEngine
  | leanEngine
  | aiProvider
  deriving DecidableEq, Repr

/--
An authority declaration is bound to the exact Cedar authorization subject and
to freshness/receipt evidence.  `roleDeclared` is retained only so the former
role-only admission can be represented as a countermodel.
-/
structure AuthorityDeclaration where
  act : AuthorityAct
  issuerKind : IssuerKind
  authorityId : String
  providerId : String
  subject : AuthorizationSubject
  currentSubject : AuthorizationSubject
  roleDeclared : Bool
  receiptValidated : Bool
  contextFresh : Bool

/-- Defective reference rule: a populated role is mistaken for authority. -/
def roleOnlyAdmission (declaration : AuthorityDeclaration) : Prop :=
  declaration.roleDeclared = true

/--
Repaired EASE-002 admission.  Authority is issuer-, identity-, subject-,
receipt-, and context-bound; no role name or provider declaration can replace
these obligations.
-/
def authorityBearingDeclaration (declaration : AuthorityDeclaration) : Prop :=
  declaration.roleDeclared = true ∧
    declaration.issuerKind ≠ .aiProvider ∧
    declaration.authorityId ≠ declaration.providerId ∧
    declaration.subject = declaration.currentSubject ∧
    declaration.receiptValidated = true ∧
    declaration.contextFresh = true

def forgedProviderExecution : AuthorityDeclaration :=
  { act := .executionAuthorization
    issuerKind := .aiProvider
    authorityId := "ease002-provider-1"
    providerId := "ease002-provider-1"
    subject := AgenticAILabProof.Enterprise.CedarDualEngineAuthorization.subjectA
    currentSubject := AgenticAILabProof.Enterprise.CedarDualEngineAuthorization.subjectA
    roleDeclared := true
    receiptValidated := false
    contextFresh := true }

theorem roleOnlyAdmissionAcceptsForgedProvider :
    roleOnlyAdmission forgedProviderExecution := by
  rfl

theorem forgedProviderDeclarationIsNotAuthorityBearing :
    ¬authorityBearingDeclaration forgedProviderExecution := by
  simp [authorityBearingDeclaration, forgedProviderExecution]

theorem roleDeclarationDoesNotImplyAuthority :
    roleOnlyAdmission forgedProviderExecution ∧
      ¬authorityBearingDeclaration forgedProviderExecution := by
  exact ⟨roleOnlyAdmissionAcceptsForgedProvider,
    forgedProviderDeclarationIsNotAuthorityBearing⟩

theorem aiProviderCannotBearAuthority
    (declaration : AuthorityDeclaration)
    (providerIssuer : declaration.issuerKind = .aiProvider) :
    ¬authorityBearingDeclaration declaration := by
  intro closed
  exact closed.2.1 providerIssuer

theorem aiProviderCannotAuthorizeExecution
    (declaration : AuthorityDeclaration)
    (_act : declaration.act = .executionAuthorization)
    (providerIssuer : declaration.issuerKind = .aiProvider) :
    ¬authorityBearingDeclaration declaration := by
  exact aiProviderCannotBearAuthority declaration providerIssuer

theorem aiProviderCannotDischargeVerification
    (declaration : AuthorityDeclaration)
    (_act : declaration.act = .verificationDischarge)
    (providerIssuer : declaration.issuerKind = .aiProvider) :
    ¬authorityBearingDeclaration declaration := by
  exact aiProviderCannotBearAuthority declaration providerIssuer

theorem aiProviderCannotAcceptResidualRisk
    (declaration : AuthorityDeclaration)
    (_act : declaration.act = .residualRiskAcceptance)
    (providerIssuer : declaration.issuerKind = .aiProvider) :
    ¬authorityBearingDeclaration declaration := by
  exact aiProviderCannotBearAuthority declaration providerIssuer

theorem staleContextRejectsAuthority
    (declaration : AuthorityDeclaration)
    (stale : declaration.contextFresh = false) :
    ¬authorityBearingDeclaration declaration := by
  intro closed
  have fresh : declaration.contextFresh = true := closed.2.2.2.2.2
  rw [stale] at fresh
  simp at fresh

theorem mismatchedSubjectRejectsAuthority
    (declaration : AuthorityDeclaration)
    (mismatch : declaration.subject ≠ declaration.currentSubject) :
    ¬authorityBearingDeclaration declaration := by
  intro closed
  exact mismatch closed.2.2.2.1

theorem unvalidatedReceiptRejectsAuthority
    (declaration : AuthorityDeclaration)
    (invalid : declaration.receiptValidated = false) :
    ¬authorityBearingDeclaration declaration := by
  intro closed
  have validated : declaration.receiptValidated = true := closed.2.2.2.2.1
  rw [invalid] at validated
  simp at validated

/-- Reuse the Cedar/Lean owner: closure supplies exact subject equality. -/
theorem cedarClosureProvidesSubjectBinding
    (semantics : AgenticAILabProof.Enterprise.CedarDualEngineAuthorization.DecisionSemantics)
    (valid : AgenticAILabProof.Enterprise.CedarDualEngineAuthorization.DecisionReceiptValid)
    (left right : AgenticAILabProof.Enterprise.CedarDualEngineAuthorization.DecisionReceipt)
    (closed : AgenticAILabProof.Enterprise.CedarDualEngineAuthorization.dualDecisionEvidenceClosed
      semantics valid left right) :
    left.subject = right.subject :=
  AgenticAILabProof.Enterprise.CedarDualEngineAuthorization.closedDualDecisionProvidesSubjectEquality
    semantics valid left right closed

/-- Reuse the Cedar/Lean owner: one engine replay is not independent evidence. -/
theorem cedarClosureProvidesIndependentEngines
    (semantics : AgenticAILabProof.Enterprise.CedarDualEngineAuthorization.DecisionSemantics)
    (valid : AgenticAILabProof.Enterprise.CedarDualEngineAuthorization.DecisionReceiptValid)
    (left right : AgenticAILabProof.Enterprise.CedarDualEngineAuthorization.DecisionReceipt)
    (closed : AgenticAILabProof.Enterprise.CedarDualEngineAuthorization.dualDecisionEvidenceClosed
      semantics valid left right) :
    left.engineId ≠ right.engineId :=
  AgenticAILabProof.Enterprise.CedarDualEngineAuthorization.closedDualDecisionProvidesDistinctEngines
    semantics valid left right closed

/-- Reuse Human Authority: accepted promotion returns subject-bound authority. -/
theorem humanClosureProvidesBoundAuthority
    (actors : AgenticAILabProof.Enterprise.HumanAuthorityAccountability.PromotionActors)
    (authorityValid : AgenticAILabProof.Enterprise.HumanAuthorityAccountability.AuthorityReceiptValid)
    (grant : AgenticAILabProof.Enterprise.HumanAuthorityAccountability.AuthorityGrant)
    (receipt : AgenticAILabProof.Enterprise.HumanAuthorityAccountability.BoundAuthorityReceipt)
    (subject : AuthorizationSubject)
    (closed : AgenticAILabProof.Enterprise.HumanAuthorityAccountability.humanPromotionEvidenceClosed
      actors authorityValid grant receipt subject) :
    receipt.subject = subject ∧
      AgenticAILabProof.Enterprise.HumanAuthorityAccountability.authorityEvidenceClosed
        authorityValid grant receipt :=
  AgenticAILabProof.Enterprise.HumanAuthorityAccountability.humanPromotionClosureProvidesBoundAuthority
    actors authorityValid grant receipt subject closed

/-- The complete EASE-002 formal binding exported to the enterprise umbrella. -/
theorem ease002FormalBound
    (declaration : AuthorityDeclaration)
    (closed : authorityBearingDeclaration declaration) :
    declaration.issuerKind ≠ .aiProvider ∧
      declaration.authorityId ≠ declaration.providerId ∧
      declaration.subject = declaration.currentSubject ∧
      declaration.receiptValidated = true ∧
      declaration.contextFresh = true := by
  exact closed.2

end AgenticAILabProof.Enterprise.AISecurityEmbodiedAuthorityBearingDeclarationClosure
