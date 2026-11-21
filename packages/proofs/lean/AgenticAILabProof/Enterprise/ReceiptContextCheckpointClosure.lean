-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.ReceiptContextMonotonicityClosure

namespace AgenticAILabProof.Enterprise.ReceiptContextCheckpointClosure

open AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure
open AgenticAILabProof.Enterprise.ReceiptContextMonotonicityClosure

/--
Countermodel: a fork-free publication domain may retain multiple historical
generations.  Membership proves that a context was published, but does not
select which published context is the current head.
-/
theorem historicalMembershipDoesNotEstablishCurrentHead :
    ∃
      (domain : AuthoritativeContextPublicationDomain)
      (historical current : ContextPublicationMembershipEvidence domain),
      historical.context ≠ current.context := by
  let historicalContext : ReceiptValidationContext :=
    {
      authorityIdentity := 191
      authorityGeneration := 20
      policySnapshotIdentity := 193
      authorizationSnapshotIdentity := 197
      revocationSnapshotIdentity := 199
    }
  let currentContext : ReceiptValidationContext :=
    {
      authorityIdentity := 191
      authorityGeneration := 21
      policySnapshotIdentity := 211
      authorizationSnapshotIdentity := 223
      revocationSnapshotIdentity := 227
    }
  let domain : AuthoritativeContextPublicationDomain :=
    {
      domainIdentity := 181
      domainSemanticIdentity := 183
      authorityIdentity := 191
      published := fun context =>
        context = historicalContext ∨ context = currentContext
      authorityBound := by
        intro context contextPublished
        rcases contextPublished with historical | current
        · subst context
          rfl
        · subst context
          rfl
      forkFree := by
        intro left right leftPublished rightPublished _ sameGeneration
        rcases leftPublished with leftHistorical | leftCurrent <;>
          rcases rightPublished with rightHistorical | rightCurrent
        · exact leftHistorical.trans rightHistorical.symm
        · subst left
          subst right
          simp [historicalContext, currentContext] at sameGeneration
        · subst left
          subst right
          simp [historicalContext, currentContext] at sameGeneration
        · exact leftCurrent.trans rightCurrent.symm
    }
  let historical :
      ContextPublicationMembershipEvidence domain :=
    {
      context := historicalContext
      member := Or.inl rfl
    }
  let current :
      ContextPublicationMembershipEvidence domain :=
    {
      context := currentContext
      member := Or.inr rfl
    }
  have contextsDiffer : historical.context ≠ current.context := by
    decide
  exact ⟨domain, historical, current, contextsDiffer⟩

/--
An authority-issued checkpoint selects one publication-domain member as the
current head.  The type is parameterized by the publication domain so evidence
from another domain cannot be silently substituted.
-/
structure AuthorityPublicationCheckpoint
    (domain : AuthoritativeContextPublicationDomain) where
  head : ContextPublicationMembershipEvidence domain

def currentAtCheckpoint
    {domain : AuthoritativeContextPublicationDomain}
    (checkpoint : AuthorityPublicationCheckpoint domain)
    (candidate : ContextPublicationMembershipEvidence domain) : Prop :=
  candidate.context = checkpoint.head.context

theorem checkpointHeadIsCurrent
    {domain : AuthoritativeContextPublicationDomain}
    (checkpoint : AuthorityPublicationCheckpoint domain) :
    currentAtCheckpoint checkpoint checkpoint.head :=
  rfl

theorem sharedCheckpointSelectsUniqueCurrentContext
    {domain : AuthoritativeContextPublicationDomain}
    (checkpoint : AuthorityPublicationCheckpoint domain)
    (left right : ContextPublicationMembershipEvidence domain)
    (leftCurrent : currentAtCheckpoint checkpoint left)
    (rightCurrent : currentAtCheckpoint checkpoint right) :
    left.context = right.context :=
  leftCurrent.trans rightCurrent.symm

theorem historicalMemberIsRejectedWhenItIsNotCheckpointHead
    {domain : AuthoritativeContextPublicationDomain}
    (checkpoint : AuthorityPublicationCheckpoint domain)
    (historical : ContextPublicationMembershipEvidence domain)
    (notHead : historical.context ≠ checkpoint.head.context) :
    ¬ currentAtCheckpoint checkpoint historical := by
  intro historicalCurrent
  exact notHead historicalCurrent

def validCheckpointAdvance
    {domain : AuthoritativeContextPublicationDomain}
    (before after : AuthorityPublicationCheckpoint domain) : Prop :=
  validAuthorityContextTransition
    before.head.context
    after.head.context

theorem validCheckpointAdvanceRejectsReceiptAtPriorHead
    {domain : AuthoritativeContextPublicationDomain}
    {before after : AuthorityPublicationCheckpoint domain}
    {receipt : ContextBoundAuthorityReceipt}
    (acceptedAtPriorHead :
      acceptedAtContext before.head.context receipt)
    (checkpointAdvanced : validCheckpointAdvance before after) :
    ¬ acceptedAtContext after.head.context receipt :=
  validTransitionRejectsReceiptIssuedBeforeTransition
    acceptedAtPriorHead
    checkpointAdvanced

/--
A verifier-owned watermark records the lowest authority generation that may be
accepted without a known rollback.  It is bounded local evidence, not a claim
that the verifier has observed the globally latest checkpoint.
-/
structure TrustedCheckpointWatermark where
  publicationDomainIdentity : Nat
  authorityIdentity : Nat
  minimumGeneration : Nat

def checkpointAcceptedByWatermark
    {domain : AuthoritativeContextPublicationDomain}
    (watermark : TrustedCheckpointWatermark)
    (checkpoint : AuthorityPublicationCheckpoint domain) : Prop :=
  domain.domainIdentity = watermark.publicationDomainIdentity ∧
    checkpoint.head.context.authorityIdentity =
        watermark.authorityIdentity ∧
      watermark.minimumGeneration ≤
        checkpoint.head.context.authorityGeneration

theorem watermarkRejectsKnownCheckpointRollback
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpoint : AuthorityPublicationCheckpoint domain}
    (generationRolledBack :
      checkpoint.head.context.authorityGeneration <
        watermark.minimumGeneration) :
    ¬ checkpointAcceptedByWatermark watermark checkpoint := by
  intro checkpointAccepted
  exact (Nat.not_le_of_gt generationRolledBack) checkpointAccepted.2.2

/--
Countermodel: a low local watermark accepts a historical checkpoint even when
another domain member has been selected as the live head.  Watermark acceptance
does not establish global latestness.
-/
theorem watermarkAcceptanceDoesNotEstablishLiveHead :
    ∃
      (domain : AuthoritativeContextPublicationDomain)
      (candidate live : AuthorityPublicationCheckpoint domain)
      (watermark : TrustedCheckpointWatermark),
      checkpointAcceptedByWatermark watermark candidate ∧
        candidate.head.context ≠ live.head.context := by
  rcases historicalMembershipDoesNotEstablishCurrentHead with
    ⟨domain, historical, current, contextsDiffer⟩
  let candidate : AuthorityPublicationCheckpoint domain :=
    { head := historical }
  let live : AuthorityPublicationCheckpoint domain :=
    { head := current }
  let watermark : TrustedCheckpointWatermark :=
    {
      publicationDomainIdentity := domain.domainIdentity
      authorityIdentity := historical.context.authorityIdentity
      minimumGeneration := 0
    }
  have candidateAccepted :
      checkpointAcceptedByWatermark watermark candidate := by
    exact ⟨rfl, rfl, Nat.zero_le _⟩
  exact
    ⟨domain, candidate, live, watermark, candidateAccepted, contextsDiffer⟩

/--
A declared checkpoint attestation is only data.  Constructing this value does
not prove that the live authority issued it.
-/
structure DeclaredCheckpointAttestation
    (domain : AuthoritativeContextPublicationDomain) where
  checkpoint : AuthorityPublicationCheckpoint domain

def checkpointMatchesDeclaredAttestation
    {domain : AuthoritativeContextPublicationDomain}
    (watermark : TrustedCheckpointWatermark)
    (declared : DeclaredCheckpointAttestation domain)
    (candidate : AuthorityPublicationCheckpoint domain) : Prop :=
  checkpointAcceptedByWatermark watermark candidate ∧
    candidate.head.context = declared.checkpoint.head.context

theorem checkpointMatchingDeclaredAttestationEqualsDeclaredHead
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {declared : DeclaredCheckpointAttestation domain}
    {candidate : AuthorityPublicationCheckpoint domain}
    (candidateMatches :
      checkpointMatchesDeclaredAttestation
        watermark
        declared
        candidate) :
    candidate.head.context = declared.checkpoint.head.context :=
  candidateMatches.2

theorem declaredHeadMismatchRejectsCandidate
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {declared : DeclaredCheckpointAttestation domain}
    {candidate : AuthorityPublicationCheckpoint domain}
    (candidateDoesNotMatch :
      candidate.head.context ≠ declared.checkpoint.head.context) :
    ¬ checkpointMatchesDeclaredAttestation
        watermark
        declared
        candidate := by
  intro candidateMatches
  exact candidateDoesNotMatch candidateMatches.2

/--
Countermodel: a historical checkpoint can declare itself to be the live head.
The structural match succeeds because both the candidate and declaration are
attacker-selected.  No authority issuance fact has been established.
-/
theorem selfReportedCheckpointAttestationDoesNotEstablishLiveCurrentness :
    ∃
      (domain : AuthoritativeContextPublicationDomain)
      (watermark : TrustedCheckpointWatermark)
      (actualCurrent candidate : AuthorityPublicationCheckpoint domain)
      (declared : DeclaredCheckpointAttestation domain),
      checkpointMatchesDeclaredAttestation
          watermark
          declared
          candidate ∧
        candidate.head.context ≠ actualCurrent.head.context := by
  rcases historicalMembershipDoesNotEstablishCurrentHead with
    ⟨domain, historical, current, contextsDiffer⟩
  let candidate : AuthorityPublicationCheckpoint domain :=
    { head := historical }
  let actualCurrent : AuthorityPublicationCheckpoint domain :=
    { head := current }
  let declared : DeclaredCheckpointAttestation domain :=
    { checkpoint := candidate }
  let watermark : TrustedCheckpointWatermark :=
    {
      publicationDomainIdentity := domain.domainIdentity
      authorityIdentity := historical.context.authorityIdentity
      minimumGeneration := 0
    }
  have candidateAccepted :
      checkpointAcceptedByWatermark watermark candidate := by
    exact ⟨rfl, rfl, Nat.zero_le _⟩
  have candidateMatches :
      checkpointMatchesDeclaredAttestation
        watermark
        declared
        candidate := by
    exact ⟨candidateAccepted, rfl⟩
  exact
    ⟨domain, watermark, actualCurrent, candidate, declared,
      candidateMatches, contextsDiffer⟩

/--
The authority owns the issuance predicate and proves that every issued
attestation names its actual current checkpoint.
-/
structure LiveCheckpointAttestationAuthority
    (domain : AuthoritativeContextPublicationDomain) where
  currentCheckpoint : AuthorityPublicationCheckpoint domain
  issued : DeclaredCheckpointAttestation domain → Prop
  issuanceSound :
    ∀ {attestation},
      issued attestation →
        attestation.checkpoint.head.context =
          currentCheckpoint.head.context

def authorityIssuedCheckpointCurrentForAdmission
    {domain : AuthoritativeContextPublicationDomain}
    (watermark : TrustedCheckpointWatermark)
    (authority : LiveCheckpointAttestationAuthority domain)
    (attestation : DeclaredCheckpointAttestation domain) : Prop :=
  authority.issued attestation ∧
    checkpointAcceptedByWatermark watermark attestation.checkpoint

theorem authorityIssuedAttestationEstablishesCurrentHead
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {authority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    (attestationAdmitted :
      authorityIssuedCheckpointCurrentForAdmission
        watermark
        authority
        attestation) :
    attestation.checkpoint.head.context =
      authority.currentCheckpoint.head.context :=
  authority.issuanceSound attestationAdmitted.1

theorem authorityIssuedAdmissionRejectsUnissuedAttestation
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {authority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    (notIssued : ¬ authority.issued attestation) :
    ¬ authorityIssuedCheckpointCurrentForAdmission
        watermark
        authority
        attestation := by
  intro attestationAdmitted
  exact notIssued attestationAdmitted.1

end AgenticAILabProof.Enterprise.ReceiptContextCheckpointClosure
