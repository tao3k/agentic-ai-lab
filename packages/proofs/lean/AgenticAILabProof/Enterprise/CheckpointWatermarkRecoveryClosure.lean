-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.ReceiptContextCheckpointClosure

namespace AgenticAILabProof.Enterprise.CheckpointWatermarkRecoveryClosure

open AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure
open AgenticAILabProof.Enterprise.ReceiptContextMonotonicityClosure
open AgenticAILabProof.Enterprise.ReceiptContextCheckpointClosure

def validCheckpointWatermarkRecovery
    (committed recovered : TrustedCheckpointWatermark) : Prop :=
  committed.publicationDomainIdentity =
      recovered.publicationDomainIdentity ∧
    committed.authorityIdentity = recovered.authorityIdentity ∧
      committed.minimumGeneration ≤ recovered.minimumGeneration

theorem validRecoveryPreservesPublicationDomain
    {committed recovered : TrustedCheckpointWatermark}
    (recoveryValid :
      validCheckpointWatermarkRecovery committed recovered) :
    committed.publicationDomainIdentity =
      recovered.publicationDomainIdentity :=
  recoveryValid.1

theorem validRecoveryPreservesAuthorityIdentity
    {committed recovered : TrustedCheckpointWatermark}
    (recoveryValid :
      validCheckpointWatermarkRecovery committed recovered) :
    committed.authorityIdentity = recovered.authorityIdentity :=
  recoveryValid.2.1

theorem validRecoveryNeverLowersGeneration
    {committed recovered : TrustedCheckpointWatermark}
    (recoveryValid :
      validCheckpointWatermarkRecovery committed recovered) :
    committed.minimumGeneration ≤ recovered.minimumGeneration :=
  recoveryValid.2.2

/--
Countermodel: a volatile reset to generation zero accepts a checkpoint that the
previously committed watermark rejected as a known rollback.
-/
theorem volatileWatermarkResetPermitsKnownRollback :
    ∃
      (domain : AuthoritativeContextPublicationDomain)
      (candidate : AuthorityPublicationCheckpoint domain)
      (committed reset : TrustedCheckpointWatermark),
      ¬ checkpointAcceptedByWatermark committed candidate ∧
        checkpointAcceptedByWatermark reset candidate := by
  rcases historicalMembershipDoesNotEstablishCurrentHead with
    ⟨domain, historical, _, _⟩
  let candidate : AuthorityPublicationCheckpoint domain :=
    { head := historical }
  let committed : TrustedCheckpointWatermark :=
    {
      publicationDomainIdentity := domain.domainIdentity
      authorityIdentity := historical.context.authorityIdentity
      minimumGeneration := historical.context.authorityGeneration + 1
    }
  let reset : TrustedCheckpointWatermark :=
    {
      publicationDomainIdentity := domain.domainIdentity
      authorityIdentity := historical.context.authorityIdentity
      minimumGeneration := 0
    }
  have rejectedBeforeRestart :
      ¬ checkpointAcceptedByWatermark committed candidate := by
    apply watermarkRejectsKnownCheckpointRollback
    exact Nat.lt_succ_self _
  have acceptedAfterReset :
      checkpointAcceptedByWatermark reset candidate := by
    exact ⟨rfl, rfl, Nat.zero_le _⟩
  exact
    ⟨domain, candidate, committed, reset, rejectedBeforeRestart,
      acceptedAfterReset⟩

theorem validRecoveryRejectsEveryPreviouslyKnownRollback
    {domain : AuthoritativeContextPublicationDomain}
    {candidate : AuthorityPublicationCheckpoint domain}
    {committed recovered : TrustedCheckpointWatermark}
    (knownRollback :
      candidate.head.context.authorityGeneration <
        committed.minimumGeneration)
    (recoveryValid :
      validCheckpointWatermarkRecovery committed recovered) :
    ¬ checkpointAcceptedByWatermark recovered candidate := by
  apply watermarkRejectsKnownCheckpointRollback
  exact
    Nat.lt_of_lt_of_le
      knownRollback
      (validRecoveryNeverLowersGeneration recoveryValid)

/--
Recovery evidence records both the committed and recovered watermark together
with the proof that recovery preserved domain, authority, and monotonic
generation.
-/
structure CheckpointWatermarkRecoveryEvidence where
  committed : TrustedCheckpointWatermark
  recovered : TrustedCheckpointWatermark
  recoveryValid :
    validCheckpointWatermarkRecovery committed recovered

theorem recoveryEvidenceRejectsKnownRollback
    {domain : AuthoritativeContextPublicationDomain}
    {candidate : AuthorityPublicationCheckpoint domain}
    (evidence : CheckpointWatermarkRecoveryEvidence)
    (knownRollback :
      candidate.head.context.authorityGeneration <
        evidence.committed.minimumGeneration) :
    ¬ checkpointAcceptedByWatermark evidence.recovered candidate :=
  validRecoveryRejectsEveryPreviouslyKnownRollback
    knownRollback
    evidence.recoveryValid

/--
Countermodel: internally valid recovery evidence can claim both its committed
and recovered watermark are low while the actual durable committed watermark
is higher.  Monotonicity relative to a self-reported committed value does not
establish durable recovery.
-/
theorem selfReportedCommittedWatermarkCanHideDurableHighWatermark :
    ∃
      (domain : AuthoritativeContextPublicationDomain)
      (candidate : AuthorityPublicationCheckpoint domain)
      (actualCommitted : TrustedCheckpointWatermark)
      (evidence : CheckpointWatermarkRecoveryEvidence),
      evidence.committed ≠ actualCommitted ∧
        ¬ checkpointAcceptedByWatermark actualCommitted candidate ∧
        checkpointAcceptedByWatermark evidence.recovered candidate := by
  rcases historicalMembershipDoesNotEstablishCurrentHead with
    ⟨domain, historical, _, _⟩
  let candidate : AuthorityPublicationCheckpoint domain :=
    { head := historical }
  let actualCommitted : TrustedCheckpointWatermark :=
    {
      publicationDomainIdentity := domain.domainIdentity
      authorityIdentity := historical.context.authorityIdentity
      minimumGeneration := historical.context.authorityGeneration + 1
    }
  let claimedCommitted : TrustedCheckpointWatermark :=
    {
      publicationDomainIdentity := domain.domainIdentity
      authorityIdentity := historical.context.authorityIdentity
      minimumGeneration := 0
    }
  let recovered : TrustedCheckpointWatermark := claimedCommitted
  let evidence : CheckpointWatermarkRecoveryEvidence :=
    {
      committed := claimedCommitted
      recovered := recovered
      recoveryValid := ⟨rfl, rfl, Nat.le_refl _⟩
    }
  have committedValuesDiffer : evidence.committed ≠ actualCommitted := by
    intro watermarksEqual
    have generationsEqual :
        evidence.committed.minimumGeneration =
          actualCommitted.minimumGeneration :=
      congrArg TrustedCheckpointWatermark.minimumGeneration watermarksEqual
    simp
      [evidence, claimedCommitted, actualCommitted]
      at generationsEqual
  have actualRejects :
      ¬ checkpointAcceptedByWatermark actualCommitted candidate := by
    apply watermarkRejectsKnownCheckpointRollback
    exact Nat.lt_succ_self _
  have recoveredAccepts :
      checkpointAcceptedByWatermark evidence.recovered candidate := by
    exact ⟨rfl, rfl, Nat.zero_le _⟩
  exact
    ⟨domain, candidate, actualCommitted, evidence, committedValuesDiffer,
      actualRejects, recoveredAccepts⟩

/--
The durable recovery authority owns the actual committed watermark and the
issuance predicate for recovery evidence.
-/
structure DurableWatermarkRecoveryAuthority where
  committedWatermark : TrustedCheckpointWatermark
  issued : CheckpointWatermarkRecoveryEvidence → Prop
  issuanceSound :
    ∀ {evidence},
      issued evidence →
        evidence.committed = committedWatermark

theorem authorityIssuedRecoveryBindsDurableCommittedWatermark
    (authority : DurableWatermarkRecoveryAuthority)
    {evidence : CheckpointWatermarkRecoveryEvidence}
    (issued : authority.issued evidence) :
    evidence.committed = authority.committedWatermark :=
  authority.issuanceSound issued

theorem authorityIssuedRecoveryRejectsDurablyKnownRollback
    {domain : AuthoritativeContextPublicationDomain}
    {candidate : AuthorityPublicationCheckpoint domain}
    (authority : DurableWatermarkRecoveryAuthority)
    {evidence : CheckpointWatermarkRecoveryEvidence}
    (issued : authority.issued evidence)
    (durablyKnownRollback :
      candidate.head.context.authorityGeneration <
        authority.committedWatermark.minimumGeneration) :
    ¬ checkpointAcceptedByWatermark evidence.recovered candidate := by
  have knownAgainstEvidence :
      candidate.head.context.authorityGeneration <
        evidence.committed.minimumGeneration := by
    rw [authority.issuanceSound issued]
    exact durablyKnownRollback
  exact
    validRecoveryRejectsEveryPreviouslyKnownRollback
      knownAgainstEvidence
      evidence.recoveryValid

inductive DurableWatermarkRecoveryOutcome
    (authority : DurableWatermarkRecoveryAuthority) where
  | recovered
      (evidence : CheckpointWatermarkRecoveryEvidence)
      (issued : authority.issued evidence)
  | indeterminate

def checkpointAcceptedAfterDurableRecovery
    {domain : AuthoritativeContextPublicationDomain}
    {authority : DurableWatermarkRecoveryAuthority}
    (outcome : DurableWatermarkRecoveryOutcome authority)
    (candidate : AuthorityPublicationCheckpoint domain) : Prop :=
  match outcome with
  | .recovered evidence _ =>
      checkpointAcceptedByWatermark evidence.recovered candidate
  | .indeterminate => False

theorem indeterminateRecoveryCannotAdmitCheckpoint
    {domain : AuthoritativeContextPublicationDomain}
    {authority : DurableWatermarkRecoveryAuthority}
    (candidate : AuthorityPublicationCheckpoint domain) :
    ¬ checkpointAcceptedAfterDurableRecovery
        (.indeterminate : DurableWatermarkRecoveryOutcome authority)
        candidate := by
  intro accepted
  exact accepted

/--
A pure descriptor carries the canonical identity inputs needed to distinguish
publication-domain semantics from an operational predicate implementation.
-/
structure PublicationDomainDescriptor where
  domainIdentity : Nat
  authorityIdentity : Nat
  semanticIdentity : Nat
  deriving DecidableEq

def publicationDomainDescriptor
    (domain : AuthoritativeContextPublicationDomain) :
    PublicationDomainDescriptor :=
  {
    domainIdentity := domain.domainIdentity
    authorityIdentity := domain.authorityIdentity
    semanticIdentity := domain.domainSemanticIdentity
  }

/--
Countermodel: equality of an ungoverned identifier does not establish equality
of domain descriptors.
-/
theorem domainIdentityEqualityAloneDoesNotEstablishDescriptorEquality :
    ∃
      (left right : PublicationDomainDescriptor),
      left.domainIdentity = right.domainIdentity ∧ left ≠ right := by
  let left : PublicationDomainDescriptor :=
    {
      domainIdentity := 229
      authorityIdentity := 233
      semanticIdentity := 239
    }
  let right : PublicationDomainDescriptor :=
    {
      domainIdentity := 229
      authorityIdentity := 233
      semanticIdentity := 241
    }
  have descriptorsDiffer : left ≠ right := by
    decide
  exact ⟨left, right, rfl, descriptorsDiffer⟩

structure PublicationDomainIdentityRegistry where
  registered : PublicationDomainDescriptor → Prop
  identityInjective :
    ∀ {left right},
      registered left →
        registered right →
          left.domainIdentity = right.domainIdentity →
            left = right

theorem registeredDomainIdentityDeterminesDescriptor
    (registry : PublicationDomainIdentityRegistry)
    {left right : PublicationDomainDescriptor}
    (leftRegistered : registry.registered left)
    (rightRegistered : registry.registered right)
    (sameIdentity : left.domainIdentity = right.domainIdentity) :
    left = right :=
  registry.identityInjective
    leftRegistered
    rightRegistered
    sameIdentity

structure RegisteredCheckpointWatermarkEvidence
    (registry : PublicationDomainIdentityRegistry) where
  watermark : TrustedCheckpointWatermark
  domainDescriptor : PublicationDomainDescriptor
  descriptorRegistered : registry.registered domainDescriptor
  identityMatches :
    domainDescriptor.domainIdentity =
      watermark.publicationDomainIdentity
  authorityMatches :
    domainDescriptor.authorityIdentity =
      watermark.authorityIdentity

/--
The closed v1 evidence binds a registered watermark descriptor to the exact
publication domain whose semantics the verifier intends to execute.  Keeping
the domain value explicit prevents a registered descriptor with the same
domain and authority identities but different publication semantics from being
substituted at the checkpoint boundary.
-/
structure PublicationDomainBoundRegisteredCheckpointWatermarkEvidence
    (registry : PublicationDomainIdentityRegistry)
    (domain : AuthoritativeContextPublicationDomain) where
  registeredEvidence : RegisteredCheckpointWatermarkEvidence registry
  descriptorMatchesDomain :
    registeredEvidence.domainDescriptor = publicationDomainDescriptor domain

def domainIdentityOnlyRegisteredWatermarkEvidence
    (registry : PublicationDomainIdentityRegistry)
    (watermark : TrustedCheckpointWatermark)
    (domainDescriptor : PublicationDomainDescriptor) : Prop :=
  registry.registered domainDescriptor ∧
    domainDescriptor.domainIdentity =
      watermark.publicationDomainIdentity

theorem domainIdentityOnlyRegistrationPermitsAuthoritySubstitution :
    ∃ (registry : PublicationDomainIdentityRegistry)
      (domainDescriptor : PublicationDomainDescriptor)
      (watermark : TrustedCheckpointWatermark),
      domainIdentityOnlyRegisteredWatermarkEvidence
          registry watermark domainDescriptor ∧
        domainDescriptor.authorityIdentity ≠ watermark.authorityIdentity := by
  let domainDescriptor : PublicationDomainDescriptor := {
    domainIdentity := 251
    authorityIdentity := 257
    semanticIdentity := 263
  }
  let registry : PublicationDomainIdentityRegistry := {
    registered := fun candidate => candidate = domainDescriptor
    identityInjective := by
      intro left right leftRegistered rightRegistered _
      exact leftRegistered.trans rightRegistered.symm
  }
  let watermark : TrustedCheckpointWatermark := {
    publicationDomainIdentity := domainDescriptor.domainIdentity
    authorityIdentity := 269
    minimumGeneration := 1
  }
  refine ⟨registry, domainDescriptor, watermark, ?_, by decide⟩
  constructor
  · rfl
  · rfl

theorem registeredCheckpointWatermarkBindsAuthority
    {registry : PublicationDomainIdentityRegistry}
    (evidence : RegisteredCheckpointWatermarkEvidence registry) :
    evidence.domainDescriptor.authorityIdentity =
      evidence.watermark.authorityIdentity :=
  evidence.authorityMatches

theorem registeredCheckpointWatermarkPermitsDomainSemanticSubstitution :
    ∃ (registry : PublicationDomainIdentityRegistry)
      (domain : AuthoritativeContextPublicationDomain),
      ∃ evidence : RegisteredCheckpointWatermarkEvidence registry,
        evidence.domainDescriptor.domainIdentity = domain.domainIdentity ∧
          evidence.domainDescriptor.authorityIdentity = domain.authorityIdentity ∧
            evidence.domainDescriptor.semanticIdentity ≠
              domain.domainSemanticIdentity := by
  let domain : AuthoritativeContextPublicationDomain := {
    domainIdentity := 271
    domainSemanticIdentity := 277
    authorityIdentity := 283
    published := fun _ => False
    authorityBound := by
      intro context contextPublished
      contradiction
    forkFree := by
      intro left right leftPublished
      contradiction
  }
  let descriptor : PublicationDomainDescriptor := {
    domainIdentity := 271
    authorityIdentity := 283
    semanticIdentity := 281
  }
  let registry : PublicationDomainIdentityRegistry := {
    registered := fun candidate => candidate = descriptor
    identityInjective := by
      intro left right leftRegistered rightRegistered _
      exact leftRegistered.trans rightRegistered.symm
  }
  let watermark : TrustedCheckpointWatermark := {
    publicationDomainIdentity := 271
    authorityIdentity := 283
    minimumGeneration := 1
  }
  let evidence : RegisteredCheckpointWatermarkEvidence registry := {
    watermark := watermark
    domainDescriptor := descriptor
    descriptorRegistered := by rfl
    identityMatches := by rfl
    authorityMatches := by rfl
  }
  refine ⟨registry, domain, evidence, ?_, ?_, ?_⟩
  · rfl
  · rfl
  · decide

theorem publicationDomainBoundWatermarkBindsSemanticIdentity
    {registry : PublicationDomainIdentityRegistry}
    {domain : AuthoritativeContextPublicationDomain}
    (evidence :
      PublicationDomainBoundRegisteredCheckpointWatermarkEvidence
        registry domain) :
    evidence.registeredEvidence.domainDescriptor.semanticIdentity =
      domain.domainSemanticIdentity := by
  have descriptorEquality :=
    congrArg
      (fun descriptor : PublicationDomainDescriptor => descriptor.semanticIdentity)
      evidence.descriptorMatchesDomain
  simpa [publicationDomainDescriptor] using descriptorEquality

theorem mismatchedPublicationDomainSemanticIdentityCannotBind
    {registry : PublicationDomainIdentityRegistry}
    {domain : AuthoritativeContextPublicationDomain}
    (evidence :
      PublicationDomainBoundRegisteredCheckpointWatermarkEvidence
        registry domain)
    (semanticIdentityMismatch :
      evidence.registeredEvidence.domainDescriptor.semanticIdentity ≠
        domain.domainSemanticIdentity) : False :=
  semanticIdentityMismatch
    (publicationDomainBoundWatermarkBindsSemanticIdentity evidence)

theorem registeredWatermarksWithSameDomainIdentityShareDescriptor
    (registry : PublicationDomainIdentityRegistry)
    (left right : RegisteredCheckpointWatermarkEvidence registry)
    (sameWatermarkDomainIdentity :
      left.watermark.publicationDomainIdentity =
        right.watermark.publicationDomainIdentity) :
    left.domainDescriptor = right.domainDescriptor := by
  apply
    registeredDomainIdentityDeterminesDescriptor
      registry
      left.descriptorRegistered
      right.descriptorRegistered
  exact
    left.identityMatches.trans
      (sameWatermarkDomainIdentity.trans right.identityMatches.symm)

end AgenticAILabProof.Enterprise.CheckpointWatermarkRecoveryClosure
