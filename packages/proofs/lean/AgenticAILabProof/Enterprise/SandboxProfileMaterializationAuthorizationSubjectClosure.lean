-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SandboxProfileMaterializationAuthorizationSubjectModel
import AgenticAILabProof.Enterprise.SandboxProfileMaterializationReplayClosure
import AgenticAILabProof.Enterprise.ReceiptAuthorityBindingClosure
import AgenticAILabProof.Enterprise.ReceiptContextCheckpointClosure
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeModel
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeCore

namespace AgenticAILabProof.Enterprise.SandboxProfileMaterializationAuthorizationSubjectClosure

open AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure
open AgenticAILabProof.Enterprise.ReceiptAuthorityBindingClosure
open AgenticAILabProof.Enterprise.ReceiptContextCheckpointClosure
open AgenticAILabProof.Enterprise.SandboxProfileRecipePortabilityClosure
open AgenticAILabProof.Enterprise.SandboxProfileMaterializationExecutionBindingClosure
open AgenticAILabProof.Enterprise.SandboxProfileMaterializationReplayClosure
open AgenticAILabProof.Enterprise.SourceBoundCompositionalEffectClosure
open AgenticAILabProof.Enterprise.SourceBoundCheckpointRestoreAuthorizationClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectReplayIdempotencyClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionPublicationClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeModel
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeCore
open AgenticAILabProof.Enterprise.CedarDualEngineAuthorization
open AgenticAILabProof.Enterprise.SandboxProfileMaterializationAuthorizationSubjectModel

abbrev SandboxMaterializationAuthorizationSubjectProjection :=
  AuthorizationSubjectProjection
    CompositionObjectSubject
    BackendMaterializationReceipt
    ReceiptValidationContext
    AuthorizationSubject

abbrev SandboxMaterializationAuthorizationSubjectProjectionRegistry :=
  AuthorizationSubjectProjectionRegistry
    Nat
    CompositionObjectSubject
    BackendMaterializationReceipt
    ReceiptValidationContext
    AuthorizationSubject

structure SandboxMaterializationLiveAuthorityContextBinding
    (currentContext : ReceiptValidationContext) where
  domain : AuthoritativeContextPublicationDomain
  watermark : TrustedCheckpointWatermark
  authority : LiveCheckpointAttestationAuthority domain
  attestation : DeclaredCheckpointAttestation domain
  attestationAdmitted :
    authorityIssuedCheckpointCurrentForAdmission
      watermark
      authority
      attestation
  attestedContextBound :
    currentContext = attestation.checkpoint.head.context

theorem liveAuthorityContextBindingSelectsCurrentHead
    {currentContext : ReceiptValidationContext}
    (binding : SandboxMaterializationLiveAuthorityContextBinding currentContext) :
    currentContext = binding.authority.currentCheckpoint.head.context := by
  exact
    binding.attestedContextBound.trans
      (authorityIssuedAttestationEstablishesCurrentHead
        binding.attestationAdmitted)

structure SandboxMaterializationAuthorizationSubjectProjectionRegistryBinding
    (currentContext : ReceiptValidationContext) where
  liveContext : SandboxMaterializationLiveAuthorityContextBinding currentContext
  registry : SandboxMaterializationAuthorizationSubjectProjectionRegistry
  authority :
    AcceptanceAuthority
      ReceiptValidationContext
      SandboxMaterializationAuthorizationSubjectProjectionRegistry
  node :
    AuthorityBoundNode
      ReceiptValidationContext
      SandboxMaterializationAuthorizationSubjectProjectionRegistry
      authority
  artifactBound :
    node.artifact = currentContext
  bindingBound : node.nodeBinding = registry

theorem authorityBoundProjectionRegistryIsAccepted
    {currentContext : ReceiptValidationContext}
    (binding :
      SandboxMaterializationAuthorizationSubjectProjectionRegistryBinding
        currentContext) :
    binding.authority.accepted binding.registry := by
  have nodeAccepted :=
    authorityValidatedNodeIsAccepted binding.authority binding.node
  simpa [binding.bindingBound] using nodeAccepted

def SandboxMaterializationCedarLifecycleFreshnessBridge
    (lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence)
    (executionReceipt : SandboxMaterializationExecutionReceipt) : Prop :=
  ∃ authorization : RecoveryAuthorization,
    ∃ expectation : RecoveryExpectation,
      RecoveryAuthorizationFresh authorization expectation ∧
        authorization.commitment = lifecycle.commitment ∧
        authorization.authorityIdentity = lifecycle.authorityIdentity ∧
        authorization.accountabilityIdentity = lifecycle.accountabilityIdentity ∧
        authorization.responsibilityScopeDigest =
          lifecycle.responsibilityScopeDigest ∧
        authorization.runtimeEpoch = lifecycle.runtimeEpoch ∧
        authorization.activeFenceToken = lifecycle.activeFenceToken ∧
        expectation.runtimeEpoch = executionReceipt.runtimeEpoch ∧
        expectation.activeFenceToken = executionReceipt.activeFenceToken

theorem cedarLifecycleFreshnessBindsExecutionGeneration
    {lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {executionReceipt : SandboxMaterializationExecutionReceipt}
    (binding :
      SandboxMaterializationCedarLifecycleFreshnessBridge
        lifecycle
        executionReceipt) :
    lifecycle.runtimeEpoch = executionReceipt.runtimeEpoch ∧
      lifecycle.activeFenceToken = executionReceipt.activeFenceToken := by
  rcases binding with
    ⟨authorization, expectation, authorizationFresh, _, _, _, _,
      authorizationEpochBound, authorizationFenceBound,
      expectationEpochBound, expectationFenceBound⟩
  rcases authorizationFresh with ⟨_, epochFresh, fenceFresh⟩
  exact
    ⟨authorizationEpochBound.symm.trans
        (epochFresh.trans expectationEpochBound),
      authorizationFenceBound.symm.trans
        (fenceFresh.trans expectationFenceBound)⟩

structure SandboxMaterializationAuthorizationSubjectBridge
    (projection : SandboxMaterializationAuthorizationSubjectProjection)
    (currentContext : ReceiptValidationContext)
    (projectionRegistryBinding :
      SandboxMaterializationAuthorizationSubjectProjectionRegistryBinding
        currentContext)
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy)
    (effectSemantics : MaterializationEffectSemantics)
    (admission : MaterializationAdmission)
    (executionRequest : SandboxMaterializationExecutionRequest)
    (executionReceipt : SandboxMaterializationExecutionReceipt)
    (completionReceiptValid : SourceBoundEffectCompletionReceiptValid)
    (restoreRequest : SourceBoundLatestCheckpointRestoreRequest)
    (window : SourceBoundEffectReplayWindow)
    (plan : SourceBoundEffectReplayPlan)
    (beforeEntry afterEntry : SourceBoundEffectReplayLedgerEntry)
    (step : SourceBoundEffectReplayStep)
    (completionReceipt : SourceBoundEffectCompletionReceipt)
    (snapshotSubjectBindingValid :
      SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid)
    (semantics : DecisionSemantics)
    (decisionReceiptValid : DecisionReceiptValid)
    (dualDecisionIdentityValid :
      SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid)
    (authorityPathAuthorized :
      String → String → String → String → Prop)
    (separationOfDutySatisfied :
      String → String → String → Prop)
    (expectedAuthority expectedCommitment : String)
    (expectedBundle : BundleEvidenceBinding.BundleDigest)
    (lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence)
    (authorizationSubject : AuthorizationSubject)
    (left right : DecisionReceipt) : Prop where
  replayClosed :
    SandboxMaterializationReplayBridge
      currentContext
      recipe
      policy
      effectSemantics
      admission
      executionRequest
      executionReceipt
      completionReceiptValid
      restoreRequest
      window
      plan
      beforeEntry
      afterEntry
      step
      completionReceipt
  cedarSubjectClosed :
    SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridge
      snapshotSubjectBindingValid
      semantics
      decisionReceiptValid
      dualDecisionIdentityValid
      authorityPathAuthorized
      separationOfDutySatisfied
      expectedAuthority
      expectedCommitment
      expectedBundle
      lifecycle
      authorizationSubject
      left
      right
  cedarLifecycleFresh :
    SandboxMaterializationCedarLifecycleFreshnessBridge
      lifecycle
      executionReceipt
  authorizationSubjectProjected :
    authorizationSubject =
      projection.project
        step.observation.event.ownerSubject
        executionRequest.materializationReceipt
        currentContext
  projectionRegisteredAtCurrentAuthorizationSnapshot :
    projectionRegisteredAt
      projectionRegistryBinding.registry
      currentContext.authorizationSnapshotIdentity
      projection

theorem closedBridgeBindsBothCedarEnginesToReplayOwner
    {projection : SandboxMaterializationAuthorizationSubjectProjection}
    {currentContext : ReceiptValidationContext}
    {projectionRegistryBinding :
      SandboxMaterializationAuthorizationSubjectProjectionRegistryBinding
        currentContext}
    {recipe : PortableRecipe}
    {policy : BackendMaterializationPolicy}
    {effectSemantics : MaterializationEffectSemantics}
    {admission : MaterializationAdmission}
    {executionRequest : SandboxMaterializationExecutionRequest}
    {executionReceipt : SandboxMaterializationExecutionReceipt}
    {completionReceiptValid : SourceBoundEffectCompletionReceiptValid}
    {restoreRequest : SourceBoundLatestCheckpointRestoreRequest}
    {window : SourceBoundEffectReplayWindow}
    {plan : SourceBoundEffectReplayPlan}
    {beforeEntry afterEntry : SourceBoundEffectReplayLedgerEntry}
    {step : SourceBoundEffectReplayStep}
    {completionReceipt : SourceBoundEffectCompletionReceipt}
    {snapshotSubjectBindingValid :
      SourceBoundEffectCompletionRecoveryCedarSnapshotSubjectBindingValid}
    {semantics : DecisionSemantics}
    {decisionReceiptValid : DecisionReceiptValid}
    {dualDecisionIdentityValid :
      SourceBoundEffectCompletionRecoveryCedarDualDecisionIdentityValid}
    {authorityPathAuthorized :
      String → String → String → String → Prop}
    {separationOfDutySatisfied :
      String → String → String → Prop}
    {expectedAuthority expectedCommitment : String}
    {expectedBundle : BundleEvidenceBinding.BundleDigest}
    {lifecycle :
      SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence}
    {authorizationSubject : AuthorizationSubject}
    {left right : DecisionReceipt}
    (closed :
      SandboxMaterializationAuthorizationSubjectBridge
        projection
        currentContext
        projectionRegistryBinding
        recipe
        policy
        effectSemantics
        admission
        executionRequest
        executionReceipt
        completionReceiptValid
        restoreRequest
        window
        plan
        beforeEntry
        afterEntry
        step
        completionReceipt
        snapshotSubjectBindingValid
        semantics
        decisionReceiptValid
        dualDecisionIdentityValid
        authorityPathAuthorized
        separationOfDutySatisfied
        expectedAuthority
        expectedCommitment
        expectedBundle
        lifecycle
        authorizationSubject
        left
        right) :
    left.subject =
        projection.project
          step.observation.event.ownerSubject
          executionRequest.materializationReceipt
          currentContext ∧
      right.subject =
        projection.project
          step.observation.event.ownerSubject
          executionRequest.materializationReceipt
          currentContext := by
  have exactSubjects :=
    closedSubjectBridgeProvidesExactSubject closed.cedarSubjectClosed
  exact
    dualEngineSubjectsBindProjectedOwner
      projection
      step.observation.event.ownerSubject
      executionRequest.materializationReceipt
      currentContext
      authorizationSubject
      left.subject
      right.subject
      exactSubjects.1
      exactSubjects.2
      closed.authorizationSubjectProjected

end AgenticAILabProof.Enterprise.SandboxProfileMaterializationAuthorizationSubjectClosure
