-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeModel

/-!
# Independent Cedar authorization-subject bridge model

The model proves that full response equality does not identify the evaluated
subject, and that two receipt fields do not establish two independent engines.
One canonical bridge therefore binds the exact subject and retains
owner-supplied snapshot and receipt validity relations.
-/

inductive Decision where
  | allow
  | deny
  deriving DecidableEq, Repr

structure Response where
  decision : Decision
  determiningPolicies : List Nat
  erroringPolicies : List Nat
  deriving DecidableEq, Repr

structure AuthorizationSubject where
  requestDigest : Nat
  policySetDigest : Nat
  entityStoreDigest : Nat
  bundleDigest : Nat
  epoch : Nat
  deriving DecidableEq, Repr

structure SnapshotDigestProjection where
  requestDigest : Nat
  policySetDigest : Nat
  entityStoreDigest : Nat
  deriving DecidableEq, Repr

structure EngineReceipt where
  engineIdentity : Nat
  receiptIdentity : Nat
  subject : AuthorizationSubject
  decision : Decision
  deriving DecidableEq, Repr

def SnapshotBindingValid :=
  SnapshotDigestProjection → AuthorizationSubject → Prop

def EngineReceiptValid :=
  EngineReceipt → Prop

def DualDecisionEvidenceIdentityValid :=
  Nat → EngineReceipt → EngineReceipt → Prop

def DecisionSemantics :=
  AuthorizationSubject → Decision

def snapshotFieldsMatch
    (snapshot : SnapshotDigestProjection)
    (subject : AuthorizationSubject) : Prop :=
  snapshot.requestDigest = subject.requestDigest ∧
  snapshot.policySetDigest = subject.policySetDigest ∧
  snapshot.entityStoreDigest = subject.entityStoreDigest

def subjectBindingClosed
    (bindingValid : SnapshotBindingValid)
    (snapshot : SnapshotDigestProjection)
    (subject : AuthorizationSubject) : Prop :=
  snapshotFieldsMatch snapshot subject ∧
  bindingValid snapshot subject

def dualReceiptEvidenceClosed
    (semantics : DecisionSemantics)
    (receiptValid : EngineReceiptValid)
    (subject : AuthorizationSubject)
    (left right : EngineReceipt) : Prop :=
  left.subject = subject ∧
  right.subject = subject ∧
  left.engineIdentity ≠ right.engineIdentity ∧
  left.receiptIdentity ≠ right.receiptIdentity ∧
  receiptValid left ∧
  receiptValid right ∧
  left.decision = right.decision ∧
  left.decision = semantics subject ∧
  right.decision = semantics subject

def authorizationSubjectBridgeClosed
    (bindingValid : SnapshotBindingValid)
    (semantics : DecisionSemantics)
    (receiptValid : EngineReceiptValid)
    (dualDecisionIdentityValid :
      DualDecisionEvidenceIdentityValid)
    (decisionEvidenceIdentity : Nat)
    (snapshot : SnapshotDigestProjection)
    (subject : AuthorizationSubject)
    (left right : EngineReceipt)
    (response : Response)
    (expectedBundle runtimeEpoch : Nat) : Prop :=
  subjectBindingClosed bindingValid snapshot subject ∧
  subject.bundleDigest = expectedBundle ∧
  subject.epoch = runtimeEpoch ∧
  dualReceiptEvidenceClosed semantics receiptValid subject left right ∧
  dualDecisionIdentityValid decisionEvidenceIdentity left right ∧
  response.decision = left.decision

def subjectA : AuthorizationSubject where
  requestDigest := 11
  policySetDigest := 21
  entityStoreDigest := 31
  bundleDigest := 41
  epoch := 7

def subjectB : AuthorizationSubject where
  requestDigest := 12
  policySetDigest := 22
  entityStoreDigest := 32
  bundleDigest := 41
  epoch := 7

def allowResponse : Response where
  decision := .allow
  determiningPolicies := [1]
  erroringPolicies := []

theorem fullResponseEqualityDoesNotIdentifyAuthorizationSubject :
    allowResponse = allowResponse ∧ subjectA ≠ subjectB := by
  decide

def snapshotA : SnapshotDigestProjection where
  requestDigest := 11
  policySetDigest := 21
  entityStoreDigest := 31

theorem copiedSnapshotFieldsDoNotProveBindingAuthority :
    snapshotFieldsMatch snapshotA subjectA ∧
    ¬ subjectBindingClosed
      (fun _snapshot _subject => False)
      snapshotA
      subjectA := by
  constructor
  · simp [snapshotFieldsMatch, snapshotA, subjectA]
  · intro closed
    exact closed.2

def receiptA : EngineReceipt where
  engineIdentity := 1
  receiptIdentity := 101
  subject := subjectA
  decision := .allow

def weakDualReceiptAgreement
    (left right : EngineReceipt) : Prop :=
  left.subject = right.subject ∧
  left.decision = right.decision

theorem sameEngineReceiptReplayPassesWeakAgreement :
    weakDualReceiptAgreement receiptA receiptA := by
  simp [weakDualReceiptAgreement]

theorem nonemptyDecisionIdentityDoesNotBindDualReceipts :
    (101 : Nat) ≠ 0 ∧
    ¬ (fun _identity _left _right => False)
      101 receiptA receiptA := by
  simp

theorem canonicalBridgeRejectsSameEngineReceiptReplay
    (bindingValid : SnapshotBindingValid)
    (semantics : DecisionSemantics)
    (receiptValid : EngineReceiptValid)
    (dualDecisionIdentityValid :
      DualDecisionEvidenceIdentityValid)
    (decisionEvidenceIdentity : Nat)
    (snapshot : SnapshotDigestProjection)
    (subject : AuthorizationSubject)
    (receipt : EngineReceipt)
    (response : Response)
    (expectedBundle runtimeEpoch : Nat) :
    ¬ authorizationSubjectBridgeClosed
      bindingValid
      semantics
      receiptValid
      dualDecisionIdentityValid
      decisionEvidenceIdentity
      snapshot
      subject
      receipt
      receipt
      response
      expectedBundle
      runtimeEpoch := by
  intro closed
  exact closed.2.2.2.1.2.2.1 rfl

theorem canonicalBridgeProvidesExactSubjectAndDistinctEngines
    {bindingValid : SnapshotBindingValid}
    {semantics : DecisionSemantics}
    {receiptValid : EngineReceiptValid}
    {dualDecisionIdentityValid :
      DualDecisionEvidenceIdentityValid}
    {decisionEvidenceIdentity : Nat}
    {snapshot : SnapshotDigestProjection}
    {subject : AuthorizationSubject}
    {left right : EngineReceipt}
    {response : Response}
    {expectedBundle runtimeEpoch : Nat}
    (closed :
      authorizationSubjectBridgeClosed
        bindingValid
        semantics
        receiptValid
        dualDecisionIdentityValid
        decisionEvidenceIdentity
        snapshot
        subject
        left
        right
        response
        expectedBundle
        runtimeEpoch) :
    left.subject = subject ∧
    right.subject = subject ∧
    left.engineIdentity ≠ right.engineIdentity :=
  ⟨closed.2.2.2.1.1,
    closed.2.2.2.1.2.1,
    closed.2.2.2.1.2.2.1⟩

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeModel
