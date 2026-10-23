-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeModel

/-!
# Independent human-authority and atomic-materialization bridge model

Authorization, accountable human authority, current governance, admission
authority, and commit authority are independent obligations.  One canonical
bridge requires all of them for the same subject and transaction.
-/

structure AuthorizationSubject where
  requestDigest : Nat
  policySetDigest : Nat
  entityStoreDigest : Nat
  bundleDigest : Nat
  epoch : Nat
  deriving DecidableEq, Repr

structure AuthorizationBridgeEvidence where
  decisionIdentity : Nat
  leftEngineIdentity : Nat
  rightEngineIdentity : Nat
  authorityIdentity : Nat
  accountabilityIdentity : Nat
  responsibilityScopeDigest : Nat
  subject : AuthorizationSubject
  deriving DecidableEq, Repr

def authorizationBridgeClosed
    (evidence : AuthorizationBridgeEvidence)
    (subject : AuthorizationSubject) : Prop :=
  evidence.decisionIdentity ≠ 0 ∧
  evidence.leftEngineIdentity ≠ evidence.rightEngineIdentity ∧
  evidence.authorityIdentity ≠ 0 ∧
  evidence.accountabilityIdentity ≠ 0 ∧
  evidence.responsibilityScopeDigest ≠ 0 ∧
  evidence.subject = subject

structure PromotionActors where
  proposer : Nat
  approver : Nat
  executor : Nat
  deriving DecidableEq, Repr

def separationOfDuties (actors : PromotionActors) : Prop :=
  actors.proposer ≠ actors.approver ∧
  actors.approver ≠ actors.executor ∧
  actors.proposer ≠ actors.executor

structure HumanAuthorityReceipt where
  receiptIdentity : Nat
  principal : Nat
  subject : AuthorizationSubject
  authoritySnapshotDigest : Nat
  accepted : Bool
  deriving DecidableEq, Repr

def HumanAuthorityReceiptValid :=
  HumanAuthorityReceipt → Prop

def humanAuthorityClosed
    (valid : HumanAuthorityReceiptValid)
    (actors : PromotionActors)
    (receipt : HumanAuthorityReceipt)
    (subject : AuthorizationSubject) : Prop :=
  separationOfDuties actors ∧
  receipt.receiptIdentity ≠ 0 ∧
  receipt.accepted = true ∧
  receipt.principal = actors.approver ∧
  receipt.subject = subject ∧
  valid receipt

structure PromotionCommitSubject where
  authorization : AuthorizationSubject
  authoritySnapshotDigest : Nat
  materializationPlanDigest : Nat
  deriving DecidableEq, Repr

structure GovernanceSnapshot where
  epoch : Nat
  policySetDigest : Nat
  entityStoreDigest : Nat
  authoritySnapshotDigest : Nat
  runtimeStateDigest : Nat
  deriving DecidableEq, Repr

def commitSubjectMatchesSnapshot
    (subject : PromotionCommitSubject)
    (snapshot : GovernanceSnapshot) : Prop :=
  subject.authorization.epoch = snapshot.epoch ∧
  subject.authorization.policySetDigest = snapshot.policySetDigest ∧
  subject.authorization.entityStoreDigest = snapshot.entityStoreDigest ∧
  subject.authoritySnapshotDigest = snapshot.authoritySnapshotDigest

structure AdmissionReceipt where
  receiptIdentity : Nat
  subject : PromotionCommitSubject
  decisionEvidenceIdentity : Nat
  humanAuthorityReceiptIdentity : Nat
  accepted : Bool
  deriving DecidableEq, Repr

def AdmissionReceiptValid :=
  AdmissionReceipt → Prop

structure CommitRequest where
  transactionIdentity : Nat
  admissionReceiptIdentity : Nat
  subject : PromotionCommitSubject
  expectedPreStateDigest : Nat
  targetPostStateDigest : Nat
  deriving DecidableEq, Repr

structure CommitReceipt where
  receiptIdentity : Nat
  transactionIdentity : Nat
  admissionReceiptIdentity : Nat
  subject : PromotionCommitSubject
  preStateDigest : Nat
  postStateDigest : Nat
  committed : Bool
  deriving DecidableEq, Repr

def CommitReceiptValid :=
  CommitReceipt → Prop

def AccountabilityAssignmentValid :=
  Nat → PromotionActors → PromotionCommitSubject → Prop

def DualDecisionEngineRolesValid :=
  Nat → Nat → Prop

def ResponsibilityScopeCoversPlanValid :=
  Nat → Nat → Prop

def humanAuthorityAtomicMaterializationClosed
    (humanValid : HumanAuthorityReceiptValid)
    (admissionValid : AdmissionReceiptValid)
    (commitValid : CommitReceiptValid)
    (accountabilityValid : AccountabilityAssignmentValid)
    (engineRolesValid : DualDecisionEngineRolesValid)
    (responsibilityScopeCoversPlanValid :
      ResponsibilityScopeCoversPlanValid)
    (authorization : AuthorizationBridgeEvidence)
    (subject : AuthorizationSubject)
    (actors : PromotionActors)
    (humanReceipt : HumanAuthorityReceipt)
    (commitSubject : PromotionCommitSubject)
    (snapshot : GovernanceSnapshot)
    (admission : AdmissionReceipt)
    (request : CommitRequest)
    (commitReceipt : CommitReceipt) : Prop :=
  authorizationBridgeClosed authorization subject ∧
  engineRolesValid
    authorization.leftEngineIdentity
    authorization.rightEngineIdentity ∧
  humanAuthorityClosed humanValid actors humanReceipt subject ∧
  authorization.authorityIdentity = actors.executor ∧
  accountabilityValid
    authorization.accountabilityIdentity actors commitSubject ∧
  responsibilityScopeCoversPlanValid
    authorization.responsibilityScopeDigest
    commitSubject.materializationPlanDigest ∧
  commitSubject.authorization = subject ∧
  commitSubject.materializationPlanDigest ≠ 0 ∧
  commitSubjectMatchesSnapshot commitSubject snapshot ∧
  admission.receiptIdentity ≠ 0 ∧
  admission.accepted = true ∧
  admission.subject = commitSubject ∧
  admission.decisionEvidenceIdentity = authorization.decisionIdentity ∧
  admission.humanAuthorityReceiptIdentity =
    humanReceipt.receiptIdentity ∧
  admissionValid admission ∧
  request.transactionIdentity ≠ 0 ∧
  request.admissionReceiptIdentity = admission.receiptIdentity ∧
  request.subject = commitSubject ∧
  request.expectedPreStateDigest = snapshot.runtimeStateDigest ∧
  commitReceipt.receiptIdentity ≠ 0 ∧
  commitReceipt.transactionIdentity = request.transactionIdentity ∧
  commitReceipt.admissionReceiptIdentity =
    admission.receiptIdentity ∧
  commitReceipt.subject = commitSubject ∧
  commitReceipt.preStateDigest = request.expectedPreStateDigest ∧
  commitReceipt.committed = true ∧
  commitReceipt.postStateDigest = request.targetPostStateDigest ∧
  commitValid commitReceipt

def subjectA : AuthorizationSubject where
  requestDigest := 11
  policySetDigest := 21
  entityStoreDigest := 31
  bundleDigest := 41
  epoch := 7

def authorizationA : AuthorizationBridgeEvidence where
  decisionIdentity := 51
  leftEngineIdentity := 52
  rightEngineIdentity := 53
  authorityIdentity := 61
  accountabilityIdentity := 71
  responsibilityScopeDigest := 72
  subject := subjectA

theorem authorizationDoesNotProveHumanAuthority :
    authorizationBridgeClosed authorizationA subjectA ∧
    ¬ humanAuthorityClosed
      (fun _receipt => False)
      { proposer := 1, approver := 2, executor := 3 }
      {
        receiptIdentity := 81
        principal := 2
        subject := subjectA
        authoritySnapshotDigest := 91
        accepted := true
      }
      subjectA := by
  constructor
  · simp [authorizationBridgeClosed, authorizationA]
  · intro closed
    exact closed.2.2.2.2.2

theorem distinctEngineIdentitiesDoNotAssignCedarAndLeanRoles :
    authorizationA.leftEngineIdentity ≠
        authorizationA.rightEngineIdentity ∧
    ¬ (fun _left _right => False)
      authorizationA.leftEngineIdentity
      authorizationA.rightEngineIdentity := by
  simp [authorizationA]

