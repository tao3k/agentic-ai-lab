-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.UseCompositionCedarLifecycleJoinModel

structure CompositionGrantCoordinate where
  grantIdentity : Nat
  runtimeGeneration : Nat
  authorityIdentity : Nat
  deriving DecidableEq, Repr

structure LifecycleGrantBinding where
  grantIdentity : Nat
  decisionIdentity : Nat
  commitment : Nat
  accountabilityIdentity : Nat
  responsibilityScopeDigest : Nat
  activeFenceToken : Nat
  policySnapshotIdentity : Nat
  policyEvidenceRoot : Nat
  credentialIdentity : Nat
  credentialGeneration : Nat
  deriving DecidableEq, Repr

structure LifecycleEvidence where
  decisionIdentity : Nat
  commitment : Nat
  authorityIdentity : Nat
  accountabilityIdentity : Nat
  responsibilityScopeDigest : Nat
  runtimeEpoch : Nat
  activeFenceToken : Nat
  policySnapshotIdentity : Nat
  policyEvidenceRoot : Nat
  policyEpoch : Nat
  credentialIdentity : Nat
  credentialGeneration : Nat
  credentialActiveGeneration : Nat
  allow : Bool
  authorityPathAuthorized : Bool
  separationOfDutySatisfied : Bool
  deriving DecidableEq, Repr

def LifecycleEvidenceClosed (evidence : LifecycleEvidence) : Prop :=
  evidence.decisionIdentity ≠ 0 ∧
    evidence.commitment ≠ 0 ∧
    evidence.authorityIdentity ≠ 0 ∧
    evidence.accountabilityIdentity ≠ 0 ∧
    evidence.responsibilityScopeDigest ≠ 0 ∧
    evidence.policySnapshotIdentity ≠ 0 ∧
    evidence.policyEvidenceRoot ≠ 0 ∧
    evidence.credentialIdentity ≠ 0 ∧
    evidence.allow = true ∧
    evidence.policyEpoch = evidence.runtimeEpoch ∧
    evidence.credentialGeneration = evidence.credentialActiveGeneration ∧
    evidence.authorityPathAuthorized = true ∧
    evidence.separationOfDutySatisfied = true

def legacyAuthorityEpochJoin
    (grant : CompositionGrantCoordinate)
    (evidence : LifecycleEvidence) : Prop :=
  grant.authorityIdentity = evidence.authorityIdentity ∧
    grant.runtimeGeneration = evidence.runtimeEpoch

structure LifecycleJoinClosed
    (grant : CompositionGrantCoordinate)
    (binding : LifecycleGrantBinding)
    (evidence : LifecycleEvidence) : Prop where
  lifecycleClosed : LifecycleEvidenceClosed evidence
  grantIdentityBound : binding.grantIdentity = grant.grantIdentity
  authorityBound : evidence.authorityIdentity = grant.authorityIdentity
  runtimeBound : evidence.runtimeEpoch = grant.runtimeGeneration
  decisionIdentityBound : binding.decisionIdentity = evidence.decisionIdentity
  commitmentBound : binding.commitment = evidence.commitment
  accountabilityBound :
    binding.accountabilityIdentity = evidence.accountabilityIdentity
  responsibilityScopeBound :
    binding.responsibilityScopeDigest = evidence.responsibilityScopeDigest
  activeFenceBound : binding.activeFenceToken = evidence.activeFenceToken
  policySnapshotBound :
    binding.policySnapshotIdentity = evidence.policySnapshotIdentity
  policyEvidenceRootBound :
    binding.policyEvidenceRoot = evidence.policyEvidenceRoot
  credentialIdentityBound :
    binding.credentialIdentity = evidence.credentialIdentity
  credentialGenerationBound :
    binding.credentialGeneration = evidence.credentialGeneration

def sampleGrant : CompositionGrantCoordinate where
  grantIdentity := 700
  runtimeGeneration := 11
  authorityIdentity := 17

def currentEvidence : LifecycleEvidence where
  decisionIdentity := 101
  commitment := 201
  authorityIdentity := 17
  accountabilityIdentity := 19
  responsibilityScopeDigest := 301
  runtimeEpoch := 11
  activeFenceToken := 401
  policySnapshotIdentity := 7
  policyEvidenceRoot := 501
  policyEpoch := 11
  credentialIdentity := 601
  credentialGeneration := 3
  credentialActiveGeneration := 3
  allow := true
  authorityPathAuthorized := true
  separationOfDutySatisfied := true

def staleBinding : LifecycleGrantBinding where
  grantIdentity := 700
  decisionIdentity := 102
  commitment := 202
  accountabilityIdentity := 20
  responsibilityScopeDigest := 302
  activeFenceToken := 402
  policySnapshotIdentity := 8
  policyEvidenceRoot := 502
  credentialIdentity := 602
  credentialGeneration := 2

theorem legacyJoinAcceptsLifecycleUnboundGrant :
    legacyAuthorityEpochJoin sampleGrant currentEvidence ∧
      staleBinding.decisionIdentity ≠ currentEvidence.decisionIdentity ∧
      staleBinding.commitment ≠ currentEvidence.commitment ∧
      staleBinding.activeFenceToken ≠ currentEvidence.activeFenceToken ∧
      staleBinding.policyEvidenceRoot ≠ currentEvidence.policyEvidenceRoot ∧
      staleBinding.credentialIdentity ≠ currentEvidence.credentialIdentity := by
  simp [legacyAuthorityEpochJoin, sampleGrant, currentEvidence, staleBinding]

theorem closedJoinRejectsDecisionReplay
    {grant : CompositionGrantCoordinate}
    {binding : LifecycleGrantBinding}
    {evidence : LifecycleEvidence}
    (closed : LifecycleJoinClosed grant binding evidence)
    (mismatch : binding.decisionIdentity ≠ evidence.decisionIdentity) : False :=
  mismatch closed.decisionIdentityBound

theorem closedJoinRejectsCommitmentReplay
    {grant : CompositionGrantCoordinate}
    {binding : LifecycleGrantBinding}
    {evidence : LifecycleEvidence}
    (closed : LifecycleJoinClosed grant binding evidence)
    (mismatch : binding.commitment ≠ evidence.commitment) : False :=
  mismatch closed.commitmentBound

theorem closedJoinRejectsFenceReplay
    {grant : CompositionGrantCoordinate}
    {binding : LifecycleGrantBinding}
    {evidence : LifecycleEvidence}
    (closed : LifecycleJoinClosed grant binding evidence)
    (mismatch : binding.activeFenceToken ≠ evidence.activeFenceToken) : False :=
  mismatch closed.activeFenceBound

theorem closedJoinRejectsPolicyEvidenceReplay
    {grant : CompositionGrantCoordinate}
    {binding : LifecycleGrantBinding}
    {evidence : LifecycleEvidence}
    (closed : LifecycleJoinClosed grant binding evidence)
    (mismatch : binding.policyEvidenceRoot ≠ evidence.policyEvidenceRoot) : False :=
  mismatch closed.policyEvidenceRootBound

theorem closedJoinRejectsCredentialReplay
    {grant : CompositionGrantCoordinate}
    {binding : LifecycleGrantBinding}
    {evidence : LifecycleEvidence}
    (closed : LifecycleJoinClosed grant binding evidence)
    (mismatch : binding.credentialIdentity ≠ evidence.credentialIdentity) : False :=
  mismatch closed.credentialIdentityBound

theorem closedJoinProvidesCurrentAuthorityEpochAndFence
    {grant : CompositionGrantCoordinate}
    {binding : LifecycleGrantBinding}
    {evidence : LifecycleEvidence}
    (closed : LifecycleJoinClosed grant binding evidence) :
    evidence.authorityIdentity = grant.authorityIdentity ∧
      evidence.runtimeEpoch = grant.runtimeGeneration ∧
      binding.activeFenceToken = evidence.activeFenceToken :=
  ⟨closed.authorityBound, closed.runtimeBound, closed.activeFenceBound⟩

end AgenticAILabProof.Enterprise.UseCompositionCedarLifecycleJoinModel
