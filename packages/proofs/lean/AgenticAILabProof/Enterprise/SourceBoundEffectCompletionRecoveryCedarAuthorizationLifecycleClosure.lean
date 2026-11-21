-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleCore
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentClosure

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleClosure

open SourceBoundEffectCompletionCrashRecoveryClosure
open SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleCore
open SourceBoundEffectCompletionRecoveryConvergenceClosure
open SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentClosure
open SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore
open SourceBoundEffectCompletionRecoveryOwnerAuditCore
open SourceBoundEffectCompletionRecoveryProgressEvidenceClosure

/-!
# Cedar dual-engine authorization lifecycle trace closure

Every non-committed recovery position resolves its exact commitment through one
Cedar authorization registry.  The registered evidence must agree with the
reference `Cedar.Spec.isAuthorized` response, remain current for the recovery
epoch and fence, and bind the credential and responsibility evidence already
carried by the commitment-authenticity closure.
-/

structure SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleEvidence
    (trace : SourceBoundEffectCompletionRecoveryTrace)
    (budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget)
    (scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope)
    (providerAcknowledgementStable : Nat → Prop)
    (expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation)
    (witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness)
    (scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme)
    (signatureVerified : String → String → String → Prop)
    (registry :
      String →
        SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence)
    (authorityPathAuthorized :
      String → String → String → String → Prop)
    (separationOfDutySatisfied :
      String → String → String → Prop)
    (envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope)
    (authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence) :
    Prop where
  commitmentEvidence :
    SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEvidence
      trace
      budgets
      scopes
      providerAcknowledgementStable
      expectations
      witnesses
      scheme
      (SourceBoundEffectCompletionRecoveryCedarAuthorizationRegistryAdmits
        registry authorityPathAuthorized separationOfDutySatisfied)
      signatureVerified
      envelopes
      authenticityEvidence
  cedarBindings :
    ∀ index,
      trace index ≠ .committed →
      let cedarEvidence := registry (envelopes index).commitment
      cedarEvidence.decisionIdentity =
          (authenticityEvidence index).policyDecisionIdentity ∧
        cedarEvidence.snapshot.evidenceRoot =
          (authenticityEvidence index).policyEvidenceRoot ∧
        cedarEvidence.credential.credentialIdentity =
          (authenticityEvidence index).credentialIdentity ∧
        cedarEvidence.accountabilityIdentity =
          (authenticityEvidence index).accountabilityIdentity ∧
        cedarEvidence.responsibilityScopeDigest =
          (authenticityEvidence index).responsibilityScopeDigest ∧
        cedarEvidence.runtimeEpoch =
          (envelopes index).payload.runtimeEpoch ∧
        cedarEvidence.activeFenceToken =
          (envelopes index).payload.activeFenceToken

theorem closedCedarLifecycleBuildsCommitmentAudit
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {signatureVerified : String → String → String → Prop}
    {registry :
      String →
        SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    (evidence :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme signatureVerified registry
        authorityPathAuthorized separationOfDutySatisfied
        envelopes authenticityEvidence) :
    SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEvidence
      trace
      budgets
      scopes
      providerAcknowledgementStable
      expectations
      witnesses
      scheme
      (SourceBoundEffectCompletionRecoveryCedarAuthorizationRegistryAdmits
        registry authorityPathAuthorized separationOfDutySatisfied)
      signatureVerified
      envelopes
      authenticityEvidence :=
  evidence.commitmentEvidence

theorem closedCedarLifecycleAuthorizationAdmitted
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {signatureVerified : String → String → String → Prop}
    {registry :
      String →
        SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    {index : Nat}
    (evidence :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme signatureVerified registry
        authorityPathAuthorized separationOfDutySatisfied
        envelopes authenticityEvidence)
    (notCommitted : trace index ≠ .committed) :
    (registry (envelopes index).commitment).Admitted
      authorityPathAuthorized
      separationOfDutySatisfied
      (authenticityEvidence index).authorityIdentity
      (envelopes index).commitment :=
  (evidence.commitmentEvidence.commitmentAuthenticity
    index notCommitted).authenticityValid.2.2.2.2.2.2.2.2.1

theorem closedCedarLifecycleConverges
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {signatureVerified : String → String → String → Prop}
    {registry :
      String →
        SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    (transitionClosed :
      SourceBoundEffectCompletionRecoveryTraceTransitionClosed trace)
    (evidence :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme signatureVerified registry
        authorityPathAuthorized separationOfDutySatisfied
        envelopes authenticityEvidence) :
    SourceBoundEffectCompletionRecoveryTraceConverges trace :=
  closedCommitmentAuditConverges
    transitionClosed evidence.commitmentEvidence

theorem staleRegisteredPolicyRejectsCedarLifecycle
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {signatureVerified : String → String → String → Prop}
    {registry :
      String →
        SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    {index : Nat}
    (notCommitted : trace index ≠ .committed)
    (stale :
      (registry (envelopes index).commitment).snapshot.policyEpoch ≠
        (registry (envelopes index).commitment).runtimeEpoch) :
    ¬ SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme signatureVerified registry
        authorityPathAuthorized separationOfDutySatisfied
        envelopes authenticityEvidence := by
  intro evidence
  exact stalePolicySnapshotRejectsAdmission stale
    (closedCedarLifecycleAuthorizationAdmitted evidence notCommitted)

theorem divergentRegisteredResponseRejectsCedarLifecycle
    {trace : SourceBoundEffectCompletionRecoveryTrace}
    {budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget}
    {scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope}
    {providerAcknowledgementStable : Nat → Prop}
    {expectations :
      Nat → SourceBoundEffectCompletionRecoveryExpectation}
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    {scheme :
      SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme}
    {signatureVerified : String → String → String → Prop}
    {registry :
      String →
        SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {envelopes :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope}
    {authenticityEvidence :
      Nat →
        SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence}
    {index : Nat}
    (notCommitted : trace index ≠ .committed)
    (divergent :
      let cedarEvidence := registry (envelopes index).commitment
      cedarEvidence.productionResponse ≠
        Cedar.Spec.isAuthorized
          cedarEvidence.snapshot.request
          cedarEvidence.snapshot.entities
          cedarEvidence.snapshot.policies) :
    ¬ SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleEvidence
        trace budgets scopes providerAcknowledgementStable expectations
        witnesses scheme signatureVerified registry
        authorityPathAuthorized separationOfDutySatisfied
        envelopes authenticityEvidence := by
  intro evidence
  exact divergentCedarResponseRejectsAdmission divergent
    (closedCedarLifecycleAuthorizationAdmitted evidence notCommitted)

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleClosure
