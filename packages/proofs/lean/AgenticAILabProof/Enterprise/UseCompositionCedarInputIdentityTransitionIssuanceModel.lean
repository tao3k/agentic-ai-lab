-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityGenerationTransitionModel

namespace AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityTransitionIssuanceModel

open AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityGenerationTransitionModel

structure IdentityTransitionClaim where
  issuerIdentity : Nat
  oldSemanticIdentity : Nat
  currentSemanticIdentity : Nat
  oldGeneration : Nat
  currentGeneration : Nat
  deriving DecidableEq, Repr

def selfReportedTransitionAccepted
    (old current : IdentityAuthoritySnapshot)
    (claim : IdentityTransitionClaim) : Prop :=
  legacySameSemanticTransition old current ∧
    claim.oldSemanticIdentity = old.semanticIdentity ∧
    claim.currentSemanticIdentity = current.semanticIdentity ∧
    claim.oldGeneration = old.generation ∧
    claim.currentGeneration = current.generation

def issuerOnlyTransitionAccepted
    (trustedIssuer : Nat)
    (old current : IdentityAuthoritySnapshot)
    (claim : IdentityTransitionClaim) : Prop :=
  claim.issuerIdentity = trustedIssuer ∧
    selfReportedTransitionAccepted old current claim

def compatibleGenerationFour : IdentityAuthoritySnapshot where
  authorityIdentity := 17
  semanticIdentity := 31
  generation := 4
  digest := fun content => content + 100
  admitted := fun content => content = 7

def compatibleGenerationFive : IdentityAuthoritySnapshot where
  authorityIdentity := 17
  semanticIdentity := 31
  generation := 5
  digest := fun content => content + 100
  admitted := fun content => content = 7

def counterfeitTransitionClaim : IdentityTransitionClaim where
  issuerIdentity := 999
  oldSemanticIdentity := 31
  currentSemanticIdentity := 31
  oldGeneration := 3
  currentGeneration := 4

def authorityIssuedButNonCurrentClaim : IdentityTransitionClaim where
  issuerIdentity := 17
  oldSemanticIdentity := 31
  currentSemanticIdentity := 31
  oldGeneration := 3
  currentGeneration := 4

theorem oldToGenerationFourCompatible :
    CompatibleIdentityGenerationTransitionClosed
      oldAuthority compatibleGenerationFour := by
  refine
    { authorityStable := rfl
      semanticIdentityStable := rfl
      generationAdvances := by decide
      admissionMonotone := ?_
      projectionStable := ?_ }
  · intro content admitted
    simpa [oldAuthority, compatibleGenerationFour] using admitted
  · intro content _
    rfl

theorem selfReportedAcceptanceAllowsCounterfeitIssuer :
    selfReportedTransitionAccepted
        oldAuthority compatibleGenerationFour counterfeitTransitionClaim ∧
      counterfeitTransitionClaim.issuerIdentity ≠ oldAuthority.authorityIdentity := by
  simp [selfReportedTransitionAccepted, legacySameSemanticTransition,
    oldAuthority, compatibleGenerationFour, counterfeitTransitionClaim]

theorem issuerOnlyAcceptanceAllowsNonCurrentHead :
    issuerOnlyTransitionAccepted
        oldAuthority.authorityIdentity
        oldAuthority
        compatibleGenerationFour
        authorityIssuedButNonCurrentClaim ∧
      authorityIssuedButNonCurrentClaim.currentGeneration ≠
        compatibleGenerationFive.generation := by
  simp [issuerOnlyTransitionAccepted, selfReportedTransitionAccepted,
    legacySameSemanticTransition, oldAuthority, compatibleGenerationFour,
    compatibleGenerationFive, authorityIssuedButNonCurrentClaim]

theorem compatibleTransitionStillRequiresIndependentIssuance :
    CompatibleIdentityGenerationTransitionClosed
        oldAuthority compatibleGenerationFour ∧
      counterfeitTransitionClaim.issuerIdentity ≠ oldAuthority.authorityIdentity :=
  ⟨oldToGenerationFourCompatible, by decide⟩

end AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityTransitionIssuanceModel
