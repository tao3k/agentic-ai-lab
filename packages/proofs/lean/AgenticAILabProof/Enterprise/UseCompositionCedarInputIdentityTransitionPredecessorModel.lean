-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityGenerationTransitionModel

namespace AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityTransitionPredecessorModel

open AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityGenerationTransitionModel

def fabricatedEmptyOldAuthority : IdentityAuthoritySnapshot where
  authorityIdentity := 17
  semanticIdentity := 31
  generation := 2
  digest := fun content => content + 999
  admitted := fun _ => False

def actuallyPublishedGeneration (generation : Nat) : Prop :=
  generation = 3 ∨ generation = 4

def independentClaimedLineageGeneration (position : Nat) : Nat :=
  if position = 0 then 2 else 4

theorem fabricatedEmptyOldMakesCompatibilityVacuous :
    CompatibleIdentityGenerationTransitionClosed
      fabricatedEmptyOldAuthority driftingAuthority := by
  refine
    { authorityStable := rfl
      semanticIdentityStable := rfl
      generationAdvances := by decide
      admissionMonotone := ?_
      projectionStable := ?_ }
  · intro content admitted
    simp [fabricatedEmptyOldAuthority] at admitted
  · intro content admitted
    simp [fabricatedEmptyOldAuthority] at admitted

theorem fabricatedOldBypassesActualPredecessorDigestDrift :
    CompatibleIdentityGenerationTransitionClosed
        fabricatedEmptyOldAuthority driftingAuthority ∧
      oldAuthority.admitted 7 ∧
      oldAuthority.digest 7 ≠ driftingAuthority.digest 7 := by
  exact
    ⟨fabricatedEmptyOldMakesCompatibilityVacuous,
      by simp [oldAuthority],
      by simp [oldAuthority, driftingAuthority]⟩

theorem fabricatedOldIsNotPublishedActualPredecessor :
    fabricatedEmptyOldAuthority.generation ≠ oldAuthority.generation := by
  decide

theorem independentLineageAllowsUnpublishedFabricatedPredecessor :
    independentClaimedLineageGeneration 0 <
        independentClaimedLineageGeneration 1 ∧
      actuallyPublishedGeneration (independentClaimedLineageGeneration 1) ∧
      ¬ actuallyPublishedGeneration
        (independentClaimedLineageGeneration 0) := by
  simp [independentClaimedLineageGeneration, actuallyPublishedGeneration]

end AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityTransitionPredecessorModel
