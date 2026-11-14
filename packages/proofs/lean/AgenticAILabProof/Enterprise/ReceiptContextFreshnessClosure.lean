-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.ReceiptAuthorityBindingClosure

namespace AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure

/--
The runtime-owned context in which an authority validates a receipt.

The source identity, declaration bundle, roots, and provided interface are
already bound by the receipt evidence model.  These fields close the remaining
enterprise state boundary: which authority generation, policy snapshot,
authorization snapshot, and revocation snapshot made that evidence acceptable.
-/
structure ReceiptValidationContext where
  authorityIdentity : Nat
  authorityGeneration : Nat
  policySnapshotIdentity : Nat
  authorizationSnapshotIdentity : Nat
  revocationSnapshotIdentity : Nat
  deriving DecidableEq

/--
An authority-issued receipt is meaningful only together with the exact
validation context owned by that authority.
-/
structure ContextBoundAuthorityReceipt where
  issuedContext : ReceiptValidationContext
  ownerAccepted : Bool

def acceptedAtContext
    (currentContext : ReceiptValidationContext)
    (receipt : ContextBoundAuthorityReceipt) : Prop :=
  receipt.ownerAccepted = true ∧ receipt.issuedContext = currentContext

def contextFreeAcceptance (receipt : ContextBoundAuthorityReceipt) : Prop :=
  receipt.ownerAccepted = true

theorem authorityIssuedReceiptIsValidAtExactContext
    {currentContext : ReceiptValidationContext}
    {receipt : ContextBoundAuthorityReceipt}
    (ownerAccepted : receipt.ownerAccepted = true)
    (exactContext : receipt.issuedContext = currentContext) :
    acceptedAtContext currentContext receipt :=
  ⟨ownerAccepted, exactContext⟩

theorem exactContextAcceptanceRejectsChangedContext
    {issuedContext currentContext : ReceiptValidationContext}
    {receipt : ContextBoundAuthorityReceipt}
    (acceptedWhenIssued : acceptedAtContext issuedContext receipt)
    (contextChanged : issuedContext ≠ currentContext) :
    ¬ acceptedAtContext currentContext receipt := by
  intro acceptedNow
  apply contextChanged
  exact acceptedWhenIssued.2.symm.trans acceptedNow.2

/--
Countermodel: an authority really accepted a receipt, but a context-free
predicate accepts it again after the authority generation changed.
-/
theorem contextFreeAcceptancePermitsStaleReplay :
    ∃
      (issuedContext currentContext : ReceiptValidationContext)
      (receipt : ContextBoundAuthorityReceipt),
      issuedContext ≠ currentContext ∧
        acceptedAtContext issuedContext receipt ∧
        contextFreeAcceptance receipt ∧
        ¬ acceptedAtContext currentContext receipt := by
  let issuedContext : ReceiptValidationContext :=
    {
      authorityIdentity := 11
      authorityGeneration := 3
      policySnapshotIdentity := 17
      authorizationSnapshotIdentity := 23
      revocationSnapshotIdentity := 29
    }
  let currentContext : ReceiptValidationContext :=
    {
      authorityIdentity := 11
      authorityGeneration := 4
      policySnapshotIdentity := 17
      authorizationSnapshotIdentity := 23
      revocationSnapshotIdentity := 29
    }
  let receipt : ContextBoundAuthorityReceipt :=
    {
      issuedContext := issuedContext
      ownerAccepted := true
    }
  have contextChanged : issuedContext ≠ currentContext := by
    decide
  have acceptedWhenIssued : acceptedAtContext issuedContext receipt := by
    exact ⟨rfl, rfl⟩
  refine
    ⟨issuedContext, currentContext, receipt, contextChanged,
      acceptedWhenIssued, rfl, ?_⟩
  exact
    exactContextAcceptanceRejectsChangedContext
      acceptedWhenIssued
      contextChanged

structure PolicyOnlyContextProjection where
  authorityIdentity : Nat
  authorityGeneration : Nat
  policySnapshotIdentity : Nat
  deriving DecidableEq

def projectPolicyOnly
    (context : ReceiptValidationContext) : PolicyOnlyContextProjection :=
  {
    authorityIdentity := context.authorityIdentity
    authorityGeneration := context.authorityGeneration
    policySnapshotIdentity := context.policySnapshotIdentity
  }

