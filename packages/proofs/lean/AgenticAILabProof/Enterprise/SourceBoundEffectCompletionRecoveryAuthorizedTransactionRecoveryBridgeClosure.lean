-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeCore
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeClosure

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeClosure

open CedarDualEngineAuthorization
open HumanAuthorityAccountability
open PromotionTransactionAtomicity
open PromotionTransactionRecovery
open SourceBoundEffectCompletionCrashRecoveryClosure
open SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeCore
open SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleCore
open SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeCore
open SourceBoundEffectCompletionRecoveryConvergenceClosure
open SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeClosure
open SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeCore
open SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore
open SourceBoundEffectCompletionRecoveryOwnerAuditCore
open SourceBoundEffectCompletionRecoveryProgressEvidenceClosure

structure SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeEvidence
    (trace : SourceBoundEffectCompletionRecoveryTrace)
    (budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget)
    (scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope)
    (providerAcknowledgementStable : Nat → Prop)
    (expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation)
    (witnesses : Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness)
    (scheme : SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme)
    (signatureVerified : String → String → String → Prop)
    (authorizationRegistry :
      String → SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence)
    (authorityPathAuthorized : String → String → String → String → Prop)
    (separationOfDutySatisfied : String → String → String → Prop)
    (envelopes : Nat → SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope)
    (authenticityEvidence :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence)
    (snapshotSubjectBindingValid :
      SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid)
    (semantics : DecisionSemantics)
    (decisionReceiptValid : DecisionReceiptValid)
    (dualDecisionIdentityValid :
      SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid)
    (subjectRegistry : String → AuthorizationSubject)
    (leftReceiptRegistry rightReceiptRegistry : String → DecisionReceipt)
    (bundleDigestAt : Nat → BundleEvidenceBinding.BundleDigest)
    (bundleDigestAtValid : Nat → BundleEvidenceBinding.BundleDigest → Prop)
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
    (commitReceiptRegistry : String → PromotionCommitReceipt)
    (recoveryAuthorityIdentityRegistry : String → String)
    (recoveryAuthorizationRegistry :
      String → SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence)
    (transactionRegistry : String → List TransactionRegistryEntry)
    (registryValid : TransactionRegistryValid)
    (recordValid : DurableRecordValid)
    (claimValid : RecoveryClaimValid)
    (receiptValid : RecoveryReceiptValid)
    (recoveryLedgerRegistry : String → List PromotionCommitReceipt)
    (durableRecordRegistry : String → DurableTransactionRecord)
    (recoveryClaimRegistry : String → RecoveryClaim)
    (recoveryReceiptRegistry : String → RecoveryReceipt)
    (expectationRequestBindingValid :
      SourceBoundEffectCompletionRecoveryExpectationRequestBindingValid)
    (authorizationRequestBindingValid :
      SourceBoundEffectCompletionRecoveryAuthorizationRequestBindingValid)
    (recoveryIdentityBindingValid :
      SourceBoundEffectCompletionRecoveryRecoveryIdentityBindingValid)
    (providerWorkerBindingValid :
      SourceBoundEffectCompletionRecoveryProviderWorkerBindingValid)
    (recoveryProvenanceBindingValid :
      SourceBoundEffectCompletionRecoveryRecoveryProvenanceBindingValid)
    (recoveryAuthorityAssignmentValid :
      SourceBoundEffectCompletionRecoveryRecoveryAuthorityAssignmentValid) : Prop where
  humanAtomicEvidence :
    SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeEvidence
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
      authorityReceiptValid
      admissionReceiptValid
      commitReceiptValid
      dualDecisionEngineRolesValid
      humanAuthoritySnapshotBindingValid
      accountabilityAssignmentValid
      responsibilityScopeCoversPlanValid
      materializationPlanValid
      actorsRegistry
      grantRegistry
      humanReceiptRegistry
      governanceSnapshotRegistry
      admissionRegistry
      requestRegistry
      commitReceiptRegistry
  recoveryBindings :
    ∀ index,
      sourceBoundEffectCompletionTransactionRecoveryRequired (trace index) →
        let commitment := (envelopes index).commitment
        SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridge
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
          (commitReceiptRegistry commitment)
          (recoveryAuthorityIdentityRegistry commitment)
          (recoveryAuthorizationRegistry commitment)
          (expectations index)
          (transactionRegistry commitment)
          registryValid
          recordValid
          claimValid
          receiptValid
          (recoveryLedgerRegistry commitment)
          (durableRecordRegistry commitment)
          (recoveryClaimRegistry commitment)
          (recoveryReceiptRegistry commitment)
          expectationRequestBindingValid
          authorizationRequestBindingValid
          recoveryIdentityBindingValid
          providerWorkerBindingValid
          recoveryProvenanceBindingValid
          recoveryAuthorityAssignmentValid

theorem closedAuthorizedRecoveryTraceConverges
    {trace}
    {budgets}
    {scopes}
    {providerAcknowledgementStable}
    {expectations}
    {witnesses}
    {scheme}
    {signatureVerified}
    {authorizationRegistry}
    {authorityPathAuthorized}
    {separationOfDutySatisfied}
    {envelopes}
    {authenticityEvidence}
    {snapshotSubjectBindingValid}
    {semantics}
    {decisionReceiptValid}
    {dualDecisionIdentityValid}
    {subjectRegistry}
    {leftReceiptRegistry rightReceiptRegistry}
    {bundleDigestAt}
    {bundleDigestAtValid}
    {authorityReceiptValid}
    {admissionReceiptValid}
    {commitReceiptValid}
    {dualDecisionEngineRolesValid}
    {humanAuthoritySnapshotBindingValid}
    {accountabilityAssignmentValid}
    {responsibilityScopeCoversPlanValid}
    {materializationPlanValid}
    {actorsRegistry}
    {grantRegistry}
    {humanReceiptRegistry}
    {governanceSnapshotRegistry}
    {admissionRegistry}
    {requestRegistry}
    {commitReceiptRegistry}
    {recoveryAuthorityIdentityRegistry}
    {recoveryAuthorizationRegistry}
    {transactionRegistry}
    {registryValid}
    {recordValid}
    {claimValid}
    {receiptValid}
    {recoveryLedgerRegistry}
    {durableRecordRegistry}
    {recoveryClaimRegistry}
    {recoveryReceiptRegistry}
    {expectationRequestBindingValid}
    {authorizationRequestBindingValid}
    {recoveryIdentityBindingValid}
    {providerWorkerBindingValid}
    {recoveryProvenanceBindingValid}
    {recoveryAuthorityAssignmentValid}
    (transitionClosed : SourceBoundEffectCompletionRecoveryTraceTransitionClosed trace)
    (evidence :
      SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeEvidence
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
        authorityReceiptValid
        admissionReceiptValid
        commitReceiptValid
        dualDecisionEngineRolesValid
        humanAuthoritySnapshotBindingValid
        accountabilityAssignmentValid
        responsibilityScopeCoversPlanValid
        materializationPlanValid
        actorsRegistry
        grantRegistry
        humanReceiptRegistry
        governanceSnapshotRegistry
        admissionRegistry
        requestRegistry
        commitReceiptRegistry
        recoveryAuthorityIdentityRegistry
        recoveryAuthorizationRegistry
        transactionRegistry
        registryValid
        recordValid
        claimValid
        receiptValid
        recoveryLedgerRegistry
        durableRecordRegistry
        recoveryClaimRegistry
        recoveryReceiptRegistry
        expectationRequestBindingValid
        authorizationRequestBindingValid
        recoveryIdentityBindingValid
        providerWorkerBindingValid
        recoveryProvenanceBindingValid
        recoveryAuthorityAssignmentValid) :
    SourceBoundEffectCompletionRecoveryTraceConverges trace :=
  closedHumanAtomicTraceConverges transitionClosed evidence.humanAtomicEvidence

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeClosure
