-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleClosure
import AgenticAILabProof.Enterprise.UseCompositionCedarCapabilityGrantClosure
import AgenticAILabProof.Enterprise.UseCompositionCedarLifecycleRegistryJoinModel

namespace AgenticAILabProof.Enterprise.UseCompositionCedarFullLifecycleRegistryJoinClosure

open AgenticAILabProof.Enterprise.ReceiptAuthorityBindingClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryConvergenceClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryProgressEvidenceClosure
open AgenticAILabProof.Enterprise.UseCompositionCedarCapabilityGrantClosure

abbrev CompositionDecisionSemantics :=
  AgenticAILabProof.Enterprise.CedarDualEngineAuthorization.DecisionSemantics

abbrev CompositionDecisionReceiptValid :=
  AgenticAILabProof.Enterprise.CedarDualEngineAuthorization.DecisionReceiptValid

abbrev CompositionDecisionReceipt :=
  AgenticAILabProof.Enterprise.CedarDualEngineAuthorization.DecisionReceipt

/-!
Packages the large source-bound lifecycle witness behind one dependent
selection.  Composition consumes the package; it does not duplicate its
commitment, signature, registry, recovery, or Cedar semantics.
-/

structure FullCedarLifecycleSelection where
  trace : SourceBoundEffectCompletionRecoveryTrace
  budgets : Nat → SourceBoundEffectCompletionRecoveryProgressBudget
  scopes : Nat → SourceBoundEffectCompletionRecoveryProgressScope
  providerAcknowledgementStable : Nat → Prop
  expectations : Nat → SourceBoundEffectCompletionRecoveryExpectation
  witnesses : Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness
  scheme : SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentScheme
  signatureVerified : String → String → String → Prop
  registry :
    String → SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence
  authorityPathAuthorized : String → String → String → String → Prop
  separationOfDutySatisfied : String → String → String → Prop
  envelopes :
    Nat → SourceBoundEffectCompletionRecoveryOwnerAuditCommitmentEnvelope
  authenticityEvidence :
    Nat → SourceBoundEffectCompletionRecoveryOwnerAuditAuthenticityEvidence
  lifecycleEvidence :
    SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleEvidence
      trace budgets scopes providerAcknowledgementStable expectations
      witnesses scheme signatureVerified registry
      authorityPathAuthorized separationOfDutySatisfied
      envelopes authenticityEvidence
  index : Nat
  notCommitted : trace index ≠ .committed

theorem fullCedarLifecycleSelectionAuthorizationAdmitted
    (selection : FullCedarLifecycleSelection) :
    (selection.registry
      (selection.envelopes selection.index).commitment).Admitted
        selection.authorityPathAuthorized
        selection.separationOfDutySatisfied
        (selection.authenticityEvidence selection.index).authorityIdentity
        (selection.envelopes selection.index).commitment :=
  closedCedarLifecycleAuthorizationAdmitted
    selection.lifecycleEvidence selection.notCommitted

structure CompositionFullLifecycleGrantReceipt where
  receiptIdentity : String
  deriving DecidableEq

structure CompositionFullLifecycleGrantBinding where
  grant : CompositionCapabilityGrant
  lifecycleEvidence :
    SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence
  inputIdentitySemanticIdentity : String
  inputIdentityGeneration : Nat

abbrev CompositionFullLifecycleGrantAcceptanceAuthority :=
  AcceptanceAuthority
    CompositionFullLifecycleGrantReceipt
    CompositionFullLifecycleGrantBinding

abbrev CompositionFullLifecycleGrantAuthorityBoundNode
    (authority : CompositionFullLifecycleGrantAcceptanceAuthority) :=
  AuthorityBoundNode
    CompositionFullLifecycleGrantReceipt
    CompositionFullLifecycleGrantBinding
    authority

theorem fullLifecycleGrantAuthorityBoundNodeAccepted
    {authority : CompositionFullLifecycleGrantAcceptanceAuthority}
    (node : CompositionFullLifecycleGrantAuthorityBoundNode authority) :
    authority.accepted node.nodeBinding := by
  have accepted := authority.sound
    node.artifact node.validatedBinding node.validation
  rw [node.exactBinding] at accepted
  exact accepted

structure CompositionCedarFullLifecycleRegistryJoinClosed
    (semantics : CompositionDecisionSemantics)
    (decisionValid : CompositionDecisionReceiptValid)
    (bridgeAuthority : SubjectContextBridgeAcceptanceAuthority)
    (bridgeNode : SubjectContextBridgeAuthorityBoundNode bridgeAuthority)
    (request : CompositionCapabilityRequest)
    (grant : CompositionCapabilityGrant)
    (left right : CompositionDecisionReceipt)
    (fullLifecycleAuthority :
      CompositionFullLifecycleGrantAcceptanceAuthority)
    (fullLifecycleNode :
      CompositionFullLifecycleGrantAuthorityBoundNode fullLifecycleAuthority)
    (selection : FullCedarLifecycleSelection) : Prop where
  grantClosed :
    CompositionCedarGrantClosed
      semantics decisionValid bridgeAuthority bridgeNode
      request grant left right
  lifecycleBindingAccepted :
    fullLifecycleAuthority.accepted fullLifecycleNode.nodeBinding
  lifecycleGrantBound : fullLifecycleNode.nodeBinding.grant = grant
  selectedLifecycleEvidenceBound :
    fullLifecycleNode.nodeBinding.lifecycleEvidence =
      selection.registry (selection.envelopes selection.index).commitment
  subjectEpochBound :
    request.authorizationSubject.epoch = request.runtimeGeneration
  requestRuntimeEpochBound :
    (selection.envelopes selection.index).payload.runtimeEpoch =
      request.runtimeGeneration

theorem closedFullLifecycleJoinUsesAuthorityValidatedBinding
    {semantics : CompositionDecisionSemantics}
    {decisionValid : CompositionDecisionReceiptValid}
    {bridgeAuthority : SubjectContextBridgeAcceptanceAuthority}
    {bridgeNode : SubjectContextBridgeAuthorityBoundNode bridgeAuthority}
    {request : CompositionCapabilityRequest}
    {grant : CompositionCapabilityGrant}
    {left right : CompositionDecisionReceipt}
    {fullLifecycleAuthority :
      CompositionFullLifecycleGrantAcceptanceAuthority}
    {fullLifecycleNode :
      CompositionFullLifecycleGrantAuthorityBoundNode fullLifecycleAuthority}
    {selection : FullCedarLifecycleSelection}
    (closed :
      CompositionCedarFullLifecycleRegistryJoinClosed
        semantics decisionValid bridgeAuthority bridgeNode request grant
        left right fullLifecycleAuthority fullLifecycleNode selection) :
    fullLifecycleAuthority.accepted fullLifecycleNode.nodeBinding ∧
      fullLifecycleNode.nodeBinding.grant = grant :=
  ⟨closed.lifecycleBindingAccepted, closed.lifecycleGrantBound⟩

theorem closedFullLifecycleJoinProvidesRegistryAdmission
    {semantics : CompositionDecisionSemantics}
    {decisionValid : CompositionDecisionReceiptValid}
    {bridgeAuthority : SubjectContextBridgeAcceptanceAuthority}
    {bridgeNode : SubjectContextBridgeAuthorityBoundNode bridgeAuthority}
    {request : CompositionCapabilityRequest}
    {grant : CompositionCapabilityGrant}
    {left right : CompositionDecisionReceipt}
    {fullLifecycleAuthority :
      CompositionFullLifecycleGrantAcceptanceAuthority}
    {fullLifecycleNode :
      CompositionFullLifecycleGrantAuthorityBoundNode fullLifecycleAuthority}
    {selection : FullCedarLifecycleSelection}
    (_closed :
      CompositionCedarFullLifecycleRegistryJoinClosed
        semantics decisionValid bridgeAuthority bridgeNode request grant
        left right fullLifecycleAuthority fullLifecycleNode selection) :
    (selection.registry
      (selection.envelopes selection.index).commitment).Admitted
        selection.authorityPathAuthorized
        selection.separationOfDutySatisfied
        (selection.authenticityEvidence selection.index).authorityIdentity
        (selection.envelopes selection.index).commitment :=
  fullCedarLifecycleSelectionAuthorizationAdmitted selection

theorem closedFullLifecycleJoinRejectsUnselectedEvidence
    {semantics : CompositionDecisionSemantics}
    {decisionValid : CompositionDecisionReceiptValid}
    {bridgeAuthority : SubjectContextBridgeAcceptanceAuthority}
    {bridgeNode : SubjectContextBridgeAuthorityBoundNode bridgeAuthority}
    {request : CompositionCapabilityRequest}
    {grant : CompositionCapabilityGrant}
    {left right : CompositionDecisionReceipt}
    {fullLifecycleAuthority :
      CompositionFullLifecycleGrantAcceptanceAuthority}
    {fullLifecycleNode :
      CompositionFullLifecycleGrantAuthorityBoundNode fullLifecycleAuthority}
    {selection : FullCedarLifecycleSelection}
    (closed :
      CompositionCedarFullLifecycleRegistryJoinClosed
        semantics decisionValid bridgeAuthority bridgeNode request grant
        left right fullLifecycleAuthority fullLifecycleNode selection)
    (mismatch :
      fullLifecycleNode.nodeBinding.lifecycleEvidence ≠
        selection.registry
          (selection.envelopes selection.index).commitment) : False :=
  mismatch closed.selectedLifecycleEvidenceBound

theorem closedFullLifecycleJoinBindsRuntimeAndFence
    {semantics : CompositionDecisionSemantics}
    {decisionValid : CompositionDecisionReceiptValid}
    {bridgeAuthority : SubjectContextBridgeAcceptanceAuthority}
    {bridgeNode : SubjectContextBridgeAuthorityBoundNode bridgeAuthority}
    {request : CompositionCapabilityRequest}
    {grant : CompositionCapabilityGrant}
    {left right : CompositionDecisionReceipt}
    {fullLifecycleAuthority :
      CompositionFullLifecycleGrantAcceptanceAuthority}
    {fullLifecycleNode :
      CompositionFullLifecycleGrantAuthorityBoundNode fullLifecycleAuthority}
    {selection : FullCedarLifecycleSelection}
    (closed :
      CompositionCedarFullLifecycleRegistryJoinClosed
        semantics decisionValid bridgeAuthority bridgeNode request grant
        left right fullLifecycleAuthority fullLifecycleNode selection) :
    fullLifecycleNode.nodeBinding.lifecycleEvidence.runtimeEpoch =
        request.runtimeGeneration ∧
      fullLifecycleNode.nodeBinding.lifecycleEvidence.activeFenceToken =
        (selection.envelopes selection.index).payload.activeFenceToken := by
  have bindings :=
    selection.lifecycleEvidence.cedarBindings
      selection.index selection.notCommitted
  constructor
  · calc
      fullLifecycleNode.nodeBinding.lifecycleEvidence.runtimeEpoch =
          (selection.registry
            (selection.envelopes selection.index).commitment).runtimeEpoch := by
        rw [closed.selectedLifecycleEvidenceBound]
      _ = (selection.envelopes selection.index).payload.runtimeEpoch :=
        bindings.2.2.2.2.2.1
      _ = request.runtimeGeneration := closed.requestRuntimeEpochBound
  · calc
      fullLifecycleNode.nodeBinding.lifecycleEvidence.activeFenceToken =
          (selection.registry
            (selection.envelopes selection.index).commitment).activeFenceToken := by
        rw [closed.selectedLifecycleEvidenceBound]
      _ = (selection.envelopes selection.index).payload.activeFenceToken :=
        bindings.2.2.2.2.2.2

end AgenticAILabProof.Enterprise.UseCompositionCedarFullLifecycleRegistryJoinClosure