/--
Countermodel: binding the authority and policy snapshot still misses an
authorization or revocation change.  Therefore policy identity alone is not a
complete enterprise validation context.
-/
theorem policyOnlyProjectionMissesAuthorizationRevocationChange :
    ∃
      (left right : ReceiptValidationContext),
      left ≠ right ∧ projectPolicyOnly left = projectPolicyOnly right := by
  let left : ReceiptValidationContext :=
    {
      authorityIdentity := 31
      authorityGeneration := 7
      policySnapshotIdentity := 37
      authorizationSnapshotIdentity := 41
      revocationSnapshotIdentity := 43
    }
  let right : ReceiptValidationContext :=
    {
      authorityIdentity := 31
      authorityGeneration := 7
      policySnapshotIdentity := 37
      authorizationSnapshotIdentity := 47
      revocationSnapshotIdentity := 53
    }
  have contextsDiffer : left ≠ right := by
    decide
  refine ⟨left, right, contextsDiffer, ?_⟩
  rfl

def everyReceiptAcceptedAtContext
    (currentContext : ReceiptValidationContext)
    (receipts : List ContextBoundAuthorityReceipt) : Prop :=
  ∀ receipt, receipt ∈ receipts → acceptedAtContext currentContext receipt

/--
Receipt-DAG admission is deliberately stronger than a pointwise universal
predicate.  A graph must contain at least one receipt, and every receipt must
be accepted at the exact current authority context.
-/
def receiptDagAdmitted
    (currentContext : ReceiptValidationContext)
    (receipts : List ContextBoundAuthorityReceipt) : Prop :=
  receipts ≠ [] ∧ everyReceiptAcceptedAtContext currentContext receipts

theorem exactContextEvidenceClosesReceiptDagAdmission
    {currentContext : ReceiptValidationContext}
    {receipts : List ContextBoundAuthorityReceipt}
    (nonemptyGraph : receipts ≠ [])
    (ownerAccepted :
      ∀ receipt, receipt ∈ receipts → receipt.ownerAccepted = true)
    (exactContext :
      ∀ receipt, receipt ∈ receipts →
        receipt.issuedContext = currentContext) :
    receiptDagAdmitted currentContext receipts := by
  refine ⟨nonemptyGraph, ?_⟩
  intro receipt receiptMember
  exact
    authorityIssuedReceiptIsValidAtExactContext
      (ownerAccepted receipt receiptMember)
      (exactContext receipt receiptMember)

theorem oneStaleReceiptRejectsReceiptDagAdmission
    {issuedContext currentContext : ReceiptValidationContext}
    {receipt : ContextBoundAuthorityReceipt}
    {receipts : List ContextBoundAuthorityReceipt}
    (receiptMember : receipt ∈ receipts)
    (acceptedWhenIssued : acceptedAtContext issuedContext receipt)
    (contextChanged : issuedContext ≠ currentContext) :
    ¬ receiptDagAdmitted currentContext receipts := by
  intro graphAdmitted
  exact
    exactContextAcceptanceRejectsChangedContext
      acceptedWhenIssued
      contextChanged
      (graphAdmitted.2 receipt receiptMember)

/--
Countermodel: a pointwise-only admission predicate accepts the empty graph
vacuously.  The nonempty condition in `receiptDagAdmitted` is therefore a
semantic requirement, not an implementation convenience.
-/
theorem pointwiseOnlyAdmissionAcceptsEmptyDag
    (currentContext : ReceiptValidationContext) :
    everyReceiptAcceptedAtContext currentContext [] := by
  simp [everyReceiptAcceptedAtContext]

theorem emptyReceiptDagIsRejected
    (currentContext : ReceiptValidationContext) :
    ¬ receiptDagAdmitted currentContext [] := by
  intro graphAdmitted
  exact graphAdmitted.1 rfl

/--
Every admitted receipt belongs to the one authority identity that owns the
current graph-validation context.  A receipt DAG therefore cannot silently
union independent authority paths.
-/
theorem receiptDagAdmissionEnforcesAuthorityIdentity
    {currentContext : ReceiptValidationContext}
    {receipts : List ContextBoundAuthorityReceipt}
    (graphAdmitted : receiptDagAdmitted currentContext receipts) :
    ∀ receipt, receipt ∈ receipts →
      receipt.issuedContext.authorityIdentity =
        currentContext.authorityIdentity := by
  intro receipt receiptMember
  exact
    congrArg
      ReceiptValidationContext.authorityIdentity
      (graphAdmitted.2 receipt receiptMember).2

theorem receiptsAcceptedAtOneContextShareAuthorityIdentity
    {currentContext : ReceiptValidationContext}
    {left right : ContextBoundAuthorityReceipt}
    (leftAccepted : acceptedAtContext currentContext left)
    (rightAccepted : acceptedAtContext currentContext right) :
    left.issuedContext.authorityIdentity =
      right.issuedContext.authorityIdentity := by
  exact
    congrArg
      ReceiptValidationContext.authorityIdentity
      (leftAccepted.2.trans rightAccepted.2.symm)

end AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure
