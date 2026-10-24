-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerEvidenceBindingClosure
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerDeferralAdmissionContractModel
import AgenticAILabProof.Enterprise.SourceBoundRuntimeWatchdogClosure

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerDeferralAdmissionContractClosure

open SourceBoundEffectCompletionCrashRecoveryClosure
open SourceBoundEffectCompletionPublicationClosure
open SourceBoundEffectCompletionRecoveryProgressEvidenceClosure
open SourceBoundEffectCompletionRecoveryOwnerDeferralAdmissionContractModel
open SourceBoundRuntimeWatchdogClosure

/-!
# Owner-native crash-deferral and storage-admission contracts

The current runtime watchdog and completion commit receipt remain observations
of already-observed runtime and post-commit facts.  This proof-only model
introduces the smallest owner-accounting contracts required to construct the
crash and storage coordinates of the existing recovery progress receipt.
-/

structure SourceBoundEffectCompletionRecoveryCrashDeferralContract where
  contractId : String
  recoveryId : String
  runtimeOwnerIdentity : String
  runtimeEpoch : Nat
  activeFenceToken : Nat
  maxDeferrals : Nat
  provenanceDigest : String
  deriving Repr

structure SourceBoundEffectCompletionRecoveryCrashDeferralReceipt where
  receiptId : String
  contractId : String
  recoveryId : String
  runtimeOwnerIdentity : String
  runtimeEpoch : Nat
  activeFenceToken : Nat
  deferralsConsumed : Nat
  deferralsRemaining : Nat
  provenanceDigest : String
  deriving Repr

def SourceBoundEffectCompletionRecoveryCrashDeferralContractValid :=
  SourceBoundEffectCompletionRecoveryCrashDeferralContract → Prop

def SourceBoundEffectCompletionRecoveryCrashDeferralReceiptValid :=
  SourceBoundEffectCompletionRecoveryCrashDeferralReceipt → Prop

structure SourceBoundEffectCompletionRecoveryCrashDeferralReceiptClosed
    (contractValid :
      SourceBoundEffectCompletionRecoveryCrashDeferralContractValid)
    (receiptValid :
      SourceBoundEffectCompletionRecoveryCrashDeferralReceiptValid)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (contract : SourceBoundEffectCompletionRecoveryCrashDeferralContract)
    (receipt : SourceBoundEffectCompletionRecoveryCrashDeferralReceipt) :
    Prop where
  contractValidates : contractValid contract
  receiptValidates : receiptValid receipt
  contractIdentityPresent : contract.contractId ≠ ""
  receiptIdentityPresent : receipt.receiptId ≠ ""
  runtimeOwnerIdentityPresent : contract.runtimeOwnerIdentity ≠ ""
  contractProvenancePresent : contract.provenanceDigest ≠ ""
  receiptProvenancePresent : receipt.provenanceDigest ≠ ""
  contractRecoveryMatches : contract.recoveryId = expectation.recoveryId
  contractRuntimeEpochMatches :
    contract.runtimeEpoch = expectation.runtimeEpoch
  contractFenceMatches :
    contract.activeFenceToken = expectation.activeFenceToken
  receiptContractMatches : receipt.contractId = contract.contractId
  receiptRecoveryMatches : receipt.recoveryId = contract.recoveryId
  receiptRuntimeOwnerMatches :
    receipt.runtimeOwnerIdentity = contract.runtimeOwnerIdentity
  receiptRuntimeEpochMatches : receipt.runtimeEpoch = contract.runtimeEpoch
  receiptFenceMatches :
    receipt.activeFenceToken = contract.activeFenceToken
  accountingCloses :
    receipt.deferralsConsumed + receipt.deferralsRemaining =
      contract.maxDeferrals

structure SourceBoundEffectCompletionRecoveryCrashDeferralAdvance
    (before after :
      SourceBoundEffectCompletionRecoveryCrashDeferralReceipt) : Prop where
  receiptIdentityAdvances : after.receiptId ≠ before.receiptId
  contractStable : after.contractId = before.contractId
  recoveryStable : after.recoveryId = before.recoveryId
  runtimeOwnerStable :
    after.runtimeOwnerIdentity = before.runtimeOwnerIdentity
  runtimeEpochStable : after.runtimeEpoch = before.runtimeEpoch
  activeFenceStable : after.activeFenceToken = before.activeFenceToken
  consumedAdvances :
    after.deferralsConsumed = before.deferralsConsumed + 1
  remainingDecreases :
    before.deferralsRemaining = after.deferralsRemaining + 1

structure SourceBoundEffectCompletionRecoveryCrashDeferralTransitionClosed
    (contractValid :
      SourceBoundEffectCompletionRecoveryCrashDeferralContractValid)
    (receiptValid :
      SourceBoundEffectCompletionRecoveryCrashDeferralReceiptValid)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (contract : SourceBoundEffectCompletionRecoveryCrashDeferralContract)
    (before after :
      SourceBoundEffectCompletionRecoveryCrashDeferralReceipt) : Prop where
  beforeCloses :
    SourceBoundEffectCompletionRecoveryCrashDeferralReceiptClosed
      contractValid receiptValid expectation contract before
  afterCloses :
    SourceBoundEffectCompletionRecoveryCrashDeferralReceiptClosed
      contractValid receiptValid expectation contract after
  advanceCloses :
    SourceBoundEffectCompletionRecoveryCrashDeferralAdvance before after

theorem closedCrashDeferralAdvanceStrictlyDecreases
    {before after :
      SourceBoundEffectCompletionRecoveryCrashDeferralReceipt}
    (advance :
      SourceBoundEffectCompletionRecoveryCrashDeferralAdvance before after) :
    after.deferralsRemaining < before.deferralsRemaining := by
  exact remainingDecreasesByOneIsStrict advance.remainingDecreases

def crashDeferralContractMatchesCurrentEvidence
    (watchdog : SourceBoundRuntimeWatchdogObservation)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (contract :
      SourceBoundEffectCompletionRecoveryCrashDeferralContract) : Prop :=
  contract.recoveryId = expectation.recoveryId ∧
    contract.runtimeOwnerIdentity = watchdog.runtimeOwnerIdentity ∧
    contract.runtimeEpoch = expectation.runtimeEpoch ∧
    contract.activeFenceToken = expectation.activeFenceToken

def crashDeferralContractCandidate
    (watchdog : SourceBoundRuntimeWatchdogObservation)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (contractId : String)
    (maxDeferrals : Nat) :
    SourceBoundEffectCompletionRecoveryCrashDeferralContract :=
  {
    contractId
    recoveryId := expectation.recoveryId
    runtimeOwnerIdentity := watchdog.runtimeOwnerIdentity
    runtimeEpoch := expectation.runtimeEpoch
    activeFenceToken := expectation.activeFenceToken
    maxDeferrals
    provenanceDigest := "proof-only-crash-deferral-candidate"
  }

theorem currentRuntimeEvidenceDoesNotDetermineCrashDeferralLimit
    (watchdog : SourceBoundRuntimeWatchdogObservation)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation) :
    crashDeferralContractMatchesCurrentEvidence
        watchdog expectation
        (crashDeferralContractCandidate
          watchdog expectation "zero-crash-deferrals" 0) ∧
      crashDeferralContractMatchesCurrentEvidence
        watchdog expectation
        (crashDeferralContractCandidate
          watchdog expectation "one-crash-deferral" 1) ∧
      (crashDeferralContractCandidate
          watchdog expectation "zero-crash-deferrals" 0).maxDeferrals ≠
        (crashDeferralContractCandidate
          watchdog expectation "one-crash-deferral" 1).maxDeferrals := by
  simp [
    crashDeferralContractMatchesCurrentEvidence,
    crashDeferralContractCandidate
  ]

structure SourceBoundEffectCompletionPrecommitStorageAdmissionContract where
  contractId : String
  recoveryId : String
  publicationId : String
  storageOwnerIdentity : String
  runtimeEpoch : Nat
  activeFenceToken : Nat
  maxDeferrals : Nat
  requiredUnits : Nat
  provenanceDigest : String
  deriving Repr

inductive SourceBoundEffectCompletionPrecommitStorageAdmissionDecision where
  | admitted
  | deferred
  | rejected
  deriving DecidableEq, Repr

structure SourceBoundEffectCompletionPrecommitStorageAdmissionReceipt where
  receiptId : String
  contractId : String
  recoveryId : String
  publicationId : String
  storageOwnerIdentity : String
  runtimeEpoch : Nat
  activeFenceToken : Nat
  decision : SourceBoundEffectCompletionPrecommitStorageAdmissionDecision
  requiredUnits : Nat
  reservedUnits : Nat
  deferralsConsumed : Nat
  deferralsRemaining : Nat
  provenanceDigest : String
  deriving Repr

def SourceBoundEffectCompletionPrecommitStorageAdmissionContractValid :=
  SourceBoundEffectCompletionPrecommitStorageAdmissionContract → Prop

def SourceBoundEffectCompletionPrecommitStorageAdmissionReceiptValid :=
  SourceBoundEffectCompletionPrecommitStorageAdmissionReceipt → Prop

def storageAdmissionDecisionEvidenceClosed
    (receipt :
      SourceBoundEffectCompletionPrecommitStorageAdmissionReceipt) : Prop :=
  match receipt.decision with
  | .admitted => receipt.requiredUnits ≤ receipt.reservedUnits
  | .deferred =>
      receipt.reservedUnits < receipt.requiredUnits ∧
        0 < receipt.deferralsRemaining
  | .rejected => True

structure SourceBoundEffectCompletionPrecommitStorageAdmissionReceiptClosed
    (contractValid :
      SourceBoundEffectCompletionPrecommitStorageAdmissionContractValid)
    (receiptValid :
      SourceBoundEffectCompletionPrecommitStorageAdmissionReceiptValid)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (publication : SourceBoundEffectCompletionPublication)
    (contract :
      SourceBoundEffectCompletionPrecommitStorageAdmissionContract)
    (receipt :
      SourceBoundEffectCompletionPrecommitStorageAdmissionReceipt) : Prop where
  contractValidates : contractValid contract
  receiptValidates : receiptValid receipt
  contractIdentityPresent : contract.contractId ≠ ""
  receiptIdentityPresent : receipt.receiptId ≠ ""
  storageOwnerIdentityPresent : contract.storageOwnerIdentity ≠ ""
  contractProvenancePresent : contract.provenanceDigest ≠ ""
  receiptProvenancePresent : receipt.provenanceDigest ≠ ""
  contractRecoveryMatches : contract.recoveryId = expectation.recoveryId
  contractPublicationMatches :
    contract.publicationId = publication.publicationId
  publicationRestoreRequestMatches :
    publication.restoreRequestId = expectation.request.requestId
  contractRuntimeEpochMatches :
    contract.runtimeEpoch = expectation.runtimeEpoch
  publicationRuntimeEpochMatches :
    publication.runtimeEpoch = expectation.runtimeEpoch
  contractFenceMatches :
    contract.activeFenceToken = expectation.activeFenceToken
  publicationFenceMatches :
    publication.activeFenceToken = expectation.activeFenceToken
  receiptContractMatches : receipt.contractId = contract.contractId
  receiptRecoveryMatches : receipt.recoveryId = contract.recoveryId
  receiptPublicationMatches :
    receipt.publicationId = contract.publicationId
  receiptStorageOwnerMatches :
    receipt.storageOwnerIdentity = contract.storageOwnerIdentity
  receiptRuntimeEpochMatches : receipt.runtimeEpoch = contract.runtimeEpoch
  receiptFenceMatches :
    receipt.activeFenceToken = contract.activeFenceToken
  receiptRequiredUnitsMatch :
    receipt.requiredUnits = contract.requiredUnits
  accountingCloses :
    receipt.deferralsConsumed + receipt.deferralsRemaining =
      contract.maxDeferrals
  decisionEvidenceCloses : storageAdmissionDecisionEvidenceClosed receipt

structure SourceBoundEffectCompletionPrecommitStorageDeferralAdvance
    (before after :
      SourceBoundEffectCompletionPrecommitStorageAdmissionReceipt) : Prop where
  beforeIsDeferred :
    before.decision =
      SourceBoundEffectCompletionPrecommitStorageAdmissionDecision.deferred
  receiptIdentityAdvances : after.receiptId ≠ before.receiptId
  contractStable : after.contractId = before.contractId
  recoveryStable : after.recoveryId = before.recoveryId
  publicationStable : after.publicationId = before.publicationId
  storageOwnerStable :
    after.storageOwnerIdentity = before.storageOwnerIdentity
  runtimeEpochStable : after.runtimeEpoch = before.runtimeEpoch
  activeFenceStable : after.activeFenceToken = before.activeFenceToken
  consumedAdvances :
    after.deferralsConsumed = before.deferralsConsumed + 1
  remainingDecreases :
    before.deferralsRemaining = after.deferralsRemaining + 1

structure SourceBoundEffectCompletionPrecommitStorageDeferralTransitionClosed
    (contractValid :
      SourceBoundEffectCompletionPrecommitStorageAdmissionContractValid)
    (receiptValid :
      SourceBoundEffectCompletionPrecommitStorageAdmissionReceiptValid)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (publication : SourceBoundEffectCompletionPublication)
    (contract :
      SourceBoundEffectCompletionPrecommitStorageAdmissionContract)
    (before after :
      SourceBoundEffectCompletionPrecommitStorageAdmissionReceipt) : Prop where
  beforeCloses :
    SourceBoundEffectCompletionPrecommitStorageAdmissionReceiptClosed
      contractValid receiptValid expectation publication contract before
  afterCloses :
    SourceBoundEffectCompletionPrecommitStorageAdmissionReceiptClosed
      contractValid receiptValid expectation publication contract after
  advanceCloses :
    SourceBoundEffectCompletionPrecommitStorageDeferralAdvance before after

theorem closedStorageDeferralAdvanceStrictlyDecreases
    {before after :
      SourceBoundEffectCompletionPrecommitStorageAdmissionReceipt}
    (advance :
      SourceBoundEffectCompletionPrecommitStorageDeferralAdvance before after) :
    after.deferralsRemaining < before.deferralsRemaining := by
  exact remainingDecreasesByOneIsStrict advance.remainingDecreases

def storageAdmissionContractMatchesCurrentEvidence
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (commitReceipt : SourceBoundEffectCompletionCommitReceipt)
    (contract :
      SourceBoundEffectCompletionPrecommitStorageAdmissionContract) : Prop :=
  contract.recoveryId = expectation.recoveryId ∧
    contract.publicationId = commitReceipt.publication.publicationId ∧
    contract.storageOwnerIdentity = commitReceipt.providerIdentity ∧
    contract.runtimeEpoch = expectation.runtimeEpoch ∧
    contract.activeFenceToken = expectation.activeFenceToken

def storageAdmissionContractCandidate
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (commitReceipt : SourceBoundEffectCompletionCommitReceipt)
    (contractId : String)
    (maxDeferrals requiredUnits : Nat) :
    SourceBoundEffectCompletionPrecommitStorageAdmissionContract :=
  {
    contractId
    recoveryId := expectation.recoveryId
    publicationId := commitReceipt.publication.publicationId
    storageOwnerIdentity := commitReceipt.providerIdentity
    runtimeEpoch := expectation.runtimeEpoch
    activeFenceToken := expectation.activeFenceToken
    maxDeferrals
    requiredUnits
    provenanceDigest := "proof-only-storage-admission-candidate"
  }

theorem currentCommitEvidenceDoesNotDeterminePrecommitStorageContract
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (commitReceipt : SourceBoundEffectCompletionCommitReceipt) :
    storageAdmissionContractMatchesCurrentEvidence
        expectation commitReceipt
        (storageAdmissionContractCandidate
          expectation commitReceipt "zero-storage-deferrals" 0 0) ∧
      storageAdmissionContractMatchesCurrentEvidence
        expectation commitReceipt
        (storageAdmissionContractCandidate
          expectation commitReceipt "one-storage-deferral" 1 1) ∧
      (storageAdmissionContractCandidate
          expectation commitReceipt "zero-storage-deferrals" 0 0).maxDeferrals ≠
        (storageAdmissionContractCandidate
          expectation commitReceipt "one-storage-deferral" 1 1).maxDeferrals ∧
      (storageAdmissionContractCandidate
          expectation commitReceipt "zero-storage-deferrals" 0 0).requiredUnits ≠
        (storageAdmissionContractCandidate
          expectation commitReceipt "one-storage-deferral" 1 1).requiredUnits := by
  simp [
    storageAdmissionContractMatchesCurrentEvidence,
    storageAdmissionContractCandidate
  ]

structure SourceBoundEffectCompletionRecoveryCrashDeferralProgressProjection
    (beforeReceipt afterReceipt :
      SourceBoundEffectCompletionRecoveryCrashDeferralReceipt)
    (beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget) : Prop where
  beforeCrashMatches :
    beforeBudget.remainingCrashes = beforeReceipt.deferralsRemaining
  afterCrashMatches :
    afterBudget.remainingCrashes = afterReceipt.deferralsRemaining
  schedulingStable :
    afterBudget.remainingSchedulingDeferrals =
      beforeBudget.remainingSchedulingDeferrals
  storageStable :
    afterBudget.remainingStorageDeferrals =
      beforeBudget.remainingStorageDeferrals

theorem closedCrashDeferralTransitionBuildsProgressReceipt
    {contractValid :
      SourceBoundEffectCompletionRecoveryCrashDeferralContractValid}
    {receiptValid :
      SourceBoundEffectCompletionRecoveryCrashDeferralReceiptValid}
    {expectation : SourceBoundEffectCompletionRecoveryExpectation}
    {contract : SourceBoundEffectCompletionRecoveryCrashDeferralContract}
    {beforeReceipt afterReceipt :
      SourceBoundEffectCompletionRecoveryCrashDeferralReceipt}
    {beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget}
    (closed :
      SourceBoundEffectCompletionRecoveryCrashDeferralTransitionClosed
        contractValid receiptValid expectation contract
        beforeReceipt afterReceipt)
    (projection :
      SourceBoundEffectCompletionRecoveryCrashDeferralProgressProjection
        beforeReceipt afterReceipt beforeBudget afterBudget) :
    SourceBoundEffectCompletionRecoveryProgressReceipt
      beforeBudget afterBudget .runtimeCrashBudget := by
  apply SourceBoundEffectCompletionRecoveryProgressReceipt.crashBudgetDecreased
  · rw [projection.beforeCrashMatches, projection.afterCrashMatches]
    exact
      closedCrashDeferralAdvanceStrictlyDecreases
        closed.advanceCloses
  · exact projection.schedulingStable
  · exact projection.storageStable

structure SourceBoundEffectCompletionRecoveryStorageDeferralProgressProjection
    (beforeReceipt afterReceipt :
      SourceBoundEffectCompletionPrecommitStorageAdmissionReceipt)
    (beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget) : Prop where
  beforeStorageMatches :
    beforeBudget.remainingStorageDeferrals =
      beforeReceipt.deferralsRemaining
  afterStorageMatches :
    afterBudget.remainingStorageDeferrals =
      afterReceipt.deferralsRemaining
  crashesStable :
    afterBudget.remainingCrashes = beforeBudget.remainingCrashes
  schedulingStable :
    afterBudget.remainingSchedulingDeferrals =
      beforeBudget.remainingSchedulingDeferrals

theorem closedStorageDeferralTransitionBuildsProgressReceipt
    {contractValid :
      SourceBoundEffectCompletionPrecommitStorageAdmissionContractValid}
    {receiptValid :
      SourceBoundEffectCompletionPrecommitStorageAdmissionReceiptValid}
    {expectation : SourceBoundEffectCompletionRecoveryExpectation}
    {publication : SourceBoundEffectCompletionPublication}
    {contract :
      SourceBoundEffectCompletionPrecommitStorageAdmissionContract}
    {beforeReceipt afterReceipt :
      SourceBoundEffectCompletionPrecommitStorageAdmissionReceipt}
    {beforeBudget afterBudget :
      SourceBoundEffectCompletionRecoveryProgressBudget}
    (closed :
      SourceBoundEffectCompletionPrecommitStorageDeferralTransitionClosed
        contractValid receiptValid expectation publication contract
        beforeReceipt afterReceipt)
    (projection :
      SourceBoundEffectCompletionRecoveryStorageDeferralProgressProjection
        beforeReceipt afterReceipt beforeBudget afterBudget) :
    SourceBoundEffectCompletionRecoveryProgressReceipt
      beforeBudget afterBudget .completionStorageAdmission := by
  apply
    SourceBoundEffectCompletionRecoveryProgressReceipt.storageDeferralDecreased
  · exact projection.crashesStable
  · exact projection.schedulingStable
  · rw [projection.beforeStorageMatches, projection.afterStorageMatches]
    exact
      closedStorageDeferralAdvanceStrictlyDecreases
        closed.advanceCloses

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerDeferralAdmissionContractClosure
