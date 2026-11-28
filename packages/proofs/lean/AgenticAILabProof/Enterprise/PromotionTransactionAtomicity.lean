-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.HumanAuthorityAccountability

namespace AgenticAILabProof.Enterprise.PromotionTransactionAtomicity

open CedarDualEngineAuthorization

abbrev AuthoritySnapshotDigest := String
abbrev MaterializationPlanDigest := String
abbrev RuntimeStateDigest := String
abbrev TransactionId := String
abbrev CommitReceiptId := String

structure PromotionCommitSubject where
  authorization : AuthorizationSubject
  authoritySnapshotDigest : AuthoritySnapshotDigest
  materializationPlanDigest : MaterializationPlanDigest
  deriving DecidableEq, Repr

structure GovernanceSnapshot where
  epoch : Nat
  policySetDigest : PolicySetDigest
  entityStoreDigest : EntityStoreDigest
  authoritySnapshotDigest : AuthoritySnapshotDigest
  runtimeStateDigest : RuntimeStateDigest
  deriving DecidableEq, Repr

structure PromotionAdmissionReceipt where
  receiptId : ReceiptId
  subject : PromotionCommitSubject
  cedarDecisionReceiptId : ReceiptId
  leanDecisionReceiptId : ReceiptId
  humanAuthorityReceiptId : ReceiptId
  accepted : Bool
  deriving DecidableEq, Repr

def admissionOnlyMaterializationEligible
    (receipt : PromotionAdmissionReceipt) : Prop :=
  receipt.accepted = true

def admissionSubjectA : PromotionCommitSubject where
  authorization := subjectA
  authoritySnapshotDigest := "sha256:authority-before-revocation"
  materializationPlanDigest := "sha256:marlin-plan-a"

def acceptedAdmissionA : PromotionAdmissionReceipt where
  receiptId := "admission-a"
  subject := admissionSubjectA
  cedarDecisionReceiptId := "cedar-a"
  leanDecisionReceiptId := "lean-a"
  humanAuthorityReceiptId := "human-approval-a"
  accepted := true

def governanceAtAdmission : GovernanceSnapshot where
  epoch := 7
  policySetDigest := "sha256:policies-a"
  entityStoreDigest := "sha256:entities-a"
  authoritySnapshotDigest := "sha256:authority-before-revocation"
  runtimeStateDigest := "sha256:runtime-before"

def governanceAfterRevocation : GovernanceSnapshot where
  epoch := 8
  policySetDigest := "sha256:policies-a"
  entityStoreDigest := "sha256:entities-a"
  authoritySnapshotDigest := "sha256:authority-after-revocation"
  runtimeStateDigest := "sha256:runtime-before"

theorem admissionReceiptReplaysAfterGovernanceChange :
    admissionOnlyMaterializationEligible acceptedAdmissionA ∧
      governanceAtAdmission ≠ governanceAfterRevocation := by
  constructor
  · simp [admissionOnlyMaterializationEligible, acceptedAdmissionA]
  · decide

def sameAuthorizationDifferentAuthorityA : PromotionCommitSubject where
  authorization := subjectA
  authoritySnapshotDigest := "sha256:authority-a"
  materializationPlanDigest := "sha256:marlin-plan-a"

def sameAuthorizationDifferentAuthorityB : PromotionCommitSubject where
  authorization := subjectA
  authoritySnapshotDigest := "sha256:authority-b"
  materializationPlanDigest := "sha256:marlin-plan-a"

theorem authorizationSubjectDoesNotIdentifyAuthoritySnapshot :
    sameAuthorizationDifferentAuthorityA.authorization =
        sameAuthorizationDifferentAuthorityB.authorization ∧
      sameAuthorizationDifferentAuthorityA ≠
        sameAuthorizationDifferentAuthorityB := by
  constructor
  · rfl
  · decide

def commitSubjectMatchesSnapshot
    (subject : PromotionCommitSubject)
    (snapshot : GovernanceSnapshot) : Prop :=
  subject.authorization.epoch = snapshot.epoch ∧
    subject.authorization.policySetDigest = snapshot.policySetDigest ∧
    subject.authorization.entityStoreDigest = snapshot.entityStoreDigest ∧
    subject.authoritySnapshotDigest = snapshot.authoritySnapshotDigest

theorem staleAdmissionDoesNotMatchCurrentSnapshot :
    ¬ commitSubjectMatchesSnapshot
      admissionSubjectA
      governanceAfterRevocation := by
  intro snapshotMatch
  have epochMatches := snapshotMatch.1
  simp [
    admissionSubjectA,
    subjectA,
    governanceAfterRevocation
  ] at epochMatches

structure PromotionCommitRequest where
  transactionId : TransactionId
  admissionReceiptId : ReceiptId
  subject : PromotionCommitSubject
  expectedPreStateDigest : RuntimeStateDigest
  targetPostStateDigest : RuntimeStateDigest
  deriving DecidableEq, Repr

inductive CommitOutcome
  | committed
  | duplicate
  | rejected
  | rolledBack
  deriving DecidableEq, Repr

structure PromotionCommitReceipt where
  receiptId : CommitReceiptId
  transactionId : TransactionId
  admissionReceiptId : ReceiptId
  subject : PromotionCommitSubject
  observedSnapshot : GovernanceSnapshot
  preStateDigest : RuntimeStateDigest
  postStateDigest : RuntimeStateDigest
  outcome : CommitOutcome
  deriving DecidableEq, Repr

def outcomePreservesAtomicState
    (request : PromotionCommitRequest)
    (receipt : PromotionCommitReceipt) : Prop :=
  match receipt.outcome with
  | .committed =>
      receipt.postStateDigest = request.targetPostStateDigest
  | .duplicate =>
      receipt.postStateDigest = request.targetPostStateDigest
  | .rejected =>
      receipt.postStateDigest = receipt.preStateDigest
  | .rolledBack =>
      receipt.postStateDigest = receipt.preStateDigest

def AdmissionReceiptValid :=
  PromotionAdmissionReceipt → Prop

def CommitReceiptValid :=
  PromotionCommitReceipt → Prop

def promotionCommitEvidenceClosed
    (admissionValid : AdmissionReceiptValid)
    (commitValid : CommitReceiptValid)
    (currentSnapshot : GovernanceSnapshot)
    (admission : PromotionAdmissionReceipt)
    (request : PromotionCommitRequest)
    (receipt : PromotionCommitReceipt) : Prop :=
  admission.accepted = true ∧
    admissionValid admission ∧
    request.admissionReceiptId = admission.receiptId ∧
    request.subject = admission.subject ∧
    commitSubjectMatchesSnapshot request.subject currentSnapshot ∧
    request.expectedPreStateDigest = currentSnapshot.runtimeStateDigest ∧
    receipt.transactionId = request.transactionId ∧
    receipt.admissionReceiptId = admission.receiptId ∧
    receipt.subject = request.subject ∧
    receipt.observedSnapshot = currentSnapshot ∧
    receipt.preStateDigest = request.expectedPreStateDigest ∧
    outcomePreservesAtomicState request receipt ∧
    commitValid receipt

def commitRequestA : PromotionCommitRequest where
  transactionId := "promotion-transaction-a"
  admissionReceiptId := "admission-a"
  subject := admissionSubjectA
  expectedPreStateDigest := "sha256:runtime-before"
  targetPostStateDigest := "sha256:runtime-after"

def committedReceiptA : PromotionCommitReceipt where
  receiptId := "commit-a"
  transactionId := "promotion-transaction-a"
  admissionReceiptId := "admission-a"
  subject := admissionSubjectA
  observedSnapshot := governanceAtAdmission
  preStateDigest := "sha256:runtime-before"
  postStateDigest := "sha256:runtime-after"
  outcome := .committed

theorem commitEvidenceClosedAtAdmissionSnapshot :
    promotionCommitEvidenceClosed
      (fun _receipt => True)
      (fun _receipt => True)
      governanceAtAdmission
      acceptedAdmissionA
      commitRequestA
      committedReceiptA := by
  simp [
    promotionCommitEvidenceClosed,
    commitSubjectMatchesSnapshot,
    outcomePreservesAtomicState,
    governanceAtAdmission,
    acceptedAdmissionA,
    admissionSubjectA,
    subjectA,
    commitRequestA,
    committedReceiptA
  ]

theorem atomicCommitRejectsStaleAdmission :
    ¬ promotionCommitEvidenceClosed
      (fun _receipt => True)
      (fun _receipt => True)
      governanceAfterRevocation
      acceptedAdmissionA
      commitRequestA
      committedReceiptA := by
  intro closed
  exact staleAdmissionDoesNotMatchCurrentSnapshot closed.2.2.2.2.1

def forgedCommittedReceipt : PromotionCommitReceipt :=
  committedReceiptA

theorem matchingCommitFieldsDoNotProveCommitAuthority :
    outcomePreservesAtomicState commitRequestA forgedCommittedReceipt ∧
      ¬ promotionCommitEvidenceClosed
        (fun _receipt => True)
        (fun _receipt => False)
        governanceAtAdmission
        acceptedAdmissionA
        commitRequestA
        forgedCommittedReceipt := by
  constructor
  · simp [
      outcomePreservesAtomicState,
      commitRequestA,
      forgedCommittedReceipt,
      committedReceiptA
    ]
  · intro closed
    exact closed.2.2.2.2.2.2.2.2.2.2.2.2

theorem closedRejectedCommitPreservesPreState
    (admissionValid : AdmissionReceiptValid)
    (commitValid : CommitReceiptValid)
    (currentSnapshot : GovernanceSnapshot)
    (admission : PromotionAdmissionReceipt)
    (request : PromotionCommitRequest)
    (receipt : PromotionCommitReceipt)
    (closed :
      promotionCommitEvidenceClosed
        admissionValid
        commitValid
        currentSnapshot
        admission
        request
        receipt)
    (rejected : receipt.outcome = .rejected) :
    receipt.postStateDigest = receipt.preStateDigest := by
  have atomicState := closed.2.2.2.2.2.2.2.2.2.2.2.1
  simp [outcomePreservesAtomicState, rejected] at atomicState
  exact atomicState

theorem closedCommittedCommitReachesExactTarget
    (admissionValid : AdmissionReceiptValid)
    (commitValid : CommitReceiptValid)
    (currentSnapshot : GovernanceSnapshot)
    (admission : PromotionAdmissionReceipt)
    (request : PromotionCommitRequest)
    (receipt : PromotionCommitReceipt)
    (closed :
      promotionCommitEvidenceClosed
        admissionValid
        commitValid
        currentSnapshot
        admission
        request
        receipt)
    (committed : receipt.outcome = .committed) :
    receipt.postStateDigest = request.targetPostStateDigest := by
  have atomicState := closed.2.2.2.2.2.2.2.2.2.2.2.1
  simp [outcomePreservesAtomicState, committed] at atomicState
  exact atomicState

end AgenticAILabProof.Enterprise.PromotionTransactionAtomicity
