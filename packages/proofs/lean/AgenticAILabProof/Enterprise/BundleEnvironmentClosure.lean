-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.BundleEvidenceBinding

namespace AgenticAILabProof.Enterprise.BundleEnvironmentClosure

open BundleOwnership
open BundleEvidenceBinding

abbrev ToolchainId := String
abbrev ImportName := String

structure EnvironmentIdentity where
  name : EnvironmentId
  toolchain : ToolchainId
  requiredImports : List ImportName
  deriving DecidableEq, Repr

structure CanonicalSourceRequirements where
  requiredImports : List ImportName
  deriving DecidableEq, Repr

def toolchainMatches
    (localToolchain : ToolchainId)
    (environment : EnvironmentIdentity) : Prop :=
  localToolchain = environment.toolchain

def importClosed
    (source : CanonicalSourceRequirements)
    (providedImports : List ImportName) : Prop :=
  ∀ importName ∈ source.requiredImports, importName ∈ providedImports

def currentEnvironmentIdentity : EnvironmentIdentity where
  name := "lean-4.31.0"
  toolchain := "4.31.0"
  requiredImports := ["Init"]

def currentCanonicalSourceRequirements : CanonicalSourceRequirements where
  requiredImports := ["Mathlib"]

theorem currentToolchainMatches :
    toolchainMatches "4.31.0" currentEnvironmentIdentity := by
  rfl

theorem toolchainMatchDoesNotImplyImportClosure :
    toolchainMatches "4.31.0" currentEnvironmentIdentity ∧
      ¬ importClosed
        currentCanonicalSourceRequirements
        currentEnvironmentIdentity.requiredImports := by
  constructor
  · rfl
  · intro closed
    have mathlibProvided :=
      closed "Mathlib" (by simp [currentCanonicalSourceRequirements])
    simp [currentEnvironmentIdentity] at mathlibProvided

structure MaterializedEnvironment extends EnvironmentIdentity where
  contentDigest : Digest
  deriving DecidableEq, Repr

def eraseEnvironmentContent
    (environment : MaterializedEnvironment) : EnvironmentIdentity :=
  environment.toEnvironmentIdentity

def environmentMaterializationA : MaterializedEnvironment where
  name := "lean-4.31.0"
  toolchain := "4.31.0"
  requiredImports := ["Mathlib"]
  contentDigest := "sha256:environment-a"

def environmentMaterializationB : MaterializedEnvironment where
  name := "lean-4.31.0"
  toolchain := "4.31.0"
  requiredImports := ["Mathlib"]
  contentDigest := "sha256:environment-b"

theorem unboundEnvironmentIdentityCannotDistinguishContentDrift :
    eraseEnvironmentContent environmentMaterializationA =
      eraseEnvironmentContent environmentMaterializationB := by
  rfl

theorem environmentMaterializationsAreDistinct :
    environmentMaterializationA ≠ environmentMaterializationB := by
  decide

structure EnvironmentResolutionReceipt where
  environmentName : EnvironmentId
  toolchain : ToolchainId
  providedImports : List ImportName
  environmentContentDigest : Digest
  providerId : String
  providerReceiptDigest : Digest
  deriving DecidableEq, Repr

def environmentReceiptMatches
    (identity : EnvironmentIdentity)
    (receipt : EnvironmentResolutionReceipt) : Prop :=
  receipt.environmentName = identity.name ∧
    receipt.toolchain = identity.toolchain

def EnvironmentReceiptValid :=
  EnvironmentResolutionReceipt → Prop

def environmentEvidenceClosed
    (valid : EnvironmentReceiptValid)
    (source : CanonicalSourceRequirements)
    (identity : EnvironmentIdentity)
    (receipt : EnvironmentResolutionReceipt) : Prop :=
  identity.requiredImports = source.requiredImports ∧
    environmentReceiptMatches identity receipt ∧
    importClosed source receipt.providedImports ∧
    valid receipt

def mathlibEnvironmentIdentity : EnvironmentIdentity where
  name := "lean-4.31.0"
  toolchain := "4.31.0"
  requiredImports := ["Mathlib"]

def mathlibEnvironmentReceipt : EnvironmentResolutionReceipt where
  environmentName := "lean-4.31.0"
  toolchain := "4.31.0"
  providedImports := ["Init", "Mathlib"]
  environmentContentDigest := "sha256:environment-a"
  providerId := "axle"
  providerReceiptDigest := "sha256:axle-environment-receipt"

theorem mathlibEnvironmentEvidenceClosed :
    environmentEvidenceClosed
      (fun _receipt => True)
      currentCanonicalSourceRequirements
      mathlibEnvironmentIdentity
      mathlibEnvironmentReceipt := by
  simp [
    environmentEvidenceClosed,
    environmentReceiptMatches,
    importClosed,
    currentCanonicalSourceRequirements,
    mathlibEnvironmentIdentity,
    mathlibEnvironmentReceipt
  ]

theorem currentEnvironmentIdentityRejected :
    ¬ environmentEvidenceClosed
      (fun _receipt => True)
      currentCanonicalSourceRequirements
      currentEnvironmentIdentity
      mathlibEnvironmentReceipt := by
  intro closed
  have requiredImportsEqual := closed.1
  simp [
    currentCanonicalSourceRequirements,
    currentEnvironmentIdentity
  ] at requiredImportsEqual

theorem matchingEnvironmentFieldsDoNotProveProviderAuthority :
    environmentReceiptMatches
        mathlibEnvironmentIdentity
        mathlibEnvironmentReceipt ∧
      ¬ environmentEvidenceClosed
        (fun _receipt => False)
        currentCanonicalSourceRequirements
        mathlibEnvironmentIdentity
        mathlibEnvironmentReceipt := by
  constructor
  · simp [
      environmentReceiptMatches,
      mathlibEnvironmentIdentity,
      mathlibEnvironmentReceipt
    ]
  · intro closed
    exact closed.2.2.2

theorem environmentEvidenceClosedProvidesRequiredImport
    (valid : EnvironmentReceiptValid)
    (source : CanonicalSourceRequirements)
    (identity : EnvironmentIdentity)
    (receipt : EnvironmentResolutionReceipt)
    (closed : environmentEvidenceClosed valid source identity receipt)
    (importName : ImportName)
    (required : importName ∈ source.requiredImports) :
    importName ∈ receipt.providedImports :=
  closed.2.2.1 importName required

end AgenticAILabProof.Enterprise.BundleEnvironmentClosure
