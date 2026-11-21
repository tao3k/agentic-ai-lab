-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.UserInterfaceProfileLibrary

namespace AgenticAILabProof.PooC4.UserInterfaceProfileSet

/-!
User-interface profile sets are a reusable policy library surface.

The Scheme side contributes POO profile objects and POO gate receipts. This
Lean module states the mathematical contract that makes a profile-set reusable:
membership, benchmark coverage, test receipts, proof receipts, dependency
closure, scope containment, observability cleanliness, and rejected
counterexamples must all agree before a public profile enters the reusable
library surface.
-/

universe u

structure ProfileSetPolicyFacts (Profile : Type u) where
  inProfileSet : Profile -> Prop
  defaultProfile : Profile
  publicProfile : Profile -> Prop
  experimentalProfile : Profile -> Prop
  acceptedGate : Profile -> Prop
  reusableGate : Profile -> Prop
  scenarioCovered : Profile -> Prop
  benchmarkPresent : Profile -> Prop
  tested : Profile -> Prop
  receiptPresent : Profile -> Prop
  obligationMapped : Profile -> Prop
  proofReceiptPresent : Profile -> Prop
  proofKnown : Profile -> Prop
  proofDischarged : Profile -> Prop
  dependencyClosed : Profile -> Prop
  scopeContained : Profile -> Prop
  observabilityClean : Profile -> Prop
  counterexampleRejected : Profile -> Prop
  dependsOn : Profile -> Profile -> Prop

structure AcceptedGateEvidence
    {Profile : Type u}
    (facts : ProfileSetPolicyFacts Profile)
    (profile : Profile) : Prop where
  tested : facts.tested profile
  scenarioCovered : facts.scenarioCovered profile
  benchmarkPresent : facts.benchmarkPresent profile
  receiptPresent : facts.receiptPresent profile
  obligationMapped : facts.obligationMapped profile
  proofReceiptPresent : facts.proofReceiptPresent profile
  proofKnown : facts.proofKnown profile
  proofDischarged : facts.proofDischarged profile
  dependencyClosed : facts.dependencyClosed profile
  scopeContained : facts.scopeContained profile
  observabilityClean : facts.observabilityClean profile
  counterexampleRejected : facts.counterexampleRejected profile

structure ReusableProfileSet
    {Profile : Type u}
    (facts : ProfileSetPolicyFacts Profile) : Prop where
  defaultInSet : facts.inProfileSet facts.defaultProfile
  gateCoverage :
    forall profile,
      facts.inProfileSet profile ->
        facts.scenarioCovered profile /\
        facts.benchmarkPresent profile /\
        facts.tested profile /\
        facts.receiptPresent profile
  acceptedGateSound :
    forall profile,
      facts.inProfileSet profile ->
        facts.acceptedGate profile ->
          AcceptedGateEvidence facts profile
  publicGateReuse :
    forall profile,
      facts.inProfileSet profile ->
        facts.publicProfile profile ->
          facts.acceptedGate profile ->
            facts.reusableGate profile
  experimentalExcluded :
    forall profile,
      facts.inProfileSet profile ->
        facts.experimentalProfile profile ->
          Not (facts.reusableGate profile)
  publicExperimentalDisjoint :
    forall profile,
      facts.inProfileSet profile ->
        facts.publicProfile profile ->
          Not (facts.experimentalProfile profile)
  dependencySound :
    forall profile dependency,
      facts.inProfileSet profile ->
        facts.dependsOn profile dependency ->
          facts.inProfileSet dependency /\ facts.reusableGate dependency

theorem reusable_profile_set_default_gate_is_covered
    {Profile : Type u}
    {facts : ProfileSetPolicyFacts Profile}
    (h : ReusableProfileSet facts) :
    facts.inProfileSet facts.defaultProfile /\
      facts.scenarioCovered facts.defaultProfile /\
      facts.benchmarkPresent facts.defaultProfile /\
      facts.tested facts.defaultProfile /\
      facts.receiptPresent facts.defaultProfile := by
  exact And.intro h.defaultInSet
    (h.gateCoverage facts.defaultProfile h.defaultInSet)

theorem accepted_public_profile_has_complete_reusable_gate
    {Profile : Type u}
    {facts : ProfileSetPolicyFacts Profile}
    (h : ReusableProfileSet facts)
    {profile : Profile}
    (hin : facts.inProfileSet profile)
    (hpublic : facts.publicProfile profile)
    (haccepted : facts.acceptedGate profile) :
    facts.proofDischarged profile /\
      facts.scopeContained profile /\
      facts.dependencyClosed profile /\
      facts.observabilityClean profile /\
      facts.counterexampleRejected profile /\
      facts.reusableGate profile := by
  have hsound := h.acceptedGateSound profile hin haccepted
  exact And.intro hsound.proofDischarged
    (And.intro hsound.scopeContained
      (And.intro hsound.dependencyClosed
        (And.intro hsound.observabilityClean
          (And.intro hsound.counterexampleRejected
            (h.publicGateReuse profile hin hpublic haccepted)))))

theorem accepted_profile_without_scope_containment_is_contradictory
    {Profile : Type u}
    {facts : ProfileSetPolicyFacts Profile}
    (h : ReusableProfileSet facts)
    {profile : Profile}
    (hin : facts.inProfileSet profile)
    (haccepted : facts.acceptedGate profile)
    (hnotScope : Not (facts.scopeContained profile)) :
    False := by
  have hsound := h.acceptedGateSound profile hin haccepted
  exact hnotScope hsound.scopeContained

theorem accepted_profile_with_unrejected_counterexample_is_contradictory
    {Profile : Type u}
    {facts : ProfileSetPolicyFacts Profile}
    (h : ReusableProfileSet facts)
    {profile : Profile}
    (hin : facts.inProfileSet profile)
    (haccepted : facts.acceptedGate profile)
    (hcounterexampleOpen : Not (facts.counterexampleRejected profile)) :
    False := by
  have hsound := h.acceptedGateSound profile hin haccepted
  exact hcounterexampleOpen hsound.counterexampleRejected

theorem experimental_profile_is_not_public_reusable_surface
    {Profile : Type u}
    {facts : ProfileSetPolicyFacts Profile}
    (h : ReusableProfileSet facts)
    {profile : Profile}
    (hin : facts.inProfileSet profile)
    (hexperimental : facts.experimentalProfile profile) :
    Not (facts.reusableGate profile) := by
  exact h.experimentalExcluded profile hin hexperimental

theorem public_profile_is_not_experimental_branch
    {Profile : Type u}
    {facts : ProfileSetPolicyFacts Profile}
    (h : ReusableProfileSet facts)
    {profile : Profile}
    (hin : facts.inProfileSet profile)
    (hpublic : facts.publicProfile profile) :
    Not (facts.experimentalProfile profile) := by
  exact h.publicExperimentalDisjoint profile hin hpublic

theorem profile_dependency_is_available_before_reuse
    {Profile : Type u}
    {facts : ProfileSetPolicyFacts Profile}
    (h : ReusableProfileSet facts)
    {profile dependency : Profile}
    (hin : facts.inProfileSet profile)
    (hdep : facts.dependsOn profile dependency) :
    facts.inProfileSet dependency /\ facts.reusableGate dependency := by
  exact h.dependencySound profile dependency hin hdep

end AgenticAILabProof.PooC4.UserInterfaceProfileSet
