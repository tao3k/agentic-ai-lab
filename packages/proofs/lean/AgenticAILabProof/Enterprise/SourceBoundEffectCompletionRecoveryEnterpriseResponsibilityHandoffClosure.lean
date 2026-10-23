-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityBindingClosure
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffClosure

open
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityBindingCore
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityBindingClosure
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffCore

structure SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffEvidence
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
    (transferAt : Nat → EnterpriseResponsibilityTransfer) :
    Prop where
  responsibilityEvidence :
    SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityEvidence
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
  adjacentContinuity :
    ∀ index,
      trace index ≠
          AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure.SourceBoundEffectCompletionCrashRecoveryState.committed →
        trace (index + 1) ≠
            AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure.SourceBoundEffectCompletionCrashRecoveryState.committed →
          let beforeCommitment := (envelopes index).commitment
          let afterCommitment := (envelopes (index + 1)).commitment
          SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityAdjacentContinuity
            transferContractBinds
            effectiveObservationBinds
            (assignmentRegistry beforeCommitment)
            (assignmentRegistry afterCommitment)
            (transferAt index)

theorem changedTraceResponsibilityRequiresHandoffAt
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
    (evidence :
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
        transferAt)
    (index : Nat)
    (currentActive :
      trace index ≠
        AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure.SourceBoundEffectCompletionCrashRecoveryState.committed)
    (nextActive :
      trace (index + 1) ≠
        AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure.SourceBoundEffectCompletionCrashRecoveryState.committed)
    (changed :
      (assignmentRegistry (envelopes index).commitment).accountablePrincipal ≠
        (assignmentRegistry
          (envelopes (index + 1)).commitment).accountablePrincipal) :
    SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffBound
      transferContractBinds
      effectiveObservationBinds
      (assignmentRegistry (envelopes index).commitment)
      (assignmentRegistry (envelopes (index + 1)).commitment)
      (transferAt index) :=
  changedAdjacentContinuityRequiresHandoff
    changed
    (evidence.adjacentContinuity index currentActive nextActive)

theorem traceResponsibilityContinuityPreservesSubjectAndScopeAt
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
    (evidence :
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
        transferAt)
    (index : Nat)
    (currentActive :
      trace index ≠
        AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure.SourceBoundEffectCompletionCrashRecoveryState.committed)
    (nextActive :
      trace (index + 1) ≠
        AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure.SourceBoundEffectCompletionCrashRecoveryState.committed) :
    (assignmentRegistry (envelopes index).commitment).subject =
        (assignmentRegistry (envelopes (index + 1)).commitment).subject ∧
      (assignmentRegistry
          (envelopes index).commitment).responsibilityScopeDigest =
        (assignmentRegistry
          (envelopes (index + 1)).commitment).responsibilityScopeDigest :=
  adjacentContinuityPreservesSubjectAndScope
    (evidence.adjacentContinuity index currentActive nextActive)

theorem changedTraceResponsibilityClosesGapAndExclusiveOverlapAt
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
    (evidence :
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
        transferAt)
    (index : Nat)
    (currentActive :
      trace index ≠
        AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure.SourceBoundEffectCompletionCrashRecoveryState.committed)
    (nextActive :
      trace (index + 1) ≠
        AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure.SourceBoundEffectCompletionCrashRecoveryState.committed)
    (changed :
      (assignmentRegistry (envelopes index).commitment).accountablePrincipal ≠
        (assignmentRegistry
          (envelopes (index + 1)).commitment).accountablePrincipal) :
    ¬(transferAt index).responsibilityGap ∧
      ¬(transferAt index).overlappingExclusiveAuthority :=
  handoffClosesResponsibilityGapAndExclusiveOverlap
    (changedTraceResponsibilityRequiresHandoffAt
      evidence
      index
      currentActive
      nextActive
      changed)

theorem closedResponsibilityHandoffPreservesAssignmentEvidence
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
    (evidence :
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
        transferAt) :
    SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityEvidence
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
      assignmentRegistry :=
  evidence.responsibilityEvidence

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffClosure
