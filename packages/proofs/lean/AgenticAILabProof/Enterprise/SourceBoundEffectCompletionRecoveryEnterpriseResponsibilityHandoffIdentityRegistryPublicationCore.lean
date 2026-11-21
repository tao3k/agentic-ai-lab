-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityClosure
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationModel

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationCore

open
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffCore
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityCore
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityClosure

abbrev HandoffIdentityRegistrySnapshot :=
  GlobalHandoffKey → Option EnterpriseResponsibilityTransfer

def HandoffIdentityRegistrySnapshotExtends
    (before after : HandoffIdentityRegistrySnapshot) :
    Prop :=
  ∀ {key transfer}, before key = some transfer → after key = some transfer

structure HandoffIdentityRegistrySnapshotClassified
    (snapshot : HandoffIdentityRegistrySnapshot) :
    Prop where
  acceptanceEvidenceNonreusing :
    ∀ {left right leftTransfer rightTransfer},
      snapshot left = some leftTransfer →
        snapshot right = some rightTransfer →
          leftTransfer.acceptanceEvidenceIdentity =
              rightTransfer.acceptanceEvidenceIdentity →
            left = right
  observationEvidenceNonreusing :
    ∀ {left right leftTransfer rightTransfer},
      snapshot left = some leftTransfer →
        snapshot right = some rightTransfer →
          leftTransfer.effectiveObservationIdentity =
              rightTransfer.effectiveObservationIdentity →
            left = right

structure HandoffIdentityRegistryPublicationStep
    (before after : HandoffIdentityRegistrySnapshot)
    (key : GlobalHandoffKey)
    (transfer : EnterpriseResponsibilityTransfer) :
    Prop where
  keyWasAbsent :
    before key = none
  keyPublished :
    after key = some transfer
  retainsExisting :
    HandoffIdentityRegistrySnapshotExtends before after
  exactDelta :
    ∀ {candidateKey candidateTransfer},
      after candidateKey = some candidateTransfer →
        candidateKey = key ∨
          before candidateKey = some candidateTransfer
  acceptanceEvidenceFresh :
    ∀ {existingKey existingTransfer},
      before existingKey = some existingTransfer →
        existingTransfer.acceptanceEvidenceIdentity ≠
          transfer.acceptanceEvidenceIdentity
  observationEvidenceFresh :
    ∀ {existingKey existingTransfer},
      before existingKey = some existingTransfer →
        existingTransfer.effectiveObservationIdentity ≠
          transfer.effectiveObservationIdentity

structure HandoffIdentityRegistryPublicationReceipt where
  publicationReceiptId : String
  registryId : String
  providerIdentity : String
  beforeRevision : Nat
  afterRevision : Nat
  beforeDigest : String
  afterDigest : String
  key : GlobalHandoffKey
  transfer : EnterpriseResponsibilityTransfer
  storageTransactionDigest : String

abbrev HandoffIdentityRegistryPublicationReceiptValid :=
  HandoffIdentityRegistryPublicationReceipt →
    HandoffIdentityRegistrySnapshot →
      HandoffIdentityRegistrySnapshot →
        Prop

structure HandoffIdentityRegistryPublicationReceiptClosed
    (receiptValid :
      HandoffIdentityRegistryPublicationReceiptValid)
    (before after : HandoffIdentityRegistrySnapshot)
    (key : GlobalHandoffKey)
    (transfer : EnterpriseResponsibilityTransfer)
    (receipt : HandoffIdentityRegistryPublicationReceipt) :
    Prop where
  validates :
    receiptValid receipt before after
  publicationStep :
    HandoffIdentityRegistryPublicationStep before after key transfer
  receiptIdentityPresent :
    receipt.publicationReceiptId ≠ ""
  registryIdentityPresent :
    receipt.registryId ≠ ""
  providerIdentityPresent :
    receipt.providerIdentity ≠ ""
  beforeDigestPresent :
    receipt.beforeDigest ≠ ""
  afterDigestPresent :
    receipt.afterDigest ≠ ""
  storageTransactionPresent :
    receipt.storageTransactionDigest ≠ ""
  revisionAdvancesOnce :
    receipt.afterRevision = receipt.beforeRevision + 1
  exactKey :
    receipt.key = key
  exactTransfer :
    receipt.transfer = transfer

structure HandoffIdentityRegistryPublicationAuthority
    (receiptValid :
      HandoffIdentityRegistryPublicationReceiptValid) :
    Prop where
  singleCommittedSuccessor :
    ∀ {before afterLeft afterRight keyLeft keyRight
        transferLeft transferRight receiptLeft receiptRight},
      HandoffIdentityRegistryPublicationReceiptClosed
          receiptValid
          before
          afterLeft
          keyLeft
          transferLeft
          receiptLeft →
        HandoffIdentityRegistryPublicationReceiptClosed
            receiptValid
            before
            afterRight
            keyRight
            transferRight
            receiptRight →
          receiptLeft.registryId = receiptRight.registryId →
            receiptLeft.beforeRevision = receiptRight.beforeRevision →
              afterLeft = afterRight
  receiptIdentityNonreusing :
    ∀ {beforeLeft afterLeft beforeRight afterRight keyLeft keyRight
        transferLeft transferRight receiptLeft receiptRight},
      HandoffIdentityRegistryPublicationReceiptClosed
          receiptValid
          beforeLeft
          afterLeft
          keyLeft
          transferLeft
          receiptLeft →
        HandoffIdentityRegistryPublicationReceiptClosed
            receiptValid
            beforeRight
            afterRight
            keyRight
            transferRight
            receiptRight →
          receiptLeft.publicationReceiptId =
              receiptRight.publicationReceiptId →
            receiptLeft.registryId = receiptRight.registryId ∧
              receiptLeft.beforeRevision = receiptRight.beforeRevision ∧
                keyLeft = keyRight

structure RecoveryExecutionIdentityOwner
    (RecoveryExecution : Type)
    (recoveryIdAt : RecoveryExecution → String) :
    Prop where
  identityPresent :
    ∀ execution, recoveryIdAt execution ≠ ""
  identityInjective :
    Function.Injective recoveryIdAt

theorem handoffIdentityRegistrySnapshotExtendsRefl
    (snapshot : HandoffIdentityRegistrySnapshot) :
    HandoffIdentityRegistrySnapshotExtends snapshot snapshot := by
  intro key transfer entry
  exact entry

theorem handoffIdentityRegistrySnapshotExtendsTrans
    {first second third : HandoffIdentityRegistrySnapshot}
    (firstToSecond :
      HandoffIdentityRegistrySnapshotExtends first second)
    (secondToThird :
      HandoffIdentityRegistrySnapshotExtends second third) :
    HandoffIdentityRegistrySnapshotExtends first third := by
  intro key transfer entry
  exact secondToThird (firstToSecond entry)

theorem publicationStepRetainsExistingEntry
    {before after : HandoffIdentityRegistrySnapshot}
    {key : GlobalHandoffKey}
    {transfer : EnterpriseResponsibilityTransfer}
    (publication :
      HandoffIdentityRegistryPublicationStep before after key transfer)
    {existingKey : GlobalHandoffKey}
    {existingTransfer : EnterpriseResponsibilityTransfer}
    (existingEntry :
      before existingKey = some existingTransfer) :
    after existingKey = some existingTransfer :=
  publication.retainsExisting existingEntry

theorem publicationStepPreservesClassification
    {before after : HandoffIdentityRegistrySnapshot}
    {key : GlobalHandoffKey}
    {transfer : EnterpriseResponsibilityTransfer}
    (beforeClassified :
      HandoffIdentityRegistrySnapshotClassified before)
    (publication :
      HandoffIdentityRegistryPublicationStep before after key transfer) :
    HandoffIdentityRegistrySnapshotClassified after := by
  constructor
  · intro left right leftTransfer rightTransfer leftEntry rightEntry sameAcceptance
    rcases publication.exactDelta leftEntry with leftNew | leftExisting
    · rcases publication.exactDelta rightEntry with rightNew | rightExisting
      · exact leftNew.trans rightNew.symm
      · subst left
        have leftTransferMatches : leftTransfer = transfer := by
          exact Option.some.inj (leftEntry.symm.trans publication.keyPublished)
        exfalso
        exact publication.acceptanceEvidenceFresh rightExisting
          (by simpa [leftTransferMatches] using sameAcceptance.symm)
    · rcases publication.exactDelta rightEntry with rightNew | rightExisting
      · subst right
        have rightTransferMatches : rightTransfer = transfer := by
          exact Option.some.inj (rightEntry.symm.trans publication.keyPublished)
        exfalso
        exact publication.acceptanceEvidenceFresh leftExisting
          (by simpa [rightTransferMatches] using sameAcceptance)
      · exact
          beforeClassified.acceptanceEvidenceNonreusing
            leftExisting
            rightExisting
            sameAcceptance
  · intro left right leftTransfer rightTransfer leftEntry rightEntry sameObservation
    rcases publication.exactDelta leftEntry with leftNew | leftExisting
    · rcases publication.exactDelta rightEntry with rightNew | rightExisting
      · exact leftNew.trans rightNew.symm
      · subst left
        have leftTransferMatches : leftTransfer = transfer := by
          exact Option.some.inj (leftEntry.symm.trans publication.keyPublished)
        exfalso
        exact publication.observationEvidenceFresh rightExisting
          (by simpa [leftTransferMatches] using sameObservation.symm)
    · rcases publication.exactDelta rightEntry with rightNew | rightExisting
      · subst right
        have rightTransferMatches : rightTransfer = transfer := by
          exact Option.some.inj (rightEntry.symm.trans publication.keyPublished)
        exfalso
        exact publication.observationEvidenceFresh leftExisting
          (by simpa [rightTransferMatches] using sameObservation)
      · exact
          beforeClassified.observationEvidenceNonreusing
            leftExisting
            rightExisting
            sameObservation

inductive HandoffIdentityRegistryPublicationChain :
    Nat →
      HandoffIdentityRegistrySnapshot →
        HandoffIdentityRegistrySnapshot →
          Prop where
  | zero (snapshot : HandoffIdentityRegistrySnapshot) :
      HandoffIdentityRegistryPublicationChain 0 snapshot snapshot
  | publish
      {revision : Nat}
      {initial before after : HandoffIdentityRegistrySnapshot}
      {key : GlobalHandoffKey}
      {transfer : EnterpriseResponsibilityTransfer}
      (previous :
        HandoffIdentityRegistryPublicationChain revision initial before)
      (publication :
        HandoffIdentityRegistryPublicationStep before after key transfer) :
      HandoffIdentityRegistryPublicationChain
        (revision + 1)
        initial
        after

theorem publicationChainPreservesClassification
    {revision : Nat}
    {initial final : HandoffIdentityRegistrySnapshot}
    (chain :
      HandoffIdentityRegistryPublicationChain revision initial final)
    (initialClassified :
      HandoffIdentityRegistrySnapshotClassified initial) :
    HandoffIdentityRegistrySnapshotClassified final := by
  induction chain with
  | zero =>
      exact initialClassified
  | publish previous publication inductionHypothesis =>
      exact
        publicationStepPreservesClassification
          (inductionHypothesis initialClassified)
          publication

theorem publicationChainRetainsInitialSnapshot
    {revision : Nat}
    {initial final : HandoffIdentityRegistrySnapshot}
    (chain :
      HandoffIdentityRegistryPublicationChain revision initial final) :
    HandoffIdentityRegistrySnapshotExtends initial final := by
  induction chain with
  | zero =>
      intro key transfer entry
      exact entry
  | publish previous publication inductionHypothesis =>
      intro key transfer entry
      exact publication.retainsExisting (inductionHypothesis entry)

theorem publicationChainRetainsInitialEntry
    {revision : Nat}
    {initial final : HandoffIdentityRegistrySnapshot}
    (chain :
      HandoffIdentityRegistryPublicationChain revision initial final)
    {key : GlobalHandoffKey}
    {transfer : EnterpriseResponsibilityTransfer}
    (entry : initial key = some transfer) :
    final key = some transfer :=
  publicationChainRetainsInitialSnapshot chain entry

inductive HandoffIdentityRegistryPublicationReceiptChain
    (receiptValid :
      HandoffIdentityRegistryPublicationReceiptValid) :
    Nat →
      String →
        Nat →
          HandoffIdentityRegistrySnapshot →
            Nat →
              HandoffIdentityRegistrySnapshot →
                Prop where
  | zero
      (registryId : String)
      (revision : Nat)
      (snapshot : HandoffIdentityRegistrySnapshot) :
      HandoffIdentityRegistryPublicationReceiptChain
        receiptValid
        0
        registryId
        revision
        snapshot
        revision
        snapshot
  | publish
      {count initialRevision currentRevision : Nat}
      {registryId : String}
      {initial before after : HandoffIdentityRegistrySnapshot}
      {key : GlobalHandoffKey}
      {transfer : EnterpriseResponsibilityTransfer}
      {receipt : HandoffIdentityRegistryPublicationReceipt}
      (previous :
        HandoffIdentityRegistryPublicationReceiptChain
          receiptValid
          count
          registryId
          initialRevision
          initial
          currentRevision
          before)
      (closed :
        HandoffIdentityRegistryPublicationReceiptClosed
          receiptValid
          before
          after
          key
          transfer
          receipt)
      (registryMatches :
        receipt.registryId = registryId)
      (revisionMatches :
        receipt.beforeRevision = currentRevision) :
      HandoffIdentityRegistryPublicationReceiptChain
        receiptValid
        (count + 1)
        registryId
        initialRevision
        initial
        receipt.afterRevision
        after

theorem receiptChainPreservesClassification
    {receiptValid :
      HandoffIdentityRegistryPublicationReceiptValid}
    {count initialRevision finalRevision : Nat}
    {registryId : String}
    {initial final : HandoffIdentityRegistrySnapshot}
    (chain :
      HandoffIdentityRegistryPublicationReceiptChain
        receiptValid
        count
        registryId
        initialRevision
        initial
        finalRevision
        final)
    (initialClassified :
      HandoffIdentityRegistrySnapshotClassified initial) :
    HandoffIdentityRegistrySnapshotClassified final := by
  induction chain with
  | zero =>
      exact initialClassified
  | publish previous closed registryMatches revisionMatches inductionHypothesis =>
      exact
        publicationStepPreservesClassification
          (inductionHypothesis initialClassified)
          closed.publicationStep

theorem receiptChainRetainsInitialSnapshot
    {receiptValid :
      HandoffIdentityRegistryPublicationReceiptValid}
    {count initialRevision finalRevision : Nat}
    {registryId : String}
    {initial final : HandoffIdentityRegistrySnapshot}
    (chain :
      HandoffIdentityRegistryPublicationReceiptChain
        receiptValid
        count
        registryId
        initialRevision
        initial
        finalRevision
        final) :
    HandoffIdentityRegistrySnapshotExtends initial final := by
  induction chain with
  | zero =>
      intro key transfer entry
      exact entry
  | publish previous closed registryMatches revisionMatches inductionHypothesis =>
      intro key transfer entry
      exact
        closed.publicationStep.retainsExisting
          (inductionHypothesis entry)

theorem receiptChainRetainsInitialEntry
    {receiptValid :
      HandoffIdentityRegistryPublicationReceiptValid}
    {count initialRevision finalRevision : Nat}
    {registryId : String}
    {initial final : HandoffIdentityRegistrySnapshot}
    (chain :
      HandoffIdentityRegistryPublicationReceiptChain
        receiptValid
        count
        registryId
        initialRevision
        initial
        finalRevision
        final)
    {key : GlobalHandoffKey}
    {transfer : EnterpriseResponsibilityTransfer}
    (entry : initial key = some transfer) :
    final key = some transfer :=
  receiptChainRetainsInitialSnapshot chain entry

theorem publicationAuthorityRejectsDivergentSuccessors
    {receiptValid :
      HandoffIdentityRegistryPublicationReceiptValid}
    (authority :
      HandoffIdentityRegistryPublicationAuthority receiptValid)
    {before afterLeft afterRight : HandoffIdentityRegistrySnapshot}
    {keyLeft keyRight : GlobalHandoffKey}
    {transferLeft transferRight : EnterpriseResponsibilityTransfer}
    {receiptLeft receiptRight :
      HandoffIdentityRegistryPublicationReceipt}
    (leftClosed :
      HandoffIdentityRegistryPublicationReceiptClosed
        receiptValid
        before
        afterLeft
        keyLeft
        transferLeft
        receiptLeft)
    (rightClosed :
      HandoffIdentityRegistryPublicationReceiptClosed
        receiptValid
        before
        afterRight
        keyRight
        transferRight
        receiptRight)
    (sameRegistry :
      receiptLeft.registryId = receiptRight.registryId)
    (sameRevision :
      receiptLeft.beforeRevision = receiptRight.beforeRevision)
    (divergent : afterLeft ≠ afterRight) :
    False :=
  divergent
    (authority.singleCommittedSuccessor
      leftClosed
      rightClosed
      sameRegistry
      sameRevision)

theorem equalPublicationReceiptIdentityDeterminesRegistryRevisionAndKey
    {receiptValid :
      HandoffIdentityRegistryPublicationReceiptValid}
    (authority :
      HandoffIdentityRegistryPublicationAuthority receiptValid)
    {beforeLeft afterLeft beforeRight afterRight :
      HandoffIdentityRegistrySnapshot}
    {keyLeft keyRight : GlobalHandoffKey}
    {transferLeft transferRight : EnterpriseResponsibilityTransfer}
    {receiptLeft receiptRight :
      HandoffIdentityRegistryPublicationReceipt}
    (leftClosed :
      HandoffIdentityRegistryPublicationReceiptClosed
        receiptValid
        beforeLeft
        afterLeft
        keyLeft
        transferLeft
        receiptLeft)
    (rightClosed :
      HandoffIdentityRegistryPublicationReceiptClosed
        receiptValid
        beforeRight
        afterRight
        keyRight
        transferRight
        receiptRight)
    (sameReceiptIdentity :
      receiptLeft.publicationReceiptId =
        receiptRight.publicationReceiptId) :
    receiptLeft.registryId = receiptRight.registryId ∧
      receiptLeft.beforeRevision = receiptRight.beforeRevision ∧
        keyLeft = keyRight :=
  authority.receiptIdentityNonreusing
    leftClosed
    rightClosed
    sameReceiptIdentity

theorem classifiedDomainProducesClassifiedSnapshot
    {handoffAt : GlobalHandoffKey → Prop}
    {transferAt :
      GlobalHandoffKey → EnterpriseResponsibilityTransfer}
    {snapshot : HandoffIdentityRegistrySnapshot}
    (classification :
      SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityClassification
        handoffAt
        transferAt)
    (entryProjects :
      ∀ {key transfer},
        snapshot key = some transfer →
          handoffAt key ∧ transferAt key = transfer) :
    HandoffIdentityRegistrySnapshotClassified snapshot := by
  constructor
  · intro left right leftTransfer rightTransfer leftEntry rightEntry sameAcceptance
    have leftProjection := entryProjects leftEntry
    have rightProjection := entryProjects rightEntry
    apply classification.acceptanceEvidenceGloballyNonreusing
      leftProjection.left
      rightProjection.left
    simpa [leftProjection.right, rightProjection.right] using sameAcceptance
  · intro left right leftTransfer rightTransfer leftEntry rightEntry sameObservation
    have leftProjection := entryProjects leftEntry
    have rightProjection := entryProjects rightEntry
    apply classification.observationEvidenceGloballyNonreusing
      leftProjection.left
      rightProjection.left
    simpa [leftProjection.right, rightProjection.right] using sameObservation

theorem classifiedSnapshotProducesPublishedDomainClassification
    {handoffAt : GlobalHandoffKey → Prop}
    {transferAt :
      GlobalHandoffKey → EnterpriseResponsibilityTransfer}
    {snapshot : HandoffIdentityRegistrySnapshot}
    (snapshotClassified :
      HandoffIdentityRegistrySnapshotClassified snapshot)
    (domainProjects :
      ∀ {key},
        handoffAt key →
          snapshot key = some (transferAt key)) :
    SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityClassification
      handoffAt
      transferAt := by
  constructor
  · intro left right leftHandoff rightHandoff sameAcceptance
    exact
      snapshotClassified.acceptanceEvidenceNonreusing
        (domainProjects leftHandoff)
        (domainProjects rightHandoff)
        sameAcceptance
  · intro left right leftHandoff rightHandoff sameObservation
    exact
      snapshotClassified.observationEvidenceNonreusing
        (domainProjects leftHandoff)
        (domainProjects rightHandoff)
        sameObservation

theorem distinctRecoveryExecutionsHaveDistinctGlobalHandoffKeys
    {RecoveryExecution : Type}
    {recoveryIdAt : RecoveryExecution → String}
    (owner :
      RecoveryExecutionIdentityOwner RecoveryExecution recoveryIdAt)
    {left right : RecoveryExecution}
    (distinct : left ≠ right)
    (position : Nat) :
    (recoveryIdAt left, position) ≠
      (recoveryIdAt right, position) := by
  intro keysEqual
  have sameRecoveryIdentity :
      recoveryIdAt left = recoveryIdAt right :=
    congrArg Prod.fst keysEqual
  exact distinct (owner.identityInjective sameRecoveryIdentity)

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationCore
