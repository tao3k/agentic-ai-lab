-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Lean
import AgenticAILabProof.Enterprise.SourceBoundEffectReplayIdempotencyClosure

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionPublicationClosure

open Lean
open AgenticAILabProof.Enterprise.SourceBoundCheckpointRestoreAuthorizationClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectReplayIdempotencyClosure

/-!
# Source-bound effect completion publication closure

This module is a v1 refinement.  It does not replace the replay event, ledger,
plan, or retry-authority owners.  It closes the later boundary between an
authorized execute step and a committed ledger/frontier transition.
-/

structure SourceBoundEffectCompletionReceipt where
  receiptId : String
  providerIdentity : String
  restoreRequestId : String
  windowId : String
  planId : String
  step : SourceBoundEffectReplayStep
  runtimeEpoch : Nat
  activeFenceToken : Nat
  successful : Bool
  resultDigest : String
  providerAcknowledgementDigest : String
  provenanceDigest : String

def SourceBoundEffectCompletionReceiptValid :=
  SourceBoundEffectCompletionReceipt → Prop

structure SourceBoundEffectCompletionReceiptClosed
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (request : SourceBoundLatestCheckpointRestoreRequest)
    (window : SourceBoundEffectReplayWindow)
    (plan : SourceBoundEffectReplayPlan)
    (receipt : SourceBoundEffectCompletionReceipt) : Prop where
  receiptValidates : receiptValid receipt
  successful : receipt.successful = true
  restoreRequestIdentityMatches : receipt.restoreRequestId = request.requestId
  windowIdentityMatches : receipt.windowId = window.windowId
  planIdentityMatches : receipt.planId = plan.planId
  runtimeEpochMatches : receipt.runtimeEpoch = request.runtimeEpoch
  activeFenceTokenMatches : receipt.activeFenceToken = request.activeFenceToken
  stepBelongsToPlan : receipt.step ∈ plan.steps
  stepExecutes : receipt.step.action = SourceBoundEffectReplayAction.execute
  idempotencyIdentityPresent : receipt.step.idempotencyKey ≠ ""
  receiptIdentityPresent : receipt.receiptId ≠ ""
  providerIdentityPresent : receipt.providerIdentity ≠ ""
  resultPresent : receipt.resultDigest ≠ ""
  providerAcknowledgementPresent : receipt.providerAcknowledgementDigest ≠ ""
  provenancePresent : receipt.provenanceDigest ≠ ""

structure SourceBoundEffectCompletionValidationExpectation where
  schemaId : String
  restoreRequestId : String
  windowId : String
  planId : String
  runtimeEpoch : Nat
  activeFenceToken : Nat
  deriving Lean.ToJson, Lean.FromJson

structure SourceBoundEffectCompletionValidationProjection where
  schemaId : String
  receiptId : String
  providerIdentity : String
  restoreRequestId : String
  windowId : String
  planId : String
  traceSequence : Nat
  idempotencyKey : String
  action : String
  runtimeEpoch : Nat
  activeFenceToken : Nat
  successful : Bool
  resultDigest : String
  providerAcknowledgementDigest : String
  provenanceDigest : String
  deriving Lean.ToJson, Lean.FromJson

def completionValidationSchemaId : String :=
  "agentic-ai-lab.effect-completion-validation.v1"

def replayActionName : SourceBoundEffectReplayAction → String
  | .execute => "execute"
  | .suppressCompleted => "suppress-completed"

def completionValidationProjection
    (receipt : SourceBoundEffectCompletionReceipt) :
    SourceBoundEffectCompletionValidationProjection :=
  {
    schemaId := completionValidationSchemaId
    receiptId := receipt.receiptId
    providerIdentity := receipt.providerIdentity
    restoreRequestId := receipt.restoreRequestId
    windowId := receipt.windowId
    planId := receipt.planId
    traceSequence := receipt.step.observation.traceSequence
    idempotencyKey := receipt.step.idempotencyKey
    action := replayActionName receipt.step.action
    runtimeEpoch := receipt.runtimeEpoch
    activeFenceToken := receipt.activeFenceToken
    successful := receipt.successful
    resultDigest := receipt.resultDigest
    providerAcknowledgementDigest := receipt.providerAcknowledgementDigest
    provenanceDigest := receipt.provenanceDigest
  }

def validationErrorUnless (condition : Bool) (message : String) : List String :=
  if condition then [] else [message]

def completionValidationErrors
    (expected : SourceBoundEffectCompletionValidationExpectation)
    (projection : SourceBoundEffectCompletionValidationProjection) : List String :=
  validationErrorUnless
      (decide (expected.schemaId = completionValidationSchemaId))
      "expectation-schema-invalid" ++
    validationErrorUnless
      (decide (projection.schemaId = expected.schemaId))
      "schema-mismatch" ++
    validationErrorUnless
      (decide (projection.restoreRequestId = expected.restoreRequestId))
      "restore-request-mismatch" ++
    validationErrorUnless
      (decide (projection.windowId = expected.windowId))
      "window-mismatch" ++
    validationErrorUnless
      (decide (projection.planId = expected.planId))
      "plan-mismatch" ++
    validationErrorUnless
      (decide (projection.runtimeEpoch = expected.runtimeEpoch))
      "runtime-epoch-mismatch" ++
    validationErrorUnless
      (decide (projection.activeFenceToken = expected.activeFenceToken))
      "active-fence-token-mismatch" ++
    validationErrorUnless
      (decide (projection.action = "execute"))
      "action-is-not-execute" ++
    validationErrorUnless projection.successful
      "provider-did-not-report-success" ++
    validationErrorUnless
      (decide (projection.receiptId ≠ ""))
      "receipt-id-empty" ++
    validationErrorUnless
      (decide (projection.providerIdentity ≠ ""))
      "provider-identity-empty" ++
    validationErrorUnless
      (decide (projection.idempotencyKey ≠ ""))
      "idempotency-key-empty" ++
    validationErrorUnless
      (decide (projection.resultDigest ≠ ""))
      "result-digest-empty" ++
    validationErrorUnless
      (decide (projection.providerAcknowledgementDigest ≠ ""))
      "provider-acknowledgement-empty" ++
    validationErrorUnless
      (decide (projection.provenanceDigest ≠ ""))
      "provenance-digest-empty"

structure SourceBoundEffectCompletionValidationResult where
  schemaId : String
  okay : Bool
  receiptId : String
  errors : List String
  deriving Lean.ToJson, Lean.FromJson

def completionValidationResult
    (expected : SourceBoundEffectCompletionValidationExpectation)
    (projection : SourceBoundEffectCompletionValidationProjection) :
    SourceBoundEffectCompletionValidationResult :=
  let errors := completionValidationErrors expected projection
  {
    schemaId := completionValidationSchemaId
    okay := errors.isEmpty
    receiptId := projection.receiptId
    errors
  }

inductive SourceBoundEffectCompletionDisposition where
  | executed (receipt : SourceBoundEffectCompletionReceipt)
  | suppressed

structure SourceBoundEffectCompletionPublicationItem where
  beforeEntry : SourceBoundEffectReplayLedgerEntry
  afterEntry : SourceBoundEffectReplayLedgerEntry
  step : SourceBoundEffectReplayStep
  disposition : SourceBoundEffectCompletionDisposition

def publicationItemCompletionReceipts
    (item : SourceBoundEffectCompletionPublicationItem) :
    List SourceBoundEffectCompletionReceipt :=
  match item.disposition with
  | .executed receipt => [receipt]
  | .suppressed => []

def publicationItemExecutedKeys
    (item : SourceBoundEffectCompletionPublicationItem) : List String :=
  match item.disposition with
  | .executed receipt => [receipt.step.idempotencyKey]
  | .suppressed => []

def SourceBoundEffectCompletionPublicationItemClosed
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (request : SourceBoundLatestCheckpointRestoreRequest)
    (window : SourceBoundEffectReplayWindow)
    (plan : SourceBoundEffectReplayPlan)
    (item : SourceBoundEffectCompletionPublicationItem) : Prop :=
  replayStepMatchesLedgerEntry item.step item.beforeEntry ∧
    item.afterEntry.observation = item.beforeEntry.observation ∧
    item.afterEntry.idempotencyKey = item.beforeEntry.idempotencyKey ∧
    item.afterEntry.replaySafe = item.beforeEntry.replaySafe ∧
    match item.disposition with
    | .executed receipt =>
        SourceBoundEffectCompletionReceiptClosed
            receiptValid request window plan receipt ∧
          receipt.step = item.step ∧
          item.step.action = SourceBoundEffectReplayAction.execute ∧
          item.beforeEntry.completed = false ∧
          item.beforeEntry.replaySafe = true ∧
          item.afterEntry.completed = true ∧
          item.afterEntry.completionReceiptId = receipt.receiptId
    | .suppressed =>
        item.step.action = SourceBoundEffectReplayAction.suppressCompleted ∧
          item.beforeEntry.completed = true ∧
          item.afterEntry = item.beforeEntry

structure SourceBoundEffectCompletionPublication where
  publicationId : String
  restoreRequestId : String
  window : SourceBoundEffectReplayWindow
  plan : SourceBoundEffectReplayPlan
  ledgerBefore : SourceBoundEffectReplayLedger
  ledgerAfter : SourceBoundEffectReplayLedger
  completionFrontierBefore : Nat
  completionFrontierAfter : Nat
  runtimeEpoch : Nat
  activeFenceToken : Nat
  items : List SourceBoundEffectCompletionPublicationItem
  provenanceDigest : String

def publicationCompletionReceipts
    (publication : SourceBoundEffectCompletionPublication) :
    List SourceBoundEffectCompletionReceipt :=
  publication.items.flatMap publicationItemCompletionReceipts

def publicationExecutedKeys
    (publication : SourceBoundEffectCompletionPublication) : List String :=
  publication.items.flatMap publicationItemExecutedKeys

structure SourceBoundEffectCompletionCommitReceipt where
  commitReceiptId : String
  providerIdentity : String
  publication : SourceBoundEffectCompletionPublication
  committed : Bool
  storageTransactionDigest : String
  evidenceDigest : String

def SourceBoundEffectCompletionCommitReceiptValid :=
  SourceBoundEffectCompletionCommitReceipt → Prop

structure SourceBoundEffectCompletionCommitReceiptClosed
    (commitValid : SourceBoundEffectCompletionCommitReceiptValid)
    (publication : SourceBoundEffectCompletionPublication)
    (receipt : SourceBoundEffectCompletionCommitReceipt) : Prop where
  commitValidates : commitValid receipt
  committed : receipt.committed = true
  exactPublicationMatches : receipt.publication = publication
  commitReceiptIdentityPresent : receipt.commitReceiptId ≠ ""
  providerIdentityPresent : receipt.providerIdentity ≠ ""
  storageTransactionPresent : receipt.storageTransactionDigest ≠ ""
  evidencePresent : receipt.evidenceDigest ≠ ""

structure SourceBoundEffectCompletionPublicationClosed
    (idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid)
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (commitValid : SourceBoundEffectCompletionCommitReceiptValid)
    (request : SourceBoundLatestCheckpointRestoreRequest)
    (window : SourceBoundEffectReplayWindow)
    (ledger : SourceBoundEffectReplayLedger)
    (plan : SourceBoundEffectReplayPlan)
    (publication : SourceBoundEffectCompletionPublication)
    (commitReceipt : SourceBoundEffectCompletionCommitReceipt) : Prop where
  ledgerBeforeCloses :
    SourceBoundEffectReplayLedgerClosed idempotencyKeyValid window ledger
  planCloses :
    SourceBoundEffectReplayPlanClosed request window ledger plan
  restoreRequestIdentityMatches :
    publication.restoreRequestId = request.requestId
  exactWindowMatches : publication.window = window
  exactPlanMatches : publication.plan = plan
  exactLedgerBeforeMatches : publication.ledgerBefore = ledger
  runtimeEpochMatches : publication.runtimeEpoch = request.runtimeEpoch
  activeFenceTokenMatches :
    publication.activeFenceToken = request.activeFenceToken
  planLedgerIdentityMatches : plan.ledgerId = ledger.ledgerId
  exactBeforeEntryProjection :
    List.map (fun item => item.beforeEntry) publication.items =
      publication.ledgerBefore.entries
  exactAfterEntryProjection :
    List.map (fun item => item.afterEntry) publication.items =
      publication.ledgerAfter.entries
  exactPlanStepProjection :
    List.map (fun item => item.step) publication.items = plan.steps
  everyPublicationItemCloses :
    ∀ item,
      item ∈ publication.items →
        SourceBoundEffectCompletionPublicationItemClosed
          receiptValid request window plan item
  completionReceiptsPresent :
    publicationCompletionReceipts publication ≠ []
  completionReceiptIdentitiesUnique :
    List.Pairwise
      (fun left right => left.receiptId ≠ right.receiptId)
      (publicationCompletionReceipts publication)
  executedIdempotencyKeysUnique :
    List.Pairwise (fun left right => left ≠ right)
      (publicationExecutedKeys publication)
  ledgerProviderIdentityPreserved :
    publication.ledgerAfter.idempotencyProviderIdentity =
      publication.ledgerBefore.idempotencyProviderIdentity
  ledgerIdentityAdvances :
    publication.ledgerAfter.ledgerId ≠ publication.ledgerBefore.ledgerId
  ledgerProvenanceAdvances :
    publication.ledgerAfter.provenanceDigest ≠
      publication.ledgerBefore.provenanceDigest
  ledgerAfterCloses :
    SourceBoundEffectReplayLedgerClosed
      idempotencyKeyValid window publication.ledgerAfter
  completionFrontierAdvancesOnce :
    publication.completionFrontierAfter =
      publication.completionFrontierBefore + 1
  publicationIdentityPresent : publication.publicationId ≠ ""
  provenancePresent : publication.provenanceDigest ≠ ""
  commitReceiptCloses :
    SourceBoundEffectCompletionCommitReceiptClosed
      commitValid publication commitReceipt

def completionPublicationChainClosed :
    SourceBoundEffectCompletionPublication →
      List SourceBoundEffectCompletionPublication → Prop
  | _, [] => True
  | current, next :: remaining =>
      current.ledgerAfter = next.ledgerBefore ∧
        current.completionFrontierAfter = next.completionFrontierBefore ∧
        completionPublicationChainClosed next remaining

def lastCompletionPublication
    (first : SourceBoundEffectCompletionPublication) :
    List SourceBoundEffectCompletionPublication →
      SourceBoundEffectCompletionPublication
  | [] => first
  | next :: remaining => lastCompletionPublication next remaining

structure SourceBoundEffectCompletionPublicationHistory where
  historyId : String
  restoreRequestId : String
  initialLedger : SourceBoundEffectReplayLedger
  finalLedger : SourceBoundEffectReplayLedger
  initialCompletionFrontier : Nat
  finalCompletionFrontier : Nat
  firstPublication : SourceBoundEffectCompletionPublication
  remainingPublications : List SourceBoundEffectCompletionPublication
  commitReceipts : List SourceBoundEffectCompletionCommitReceipt
  provenanceDigest : String

def historyPublications
    (history : SourceBoundEffectCompletionPublicationHistory) :
    List SourceBoundEffectCompletionPublication :=
  history.firstPublication :: history.remainingPublications

def historyCompletionReceipts
    (history : SourceBoundEffectCompletionPublicationHistory) :
    List SourceBoundEffectCompletionReceipt :=
  (historyPublications history).flatMap publicationCompletionReceipts

def historyExecutedKeys
    (history : SourceBoundEffectCompletionPublicationHistory) : List String :=
  (historyPublications history).flatMap publicationExecutedKeys

structure SourceBoundEffectCompletionPublicationHistoryClosed
    (idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid)
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (commitValid : SourceBoundEffectCompletionCommitReceiptValid)
    (request : SourceBoundLatestCheckpointRestoreRequest)
    (window : SourceBoundEffectReplayWindow)
    (ledger : SourceBoundEffectReplayLedger)
    (plan : SourceBoundEffectReplayPlan)
    (history : SourceBoundEffectCompletionPublicationHistory) : Prop where
  restoreRequestIdentityMatches :
    history.restoreRequestId = request.requestId
  initialLedgerMatches :
    history.firstPublication.ledgerBefore = history.initialLedger
  initialReplayLedgerMatches : history.initialLedger = ledger
  initialFrontierMatches :
    history.firstPublication.completionFrontierBefore =
      history.initialCompletionFrontier
  finalLedgerMatches :
    (lastCompletionPublication
      history.firstPublication history.remainingPublications).ledgerAfter =
        history.finalLedger
  finalFrontierMatches :
    (lastCompletionPublication
      history.firstPublication
      history.remainingPublications).completionFrontierAfter =
        history.finalCompletionFrontier
  publicationChainCloses :
    completionPublicationChainClosed
      history.firstPublication history.remainingPublications
  exactCommitReceiptProjection :
    List.map (fun receipt => receipt.publication) history.commitReceipts =
      historyPublications history
  everyPublicationCloses :
    ∀ publication,
      publication ∈ historyPublications history →
        ∃ commitReceipt,
          commitReceipt ∈ history.commitReceipts ∧
            SourceBoundEffectCompletionPublicationClosed
              idempotencyKeyValid receiptValid commitValid
              request window publication.ledgerBefore plan
              publication commitReceipt
  publicationIdentitiesUnique :
    List.Pairwise
      (fun left right => left.publicationId ≠ right.publicationId)
      (historyPublications history)
  commitReceiptIdentitiesUnique :
    List.Pairwise
      (fun left right => left.commitReceiptId ≠ right.commitReceiptId)
      history.commitReceipts
  completionReceiptIdentitiesUnique :
    List.Pairwise
      (fun left right => left.receiptId ≠ right.receiptId)
      (historyCompletionReceipts history)
  executedIdempotencyKeysUnique :
    List.Pairwise (fun left right => left ≠ right)
      (historyExecutedKeys history)
  historyIdentityPresent : history.historyId ≠ ""
  provenancePresent : history.provenanceDigest ≠ ""

theorem opaqueReceiptIdentityCanCloseLedgerEntryWithoutReceiptEvidence
    (observation : SourceBoundEffectReplayObservation) :
    replayLedgerEntryClosed
      {
        observation
        idempotencyKey := "idempotency-key"
        completed := true
        replaySafe := false
        completionReceiptId := "opaque-receipt-id"
      } := by
  simp [replayLedgerEntryClosed]

theorem emptyReceiptIdentityIsRejectedByJson
    (expected : SourceBoundEffectCompletionValidationExpectation)
    (projection : SourceBoundEffectCompletionValidationProjection)
    (identityEmpty : projection.receiptId = "") :
    "receipt-id-empty" ∈ completionValidationErrors expected projection := by
  simp [completionValidationErrors, validationErrorUnless, identityEmpty]

theorem jsonValidationDoesNotEntailProviderAuthority
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (expected : SourceBoundEffectCompletionValidationExpectation)
    (receipt : SourceBoundEffectCompletionReceipt)
    (jsonAccepted :
      (completionValidationResult
        expected (completionValidationProjection receipt)).okay = true)
    (providerRejects : ¬ receiptValid receipt) :
    (completionValidationResult
        expected (completionValidationProjection receipt)).okay = true ∧
      ¬ receiptValid receipt :=
  ⟨jsonAccepted, providerRejects⟩

theorem completionEvidenceDoesNotEntailAtomicCommitAuthority
    (receiptValid : SourceBoundEffectCompletionReceiptValid)
    (commitValid : SourceBoundEffectCompletionCommitReceiptValid)
    (completion : SourceBoundEffectCompletionReceipt)
    (commit : SourceBoundEffectCompletionCommitReceipt)
    (completionAccepted : receiptValid completion)
    (commitRejected : ¬ commitValid commit) :
    receiptValid completion ∧ ¬ commitValid commit :=
  ⟨completionAccepted, commitRejected⟩

theorem closedCompletionReceiptBindsCurrentFenceToken
    {receiptValid : SourceBoundEffectCompletionReceiptValid}
    {request : SourceBoundLatestCheckpointRestoreRequest}
    {window : SourceBoundEffectReplayWindow}
    {plan : SourceBoundEffectReplayPlan}
    {receipt : SourceBoundEffectCompletionReceipt}
    (closes :
      SourceBoundEffectCompletionReceiptClosed
        receiptValid request window plan receipt) :
    receipt.activeFenceToken = request.activeFenceToken :=
  closes.activeFenceTokenMatches

theorem closedAtomicCommitBindsExactPublication
    {commitValid : SourceBoundEffectCompletionCommitReceiptValid}
    {publication : SourceBoundEffectCompletionPublication}
    {receipt : SourceBoundEffectCompletionCommitReceipt}
    (closes :
      SourceBoundEffectCompletionCommitReceiptClosed
        commitValid publication receipt) :
    receipt.publication = publication :=
  closes.exactPublicationMatches

theorem duplicateCommittedKeyViolatesHistoryUniqueness
    (key : String) :
    ¬ List.Pairwise (fun left right => left ≠ right) [key, key] := by
  simp

theorem closedCompletionHistorySeparatesCommittedKeys
    {idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid}
    {receiptValid : SourceBoundEffectCompletionReceiptValid}
    {commitValid : SourceBoundEffectCompletionCommitReceiptValid}
    {request : SourceBoundLatestCheckpointRestoreRequest}
    {window : SourceBoundEffectReplayWindow}
    {ledger : SourceBoundEffectReplayLedger}
    {plan : SourceBoundEffectReplayPlan}
    {history : SourceBoundEffectCompletionPublicationHistory}
    (closes :
      SourceBoundEffectCompletionPublicationHistoryClosed
        idempotencyKeyValid receiptValid commitValid
        request window ledger plan history) :
    List.Pairwise (fun left right => left ≠ right)
      (historyExecutedKeys history) :=
  closes.executedIdempotencyKeysUnique

theorem duplicatedCommittedKeyCannotCloseHistory
    {idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid}
    {receiptValid : SourceBoundEffectCompletionReceiptValid}
    {commitValid : SourceBoundEffectCompletionCommitReceiptValid}
    {request : SourceBoundLatestCheckpointRestoreRequest}
    {window : SourceBoundEffectReplayWindow}
    {ledger : SourceBoundEffectReplayLedger}
    {plan : SourceBoundEffectReplayPlan}
    {history : SourceBoundEffectCompletionPublicationHistory}
    (closes :
      SourceBoundEffectCompletionPublicationHistoryClosed
        idempotencyKeyValid receiptValid commitValid
        request window ledger plan history)
    (key : String)
    (duplicates : historyExecutedKeys history = [key, key]) :
    False := by
  have unique := closes.executedIdempotencyKeysUnique
  rw [duplicates] at unique
  simp at unique

theorem emptyCommitReceiptCoverageCannotCloseHistory
    {idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid}
    {receiptValid : SourceBoundEffectCompletionReceiptValid}
    {commitValid : SourceBoundEffectCompletionCommitReceiptValid}
    {request : SourceBoundLatestCheckpointRestoreRequest}
    {window : SourceBoundEffectReplayWindow}
    {ledger : SourceBoundEffectReplayLedger}
    {plan : SourceBoundEffectReplayPlan}
    {history : SourceBoundEffectCompletionPublicationHistory}
    (closes :
      SourceBoundEffectCompletionPublicationHistoryClosed
        idempotencyKeyValid receiptValid commitValid
        request window ledger plan history) :
    history.commitReceipts ≠ [] := by
  intro receiptsEmpty
  have exactCoverage := closes.exactCommitReceiptProjection
  rw [receiptsEmpty] at exactCoverage
  simp [historyPublications] at exactCoverage

theorem independentlyClosedCompletionOwnersCompose
    {ReplayEvidence CompletionEvidence : Prop}
    (replayCloses : ReplayEvidence)
    (completionCloses : CompletionEvidence) :
    ReplayEvidence ∧ CompletionEvidence :=
  ⟨replayCloses, completionCloses⟩

def concreteCompletionValidationExpectation :
    SourceBoundEffectCompletionValidationExpectation :=
  {
    schemaId := completionValidationSchemaId
    restoreRequestId := "restore-request-1"
    windowId := "replay-window-1"
    planId := "replay-plan-1"
    runtimeEpoch := 7
    activeFenceToken := 8
  }

def concreteCompletionValidationProjection :
    SourceBoundEffectCompletionValidationProjection :=
  {
    schemaId := completionValidationSchemaId
    receiptId := "completion-receipt-1"
    providerIdentity := "effect-provider-1"
    restoreRequestId := "restore-request-1"
    windowId := "replay-window-1"
    planId := "replay-plan-1"
    traceSequence := 12
    idempotencyKey := "effect-key-12"
    action := "execute"
    runtimeEpoch := 7
    activeFenceToken := 8
    successful := true
    resultDigest := "sha256:effect-result"
    providerAcknowledgementDigest := "sha256:provider-ack"
    provenanceDigest := "sha256:completion-provenance"
  }

theorem concreteCompletionValidationProjectionCloses :
    completionValidationErrors
      concreteCompletionValidationExpectation
      concreteCompletionValidationProjection = [] := by
  native_decide

def concreteCompletionValidationJson : Lean.Json :=
  Lean.toJson
    (completionValidationResult
      concreteCompletionValidationExpectation
      concreteCompletionValidationProjection)

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionPublicationClosure
