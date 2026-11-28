-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffClosure
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityClosure

open
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityBindingCore
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityBindingClosure
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffCore
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffClosure
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityCore

abbrev GlobalHandoffKey := String × Nat

def SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffPosition
    (trace : RecoveryTrace)
    (envelopes : Nat → CommitmentEnvelope)
    (assignmentRegistry :
      String →
        SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityAssignment)
    (index : Nat) :
    Prop :=
  trace index ≠
      AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure.SourceBoundEffectCompletionCrashRecoveryState.committed ∧
    trace (index + 1) ≠
        AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure.SourceBoundEffectCompletionCrashRecoveryState.committed ∧
      (assignmentRegistry
          (envelopes index).commitment).accountablePrincipal ≠
        (assignmentRegistry
          (envelopes (index + 1)).commitment).accountablePrincipal

structure SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityEvidence
    (trace : RecoveryTrace)
    (budgets : Nat → ProgressBudget)
    (scopes : Nat → ProgressScope)
    (providerAcknowledgementStable : Nat → Prop)
    (expectations : Nat → RecoveryExpectation)
    (witnesses : Nat → OwnerAuditWitness)
    (scheme : CommitmentScheme)
    (signatureVerified : String → String → String → Prop)
    (authorizationRegistry : String → CedarAuthorizationEvidence)
    (authorityPathAuthorized : String → String → String → String → Prop)
    (separationOfDutySatisfied : String → String → String → Prop)
    (envelopes : Nat → CommitmentEnvelope)
    (authenticityEvidence : Nat → AuthenticityEvidence)
    (snapshotSubjectBindingValid : CedarSnapshotSubjectBindingValid)
    (semantics : DecisionSemantics)
    (decisionReceiptValid : DecisionReceiptValid)
    (dualDecisionIdentityValid : CedarDualDecisionIdentityValid)
    (subjectRegistry : String → AuthorizationSubject)
    (leftReceiptRegistry rightReceiptRegistry :
      String → DecisionReceipt)
    (bundleDigestAt :
      Nat → AgenticAILabProof.Enterprise.BundleEvidenceBinding.BundleDigest)
    (bundleDigestAtValid :
      Nat →
        AgenticAILabProof.Enterprise.BundleEvidenceBinding.BundleDigest →
          Prop)
    (authorityReceiptValid : AuthorityReceiptValid)
    (assignmentValid :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityAssignment →
        Prop)
    (grantRegistry : String → AuthorityGrant)
    (authorityReceiptRegistry : String → BoundAuthorityReceipt)
    (freshnessChecksAt : Nat → EvidenceFreshnessChecks)
    (assignmentRegistry :
      String →
        SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityAssignment)
    (transferContractBinds : String → String → String → Prop)
    (effectiveObservationBinds : String → Nat → Prop)
    (transferAt : Nat → EnterpriseResponsibilityTransfer)
    (globalHandoffAt : GlobalHandoffKey → Prop)
    (globalTransferAt :
      GlobalHandoffKey → EnterpriseResponsibilityTransfer) :
    Prop where
  handoffEvidence :
    SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffEvidence
      trace
      budgets
      scopes
      providerAcknowledgementStable
      expectations
      witnesses
      scheme
      signatureVerified
      authorizationRegistry
      authorityPathAuthorized
      separationOfDutySatisfied
      envelopes
      authenticityEvidence
      snapshotSubjectBindingValid
      semantics
      decisionReceiptValid
      dualDecisionIdentityValid
      subjectRegistry
      leftReceiptRegistry
      rightReceiptRegistry
      bundleDigestAt
      bundleDigestAtValid
      authorityReceiptValid
      assignmentValid
      grantRegistry
      authorityReceiptRegistry
      freshnessChecksAt
      assignmentRegistry
      transferContractBinds
      effectiveObservationBinds
      transferAt
  identityClassification :
    SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityClassification
      globalHandoffAt
      globalTransferAt
  globalPositionBindings :
    ∀ index,
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffPosition
          trace
          envelopes
          assignmentRegistry
          index →
        let key : GlobalHandoffKey :=
          ((witnesses index).recoveryId, index)
        globalHandoffAt key ∧ globalTransferAt key = transferAt index

theorem classifiedHandoffPositionHasAdmittedTransfer
    {trace : RecoveryTrace}
    {budgets : Nat → ProgressBudget}
    {scopes : Nat → ProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → RecoveryExpectation}
    {witnesses : Nat → OwnerAuditWitness}
    {scheme : CommitmentScheme}
    {signatureVerified : String → String → String → Prop}
    {authorizationRegistry : String → CedarAuthorizationEvidence}
    {authorityPathAuthorized : String → String → String → String → Prop}
    {separationOfDutySatisfied : String → String → String → Prop}
    {envelopes : Nat → CommitmentEnvelope}
    {authenticityEvidence : Nat → AuthenticityEvidence}
    {snapshotSubjectBindingValid : CedarSnapshotSubjectBindingValid}
    {semantics : DecisionSemantics}
    {decisionReceiptValid : DecisionReceiptValid}
    {dualDecisionIdentityValid : CedarDualDecisionIdentityValid}
    {subjectRegistry : String → AuthorizationSubject}
    {leftReceiptRegistry rightReceiptRegistry :
      String → DecisionReceipt}
    {bundleDigestAt :
      Nat → AgenticAILabProof.Enterprise.BundleEvidenceBinding.BundleDigest}
    {bundleDigestAtValid :
      Nat →
        AgenticAILabProof.Enterprise.BundleEvidenceBinding.BundleDigest →
          Prop}
    {authorityReceiptValid : AuthorityReceiptValid}
    {assignmentValid :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityAssignment →
        Prop}
    {grantRegistry : String → AuthorityGrant}
    {authorityReceiptRegistry : String → BoundAuthorityReceipt}
    {freshnessChecksAt : Nat → EvidenceFreshnessChecks}
    {assignmentRegistry :
      String →
        SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityAssignment}
    {transferContractBinds : String → String → String → Prop}
    {effectiveObservationBinds : String → Nat → Prop}
    {transferAt : Nat → EnterpriseResponsibilityTransfer}
    {globalHandoffAt : GlobalHandoffKey → Prop}
    {globalTransferAt :
      GlobalHandoffKey → EnterpriseResponsibilityTransfer}
    (evidence :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityEvidence
        trace
        budgets
        scopes
        providerAcknowledgementStable
        expectations
        witnesses
        scheme
        signatureVerified
        authorizationRegistry
        authorityPathAuthorized
        separationOfDutySatisfied
        envelopes
        authenticityEvidence
        snapshotSubjectBindingValid
        semantics
        decisionReceiptValid
        dualDecisionIdentityValid
        subjectRegistry
        leftReceiptRegistry
        rightReceiptRegistry
        bundleDigestAt
        bundleDigestAtValid
        authorityReceiptValid
        assignmentValid
        grantRegistry
        authorityReceiptRegistry
        freshnessChecksAt
        assignmentRegistry
        transferContractBinds
        effectiveObservationBinds
        transferAt
        globalHandoffAt
        globalTransferAt)
    {index : Nat}
    (position :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffPosition
        trace
        envelopes
        assignmentRegistry
        index) :
    SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffBound
      transferContractBinds
      effectiveObservationBinds
      (assignmentRegistry (envelopes index).commitment)
      (assignmentRegistry (envelopes (index + 1)).commitment)
      (transferAt index) :=
  changedTraceResponsibilityRequiresHandoffAt
    evidence.handoffEvidence
    index
    position.left
    position.right.left
    position.right.right

theorem distinctTraceHandoffsHaveDistinctAcceptanceEvidence
    {trace : RecoveryTrace}
    {budgets : Nat → ProgressBudget}
    {scopes : Nat → ProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → RecoveryExpectation}
    {witnesses : Nat → OwnerAuditWitness}
    {scheme : CommitmentScheme}
    {signatureVerified : String → String → String → Prop}
    {authorizationRegistry : String → CedarAuthorizationEvidence}
    {authorityPathAuthorized : String → String → String → String → Prop}
    {separationOfDutySatisfied : String → String → String → Prop}
    {envelopes : Nat → CommitmentEnvelope}
    {authenticityEvidence : Nat → AuthenticityEvidence}
    {snapshotSubjectBindingValid : CedarSnapshotSubjectBindingValid}
    {semantics : DecisionSemantics}
    {decisionReceiptValid : DecisionReceiptValid}
    {dualDecisionIdentityValid : CedarDualDecisionIdentityValid}
    {subjectRegistry : String → AuthorizationSubject}
    {leftReceiptRegistry rightReceiptRegistry :
      String → DecisionReceipt}
    {bundleDigestAt :
      Nat → AgenticAILabProof.Enterprise.BundleEvidenceBinding.BundleDigest}
    {bundleDigestAtValid :
      Nat →
        AgenticAILabProof.Enterprise.BundleEvidenceBinding.BundleDigest →
          Prop}
    {authorityReceiptValid : AuthorityReceiptValid}
    {assignmentValid :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityAssignment →
        Prop}
    {grantRegistry : String → AuthorityGrant}
    {authorityReceiptRegistry : String → BoundAuthorityReceipt}
    {freshnessChecksAt : Nat → EvidenceFreshnessChecks}
    {assignmentRegistry :
      String →
        SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityAssignment}
    {transferContractBinds : String → String → String → Prop}
    {effectiveObservationBinds : String → Nat → Prop}
    {transferAt : Nat → EnterpriseResponsibilityTransfer}
    {globalHandoffAt : GlobalHandoffKey → Prop}
    {globalTransferAt :
      GlobalHandoffKey → EnterpriseResponsibilityTransfer}
    (evidence :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityEvidence
        trace
        budgets
        scopes
        providerAcknowledgementStable
        expectations
        witnesses
        scheme
        signatureVerified
        authorizationRegistry
        authorityPathAuthorized
        separationOfDutySatisfied
        envelopes
        authenticityEvidence
        snapshotSubjectBindingValid
        semantics
        decisionReceiptValid
        dualDecisionIdentityValid
        subjectRegistry
        leftReceiptRegistry
        rightReceiptRegistry
        bundleDigestAt
        bundleDigestAtValid
        authorityReceiptValid
        assignmentValid
        grantRegistry
        authorityReceiptRegistry
        freshnessChecksAt
        assignmentRegistry
        transferContractBinds
        effectiveObservationBinds
        transferAt
        globalHandoffAt
        globalTransferAt)
    {left right : Nat}
    (leftHandoff :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffPosition
        trace
        envelopes
        assignmentRegistry
        left)
    (rightHandoff :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffPosition
        trace
        envelopes
        assignmentRegistry
        right)
    (distinct : left ≠ right) :
    (transferAt left).acceptanceEvidenceIdentity ≠
      (transferAt right).acceptanceEvidenceIdentity := by
  have leftBinding :=
    evidence.globalPositionBindings left leftHandoff
  have rightBinding :=
    evidence.globalPositionBindings right rightHandoff
  have keysDistinct :
      ((witnesses left).recoveryId, left) ≠
        ((witnesses right).recoveryId, right) := by
    intro keysEqual
    exact distinct (congrArg Prod.snd keysEqual)
  have globallyDistinct :=
    distinctHandoffsHaveDistinctAcceptanceEvidence
      evidence.identityClassification
      leftBinding.left
      rightBinding.left
      keysDistinct
  rw [leftBinding.right, rightBinding.right] at globallyDistinct
  exact globallyDistinct

theorem distinctTraceHandoffsHaveDistinctObservationEvidence
    {trace : RecoveryTrace}
    {budgets : Nat → ProgressBudget}
    {scopes : Nat → ProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → RecoveryExpectation}
    {witnesses : Nat → OwnerAuditWitness}
    {scheme : CommitmentScheme}
    {signatureVerified : String → String → String → Prop}
    {authorizationRegistry : String → CedarAuthorizationEvidence}
    {authorityPathAuthorized : String → String → String → String → Prop}
    {separationOfDutySatisfied : String → String → String → Prop}
    {envelopes : Nat → CommitmentEnvelope}
    {authenticityEvidence : Nat → AuthenticityEvidence}
    {snapshotSubjectBindingValid : CedarSnapshotSubjectBindingValid}
    {semantics : DecisionSemantics}
    {decisionReceiptValid : DecisionReceiptValid}
    {dualDecisionIdentityValid : CedarDualDecisionIdentityValid}
    {subjectRegistry : String → AuthorizationSubject}
    {leftReceiptRegistry rightReceiptRegistry :
      String → DecisionReceipt}
    {bundleDigestAt :
      Nat → AgenticAILabProof.Enterprise.BundleEvidenceBinding.BundleDigest}
    {bundleDigestAtValid :
      Nat →
        AgenticAILabProof.Enterprise.BundleEvidenceBinding.BundleDigest →
          Prop}
    {authorityReceiptValid : AuthorityReceiptValid}
    {assignmentValid :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityAssignment →
        Prop}
    {grantRegistry : String → AuthorityGrant}
    {authorityReceiptRegistry : String → BoundAuthorityReceipt}
    {freshnessChecksAt : Nat → EvidenceFreshnessChecks}
    {assignmentRegistry :
      String →
        SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityAssignment}
    {transferContractBinds : String → String → String → Prop}
    {effectiveObservationBinds : String → Nat → Prop}
    {transferAt : Nat → EnterpriseResponsibilityTransfer}
    {globalHandoffAt : GlobalHandoffKey → Prop}
    {globalTransferAt :
      GlobalHandoffKey → EnterpriseResponsibilityTransfer}
    (evidence :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityEvidence
        trace
        budgets
        scopes
        providerAcknowledgementStable
        expectations
        witnesses
        scheme
        signatureVerified
        authorizationRegistry
        authorityPathAuthorized
        separationOfDutySatisfied
        envelopes
        authenticityEvidence
        snapshotSubjectBindingValid
        semantics
        decisionReceiptValid
        dualDecisionIdentityValid
        subjectRegistry
        leftReceiptRegistry
        rightReceiptRegistry
        bundleDigestAt
        bundleDigestAtValid
        authorityReceiptValid
        assignmentValid
        grantRegistry
        authorityReceiptRegistry
        freshnessChecksAt
        assignmentRegistry
        transferContractBinds
        effectiveObservationBinds
        transferAt
        globalHandoffAt
        globalTransferAt)
    {left right : Nat}
    (leftHandoff :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffPosition
        trace
        envelopes
        assignmentRegistry
        left)
    (rightHandoff :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffPosition
        trace
        envelopes
        assignmentRegistry
        right)
    (distinct : left ≠ right) :
    (transferAt left).effectiveObservationIdentity ≠
      (transferAt right).effectiveObservationIdentity := by
  have leftBinding :=
    evidence.globalPositionBindings left leftHandoff
  have rightBinding :=
    evidence.globalPositionBindings right rightHandoff
  have keysDistinct :
      ((witnesses left).recoveryId, left) ≠
        ((witnesses right).recoveryId, right) := by
    intro keysEqual
    exact distinct (congrArg Prod.snd keysEqual)
  have globallyDistinct :=
    distinctHandoffsHaveDistinctObservationEvidence
      evidence.identityClassification
      leftBinding.left
      rightBinding.left
      keysDistinct
  rw [leftBinding.right, rightBinding.right] at globallyDistinct
  exact globallyDistinct

theorem classifiedHandoffIdentityPreservesHandoffEvidence
    {trace : RecoveryTrace}
    {budgets : Nat → ProgressBudget}
    {scopes : Nat → ProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations : Nat → RecoveryExpectation}
    {witnesses : Nat → OwnerAuditWitness}
    {scheme : CommitmentScheme}
    {signatureVerified : String → String → String → Prop}
    {authorizationRegistry : String → CedarAuthorizationEvidence}
    {authorityPathAuthorized : String → String → String → String → Prop}
    {separationOfDutySatisfied : String → String → String → Prop}
    {envelopes : Nat → CommitmentEnvelope}
    {authenticityEvidence : Nat → AuthenticityEvidence}
    {snapshotSubjectBindingValid : CedarSnapshotSubjectBindingValid}
    {semantics : DecisionSemantics}
    {decisionReceiptValid : DecisionReceiptValid}
    {dualDecisionIdentityValid : CedarDualDecisionIdentityValid}
    {subjectRegistry : String → AuthorizationSubject}
    {leftReceiptRegistry rightReceiptRegistry :
      String → DecisionReceipt}
    {bundleDigestAt :
      Nat → AgenticAILabProof.Enterprise.BundleEvidenceBinding.BundleDigest}
    {bundleDigestAtValid :
      Nat →
        AgenticAILabProof.Enterprise.BundleEvidenceBinding.BundleDigest →
          Prop}
    {authorityReceiptValid : AuthorityReceiptValid}
    {assignmentValid :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityAssignment →
        Prop}
    {grantRegistry : String → AuthorityGrant}
    {authorityReceiptRegistry : String → BoundAuthorityReceipt}
    {freshnessChecksAt : Nat → EvidenceFreshnessChecks}
    {assignmentRegistry :
      String →
        SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityAssignment}
    {transferContractBinds : String → String → String → Prop}
    {effectiveObservationBinds : String → Nat → Prop}
    {transferAt : Nat → EnterpriseResponsibilityTransfer}
    {globalHandoffAt : GlobalHandoffKey → Prop}
    {globalTransferAt :
      GlobalHandoffKey → EnterpriseResponsibilityTransfer}
    (evidence :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityEvidence
        trace
        budgets
        scopes
        providerAcknowledgementStable
        expectations
        witnesses
        scheme
        signatureVerified
        authorizationRegistry
        authorityPathAuthorized
        separationOfDutySatisfied
        envelopes
        authenticityEvidence
        snapshotSubjectBindingValid
        semantics
        decisionReceiptValid
        dualDecisionIdentityValid
        subjectRegistry
        leftReceiptRegistry
        rightReceiptRegistry
        bundleDigestAt
        bundleDigestAtValid
        authorityReceiptValid
        assignmentValid
        grantRegistry
        authorityReceiptRegistry
        freshnessChecksAt
        assignmentRegistry
        transferContractBinds
        effectiveObservationBinds
        transferAt
        globalHandoffAt
        globalTransferAt) :
    SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffEvidence
      trace
      budgets
      scopes
      providerAcknowledgementStable
      expectations
      witnesses
      scheme
      signatureVerified
      authorizationRegistry
      authorityPathAuthorized
      separationOfDutySatisfied
      envelopes
      authenticityEvidence
      snapshotSubjectBindingValid
      semantics
      decisionReceiptValid
      dualDecisionIdentityValid
      subjectRegistry
      leftReceiptRegistry
      rightReceiptRegistry
      bundleDigestAt
      bundleDigestAtValid
      authorityReceiptValid
      assignmentValid
      grantRegistry
      authorityReceiptRegistry
      freshnessChecksAt
      assignmentRegistry
      transferContractBinds
      effectiveObservationBinds
      transferAt :=
  evidence.handoffEvidence

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityClosure
