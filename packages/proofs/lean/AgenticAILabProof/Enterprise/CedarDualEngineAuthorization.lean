-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Cedar.Spec
import AgenticAILabProof.Enterprise.BundleEvidenceBinding

namespace AgenticAILabProof.Enterprise.CedarDualEngineAuthorization

open BundleEvidenceBinding

abbrev SubjectDigest := String
abbrev PolicySetDigest := String
abbrev EntityStoreDigest := String
abbrev EngineId := String
abbrev ReceiptId := String

def cedarSpecDecision
    (request : Cedar.Spec.Request)
    (entities : Cedar.Spec.Entities)
    (policies : Cedar.Spec.Policies) : Cedar.Spec.Decision :=
  (Cedar.Spec.isAuthorized request entities policies).decision

structure AuthorizationSubject where
  requestDigest : SubjectDigest
  policySetDigest : PolicySetDigest
  entityStoreDigest : EntityStoreDigest
  bundleDigest : BundleDigest
  profileIdentities : List String
  governanceAssessmentDigest : SubjectDigest
  subjectSnapshotDigest : SubjectDigest
  epoch : Nat
  deriving DecidableEq, Repr

structure DecisionReceipt where
  engineId : EngineId
  receiptId : ReceiptId
  subject : AuthorizationSubject
  decision : Cedar.Spec.Decision
  deriving DecidableEq, Repr

def currentBundleEpochJoin
    (left right : DecisionReceipt) : Prop :=
  left.subject.bundleDigest = right.subject.bundleDigest ∧
    left.subject.epoch = right.subject.epoch ∧
    left.decision = right.decision

def subjectA : AuthorizationSubject where
  requestDigest := "sha256:request-a"
  policySetDigest := "sha256:policies-a"
  entityStoreDigest := "sha256:entities-a"
  bundleDigest := "sha256:bundle"
  profileIdentities := ["healthcare/base", "healthcare/medication-safety"]
  governanceAssessmentDigest := "sha256:governance-a"
  subjectSnapshotDigest := "sha256:subject-a"
  epoch := 7

def subjectB : AuthorizationSubject where
  requestDigest := "sha256:request-b"
  policySetDigest := "sha256:policies-b"
  entityStoreDigest := "sha256:entities-b"
  bundleDigest := "sha256:bundle"
  profileIdentities := ["healthcare/base", "healthcare/medication-safety"]
  governanceAssessmentDigest := "sha256:governance-b"
  subjectSnapshotDigest := "sha256:subject-b"
  epoch := 7

def cedarReceiptA : DecisionReceipt where
  engineId := "cedar"
  receiptId := "cedar-a"
  subject := subjectA
  decision := .allow

def leanReceiptB : DecisionReceipt where
  engineId := "lean"
  receiptId := "lean-b"
  subject := subjectB
  decision := .allow

theorem authorizationSubjectsAreDistinct : subjectA ≠ subjectB := by
  decide

theorem sameDecisionDifferentSubjectPassesBundleEpochJoin :
    currentBundleEpochJoin cedarReceiptA leanReceiptB := by
  simp [
    currentBundleEpochJoin,
    cedarReceiptA,
    leanReceiptB,
    subjectA,
    subjectB
  ]

theorem currentJoinAcceptsSameEngineReceiptReplay :
    currentBundleEpochJoin cedarReceiptA cedarReceiptA := by
  simp [currentBundleEpochJoin]

def DecisionSemantics :=
  AuthorizationSubject → Cedar.Spec.Decision

def denySemantics : DecisionSemantics :=
  fun _subject => .deny

def leanReceiptA : DecisionReceipt where
  engineId := "lean"
  receiptId := "lean-a"
  subject := subjectA
  decision := .allow

def decisionCorrect
    (semantics : DecisionSemantics)
    (receipt : DecisionReceipt) : Prop :=
  receipt.decision = semantics receipt.subject

theorem dualAgreementDoesNotImplySemanticCorrectness :
    currentBundleEpochJoin cedarReceiptA leanReceiptA ∧
      ¬ decisionCorrect denySemantics cedarReceiptA ∧
      ¬ decisionCorrect denySemantics leanReceiptA := by
  simp [
    currentBundleEpochJoin,
    cedarReceiptA,
    leanReceiptA,
    subjectA,
    decisionCorrect,
    denySemantics
  ]

def DecisionReceiptValid :=
  DecisionReceipt → Prop

def dualDecisionEvidenceClosed
    (semantics : DecisionSemantics)
    (valid : DecisionReceiptValid)
    (left right : DecisionReceipt) : Prop :=
  left.subject = right.subject ∧
    left.engineId ≠ right.engineId ∧
    left.receiptId ≠ right.receiptId ∧
    valid left ∧
    valid right ∧
    left.decision = right.decision ∧
    decisionCorrect semantics left ∧
    decisionCorrect semantics right

theorem closedDualDecisionRejectsDifferentSubjects
    (semantics : DecisionSemantics)
    (valid : DecisionReceiptValid) :
    ¬ dualDecisionEvidenceClosed
      semantics
      valid
      cedarReceiptA
      leanReceiptB := by
  intro closed
  exact authorizationSubjectsAreDistinct closed.1

theorem closedDualDecisionRejectsSameEngineReplay
    (semantics : DecisionSemantics)
    (valid : DecisionReceiptValid) :
    ¬ dualDecisionEvidenceClosed
      semantics
      valid
      cedarReceiptA
      cedarReceiptA := by
  intro closed
  exact closed.2.1 rfl

theorem closedDualDecisionProvidesSubjectEquality
    (semantics : DecisionSemantics)
    (valid : DecisionReceiptValid)
    (left right : DecisionReceipt)
    (closed : dualDecisionEvidenceClosed semantics valid left right) :
    left.subject = right.subject :=
  closed.1

theorem closedDualDecisionProvidesDistinctEngines
    (semantics : DecisionSemantics)
    (valid : DecisionReceiptValid)
    (left right : DecisionReceipt)
    (closed : dualDecisionEvidenceClosed semantics valid left right) :
    left.engineId ≠ right.engineId :=
  closed.2.1

theorem closedDualDecisionProvidesGovernanceAssessmentIdentity
    (semantics : DecisionSemantics)
    (valid : DecisionReceiptValid)
    (left right : DecisionReceipt)
    (closed : dualDecisionEvidenceClosed semantics valid left right) :
    left.subject.governanceAssessmentDigest =
      right.subject.governanceAssessmentDigest := by
  exact congrArg AuthorizationSubject.governanceAssessmentDigest closed.1

theorem closedDualDecisionProvidesSubjectSnapshotIdentity
    (semantics : DecisionSemantics)
    (valid : DecisionReceiptValid)
    (left right : DecisionReceipt)
    (closed : dualDecisionEvidenceClosed semantics valid left right) :
    left.subject.subjectSnapshotDigest = right.subject.subjectSnapshotDigest := by
  exact congrArg AuthorizationSubject.subjectSnapshotDigest closed.1

theorem closedDualDecisionProvidesSemanticCorrectness
    (semantics : DecisionSemantics)
    (valid : DecisionReceiptValid)
    (left right : DecisionReceipt)
    (closed : dualDecisionEvidenceClosed semantics valid left right) :
    decisionCorrect semantics left ∧ decisionCorrect semantics right :=
  closed.2.2.2.2.2.2

end AgenticAILabProof.Enterprise.CedarDualEngineAuthorization
