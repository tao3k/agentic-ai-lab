-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Vertical.Healthcare.StandardMigrationRefinement

inductive MigrationPhase where
  | inventory | mapped | conformant | humanReviewed | authorized | cutoverReady
  deriving DecidableEq

structure MigrationState where
  phase : MigrationPhase
  parserBound : Bool
  mappingComplete : Bool
  conformanceBound : Bool
  humanReviewed : Bool
  cedarPermit : Bool
  cutoverReady : Bool
  aiAuthority : Bool

def admissible (state : MigrationState) : Prop :=
  state.aiAuthority = false ∧
  (state.humanReviewed = true → state.conformanceBound = true) ∧
  (state.cedarPermit = true → state.humanReviewed = true) ∧
  (state.cutoverReady = true →
    state.parserBound = true ∧ state.mappingComplete = true ∧
    state.conformanceBound = true ∧ state.humanReviewed = true ∧
    state.cedarPermit = true)

def quintSourceDigest : String :=
  "sha256:b686064c4e647465c847e30c6d654fe86722aa7a0ed86f2fb74b6b7ab69abd88"

def quintInvariantNames : List String :=
  ["AINeverGrantsAuthority", "ReviewRequiresConformance",
   "CedarPermitRequiresHumanReview", "CutoverRequiresCedarPermit",
   "CutoverRequiresCompleteEvidence"]

structure QuintImpactContract where
  quintSourceDigest : String
  impactedLeanDeclarations : List String
  deriving DecidableEq

def migrationImpactContract : QuintImpactContract :=
  { quintSourceDigest := quintSourceDigest
    impactedLeanDeclarations :=
      ["aiCannotAuthorize", "cutoverRequiresHumanCedarAndEvidence",
       "quintImpactContractBindsExactSource"] }

theorem aiCannotAuthorize (state : MigrationState)
    (accepted : admissible state) : state.aiAuthority = false :=
  accepted.1

theorem cutoverRequiresHumanCedarAndEvidence (state : MigrationState)
    (accepted : admissible state) (ready : state.cutoverReady = true) :
    state.parserBound = true ∧ state.mappingComplete = true ∧
    state.conformanceBound = true ∧ state.humanReviewed = true ∧
    state.cedarPermit = true :=
  accepted.2.2.2 ready

theorem quintImpactContractBindsExactSource :
    migrationImpactContract.quintSourceDigest = quintSourceDigest := by
  rfl

end AgenticAILabProof.Vertical.Healthcare.StandardMigrationRefinement
