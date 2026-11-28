-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.CedarDualEngineAuthorization
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeCore

open CedarDualEngineAuthorization
open SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleCore

/-!
# Exact authorization-subject and distinct-engine bridge

The Cedar lifecycle response is not itself a digest commitment to the evaluated
request, policy set, entity store, Bundle, and epoch.  This bridge reuses the
existing `AuthorizationSubject` and dual-receipt closure rather than defining a
second subject model.
-/

def SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid :=
  SourceBoundEffectCompletionRecoveryCedarPolicySnapshot →
    AuthorizationSubject →
    Prop

def SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid :=
  String → DecisionReceipt → DecisionReceipt → Prop

structure SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBound
    (snapshotSubjectBindingValid :
      SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid)
    (semantics : DecisionSemantics)
    (decisionReceiptValid : DecisionReceiptValid)
    (dualDecisionIdentityValid :
      SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid)
    (lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence)
    (subject : AuthorizationSubject)
    (left right : DecisionReceipt)
    (expectedBundle : BundleEvidenceBinding.BundleDigest) : Prop where
  snapshotBindsSubject :
    snapshotSubjectBindingValid lifecycle.snapshot subject
  bundleMatches :
    subject.bundleDigest = expectedBundle
  epochMatches :
    subject.epoch = lifecycle.runtimeEpoch
  dualDecisionCloses :
    dualDecisionEvidenceClosed
      semantics decisionReceiptValid left right
  decisionIdentityBindsReceipts :
    dualDecisionIdentityValid
      lifecycle.decisionIdentity left right
  leftSubjectMatches :
    left.subject = subject
  lifecycleDecisionMatches :
    lifecycle.productionResponse.decision = left.decision
  referenceSemanticsMatches :
    semantics subject =
      (Cedar.Spec.isAuthorized
        lifecycle.snapshot.request
        lifecycle.snapshot.entities
        lifecycle.snapshot.policies).decision

structure SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridge
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
    (lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence)
    (subject : AuthorizationSubject)
    (left right : DecisionReceipt) : Prop where
  lifecycleAdmitted :
    lifecycle.Admitted
      authorityPathAuthorized
      separationOfDutySatisfied
      expectedAuthority
      expectedCommitment
  subjectBound :
    SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBound
      snapshotSubjectBindingValid
      semantics
      decisionReceiptValid
      dualDecisionIdentityValid
      lifecycle
      subject
      left
      right
      expectedBundle

theorem closedSubjectBridgeProvidesExactSubject
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
    {lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {subject : AuthorizationSubject}
    {left right : DecisionReceipt}
    (closed :
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
        right) :
    left.subject = subject ∧ right.subject = subject := by
  refine ⟨closed.subjectBound.leftSubjectMatches, ?_⟩
  exact
    closed.subjectBound.dualDecisionCloses.1.symm.trans
      closed.subjectBound.leftSubjectMatches

theorem closedSubjectBridgeProvidesDistinctEngines
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
    {lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {subject : AuthorizationSubject}
    {left right : DecisionReceipt}
    (closed :
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
        right) :
    left.engineId ≠ right.engineId ∧
    left.receiptId ≠ right.receiptId :=
  ⟨closed.subjectBound.dualDecisionCloses.2.1,
    closed.subjectBound.dualDecisionCloses.2.2.1⟩

theorem closedSubjectBridgeProvidesCurrentBundleAndEpoch
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
    {lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {subject : AuthorizationSubject}
    {left right : DecisionReceipt}
    (closed :
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
        right) :
    subject.bundleDigest = expectedBundle ∧
    subject.epoch = lifecycle.runtimeEpoch :=
  ⟨closed.subjectBound.bundleMatches,
    closed.subjectBound.epochMatches⟩

theorem invalidSnapshotSubjectBindingRejectsBridge
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
    {lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {subject : AuthorizationSubject}
    {left right : DecisionReceipt}
    (invalid :
      ¬ snapshotSubjectBindingValid lifecycle.snapshot subject) :
    ¬ SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridge
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
        right := by
  intro closed
  exact invalid closed.subjectBound.snapshotBindsSubject

theorem sameEngineReceiptReplayRejectsBridge
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
    {lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {subject : AuthorizationSubject}
    {receipt : DecisionReceipt} :
    ¬ SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridge
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
        receipt
        receipt := by
  intro closed
  exact closed.subjectBound.dualDecisionCloses.2.1 rfl

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeCore
