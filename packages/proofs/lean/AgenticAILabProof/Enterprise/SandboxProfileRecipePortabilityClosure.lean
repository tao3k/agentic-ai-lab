-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure
import AgenticAILabProof.Enterprise.CedarDualEngineAuthorization

namespace AgenticAILabProof.Enterprise.SandboxProfileRecipePortabilityClosure

open AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure

abbrev RecipeIdentity := Nat
abbrev LogicalResourceRole := Nat
abbrev BackendIdentity := Nat
abbrev BackendMaterializationPolicyIdentity := Nat
abbrev MaterializationAdmissionIdentity :=
  AgenticAILabProof.Enterprise.CedarDualEngineAuthorization.ReceiptId
abbrev RuntimeMountTarget := Nat

/-- The composable recipe owns only stable logical identity. -/
structure PortableRecipe where
  identity : RecipeIdentity
  resourceRole : LogicalResourceRole
  backendIdentity : BackendIdentity
deriving DecidableEq

/-- The backend policy, rather than the recipe, owns target resolution. -/
structure BackendMaterializationPolicy where
  identity : BackendMaterializationPolicyIdentity
  targetFor : BackendIdentity → LogicalResourceRole → RuntimeMountTarget

/-- A backend-owned receipt introduces the concrete target at materialization. -/
structure BackendMaterializationReceipt where
  recipeIdentity : RecipeIdentity
  resourceRole : LogicalResourceRole
  backendIdentity : BackendIdentity
  policyIdentity : BackendMaterializationPolicyIdentity
  runtimeTarget : RuntimeMountTarget
deriving DecidableEq

/-- Authority-owned admission for one exact recipe/backend/policy tuple. -/
structure MaterializationAdmission where
  identity : MaterializationAdmissionIdentity
  recipeIdentity : RecipeIdentity
  backendIdentity : BackendIdentity
  policyIdentity : BackendMaterializationPolicyIdentity
  authorityReceipt : ContextBoundAuthorityReceipt

def receiptClosesRecipe
    (recipe : PortableRecipe)
    (receipt : BackendMaterializationReceipt) : Prop :=
  receipt.recipeIdentity = recipe.identity ∧
  receipt.resourceRole = recipe.resourceRole ∧
  receipt.backendIdentity = recipe.backendIdentity

def receiptClosesBackendPolicy
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (receipt : BackendMaterializationReceipt) : Prop :=
  receiptClosesRecipe recipe receipt ∧
  receipt.policyIdentity = policy.identity ∧
  receipt.runtimeTarget =
    policy.targetFor recipe.backendIdentity recipe.resourceRole

structure MaterializationAdmissionClosure
    (currentContext : ReceiptValidationContext)
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (admission : MaterializationAdmission)
    (receipt : BackendMaterializationReceipt) : Prop where
  backendPolicyClosed : receiptClosesBackendPolicy recipe policy receipt
  recipeIdentityBound : admission.recipeIdentity = recipe.identity
  backendIdentityBound : admission.backendIdentity = recipe.backendIdentity
  policyIdentityBound : admission.policyIdentity = policy.identity
  currentPolicySnapshotBound :
    policy.identity = currentContext.policySnapshotIdentity
  acceptedAtCurrentContext :
    acceptedAtContext currentContext admission.authorityReceipt

/-- Countermodel for the old design: a backend target embedded in identity makes
    two layouts denote two different recipes. -/
def targetBearingRecipeIdentity
    (role : LogicalResourceRole)
    (target : RuntimeMountTarget) : LogicalResourceRole × RuntimeMountTarget :=
  (role, target)

theorem embeddedTargetMakesBackendLayoutChangeRecipeIdentity
    (role : LogicalResourceRole)
    {leftTarget rightTarget : RuntimeMountTarget}
    (targetsDiffer : leftTarget ≠ rightTarget) :
    targetBearingRecipeIdentity role leftTarget ≠
      targetBearingRecipeIdentity role rightTarget := by
  intro identitiesEqual
  exact targetsDiffer (congrArg Prod.snd identitiesEqual)

def uncheckedMaterializationReceipt
    (recipe : PortableRecipe)
    (policyIdentity : BackendMaterializationPolicyIdentity)
    (target : RuntimeMountTarget) : BackendMaterializationReceipt :=
  { recipeIdentity := recipe.identity
    resourceRole := recipe.resourceRole
    backendIdentity := recipe.backendIdentity
    policyIdentity := policyIdentity
    runtimeTarget := target }

theorem recipeClosureAlonePermitsRuntimeTargetSubstitution
    (recipe : PortableRecipe)
    (policyIdentity : BackendMaterializationPolicyIdentity)
    {leftTarget rightTarget : RuntimeMountTarget}
    (targetsDiffer : leftTarget ≠ rightTarget) :
    ∃ leftReceipt rightReceipt,
      receiptClosesRecipe recipe leftReceipt ∧
      receiptClosesRecipe recipe rightReceipt ∧
      leftReceipt.runtimeTarget ≠ rightReceipt.runtimeTarget := by
  refine ⟨uncheckedMaterializationReceipt recipe policyIdentity leftTarget,
    uncheckedMaterializationReceipt recipe policyIdentity rightTarget,
    ?_, ?_, ?_⟩
  · exact ⟨rfl, rfl, rfl⟩
  · exact ⟨rfl, rfl, rfl⟩
  · simpa [uncheckedMaterializationReceipt] using targetsDiffer

def materialize
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy) : BackendMaterializationReceipt :=
  { recipeIdentity := recipe.identity
    resourceRole := recipe.resourceRole
    backendIdentity := recipe.backendIdentity
    policyIdentity := policy.identity
    runtimeTarget :=
      policy.targetFor recipe.backendIdentity recipe.resourceRole }

def admitMaterialization
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (context : ReceiptValidationContext)
    (ownerAccepted : Bool)
    (admissionIdentity : MaterializationAdmissionIdentity) :
    MaterializationAdmission :=
  { identity := admissionIdentity
    recipeIdentity := recipe.identity
    backendIdentity := recipe.backendIdentity
    policyIdentity := policy.identity
    authorityReceipt :=
      { issuedContext := context
        ownerAccepted := ownerAccepted } }

theorem exactBackendPolicyClosureStillPermitsStaleAdmission
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (admissionIdentity : MaterializationAdmissionIdentity)
    (currentContext staleContext : ReceiptValidationContext)
    (contextsDiffer : staleContext ≠ currentContext) :
    receiptClosesBackendPolicy recipe policy (materialize recipe policy) ∧
    ¬ acceptedAtContext currentContext
      (admitMaterialization recipe policy staleContext true
        admissionIdentity).authorityReceipt := by
  constructor
  · exact ⟨⟨rfl, rfl, rfl⟩, rfl, rfl⟩
  · intro staleAccepted
    exact contextsDiffer staleAccepted.2

theorem exactCurrentContextAdmissionClosesMaterialization
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (admissionIdentity : MaterializationAdmissionIdentity)
    (currentContext : ReceiptValidationContext)
    (policySnapshotBound :
      policy.identity = currentContext.policySnapshotIdentity) :
    MaterializationAdmissionClosure
      currentContext
      recipe
      policy
      (admitMaterialization recipe policy currentContext true admissionIdentity)
      (materialize recipe policy) := by
  constructor
  · exact ⟨⟨rfl, rfl, rfl⟩, rfl, rfl⟩
  · rfl
  · rfl
  · rfl
  · exact policySnapshotBound
  · exact ⟨rfl, rfl⟩

theorem exactContextAdmissionRejectsStaleContext
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (admissionIdentity : MaterializationAdmissionIdentity)
    (currentContext staleContext : ReceiptValidationContext)
    (contextsDiffer : staleContext ≠ currentContext) :
    ¬ MaterializationAdmissionClosure
      currentContext
      recipe
      policy
      (admitMaterialization recipe policy staleContext true admissionIdentity)
      (materialize recipe policy) := by
  intro closed
  exact contextsDiffer closed.acceptedAtCurrentContext.2

theorem everyBackendMaterializationClosesThePortableRecipe
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy) :
    receiptClosesRecipe recipe (materialize recipe policy) := by
  exact ⟨rfl, rfl, rfl⟩

theorem everyMaterializationClosesTheExactBackendPolicy
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy) :
    receiptClosesBackendPolicy recipe policy (materialize recipe policy) := by
  exact ⟨⟨rfl, rfl, rfl⟩, rfl, rfl⟩

theorem distinctPolicyTargetsDoNotChangePortableRecipeIdentity
    (recipe : PortableRecipe)
    (leftPolicy rightPolicy : BackendMaterializationPolicy) :
    (materialize recipe leftPolicy).recipeIdentity =
      (materialize recipe rightPolicy).recipeIdentity ∧
    (materialize recipe leftPolicy).resourceRole =
      (materialize recipe rightPolicy).resourceRole ∧
    (materialize recipe leftPolicy).backendIdentity =
      (materialize recipe rightPolicy).backendIdentity := by
  exact ⟨rfl, rfl, rfl⟩

theorem closedReceiptsForOnePolicyResolveOneRuntimeTarget
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (leftReceipt rightReceipt : BackendMaterializationReceipt)
    (leftClosed : receiptClosesBackendPolicy recipe policy leftReceipt)
    (rightClosed : receiptClosesBackendPolicy recipe policy rightReceipt) :
    leftReceipt.runtimeTarget = rightReceipt.runtimeTarget := by
  exact leftClosed.2.2.trans rightClosed.2.2.symm

theorem closedReceiptBindsTheDeclaredBackend
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (receipt : BackendMaterializationReceipt)
    (closed : receiptClosesBackendPolicy recipe policy receipt) :
    receipt.backendIdentity = recipe.backendIdentity := by
  exact closed.1.2.2

theorem closedReceiptBindsTheExactPolicyIdentity
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (receipt : BackendMaterializationReceipt)
    (closed : receiptClosesBackendPolicy recipe policy receipt) :
    receipt.policyIdentity = policy.identity := by
  exact closed.2.1

theorem runtimeTargetIsOwnedOnlyByTheMaterializationReceipt
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy) :
    (materialize recipe policy).runtimeTarget =
      policy.targetFor recipe.backendIdentity recipe.resourceRole ∧
    receiptClosesBackendPolicy recipe policy (materialize recipe policy) := by
  exact ⟨rfl, everyMaterializationClosesTheExactBackendPolicy recipe policy⟩

end AgenticAILabProof.Enterprise.SandboxProfileRecipePortabilityClosure
