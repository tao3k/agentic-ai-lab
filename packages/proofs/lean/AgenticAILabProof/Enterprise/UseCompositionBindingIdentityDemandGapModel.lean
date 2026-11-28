-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Init

namespace AgenticAILabProof.Enterprise.UseCompositionBindingIdentityDemandGapModel

inductive MacroHead where
  | useComposition
  | userComposition
deriving DecidableEq, Repr

structure MacroSurface where
  head : MacroHead
  establishesBinding : Bool
  repeatsBindingNameAtCallSite : Bool
  hasCanonicalModuleHeader : Bool
deriving DecidableEq, Repr

def satisfiesDirectBindingContract (surface : MacroSurface) : Bool :=
  surface.head == MacroHead.useComposition &&
    surface.establishesBinding &&
    !surface.repeatsBindingNameAtCallSite &&
    surface.hasCanonicalModuleHeader

def currentExpressionMacroSurface : MacroSurface :=
  { head := MacroHead.useComposition
    establishesBinding := false
    repeatsBindingNameAtCallSite := true
    hasCanonicalModuleHeader := true }

def legacyUserCompositionSurface : MacroSurface :=
  { head := MacroHead.userComposition
    establishesBinding := true
    repeatsBindingNameAtCallSite := false
    hasCanonicalModuleHeader := false }

def directUseCompositionSurface : MacroSurface :=
  { head := MacroHead.useComposition
    establishesBinding := true
    repeatsBindingNameAtCallSite := false
    hasCanonicalModuleHeader := true }

theorem currentExpressionMacroViolatesDirectBindingContract :
    satisfiesDirectBindingContract currentExpressionMacroSurface = false := by
  decide

theorem legacyUserCompositionViolatesCanonicalHeadContract :
    satisfiesDirectBindingContract legacyUserCompositionSurface = false := by
  decide

theorem directUseCompositionSatisfiesBindingContract :
    satisfiesDirectBindingContract directUseCompositionSurface = true := by
  decide

abbrev ModuleIdentity := Nat
abbrev AliasIdentity := Nat
abbrev ProfileSlotIdentity := Nat
abbrev LineageRootIdentity := Nat
abbrev Generation := Nat

def aliasDerivedProfileIdentity
    (alias : AliasIdentity) (slot : ProfileSlotIdentity) : Nat × Nat :=
  (alias, slot)

def moduleProfileCoordinate
    (moduleIdentity : ModuleIdentity) (slot : ProfileSlotIdentity) : Nat × Nat :=
  (moduleIdentity, slot)

theorem aliasRenameChangesAliasDerivedIdentity :
    aliasDerivedProfileIdentity 10 7 ≠ aliasDerivedProfileIdentity 11 7 := by
  decide

theorem aliasRenamePreservesModuleProfileCoordinate :
    moduleProfileCoordinate 42 7 = moduleProfileCoordinate 42 7 := by
  rfl

def slotOnlyProfileIdentity (slot : ProfileSlotIdentity) : ProfileSlotIdentity :=
  slot

theorem slotOnlyIdentityCollidesAcrossModules :
    slotOnlyProfileIdentity 7 = slotOnlyProfileIdentity 7 ∧
      moduleProfileCoordinate 41 7 ≠ moduleProfileCoordinate 42 7 := by
  decide

structure ProfileIdentity where
  moduleCoordinate : ModuleIdentity × ProfileSlotIdentity
  lineageRoot : LineageRootIdentity
deriving DecidableEq, Repr

def canonicalProfileIdentity
    (moduleIdentity : ModuleIdentity)
    (slot : ProfileSlotIdentity)
    (lineageRoot : LineageRootIdentity) : ProfileIdentity :=
  { moduleCoordinate := moduleProfileCoordinate moduleIdentity slot
    lineageRoot := lineageRoot }

theorem sameModuleSlotWithFreshRootsRemainDistinct :
    canonicalProfileIdentity 42 7 100 ≠ canonicalProfileIdentity 42 7 101 := by
  decide

def syntheticModuleWrappedLocalIdentity
    (syntheticModule : ModuleIdentity)
    (syntheticSlot : ProfileSlotIdentity)
    (lineageRoot : LineageRootIdentity) : ProfileIdentity :=
  canonicalProfileIdentity syntheticModule syntheticSlot lineageRoot

theorem renamingSyntheticLocalModuleChangesModuleCoordinateIdentity :
    syntheticModuleWrappedLocalIdentity 700 9 100 ≠
      syntheticModuleWrappedLocalIdentity 701 9 100 := by
  decide

inductive ProfileOriginIdentity where
  | moduleExport (moduleIdentity : ModuleIdentity)
      (slot : ProfileSlotIdentity)
  | localLineage (lineageRoot : LineageRootIdentity)
deriving DecidableEq, Repr

structure OriginAwareProfileIdentity where
  origin : ProfileOriginIdentity
  lineageRoot : LineageRootIdentity
deriving DecidableEq, Repr

def moduleExportProfileIdentity
    (moduleIdentity : ModuleIdentity)
    (slot : ProfileSlotIdentity)
    (lineageRoot : LineageRootIdentity) : OriginAwareProfileIdentity :=
  { origin := ProfileOriginIdentity.moduleExport moduleIdentity slot
    lineageRoot := lineageRoot }

def localProfileIdentity
    (lineageRoot : LineageRootIdentity) : OriginAwareProfileIdentity :=
  { origin := ProfileOriginIdentity.localLineage lineageRoot
    lineageRoot := lineageRoot }

theorem sameExportSlotFromDifferentModulesRemainsDistinct :
    moduleExportProfileIdentity 41 7 100 ≠
      moduleExportProfileIdentity 42 7 100 := by
  decide

theorem syntheticModuleRenameCannotChangeLocalOriginIdentity :
    let _presentationModuleBefore : ModuleIdentity := 700
    let _presentationModuleAfter : ModuleIdentity := 701
    localProfileIdentity 100 = localProfileIdentity 100 := by
  rfl

theorem localLineageRootsRemainDistinct :
    localProfileIdentity 100 ≠ localProfileIdentity 101 := by
  decide

structure WrappedLocalProfileReference where
  presentationModule : Nat
  presentationAlias : Nat
  presentationSlot : Nat
  localIdentity : OriginAwareProfileIdentity
deriving DecidableEq, Repr

structure DirectLocalProfileReference where
  localIdentity : OriginAwareProfileIdentity
deriving DecidableEq, Repr

def elaborateWrappedLocalProfile
    (reference : WrappedLocalProfileReference) : OriginAwareProfileIdentity :=
  reference.localIdentity

def elaborateDirectLocalProfile
    (reference : DirectLocalProfileReference) : OriginAwareProfileIdentity :=
  reference.localIdentity

theorem wrapperPresentationIsNonInjectiveAfterLocalElaboration :
    let profile := localProfileIdentity 100
    let before : WrappedLocalProfileReference :=
      { presentationModule := 700
        presentationAlias := 10
        presentationSlot := 9
        localIdentity := profile }
    let after : WrappedLocalProfileReference :=
      { presentationModule := 701
        presentationAlias := 11
        presentationSlot := 9
        localIdentity := profile }
    before ≠ after ∧
      elaborateWrappedLocalProfile before =
        elaborateWrappedLocalProfile after := by
  decide

theorem wrappedAndDirectLocalSurfacesHaveOneSemanticNormalForm :
    let profile := localProfileIdentity 100
    let wrapped : WrappedLocalProfileReference :=
      { presentationModule := 700
        presentationAlias := 10
        presentationSlot := 9
        localIdentity := profile }
    let direct : DirectLocalProfileReference :=
      { localIdentity := profile }
    elaborateWrappedLocalProfile wrapped = elaborateDirectLocalProfile direct := by
  rfl

structure ImportedProfileReference where
  moduleIdentity : ModuleIdentity
  slot : ProfileSlotIdentity
  lineageRoot : LineageRootIdentity
deriving DecidableEq, Repr

def elaborateImportedProfile
    (reference : ImportedProfileReference) : OriginAwareProfileIdentity :=
  moduleExportProfileIdentity
    reference.moduleIdentity reference.slot reference.lineageRoot

theorem importedModuleIdentityIsNotPresentationErased :
    let left : ImportedProfileReference :=
      { moduleIdentity := 41, slot := 7, lineageRoot := 100 }
    let right : ImportedProfileReference :=
      { moduleIdentity := 42, slot := 7, lineageRoot := 100 }
    elaborateImportedProfile left ≠ elaborateImportedProfile right := by
  decide

inductive DemandState where
  | pending
  | realizing
  | realized
  | failed
deriving DecidableEq, Repr

def stateDerivedIdentity
    (profile : OriginAwareProfileIdentity)
    (state : DemandState) : OriginAwareProfileIdentity × DemandState :=
  (profile, state)

theorem demandTransitionMutatesStateDerivedIdentity :
    let profile := moduleExportProfileIdentity 42 7 100
    stateDerivedIdentity profile DemandState.pending ≠
      stateDerivedIdentity profile DemandState.realized := by
  decide

def stableIdentityAcrossDemand
    (profile : OriginAwareProfileIdentity)
    (_state : DemandState) : OriginAwareProfileIdentity :=
  profile

theorem demandTransitionPreservesCanonicalProfileIdentity :
    let profile := moduleExportProfileIdentity 42 7 100
    stableIdentityAcrossDemand profile DemandState.pending =
      stableIdentityAcrossDemand profile DemandState.realized := by
  rfl

def legacyDemandKey
    (profile : OriginAwareProfileIdentity) : OriginAwareProfileIdentity :=
  profile

def generationBoundDemandKey
    (profile : OriginAwareProfileIdentity)
    (generation : Generation) : OriginAwareProfileIdentity × Generation :=
  (profile, generation)

theorem identityOnlyDemandKeyAliasesGenerations :
    let profile := moduleExportProfileIdentity 42 7 100
    legacyDemandKey profile = legacyDemandKey profile := by
  rfl

theorem generationBoundDemandKeyRejectsStaleReuse :
    let profile := moduleExportProfileIdentity 42 7 100
    generationBoundDemandKey profile 5 ≠ generationBoundDemandKey profile 6 := by
  decide

structure ProfileDemandWitness where
  profileIdentity : OriginAwareProfileIdentity
  generation : Generation
  demandKey : OriginAwareProfileIdentity × Generation
deriving DecidableEq, Repr

def demandWitnessClosesIdentityAndGeneration
    (witness : ProfileDemandWitness) : Prop :=
  witness.demandKey = (witness.profileIdentity, witness.generation)

theorem canonicalDemandWitnessClosesIdentityAndGeneration :
    let profile := moduleExportProfileIdentity 42 7 100
    let witness : ProfileDemandWitness :=
      { profileIdentity := profile
        generation := 5
        demandKey := generationBoundDemandKey profile 5 }
    demandWitnessClosesIdentityAndGeneration witness := by
  rfl

theorem staleDemandWitnessFailsClosed :
    let profile := moduleExportProfileIdentity 42 7 100
    let witness : ProfileDemandWitness :=
      { profileIdentity := profile
        generation := 6
        demandKey := generationBoundDemandKey profile 5 }
    ¬ demandWitnessClosesIdentityAndGeneration witness := by
  simp [demandWitnessClosesIdentityAndGeneration,
    generationBoundDemandKey, moduleExportProfileIdentity]

end AgenticAILabProof.Enterprise.UseCompositionBindingIdentityDemandGapModel
