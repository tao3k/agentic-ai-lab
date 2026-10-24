-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.HumanAuthorityAccountability
import AgenticAILabProof.Enterprise.PromotionTransactionAtomicity
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeCore

open CedarDualEngineAuthorization
open HumanAuthorityAccountability
open PromotionTransactionAtomicity
open SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleCore
open SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeCore

/-!
# Human authority and atomic materialization bridge

The bridge connects the exact Cedar authorization subject to accountable human
authority and the current atomic materialization transaction.  Approval,
execution authority, accountability, authority-snapshot provenance,
responsibility scope, admission authority, and commit authority remain
separate proof obligations.
-/

def SourceBoundEffectCompletionRecoveryDualDecisionEngineRolesValid :=
  DecisionReceipt → DecisionReceipt → Prop

def SourceBoundEffectCompletionRecoveryHumanAuthoritySnapshotBindingValid :=
  AuthorityGrant →
    BoundAuthorityReceipt →
    AuthoritySnapshotDigest →
    Prop

def SourceBoundEffectCompletionRecoveryAccountabilityAssignmentValid :=
  String → PromotionActors → PromotionCommitSubject → Prop

def SourceBoundEffectCompletionRecoveryResponsibilityScopeCoversPlanValid :=
  String → MaterializationPlanDigest → Prop

def SourceBoundEffectCompletionRecoveryMaterializationPlanValid :=
  MaterializationPlanDigest → Prop

structure SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBound
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
    (lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence)
    (subject : AuthorizationSubject)
    (left right : DecisionReceipt)
    (actors : PromotionActors)
    (grant : AuthorityGrant)
    (humanReceipt : BoundAuthorityReceipt)
    (currentSnapshot : GovernanceSnapshot)
    (admission : PromotionAdmissionReceipt)
    (request : PromotionCommitRequest)
    (commitReceipt : PromotionCommitReceipt) : Prop where
  decisionEngineRolesBind :
    dualDecisionEngineRolesValid left right
  humanAuthorityCloses :
    humanPromotionEvidenceClosed
      actors authorityReceiptValid grant humanReceipt subject
  lifecycleAuthorityIsExecutor :
    lifecycle.authorityIdentity = actors.executor
  accountabilityAssigned :
    accountabilityAssignmentValid
      lifecycle.accountabilityIdentity actors admission.subject
  humanAuthoritySnapshotBinds :
    humanAuthoritySnapshotBindingValid
      grant humanReceipt admission.subject.authoritySnapshotDigest
  commitSubjectAuthorizationMatches :
    admission.subject.authorization = subject
  responsibilityScopeCoversPlan :
    responsibilityScopeCoversPlanValid
      lifecycle.responsibilityScopeDigest
      admission.subject.materializationPlanDigest
  materializationPlanValidates :
    materializationPlanValid
      admission.subject.materializationPlanDigest
  admissionCedarReceiptMatches :
    admission.cedarDecisionReceiptId = left.receiptId
  admissionLeanReceiptMatches :
    admission.leanDecisionReceiptId = right.receiptId
  admissionHumanReceiptMatches :
    admission.humanAuthorityReceiptId = humanReceipt.receiptId
  atomicCommitCloses :
    promotionCommitEvidenceClosed
      admissionReceiptValid
      commitReceiptValid
      currentSnapshot
      admission
      request
      commitReceipt

structure SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridge
    (snapshotSubjectBindingValid :
      SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid)
    (semantics : DecisionSemantics)
    (decisionReceiptValid : DecisionReceiptValid)
    (dualDecisionIdentityValid :
      SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid)
    (authorityPathAuthorized :
      String → String → String → String → Prop)
    (separationOfDutySatisfied :
      String → String → String → Prop)
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
    (lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence)
    (subject : AuthorizationSubject)
    (left right : DecisionReceipt)
    (actors : PromotionActors)
    (grant : AuthorityGrant)
    (humanReceipt : BoundAuthorityReceipt)
    (currentSnapshot : GovernanceSnapshot)
    (admission : PromotionAdmissionReceipt)
    (request : PromotionCommitRequest)
    (commitReceipt : PromotionCommitReceipt) : Prop where
  subjectBridge :
    SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridge
      snapshotSubjectBindingValid
      semantics
      decisionReceiptValid
      dualDecisionIdentityValid
      authorityPathAuthorized
      separationOfDutySatisfied
      expectedAuthority
      expectedCommitment
      expectedBundle
      lifecycle
      subject
      left
      right
  humanAtomicBound :
    SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBound
      authorityReceiptValid
      admissionReceiptValid
      commitReceiptValid
      dualDecisionEngineRolesValid
      humanAuthoritySnapshotBindingValid
      accountabilityAssignmentValid
      responsibilityScopeCoversPlanValid
      materializationPlanValid
      lifecycle
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

theorem closedHumanAtomicBridgeProvidesSubjectAuthorization
    {snapshotSubjectBindingValid :
      SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid}
    {semantics : DecisionSemantics}
    {decisionReceiptValid : DecisionReceiptValid}
    {dualDecisionIdentityValid :
      SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid}
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {expectedAuthority expectedCommitment : String}
    {expectedBundle : BundleEvidenceBinding.BundleDigest}
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
    {lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {subject : AuthorizationSubject}
    {left right : DecisionReceipt}
    {actors : PromotionActors}
    {grant : AuthorityGrant}
    {humanReceipt : BoundAuthorityReceipt}
    {currentSnapshot : GovernanceSnapshot}
    {admission : PromotionAdmissionReceipt}
    {request : PromotionCommitRequest}
    {commitReceipt : PromotionCommitReceipt}
    (closed :
      SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridge
        snapshotSubjectBindingValid semantics decisionReceiptValid
        dualDecisionIdentityValid authorityPathAuthorized
        separationOfDutySatisfied expectedAuthority expectedCommitment
        expectedBundle authorityReceiptValid admissionReceiptValid
        commitReceiptValid dualDecisionEngineRolesValid
        humanAuthoritySnapshotBindingValid accountabilityAssignmentValid
        responsibilityScopeCoversPlanValid materializationPlanValid
        lifecycle subject left right actors grant humanReceipt
        currentSnapshot admission request commitReceipt) :
    SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridge
      snapshotSubjectBindingValid semantics decisionReceiptValid
      dualDecisionIdentityValid authorityPathAuthorized
      separationOfDutySatisfied expectedAuthority expectedCommitment
      expectedBundle lifecycle subject left right :=
  closed.subjectBridge

theorem closedHumanAtomicBridgeProvidesHumanAuthority
    {snapshotSubjectBindingValid :
      SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid}
    {semantics : DecisionSemantics}
    {decisionReceiptValid : DecisionReceiptValid}
    {dualDecisionIdentityValid :
      SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid}
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {expectedAuthority expectedCommitment : String}
    {expectedBundle : BundleEvidenceBinding.BundleDigest}
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
    {lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {subject : AuthorizationSubject}
    {left right : DecisionReceipt}
    {actors : PromotionActors}
    {grant : AuthorityGrant}
    {humanReceipt : BoundAuthorityReceipt}
    {currentSnapshot : GovernanceSnapshot}
    {admission : PromotionAdmissionReceipt}
    {request : PromotionCommitRequest}
    {commitReceipt : PromotionCommitReceipt}
    (closed :
      SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridge
        snapshotSubjectBindingValid semantics decisionReceiptValid
        dualDecisionIdentityValid authorityPathAuthorized
        separationOfDutySatisfied expectedAuthority expectedCommitment
        expectedBundle authorityReceiptValid admissionReceiptValid
        commitReceiptValid dualDecisionEngineRolesValid
        humanAuthoritySnapshotBindingValid accountabilityAssignmentValid
        responsibilityScopeCoversPlanValid materializationPlanValid
        lifecycle subject left right actors grant humanReceipt
        currentSnapshot admission request commitReceipt) :
    humanPromotionEvidenceClosed
      actors authorityReceiptValid grant humanReceipt subject :=
  closed.humanAtomicBound.humanAuthorityCloses

theorem closedHumanAtomicBridgeProvidesAtomicCommit
    {snapshotSubjectBindingValid :
      SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid}
    {semantics : DecisionSemantics}
    {decisionReceiptValid : DecisionReceiptValid}
    {dualDecisionIdentityValid :
      SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid}
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {expectedAuthority expectedCommitment : String}
    {expectedBundle : BundleEvidenceBinding.BundleDigest}
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
    {lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {subject : AuthorizationSubject}
    {left right : DecisionReceipt}
    {actors : PromotionActors}
    {grant : AuthorityGrant}
    {humanReceipt : BoundAuthorityReceipt}
    {currentSnapshot : GovernanceSnapshot}
    {admission : PromotionAdmissionReceipt}
    {request : PromotionCommitRequest}
    {commitReceipt : PromotionCommitReceipt}
    (closed :
      SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridge
        snapshotSubjectBindingValid semantics decisionReceiptValid
        dualDecisionIdentityValid authorityPathAuthorized
        separationOfDutySatisfied expectedAuthority expectedCommitment
        expectedBundle authorityReceiptValid admissionReceiptValid
        commitReceiptValid dualDecisionEngineRolesValid
        humanAuthoritySnapshotBindingValid accountabilityAssignmentValid
        responsibilityScopeCoversPlanValid materializationPlanValid
        lifecycle subject left right actors grant humanReceipt
        currentSnapshot admission request commitReceipt) :
    promotionCommitEvidenceClosed
      admissionReceiptValid
      commitReceiptValid
      currentSnapshot
      admission
      request
      commitReceipt :=
  closed.humanAtomicBound.atomicCommitCloses

theorem staleGovernanceRejectsHumanAtomicBridge
    {snapshotSubjectBindingValid :
      SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid}
    {semantics : DecisionSemantics}
    {decisionReceiptValid : DecisionReceiptValid}
    {dualDecisionIdentityValid :
      SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid}
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {expectedAuthority expectedCommitment : String}
    {expectedBundle : BundleEvidenceBinding.BundleDigest}
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
    {lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {subject : AuthorizationSubject}
    {left right : DecisionReceipt}
    {actors : PromotionActors}
    {grant : AuthorityGrant}
    {humanReceipt : BoundAuthorityReceipt}
    {currentSnapshot : GovernanceSnapshot}
    {admission : PromotionAdmissionReceipt}
    {request : PromotionCommitRequest}
    {commitReceipt : PromotionCommitReceipt}
    (stale :
      ¬ commitSubjectMatchesSnapshot
        admission.subject currentSnapshot) :
    ¬ SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridge
        snapshotSubjectBindingValid semantics decisionReceiptValid
        dualDecisionIdentityValid authorityPathAuthorized
        separationOfDutySatisfied expectedAuthority expectedCommitment
        expectedBundle authorityReceiptValid admissionReceiptValid
        commitReceiptValid dualDecisionEngineRolesValid
        humanAuthoritySnapshotBindingValid accountabilityAssignmentValid
        responsibilityScopeCoversPlanValid materializationPlanValid
        lifecycle subject left right actors grant humanReceipt
        currentSnapshot admission request commitReceipt := by
  intro closed
  have atomic := closed.humanAtomicBound.atomicCommitCloses
  exact stale
    (atomic.2.2.2.1 ▸ atomic.2.2.2.2.1)

theorem invalidHumanAuthoritySnapshotBindingRejectsBridge
    {snapshotSubjectBindingValid :
      SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid}
    {semantics : DecisionSemantics}
    {decisionReceiptValid : DecisionReceiptValid}
    {dualDecisionIdentityValid :
      SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid}
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {expectedAuthority expectedCommitment : String}
    {expectedBundle : BundleEvidenceBinding.BundleDigest}
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
    {lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {subject : AuthorizationSubject}
    {left right : DecisionReceipt}
    {actors : PromotionActors}
    {grant : AuthorityGrant}
    {humanReceipt : BoundAuthorityReceipt}
    {currentSnapshot : GovernanceSnapshot}
    {admission : PromotionAdmissionReceipt}
    {request : PromotionCommitRequest}
    {commitReceipt : PromotionCommitReceipt}
    (invalid :
      ¬ humanAuthoritySnapshotBindingValid
        grant humanReceipt admission.subject.authoritySnapshotDigest) :
    ¬ SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridge
        snapshotSubjectBindingValid semantics decisionReceiptValid
        dualDecisionIdentityValid authorityPathAuthorized
        separationOfDutySatisfied expectedAuthority expectedCommitment
        expectedBundle authorityReceiptValid admissionReceiptValid
        commitReceiptValid dualDecisionEngineRolesValid
        humanAuthoritySnapshotBindingValid accountabilityAssignmentValid
        responsibilityScopeCoversPlanValid materializationPlanValid
        lifecycle subject left right actors grant humanReceipt
        currentSnapshot admission request commitReceipt := by
  intro closed
  exact invalid
    closed.humanAtomicBound.humanAuthoritySnapshotBinds

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeCore
