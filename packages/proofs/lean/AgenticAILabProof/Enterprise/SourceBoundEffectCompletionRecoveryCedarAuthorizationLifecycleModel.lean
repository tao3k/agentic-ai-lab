-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleModel

/-!
# Independent dual-engine authorization and credential lifecycle model

The model separates full engine-response agreement, policy freshness,
credential activity, delegation, and separation of duty under one canonical
admission contract.
-/

inductive AuthorizationDecision where
  | allow
  | deny
  deriving DecidableEq, Repr

structure AuthorizationResponse where
  decision : AuthorizationDecision
  determiningPolicies : List Nat
  erroringPolicies : List Nat
  deriving DecidableEq, Repr

structure PolicySnapshot where
  snapshotIdentity : Nat
  evidenceRoot : Nat
  policyEpoch : Nat
  activeFenceToken : Nat
  deriving DecidableEq, Repr

structure CredentialLifecycle where
  credentialIdentity : Nat
  subjectIdentity : Nat
  validFromEpoch : Nat
  validUntilEpoch : Nat
  revokedAtEpoch : Option Nat
  generation : Nat
  activeGeneration : Nat
  deriving DecidableEq, Repr

def CredentialLifecycle.ActiveAt
    (credential : CredentialLifecycle)
    (epoch : Nat) : Prop :=
  credential.credentialIdentity ≠ 0 ∧
  credential.subjectIdentity ≠ 0 ∧
  credential.validFromEpoch ≤ epoch ∧
  epoch < credential.validUntilEpoch ∧
  (∀ revokedAt, credential.revokedAtEpoch = some revokedAt → epoch < revokedAt) ∧
  credential.generation = credential.activeGeneration

structure AuthorizationLifecycleEvidence where
  decisionIdentity : Nat
  commitment : Nat
  authorityIdentity : Nat
  accountabilityIdentity : Nat
  responsibilityScopeDigest : Nat
  runtimeEpoch : Nat
  activeFenceToken : Nat
  snapshot : PolicySnapshot
  credential : CredentialLifecycle
  referenceResponse : AuthorizationResponse
  productionResponse : AuthorizationResponse
  deriving DecidableEq, Repr

def AuthorizationLifecycleEvidence.Closed
    (authorityPathAuthorized : Nat → Nat → Nat → Nat → Prop)
    (separationOfDutySatisfied : Nat → Nat → Nat → Prop)
    (evidence : AuthorizationLifecycleEvidence) : Prop :=
  evidence.decisionIdentity ≠ 0 ∧
  evidence.commitment ≠ 0 ∧
  evidence.authorityIdentity ≠ 0 ∧
  evidence.accountabilityIdentity ≠ 0 ∧
  evidence.responsibilityScopeDigest ≠ 0 ∧
  evidence.referenceResponse = evidence.productionResponse ∧
  evidence.productionResponse.decision = .allow ∧
  evidence.productionResponse.erroringPolicies = [] ∧
  evidence.snapshot.snapshotIdentity ≠ 0 ∧
  evidence.snapshot.evidenceRoot ≠ 0 ∧
  evidence.snapshot.policyEpoch = evidence.runtimeEpoch ∧
  evidence.snapshot.activeFenceToken = evidence.activeFenceToken ∧
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

def referenceAllow : AuthorizationResponse where
  decision := .allow
  determiningPolicies := [10]
  erroringPolicies := []

def productionAllowDifferentPolicy : AuthorizationResponse where
  decision := .allow
  determiningPolicies := [11]
  erroringPolicies := []

theorem decisionOnlyAgreementDoesNotProveResponseAgreement :
    referenceAllow.decision = productionAllowDifferentPolicy.decision ∧
    referenceAllow ≠ productionAllowDifferentPolicy := by
  decide

def revokedCredential : CredentialLifecycle where
  credentialIdentity := 7
  subjectIdentity := 8
  validFromEpoch := 1
  validUntilEpoch := 20
  revokedAtEpoch := some 5
  generation := 3
  activeGeneration := 3

theorem verifiedSignatureDoesNotProveCredentialActive :
    (True : Prop) ∧
    ¬ revokedCredential.ActiveAt 10 := by
  constructor
  · trivial
  · intro active
    have beforeRevocation := active.2.2.2.2.1 5 rfl
    omega

theorem closedLifecycleForcesFullEngineAgreement
    {authorityPathAuthorized : Nat → Nat → Nat → Nat → Prop}
    {separationOfDutySatisfied : Nat → Nat → Nat → Prop}
    {evidence : AuthorizationLifecycleEvidence}
    (closed :
      evidence.Closed
        authorityPathAuthorized separationOfDutySatisfied) :
    evidence.referenceResponse = evidence.productionResponse :=
  closed.2.2.2.2.2.1

theorem closedLifecycleForcesCurrentPolicyEpoch
    {authorityPathAuthorized : Nat → Nat → Nat → Nat → Prop}
    {separationOfDutySatisfied : Nat → Nat → Nat → Prop}
    {evidence : AuthorizationLifecycleEvidence}
    (closed :
      evidence.Closed
        authorityPathAuthorized separationOfDutySatisfied) :
    evidence.snapshot.policyEpoch = evidence.runtimeEpoch :=
  closed.2.2.2.2.2.2.2.2.2.2.1

theorem stalePolicySnapshotRejectsLifecycle
    {authorityPathAuthorized : Nat → Nat → Nat → Nat → Prop}
    {separationOfDutySatisfied : Nat → Nat → Nat → Prop}
    {evidence : AuthorizationLifecycleEvidence}
    (stale : evidence.snapshot.policyEpoch ≠ evidence.runtimeEpoch) :
    ¬ evidence.Closed
        authorityPathAuthorized separationOfDutySatisfied := by
  intro closed
  exact stale closed.2.2.2.2.2.2.2.2.2.2.1

theorem divergentEngineResponseRejectsLifecycle
    {authorityPathAuthorized : Nat → Nat → Nat → Nat → Prop}
    {separationOfDutySatisfied : Nat → Nat → Nat → Prop}
    {evidence : AuthorizationLifecycleEvidence}
    (divergent :
      evidence.referenceResponse ≠ evidence.productionResponse) :
    ¬ evidence.Closed
        authorityPathAuthorized separationOfDutySatisfied := by
  intro closed
  exact divergent closed.2.2.2.2.2.1

theorem erroringAllowRejectsLifecycle
    {authorityPathAuthorized : Nat → Nat → Nat → Nat → Prop}
    {separationOfDutySatisfied : Nat → Nat → Nat → Prop}
    {evidence : AuthorizationLifecycleEvidence}
    (erroring : evidence.productionResponse.erroringPolicies ≠ []) :
    ¬ evidence.Closed
        authorityPathAuthorized separationOfDutySatisfied := by
  intro closed
  exact erroring closed.2.2.2.2.2.2.2.1

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleModel
