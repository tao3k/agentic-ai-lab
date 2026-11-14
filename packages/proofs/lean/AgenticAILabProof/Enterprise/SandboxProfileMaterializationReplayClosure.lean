-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SandboxProfileMaterializationExecutionBindingClosure
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionPublicationClosure

namespace AgenticAILabProof.Enterprise.SandboxProfileMaterializationReplayClosure

open AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure
open AgenticAILabProof.Enterprise.SandboxProfileRecipePortabilityClosure
open AgenticAILabProof.Enterprise.SandboxProfileMaterializationExecutionBindingClosure
open AgenticAILabProof.Enterprise.SourceBoundCheckpointRestoreAuthorizationClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectReplayIdempotencyClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionPublicationClosure

def statelessConsumerAccepts
    (expected observed : SandboxMaterializationExecutionReceipt) : Prop :=
  observed = expected

theorem exactExecutionClosureAlonePermitsDuplicateConsumerAcceptance
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
    SandboxMaterializationExecutionClosure
        currentContext recipe policy effectSemantics admission request receipt ∧
      statelessConsumerAccepts receipt receipt ∧
      statelessConsumerAccepts receipt receipt := by
  exact ⟨closed, rfl, rfl⟩

def executedPublicationItem
    (beforeEntry afterEntry : SourceBoundEffectReplayLedgerEntry)
    (step : SourceBoundEffectReplayStep)
    (completionReceipt : SourceBoundEffectCompletionReceipt) :
    SourceBoundEffectCompletionPublicationItem :=
  { beforeEntry := beforeEntry
    afterEntry := afterEntry
    step := step
    disposition := .executed completionReceipt }

structure SandboxMaterializationReplayBridge
    (currentContext : ReceiptValidationContext)
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
    (completionReceipt : SourceBoundEffectCompletionReceipt) : Prop where
  executionClosed :
    SandboxMaterializationExecutionClosure
      currentContext recipe policy effectSemantics admission
      executionRequest executionReceipt
  publicationItemCloses :
    SourceBoundEffectCompletionPublicationItemClosed
      completionReceiptValid restoreRequest window plan
      (executedPublicationItem beforeEntry afterEntry step completionReceipt)
  transactionIdentityBound :
    window.sourceTraceReceipt.transactionId = executionReceipt.transactionIdentity
  effectIdentityBound :
    step.observation.event.effectId = executionReceipt.effectIdentity
  runtimeEpochBound : executionReceipt.runtimeEpoch = window.runtimeEpoch
  activeFenceTokenBound :
    executionReceipt.activeFenceToken = window.activeFenceToken
  resultDigestBound :
    completionReceipt.resultDigest = executionReceipt.postStateIdentity
  beforeEntryNotCompleted : beforeEntry.completed = false
  beforeEntryReplaySafe : beforeEntry.replaySafe = true
  stepExecutes : step.action = SourceBoundEffectReplayAction.execute
  afterEntryCompleted : afterEntry.completed = true
  completionReceiptIdentityBound :
    afterEntry.completionReceiptId = completionReceipt.receiptId

theorem closedBridgeBindsCanonicalTransactionAndEffect
    {currentContext : ReceiptValidationContext}
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
    (bridge : SandboxMaterializationReplayBridge
      currentContext recipe policy effectSemantics admission executionRequest
      executionReceipt completionReceiptValid restoreRequest window plan
      beforeEntry afterEntry step completionReceipt) :
    window.sourceTraceReceipt.transactionId = executionReceipt.transactionIdentity ∧
    step.observation.event.effectId = executionReceipt.effectIdentity :=
  ⟨bridge.transactionIdentityBound, bridge.effectIdentityBound⟩

theorem closedBridgePublishesTheExactPostStateDigest
    {currentContext : ReceiptValidationContext}
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
    (bridge : SandboxMaterializationReplayBridge
      currentContext recipe policy effectSemantics admission executionRequest
      executionReceipt completionReceiptValid restoreRequest window plan
      beforeEntry afterEntry step completionReceipt) :
    completionReceipt.resultDigest = executionReceipt.postStateIdentity :=
  bridge.resultDigestBound

theorem closedBridgeAdvancesOneCompletionEntry
    {currentContext : ReceiptValidationContext}
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
    (bridge : SandboxMaterializationReplayBridge
      currentContext recipe policy effectSemantics admission executionRequest
      executionReceipt completionReceiptValid restoreRequest window plan
      beforeEntry afterEntry step completionReceipt) :
    beforeEntry.completed = false ∧
    beforeEntry.replaySafe = true ∧
    afterEntry.completed = true ∧
    afterEntry.completionReceiptId = completionReceipt.receiptId :=
  ⟨bridge.beforeEntryNotCompleted, bridge.beforeEntryReplaySafe,
    bridge.afterEntryCompleted, bridge.completionReceiptIdentityBound⟩

theorem executedStepCannotExecuteAgainAgainstCompletedEntry
    {currentContext : ReceiptValidationContext}
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
    (bridge : SandboxMaterializationReplayBridge
      currentContext recipe policy effectSemantics admission executionRequest
      executionReceipt completionReceiptValid restoreRequest window plan
      beforeEntry afterEntry step completionReceipt) :
    ¬ replayStepMatchesLedgerEntry step afterEntry := by
  intro replayMatchesCompleted
  rcases replayMatchesCompleted with
    ⟨_, _, completedAndSuppressed | incompleteAndReplaySafeAndExecute⟩
  · have actionContradiction :
        SourceBoundEffectReplayAction.execute =
          SourceBoundEffectReplayAction.suppressCompleted :=
      bridge.stepExecutes.symm.trans completedAndSuppressed.2
    cases actionContradiction
  · have completionContradiction : true = false :=
      bridge.afterEntryCompleted.symm.trans
        incompleteAndReplaySafeAndExecute.1
    cases completionContradiction

end AgenticAILabProof.Enterprise.SandboxProfileMaterializationReplayClosure
