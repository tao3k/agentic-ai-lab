-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.PooC4

structure ControlPlaneHandoffFacts where
  policyReady : Bool
  compositionAccepted : Bool
  graphContractOk : Bool
  runtimeOwnerExternal : Bool
  executionDeferred : Bool
  artifactsDeclared : Bool
deriving Repr, DecidableEq

def controlPlaneHandoffAccepted (facts : ControlPlaneHandoffFacts) : Prop :=
  facts.policyReady = true
    ∧ facts.compositionAccepted = true
    ∧ facts.graphContractOk = true
    ∧ facts.runtimeOwnerExternal = true
    ∧ facts.executionDeferred = true
    ∧ facts.artifactsDeclared = true

theorem controlPlaneHandoffAcceptedByAllOk
    (facts : ControlPlaneHandoffFacts)
    (hpolicy : facts.policyReady = true)
    (hcomposition : facts.compositionAccepted = true)
    (hgraph : facts.graphContractOk = true)
    (howner : facts.runtimeOwnerExternal = true)
    (hdeferred : facts.executionDeferred = true)
    (hartifacts : facts.artifactsDeclared = true) :
    controlPlaneHandoffAccepted facts := by
  unfold controlPlaneHandoffAccepted
  exact ⟨hpolicy, hcomposition, hgraph, howner, hdeferred, hartifacts⟩

theorem controlPlaneHandoffRejectedByPolicy
    (facts : ControlPlaneHandoffFacts)
    (hpolicy : facts.policyReady = false) :
    ¬ controlPlaneHandoffAccepted facts := by
  intro h
  unfold controlPlaneHandoffAccepted at h
  rw [hpolicy] at h
  cases h.left

theorem controlPlaneHandoffRejectedByComposition
    (facts : ControlPlaneHandoffFacts)
    (hcomposition : facts.compositionAccepted = false) :
    ¬ controlPlaneHandoffAccepted facts := by
  intro h
  unfold controlPlaneHandoffAccepted at h
  rw [hcomposition] at h
  cases h.right.left

theorem controlPlaneHandoffRejectedByGraph
    (facts : ControlPlaneHandoffFacts)
    (hgraph : facts.graphContractOk = false) :
    ¬ controlPlaneHandoffAccepted facts := by
  intro h
  unfold controlPlaneHandoffAccepted at h
  rw [hgraph] at h
  cases h.right.right.left

theorem controlPlaneHandoffRejectedByRuntimeOwner
    (facts : ControlPlaneHandoffFacts)
    (howner : facts.runtimeOwnerExternal = false) :
    ¬ controlPlaneHandoffAccepted facts := by
  intro h
  unfold controlPlaneHandoffAccepted at h
  rw [howner] at h
  cases h.right.right.right.left

theorem controlPlaneHandoffRejectedByExecution
    (facts : ControlPlaneHandoffFacts)
    (hdeferred : facts.executionDeferred = false) :
    ¬ controlPlaneHandoffAccepted facts := by
  intro h
  unfold controlPlaneHandoffAccepted at h
  rw [hdeferred] at h
  cases h.right.right.right.right.left

theorem controlPlaneHandoffRejectedByArtifacts
    (facts : ControlPlaneHandoffFacts)
    (hartifacts : facts.artifactsDeclared = false) :
    ¬ controlPlaneHandoffAccepted facts := by
  intro h
  unfold controlPlaneHandoffAccepted at h
  rw [hartifacts] at h
  cases h.right.right.right.right.right

end AgenticAILabProof.PooC4
