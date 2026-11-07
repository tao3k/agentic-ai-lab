-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeClosure
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridgeCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridgeClosure

open AgenticAILabProof.Enterprise
open AgenticAILabProof.Enterprise.BundleEvidenceBinding
open AgenticAILabProof.Enterprise.CedarDualEngineAuthorization
open AgenticAILabProof.Enterprise.EffectDomainCoverage
open AgenticAILabProof.Enterprise.HumanAuthorityAccountability
open AgenticAILabProof.Enterprise.PromotionTransactionAtomicity
open AgenticAILabProof.Enterprise.PromotionTransactionRecovery
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryConvergenceClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridgeCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryProgressEvidenceClosure

structure SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridgeEvidence
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
    (envelopes :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope)
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
    (bundleDigestAt : Nat → BundleDigest)
    (bundleDigestAtValid : Nat → BundleDigest → Prop)
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
      SourceBoundEffectCompletionRecoveryRecoveryAuthorityAssignmentValid)
    (effectCoverageWitnessValid : EffectCoverageWitnessValid)
    (effectWorldValid : EffectWorldValid)
    (compensationReceiptValid : CompensationReceiptValid)
    (planEffectUniverseBindingValid :
      MaterializationPlanEffectUniverseBindingValid)
    (observationWorldBindingValid :
      RecoveryEffectObservationWorldBindingValid)
    (compensationFenceBindingValid :
      CompensationFenceBindingValid)
    (effectCompensationProvenanceBindingValid :
      EffectCompensationProvenanceBindingValid)
    (effectCoverageWitnessRegistry : String → EffectCoverageWitness)
    (effectObligationRegistry : String → List EffectObligation)
    (compensationReceiptRegistry : String → List CompensationReceipt)
    (effectWorldBeforeRegistry : String → EffectWorld)
    (effectWorldAfterRegistry : String → EffectWorld) : Prop where
  authorizedRecoveryEvidence :
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
      recoveryAuthorityAssignmentValid
  effectDomainRollbackBindings :
    ∀ (index : Nat),
      sourceBoundEffectCompletionTransactionRecoveryRequired (trace index) →
        let commitment := (envelopes index).commitment
        SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridge
          (SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridge
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
            recoveryAuthorityAssignmentValid)
          (requestRegistry commitment)
          (recoveryClaimRegistry commitment).acquiredFenceToken
          (recoveryReceiptRegistry commitment)
          effectCoverageWitnessValid
          effectWorldValid
          compensationReceiptValid
          planEffectUniverseBindingValid
          observationWorldBindingValid
          compensationFenceBindingValid
          effectCompensationProvenanceBindingValid
          commitment
          (effectCoverageWitnessRegistry commitment)
          (effectObligationRegistry commitment)
          (compensationReceiptRegistry commitment)
          (effectWorldBeforeRegistry commitment)
          (effectWorldAfterRegistry commitment)

theorem closedEffectDomainRollbackTraceConverges
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses : Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {scheme : SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {signatureVerified : String → String → String → Prop}
    {authorizationRegistry :
      String → SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {authorityPathAuthorized : String → String → String → String → Prop}
    {separationOfDutySatisfied : String → String → String → Prop}
    {envelopes :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {authenticityEvidence :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    {snapshotSubjectBindingValid :
      SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid}
    {semantics : DecisionSemantics}
    {decisionReceiptValid : DecisionReceiptValid}
    {dualDecisionIdentityValid :
      SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid}
    {subjectRegistry : String → AuthorizationSubject}
    {leftReceiptRegistry rightReceiptRegistry : String → DecisionReceipt}
    {bundleDigestAt : Nat → BundleDigest}
    {bundleDigestAtValid : Nat → BundleDigest → Prop}
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
    {recoveryAuthorityIdentityRegistry : String → String}
    {recoveryAuthorizationRegistry :
      String → SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {transactionRegistry : String → List TransactionRegistryEntry}
    {registryValid : TransactionRegistryValid}
    {recordValid : DurableRecordValid}
    {claimValid : RecoveryClaimValid}
    {receiptValid : RecoveryReceiptValid}
    {recoveryLedgerRegistry : String → List PromotionCommitReceipt}
    {durableRecordRegistry : String → DurableTransactionRecord}
    {recoveryClaimRegistry : String → RecoveryClaim}
    {recoveryReceiptRegistry : String → RecoveryReceipt}
    {expectationRequestBindingValid :
      SourceBoundEffectCompletionRecoveryExpectationRequestBindingValid}
    {authorizationRequestBindingValid :
      SourceBoundEffectCompletionRecoveryAuthorizationRequestBindingValid}
    {recoveryIdentityBindingValid :
      SourceBoundEffectCompletionRecoveryRecoveryIdentityBindingValid}
    {providerWorkerBindingValid :
      SourceBoundEffectCompletionRecoveryProviderWorkerBindingValid}
    {recoveryProvenanceBindingValid :
      SourceBoundEffectCompletionRecoveryRecoveryProvenanceBindingValid}
    {recoveryAuthorityAssignmentValid :
      SourceBoundEffectCompletionRecoveryRecoveryAuthorityAssignmentValid}
    {effectCoverageWitnessValid : EffectCoverageWitnessValid}
    {effectWorldValid : EffectWorldValid}
    {compensationReceiptValid : CompensationReceiptValid}
    {planEffectUniverseBindingValid :
      MaterializationPlanEffectUniverseBindingValid}
    {observationWorldBindingValid :
      RecoveryEffectObservationWorldBindingValid}
    {compensationFenceBindingValid :
      CompensationFenceBindingValid}
    {effectCompensationProvenanceBindingValid :
      EffectCompensationProvenanceBindingValid}
    {effectCoverageWitnessRegistry : String → EffectCoverageWitness}
    {effectObligationRegistry : String → List EffectObligation}
    {compensationReceiptRegistry : String → List CompensationReceipt}
    {effectWorldBeforeRegistry : String → EffectWorld}
    {effectWorldAfterRegistry : String → EffectWorld}
    (transitionClosed :
      SourceBoundEffectCompletionRecoveryTraceTransitionClosed trace)
    (evidence :
      SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridgeEvidence
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
        recoveryAuthorityAssignmentValid
        effectCoverageWitnessValid
        effectWorldValid
        compensationReceiptValid
        planEffectUniverseBindingValid
        observationWorldBindingValid
        compensationFenceBindingValid
        effectCompensationProvenanceBindingValid
        effectCoverageWitnessRegistry
        effectObligationRegistry
        compensationReceiptRegistry
        effectWorldBeforeRegistry
        effectWorldAfterRegistry) :
    SourceBoundEffectCompletionRecoveryTraceConverges trace :=
  closedAuthorizedRecoveryTraceConverges
    transitionClosed
    evidence.authorizedRecoveryEvidence

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridgeClosure
