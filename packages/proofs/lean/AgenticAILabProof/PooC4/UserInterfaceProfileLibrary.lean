-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.PooC4.UserInterfaceProfileLibrary

inductive ProfileStatus where
  | publicProfile
  | experimental
  | rejected
deriving Repr, DecidableEq

inductive ProofStatus where
  | discharged
  | openProof
  | experimental
  | rejected
deriving Repr, DecidableEq

structure ProfileGateFacts where
  publicProfile : Prop
  tested : Prop
  hasScenario : Prop
  hasFactProjection : Prop
  mappedToLeanObligations : Prop
  proofStatusKnown : Prop
  dischargedRequiredObligations : Prop
  reusableLibrarySurface : Prop
  experimental : Prop

structure ProfileGateFacts.PublicProfile (facts : ProfileGateFacts) : Prop where
  publicProfile : facts.publicProfile
  tested : facts.tested
  hasScenario : facts.hasScenario
  hasFactProjection : facts.hasFactProjection
  mappedToLeanObligations : facts.mappedToLeanObligations
  proofStatusKnown : facts.proofStatusKnown

structure ProfileGateFacts.ReusableLibrarySurface
    (facts : ProfileGateFacts) : Prop where
  publicProfile : facts.publicProfile
  tested : facts.tested
  hasScenario : facts.hasScenario
  hasFactProjection : facts.hasFactProjection
  mappedToLeanObligations : facts.mappedToLeanObligations
  proofStatusKnown : facts.proofStatusKnown
  dischargedRequiredObligations :
    facts.dischargedRequiredObligations
  reusableLibrarySurface : facts.reusableLibrarySurface

theorem reusable_profile_is_tested
    {facts : ProfileGateFacts}
    (surface : facts.ReusableLibrarySurface) :
    facts.tested :=
  surface.tested

theorem reusable_profile_has_scenario
    {facts : ProfileGateFacts}
    (surface : facts.ReusableLibrarySurface) :
    facts.hasScenario :=
  surface.hasScenario

theorem reusable_profile_has_fact_projection
    {facts : ProfileGateFacts}
    (surface : facts.ReusableLibrarySurface) :
    facts.hasFactProjection :=
  surface.hasFactProjection

theorem reusable_profile_is_mapped_to_lean_obligations
    {facts : ProfileGateFacts}
    (surface : facts.ReusableLibrarySurface) :
    facts.mappedToLeanObligations :=
  surface.mappedToLeanObligations

theorem reusable_profile_proof_status_known
    {facts : ProfileGateFacts}
    (surface : facts.ReusableLibrarySurface) :
    facts.proofStatusKnown :=
  surface.proofStatusKnown

theorem reusable_profile_required_obligations_discharged
    {facts : ProfileGateFacts}
    (surface : facts.ReusableLibrarySurface) :
    facts.dischargedRequiredObligations :=
  surface.dischargedRequiredObligations

theorem experimental_profile_not_public_reusable
    {facts : ProfileGateFacts}
    (_experimental : facts.experimental)
    (notPublic : ¬ facts.publicProfile) :
    ¬ facts.ReusableLibrarySurface := by
  intro surface
  exact notPublic surface.publicProfile

theorem public_profile_requires_known_proof_status
    {facts : ProfileGateFacts}
    (publicProfile : facts.PublicProfile) :
    facts.proofStatusKnown :=
  publicProfile.proofStatusKnown

end AgenticAILabProof.PooC4.UserInterfaceProfileLibrary
