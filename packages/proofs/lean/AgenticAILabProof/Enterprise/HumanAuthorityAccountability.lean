-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.CedarDualEngineAuthorization

namespace AgenticAILabProof.Enterprise.HumanAuthorityAccountability

open CedarDualEngineAuthorization

abbrev PrincipalId := String
abbrev GrantId := String
abbrev DelegationRootDigest := String

inductive Capability
  | propose
  | approve
  | execute
  | revoke
  deriving DecidableEq, Repr

structure UnboundAuthorityReceipt where
  principal : PrincipalId
  capability : Capability
  accepted : Bool
  deriving DecidableEq, Repr

def acceptsUnboundAuthority
    (_subject : AuthorizationSubject)
    (receipt : UnboundAuthorityReceipt) : Prop :=
  receipt.accepted = true

def unboundApproval : UnboundAuthorityReceipt where
  principal := "alice"
  capability := .approve
  accepted := true

theorem unboundAuthorityReplaysAcrossSubjects :
    acceptsUnboundAuthority subjectA unboundApproval ∧
      acceptsUnboundAuthority subjectB unboundApproval := by
  constructor <;> simp [acceptsUnboundAuthority, unboundApproval]

structure AuthorityGrant where
  grantId : GrantId
  principal : PrincipalId
  capability : Capability
  scopeSubject : AuthorizationSubject
  validFromEpoch : Nat
  validUntilEpoch : Nat
  revokedAtEpoch : Option Nat
  delegationRootDigest : DelegationRootDigest
  deriving DecidableEq, Repr

structure BoundAuthorityReceipt where
  receiptId : ReceiptId
  principal : PrincipalId
  capability : Capability
  subject : AuthorizationSubject
  grantId : GrantId
  accepted : Bool
  deriving DecidableEq, Repr

def grantNotRevokedAt
    (grant : AuthorityGrant)
    (epoch : Nat) : Prop :=
  match grant.revokedAtEpoch with
  | none => True
  | some revokedAt => epoch < revokedAt

def grantAuthorizes
    (grant : AuthorityGrant)
    (receipt : BoundAuthorityReceipt) : Prop :=
  receipt.principal = grant.principal ∧
    receipt.capability = grant.capability ∧
    receipt.grantId = grant.grantId ∧
    receipt.subject = grant.scopeSubject ∧
    grant.validFromEpoch ≤ receipt.subject.epoch ∧
    receipt.subject.epoch ≤ grant.validUntilEpoch ∧
    grantNotRevokedAt grant receipt.subject.epoch

def AuthorityReceiptValid :=
  BoundAuthorityReceipt → Prop

def authorityEvidenceClosed
    (valid : AuthorityReceiptValid)
    (grant : AuthorityGrant)
    (receipt : BoundAuthorityReceipt) : Prop :=
  receipt.accepted = true ∧
    grantAuthorizes grant receipt ∧
    valid receipt

def approvalGrantA : AuthorityGrant where
  grantId := "grant-approve-a"
  principal := "alice"
  capability := .approve
  scopeSubject := subjectA
  validFromEpoch := 1
  validUntilEpoch := 10
  revokedAtEpoch := none
  delegationRootDigest := "sha256:delegation-root"

def boundApprovalA : BoundAuthorityReceipt where
  receiptId := "human-approval-a"
  principal := "alice"
  capability := .approve
  subject := subjectA
  grantId := "grant-approve-a"
  accepted := true

theorem approvalAuthorityEvidenceClosed :
    authorityEvidenceClosed
      (fun _receipt => True)
      approvalGrantA
      boundApprovalA := by
  simp [
    authorityEvidenceClosed,
    grantAuthorizes,
    grantNotRevokedAt,
    approvalGrantA,
    boundApprovalA,
    subjectA
  ]

def revokedApprovalGrant : AuthorityGrant :=
  { approvalGrantA with revokedAtEpoch := some 7 }

theorem revokedAuthorityRejected :
    ¬ authorityEvidenceClosed
      (fun _receipt => True)
      revokedApprovalGrant
      boundApprovalA := by
  intro closed
  have notRevoked := closed.2.1.2.2.2.2.2
  simp [
    grantNotRevokedAt,
    revokedApprovalGrant,
    boundApprovalA,
    subjectA
  ] at notRevoked

def approvalForSubjectB : BoundAuthorityReceipt :=
  { boundApprovalA with subject := subjectB }

theorem authorityScopeMismatchRejected :
    ¬ authorityEvidenceClosed
      (fun _receipt => True)
      approvalGrantA
      approvalForSubjectB := by
  intro closed
  have scopeMatches := closed.2.1.2.2.2.1
  simp [
    approvalGrantA,
    approvalForSubjectB,
    subjectA,
    subjectB
  ] at scopeMatches

theorem matchingGrantFieldsDoNotProveAuthorityReceiptValidity :
    grantAuthorizes approvalGrantA boundApprovalA ∧
      ¬ authorityEvidenceClosed
        (fun _receipt => False)
        approvalGrantA
        boundApprovalA := by
  constructor
  · exact approvalAuthorityEvidenceClosed.2.1
  · intro closed
    exact closed.2.2

structure PromotionActors where
  proposer : PrincipalId
  approver : PrincipalId
  executor : PrincipalId
  deriving DecidableEq, Repr

def rolesPopulated (actors : PromotionActors) : Prop :=
  actors.proposer ≠ "" ∧ actors.approver ≠ "" ∧ actors.executor ≠ ""

def separationOfDuties (actors : PromotionActors) : Prop :=
  actors.proposer ≠ actors.approver ∧
    actors.approver ≠ actors.executor ∧
    actors.proposer ≠ actors.executor

def selfApprovedActors : PromotionActors where
  proposer := "alice"
  approver := "alice"
  executor := "alice"

theorem populatedRolesDoNotImplySeparationOfDuties :
    rolesPopulated selfApprovedActors ∧
      ¬ separationOfDuties selfApprovedActors := by
  simp [rolesPopulated, separationOfDuties, selfApprovedActors]

def humanPromotionEvidenceClosed
    (actors : PromotionActors)
    (authorityValid : AuthorityReceiptValid)
    (grant : AuthorityGrant)
    (receipt : BoundAuthorityReceipt)
    (subject : AuthorizationSubject) : Prop :=
  separationOfDuties actors ∧
    receipt.subject = subject ∧
    receipt.principal = actors.approver ∧
    receipt.capability = .approve ∧
    authorityEvidenceClosed authorityValid grant receipt

theorem humanPromotionClosureRejectsSelfApproval
    (authorityValid : AuthorityReceiptValid)
    (grant : AuthorityGrant)
    (receipt : BoundAuthorityReceipt)
    (subject : AuthorizationSubject) :
    ¬ humanPromotionEvidenceClosed
      selfApprovedActors
      authorityValid
      grant
      receipt
      subject := by
  intro closed
  exact closed.1.1 rfl

theorem humanPromotionClosureProvidesBoundAuthority
    (actors : PromotionActors)
    (authorityValid : AuthorityReceiptValid)
    (grant : AuthorityGrant)
    (receipt : BoundAuthorityReceipt)
    (subject : AuthorizationSubject)
    (closed :
      humanPromotionEvidenceClosed
        actors
        authorityValid
        grant
        receipt
        subject) :
    receipt.subject = subject ∧
      authorityEvidenceClosed authorityValid grant receipt :=
  ⟨closed.2.1, closed.2.2.2.2⟩

end AgenticAILabProof.Enterprise.HumanAuthorityAccountability
