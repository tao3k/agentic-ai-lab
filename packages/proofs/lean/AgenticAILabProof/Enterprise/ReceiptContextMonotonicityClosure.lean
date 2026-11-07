-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure

namespace AgenticAILabProof.Enterprise.ReceiptContextMonotonicityClosure

open AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure

/--
A successor context on one authority path must preserve the authority identity
and strictly advance the authority generation.  Strict advancement makes the
generation an anti-ABA fence rather than a mutable version label.
-/
def validAuthorityContextTransition
    (before after : ReceiptValidationContext) : Prop :=
  before.authorityIdentity = after.authorityIdentity ∧
    before.authorityGeneration < after.authorityGeneration

theorem validAuthorityContextTransitionChangesContext
    {before after : ReceiptValidationContext}
    (transitionValid : validAuthorityContextTransition before after) :
    before ≠ after := by
  intro contextsEqual
  have generationsEqual :
      before.authorityGeneration = after.authorityGeneration :=
    congrArg ReceiptValidationContext.authorityGeneration contextsEqual
  exact (Nat.ne_of_lt transitionValid.2) generationsEqual

theorem validTransitionRejectsReceiptIssuedBeforeTransition
    {before after : ReceiptValidationContext}
    {receipt : ContextBoundAuthorityReceipt}
    (acceptedBefore : acceptedAtContext before receipt)
    (transitionValid : validAuthorityContextTransition before after) :
    ¬ acceptedAtContext after receipt :=
  exactContextAcceptanceRejectsChangedContext
    acceptedBefore
    (validAuthorityContextTransitionChangesContext transitionValid)

/--
Countermodel: exact context equality rejects an old receipt while the current
context is different, but accepts it again if the authority publishes the old
context value as current.  Equality alone therefore does not prevent
`C₀ → C₁ → C₀` rollback replay.
-/
theorem exactEqualityAlonePermitsRollbackReplay :
    ∃
      (contextZero contextOne : ReceiptValidationContext)
      (receipt : ContextBoundAuthorityReceipt),
      contextZero ≠ contextOne ∧
        acceptedAtContext contextZero receipt ∧
        ¬ acceptedAtContext contextOne receipt ∧
        acceptedAtContext contextZero receipt := by
  let contextZero : ReceiptValidationContext :=
    {
      authorityIdentity := 61
      authorityGeneration := 5
      policySnapshotIdentity := 67
      authorizationSnapshotIdentity := 71
      revocationSnapshotIdentity := 73
    }
  let contextOne : ReceiptValidationContext :=
    {
      authorityIdentity := 61
      authorityGeneration := 6
      policySnapshotIdentity := 79
      authorizationSnapshotIdentity := 83
      revocationSnapshotIdentity := 89
    }
  let receipt : ContextBoundAuthorityReceipt :=
    {
      issuedContext := contextZero
      ownerAccepted := true
    }
  have contextsDiffer : contextZero ≠ contextOne := by
    decide
  have acceptedAtZero : acceptedAtContext contextZero receipt := by
    exact ⟨rfl, rfl⟩
  refine
    ⟨contextZero, contextOne, receipt, contextsDiffer, acceptedAtZero, ?_,
      acceptedAtZero⟩
  exact
    exactContextAcceptanceRejectsChangedContext
      acceptedAtZero
      contextsDiffer

/--
An authority context lineage is indexed by an authority-owned monotonically
increasing position.  The structure directly records the semantic invariant
needed by receipt validation; it does not derive freshness from wall-clock
time.
-/
structure AuthorityContextLineage where
  authorityIdentity : Nat
  contextAt : Nat → ReceiptValidationContext
  fixedAuthority :
    ∀ position,
      (contextAt position).authorityIdentity = authorityIdentity
  generationStrict :
    ∀ {earlier later},
      earlier < later →
        (contextAt earlier).authorityGeneration <
          (contextAt later).authorityGeneration

theorem authorityContextLineageNeverReusesEarlierContext
    (lineage : AuthorityContextLineage)
    {earlier later : Nat}
    (positionAdvanced : earlier < later) :
    lineage.contextAt earlier ≠ lineage.contextAt later := by
  intro contextsEqual
  have generationsEqual :
      (lineage.contextAt earlier).authorityGeneration =
        (lineage.contextAt later).authorityGeneration :=
    congrArg ReceiptValidationContext.authorityGeneration contextsEqual
  exact
    (Nat.ne_of_lt (lineage.generationStrict positionAdvanced))
      generationsEqual

theorem receiptIssuedAtEarlierLineagePositionIsRejectedLater
    (lineage : AuthorityContextLineage)
    {earlier later : Nat}
    {receipt : ContextBoundAuthorityReceipt}
    (positionAdvanced : earlier < later)
    (acceptedEarlier :
      acceptedAtContext (lineage.contextAt earlier) receipt) :
    ¬ acceptedAtContext (lineage.contextAt later) receipt :=
  exactContextAcceptanceRejectsChangedContext
    acceptedEarlier
    (authorityContextLineageNeverReusesEarlierContext
      lineage
      positionAdvanced)

theorem lineagePositionsShareAuthorityIdentity
    (lineage : AuthorityContextLineage)
    (left right : Nat) :
    (lineage.contextAt left).authorityIdentity =
      (lineage.contextAt right).authorityIdentity := by
  exact (lineage.fixedAuthority left).trans (lineage.fixedAuthority right).symm

/--
Countermodel: transition-local monotonicity does not make publication
single-valued.  Two different contexts can both be valid successors of the
same context while reusing the same next generation.
-/
theorem validTransitionsAlonePermitSameGenerationFork :
    ∃
      (before left right : ReceiptValidationContext),
      left ≠ right ∧
        validAuthorityContextTransition before left ∧
        validAuthorityContextTransition before right ∧
        left.authorityGeneration = right.authorityGeneration := by
  let before : ReceiptValidationContext :=
    {
      authorityIdentity := 97
      authorityGeneration := 10
      policySnapshotIdentity := 101
      authorizationSnapshotIdentity := 103
      revocationSnapshotIdentity := 107
    }
  let left : ReceiptValidationContext :=
    {
      authorityIdentity := 97
      authorityGeneration := 11
      policySnapshotIdentity := 109
      authorizationSnapshotIdentity := 113
      revocationSnapshotIdentity := 127
    }
  let right : ReceiptValidationContext :=
    {
      authorityIdentity := 97
      authorityGeneration := 11
      policySnapshotIdentity := 131
      authorizationSnapshotIdentity := 137
      revocationSnapshotIdentity := 139
    }
  have contextsDiffer : left ≠ right := by
    decide
  have leftValid : validAuthorityContextTransition before left := by
    constructor
    · rfl
    · decide
  have rightValid : validAuthorityContextTransition before right := by
    constructor
    · rfl
    · decide
  refine
    ⟨before, left, right, contextsDiffer, leftValid, rightValid, ?_⟩
  rfl

def ForkFreeContextPublication
    (published : ReceiptValidationContext → Prop) : Prop :=
  ∀ {left right},
    published left →
      published right →
        left.authorityIdentity = right.authorityIdentity →
          left.authorityGeneration = right.authorityGeneration →
            left = right

def publishedByLineage
    (lineage : AuthorityContextLineage)
    (context : ReceiptValidationContext) : Prop :=
  ∃ position, lineage.contextAt position = context

theorem lineagePublicationIsForkFree
    (lineage : AuthorityContextLineage) :
    ForkFreeContextPublication (publishedByLineage lineage) := by
  intro left right leftPublished rightPublished _ generationsEqual
  rcases leftPublished with ⟨leftPosition, leftContext⟩
  rcases rightPublished with ⟨rightPosition, rightContext⟩
  subst left
  subst right
  have positionsEqual : leftPosition = rightPosition := by
    rcases Nat.lt_trichotomy leftPosition rightPosition with
      positionBefore | positionEqual | positionAfter
    · have generationBefore :=
        lineage.generationStrict positionBefore
      exact False.elim ((Nat.ne_of_lt generationBefore) generationsEqual)
    · exact positionEqual
    · have generationAfter :=
        lineage.generationStrict positionAfter
      exact
        False.elim
          ((Nat.ne_of_lt generationAfter) generationsEqual.symm)
  subst rightPosition
  rfl

theorem forkFreePublicationMakesGenerationUnique
    {published : ReceiptValidationContext → Prop}
    (publicationForkFree : ForkFreeContextPublication published)
    {left right : ReceiptValidationContext}
    (leftPublished : published left)
    (rightPublished : published right)
    (sameAuthority :
      left.authorityIdentity = right.authorityIdentity)
    (sameGeneration :
      left.authorityGeneration = right.authorityGeneration) :
    left = right :=
  publicationForkFree
    leftPublished
    rightPublished
    sameAuthority
    sameGeneration

/--
Countermodel: two locally valid monotone lineage views can disagree about the
context published by one authority at the same generation.  Local monotonicity
does not establish cross-view consistency.
-/
theorem individuallyValidLineagesCanDisagreeAtSameGeneration :
    ∃
      (left right : AuthorityContextLineage),
      left.authorityIdentity = right.authorityIdentity ∧
        (left.contextAt 1).authorityGeneration =
          (right.contextAt 1).authorityGeneration ∧
        left.contextAt 1 ≠ right.contextAt 1 := by
  let left : AuthorityContextLineage :=
    {
      authorityIdentity := 149
      contextAt := fun position =>
        {
          authorityIdentity := 149
          authorityGeneration := position
          policySnapshotIdentity := 151
          authorizationSnapshotIdentity := 157
          revocationSnapshotIdentity := 163
        }
      fixedAuthority := by
        intro position
        rfl
      generationStrict := by
        intro earlier later positionAdvanced
        exact positionAdvanced
    }
  let right : AuthorityContextLineage :=
    {
      authorityIdentity := 149
      contextAt := fun position =>
        {
          authorityIdentity := 149
          authorityGeneration := position
          policySnapshotIdentity := 167
          authorizationSnapshotIdentity := 173
          revocationSnapshotIdentity := 179
        }
      fixedAuthority := by
        intro position
        rfl
      generationStrict := by
        intro earlier later positionAdvanced
        exact positionAdvanced
    }
  have contextsDiffer : left.contextAt 1 ≠ right.contextAt 1 := by
    decide
  exact ⟨left, right, rfl, rfl, contextsDiffer⟩

/--
The shared authority-owned publication domain against which a verifier checks
membership evidence.  The structure specifies semantics only; it does not
select a database, log, or consensus implementation.
-/
structure AuthoritativeContextPublicationDomain where
  domainIdentity : Nat
  domainSemanticIdentity : Nat
  authorityIdentity : Nat
  published : ReceiptValidationContext → Prop
  authorityBound :
    ∀ {context},
      published context →
        context.authorityIdentity = authorityIdentity
  forkFree : ForkFreeContextPublication published

structure ContextPublicationMembershipEvidence
    (domain : AuthoritativeContextPublicationDomain) where
  context : ReceiptValidationContext
  member : domain.published context

theorem sharedPublicationDomainRejectsSplitViewEquivocation
    (domain : AuthoritativeContextPublicationDomain)
    (left right : ContextPublicationMembershipEvidence domain)
    (sameGeneration :
      left.context.authorityGeneration =
        right.context.authorityGeneration) :
    left.context = right.context := by
  have sameAuthority :
      left.context.authorityIdentity =
        right.context.authorityIdentity :=
    (domain.authorityBound left.member).trans
      (domain.authorityBound right.member).symm
  exact
    domain.forkFree
      left.member
      right.member
      sameAuthority
      sameGeneration

end AgenticAILabProof.Enterprise.ReceiptContextMonotonicityClosure
