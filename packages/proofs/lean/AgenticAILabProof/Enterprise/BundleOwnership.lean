-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.Core

namespace AgenticAILabProof.Enterprise.BundleOwnership

abbrev PackageId := String
abbrev DeclarationName := String
abbrev OwnerPath := String
abbrev Digest := String

structure DeclarationIdentity where
  name : DeclarationName
  ownerPath : OwnerPath
  ownerSourceDigest : Digest
  deriving DecidableEq, Repr

structure BoundDeclarationIdentity extends DeclarationIdentity where
  ownerPackageId : PackageId
  deriving DecidableEq, Repr

structure ResolvedSourceIdentity where
  packageId : PackageId
  sourceTreeDigest : Digest
  deriving DecidableEq, Repr

def eraseOwnerPackage
    (declaration : BoundDeclarationIdentity) : DeclarationIdentity :=
  declaration.toDeclarationIdentity

def unboundManifestProjection
    (declarations : List BoundDeclarationIdentity) : List DeclarationIdentity :=
  declarations.map eraseOwnerPackage

def declarationA : DeclarationIdentity where
  name := "Enterprise.Policy"
  ownerPath := "Enterprise/Policy.lean"
  ownerSourceDigest := "sha256:policy"

def declarationB : DeclarationIdentity where
  name := "Enterprise.Workflow"
  ownerPath := "Enterprise/Workflow.lean"
  ownerSourceDigest := "sha256:workflow"

def packageA : PackageId := "industry-a"
def packageB : PackageId := "industry-b"

def assignmentLeft : List BoundDeclarationIdentity :=
  [
    { declarationA with ownerPackageId := packageA },
    { declarationB with ownerPackageId := packageB }
  ]

def assignmentRight : List BoundDeclarationIdentity :=
  [
    { declarationA with ownerPackageId := packageB },
    { declarationB with ownerPackageId := packageA }
  ]

theorem unboundProjectionCannotDistinguishOwnerSwap :
    unboundManifestProjection assignmentLeft =
      unboundManifestProjection assignmentRight := by
  rfl

theorem packageOwnersAreDistinct : packageA ≠ packageB := by
  decide

theorem boundProjectionDistinguishesOwnerSwap :
    assignmentLeft ≠ assignmentRight := by
  decide

def ownershipClosed
    (resolvedPackages : List PackageId)
    (declarations : List BoundDeclarationIdentity) : Prop :=
  ∀ declaration ∈ declarations,
    declaration.ownerPackageId ∈ resolvedPackages

theorem assignmentLeftOwnershipClosed :
    ownershipClosed [packageA, packageB] assignmentLeft := by
  intro declaration declarationMember
  simp [assignmentLeft] at declarationMember
  rcases declarationMember with rfl | rfl
  · simp [packageA]
  · simp [packageB]

theorem foreignOwnerRejected
    (resolvedPackages : List PackageId)
    (declaration : BoundDeclarationIdentity)
    (ownerMissing : declaration.ownerPackageId ∉ resolvedPackages) :
    ¬ ownershipClosed resolvedPackages [declaration] := by
  intro closed
  exact ownerMissing (closed declaration (by simp))

def ownerAssignmentFunctional
    (declarations : List BoundDeclarationIdentity) : Prop :=
  ∀ left ∈ declarations, ∀ right ∈ declarations,
    left.name = right.name → left.ownerPackageId = right.ownerPackageId

theorem conflictingOwnersRejected
    (left right : BoundDeclarationIdentity)
    (sameName : left.name = right.name)
    (differentOwners : left.ownerPackageId ≠ right.ownerPackageId) :
    ¬ ownerAssignmentFunctional [left, right] := by
  intro functional
  exact differentOwners
    (functional left (by simp) right (by simp) sameName)

def SourceTreeIncludes :=
  Digest → OwnerPath → Digest → Prop

def sourceEvidenceClosed
    (includes : SourceTreeIncludes)
    (resolvedSources : List ResolvedSourceIdentity)
    (declarations : List BoundDeclarationIdentity) : Prop :=
  ∀ declaration ∈ declarations,
    ∃ source ∈ resolvedSources,
      source.packageId = declaration.ownerPackageId ∧
      includes
        source.sourceTreeDigest
        declaration.ownerPath
        declaration.ownerSourceDigest

def resolvedPackageA : ResolvedSourceIdentity where
  packageId := packageA
  sourceTreeDigest := "sha256:tree-a"

def boundDeclarationA : BoundDeclarationIdentity :=
  { declarationA with ownerPackageId := packageA }

theorem packageBindingAloneDoesNotProveSourceMembership :
    ownershipClosed [packageA] [boundDeclarationA] ∧
      ¬ sourceEvidenceClosed
        (fun _treeDigest _ownerPath _sourceDigest => False)
        [resolvedPackageA]
        [boundDeclarationA] := by
  constructor
  · intro declaration declarationMember
    simp [boundDeclarationA] at declarationMember
    subst declaration
    simp [packageA]
  · intro evidence
    obtain ⟨source, sourceMember, _packageMatches, included⟩ :=
      evidence boundDeclarationA (by simp)
    simp [resolvedPackageA] at sourceMember
    subst source
    exact included

def evidenceClosed
    (includes : SourceTreeIncludes)
    (resolvedSources : List ResolvedSourceIdentity)
    (declarations : List BoundDeclarationIdentity) : Prop :=
  ownershipClosed
      (resolvedSources.map ResolvedSourceIdentity.packageId)
      declarations ∧
    ownerAssignmentFunctional declarations ∧
    sourceEvidenceClosed includes resolvedSources declarations

theorem evidenceClosedProvidesResolvedOwner
    (includes : SourceTreeIncludes)
    (resolvedSources : List ResolvedSourceIdentity)
    (declarations : List BoundDeclarationIdentity)
    (closed : evidenceClosed includes resolvedSources declarations)
    (declaration : BoundDeclarationIdentity)
    (declarationMember : declaration ∈ declarations) :
    declaration.ownerPackageId ∈
      resolvedSources.map ResolvedSourceIdentity.packageId :=
  closed.1 declaration declarationMember

theorem evidenceClosedProvidesSourceMembership
    (includes : SourceTreeIncludes)
    (resolvedSources : List ResolvedSourceIdentity)
    (declarations : List BoundDeclarationIdentity)
    (closed : evidenceClosed includes resolvedSources declarations)
    (declaration : BoundDeclarationIdentity)
    (declarationMember : declaration ∈ declarations) :
    ∃ source ∈ resolvedSources,
      source.packageId = declaration.ownerPackageId ∧
      includes
        source.sourceTreeDigest
        declaration.ownerPath
        declaration.ownerSourceDigest :=
  closed.2.2 declaration declarationMember

end AgenticAILabProof.Enterprise.BundleOwnership
