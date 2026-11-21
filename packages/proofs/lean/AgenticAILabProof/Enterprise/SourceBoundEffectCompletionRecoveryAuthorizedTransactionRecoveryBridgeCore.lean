-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.PromotionTransactionRecovery
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeCore

open CedarDualEngineAuthorization
open HumanAuthorityAccountability
open PromotionTransactionAtomicity
open PromotionTransactionRecovery
open SourceBoundCheckpointRestoreAuthorizationClosure
open SourceBoundEffectCompletionCrashRecoveryClosure
open SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleCore
open SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeCore
open SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeCore

abbrev SourceBoundEffectCompletionRecoveryExpectationRequestBindingValid :=
  SourceBoundLatestCheckpointRestoreRequest →
    PromotionCommitRequest →
      Prop

abbrev SourceBoundEffectCompletionRecoveryAuthorizationRequestBindingValid :=
  Cedar.Spec.Request →
    PromotionCommitRequest →
      RecoveryClaim →
        Prop

abbrev SourceBoundEffectCompletionRecoveryRecoveryIdentityBindingValid :=
  String →
    RecoveryReceiptId →
      Prop

abbrev SourceBoundEffectCompletionRecoveryProviderWorkerBindingValid :=
  String →
    WorkerId →
      Prop

abbrev SourceBoundEffectCompletionRecoveryRecoveryProvenanceBindingValid :=
  String →
    String →
      DurableTransactionRecord →
        RecoveryClaim →
          RecoveryReceipt →
            Prop

abbrev SourceBoundEffectCompletionRecoveryRecoveryAuthorityAssignmentValid :=
  String →
    String →
      PromotionActors →
        PromotionCommitSubject →
          RecoveryClaim →
            Prop

def sourceBoundEffectCompletionTransactionRecoveryRequired
    (state : SourceBoundEffectCompletionCrashRecoveryState) : Prop :=
  state = SourceBoundEffectCompletionCrashRecoveryState.executedUncommitted ∨
    state = SourceBoundEffectCompletionCrashRecoveryState.indeterminate

theorem transactionRecoveryRequiredIsNotCommitted
    {state : SourceBoundEffectCompletionCrashRecoveryState}
    (required : sourceBoundEffectCompletionTransactionRecoveryRequired state) :
    state ≠ SourceBoundEffectCompletionCrashRecoveryState.committed := by
  intro committed
  rcases required with executed | indeterminate
  · cases executed.symm.trans committed
  · cases indeterminate.symm.trans committed

structure SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridge
    (snapshotSubjectBindingValid :
      SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid)
    (semantics : DecisionSemantics)
    (decisionReceiptValid : DecisionReceiptValid)
    (dualDecisionIdentityValid :
      SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid)
    (authorityPathAuthorized : String → String → String → String → Prop)
    (separationOfDutySatisfied : String → String → String → Prop)
    (expectedAuthority expectedCommitment : String)
    (expectedBundle : BundleEvidenceBinding.BundleDigest)
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
    (commitLifecycle : SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence)
    (subject : AuthorizationSubject)
    (left right : DecisionReceipt)
    (actors : PromotionActors)
    (grant : AuthorityGrant)
    (humanReceipt : BoundAuthorityReceipt)
    (currentSnapshot : GovernanceSnapshot)
    (admission : PromotionAdmissionReceipt)
    (request : PromotionCommitRequest)
    (commitReceipt : PromotionCommitReceipt)
    (recoveryAuthorityIdentity : String)
    (recoveryLifecycle : SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (registry : List TransactionRegistryEntry)
    (registryValid : TransactionRegistryValid)
    (recordValid : DurableRecordValid)
    (claimValid : RecoveryClaimValid)
    (receiptValid : RecoveryReceiptValid)
    (ledger : List PromotionCommitReceipt)
    (record : DurableTransactionRecord)
    (claim : RecoveryClaim)
    (recoveryReceipt : RecoveryReceipt)
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
  humanAtomicBridge :
    SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridge
      snapshotSubjectBindingValid
      semantics
      decisionReceiptValid
      dualDecisionIdentityValid
      authorityPathAuthorized
      separationOfDutySatisfied
      expectedAuthority
      expectedCommitment
      expectedBundle
      authorityReceiptValid
      admissionReceiptValid
      commitReceiptValid
      dualDecisionEngineRolesValid
      humanAuthoritySnapshotBindingValid
      accountabilityAssignmentValid
      responsibilityScopeCoversPlanValid
      materializationPlanValid
      commitLifecycle
      subject
      left
      right
      actors
      grant
      humanReceipt
      currentSnapshot
      admission
      request
      commitReceipt
  recoveryAuthorizationAdmitted :
    recoveryLifecycle.Admitted
      authorityPathAuthorized
      separationOfDutySatisfied
      recoveryAuthorityIdentity
      expectedCommitment
  recoveryRuntimeEpochMatches :
    recoveryLifecycle.runtimeEpoch = expectation.runtimeEpoch
  recoveryLifecycleFenceMatches :
    recoveryLifecycle.activeFenceToken = expectation.activeFenceToken
  recoveryClaimFenceMatches :
    expectation.activeFenceToken = claim.acquiredFenceToken
  expectationRequestBinds :
    expectationRequestBindingValid expectation.request record.request
  authorizationRequestBinds :
    authorizationRequestBindingValid recoveryLifecycle.snapshot.request record.request claim
  recoveryIdentityBinds :
    recoveryIdentityBindingValid expectation.recoveryId recoveryReceipt.receiptId
  providerWorkerBinds :
    providerWorkerBindingValid expectation.providerIdentity claim.workerId
  recoveryProvenanceBinds :
    recoveryProvenanceBindingValid
      expectedCommitment
      expectation.provenanceDigest
      record
      claim
      recoveryReceipt
  recoveryAuthorityAssigns :
    recoveryAuthorityAssignmentValid
      recoveryLifecycle.authorityIdentity
      recoveryLifecycle.accountabilityIdentity
      actors
      record.request.subject
      claim
  recoveryScopeCoversPlan :
    responsibilityScopeCoversPlanValid
      recoveryLifecycle.responsibilityScopeDigest
      record.request.subject.materializationPlanDigest
  recordRequestMatchesAtomic :
    record.request = request
  recoveryBaseReceiptMatchesAtomic :
    recoveryReceipt.effectReceipt.base = commitReceipt
  recoveryCloses :
    RecoveryEvidenceClosed
      registry
      registryValid
      recordValid
      commitReceiptValid
      claimValid
      receiptValid
      ledger
      record
      claim
      recoveryReceipt

theorem closedAuthorizedRecoveryProvidesHumanAtomicBridge
    {snapshotSubjectBindingValid}
    {semantics}
    {decisionReceiptValid}
    {dualDecisionIdentityValid}
    {authorityPathAuthorized}
    {separationOfDutySatisfied}
    {expectedAuthority expectedCommitment}
    {expectedBundle}
    {authorityReceiptValid}
    {admissionReceiptValid}
    {commitReceiptValid}
    {dualDecisionEngineRolesValid}
    {humanAuthoritySnapshotBindingValid}
    {accountabilityAssignmentValid}
    {responsibilityScopeCoversPlanValid}
    {materializationPlanValid}
    {commitLifecycle}
    {subject}
    {left right}
    {actors}
    {grant}
    {humanReceipt}
    {currentSnapshot}
    {admission}
    {request}
    {commitReceipt}
    {recoveryAuthorityIdentity}
    {recoveryLifecycle}
    {expectation}
    {registry}
    {registryValid}
    {recordValid}
    {claimValid}
    {receiptValid}
    {ledger}
    {record}
    {claim}
    {recoveryReceipt}
    {expectationRequestBindingValid}
    {authorizationRequestBindingValid}
    {recoveryIdentityBindingValid}
    {providerWorkerBindingValid}
    {recoveryProvenanceBindingValid}
    {recoveryAuthorityAssignmentValid}
    (closed :
      SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridge
        snapshotSubjectBindingValid
        semantics
        decisionReceiptValid
        dualDecisionIdentityValid
        authorityPathAuthorized
        separationOfDutySatisfied
        expectedAuthority
        expectedCommitment
        expectedBundle
        authorityReceiptValid
        admissionReceiptValid
        commitReceiptValid
        dualDecisionEngineRolesValid
        humanAuthoritySnapshotBindingValid
        accountabilityAssignmentValid
        responsibilityScopeCoversPlanValid
        materializationPlanValid
        commitLifecycle
        subject
        left
        right
        actors
        grant
        humanReceipt
        currentSnapshot
        admission
        request
        commitReceipt
        recoveryAuthorityIdentity
        recoveryLifecycle
        expectation
        registry
        registryValid
        recordValid
        claimValid
        receiptValid
        ledger
        record
        claim
        recoveryReceipt
        expectationRequestBindingValid
        authorizationRequestBindingValid
        recoveryIdentityBindingValid
        providerWorkerBindingValid
        recoveryProvenanceBindingValid
        recoveryAuthorityAssignmentValid) :
    SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridge
      snapshotSubjectBindingValid
      semantics
      decisionReceiptValid
      dualDecisionIdentityValid
      authorityPathAuthorized
      separationOfDutySatisfied
      expectedAuthority
      expectedCommitment
      expectedBundle
      authorityReceiptValid
      admissionReceiptValid
      commitReceiptValid
      dualDecisionEngineRolesValid
      humanAuthoritySnapshotBindingValid
      accountabilityAssignmentValid
      responsibilityScopeCoversPlanValid
      materializationPlanValid
      commitLifecycle
      subject
      left
      right
      actors
      grant
      humanReceipt
      currentSnapshot
      admission
      request
      commitReceipt :=
  closed.humanAtomicBridge

theorem closedAuthorizedRecoveryProvidesRecoveryEvidence
    {snapshotSubjectBindingValid}
    {semantics}
    {decisionReceiptValid}
    {dualDecisionIdentityValid}
    {authorityPathAuthorized}
    {separationOfDutySatisfied}
    {expectedAuthority expectedCommitment}
    {expectedBundle}
    {authorityReceiptValid}
    {admissionReceiptValid}
    {commitReceiptValid}
    {dualDecisionEngineRolesValid}
    {humanAuthoritySnapshotBindingValid}
    {accountabilityAssignmentValid}
    {responsibilityScopeCoversPlanValid}
    {materializationPlanValid}
    {commitLifecycle}
    {subject}
    {left right}
    {actors}
    {grant}
    {humanReceipt}
    {currentSnapshot}
    {admission}
    {request}
    {commitReceipt}
    {recoveryAuthorityIdentity}
    {recoveryLifecycle}
    {expectation}
    {registry}
    {registryValid}
    {recordValid}
    {claimValid}
    {receiptValid}
    {ledger}
    {record}
    {claim}
    {recoveryReceipt}
    {expectationRequestBindingValid}
    {authorizationRequestBindingValid}
    {recoveryIdentityBindingValid}
    {providerWorkerBindingValid}
    {recoveryProvenanceBindingValid}
    {recoveryAuthorityAssignmentValid}
    (closed :
      SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridge
        snapshotSubjectBindingValid
        semantics
        decisionReceiptValid
        dualDecisionIdentityValid
        authorityPathAuthorized
        separationOfDutySatisfied
        expectedAuthority
        expectedCommitment
        expectedBundle
        authorityReceiptValid
        admissionReceiptValid
        commitReceiptValid
        dualDecisionEngineRolesValid
        humanAuthoritySnapshotBindingValid
        accountabilityAssignmentValid
        responsibilityScopeCoversPlanValid
        materializationPlanValid
        commitLifecycle
        subject
        left
        right
        actors
        grant
        humanReceipt
        currentSnapshot
        admission
        request
        commitReceipt
        recoveryAuthorityIdentity
        recoveryLifecycle
        expectation
        registry
        registryValid
        recordValid
        claimValid
        receiptValid
        ledger
        record
        claim
        recoveryReceipt
        expectationRequestBindingValid
        authorizationRequestBindingValid
        recoveryIdentityBindingValid
        providerWorkerBindingValid
        recoveryProvenanceBindingValid
        recoveryAuthorityAssignmentValid) :
    RecoveryEvidenceClosed
      registry
      registryValid
      recordValid
      commitReceiptValid
      claimValid
      receiptValid
      ledger
      record
      claim
      recoveryReceipt :=
  closed.recoveryCloses

theorem staleRecoveryEpochRejectsAuthorizedBridge
    {snapshotSubjectBindingValid}
    {semantics}
    {decisionReceiptValid}
    {dualDecisionIdentityValid}
    {authorityPathAuthorized}
    {separationOfDutySatisfied}
    {expectedAuthority expectedCommitment}
    {expectedBundle}
    {authorityReceiptValid}
    {admissionReceiptValid}
    {commitReceiptValid}
    {dualDecisionEngineRolesValid}
    {humanAuthoritySnapshotBindingValid}
    {accountabilityAssignmentValid}
    {responsibilityScopeCoversPlanValid}
    {materializationPlanValid}
    {commitLifecycle}
    {subject}
    {left right}
    {actors}
    {grant}
    {humanReceipt}
    {currentSnapshot}
    {admission}
    {request}
    {commitReceipt}
    {recoveryAuthorityIdentity}
    {recoveryLifecycle}
    {expectation}
    {registry}
    {registryValid}
    {recordValid}
    {claimValid}
    {receiptValid}
    {ledger}
    {record}
    {claim}
    {recoveryReceipt}
    {expectationRequestBindingValid}
    {authorizationRequestBindingValid}
    {recoveryIdentityBindingValid}
    {providerWorkerBindingValid}
    {recoveryProvenanceBindingValid}
    {recoveryAuthorityAssignmentValid}
    (stale : recoveryLifecycle.runtimeEpoch ≠ expectation.runtimeEpoch) :
    ¬ SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridge
      snapshotSubjectBindingValid
      semantics
      decisionReceiptValid
      dualDecisionIdentityValid
      authorityPathAuthorized
      separationOfDutySatisfied
      expectedAuthority
      expectedCommitment
      expectedBundle
      authorityReceiptValid
      admissionReceiptValid
      commitReceiptValid
      dualDecisionEngineRolesValid
      humanAuthoritySnapshotBindingValid
      accountabilityAssignmentValid
      responsibilityScopeCoversPlanValid
      materializationPlanValid
      commitLifecycle
      subject
      left
      right
      actors
      grant
      humanReceipt
      currentSnapshot
      admission
      request
      commitReceipt
      recoveryAuthorityIdentity
      recoveryLifecycle
      expectation
      registry
      registryValid
      recordValid
      claimValid
      receiptValid
      ledger
      record
      claim
      recoveryReceipt
      expectationRequestBindingValid
      authorizationRequestBindingValid
      recoveryIdentityBindingValid
      providerWorkerBindingValid
      recoveryProvenanceBindingValid
      recoveryAuthorityAssignmentValid := by
  intro closed
  exact stale closed.recoveryRuntimeEpochMatches

theorem wrongAtomicReceiptRejectsAuthorizedBridge
    {snapshotSubjectBindingValid}
    {semantics}
    {decisionReceiptValid}
    {dualDecisionIdentityValid}
    {authorityPathAuthorized}
    {separationOfDutySatisfied}
    {expectedAuthority expectedCommitment}
    {expectedBundle}
    {authorityReceiptValid}
    {admissionReceiptValid}
    {commitReceiptValid}
    {dualDecisionEngineRolesValid}
    {humanAuthoritySnapshotBindingValid}
    {accountabilityAssignmentValid}
    {responsibilityScopeCoversPlanValid}
    {materializationPlanValid}
    {commitLifecycle}
    {subject}
    {left right}
    {actors}
    {grant}
    {humanReceipt}
    {currentSnapshot}
    {admission}
    {request}
    {commitReceipt}
    {recoveryAuthorityIdentity}
    {recoveryLifecycle}
    {expectation}
    {registry}
    {registryValid}
    {recordValid}
    {claimValid}
    {receiptValid}
    {ledger}
    {record}
    {claim}
    {recoveryReceipt}
    {expectationRequestBindingValid}
    {authorizationRequestBindingValid}
    {recoveryIdentityBindingValid}
    {providerWorkerBindingValid}
    {recoveryProvenanceBindingValid}
    {recoveryAuthorityAssignmentValid}
    (wrong : recoveryReceipt.effectReceipt.base ≠ commitReceipt) :
    ¬ SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridge
      snapshotSubjectBindingValid
      semantics
      decisionReceiptValid
      dualDecisionIdentityValid
      authorityPathAuthorized
      separationOfDutySatisfied
      expectedAuthority
      expectedCommitment
      expectedBundle
      authorityReceiptValid
      admissionReceiptValid
      commitReceiptValid
      dualDecisionEngineRolesValid
      humanAuthoritySnapshotBindingValid
      accountabilityAssignmentValid
      responsibilityScopeCoversPlanValid
      materializationPlanValid
      commitLifecycle
      subject
      left
      right
      actors
      grant
      humanReceipt
      currentSnapshot
      admission
      request
      commitReceipt
      recoveryAuthorityIdentity
      recoveryLifecycle
      expectation
      registry
      registryValid
      recordValid
      claimValid
      receiptValid
      ledger
      record
      claim
      recoveryReceipt
      expectationRequestBindingValid
      authorizationRequestBindingValid
      recoveryIdentityBindingValid
      providerWorkerBindingValid
      recoveryProvenanceBindingValid
      recoveryAuthorityAssignmentValid := by
  intro closed
  exact wrong closed.recoveryBaseReceiptMatchesAtomic

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeCore
