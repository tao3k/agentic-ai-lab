-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.ReceiptContextMonotonicityClosure

namespace AgenticAILabProof.Enterprise.ReceiptContextLineagePrefixClosure

open AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure
open AgenticAILabProof.Enterprise.ReceiptContextMonotonicityClosure

structure AuthorityContextLineagePrefix where
  lineage : AuthorityContextLineage
  headPosition : Nat

def lineagePrefixAt
    (lineage : AuthorityContextLineage)
    (headPosition : Nat) : AuthorityContextLineagePrefix :=
  { lineage := lineage, headPosition := headPosition }

def publishedByLineagePrefix
    (lineagePrefix : AuthorityContextLineagePrefix)
    (context : ReceiptValidationContext) : Prop :=
  ∃ position,
    position ≤ lineagePrefix.headPosition ∧
      lineagePrefix.lineage.contextAt position = context

theorem lineagePrefixHeadIsPublished
    (lineagePrefix : AuthorityContextLineagePrefix) :
    publishedByLineagePrefix
      lineagePrefix
      (lineagePrefix.lineage.contextAt lineagePrefix.headPosition) :=
  ⟨lineagePrefix.headPosition, Nat.le_refl _, rfl⟩

theorem lineagePositionAtOrBeforeHeadIsPublished
    (lineagePrefix : AuthorityContextLineagePrefix)
    {position : Nat}
    (notAfterHead : position ≤ lineagePrefix.headPosition) :
    publishedByLineagePrefix
      lineagePrefix
      (lineagePrefix.lineage.contextAt position) :=
  ⟨position, notAfterHead, rfl⟩

theorem lineagePositionAfterHeadIsNotPublished
    (lineagePrefix : AuthorityContextLineagePrefix)
    {position : Nat}
    (afterHead : lineagePrefix.headPosition < position) :
    ¬ publishedByLineagePrefix
        lineagePrefix
        (lineagePrefix.lineage.contextAt position) := by
  intro published
  rcases published with ⟨publishedPosition, beforeHead, contextsEqual⟩
  have publishedBeforeFuture : publishedPosition < position :=
    Nat.lt_of_le_of_lt beforeHead afterHead
  exact
    (authorityContextLineageNeverReusesEarlierContext
      lineagePrefix.lineage publishedBeforeFuture)
      contextsEqual

theorem lineagePrefixPublicationIsForkFree
    (lineagePrefix : AuthorityContextLineagePrefix) :
    ForkFreeContextPublication (publishedByLineagePrefix lineagePrefix) := by
  intro left right leftPublished rightPublished sameAuthority sameGeneration
  apply lineagePublicationIsForkFree lineagePrefix.lineage
  · rcases leftPublished with ⟨position, _, contextEqual⟩
    exact ⟨position, contextEqual⟩
  · rcases rightPublished with ⟨position, _, contextEqual⟩
    exact ⟨position, contextEqual⟩
  · exact sameAuthority
  · exact sameGeneration

def AuthorityContextLineagePrefix.toPublicationDomain
    (lineagePrefix : AuthorityContextLineagePrefix)
    (domainIdentity domainSemanticIdentity : Nat) :
    AuthoritativeContextPublicationDomain where
  domainIdentity := domainIdentity
  domainSemanticIdentity := domainSemanticIdentity
  authorityIdentity := lineagePrefix.lineage.authorityIdentity
  published := publishedByLineagePrefix lineagePrefix
  authorityBound := by
    intro context published
    rcases published with ⟨position, _, contextEqual⟩
    rw [← contextEqual]
    exact lineagePrefix.lineage.fixedAuthority position
  forkFree := lineagePrefixPublicationIsForkFree lineagePrefix

structure LineagePrefixPublicationDomainBinding
    (lineagePrefix : AuthorityContextLineagePrefix)
    (domain : AuthoritativeContextPublicationDomain) : Prop where
  authorityIdentityBound :
    domain.authorityIdentity = lineagePrefix.lineage.authorityIdentity
  publishedExact :
    ∀ context,
      domain.published context ↔
        publishedByLineagePrefix lineagePrefix context

theorem boundDomainPublishesPrefixHead
    {lineagePrefix : AuthorityContextLineagePrefix}
    {domain : AuthoritativeContextPublicationDomain}
    (binding :
      LineagePrefixPublicationDomainBinding lineagePrefix domain) :
    domain.published
      (lineagePrefix.lineage.contextAt lineagePrefix.headPosition) :=
  (binding.publishedExact _).2
    (lineagePrefixHeadIsPublished lineagePrefix)

theorem boundDomainRejectsPositionAfterPrefixHead
    {lineagePrefix : AuthorityContextLineagePrefix}
    {domain : AuthoritativeContextPublicationDomain}
    (binding :
      LineagePrefixPublicationDomainBinding lineagePrefix domain)
    {position : Nat}
    (afterHead : lineagePrefix.headPosition < position) :
    ¬ domain.published (lineagePrefix.lineage.contextAt position) := by
  intro domainPublished
  exact
    (lineagePositionAfterHeadIsNotPublished lineagePrefix afterHead)
      ((binding.publishedExact _).1 domainPublished)

end AgenticAILabProof.Enterprise.ReceiptContextLineagePrefixClosure
