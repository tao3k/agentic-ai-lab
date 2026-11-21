-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeCore
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationResponsibilityHandoffBindingClosure

/-!
The Cedar subject bridge and the enterprise responsibility-handoff closure are
locally sound but own different projections.  RFC45-120-48 needs an explicit
cross-plane binding from the exact Cedar authorization subject and decision
evidence to the responsibility transfer asset and authority evidence, while
retaining successor acceptance as independent evidence.
-/

abbrev AuthorizationSubjectIdentity := Nat
abbrev AuthorizationDecisionEvidenceIdentity := Nat
abbrev AcceptanceEvidenceIdentity := Nat
abbrev OwnerAuditCommitmentIdentity := Nat

structure CedarAuthorizationProjection where
  subject : AuthorizationSubjectIdentity
  decisionEvidenceIdentity : AuthorizationDecisionEvidenceIdentity
  ownerAuditCommitmentIdentity : OwnerAuditCommitmentIdentity
  lifecycleClosed : Prop

def CedarAuthorizationLocallyClosed
    (projection : CedarAuthorizationProjection) : Prop :=
  projection.lifecycleClosed

structure ResponsibilityHandoffProjection where
  asset : AuthorizationSubjectIdentity
  beforeSubject : AuthorizationSubjectIdentity
  afterSubject : AuthorizationSubjectIdentity
  authorityEvidenceIdentity : AuthorizationDecisionEvidenceIdentity
  acceptanceEvidenceIdentity : AcceptanceEvidenceIdentity
  ownerAuditCommitmentIdentity : OwnerAuditCommitmentIdentity
  transferAdmitted : Prop
  successorAccepted : Prop
  registryPublicationClosed : Prop

def ResponsibilityHandoffLocallyClosed
    (projection : ResponsibilityHandoffProjection) : Prop :=
  projection.transferAdmitted ∧
    projection.asset = projection.beforeSubject ∧
    projection.asset = projection.afterSubject ∧
    projection.successorAccepted ∧
    projection.registryPublicationClosed

structure CedarAuthorizationResponsibilityHandoffBindingClosure where
  cedar : CedarAuthorizationProjection
  handoff : ResponsibilityHandoffProjection
  cedarClosed : CedarAuthorizationLocallyClosed cedar
  handoffClosed : ResponsibilityHandoffLocallyClosed handoff
  exactOwnerAuditCommitment :
    cedar.ownerAuditCommitmentIdentity =
      handoff.ownerAuditCommitmentIdentity
  exactAuthorizationSubjectAsset : cedar.subject = handoff.asset
  exactAuthorityEvidence :
    cedar.decisionEvidenceIdentity = handoff.authorityEvidenceIdentity

theorem closedAuthorizationSubjectIsTransferAsset
    (closure : CedarAuthorizationResponsibilityHandoffBindingClosure) :
    closure.cedar.subject = closure.handoff.asset :=
  closure.exactAuthorizationSubjectAsset

theorem closedAuthorizationSubjectIsContinuousAcrossHandoff
    (closure : CedarAuthorizationResponsibilityHandoffBindingClosure) :
    closure.cedar.subject = closure.handoff.beforeSubject ∧
      closure.cedar.subject = closure.handoff.afterSubject := by
  constructor
  · exact closure.exactAuthorizationSubjectAsset.trans closure.handoffClosed.2.1
  · exact closure.exactAuthorizationSubjectAsset.trans closure.handoffClosed.2.2.1

theorem closedCedarDecisionIsTransferAuthorityEvidence
    (closure : CedarAuthorizationResponsibilityHandoffBindingClosure) :
    closure.cedar.decisionEvidenceIdentity =
      closure.handoff.authorityEvidenceIdentity :=
  closure.exactAuthorityEvidence

theorem closedHandoffRetainsIndependentSuccessorAcceptance
    (closure : CedarAuthorizationResponsibilityHandoffBindingClosure) :
    closure.handoff.successorAccepted :=
  closure.handoffClosed.2.2.2.1

theorem closedBridgeRetainsRegistryPublicationClosure
    (closure : CedarAuthorizationResponsibilityHandoffBindingClosure) :
    closure.handoff.registryPublicationClosed :=
  closure.handoffClosed.2.2.2.2

theorem closedBridgeUsesOneOwnerAuditCommitment
    (closure : CedarAuthorizationResponsibilityHandoffBindingClosure) :
    closure.cedar.ownerAuditCommitmentIdentity =
      closure.handoff.ownerAuditCommitmentIdentity :=
  closure.exactOwnerAuditCommitment

def locallyClosedCedarA : CedarAuthorizationProjection :=
  {
    subject := 1
    decisionEvidenceIdentity := 101
    ownerAuditCommitmentIdentity := 9
    lifecycleClosed := True
  }

def locallyClosedHandoffB : ResponsibilityHandoffProjection :=
  {
    asset := 2
    beforeSubject := 2
    afterSubject := 2
    authorityEvidenceIdentity := 202
    acceptanceEvidenceIdentity := 303
    ownerAuditCommitmentIdentity := 9
    transferAdmitted := True
    successorAccepted := True
    registryPublicationClosed := True
  }

theorem localClosuresAndSharedCommitmentPermitSubjectReplacement :
    CedarAuthorizationLocallyClosed locallyClosedCedarA ∧
      ResponsibilityHandoffLocallyClosed locallyClosedHandoffB ∧
      locallyClosedCedarA.ownerAuditCommitmentIdentity =
        locallyClosedHandoffB.ownerAuditCommitmentIdentity ∧
      locallyClosedCedarA.subject ≠ locallyClosedHandoffB.asset ∧
      locallyClosedCedarA.decisionEvidenceIdentity ≠
        locallyClosedHandoffB.authorityEvidenceIdentity := by
  constructor
  · trivial
  · constructor
    · exact ⟨trivial, rfl, rfl, trivial, trivial⟩
    · constructor
      · rfl
      · constructor
        · intro subjectReplaced
          cases subjectReplaced
        · intro evidenceReplaced
          cases evidenceReplaced

def closedCedarAuthorizationResponsibilityHandoff :
    CedarAuthorizationResponsibilityHandoffBindingClosure :=
  {
    cedar := {
      subject := 1
      decisionEvidenceIdentity := 101
      ownerAuditCommitmentIdentity := 9
      lifecycleClosed := True
    }
    handoff := {
      asset := 1
      beforeSubject := 1
      afterSubject := 1
      authorityEvidenceIdentity := 101
      acceptanceEvidenceIdentity := 303
      ownerAuditCommitmentIdentity := 9
      transferAdmitted := True
      successorAccepted := True
      registryPublicationClosed := True
    }
    cedarClosed := trivial
    handoffClosed := ⟨trivial, rfl, rfl, trivial, trivial⟩
    exactOwnerAuditCommitment := rfl
    exactAuthorizationSubjectAsset := rfl
    exactAuthorityEvidence := rfl
  }

theorem concreteAuthorizationResponsibilityHandoffIsClosed :
    closedCedarAuthorizationResponsibilityHandoff.cedar.subject = 1 ∧
      closedCedarAuthorizationResponsibilityHandoff.handoff.asset = 1 ∧
      closedCedarAuthorizationResponsibilityHandoff.handoff.successorAccepted := by
  exact ⟨rfl, rfl, trivial⟩

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationResponsibilityHandoffBindingClosure
