-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Export.DeclarationClosureModel

universe u v

def EnvironmentClosed
    (environmentDependsOn : α → α → Prop)
    (selected : α → Prop) :
    Prop :=
  ∀ {declaration dependency},
    selected declaration →
      environmentDependsOn declaration dependency →
        selected dependency

def SourceFamilyClosed
    (sourceOf : α → Option β)
    (sameSourceFamily : β → α → Prop)
    (selected : α → Prop) :
    Prop :=
  ∀ {declaration source familyMember},
    selected declaration →
      sourceOf declaration = some source →
        sameSourceFamily source familyMember →
          selected familyMember

def ProjectedSourceSet
    (sourceOf : α → Option β)
    (selected : α → Prop)
    (source : β) :
    Prop :=
  ∃ declaration,
    selected declaration ∧
      sourceOf declaration = some source

def SourceReplayClosed
    (sourceDependsOn : β → β → Prop)
    (selectedSources : β → Prop) :
    Prop :=
  ∀ {source dependency},
    selectedSources source →
      sourceDependsOn source dependency →
        selectedSources dependency

def SourceDependencyWitnessed
    (sourceOf : α → Option β)
    (sameSourceFamily : β → α → Prop)
    (environmentDependsOn : α → α → Prop)
    (sourceDependsOn : β → β → Prop) :
    Prop :=
  ∀ {declaration source dependency},
    sourceOf declaration = some source →
      sourceDependsOn source dependency →
        ∃ familyMember environmentDependency,
          sameSourceFamily source familyMember ∧
            environmentDependsOn
              familyMember
              environmentDependency ∧
            sourceOf environmentDependency = some dependency

theorem sourceFamilyAndEnvironmentClosureImplyReplayClosure
    {sourceOf : α → Option β}
    {sameSourceFamily : β → α → Prop}
    {environmentDependsOn : α → α → Prop}
    {sourceDependsOn : β → β → Prop}
    {selected : α → Prop}
    (familyClosed :
      SourceFamilyClosed sourceOf sameSourceFamily selected)
    (environmentClosed :
      EnvironmentClosed environmentDependsOn selected)
    (dependencyWitnessed :
      SourceDependencyWitnessed
        sourceOf
        sameSourceFamily
        environmentDependsOn
        sourceDependsOn) :
    SourceReplayClosed
      sourceDependsOn
      (ProjectedSourceSet sourceOf selected) := by
  intro source dependency sourceSelected sourceDependency
  rcases sourceSelected with
    ⟨declaration, declarationSelected, declarationSource⟩
  rcases dependencyWitnessed declarationSource sourceDependency with
    ⟨familyMember,
      environmentDependency,
      familyMembership,
      environmentDependencyEdge,
      dependencySource⟩
  exact
    ⟨environmentDependency,
      environmentClosed
        (familyClosed
          declarationSelected
          declarationSource
          familyMembership)
        environmentDependencyEdge,
      dependencySource⟩

inductive CounterexampleEnvironmentDeclaration
  | structureType
  | structureConstructor
  | reducibleAlias
  | internalNoSourceRange
  deriving DecidableEq, Repr

inductive CounterexampleSourceDeclaration
  | structureSource
  | aliasSource
  deriving DecidableEq, Repr

def counterexampleEnvironmentDependsOn :
    CounterexampleEnvironmentDeclaration →
      CounterexampleEnvironmentDeclaration →
        Prop
  | .structureConstructor, .reducibleAlias => True
  | _, _ => False

def counterexampleSourceOf :
    CounterexampleEnvironmentDeclaration →
      Option CounterexampleSourceDeclaration
  | .structureType => some .structureSource
  | .structureConstructor => some .structureSource
  | .reducibleAlias => some .aliasSource
  | .internalNoSourceRange => none

def counterexampleRootSelection :
    CounterexampleEnvironmentDeclaration →
      Prop
  | .structureType => True
  | _ => False

def counterexampleSourceDependsOn :
    CounterexampleSourceDeclaration →
      CounterexampleSourceDeclaration →
        Prop
  | .structureSource, .aliasSource => True
  | _, _ => False

theorem counterexampleRootIsEnvironmentClosed :
    EnvironmentClosed
      counterexampleEnvironmentDependsOn
      counterexampleRootSelection := by
  intro declaration dependency declarationSelected dependencyEdge
  cases declaration <;> cases dependency <;>
    simp_all [
      counterexampleRootSelection,
      counterexampleEnvironmentDependsOn
    ]

theorem counterexampleRootProjectsStructureSource :
    ProjectedSourceSet
      counterexampleSourceOf
      counterexampleRootSelection
      .structureSource := by
  exact ⟨.structureType, by trivial, rfl⟩

theorem counterexampleRootDoesNotProjectAliasSource :
    ¬ ProjectedSourceSet
      counterexampleSourceOf
      counterexampleRootSelection
      .aliasSource := by
  intro projected
  rcases projected with ⟨declaration, declarationSelected, declarationSource⟩
  cases declaration <;>
    simp_all [
      counterexampleRootSelection,
      counterexampleSourceOf
    ]

theorem environmentClosureAloneDoesNotImplySourceReplayClosure :
    EnvironmentClosed
        counterexampleEnvironmentDependsOn
        counterexampleRootSelection ∧
      ¬ SourceReplayClosed
        counterexampleSourceDependsOn
        (ProjectedSourceSet
          counterexampleSourceOf
          counterexampleRootSelection) := by
  constructor
  · exact counterexampleRootIsEnvironmentClosed
  · intro sourceClosed
    have aliasProjected :
        ProjectedSourceSet
          counterexampleSourceOf
          counterexampleRootSelection
          .aliasSource :=
      sourceClosed
        (source := .structureSource)
        (dependency := .aliasSource)
        counterexampleRootProjectsStructureSource
        (by
          simp [counterexampleSourceDependsOn])
    exact counterexampleRootDoesNotProjectAliasSource aliasProjected

theorem nonSourceBearingTraversalNodeIsAbsentFromReceiptProjection :
    ¬ ∃ source,
      counterexampleSourceOf .internalNoSourceRange = some source := by
  simp [counterexampleSourceOf]

end AgenticAILabProof.Export.DeclarationClosureModel
