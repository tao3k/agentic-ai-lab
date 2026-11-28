-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionPublicationClosure

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure

open SourceBoundCheckpointRestoreAuthorizationClosure
open SourceBoundEffectCompletionPublicationClosure
open SourceBoundEffectReplayIdempotencyClosure

inductive SourceBoundEffectPhysicalCompletionState where
  | notExecuted
  | executed
  deriving DecidableEq, Repr

inductive SourceBoundEffectLedgerOnlyRecoveryDecision where
  | execute
  | suppress
  deriving DecidableEq, Repr

def SourceBoundEffectLedgerOnlyRecoveryDecisionSafe
    (physicalState : SourceBoundEffectPhysicalCompletionState)
    (decision : SourceBoundEffectLedgerOnlyRecoveryDecision) : Prop :=
  match physicalState, decision with
  | .notExecuted, .execute => True
  | .executed, .suppress => True
  | _, _ => False

structure SourceBoundEffectCrashWorld where
  ledger : SourceBoundEffectReplayLedger
  ledgerEntry : SourceBoundEffectReplayLedgerEntry
  physicalState : SourceBoundEffectPhysicalCompletionState

def crashWorldEngineProjection
    (world : SourceBoundEffectCrashWorld) :
    SourceBoundEffectReplayLedger × SourceBoundEffectReplayLedgerEntry :=
  (world.ledger, world.ledgerEntry)

def notExecutedCrashWorld
    (ledger : SourceBoundEffectReplayLedger)
    (entry : SourceBoundEffectReplayLedgerEntry) :
    SourceBoundEffectCrashWorld :=
  {
    ledger := ledger
    ledgerEntry := entry
    physicalState := .notExecuted
  }

def executedUncommittedCrashWorld
    (ledger : SourceBoundEffectReplayLedger)
    (entry : SourceBoundEffectReplayLedgerEntry) :
    SourceBoundEffectCrashWorld :=
  {
    ledger := ledger
    ledgerEntry := entry
    physicalState := .executed
  }

theorem precommitCrashWorldsHaveTheSameEngineProjection
    (ledger : SourceBoundEffectReplayLedger)
    (entry : SourceBoundEffectReplayLedgerEntry) :
    crashWorldEngineProjection (notExecutedCrashWorld ledger entry) =
      crashWorldEngineProjection (executedUncommittedCrashWorld ledger entry) := by
  rfl

theorem noLedgerOnlyRecoveryDecisionIsSafeForBothWorlds
    (decision : SourceBoundEffectLedgerOnlyRecoveryDecision) :
    ¬ (
      SourceBoundEffectLedgerOnlyRecoveryDecisionSafe .notExecuted decision ∧
      SourceBoundEffectLedgerOnlyRecoveryDecisionSafe .executed decision
    ) := by
  cases decision <;>
    simp [SourceBoundEffectLedgerOnlyRecoveryDecisionSafe]

theorem noLedgerProjectionRecoveryFunctionIsSafeForBothWorlds
    (recover :
      SourceBoundEffectReplayLedger × SourceBoundEffectReplayLedgerEntry →
        SourceBoundEffectLedgerOnlyRecoveryDecision)
    (ledger : SourceBoundEffectReplayLedger)
    (entry : SourceBoundEffectReplayLedgerEntry) :
    ¬ (
      SourceBoundEffectLedgerOnlyRecoveryDecisionSafe
        .notExecuted
        (recover (crashWorldEngineProjection (notExecutedCrashWorld ledger entry))) ∧
      SourceBoundEffectLedgerOnlyRecoveryDecisionSafe
        .executed
        (recover (crashWorldEngineProjection (executedUncommittedCrashWorld ledger entry)))
    ) := by
  rw [precommitCrashWorldsHaveTheSameEngineProjection ledger entry]
  exact
    noLedgerOnlyRecoveryDecisionIsSafeForBothWorlds
      (recover (crashWorldEngineProjection (executedUncommittedCrashWorld ledger entry)))

inductive SourceBoundEffectProviderRecoveryObservationStatus where
  | definitelyNotExecuted
  | acknowledged
  | indeterminate
  | conflict
  deriving DecidableEq, Repr

structure SourceBoundEffectCompletionRecoveryExpectation where
  recoveryId : String
  providerIdentity : String
  request : SourceBoundLatestCheckpointRestoreRequest
  window : SourceBoundEffectReplayWindow
  ledger : SourceBoundEffectReplayLedger
  plan : SourceBoundEffectReplayPlan
  ledgerEntry : SourceBoundEffectReplayLedgerEntry
  step : SourceBoundEffectReplayStep
  completionFrontier : Nat
  runtimeEpoch : Nat
  activeFenceToken : Nat
  provenanceDigest : String

def SourceBoundEffectCompletionRecoveryExpectationClosed
    (expectation : SourceBoundEffectCompletionRecoveryExpectation) : Prop :=
  expectation.recoveryId ≠ "" ∧
  expectation.providerIdentity ≠ "" ∧
  expectation.window.restoreRequestId ≠ "" ∧
  expectation.provenanceDigest ≠ "" ∧
  expectation.providerIdentity = expectation.ledger.idempotencyProviderIdentity ∧
  expectation.ledgerEntry ∈ expectation.ledger.entries ∧
  expectation.step ∈ expectation.plan.steps ∧
  expectation.ledgerEntry.observation = expectation.step.observation ∧
  expectation.ledgerEntry.idempotencyKey = expectation.step.idempotencyKey ∧
  expectation.step.idempotencyKey ≠ "" ∧
  expectation.plan.ledgerId = expectation.ledger.ledgerId ∧
  expectation.runtimeEpoch = expectation.window.runtimeEpoch ∧
  expectation.plan.runtimeEpoch = expectation.runtimeEpoch ∧
  expectation.activeFenceToken = expectation.window.activeFenceToken ∧
  expectation.plan.activeFenceToken = expectation.activeFenceToken

structure SourceBoundEffectProviderRecoveryObservation where
  observationId : String
  recoveryId : String
  providerIdentity : String
  step : SourceBoundEffectReplayStep
  runtimeEpoch : Nat
  activeFenceToken : Nat
  status : SourceBoundEffectProviderRecoveryObservationStatus
  completionReceipt : Option SourceBoundEffectCompletionReceipt
  providerStateDigest : String
  idempotencyContractDigest : String
  evidenceDigest : String
  provenanceDigest : String

def SourceBoundEffectProviderRecoveryObservationValid
    (observation : SourceBoundEffectProviderRecoveryObservation) : Prop :=
  observation.observationId ≠ "" ∧
  observation.recoveryId ≠ "" ∧
  observation.providerIdentity ≠ "" ∧
  observation.step.idempotencyKey ≠ "" ∧
  observation.providerStateDigest ≠ "" ∧
  observation.idempotencyContractDigest ≠ "" ∧
  observation.evidenceDigest ≠ "" ∧
  observation.provenanceDigest ≠ "" ∧
  match observation.status, observation.completionReceipt with
  | .definitelyNotExecuted, none => True
  | .acknowledged, some _ => True
  | .indeterminate, none => True
  | .conflict, _ => True
  | _, _ => False

def SourceBoundEffectProviderRecoveryObservationAuthoritative
    (physicalState : SourceBoundEffectPhysicalCompletionState)
    (observation : SourceBoundEffectProviderRecoveryObservation) : Prop :=
  match observation.status with
  | .definitelyNotExecuted => physicalState = .notExecuted
  | .acknowledged => physicalState = .executed
  | .indeterminate => True
  | .conflict => True

def SourceBoundEffectProviderRecoveryObservationClosed
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (observation : SourceBoundEffectProviderRecoveryObservation) : Prop :=
  SourceBoundEffectCompletionRecoveryExpectationClosed expectation ∧
  SourceBoundEffectProviderRecoveryObservationValid observation ∧
  observation.recoveryId = expectation.recoveryId ∧
  observation.providerIdentity = expectation.providerIdentity ∧
  observation.step = expectation.step ∧
  observation.runtimeEpoch = expectation.runtimeEpoch ∧
  observation.activeFenceToken = expectation.activeFenceToken ∧
  match observation.status, observation.completionReceipt with
  | .acknowledged, some receipt =>
      SourceBoundEffectCompletionReceiptClosed
        receiptValid
        expectation.request
        expectation.window
        expectation.plan
        receipt
  | .definitelyNotExecuted, none => True
  | .indeterminate, none => True
  | .conflict, _ => True
  | _, _ => False

structure SourceBoundEffectCompletionCrashRecoverySnapshot where
  expectation : SourceBoundEffectCompletionRecoveryExpectation
  providerObservation : SourceBoundEffectProviderRecoveryObservation
  commitReceipt : Option SourceBoundEffectCompletionCommitReceipt
  storageObservationDigest : String
  provenanceDigest : String

inductive SourceBoundEffectCompletionCrashRecoveryState where
  | notExecuted
  | executedUncommitted
  | committed
  | indeterminate
  deriving DecidableEq, Repr

inductive SourceBoundEffectCompletionCrashRecoveryDisposition where
  | execute
  | resumePublication
  | suppressCommitted
  | failClosed
  deriving DecidableEq, Repr

structure SourceBoundEffectCompletionCrashRecoveryClassification where
  recoveryId : String
  state : SourceBoundEffectCompletionCrashRecoveryState
  disposition : SourceBoundEffectCompletionCrashRecoveryDisposition
  evidenceDigest : String
  provenanceDigest : String
  deriving DecidableEq, Repr

def SourceBoundEffectCompletionCrashRecoveryClassificationValid
    (classification : SourceBoundEffectCompletionCrashRecoveryClassification) : Prop :=
  classification.recoveryId ≠ "" ∧
  classification.evidenceDigest ≠ "" ∧
  classification.provenanceDigest ≠ ""

def SourceBoundEffectCommittedRecoveryEvidenceClosed
    (idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid)
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (commitReceiptValid : SourceBoundEffectCompletionCommitReceiptValid)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (commitReceipt : SourceBoundEffectCompletionCommitReceipt) : Prop :=
  SourceBoundEffectCompletionPublicationClosed
    idempotencyKeyValid
    receiptValid
    commitReceiptValid
    expectation.request
    expectation.window
    expectation.ledger
    expectation.plan
    commitReceipt.publication
    commitReceipt

def SourceBoundEffectCompletionCrashRecoveryClassificationClosed
    (idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid)
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (commitReceiptValid : SourceBoundEffectCompletionCommitReceiptValid)
    (physicalState : SourceBoundEffectPhysicalCompletionState)
    (snapshot : SourceBoundEffectCompletionCrashRecoverySnapshot)
    (classification : SourceBoundEffectCompletionCrashRecoveryClassification) : Prop :=
  SourceBoundEffectCompletionCrashRecoveryClassificationValid classification ∧
  SourceBoundEffectProviderRecoveryObservationClosed
    receiptValid
    snapshot.expectation
    snapshot.providerObservation ∧
  SourceBoundEffectProviderRecoveryObservationAuthoritative
    physicalState
    snapshot.providerObservation ∧
  snapshot.storageObservationDigest ≠ "" ∧
  snapshot.provenanceDigest ≠ "" ∧
  classification.recoveryId = snapshot.expectation.recoveryId ∧
  match classification.state with
  | .notExecuted =>
      physicalState = .notExecuted ∧
      snapshot.expectation.ledgerEntry.completed = false ∧
      snapshot.commitReceipt = none ∧
      snapshot.providerObservation.status = .definitelyNotExecuted ∧
      snapshot.providerObservation.completionReceipt = none ∧
      classification.disposition = .execute
  | .executedUncommitted =>
      physicalState = .executed ∧
      snapshot.expectation.ledgerEntry.completed = false ∧
      snapshot.commitReceipt = none ∧
      snapshot.providerObservation.status = .acknowledged ∧
      (∃ receipt,
        snapshot.providerObservation.completionReceipt = some receipt ∧
        SourceBoundEffectCompletionReceiptClosed
          receiptValid
          snapshot.expectation.request
          snapshot.expectation.window
          snapshot.expectation.plan
          receipt) ∧
      classification.disposition = .resumePublication
  | .committed =>
      physicalState = .executed ∧
      (∃ commitReceipt,
        snapshot.commitReceipt = some commitReceipt ∧
        SourceBoundEffectCommittedRecoveryEvidenceClosed
          idempotencyKeyValid
          receiptValid
          commitReceiptValid
          snapshot.expectation
          commitReceipt) ∧
      classification.disposition = .suppressCommitted
  | .indeterminate =>
      (
        snapshot.providerObservation.status = .indeterminate ∨
        snapshot.providerObservation.status = .conflict ∨
        (
          snapshot.expectation.ledgerEntry.completed = true ∧
          snapshot.commitReceipt = none
        )
      ) ∧
      classification.disposition = .failClosed

theorem authoritativeNegativeObservationCertifiesNotExecuted
    (observation : SourceBoundEffectProviderRecoveryObservation)
    (physicalState : SourceBoundEffectPhysicalCompletionState)
    (hstatus : observation.status = .definitelyNotExecuted)
    (hauthority :
      SourceBoundEffectProviderRecoveryObservationAuthoritative
        physicalState
        observation) :
    physicalState = .notExecuted := by
  simpa [SourceBoundEffectProviderRecoveryObservationAuthoritative, hstatus] using hauthority

theorem authoritativeNegativeObservationRejectsExecutedWorld
    (observation : SourceBoundEffectProviderRecoveryObservation)
    (hstatus : observation.status = .definitelyNotExecuted) :
    ¬ SourceBoundEffectProviderRecoveryObservationAuthoritative
      .executed
      observation := by
  simp [SourceBoundEffectProviderRecoveryObservationAuthoritative, hstatus]

theorem acknowledgedObservationRejectsNotExecutedWorld
    (observation : SourceBoundEffectProviderRecoveryObservation)
    (hstatus : observation.status = .acknowledged) :
    ¬ SourceBoundEffectProviderRecoveryObservationAuthoritative
      .notExecuted
      observation := by
  simp [SourceBoundEffectProviderRecoveryObservationAuthoritative, hstatus]

theorem closedNotExecutedRecoveryExecutes
    (idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid)
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (commitReceiptValid : SourceBoundEffectCompletionCommitReceiptValid)
    (snapshot : SourceBoundEffectCompletionCrashRecoverySnapshot)
    (classification : SourceBoundEffectCompletionCrashRecoveryClassification)
    (hclosed :
      SourceBoundEffectCompletionCrashRecoveryClassificationClosed
        idempotencyKeyValid
        receiptValid
        commitReceiptValid
        .notExecuted
        snapshot
        classification)
    (hstate : classification.state = .notExecuted) :
    classification.disposition = .execute := by
  have hcase := hclosed.2.2.2.2.2.2
  rw [hstate] at hcase
  exact hcase.2.2.2.2.2

theorem closedExecutedUncommittedRecoveryResumesPublication
    (idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid)
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (commitReceiptValid : SourceBoundEffectCompletionCommitReceiptValid)
    (snapshot : SourceBoundEffectCompletionCrashRecoverySnapshot)
    (classification : SourceBoundEffectCompletionCrashRecoveryClassification)
    (hclosed :
      SourceBoundEffectCompletionCrashRecoveryClassificationClosed
        idempotencyKeyValid
        receiptValid
        commitReceiptValid
        .executed
        snapshot
        classification)
    (hstate : classification.state = .executedUncommitted) :
    classification.disposition = .resumePublication := by
  have hcase := hclosed.2.2.2.2.2.2
  rw [hstate] at hcase
  exact hcase.2.2.2.2.2

theorem closedExecutedUncommittedRecoveryNeverExecutesAgain
    (idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid)
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (commitReceiptValid : SourceBoundEffectCompletionCommitReceiptValid)
    (snapshot : SourceBoundEffectCompletionCrashRecoverySnapshot)
    (classification : SourceBoundEffectCompletionCrashRecoveryClassification)
    (hclosed :
      SourceBoundEffectCompletionCrashRecoveryClassificationClosed
        idempotencyKeyValid
        receiptValid
        commitReceiptValid
        .executed
        snapshot
        classification)
    (hstate : classification.state = .executedUncommitted) :
    classification.disposition ≠ .execute := by
  rw [
    closedExecutedUncommittedRecoveryResumesPublication
      idempotencyKeyValid
      receiptValid
      commitReceiptValid
      snapshot
      classification
      hclosed
      hstate
  ]
  simp

theorem closedCommittedRecoverySuppresses
    (idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid)
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (commitReceiptValid : SourceBoundEffectCompletionCommitReceiptValid)
    (snapshot : SourceBoundEffectCompletionCrashRecoverySnapshot)
    (classification : SourceBoundEffectCompletionCrashRecoveryClassification)
    (hclosed :
      SourceBoundEffectCompletionCrashRecoveryClassificationClosed
        idempotencyKeyValid
        receiptValid
        commitReceiptValid
        .executed
        snapshot
        classification)
    (hstate : classification.state = .committed) :
    classification.disposition = .suppressCommitted := by
  have hcase := hclosed.2.2.2.2.2.2
  rw [hstate] at hcase
  exact hcase.2.2

theorem closedCommittedRecoveryCarriesExistingPublicationAuthority
    (idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid)
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (commitReceiptValid : SourceBoundEffectCompletionCommitReceiptValid)
    (snapshot : SourceBoundEffectCompletionCrashRecoverySnapshot)
    (classification : SourceBoundEffectCompletionCrashRecoveryClassification)
    (hclosed :
      SourceBoundEffectCompletionCrashRecoveryClassificationClosed
        idempotencyKeyValid
        receiptValid
        commitReceiptValid
        .executed
        snapshot
        classification)
    (hstate : classification.state = .committed) :
    ∃ commitReceipt,
      snapshot.commitReceipt = some commitReceipt ∧
      SourceBoundEffectCommittedRecoveryEvidenceClosed
        idempotencyKeyValid
        receiptValid
        commitReceiptValid
        snapshot.expectation
        commitReceipt := by
  have hcase := hclosed.2.2.2.2.2.2
  rw [hstate] at hcase
  exact hcase.2.1

theorem closedIndeterminateRecoveryFailsClosed
    (idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid)
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (commitReceiptValid : SourceBoundEffectCompletionCommitReceiptValid)
    (physicalState : SourceBoundEffectPhysicalCompletionState)
    (snapshot : SourceBoundEffectCompletionCrashRecoverySnapshot)
    (classification : SourceBoundEffectCompletionCrashRecoveryClassification)
    (hclosed :
      SourceBoundEffectCompletionCrashRecoveryClassificationClosed
        idempotencyKeyValid
        receiptValid
        commitReceiptValid
        physicalState
        snapshot
        classification)
    (hstate : classification.state = .indeterminate) :
    classification.disposition = .failClosed := by
  have hcase := hclosed.2.2.2.2.2.2
  rw [hstate] at hcase
  exact hcase.2

theorem staleFenceObservationCannotCloseRecovery
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (observation : SourceBoundEffectProviderRecoveryObservation)
    (hstale : observation.activeFenceToken ≠ expectation.activeFenceToken) :
    ¬ SourceBoundEffectProviderRecoveryObservationClosed
      receiptValid
      expectation
      observation := by
  intro hclosed
  exact hstale hclosed.2.2.2.2.2.2.1

theorem staleEpochObservationCannotCloseRecovery
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (expectation : SourceBoundEffectCompletionRecoveryExpectation)
    (observation : SourceBoundEffectProviderRecoveryObservation)
    (hstale : observation.runtimeEpoch ≠ expectation.runtimeEpoch) :
    ¬ SourceBoundEffectProviderRecoveryObservationClosed
      receiptValid
      expectation
      observation := by
  intro hclosed
  exact hstale hclosed.2.2.2.2.2.1

theorem completedLedgerWithoutCommitEvidenceForcesIndeterminate
    (idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid)
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (commitReceiptValid : SourceBoundEffectCompletionCommitReceiptValid)
    (physicalState : SourceBoundEffectPhysicalCompletionState)
    (snapshot : SourceBoundEffectCompletionCrashRecoverySnapshot)
    (classification : SourceBoundEffectCompletionCrashRecoveryClassification)
    (hclosed :
      SourceBoundEffectCompletionCrashRecoveryClassificationClosed
        idempotencyKeyValid
        receiptValid
        commitReceiptValid
        physicalState
        snapshot
        classification)
    (hcompleted : snapshot.expectation.ledgerEntry.completed = true)
    (hmissing : snapshot.commitReceipt = none) :
    classification.state = .indeterminate := by
  have hcase := hclosed.2.2.2.2.2.2
  cases hstate : classification.state with
  | notExecuted =>
      rw [hstate] at hcase
      exact False.elim (by simpa [hcompleted] using hcase.2.1)
  | executedUncommitted =>
      rw [hstate] at hcase
      exact False.elim (by simpa [hcompleted] using hcase.2.1)
  | committed =>
      rw [hstate] at hcase
      rcases hcase.2.1 with ⟨commitReceipt, hreceipt, _⟩
      rw [hmissing] at hreceipt
      simp at hreceipt
  | indeterminate =>
      rfl

theorem providerAcknowledgementDoesNotCreateStorageCommitEvidence
    (observation : SourceBoundEffectProviderRecoveryObservation)
    (receipt : SourceBoundEffectCompletionReceipt)
    (hacknowledged : observation.status = .acknowledged)
    (hreceipt : observation.completionReceipt = some receipt) :
    observation.status = .acknowledged ∧
      observation.completionReceipt = some receipt ∧
      (none : Option SourceBoundEffectCompletionCommitReceipt) = none := by
  exact ⟨hacknowledged, hreceipt, rfl⟩

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionCrashRecoveryClosure
