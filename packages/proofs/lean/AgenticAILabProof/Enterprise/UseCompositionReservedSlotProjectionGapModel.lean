-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Init

namespace AgenticAILabProof.Enterprise.UseCompositionReservedSlotProjectionGapModel

abbrev ModuleIdentity := Nat
abbrev ImportClosureIdentity := Nat
abbrev CapabilitySet := Nat
abbrev DomainValue := Nat

structure AuthoritySlots where
  identity : ModuleIdentity
  imports : ImportClosureIdentity
  grantedCapabilities : CapabilitySet
deriving DecidableEq, Repr

structure ProfileContribution where
  domainValue : DomainValue
  requestedCapabilities : CapabilitySet
deriving DecidableEq, Repr

structure MixModuleObject where
  authority : AuthoritySlots
  profile : ProfileContribution
deriving DecidableEq, Repr

structure RuntimePrototype where
  authority : AuthoritySlots
  domainValue : DomainValue
  requestedCapabilities : CapabilitySet
deriving DecidableEq, Repr

def legacyDirectMixComposition
    (_target : RuntimePrototype) (mix : MixModuleObject) : RuntimePrototype :=
  { authority := mix.authority
    domainValue := mix.profile.domainValue
    requestedCapabilities := mix.profile.requestedCapabilities }

def projectMixProfile (mix : MixModuleObject) : ProfileContribution :=
  mix.profile

def composeProjectedProfile
    (target : RuntimePrototype)
    (profile : ProfileContribution) : RuntimePrototype :=
  { authority := target.authority
    domainValue := profile.domainValue
    requestedCapabilities := profile.requestedCapabilities }

def baseAuthority : AuthoritySlots :=
  { identity := 42
    imports := 5
    grantedCapabilities := 1 }

def attackerAuthority : AuthoritySlots :=
  { identity := 99
    imports := 77
    grantedCapabilities := 255 }

def baseRuntime : RuntimePrototype :=
  { authority := baseAuthority
    domainValue := 10
    requestedCapabilities := 0 }

def attackerMix : MixModuleObject :=
  { authority := attackerAuthority
    profile :=
      { domainValue := 20
        requestedCapabilities := 128 } }

theorem directMixCompositionAllowsReservedSlotTakeover :
    let result := legacyDirectMixComposition baseRuntime attackerMix
    result.authority.identity = 99 ∧
      result.authority.imports = 77 ∧
      result.authority.grantedCapabilities = 255 := by
  decide

theorem directMixCompositionViolatesProfileIdentityPreservation :
    (legacyDirectMixComposition baseRuntime attackerMix).authority.identity ≠
      baseRuntime.authority.identity := by
  decide

theorem projectedProfileCompositionPreservesAuthority
    (target : RuntimePrototype) (mix : MixModuleObject) :
    (composeProjectedProfile target (projectMixProfile mix)).authority =
      target.authority := by
  rfl

theorem projectedProfileCannotGrantRequestedCapabilities
    (target : RuntimePrototype) (mix : MixModuleObject) :
    (composeProjectedProfile target (projectMixProfile mix)).authority.grantedCapabilities =
      target.authority.grantedCapabilities := by
  rfl

theorem projectedProfileKeepsRequirementsSeparateFromGrants :
    let result := composeProjectedProfile baseRuntime (projectMixProfile attackerMix)
    result.requestedCapabilities = 128 ∧
      result.authority.grantedCapabilities = 1 := by
  decide

theorem projectedCounterexamplePreservesEveryReservedSlot :
    let result := composeProjectedProfile baseRuntime (projectMixProfile attackerMix)
    result.authority.identity = 42 ∧
      result.authority.imports = 5 ∧
      result.authority.grantedCapabilities = 1 ∧
      result.domainValue = 20 := by
  decide

structure ExistingProfileOperandEvidence where
  identifierResolved : Bool
  isPooObject : Bool
  hasProfileProjection : Bool
deriving DecidableEq, Repr

def syntaxOnlyAdmission (evidence : ExistingProfileOperandEvidence) : Bool :=
  evidence.identifierResolved

def profileProjectionAdmission
    (evidence : ExistingProfileOperandEvidence) : Bool :=
  evidence.identifierResolved &&
    evidence.isPooObject &&
    evidence.hasProfileProjection

def nonPooIdentifierEvidence : ExistingProfileOperandEvidence :=
  { identifierResolved := true
    isPooObject := false
    hasProfileProjection := false }

def wholeMixWithoutProjectionEvidence : ExistingProfileOperandEvidence :=
  { identifierResolved := true
    isPooObject := true
    hasProfileProjection := false }

def projectedMixEvidence : ExistingProfileOperandEvidence :=
  { identifierResolved := true
    isPooObject := true
    hasProfileProjection := true }

theorem syntaxOnlyAdmissionAcceptsNonPooIdentifier :
    syntaxOnlyAdmission nonPooIdentifierEvidence = true := by
  decide

theorem projectionAdmissionRejectsNonPooIdentifier :
    profileProjectionAdmission nonPooIdentifierEvidence = false := by
  decide

theorem projectionAdmissionRejectsWholeMixWithoutProjection :
    profileProjectionAdmission wholeMixWithoutProjectionEvidence = false := by
  decide

theorem projectionAdmissionAcceptsProjectedMix :
    profileProjectionAdmission projectedMixEvidence = true := by
  decide

end AgenticAILabProof.Enterprise.UseCompositionReservedSlotProjectionGapModel
