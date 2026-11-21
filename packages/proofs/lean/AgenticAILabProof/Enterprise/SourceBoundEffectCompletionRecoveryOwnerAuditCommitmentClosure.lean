-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditClosure
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentClosure

open SourceBoundEffectCompletionCrashRecoveryClosure
open SourceBoundEffectCompletionRecoveryConvergenceClosure
open SourceBoundEffectCompletionRecoveryOwnerAuditClosure
open SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore
open SourceBoundEffectCompletionRecoveryOwnerAuditCore
open SourceBoundEffectCompletionRecoveryProgressEvidenceClosure

/-!
# Recovery owner-audit commitment and authenticity closure

This closure binds the canonical audit trace to content-addressed commitments,
external authorization decisions, verified credentials, and explicit
enterprise accountability evidence.  It does not implement policy evaluation
or signature verification.
-/

structure SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEvidence
    (trace : SourceBoundEffectCompletionRecoveryTrace)
    (budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget)
    (scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope)
    (providerAcknowledgementStable : Nat → Prop)
    (expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation)
    (witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness)
    (scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme)
    (authorized : String → String → Prop)
    (signatureVerified : String → String → String → Prop)
    (envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope)
    (authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence) :
    Prop where
  auditEvidence :
    SourceBoundEffectCompletionRecoveryOwnerAuditEvidence
      trace budgets scopes providerAcknowledgementStable
      expectations witnesses
  commitmentAuthenticity :
    ∀ index,
      trace index ≠ .committed →
      SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityClosed
        scheme
        authorized
        signatureVerified
        (witnesses index)
        (envelopes index)
        (authenticityEvidence index)

theorem closedCommitmentAuditBuildsOwnerAudit
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {authorized : String → String → Prop}
    {signatureVerified : String → String → String → Prop}
    {envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    (evidence :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme authorized signatureVerified
        envelopes authenticityEvidence) :
    SourceBoundEffectCompletionRecoveryOwnerAuditEvidence
      trace budgets scopes providerAcknowledgementStable
      expectations witnesses :=
  evidence.auditEvidence

theorem closedCommitmentAuditPreservesPredecessorCommitment
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {authorized : String → String → Prop}
    {signatureVerified : String → String → String → Prop}
    {envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    {index : Nat}
    (evidence :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme authorized signatureVerified
        envelopes authenticityEvidence)
    (currentNotCommitted : trace index ≠ .committed)
    (nextNotCommitted : trace (index + 1) ≠ .committed) :
    (envelopes (index + 1)).payload.previousCommitment =
      some (envelopes index).commitment := by
  exact adjacentCommitmentsPreservePredecessor
    (evidence.auditEvidence.adjacent
      index currentNotCommitted nextNotCommitted)
    (evidence.commitmentAuthenticity
      index currentNotCommitted).commitmentClosed
    (evidence.commitmentAuthenticity
      (index + 1) nextNotCommitted).commitmentClosed

theorem closedCommitmentAuditConverges
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {authorized : String → String → Prop}
    {signatureVerified : String → String → String → Prop}
    {envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    (transitionClosed :
      SourceBoundEffectCompletionRecoveryTraceTransitionClosed trace)
    (evidence :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme authorized signatureVerified
        envelopes authenticityEvidence) :
    SourceBoundEffectCompletionRecoveryTraceConverges trace :=
  closedOwnerAuditConverges transitionClosed evidence.auditEvidence

theorem mismatchedCommitmentRejectsCommitmentAudit
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {authorized : String → String → Prop}
    {signatureVerified : String → String → String → Prop}
    {envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    {index : Nat}
    (notCommitted : trace index ≠ .committed)
    (mismatched :
      (authenticityEvidence index).commitment ≠
        (envelopes index).commitment) :
    ¬ SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme authorized signatureVerified
        envelopes authenticityEvidence := by
  intro evidence
  exact
    mismatchedAuthenticityCommitmentRejectsClosure mismatched
      (evidence.commitmentAuthenticity index notCommitted)

theorem unauthorizedCommitmentRejectsCommitmentAudit
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {authorized : String → String → Prop}
    {signatureVerified : String → String → String → Prop}
    {envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    {index : Nat}
    (notCommitted : trace index ≠ .committed)
    (unauthorized :
      ¬ authorized
        (authenticityEvidence index).authorityIdentity
        (envelopes index).commitment) :
    ¬ SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme authorized signatureVerified
        envelopes authenticityEvidence := by
  intro evidence
  exact
    unauthorizedCommitmentRejectsAuthenticityClosure unauthorized
      (evidence.commitmentAuthenticity index notCommitted)

theorem invalidSignatureRejectsCommitmentAudit
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {authorized : String → String → Prop}
    {signatureVerified : String → String → String → Prop}
    {envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    {index : Nat}
    (notCommitted : trace index ≠ .committed)
    (invalid :
      ¬ signatureVerified
        (authenticityEvidence index).credentialIdentity
        (envelopes index).commitment
        (authenticityEvidence index).signature) :
    ¬ SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme authorized signatureVerified
        envelopes authenticityEvidence := by
  intro evidence
  exact
    invalidSignatureRejectsAuthenticityClosure invalid
      (evidence.commitmentAuthenticity index notCommitted)

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentClosure
