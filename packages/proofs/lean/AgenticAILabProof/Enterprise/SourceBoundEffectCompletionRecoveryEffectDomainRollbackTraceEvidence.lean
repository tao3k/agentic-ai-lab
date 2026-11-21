-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridgeClosure

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEffectDomainRollbackTraceEvidence

open AgenticAILabProof.Enterprise
open AgenticAILabProof.Enterprise.BundleEvidenceBinding
open AgenticAILabProof.Enterprise.CedarDualEngineAuthorization
open AgenticAILabProof.Enterprise.EffectDomainCoverage
open AgenticAILabProof.Enterprise.HumanAuthorityAccountability
open AgenticAILabProof.Enterprise.PromotionTransactionAtomicity
open AgenticAILabProof.Enterprise.PromotionTransactionRecovery
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryConvergenceClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridgeClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridgeCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryProgressEvidenceClosure

structure SourceBoundEffectCompletionRecoveryEffectDomainRollbackTraceEvidence where
  trace : SourceBoundEffectCompletionRecoveryTrace
  budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget
  scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope
  providerAcknowledgementStable : Nat → Prop
  expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation
  witnesses : Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness
  scheme : SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme
  signatureVerified : String → String → String → Prop
  authorizationRegistry :
    String → SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence
  authorityPathAuthorized : String → String → String → String → Prop
  separationOfDutySatisfied : String → String → String → Prop
  envelopes :
    Nat → SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope
  authenticityEvidence :
    Nat → SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence
  snapshotSubjectBindingValid :
    SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid
  semantics : DecisionSemantics
  decisionReceiptValid : DecisionReceiptValid
  dualDecisionIdentityValid :
    SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid
  subjectRegistry : String → AuthorizationSubject
  leftReceiptRegistry : String → DecisionReceipt
  rightReceiptRegistry : String → DecisionReceipt
  bundleDigestAt : Nat → BundleDigest
  bundleDigestAtValid : Nat → BundleDigest → Prop
  authorityReceiptValid : AuthorityReceiptValid
  admissionReceiptValid : AdmissionReceiptValid
  commitReceiptValid : CommitReceiptValid
  dualDecisionEngineRolesValid :
    SourceBoundEffectCompletionRecoveryDualDecisionEngineRolesValid
  humanAuthoritySnapshotBindingValid :
    SourceBoundEffectCompletionRecoveryHumanAuthoritySnapshotBindingValid
  accountabilityAssignmentValid :
    SourceBoundEffectCompletionRecoveryAccountabilityAssignmentValid
  responsibilityScopeCoversPlanValid :
    SourceBoundEffectCompletionRecoveryResponsibilityScopeCoversPlanValid
  materializationPlanValid :
    SourceBoundEffectCompletionRecoveryMaterializationPlanValid
  actorsRegistry : String → PromotionActors
  grantRegistry : String → AuthorityGrant
  humanReceiptRegistry : String → BoundAuthorityReceipt
  governanceSnapshotRegistry : String → GovernanceSnapshot
  admissionRegistry : String → PromotionAdmissionReceipt
  requestRegistry : String → PromotionCommitRequest
  commitReceiptRegistry : String → PromotionCommitReceipt
  recoveryAuthorityIdentityRegistry : String → String
  recoveryAuthorizationRegistry :
    String → SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence
  transactionRegistry : String → List TransactionRegistryEntry
  registryValid : TransactionRegistryValid
  recordValid : DurableRecordValid
  claimValid : RecoveryClaimValid
  receiptValid : RecoveryReceiptValid
  recoveryLedgerRegistry : String → List PromotionCommitReceipt
  durableRecordRegistry : String → DurableTransactionRecord
  recoveryClaimRegistry : String → RecoveryClaim
  recoveryReceiptRegistry : String → RecoveryReceipt
  expectationRequestBindingValid :
    SourceBoundEffectCompletionRecoveryExpectationRequestBindingValid
  authorizationRequestBindingValid :
    SourceBoundEffectCompletionRecoveryAuthorizationRequestBindingValid
  recoveryIdentityBindingValid :
    SourceBoundEffectCompletionRecoveryRecoveryIdentityBindingValid
  providerWorkerBindingValid :
    SourceBoundEffectCompletionRecoveryProviderWorkerBindingValid
  recoveryProvenanceBindingValid :
    SourceBoundEffectCompletionRecoveryRecoveryProvenanceBindingValid
  recoveryAuthorityAssignmentValid :
    SourceBoundEffectCompletionRecoveryRecoveryAuthorityAssignmentValid
  effectCoverageWitnessValid : EffectCoverageWitnessValid
  effectWorldValid : EffectWorldValid
  compensationReceiptValid : CompensationReceiptValid
  planEffectUniverseBindingValid :
    MaterializationPlanEffectUniverseBindingValid
  observationWorldBindingValid :
    RecoveryEffectObservationWorldBindingValid
  compensationFenceBindingValid :
    CompensationFenceBindingValid
  effectCompensationProvenanceBindingValid :
    EffectCompensationProvenanceBindingValid
  effectCoverageWitnessRegistry : String → EffectCoverageWitness
  effectObligationRegistry : String → List EffectObligation
  compensationReceiptRegistry : String → List CompensationReceipt
  effectWorldBeforeRegistry : String → EffectWorld
  effectWorldAfterRegistry : String → EffectWorld
  closed :
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
      effectWorldAfterRegistry

namespace SourceBoundEffectCompletionRecoveryEffectDomainRollbackTraceEvidence

abbrev CommitmentAt
    (evidence : SourceBoundEffectCompletionRecoveryEffectDomainRollbackTraceEvidence)
    (index : Nat) : String :=
  (evidence.envelopes index).commitment

abbrev RecoveryReceiptAt
    (evidence : SourceBoundEffectCompletionRecoveryEffectDomainRollbackTraceEvidence)
    (index : Nat) : RecoveryReceipt :=
  evidence.recoveryReceiptRegistry (evidence.CommitmentAt index)

abbrev RecoveryClaimAt
    (evidence : SourceBoundEffectCompletionRecoveryEffectDomainRollbackTraceEvidence)
    (index : Nat) : RecoveryClaim :=
  evidence.recoveryClaimRegistry (evidence.CommitmentAt index)

abbrev RecoveryFenceAt
    (evidence : SourceBoundEffectCompletionRecoveryEffectDomainRollbackTraceEvidence)
    (index : Nat) : Nat :=
  (evidence.RecoveryClaimAt index).acquiredFenceToken

abbrev OutcomeAt
    (evidence : SourceBoundEffectCompletionRecoveryEffectDomainRollbackTraceEvidence)
    (index : Nat) : CommitOutcome :=
  (evidence.RecoveryReceiptAt index).effectReceipt.base.outcome

abbrev AuthorizedRecoveryAt
    (evidence : SourceBoundEffectCompletionRecoveryEffectDomainRollbackTraceEvidence)
    (index : Nat) : Prop :=
  let commitment := evidence.CommitmentAt index
  SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridge
    evidence.snapshotSubjectBindingValid
    evidence.semantics
    evidence.decisionReceiptValid
    evidence.dualDecisionIdentityValid
    evidence.authorityPathAuthorized
    evidence.separationOfDutySatisfied
    (evidence.authenticityEvidence index).authorityIdentity
    commitment
    (evidence.bundleDigestAt index)
    evidence.authorityReceiptValid
    evidence.admissionReceiptValid
    evidence.commitReceiptValid
    evidence.dualDecisionEngineRolesValid
    evidence.humanAuthoritySnapshotBindingValid
    evidence.accountabilityAssignmentValid
    evidence.responsibilityScopeCoversPlanValid
    evidence.materializationPlanValid
    (evidence.authorizationRegistry commitment)
    (evidence.subjectRegistry commitment)
    (evidence.leftReceiptRegistry commitment)
    (evidence.rightReceiptRegistry commitment)
    (evidence.actorsRegistry commitment)
    (evidence.grantRegistry commitment)
    (evidence.humanReceiptRegistry commitment)
    (evidence.governanceSnapshotRegistry commitment)
    (evidence.admissionRegistry commitment)
    (evidence.requestRegistry commitment)
    (evidence.commitReceiptRegistry commitment)
    (evidence.recoveryAuthorityIdentityRegistry commitment)
    (evidence.recoveryAuthorizationRegistry commitment)
    (evidence.expectations index)
    (evidence.transactionRegistry commitment)
    evidence.registryValid
    evidence.recordValid
    evidence.claimValid
    evidence.receiptValid
    (evidence.recoveryLedgerRegistry commitment)
    (evidence.durableRecordRegistry commitment)
    (evidence.recoveryClaimRegistry commitment)
    (evidence.recoveryReceiptRegistry commitment)
    evidence.expectationRequestBindingValid
    evidence.authorizationRequestBindingValid
    evidence.recoveryIdentityBindingValid
    evidence.providerWorkerBindingValid
    evidence.recoveryProvenanceBindingValid
    evidence.recoveryAuthorityAssignmentValid

abbrev EffectDomainBridgeAt
    (evidence : SourceBoundEffectCompletionRecoveryEffectDomainRollbackTraceEvidence)
    (index : Nat) : Prop :=
  let commitment := evidence.CommitmentAt index
  SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridge
    (evidence.AuthorizedRecoveryAt index)
    (evidence.requestRegistry commitment)
    (evidence.recoveryClaimRegistry commitment).acquiredFenceToken
    (evidence.recoveryReceiptRegistry commitment)
    evidence.effectCoverageWitnessValid
    evidence.effectWorldValid
    evidence.compensationReceiptValid
    evidence.planEffectUniverseBindingValid
    evidence.observationWorldBindingValid
    evidence.compensationFenceBindingValid
    evidence.effectCompensationProvenanceBindingValid
    commitment
    (evidence.effectCoverageWitnessRegistry commitment)
    (evidence.effectObligationRegistry commitment)
    (evidence.compensationReceiptRegistry commitment)
    (evidence.effectWorldBeforeRegistry commitment)
    (evidence.effectWorldAfterRegistry commitment)

theorem effectDomainBridgeAt
    (evidence : SourceBoundEffectCompletionRecoveryEffectDomainRollbackTraceEvidence)
    (index : Nat)
    (required :
      sourceBoundEffectCompletionTransactionRecoveryRequired
        (evidence.trace index)) :
    evidence.EffectDomainBridgeAt index :=
  evidence.closed.effectDomainRollbackBindings index required

end SourceBoundEffectCompletionRecoveryEffectDomainRollbackTraceEvidence

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEffectDomainRollbackTraceEvidence
