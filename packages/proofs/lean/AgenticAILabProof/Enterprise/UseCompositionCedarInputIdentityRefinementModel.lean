-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityRefinementModel

structure AuthorizationSubject where
  requestDigest : Nat
  policySetDigest : Nat
  entityStoreDigest : Nat
  bundleDigest : Nat
  deriving DecidableEq, Repr

structure CedarInputSnapshot where
  request : Nat
  entities : Nat
  policies : Nat
  deriving DecidableEq, Repr

structure CedarInputIdentityAuthority where
  authorityIdentity : Nat
  semanticIdentity : Nat
  generation : Nat
  requestDigest : Nat → Nat
  entityStoreDigest : Nat → Nat
  policySetDigest : Nat → Nat
  bundleDigest : CedarInputSnapshot → Nat
  requestAdmitted : Nat → Prop
  entitiesAdmitted : Nat → Prop
  policiesAdmitted : Nat → Prop
  snapshotAdmitted : CedarInputSnapshot → Prop
  requestUniqueOnAdmitted :
    ∀ left right,
      requestAdmitted left → requestAdmitted right →
      requestDigest left = requestDigest right → left = right
  entitiesUniqueOnAdmitted :
    ∀ left right,
      entitiesAdmitted left → entitiesAdmitted right →
      entityStoreDigest left = entityStoreDigest right → left = right
  policiesUniqueOnAdmitted :
    ∀ left right,
      policiesAdmitted left → policiesAdmitted right →
      policySetDigest left = policySetDigest right → left = right
  snapshotUniqueOnAdmitted :
    ∀ left right,
      snapshotAdmitted left → snapshotAdmitted right →
      bundleDigest left = bundleDigest right → left = right

def weakSubjectInputBinding
    (_subject : AuthorizationSubject)
    (_snapshot : CedarInputSnapshot) : Prop := True

structure SubjectInputIdentityRefinementClosed
    (identityAuthority : CedarInputIdentityAuthority)
    (expectedAuthority expectedSemanticIdentity expectedGeneration : Nat)
    (subject : AuthorizationSubject)
    (snapshot : CedarInputSnapshot) : Prop where
  authorityBound : identityAuthority.authorityIdentity = expectedAuthority
  semanticIdentityBound :
    identityAuthority.semanticIdentity = expectedSemanticIdentity
  generationBound : identityAuthority.generation = expectedGeneration
  requestAdmitted : identityAuthority.requestAdmitted snapshot.request
  entitiesAdmitted : identityAuthority.entitiesAdmitted snapshot.entities
  policiesAdmitted : identityAuthority.policiesAdmitted snapshot.policies
  snapshotAdmitted : identityAuthority.snapshotAdmitted snapshot
  requestDigestBound :
    subject.requestDigest = identityAuthority.requestDigest snapshot.request
  entityStoreDigestBound :
    subject.entityStoreDigest =
      identityAuthority.entityStoreDigest snapshot.entities
  policySetDigestBound :
    subject.policySetDigest = identityAuthority.policySetDigest snapshot.policies
  bundleDigestBound :
    subject.bundleDigest = identityAuthority.bundleDigest snapshot

def subjectA : AuthorizationSubject where
  requestDigest := 11
  policySetDigest := 21
  entityStoreDigest := 31
  bundleDigest := 41

def snapshotB : CedarInputSnapshot where
  request := 12
  entities := 32
  policies := 22

theorem weakAcceptedBindingAllowsCrossSubjectCedarInputs :
    weakSubjectInputBinding subjectA snapshotB ∧
      subjectA.requestDigest ≠ snapshotB.request ∧
      subjectA.entityStoreDigest ≠ snapshotB.entities ∧
      subjectA.policySetDigest ≠ snapshotB.policies := by
  simp [weakSubjectInputBinding, subjectA, snapshotB]

theorem closedRefinementRejectsRequestDigestMismatch
    {identityAuthority : CedarInputIdentityAuthority}
    {expectedAuthority expectedSemanticIdentity expectedGeneration : Nat}
    {subject : AuthorizationSubject}
    {snapshot : CedarInputSnapshot}
    (closed :
      SubjectInputIdentityRefinementClosed identityAuthority
        expectedAuthority expectedSemanticIdentity expectedGeneration
        subject snapshot)
    (mismatch :
      subject.requestDigest ≠ identityAuthority.requestDigest snapshot.request) :
    False :=
  mismatch closed.requestDigestBound

theorem closedRefinementRejectsEntityDigestMismatch
    {identityAuthority : CedarInputIdentityAuthority}
    {expectedAuthority expectedSemanticIdentity expectedGeneration : Nat}
    {subject : AuthorizationSubject}
    {snapshot : CedarInputSnapshot}
    (closed :
      SubjectInputIdentityRefinementClosed identityAuthority
        expectedAuthority expectedSemanticIdentity expectedGeneration
        subject snapshot)
    (mismatch :
      subject.entityStoreDigest ≠
        identityAuthority.entityStoreDigest snapshot.entities) : False :=
  mismatch closed.entityStoreDigestBound

theorem closedRefinementRejectsPolicyDigestMismatch
    {identityAuthority : CedarInputIdentityAuthority}
    {expectedAuthority expectedSemanticIdentity expectedGeneration : Nat}
    {subject : AuthorizationSubject}
    {snapshot : CedarInputSnapshot}
    (closed :
      SubjectInputIdentityRefinementClosed identityAuthority
        expectedAuthority expectedSemanticIdentity expectedGeneration
        subject snapshot)
    (mismatch :
      subject.policySetDigest ≠
        identityAuthority.policySetDigest snapshot.policies) : False :=
  mismatch closed.policySetDigestBound

theorem closedRefinementRejectsBundleDigestMismatch
    {identityAuthority : CedarInputIdentityAuthority}
    {expectedAuthority expectedSemanticIdentity expectedGeneration : Nat}
    {subject : AuthorizationSubject}
    {snapshot : CedarInputSnapshot}
    (closed :
      SubjectInputIdentityRefinementClosed identityAuthority
        expectedAuthority expectedSemanticIdentity expectedGeneration
        subject snapshot)
    (mismatch :
      subject.bundleDigest ≠ identityAuthority.bundleDigest snapshot) : False :=
  mismatch closed.bundleDigestBound

theorem equalAdmittedRequestDigestIdentifiesExactRequest
    {identityAuthority : CedarInputIdentityAuthority}
    {left right : Nat}
    (leftAdmitted : identityAuthority.requestAdmitted left)
    (rightAdmitted : identityAuthority.requestAdmitted right)
    (sameDigest :
      identityAuthority.requestDigest left =
        identityAuthority.requestDigest right) :
    left = right :=
  identityAuthority.requestUniqueOnAdmitted
    left right leftAdmitted rightAdmitted sameDigest

theorem closedRefinementRejectsStaleIdentityGeneration
    {identityAuthority : CedarInputIdentityAuthority}
    {expectedAuthority expectedSemanticIdentity expectedGeneration : Nat}
    {subject : AuthorizationSubject}
    {snapshot : CedarInputSnapshot}
    (closed :
      SubjectInputIdentityRefinementClosed identityAuthority
        expectedAuthority expectedSemanticIdentity expectedGeneration
        subject snapshot)
    (mismatch : identityAuthority.generation ≠ expectedGeneration) : False :=
  mismatch closed.generationBound

end AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityRefinementModel
