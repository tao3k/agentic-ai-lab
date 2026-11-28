-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationClosure

open
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffCore
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityCore
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityClosure
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationCore

structure SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationEvidence
    {RecoveryExecution : Type}
    (recoveryIdAt : RecoveryExecution → String)
    (execution : RecoveryExecution)
    (witnessRecoveryId : String)
    (position : Nat)
    (handoffAt : GlobalHandoffKey → Prop)
    (globalTransferAt :
      GlobalHandoffKey → EnterpriseResponsibilityTransfer)
    (before after : HandoffIdentityRegistrySnapshot)
    (transfer : EnterpriseResponsibilityTransfer)
    (receiptValid :
      HandoffIdentityRegistryPublicationReceiptValid)
    (receipt : HandoffIdentityRegistryPublicationReceipt) :
    Prop where
  recoveryIdentityOwner :
    RecoveryExecutionIdentityOwner RecoveryExecution recoveryIdAt
  recoveryIdentityMatches :
    recoveryIdAt execution = witnessRecoveryId
  identityClassification :
    SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityClassification
      handoffAt
      globalTransferAt
  handoffExists :
    handoffAt (witnessRecoveryId, position)
  exactTransfer :
    globalTransferAt (witnessRecoveryId, position) = transfer
  beforeEntriesProject :
    ∀ {key candidateTransfer},
      before key = some candidateTransfer →
        handoffAt key ∧ globalTransferAt key = candidateTransfer
  publicationAuthority :
    HandoffIdentityRegistryPublicationAuthority receiptValid
  publicationReceiptClosed :
    HandoffIdentityRegistryPublicationReceiptClosed
      receiptValid
      before
      after
      (witnessRecoveryId, position)
      transfer
      receipt

theorem registryBeforePublicationIsClassified
    {RecoveryExecution : Type}
    {recoveryIdAt : RecoveryExecution → String}
    {execution : RecoveryExecution}
    {witnessRecoveryId : String}
    {position : Nat}
    {handoffAt : GlobalHandoffKey → Prop}
    {globalTransferAt :
      GlobalHandoffKey → EnterpriseResponsibilityTransfer}
    {before after : HandoffIdentityRegistrySnapshot}
    {transfer : EnterpriseResponsibilityTransfer}
    (evidence :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationEvidence
        recoveryIdAt
        execution
        witnessRecoveryId
        position
        handoffAt
        globalTransferAt
        before
        after
        transfer
        receiptValid
        receipt) :
    HandoffIdentityRegistrySnapshotClassified before :=
  classifiedDomainProducesClassifiedSnapshot
    evidence.identityClassification
    evidence.beforeEntriesProject

theorem publishedRegistrySnapshotIsClassified
    {RecoveryExecution : Type}
    {recoveryIdAt : RecoveryExecution → String}
    {execution : RecoveryExecution}
    {witnessRecoveryId : String}
    {position : Nat}
    {handoffAt : GlobalHandoffKey → Prop}
    {globalTransferAt :
      GlobalHandoffKey → EnterpriseResponsibilityTransfer}
    {before after : HandoffIdentityRegistrySnapshot}
    {transfer : EnterpriseResponsibilityTransfer}
    (evidence :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationEvidence
        recoveryIdAt
        execution
        witnessRecoveryId
        position
        handoffAt
        globalTransferAt
        before
        after
        transfer
        receiptValid
        receipt) :
    HandoffIdentityRegistrySnapshotClassified after :=
  publicationStepPreservesClassification
    (registryBeforePublicationIsClassified evidence)
    evidence.publicationReceiptClosed.publicationStep

theorem publishedHandoffEntryIsExact
    {RecoveryExecution : Type}
    {recoveryIdAt : RecoveryExecution → String}
    {execution : RecoveryExecution}
    {witnessRecoveryId : String}
    {position : Nat}
    {handoffAt : GlobalHandoffKey → Prop}
    {globalTransferAt :
      GlobalHandoffKey → EnterpriseResponsibilityTransfer}
    {before after : HandoffIdentityRegistrySnapshot}
    {transfer : EnterpriseResponsibilityTransfer}
    (evidence :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationEvidence
        recoveryIdAt
        execution
        witnessRecoveryId
        position
        handoffAt
        globalTransferAt
        before
        after
        transfer
        receiptValid
        receipt) :
    after (witnessRecoveryId, position) = some transfer :=
  evidence.publicationReceiptClosed.publicationStep.keyPublished

theorem publishedHandoffCarriesClosedReceipt
    {RecoveryExecution : Type}
    {recoveryIdAt : RecoveryExecution → String}
    {execution : RecoveryExecution}
    {witnessRecoveryId : String}
    {position : Nat}
    {handoffAt : GlobalHandoffKey → Prop}
    {globalTransferAt :
      GlobalHandoffKey → EnterpriseResponsibilityTransfer}
    {before after : HandoffIdentityRegistrySnapshot}
    {transfer : EnterpriseResponsibilityTransfer}
    (evidence :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationEvidence
        recoveryIdAt
        execution
        witnessRecoveryId
        position
        handoffAt
        globalTransferAt
        before
        after
        transfer
        receiptValid
        receipt) :
    HandoffIdentityRegistryPublicationReceiptClosed
      receiptValid
      before
      after
      (witnessRecoveryId, position)
      transfer
      receipt :=
  evidence.publicationReceiptClosed

theorem sameRegistryRevisionCannotCommitDivergentSuccessor
    {RecoveryExecution : Type}
    {recoveryIdAt : RecoveryExecution → String}
    {execution : RecoveryExecution}
    {witnessRecoveryId : String}
    {position : Nat}
    {handoffAt : GlobalHandoffKey → Prop}
    {globalTransferAt :
      GlobalHandoffKey → EnterpriseResponsibilityTransfer}
    {before after otherAfter : HandoffIdentityRegistrySnapshot}
    {transfer otherTransfer : EnterpriseResponsibilityTransfer}
    {otherKey : GlobalHandoffKey}
    {otherReceipt : HandoffIdentityRegistryPublicationReceipt}
    (evidence :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationEvidence
        recoveryIdAt
        execution
        witnessRecoveryId
        position
        handoffAt
        globalTransferAt
        before
        after
        transfer
        receiptValid
        receipt)
    (otherClosed :
      HandoffIdentityRegistryPublicationReceiptClosed
        receiptValid
        before
        otherAfter
        otherKey
        otherTransfer
        otherReceipt)
    (sameRegistry :
      receipt.registryId = otherReceipt.registryId)
    (sameRevision :
      receipt.beforeRevision = otherReceipt.beforeRevision) :
    after = otherAfter :=
  evidence.publicationAuthority.singleCommittedSuccessor
    evidence.publicationReceiptClosed
    otherClosed
    sameRegistry
    sameRevision

theorem publishedRegistryEntryProjectsToSemanticHandoff
    {RecoveryExecution : Type}
    {recoveryIdAt : RecoveryExecution → String}
    {execution : RecoveryExecution}
    {witnessRecoveryId : String}
    {position : Nat}
    {handoffAt : GlobalHandoffKey → Prop}
    {globalTransferAt :
      GlobalHandoffKey → EnterpriseResponsibilityTransfer}
    {before after : HandoffIdentityRegistrySnapshot}
    {transfer candidateTransfer : EnterpriseResponsibilityTransfer}
    (evidence :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationEvidence
        recoveryIdAt
        execution
        witnessRecoveryId
        position
        handoffAt
        globalTransferAt
        before
        after
        transfer
        receiptValid
        receipt)
    {key : GlobalHandoffKey}
    (entry : after key = some candidateTransfer) :
    handoffAt key ∧ globalTransferAt key = candidateTransfer := by
  rcases
      evidence.publicationReceiptClosed.publicationStep.exactDelta entry with
    newKey | existingEntry
  · subst key
    have candidateMatches : candidateTransfer = transfer := by
      exact
        Option.some.inj
          (entry.symm.trans
            evidence.publicationReceiptClosed.publicationStep.keyPublished)
    subst candidateTransfer
    exact ⟨evidence.handoffExists, evidence.exactTransfer⟩
  · exact evidence.beforeEntriesProject existingEntry

theorem publishedRegistryCarriesSemanticIdentityClassification
    {RecoveryExecution : Type}
    {recoveryIdAt : RecoveryExecution → String}
    {execution : RecoveryExecution}
    {witnessRecoveryId : String}
    {position : Nat}
    {handoffAt : GlobalHandoffKey → Prop}
    {globalTransferAt :
      GlobalHandoffKey → EnterpriseResponsibilityTransfer}
    {before after : HandoffIdentityRegistrySnapshot}
    {transfer : EnterpriseResponsibilityTransfer}
    (evidence :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationEvidence
        recoveryIdAt
        execution
        witnessRecoveryId
        position
        handoffAt
        globalTransferAt
        before
        after
        transfer
        receiptValid
        receipt) :
    SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityClassification
      (fun key => ∃ candidateTransfer, after key = some candidateTransfer)
      globalTransferAt := by
  apply
    classifiedSnapshotProducesPublishedDomainClassification
      (publishedRegistrySnapshotIsClassified evidence)
  intro key publishedEntry
  rcases publishedEntry with ⟨candidateTransfer, entry⟩
  have projection :=
    publishedRegistryEntryProjectsToSemanticHandoff evidence entry
  simpa [projection.right] using entry

theorem publishedHandoffEntrySurvivesFollowingPublicationChain
    {RecoveryExecution : Type}
    {recoveryIdAt : RecoveryExecution → String}
    {execution : RecoveryExecution}
    {witnessRecoveryId : String}
    {position revision : Nat}
    {handoffAt : GlobalHandoffKey → Prop}
    {globalTransferAt :
      GlobalHandoffKey → EnterpriseResponsibilityTransfer}
    {before after final : HandoffIdentityRegistrySnapshot}
    {transfer : EnterpriseResponsibilityTransfer}
    (evidence :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationEvidence
        recoveryIdAt
        execution
        witnessRecoveryId
        position
        handoffAt
        globalTransferAt
        before
        after
        transfer
        receiptValid
        receipt)
    (following :
      HandoffIdentityRegistryPublicationReceiptChain
        receiptValid
        revision
        receipt.registryId
        receipt.afterRevision
        after
        finalRevision
        final) :
    final (witnessRecoveryId, position) = some transfer :=
  receiptChainRetainsInitialEntry
    following
    evidence.publicationReceiptClosed.publicationStep.keyPublished

theorem publishedRegistryRemainsClassifiedAcrossFollowingChain
    {RecoveryExecution : Type}
    {recoveryIdAt : RecoveryExecution → String}
    {execution : RecoveryExecution}
    {witnessRecoveryId : String}
    {position revision : Nat}
    {handoffAt : GlobalHandoffKey → Prop}
    {globalTransferAt :
      GlobalHandoffKey → EnterpriseResponsibilityTransfer}
    {before after final : HandoffIdentityRegistrySnapshot}
    {transfer : EnterpriseResponsibilityTransfer}
    (evidence :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationEvidence
        recoveryIdAt
        execution
        witnessRecoveryId
        position
        handoffAt
        globalTransferAt
        before
        after
        transfer
        receiptValid
        receipt)
    (following :
      HandoffIdentityRegistryPublicationReceiptChain
        receiptValid
        revision
        receipt.registryId
        receipt.afterRevision
        after
        finalRevision
        final) :
    HandoffIdentityRegistrySnapshotClassified final :=
  receiptChainPreservesClassification
    following
    (publishedRegistrySnapshotIsClassified evidence)

theorem ownedRecoveryExecutionIdentityCannotCollapseGlobalHandoffKey
    {RecoveryExecution : Type}
    {recoveryIdAt : RecoveryExecution → String}
    (owner :
      RecoveryExecutionIdentityOwner RecoveryExecution recoveryIdAt)
    {left right : RecoveryExecution}
    (distinct : left ≠ right)
    (position : Nat) :
    (recoveryIdAt left, position) ≠
      (recoveryIdAt right, position) :=
  distinctRecoveryExecutionsHaveDistinctGlobalHandoffKeys
    owner
    distinct
    position

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationClosure
