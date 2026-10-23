-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Cedar.Spec
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleCore

open SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore

/-!
# Cedar dual-engine authorization and credential lifecycle core

The reference decision is computed by `Cedar.Spec.isAuthorized`.  A production
adapter must return the complete same response, not merely the same allow/deny
bit.  Credential lifecycle and enterprise responsibility remain explicit.
-/

structure SourceBoundEffectCompletionRecoveryCredentialLifecycle where
  credentialIdentity : String
  subjectIdentity : String
  validFromEpoch : Nat
  validUntilEpoch : Nat
  revokedAtEpoch : Option Nat
  generation : Nat
  activeGeneration : Nat

def SourceBoundEffectCompletionRecoveryCredentialLifecycle.ActiveAt
    (credential :
      SourceBoundEffectCompletionRecoveryCredentialLifecycle)
    (epoch : Nat) : Prop :=
  credential.credentialIdentity ≠ "" ∧
  credential.subjectIdentity ≠ "" ∧
  credential.validFromEpoch ≤ epoch ∧
  epoch < credential.validUntilEpoch ∧
  (∀ revokedAt,
    credential.revokedAtEpoch = some revokedAt →
    epoch < revokedAt) ∧
  credential.generation = credential.activeGeneration

structure SourceBoundEffectCompletionRecoveryCedarPolicySnapshot where
  snapshotIdentity : String
  evidenceRoot : String
  policyEpoch : Nat
  activeFenceToken : Nat
  request : Cedar.Spec.Request
  entities : Cedar.Spec.Entities
  policies : Cedar.Spec.Policies

structure SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence where
  decisionIdentity : String
  commitment : String
  authorityIdentity : String
  accountabilityIdentity : String
  responsibilityScopeDigest : String
  runtimeEpoch : Nat
  activeFenceToken : Nat
  snapshot : SourceBoundEffectCompletionRecoveryCedarPolicySnapshot
  credential : SourceBoundEffectCompletionRecoveryCredentialLifecycle
  productionResponse : Cedar.Spec.Response

def SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence.Admitted
    (authorityPathAuthorized :
      String → String → String → String → Prop)
    (separationOfDutySatisfied :
      String → String → String → Prop)
    (expectedAuthority expectedCommitment : String)
    (evidence :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence) :
    Prop :=
  evidence.decisionIdentity ≠ "" ∧
  evidence.commitment = expectedCommitment ∧
  evidence.authorityIdentity = expectedAuthority ∧
  evidence.accountabilityIdentity ≠ "" ∧
  evidence.responsibilityScopeDigest ≠ "" ∧
  evidence.snapshot.snapshotIdentity ≠ "" ∧
  evidence.snapshot.evidenceRoot ≠ "" ∧
  evidence.snapshot.policyEpoch = evidence.runtimeEpoch ∧
  evidence.snapshot.activeFenceToken = evidence.activeFenceToken ∧
  evidence.productionResponse =
    Cedar.Spec.isAuthorized
      evidence.snapshot.request
      evidence.snapshot.entities
      evidence.snapshot.policies ∧
  evidence.productionResponse.decision = .allow ∧
  evidence.productionResponse.erroringPolicies.isEmpty = true ∧
  evidence.credential.ActiveAt evidence.runtimeEpoch ∧
  authorityPathAuthorized
    evidence.credential.subjectIdentity
    evidence.authorityIdentity
    evidence.responsibilityScopeDigest
    evidence.commitment ∧
  separationOfDutySatisfied
    evidence.authorityIdentity
    evidence.accountabilityIdentity
    evidence.commitment

def SourceBoundEffectCompletionRecoveryCedarAuthorizationRegistryAdmits
    (registry :
      String →
        SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence)
    (authorityPathAuthorized :
      String → String → String → String → Prop)
    (separationOfDutySatisfied :
      String → String → String → Prop)
    (authority commitment : String) : Prop :=
  (registry commitment).Admitted
    authorityPathAuthorized
    separationOfDutySatisfied
    authority
    commitment

theorem admittedCedarAuthorizationUsesReferenceResponse
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {expectedAuthority expectedCommitment : String}
    {evidence :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    (admitted :
      evidence.Admitted
        authorityPathAuthorized
        separationOfDutySatisfied
        expectedAuthority
        expectedCommitment) :
    evidence.productionResponse =
      Cedar.Spec.isAuthorized
        evidence.snapshot.request
        evidence.snapshot.entities
        evidence.snapshot.policies :=
  admitted.2.2.2.2.2.2.2.2.2.1

theorem admittedCedarAuthorizationIsAllow
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {expectedAuthority expectedCommitment : String}
    {evidence :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    (admitted :
      evidence.Admitted
        authorityPathAuthorized
        separationOfDutySatisfied
        expectedAuthority
        expectedCommitment) :
    evidence.productionResponse.decision = .allow :=
  admitted.2.2.2.2.2.2.2.2.2.2.1

theorem divergentCedarResponseRejectsAdmission
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {expectedAuthority expectedCommitment : String}
    {evidence :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    (divergent :
      evidence.productionResponse ≠
        Cedar.Spec.isAuthorized
          evidence.snapshot.request
          evidence.snapshot.entities
          evidence.snapshot.policies) :
    ¬ evidence.Admitted
        authorityPathAuthorized
        separationOfDutySatisfied
        expectedAuthority
        expectedCommitment := by
  intro admitted
  exact divergent admitted.2.2.2.2.2.2.2.2.2.1

theorem stalePolicySnapshotRejectsAdmission
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {expectedAuthority expectedCommitment : String}
    {evidence :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    (stale : evidence.snapshot.policyEpoch ≠ evidence.runtimeEpoch) :
    ¬ evidence.Admitted
        authorityPathAuthorized
        separationOfDutySatisfied
        expectedAuthority
        expectedCommitment := by
  intro admitted
  exact stale admitted.2.2.2.2.2.2.2.1

theorem revokedCredentialRejectsAdmission
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {expectedAuthority expectedCommitment : String}
    {evidence :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {revokedAt : Nat}
    (revoked :
      evidence.credential.revokedAtEpoch = some revokedAt)
    (notBeforeRevocation : ¬ evidence.runtimeEpoch < revokedAt) :
    ¬ evidence.Admitted
        authorityPathAuthorized
        separationOfDutySatisfied
        expectedAuthority
        expectedCommitment := by
  intro admitted
  exact notBeforeRevocation
    (admitted.2.2.2.2.2.2.2.2.2.2.2.2.1.2.2.2.2.1
      revokedAt revoked)

theorem erroringCedarResponseRejectsAdmission
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {expectedAuthority expectedCommitment : String}
    {evidence :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    (erroring :
      evidence.productionResponse.erroringPolicies.isEmpty ≠ true) :
    ¬ evidence.Admitted
        authorityPathAuthorized
        separationOfDutySatisfied
        expectedAuthority
        expectedCommitment := by
  intro admitted
  exact erroring admitted.2.2.2.2.2.2.2.2.2.2.2.1

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleCore
