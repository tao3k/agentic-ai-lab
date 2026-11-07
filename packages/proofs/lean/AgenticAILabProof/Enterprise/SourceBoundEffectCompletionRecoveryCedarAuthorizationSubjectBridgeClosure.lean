-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleClosure
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeClosure

open CedarDualEngineAuthorization
open SourceBoundEffectCompletionCrashRecoveryClosure
open SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleClosure
open SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleCore
open SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeCore
open SourceBoundEffectCompletionRecoveryConvergenceClosure
open SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore
open SourceBoundEffectCompletionRecoveryOwnerAuditCore
open SourceBoundEffectCompletionRecoveryProgressEvidenceClosure

/-!
# Authorization-subject bridge over the recovery trace

Each non-committed recovery position resolves its authorization subject and
two decision receipts through the exact owner-audit commitment.
-/

structure SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeEvidence
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
    (signatureVerified : String → String → String → Prop)
    (authorizationRegistry :
      String →
        SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence)
    (authorityPathAuthorized :
      String → String → String → String → Prop)
    (separationOfDutySatisfied :
      String → String → String → Prop)
    (envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope)
    (authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence)
    (snapshotSubjectBindingValid :
      SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid)
    (semantics : DecisionSemantics)
    (decisionReceiptValid : DecisionReceiptValid)
    (dualDecisionIdentityValid :
      SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid)
    (subjectRegistry : String → AuthorizationSubject)
    (leftReceiptRegistry rightReceiptRegistry :
      String → DecisionReceipt)
    (bundleDigestAt :
      Nat → BundleEvidenceBinding.BundleDigest)
    (bundleDigestAtValid :
      Nat → BundleEvidenceBinding.BundleDigest → Prop) : Prop where
  lifecycleEvidence :
    SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleEvidence
      trace
      budgets
      scopes
      providerAcknowledgementStable
      expectations
      witnesses
      scheme
      signatureVerified
      authorizationRegistry
      authorityPathAuthorized
      separationOfDutySatisfied
      envelopes
      authenticityEvidence
  subjectBindings :
    ∀ index,
      trace index ≠ .committed →
      let commitment := (envelopes index).commitment
      SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBound
        snapshotSubjectBindingValid
        semantics
        decisionReceiptValid
        dualDecisionIdentityValid
        (authorizationRegistry commitment)
        (subjectRegistry commitment)
        (leftReceiptRegistry commitment)
        (rightReceiptRegistry commitment)
        (bundleDigestAt index)
  bundleDigestBindings :
    ∀ index,
      trace index ≠ .committed →
      bundleDigestAtValid index (bundleDigestAt index)

theorem closedSubjectBridgeBuildsLifecycle
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
    {signatureVerified : String → String → String → Prop}
    {authorizationRegistry :
      String →
        SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    {snapshotSubjectBindingValid :
      SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid}
    {semantics : DecisionSemantics}
    {decisionReceiptValid : DecisionReceiptValid}
    {dualDecisionIdentityValid :
      SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid}
    {subjectRegistry : String → AuthorizationSubject}
    {leftReceiptRegistry rightReceiptRegistry :
      String → DecisionReceipt}
    {bundleDigestAt :
      Nat → BundleEvidenceBinding.BundleDigest}
    {bundleDigestAtValid :
      Nat → BundleEvidenceBinding.BundleDigest → Prop}
    (evidence :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme signatureVerified authorizationRegistry
        authorityPathAuthorized separationOfDutySatisfied
        envelopes authenticityEvidence snapshotSubjectBindingValid
        semantics decisionReceiptValid dualDecisionIdentityValid
        subjectRegistry
        leftReceiptRegistry rightReceiptRegistry bundleDigestAt
        bundleDigestAtValid) :
    SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleEvidence
      trace budgets scopes providerAcknowledgementStable expectations
      witnesses scheme signatureVerified authorizationRegistry
      authorityPathAuthorized separationOfDutySatisfied
      envelopes authenticityEvidence :=
  evidence.lifecycleEvidence

theorem closedSubjectBridgeAt
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
    {signatureVerified : String → String → String → Prop}
    {authorizationRegistry :
      String →
        SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    {snapshotSubjectBindingValid :
      SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid}
    {semantics : DecisionSemantics}
    {decisionReceiptValid : DecisionReceiptValid}
    {dualDecisionIdentityValid :
      SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid}
    {subjectRegistry : String → AuthorizationSubject}
    {leftReceiptRegistry rightReceiptRegistry :
      String → DecisionReceipt}
    {bundleDigestAt :
      Nat → BundleEvidenceBinding.BundleDigest}
    {bundleDigestAtValid :
      Nat → BundleEvidenceBinding.BundleDigest → Prop}
    {index : Nat}
    (evidence :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme signatureVerified authorizationRegistry
        authorityPathAuthorized separationOfDutySatisfied
        envelopes authenticityEvidence snapshotSubjectBindingValid
        semantics decisionReceiptValid dualDecisionIdentityValid
        subjectRegistry
        leftReceiptRegistry rightReceiptRegistry bundleDigestAt
        bundleDigestAtValid)
    (notCommitted : trace index ≠ .committed) :
    let commitment := (envelopes index).commitment
    SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridge
      snapshotSubjectBindingValid
      semantics
      decisionReceiptValid
      dualDecisionIdentityValid
      authorityPathAuthorized
      separationOfDutySatisfied
      (authenticityEvidence index).authorityIdentity
      commitment
      (bundleDigestAt index)
      (authorizationRegistry commitment)
      (subjectRegistry commitment)
      (leftReceiptRegistry commitment)
      (rightReceiptRegistry commitment) := by
  let commitment := (envelopes index).commitment
  constructor
  · exact closedCedarLifecycleAuthorizationAdmitted
      evidence.lifecycleEvidence notCommitted
  · exact evidence.subjectBindings index notCommitted

theorem closedSubjectBridgeConverges
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
    {signatureVerified : String → String → String → Prop}
    {authorizationRegistry :
      String →
        SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    {snapshotSubjectBindingValid :
      SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid}
    {semantics : DecisionSemantics}
    {decisionReceiptValid : DecisionReceiptValid}
    {dualDecisionIdentityValid :
      SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid}
    {subjectRegistry : String → AuthorizationSubject}
    {leftReceiptRegistry rightReceiptRegistry :
      String → DecisionReceipt}
    {bundleDigestAt :
      Nat → BundleEvidenceBinding.BundleDigest}
    {bundleDigestAtValid :
      Nat → BundleEvidenceBinding.BundleDigest → Prop}
    (transitionClosed :
      SourceBoundEffectCompletionRecoveryTraceTransitionClosed trace)
    (evidence :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme signatureVerified authorizationRegistry
        authorityPathAuthorized separationOfDutySatisfied
        envelopes authenticityEvidence snapshotSubjectBindingValid
        semantics decisionReceiptValid dualDecisionIdentityValid
        subjectRegistry
        leftReceiptRegistry rightReceiptRegistry bundleDigestAt
        bundleDigestAtValid) :
    SourceBoundEffectCompletionRecoveryTraceConverges trace :=
  closedCedarLifecycleConverges
    transitionClosed evidence.lifecycleEvidence

theorem sameEngineReceiptReplayRejectsTraceBridge
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
    {signatureVerified : String → String → String → Prop}
    {authorizationRegistry :
      String →
        SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    {snapshotSubjectBindingValid :
      SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid}
    {semantics : DecisionSemantics}
    {decisionReceiptValid : DecisionReceiptValid}
    {dualDecisionIdentityValid :
      SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid}
    {subjectRegistry : String → AuthorizationSubject}
    {receiptRegistry : String → DecisionReceipt}
    {bundleDigestAt :
      Nat → BundleEvidenceBinding.BundleDigest}
    {bundleDigestAtValid :
      Nat → BundleEvidenceBinding.BundleDigest → Prop}
    {index : Nat}
    (notCommitted : trace index ≠ .committed) :
    ¬ SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme signatureVerified authorizationRegistry
        authorityPathAuthorized separationOfDutySatisfied
        envelopes authenticityEvidence snapshotSubjectBindingValid
        semantics decisionReceiptValid dualDecisionIdentityValid
        subjectRegistry
        receiptRegistry receiptRegistry bundleDigestAt
        bundleDigestAtValid := by
  intro evidence
  have closed := closedSubjectBridgeAt evidence notCommitted
  exact closed.subjectBound.dualDecisionCloses.2.1 rfl

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeClosure
