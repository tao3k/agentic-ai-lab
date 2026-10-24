-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.PooC4

structure ProofGateBundleFacts where
  compositionAccepted : Bool
  scenarioAccepted : Bool
  handoffAccepted : Bool
  runtimeBoundaryOk : Bool
deriving Repr, DecidableEq

def proofGateBundleAccepted (facts : ProofGateBundleFacts) : Prop :=
  facts.compositionAccepted = true
    ∧ facts.scenarioAccepted = true
    ∧ facts.handoffAccepted = true
    ∧ facts.runtimeBoundaryOk = true

theorem proofGateBundleAcceptedByAllOk
    (facts : ProofGateBundleFacts)
    (hcomposition : facts.compositionAccepted = true)
    (hscenario : facts.scenarioAccepted = true)
    (hhandoff : facts.handoffAccepted = true)
    (hruntime : facts.runtimeBoundaryOk = true) :
    proofGateBundleAccepted facts := by
  unfold proofGateBundleAccepted
  exact ⟨hcomposition, hscenario, hhandoff, hruntime⟩

theorem proofGateBundleRejectedByComposition
    (facts : ProofGateBundleFacts)
    (hcomposition : facts.compositionAccepted = false) :
    ¬ proofGateBundleAccepted facts := by
  intro h
  unfold proofGateBundleAccepted at h
  rw [hcomposition] at h
  cases h.left

theorem proofGateBundleRejectedByScenario
    (facts : ProofGateBundleFacts)
    (hscenario : facts.scenarioAccepted = false) :
    ¬ proofGateBundleAccepted facts := by
  intro h
  unfold proofGateBundleAccepted at h
  rw [hscenario] at h
  cases h.right.left

theorem proofGateBundleRejectedByHandoff
    (facts : ProofGateBundleFacts)
    (hhandoff : facts.handoffAccepted = false) :
    ¬ proofGateBundleAccepted facts := by
  intro h
  unfold proofGateBundleAccepted at h
  rw [hhandoff] at h
  cases h.right.right.left

theorem proofGateBundleRejectedByRuntimeBoundary
    (facts : ProofGateBundleFacts)
    (hruntime : facts.runtimeBoundaryOk = false) :
    ¬ proofGateBundleAccepted facts := by
  intro h
  unfold proofGateBundleAccepted at h
  rw [hruntime] at h
  cases h.right.right.right

end AgenticAILabProof.PooC4