theorem nonemptyResponsibilityScopeDoesNotCoverMaterializationPlan :
    authorizationA.responsibilityScopeDigest ≠ 0 ∧
    ¬ (fun _scope _plan => False)
      authorizationA.responsibilityScopeDigest
      101 := by
  simp [authorizationA]

def humanReceiptAtAdmission : HumanAuthorityReceipt where
  receiptIdentity := 81
  principal := 2
  subject := subjectA
  authoritySnapshotDigest := 91
  accepted := true

def commitSubjectAtAdmission : PromotionCommitSubject where
  authorization := subjectA
  authoritySnapshotDigest := 91
  materializationPlanDigest := 101

def governanceAfterAuthorityChange : GovernanceSnapshot where
  epoch := 7
  policySetDigest := 21
  entityStoreDigest := 31
  authoritySnapshotDigest := 92
  runtimeStateDigest := 111

theorem humanAuthorityAtAdmissionDoesNotProveCurrentGovernance :
    humanAuthorityClosed
      (fun _receipt => True)
      { proposer := 1, approver := 2, executor := 3 }
      humanReceiptAtAdmission
      subjectA ∧
    ¬ commitSubjectMatchesSnapshot
      commitSubjectAtAdmission
      governanceAfterAuthorityChange := by
  constructor
  · simp [
      humanAuthorityClosed,
      separationOfDuties,
      humanReceiptAtAdmission
    ]
  · simp [
      commitSubjectMatchesSnapshot,
      commitSubjectAtAdmission,
      subjectA,
      governanceAfterAuthorityChange
    ]

def admissionA : AdmissionReceipt where
  receiptIdentity := 121
  subject := commitSubjectAtAdmission
  decisionEvidenceIdentity := 51
  humanAuthorityReceiptIdentity := 81
  accepted := true

theorem matchingAdmissionFieldsDoNotProveAdmissionAuthority :
    admissionA.accepted = true ∧
    admissionA.subject = commitSubjectAtAdmission ∧
    ¬ (fun _admission : AdmissionReceipt => False) admissionA := by
  simp [admissionA]

def requestA : CommitRequest where
  transactionIdentity := 131
  admissionReceiptIdentity := 121
  subject := commitSubjectAtAdmission
  expectedPreStateDigest := 111
  targetPostStateDigest := 112

def commitReceiptA : CommitReceipt where
  receiptIdentity := 141
  transactionIdentity := 131
  admissionReceiptIdentity := 121
  subject := commitSubjectAtAdmission
  preStateDigest := 111
  postStateDigest := 112
  committed := true

theorem matchingCommitFieldsDoNotProveCommitAuthority :
    commitReceiptA.transactionIdentity = requestA.transactionIdentity ∧
    commitReceiptA.postStateDigest = requestA.targetPostStateDigest ∧
    ¬ (fun _receipt : CommitReceipt => False) commitReceiptA := by
  simp [commitReceiptA, requestA]

theorem canonicalBridgeRejectsStaleAuthoritySnapshot
    {humanValid : HumanAuthorityReceiptValid}
    {admissionValid : AdmissionReceiptValid}
    {commitValid : CommitReceiptValid}
    {accountabilityValid : AccountabilityAssignmentValid}
    {engineRolesValid : DualDecisionEngineRolesValid}
    {responsibilityScopeCoversPlanValid :
      ResponsibilityScopeCoversPlanValid}
    {authorization : AuthorizationBridgeEvidence}
    {subject : AuthorizationSubject}
    {actors : PromotionActors}
    {humanReceipt : HumanAuthorityReceipt}
    {commitSubject : PromotionCommitSubject}
    {snapshot : GovernanceSnapshot}
    {admission : AdmissionReceipt}
    {request : CommitRequest}
    {commitReceipt : CommitReceipt}
    (stale :
      commitSubject.authoritySnapshotDigest ≠
        snapshot.authoritySnapshotDigest) :
    ¬ humanAuthorityAtomicMaterializationClosed
        humanValid
        admissionValid
        commitValid
        accountabilityValid
        engineRolesValid
        responsibilityScopeCoversPlanValid
        authorization
        subject
        actors
        humanReceipt
        commitSubject
        snapshot
        admission
        request
        commitReceipt := by
  intro closed
  exact stale closed.2.2.2.2.2.2.2.2.1.2.2.2

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryHumanAuthorityAtomicMaterializationBridgeModel
