-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.CedarDualEngineArbitration

namespace AgenticAILabProof.PooC4.CedarCapabilityRiskProjection

open AgenticAILabProof.PooC4.CedarDualEngineArbitration

/-!
The trusted projection from an effective capability contract to Cedar
arbitration risk.

The caller may state a preferred risk, but that value is deliberately ignored.
Only an explicitly admitted ordinary operation can select the
conformance-backed shadow mode; every privileged or unknown operation selects
strict lockstep.
-/

inductive CapabilityOperation where
  | ordinary
  | governanceMutation
  | authorityElevation
  | capabilityMutation
  | policyPublication
  | unknown
deriving DecidableEq, Repr

structure EffectiveCapabilityContract (Identity : Type) where
  identity : Identity
  operation : CapabilityOperation
  ordinaryAuthorityAdmitted : Bool
deriving DecidableEq, Repr

def projectAuthorityRisk
    {Identity : Type}
    (contract : EffectiveCapabilityContract Identity) :
    AuthorityRisk :=
  match contract.operation with
  | .ordinary =>
      if contract.ordinaryAuthorityAdmitted then
        .ordinary
      else
        .elevated
  | .governanceMutation => .elevated
  | .authorityElevation => .elevated
  | .capabilityMutation => .elevated
  | .policyPublication => .elevated
  | .unknown => .elevated

def resolveAuthorityRisk
    {Identity : Type}
    (contract : EffectiveCapabilityContract Identity)
    (_callerClaim : AuthorityRisk) :
    AuthorityRisk :=
  projectAuthorityRisk contract

def requiredArbitrationMode
    {Identity : Type}
    (contract : EffectiveCapabilityContract Identity) :
    ArbitrationMode :=
  requiredMode (projectAuthorityRisk contract)

theorem admitted_ordinary_operation_is_ordinary
    {Identity : Type}
    (identity : Identity) :
    projectAuthorityRisk
      { identity := identity
        operation := .ordinary
        ordinaryAuthorityAdmitted := true } = .ordinary := by
  rfl

theorem unadmitted_ordinary_operation_is_elevated
    {Identity : Type}
    (identity : Identity) :
    projectAuthorityRisk
      { identity := identity
        operation := .ordinary
        ordinaryAuthorityAdmitted := false } = .elevated := by
  rfl

theorem governance_mutation_is_elevated
    {Identity : Type}
    (identity : Identity)
    (ordinaryAuthorityAdmitted : Bool) :
    projectAuthorityRisk
      { identity := identity
        operation := .governanceMutation
        ordinaryAuthorityAdmitted := ordinaryAuthorityAdmitted } =
      .elevated := by
  rfl

theorem authority_elevation_is_elevated
    {Identity : Type}
    (identity : Identity)
    (ordinaryAuthorityAdmitted : Bool) :
    projectAuthorityRisk
      { identity := identity
        operation := .authorityElevation
        ordinaryAuthorityAdmitted := ordinaryAuthorityAdmitted } =
      .elevated := by
  rfl

theorem capability_mutation_is_elevated
    {Identity : Type}
    (identity : Identity)
    (ordinaryAuthorityAdmitted : Bool) :
    projectAuthorityRisk
      { identity := identity
        operation := .capabilityMutation
        ordinaryAuthorityAdmitted := ordinaryAuthorityAdmitted } =
      .elevated := by
  rfl

theorem policy_publication_is_elevated
    {Identity : Type}
    (identity : Identity)
    (ordinaryAuthorityAdmitted : Bool) :
    projectAuthorityRisk
      { identity := identity
        operation := .policyPublication
        ordinaryAuthorityAdmitted := ordinaryAuthorityAdmitted } =
      .elevated := by
  rfl

theorem unknown_operation_is_elevated
    {Identity : Type}
    (identity : Identity)
    (ordinaryAuthorityAdmitted : Bool) :
    projectAuthorityRisk
      { identity := identity
        operation := .unknown
        ordinaryAuthorityAdmitted := ordinaryAuthorityAdmitted } =
      .elevated := by
  rfl

theorem caller_claim_cannot_change_projected_risk
    {Identity : Type}
    (contract : EffectiveCapabilityContract Identity)
    (callerClaim : AuthorityRisk) :
    resolveAuthorityRisk contract callerClaim =
      projectAuthorityRisk contract := by
  rfl

theorem caller_cannot_downgrade_governance_mutation
    {Identity : Type}
    (identity : Identity)
    (ordinaryAuthorityAdmitted : Bool) :
    resolveAuthorityRisk
        { identity := identity
          operation := .governanceMutation
          ordinaryAuthorityAdmitted := ordinaryAuthorityAdmitted }
        .ordinary =
      .elevated := by
  rfl

theorem elevated_projection_selects_strict_lockstep
    {Identity : Type}
    (contract : EffectiveCapabilityContract Identity)
    (elevated : projectAuthorityRisk contract = .elevated) :
    requiredArbitrationMode contract = .strictLockstep := by
  simp [requiredArbitrationMode, elevated, requiredMode]

theorem admitted_ordinary_selects_shadow_mode
    {Identity : Type}
    (identity : Identity) :
    requiredArbitrationMode
      { identity := identity
        operation := .ordinary
        ordinaryAuthorityAdmitted := true } =
      .rustWithLeanShadow := by
  rfl

theorem unknown_selects_strict_lockstep
    {Identity : Type}
    (identity : Identity)
    (ordinaryAuthorityAdmitted : Bool) :
    requiredArbitrationMode
      { identity := identity
        operation := .unknown
        ordinaryAuthorityAdmitted := ordinaryAuthorityAdmitted } =
      .strictLockstep := by
  rfl

end AgenticAILabProof.PooC4.CedarCapabilityRiskProjection
