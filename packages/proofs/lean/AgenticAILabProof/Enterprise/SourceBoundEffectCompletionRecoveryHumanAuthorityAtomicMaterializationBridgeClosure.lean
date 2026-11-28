-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeClosure
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeClosure

open CedarDualEngineAuthorization
open HumanAuthorityAccountability
open PromotionTransactionAtomicity
open SourceBoundEffectCompletionCrashRecoveryClosure
open SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleCore
open SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeClosure
open SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeCore
open SourceBoundEffectCompletionRecoveryConvergenceClosure
open SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeCore
open SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore
open SourceBoundEffectCompletionRecoveryOwnerAuditCore
open SourceBoundEffectCompletionRecoveryProgressEvidenceClosure

/-!
# Human-authority and atomic-materialization bridge over the recovery trace

Every non-committed recovery position resolves the human and transaction
evidence through the same owner-audit commitment as its Cedar lifecycle and
authorization subject.
-/

structure SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeEvidence
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
      Nat → BundleEvidenceBinding.BundleDigest → Prop)
    (authorityReceiptValid : AuthorityReceiptValid)
    (admissionReceiptValid : AdmissionReceiptValid)
    (commitReceiptValid : CommitReceiptValid)
    (dualDecisionEngineRolesValid :
      SourceBoundEffectCompletionRecoveryDualDecisionEngineRolesValid)
    (humanAuthoritySnapshotBindingValid :
      SourceBoundEffectCompletionRecoveryHumanAuthoritySnapshotBindingValid)
    (accountabilityAssignmentValid :
      SourceBoundEffectCompletionRecoveryAccountabilityAssignmentValid)
    (responsibilityScopeCoversPlanValid :
      SourceBoundEffectCompletionRecoveryResponsibilityScopeCoversPlanValid)
    (materializationPlanValid :
      SourceBoundEffectCompletionRecoveryMaterializationPlanValid)
    (actorsRegistry : String → PromotionActors)
    (grantRegistry : String → AuthorityGrant)
    (humanReceiptRegistry : String → BoundAuthorityReceipt)
    (governanceSnapshotRegistry : String → GovernanceSnapshot)
    (admissionRegistry : String → PromotionAdmissionReceipt)
    (requestRegistry : String → PromotionCommitRequest)
    (commitReceiptRegistry : String → PromotionCommitReceipt) : Prop where
  subjectBridgeEvidence :
    SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeEvidence
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
      snapshotSubjectBindingValid
      semantics
      decisionReceiptValid
      dualDecisionIdentityValid
      subjectRegistry
      leftReceiptRegistry
      rightReceiptRegistry
      bundleDigestAt
      bundleDigestAtValid
  humanAtomicBindings :
    ∀ index,
      trace index ≠ .committed →
      let commitment := (envelopes index).commitment
      SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBound
        authorityReceiptValid
        admissionReceiptValid
        commitReceiptValid
        dualDecisionEngineRolesValid
        humanAuthoritySnapshotBindingValid
        accountabilityAssignmentValid
        responsibilityScopeCoversPlanValid
        materializationPlanValid
        (authorizationRegistry commitment)
        (subjectRegistry commitment)
        (leftReceiptRegistry commitment)
        (rightReceiptRegistry commitment)
        (actorsRegistry commitment)
        (grantRegistry commitment)
        (humanReceiptRegistry commitment)
        (governanceSnapshotRegistry commitment)
        (admissionRegistry commitment)
        (requestRegistry commitment)
        (commitReceiptRegistry commitment)

theorem closedHumanAtomicTraceBuildsSubjectBridge
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
    {authorityReceiptValid : AuthorityReceiptValid}
    {admissionReceiptValid : AdmissionReceiptValid}
    {commitReceiptValid : CommitReceiptValid}
    {dualDecisionEngineRolesValid :
      SourceBoundEffectCompletionRecoveryDualDecisionEngineRolesValid}
    {humanAuthoritySnapshotBindingValid :
      SourceBoundEffectCompletionRecoveryHumanAuthoritySnapshotBindingValid}
    {accountabilityAssignmentValid :
      SourceBoundEffectCompletionRecoveryAccountabilityAssignmentValid}
    {responsibilityScopeCoversPlanValid :
      SourceBoundEffectCompletionRecoveryResponsibilityScopeCoversPlanValid}
    {materializationPlanValid :
      SourceBoundEffectCompletionRecoveryMaterializationPlanValid}
    {actorsRegistry : String → PromotionActors}
    {grantRegistry : String → AuthorityGrant}
    {humanReceiptRegistry : String → BoundAuthorityReceipt}
    {governanceSnapshotRegistry : String → GovernanceSnapshot}
    {admissionRegistry : String → PromotionAdmissionReceipt}
    {requestRegistry : String → PromotionCommitRequest}
    {commitReceiptRegistry : String → PromotionCommitReceipt}
    (evidence :
      SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme signatureVerified authorizationRegistry
        authorityPathAuthorized separationOfDutySatisfied
        envelopes authenticityEvidence snapshotSubjectBindingValid
        semantics decisionReceiptValid dualDecisionIdentityValid
        subjectRegistry leftReceiptRegistry rightReceiptRegistry
        bundleDigestAt bundleDigestAtValid authorityReceiptValid
        admissionReceiptValid commitReceiptValid
        dualDecisionEngineRolesValid humanAuthoritySnapshotBindingValid
        accountabilityAssignmentValid responsibilityScopeCoversPlanValid
        materializationPlanValid actorsRegistry grantRegistry
        humanReceiptRegistry governanceSnapshotRegistry admissionRegistry
        requestRegistry commitReceiptRegistry) :
    SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeEvidence
      trace budgets scopes providerAcknowledgementStable expectations
      witnesses scheme signatureVerified authorizationRegistry
      authorityPathAuthorized separationOfDutySatisfied
      envelopes authenticityEvidence snapshotSubjectBindingValid
      semantics decisionReceiptValid dualDecisionIdentityValid
      subjectRegistry leftReceiptRegistry rightReceiptRegistry
      bundleDigestAt bundleDigestAtValid :=
  evidence.subjectBridgeEvidence

theorem closedHumanAtomicBridgeAt
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
    {authorityReceiptValid : AuthorityReceiptValid}
    {admissionReceiptValid : AdmissionReceiptValid}
    {commitReceiptValid : CommitReceiptValid}
    {dualDecisionEngineRolesValid :
      SourceBoundEffectCompletionRecoveryDualDecisionEngineRolesValid}
    {humanAuthoritySnapshotBindingValid :
      SourceBoundEffectCompletionRecoveryHumanAuthoritySnapshotBindingValid}
    {accountabilityAssignmentValid :
      SourceBoundEffectCompletionRecoveryAccountabilityAssignmentValid}
    {responsibilityScopeCoversPlanValid :
      SourceBoundEffectCompletionRecoveryResponsibilityScopeCoversPlanValid}
    {materializationPlanValid :
      SourceBoundEffectCompletionRecoveryMaterializationPlanValid}
    {actorsRegistry : String → PromotionActors}
    {grantRegistry : String → AuthorityGrant}
    {humanReceiptRegistry : String → BoundAuthorityReceipt}
    {governanceSnapshotRegistry : String → GovernanceSnapshot}
    {admissionRegistry : String → PromotionAdmissionReceipt}
    {requestRegistry : String → PromotionCommitRequest}
    {commitReceiptRegistry : String → PromotionCommitReceipt}
    {index : Nat}
    (evidence :
      SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme signatureVerified authorizationRegistry
        authorityPathAuthorized separationOfDutySatisfied
        envelopes authenticityEvidence snapshotSubjectBindingValid
        semantics decisionReceiptValid dualDecisionIdentityValid
        subjectRegistry leftReceiptRegistry rightReceiptRegistry
        bundleDigestAt bundleDigestAtValid authorityReceiptValid
        admissionReceiptValid commitReceiptValid
        dualDecisionEngineRolesValid humanAuthoritySnapshotBindingValid
        accountabilityAssignmentValid responsibilityScopeCoversPlanValid
        materializationPlanValid actorsRegistry grantRegistry
        humanReceiptRegistry governanceSnapshotRegistry admissionRegistry
        requestRegistry commitReceiptRegistry)
    (notCommitted : trace index ≠ .committed) :
    let commitment := (envelopes index).commitment
    SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridge
      snapshotSubjectBindingValid
      semantics
      decisionReceiptValid
      dualDecisionIdentityValid
      authorityPathAuthorized
      separationOfDutySatisfied
      (authenticityEvidence index).authorityIdentity
      commitment
      (bundleDigestAt index)
      authorityReceiptValid
      admissionReceiptValid
      commitReceiptValid
      dualDecisionEngineRolesValid
      humanAuthoritySnapshotBindingValid
      accountabilityAssignmentValid
      responsibilityScopeCoversPlanValid
      materializationPlanValid
      (authorizationRegistry commitment)
      (subjectRegistry commitment)
      (leftReceiptRegistry commitment)
      (rightReceiptRegistry commitment)
      (actorsRegistry commitment)
      (grantRegistry commitment)
      (humanReceiptRegistry commitment)
      (governanceSnapshotRegistry commitment)
      (admissionRegistry commitment)
      (requestRegistry commitment)
      (commitReceiptRegistry commitment) := by
  let commitment := (envelopes index).commitment
  constructor
  · exact closedSubjectBridgeAt
      evidence.subjectBridgeEvidence notCommitted
  · exact evidence.humanAtomicBindings index notCommitted

theorem closedHumanAtomicTraceConverges
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
    {authorityReceiptValid : AuthorityReceiptValid}
    {admissionReceiptValid : AdmissionReceiptValid}
    {commitReceiptValid : CommitReceiptValid}
    {dualDecisionEngineRolesValid :
      SourceBoundEffectCompletionRecoveryDualDecisionEngineRolesValid}
    {humanAuthoritySnapshotBindingValid :
      SourceBoundEffectCompletionRecoveryHumanAuthoritySnapshotBindingValid}
    {accountabilityAssignmentValid :
      SourceBoundEffectCompletionRecoveryAccountabilityAssignmentValid}
    {responsibilityScopeCoversPlanValid :
      SourceBoundEffectCompletionRecoveryResponsibilityScopeCoversPlanValid}
    {materializationPlanValid :
      SourceBoundEffectCompletionRecoveryMaterializationPlanValid}
    {actorsRegistry : String → PromotionActors}
    {grantRegistry : String → AuthorityGrant}
    {humanReceiptRegistry : String → BoundAuthorityReceipt}
    {governanceSnapshotRegistry : String → GovernanceSnapshot}
    {admissionRegistry : String → PromotionAdmissionReceipt}
    {requestRegistry : String → PromotionCommitRequest}
    {commitReceiptRegistry : String → PromotionCommitReceipt}
    (transitionClosed :
      SourceBoundEffectCompletionRecoveryTraceTransitionClosed trace)
    (evidence :
      SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme signatureVerified authorizationRegistry
        authorityPathAuthorized separationOfDutySatisfied
        envelopes authenticityEvidence snapshotSubjectBindingValid
        semantics decisionReceiptValid dualDecisionIdentityValid
        subjectRegistry leftReceiptRegistry rightReceiptRegistry
        bundleDigestAt bundleDigestAtValid authorityReceiptValid
        admissionReceiptValid commitReceiptValid
        dualDecisionEngineRolesValid humanAuthoritySnapshotBindingValid
        accountabilityAssignmentValid responsibilityScopeCoversPlanValid
        materializationPlanValid actorsRegistry grantRegistry
        humanReceiptRegistry governanceSnapshotRegistry admissionRegistry
        requestRegistry commitReceiptRegistry) :
    SourceBoundEffectCompletionRecoveryTraceConverges trace :=
  closedSubjectBridgeConverges
    transitionClosed evidence.subjectBridgeEvidence

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeClosure
