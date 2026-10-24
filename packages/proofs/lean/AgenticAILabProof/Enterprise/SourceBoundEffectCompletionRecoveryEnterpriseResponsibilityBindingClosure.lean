-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeClosure
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityBindingCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityBindingClosure

open
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityBindingCore

abbrev RecoveryTrace :=
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryConvergenceClosure.SourceBoundEffectCompletionRecoveryTrace

abbrev RecoveryState :=
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure.SourceBoundEffectCompletionCrashRecoveryState

abbrev ProgressBudget :=
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryProgressEvidenceClosure.SourceBoundEffectCompletionRecoveryProgressBudget

abbrev ProgressScope :=
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryProgressEvidenceClosure.SourceBoundEffectCompletionRecoveryProgressScope

abbrev RecoveryExpectation :=
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure.SourceBoundEffectCompletionRecoveryExpectation

abbrev OwnerAuditWitness :=
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCore.SourceBoundEffectCompletionRecoveryOwnerAuditWitness

abbrev CommitmentScheme :=
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore.SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme

abbrev CommitmentEnvelope :=
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore.SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope

abbrev AuthenticityEvidence :=
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore.SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence

abbrev SubjectBridgeEvidence :=
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeClosure.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeEvidence

structure SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityEvidence
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
        SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityAssignment) :
    Prop where
  subjectBridgeEvidence :
    SubjectBridgeEvidence
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
  responsibilityBindings :
    ∀ index,
      trace index ≠
          AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure.SourceBoundEffectCompletionCrashRecoveryState.committed →
        let commitment := (envelopes index).commitment
        SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityBound
          snapshotSubjectBindingValid
          semantics
          decisionReceiptValid
          dualDecisionIdentityValid
          authorityReceiptValid
          assignmentValid
          (authorizationRegistry commitment)
          (authenticityEvidence index)
          (subjectRegistry commitment)
          (leftReceiptRegistry commitment)
          (rightReceiptRegistry commitment)
          (bundleDigestAt index)
          (grantRegistry commitment)
          (authorityReceiptRegistry commitment)
          (freshnessChecksAt index)
          commitment
          (authorizationRegistry commitment).runtimeEpoch
          (assignmentRegistry commitment)

theorem closedEnterpriseResponsibilityBindsAccountabilityAt
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
    (evidence :
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
        assignmentRegistry)
    (index : Nat)
    (active :
      trace index ≠
        AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure.SourceBoundEffectCompletionCrashRecoveryState.committed) :
    let commitment := (envelopes index).commitment
    (authorizationRegistry commitment).accountabilityIdentity =
        (authenticityEvidence index).accountabilityIdentity ∧
      (authenticityEvidence index).accountabilityIdentity =
        (assignmentRegistry commitment).accountablePrincipal := by
  exact enterpriseResponsibilityBindsAccountability
    (evidence.responsibilityBindings index active)

theorem closedEnterpriseResponsibilityBindsScopeAt
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
    (evidence :
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
        assignmentRegistry)
    (index : Nat)
    (active :
      trace index ≠
        AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure.SourceBoundEffectCompletionCrashRecoveryState.committed) :
    let commitment := (envelopes index).commitment
    (authorizationRegistry commitment).responsibilityScopeDigest =
        (authenticityEvidence index).responsibilityScopeDigest ∧
      (authenticityEvidence index).responsibilityScopeDigest =
        (assignmentRegistry commitment).responsibilityScopeDigest := by
  exact enterpriseResponsibilityBindsScope
    (evidence.responsibilityBindings index active)

theorem closedEnterpriseResponsibilityBindsCommitmentAt
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
    (evidence :
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
        assignmentRegistry)
    (index : Nat)
    (active :
      trace index ≠
        AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure.SourceBoundEffectCompletionCrashRecoveryState.committed) :
    let commitment := (envelopes index).commitment
    (authorizationRegistry commitment).commitment =
        (authenticityEvidence index).commitment ∧
      (authenticityEvidence index).commitment =
        (assignmentRegistry commitment).commitment ∧
      (assignmentRegistry commitment).commitment = commitment := by
  exact enterpriseResponsibilityBindsCommitment
    (evidence.responsibilityBindings index active)

theorem closedEnterpriseResponsibilityPreservesSubjectBridge
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
    (evidence :
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
        assignmentRegistry) :
    SubjectBridgeEvidence
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
      bundleDigestAtValid :=
  evidence.subjectBridgeEvidence

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityBindingClosure
