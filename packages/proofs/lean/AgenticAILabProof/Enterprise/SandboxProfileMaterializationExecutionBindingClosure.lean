-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SandboxProfileRecipePortabilityClosure
import AgenticAILabProof.Enterprise.EffectDomainCoverage
import AgenticAILabProof.Enterprise.PromotionTransactionAtomicity

namespace AgenticAILabProof.Enterprise.SandboxProfileMaterializationExecutionBindingClosure

open AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure
open AgenticAILabProof.Enterprise.SandboxProfileRecipePortabilityClosure

abbrev MaterializationTransactionIdentity :=
  AgenticAILabProof.Enterprise.PromotionTransactionAtomicity.TransactionId
abbrev RuntimeStateIdentity :=
  AgenticAILabProof.Enterprise.PromotionTransactionAtomicity.RuntimeStateDigest
abbrev MaterializationEffectIdentity :=
  AgenticAILabProof.Enterprise.EffectDomainCoverage.EffectId
abbrev MaterializationEffectSemanticsIdentity := String

structure MaterializationEffectSemantics where
  identity : MaterializationEffectSemanticsIdentity
  postStateFor :
    RuntimeStateIdentity → BackendIdentity → RuntimeMountTarget →
      RuntimeStateIdentity
  effectIdentityFor :
    MaterializationTransactionIdentity → BackendIdentity → RuntimeMountTarget →
      MaterializationEffectIdentity

structure SandboxMaterializationExecutionRequest where
  transactionIdentity : MaterializationTransactionIdentity
  admissionIdentity : MaterializationAdmissionIdentity
  materializationReceipt : BackendMaterializationReceipt
  effectSemanticsIdentity : MaterializationEffectSemanticsIdentity
  expectedContext : ReceiptValidationContext
  runtimeEpoch : Nat
  activeFenceToken : Nat
  expectedPreStateIdentity : RuntimeStateIdentity

structure SandboxMaterializationExecutionReceipt where
  transactionIdentity : MaterializationTransactionIdentity
  admissionIdentity : MaterializationAdmissionIdentity
  recipeIdentity : RecipeIdentity
  backendIdentity : BackendIdentity
  policyIdentity : BackendMaterializationPolicyIdentity
  effectSemanticsIdentity : MaterializationEffectSemanticsIdentity
  runtimeTarget : RuntimeMountTarget
  observedContext : ReceiptValidationContext
  runtimeEpoch : Nat
  activeFenceToken : Nat
  preStateIdentity : RuntimeStateIdentity
  postStateIdentity : RuntimeStateIdentity
  effectIdentity : MaterializationEffectIdentity
  committed : Bool

structure SandboxMaterializationExecutionClosure
    (currentContext : ReceiptValidationContext)
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (effectSemantics : MaterializationEffectSemantics)
    (admission : MaterializationAdmission)
    (request : SandboxMaterializationExecutionRequest)
    (receipt : SandboxMaterializationExecutionReceipt) : Prop where
  admissionClosed :
    MaterializationAdmissionClosure
      currentContext recipe policy admission request.materializationReceipt
  requestAdmissionIdentityBound : request.admissionIdentity = admission.identity
  requestContextBound : request.expectedContext = currentContext
  requestEffectSemanticsBound :
    request.effectSemanticsIdentity = effectSemantics.identity
  transactionIdentityBound :
    receipt.transactionIdentity = request.transactionIdentity
  receiptAdmissionIdentityBound : receipt.admissionIdentity = admission.identity
  recipeIdentityBound :
    receipt.recipeIdentity = request.materializationReceipt.recipeIdentity
  backendIdentityBound :
    receipt.backendIdentity = request.materializationReceipt.backendIdentity
  policyIdentityBound :
    receipt.policyIdentity = request.materializationReceipt.policyIdentity
  receiptEffectSemanticsBound :
    receipt.effectSemanticsIdentity = effectSemantics.identity
  runtimeTargetBound :
    receipt.runtimeTarget = request.materializationReceipt.runtimeTarget
  executionContextBound : receipt.observedContext = currentContext
  runtimeEpochBound : receipt.runtimeEpoch = request.runtimeEpoch
  activeFenceTokenBound :
    receipt.activeFenceToken = request.activeFenceToken
  preStateBound : receipt.preStateIdentity = request.expectedPreStateIdentity
  postStateBound :
    receipt.postStateIdentity =
      effectSemantics.postStateFor
        request.expectedPreStateIdentity
        request.materializationReceipt.backendIdentity
        request.materializationReceipt.runtimeTarget
  effectIdentityBound :
    receipt.effectIdentity =
      effectSemantics.effectIdentityFor
        request.transactionIdentity
        request.materializationReceipt.backendIdentity
        request.materializationReceipt.runtimeTarget
  committed : receipt.committed = true

def admissionAndCommittedOnly
    (currentContext : ReceiptValidationContext)
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (admission : MaterializationAdmission)
    (request : SandboxMaterializationExecutionRequest)
    (receipt : SandboxMaterializationExecutionReceipt) : Prop :=
  MaterializationAdmissionClosure
      currentContext recipe policy admission request.materializationReceipt ∧
  receipt.committed = true

def forgeExecutionReceipt
    (request : SandboxMaterializationExecutionRequest)
    (substitutedTarget : RuntimeMountTarget)
    (substitutedContext : ReceiptValidationContext) :
    SandboxMaterializationExecutionReceipt :=
  { transactionIdentity := request.transactionIdentity
    admissionIdentity := request.admissionIdentity
    recipeIdentity := request.materializationReceipt.recipeIdentity
    backendIdentity := request.materializationReceipt.backendIdentity
    policyIdentity := request.materializationReceipt.policyIdentity
    effectSemanticsIdentity := request.effectSemanticsIdentity
    runtimeTarget := substitutedTarget
    observedContext := substitutedContext
    runtimeEpoch := request.runtimeEpoch
    activeFenceToken := request.activeFenceToken
    preStateIdentity := request.expectedPreStateIdentity
    postStateIdentity := request.expectedPreStateIdentity
    effectIdentity := ""
    committed := true }

theorem admissionAndCommittedOnlyPermitTargetAndContextSubstitution
    (currentContext : ReceiptValidationContext)
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (admission : MaterializationAdmission)
    (request : SandboxMaterializationExecutionRequest)
    (admissionClosed :
      MaterializationAdmissionClosure
        currentContext recipe policy admission request.materializationReceipt)
    (substitutedTarget : RuntimeMountTarget)
    (targetDiffers :
      substitutedTarget ≠ request.materializationReceipt.runtimeTarget)
    (substitutedContext : ReceiptValidationContext)
    (contextDiffers : substitutedContext ≠ currentContext) :
    admissionAndCommittedOnly
      currentContext recipe policy admission request
      (forgeExecutionReceipt request substitutedTarget substitutedContext) ∧
    (forgeExecutionReceipt request substitutedTarget
      substitutedContext).runtimeTarget ≠
      request.materializationReceipt.runtimeTarget ∧
    (forgeExecutionReceipt request substitutedTarget
      substitutedContext).observedContext ≠ currentContext := by
  exact ⟨⟨admissionClosed, rfl⟩, targetDiffers, contextDiffers⟩

def admittedTargetContextAndCommitOnly
    (currentContext : ReceiptValidationContext)
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (admission : MaterializationAdmission)
    (request : SandboxMaterializationExecutionRequest)
    (receipt : SandboxMaterializationExecutionReceipt) : Prop :=
  MaterializationAdmissionClosure
      currentContext recipe policy admission request.materializationReceipt ∧
  request.expectedContext = currentContext ∧
  receipt.runtimeTarget = request.materializationReceipt.runtimeTarget ∧
  receipt.observedContext = currentContext ∧
  receipt.committed = true

def forgeEffectReceipt
    (request : SandboxMaterializationExecutionRequest)
    (substitutedPostState : RuntimeStateIdentity)
    (substitutedEffectIdentity : MaterializationEffectIdentity) :
    SandboxMaterializationExecutionReceipt :=
  { transactionIdentity := request.transactionIdentity
    admissionIdentity := request.admissionIdentity
    recipeIdentity := request.materializationReceipt.recipeIdentity
    backendIdentity := request.materializationReceipt.backendIdentity
    policyIdentity := request.materializationReceipt.policyIdentity
    effectSemanticsIdentity := request.effectSemanticsIdentity
    runtimeTarget := request.materializationReceipt.runtimeTarget
    observedContext := request.expectedContext
    runtimeEpoch := request.runtimeEpoch
    activeFenceToken := request.activeFenceToken
    preStateIdentity := request.expectedPreStateIdentity
    postStateIdentity := substitutedPostState
    effectIdentity := substitutedEffectIdentity
    committed := true }

theorem admittedTargetContextAndCommitPermitEffectSubstitution
    (currentContext : ReceiptValidationContext)
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (effectSemantics : MaterializationEffectSemantics)
    (admission : MaterializationAdmission)
    (request : SandboxMaterializationExecutionRequest)
    (admissionClosed :
      MaterializationAdmissionClosure
        currentContext recipe policy admission request.materializationReceipt)
    (requestContextBound : request.expectedContext = currentContext)
    (substitutedPostState : RuntimeStateIdentity)
    (postStateDiffers :
      substitutedPostState ≠
        effectSemantics.postStateFor
          request.expectedPreStateIdentity
          request.materializationReceipt.backendIdentity
          request.materializationReceipt.runtimeTarget)
    (substitutedEffectIdentity : MaterializationEffectIdentity)
    (effectIdentityDiffers :
      substitutedEffectIdentity ≠
        effectSemantics.effectIdentityFor
          request.transactionIdentity
          request.materializationReceipt.backendIdentity
          request.materializationReceipt.runtimeTarget) :
    admittedTargetContextAndCommitOnly
      currentContext recipe policy admission request
      (forgeEffectReceipt request substitutedPostState
        substitutedEffectIdentity) ∧
    (forgeEffectReceipt request substitutedPostState
      substitutedEffectIdentity).postStateIdentity ≠
        effectSemantics.postStateFor
          request.expectedPreStateIdentity
          request.materializationReceipt.backendIdentity
          request.materializationReceipt.runtimeTarget ∧
    (forgeEffectReceipt request substitutedPostState
      substitutedEffectIdentity).effectIdentity ≠
        effectSemantics.effectIdentityFor
          request.transactionIdentity
          request.materializationReceipt.backendIdentity
          request.materializationReceipt.runtimeTarget := by
  exact
    ⟨⟨admissionClosed, requestContextBound, rfl, requestContextBound, rfl⟩,
      postStateDiffers, effectIdentityDiffers⟩

def commitMaterialization
    (request : SandboxMaterializationExecutionRequest)
    (effectSemantics : MaterializationEffectSemantics) :
    SandboxMaterializationExecutionReceipt :=
  { transactionIdentity := request.transactionIdentity
    admissionIdentity := request.admissionIdentity
    recipeIdentity := request.materializationReceipt.recipeIdentity
    backendIdentity := request.materializationReceipt.backendIdentity
    policyIdentity := request.materializationReceipt.policyIdentity
    effectSemanticsIdentity := effectSemantics.identity
    runtimeTarget := request.materializationReceipt.runtimeTarget
    observedContext := request.expectedContext
    runtimeEpoch := request.runtimeEpoch
    activeFenceToken := request.activeFenceToken
    preStateIdentity := request.expectedPreStateIdentity
    postStateIdentity :=
      effectSemantics.postStateFor
        request.expectedPreStateIdentity
        request.materializationReceipt.backendIdentity
        request.materializationReceipt.runtimeTarget
    effectIdentity :=
      effectSemantics.effectIdentityFor
        request.transactionIdentity
        request.materializationReceipt.backendIdentity
        request.materializationReceipt.runtimeTarget
    committed := true }

theorem executionBuiltFromExactAdmissionIsClosed
    (currentContext : ReceiptValidationContext)
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (effectSemantics : MaterializationEffectSemantics)
    (admission : MaterializationAdmission)
    (request : SandboxMaterializationExecutionRequest)
    (admissionClosed :
      MaterializationAdmissionClosure
        currentContext recipe policy admission request.materializationReceipt)
    (requestAdmissionBound : request.admissionIdentity = admission.identity)
    (requestContextBound : request.expectedContext = currentContext)
    (requestEffectSemanticsBound :
      request.effectSemanticsIdentity = effectSemantics.identity) :
    SandboxMaterializationExecutionClosure
      currentContext recipe policy effectSemantics admission request
      (commitMaterialization request effectSemantics) := by
  constructor
  · exact admissionClosed
  · exact requestAdmissionBound
  · exact requestContextBound
  · exact requestEffectSemanticsBound
  · rfl
  · exact requestAdmissionBound
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · exact requestContextBound
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl

theorem exactExecutionClosureRejectsTargetSubstitution
    (currentContext : ReceiptValidationContext)
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (effectSemantics : MaterializationEffectSemantics)
    (admission : MaterializationAdmission)
    (request : SandboxMaterializationExecutionRequest)
    (substitutedTarget : RuntimeMountTarget)
    (targetDiffers :
      substitutedTarget ≠ request.materializationReceipt.runtimeTarget)
    (substitutedContext : ReceiptValidationContext) :
    ¬ SandboxMaterializationExecutionClosure
      currentContext recipe policy effectSemantics admission request
      (forgeExecutionReceipt request substitutedTarget substitutedContext) := by
  intro closed
  exact targetDiffers closed.runtimeTargetBound

theorem exactExecutionClosureRejectsContextSubstitution
    (currentContext : ReceiptValidationContext)
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (effectSemantics : MaterializationEffectSemantics)
    (admission : MaterializationAdmission)
    (request : SandboxMaterializationExecutionRequest)
    (substitutedTarget : RuntimeMountTarget)
    (substitutedContext : ReceiptValidationContext)
    (contextDiffers : substitutedContext ≠ currentContext) :
    ¬ SandboxMaterializationExecutionClosure
      currentContext recipe policy effectSemantics admission request
      (forgeExecutionReceipt request substitutedTarget substitutedContext) := by
  intro closed
  exact contextDiffers closed.executionContextBound

theorem exactExecutionClosureRejectsPostStateSubstitution
    (currentContext : ReceiptValidationContext)
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (effectSemantics : MaterializationEffectSemantics)
    (admission : MaterializationAdmission)
    (request : SandboxMaterializationExecutionRequest)
    (substitutedPostState : RuntimeStateIdentity)
    (postStateDiffers :
      substitutedPostState ≠
        effectSemantics.postStateFor
          request.expectedPreStateIdentity
          request.materializationReceipt.backendIdentity
          request.materializationReceipt.runtimeTarget)
    (substitutedEffectIdentity : MaterializationEffectIdentity) :
    ¬ SandboxMaterializationExecutionClosure
      currentContext recipe policy effectSemantics admission request
      (forgeEffectReceipt request substitutedPostState
        substitutedEffectIdentity) := by
  intro closed
  exact postStateDiffers closed.postStateBound

theorem exactExecutionClosureRejectsEffectIdentitySubstitution
    (currentContext : ReceiptValidationContext)
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (effectSemantics : MaterializationEffectSemantics)
    (admission : MaterializationAdmission)
    (request : SandboxMaterializationExecutionRequest)
    (substitutedPostState : RuntimeStateIdentity)
    (substitutedEffectIdentity : MaterializationEffectIdentity)
    (effectIdentityDiffers :
      substitutedEffectIdentity ≠
        effectSemantics.effectIdentityFor
          request.transactionIdentity
          request.materializationReceipt.backendIdentity
          request.materializationReceipt.runtimeTarget) :
    ¬ SandboxMaterializationExecutionClosure
      currentContext recipe policy effectSemantics admission request
      (forgeEffectReceipt request substitutedPostState
        substitutedEffectIdentity) := by
  intro closed
  exact effectIdentityDiffers closed.effectIdentityBound

theorem closedExecutionConsumesTheExactAdmissionIdentity
    (currentContext : ReceiptValidationContext)
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (effectSemantics : MaterializationEffectSemantics)
    (admission : MaterializationAdmission)
    (request : SandboxMaterializationExecutionRequest)
    (receipt : SandboxMaterializationExecutionReceipt)
    (closed :
      SandboxMaterializationExecutionClosure
        currentContext recipe policy effectSemantics admission request receipt) :
    receipt.admissionIdentity = admission.identity :=
  closed.receiptAdmissionIdentityBound

theorem closedExecutionConsumesTheExactResolvedTarget
    (currentContext : ReceiptValidationContext)
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (effectSemantics : MaterializationEffectSemantics)
    (admission : MaterializationAdmission)
    (request : SandboxMaterializationExecutionRequest)
    (receipt : SandboxMaterializationExecutionReceipt)
    (closed :
      SandboxMaterializationExecutionClosure
        currentContext recipe policy effectSemantics admission request receipt) :
    receipt.runtimeTarget =
      policy.targetFor recipe.backendIdentity recipe.resourceRole := by
  exact closed.runtimeTargetBound.trans
    closed.admissionClosed.backendPolicyClosed.2.2

theorem closedExecutionProducesTheSemanticsOwnedPostState
    (currentContext : ReceiptValidationContext)
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (effectSemantics : MaterializationEffectSemantics)
    (admission : MaterializationAdmission)
    (request : SandboxMaterializationExecutionRequest)
    (receipt : SandboxMaterializationExecutionReceipt)
    (closed :
      SandboxMaterializationExecutionClosure
        currentContext recipe policy effectSemantics admission request receipt) :
    receipt.postStateIdentity =
      effectSemantics.postStateFor
        request.expectedPreStateIdentity
        request.materializationReceipt.backendIdentity
        request.materializationReceipt.runtimeTarget :=
  closed.postStateBound

theorem closedExecutionProducesTheSemanticsOwnedEffectIdentity
    (currentContext : ReceiptValidationContext)
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (effectSemantics : MaterializationEffectSemantics)
    (admission : MaterializationAdmission)
    (request : SandboxMaterializationExecutionRequest)
    (receipt : SandboxMaterializationExecutionReceipt)
    (closed :
      SandboxMaterializationExecutionClosure
        currentContext recipe policy effectSemantics admission request receipt) :
    receipt.effectIdentity =
      effectSemantics.effectIdentityFor
        request.transactionIdentity
        request.materializationReceipt.backendIdentity
        request.materializationReceipt.runtimeTarget :=
  closed.effectIdentityBound

end AgenticAILabProof.Enterprise.SandboxProfileMaterializationExecutionBindingClosure
