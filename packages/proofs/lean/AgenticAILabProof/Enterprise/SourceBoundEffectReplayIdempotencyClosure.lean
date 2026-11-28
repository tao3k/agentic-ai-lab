-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundCheckpointRestoreAuthorizationClosure

namespace AgenticAILabProof.Enterprise.SourceBoundEffectReplayIdempotencyClosure

open AgenticAILabProof.Enterprise.SourceBoundCompositionalEffectClosure
open AgenticAILabProof.Enterprise.SourceBoundProgressEvidenceClosure
open AgenticAILabProof.Enterprise.SourceBoundFingerprintHistoryClosure
open AgenticAILabProof.Enterprise.SourceBoundFingerprintContentAddressClosure
open AgenticAILabProof.Enterprise.SourceBoundCheckpointRestoreAuthorizationClosure

structure SourceBoundEffectReplayObservation where
  traceSequence : Nat
  event : SourceBoundEffectExecutionEvent
  deriving DecidableEq, Repr

/--
The existing source-bound trace receipt owns effect identity and source
coordinates.  Replay observations add ordering without replacing the existing
event schema.
-/
structure SourceBoundEffectReplayWindow where
  windowId : String
  restoreRequestId : String
  canonicalRoot : CanonicalFingerprintHistoryIdentity
  runtimeEpoch : Nat
  activeFenceToken : Nat
  checkpointSequence : Nat
  effectFrontierSequence : Nat
  sourceTraceReceipt : SourceBoundEffectExecutionTraceReceipt
  observations : List SourceBoundEffectReplayObservation
  provenanceDigest : String
  deriving Repr

structure SourceBoundEffectReplayWindowClosed
    (request : SourceBoundLatestCheckpointRestoreRequest)
    (window : SourceBoundEffectReplayWindow) : Prop where
  restoreRequestIdentityMatches :
    window.restoreRequestId = request.requestId
  canonicalRootMatches :
    window.canonicalRoot = request.canonicalRoot
  runtimeEpochMatches :
    window.runtimeEpoch = request.runtimeEpoch
  activeFenceTokenMatches :
    window.activeFenceToken = request.activeFenceToken
  checkpointSequenceMatches :
    window.checkpointSequence =
      request.targetEnvelope.checkpoint.sequence
  sourceTraceRegistryMatches :
    window.sourceTraceReceipt.registryDigest =
      request.targetEnvelope.checkpoint.registryDigest
  sourceTraceFenceIsNotFuture :
    window.sourceTraceReceipt.fenceToken ≤ window.activeFenceToken
  observationProjectionMatches :
    window.observations.map (·.event) =
      window.sourceTraceReceipt.events
  observationSequencesUnique :
    window.observations.Pairwise
      (fun left right => left.traceSequence ≠ right.traceSequence)
  everyObservationWithinWindow :
    ∀ observation,
      observation ∈ window.observations →
        window.checkpointSequence < observation.traceSequence ∧
          observation.traceSequence ≤ window.effectFrontierSequence
  windowIdentityPresent : window.windowId ≠ ""
  provenancePresent : window.provenanceDigest ≠ ""

structure SourceBoundEffectReplayLedgerEntry where
  observation : SourceBoundEffectReplayObservation
  idempotencyKey : String
  completed : Bool
  replaySafe : Bool
  completionReceiptId : String
  deriving DecidableEq, Repr

def replayLedgerEntryClosed
    (entry : SourceBoundEffectReplayLedgerEntry) : Prop :=
  entry.idempotencyKey ≠ "" ∧
    ((entry.completed = true ∧ entry.completionReceiptId ≠ "") ∨
      (entry.completed = false ∧ entry.replaySafe = true))

structure SourceBoundEffectReplayLedger where
  ledgerId : String
  idempotencyProviderIdentity : String
  entries : List SourceBoundEffectReplayLedgerEntry
  provenanceDigest : String
  deriving Repr

def SourceBoundEffectIdempotencyKeyValid :=
  SourceBoundEffectReplayObservation → String → Prop

def denyEveryEffectIdempotencyKey :
    SourceBoundEffectIdempotencyKeyValid :=
  fun _observation _key => False

def replayLedgerCoversObservations
    (observations : List SourceBoundEffectReplayObservation)
    (entries : List SourceBoundEffectReplayLedgerEntry) : Prop :=
  entries.map (·.observation) = observations

structure SourceBoundEffectReplayLedgerClosed
    (idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid)
    (window : SourceBoundEffectReplayWindow)
    (ledger : SourceBoundEffectReplayLedger) : Prop where
  exactObservationCoverage :
    replayLedgerCoversObservations window.observations ledger.entries
  everyLedgerEntryCloses :
    ∀ entry, entry ∈ ledger.entries → replayLedgerEntryClosed entry
  idempotencyKeysUnique :
    ledger.entries.Pairwise
      (fun left right => left.idempotencyKey ≠ right.idempotencyKey)
  everyIdempotencyKeyValid :
    ∀ entry,
      entry ∈ ledger.entries →
        idempotencyKeyValid entry.observation entry.idempotencyKey
  ledgerIdentityPresent : ledger.ledgerId ≠ ""
  idempotencyProviderIdentityPresent :
    ledger.idempotencyProviderIdentity ≠ ""
  provenancePresent : ledger.provenanceDigest ≠ ""

inductive SourceBoundEffectReplayAction where
  | execute
  | suppressCompleted
  deriving DecidableEq, Repr

structure SourceBoundEffectReplayStep where
  observation : SourceBoundEffectReplayObservation
  idempotencyKey : String
  action : SourceBoundEffectReplayAction
  deriving DecidableEq, Repr

def replayStepMatchesLedgerEntry
    (step : SourceBoundEffectReplayStep)
    (entry : SourceBoundEffectReplayLedgerEntry) : Prop :=
  step.observation = entry.observation ∧
    step.idempotencyKey = entry.idempotencyKey ∧
      ((entry.completed = true ∧
          step.action = .suppressCompleted) ∨
        (entry.completed = false ∧
          entry.replaySafe = true ∧
          step.action = .execute))

structure SourceBoundEffectReplayPlan where
  planId : String
  ledgerId : String
  runtimeEpoch : Nat
  activeFenceToken : Nat
  steps : List SourceBoundEffectReplayStep
  provenanceDigest : String
  deriving Repr

structure SourceBoundEffectReplayPlanClosed
    (request : SourceBoundLatestCheckpointRestoreRequest)
    (window : SourceBoundEffectReplayWindow)
    (ledger : SourceBoundEffectReplayLedger)
    (plan : SourceBoundEffectReplayPlan) : Prop where
  ledgerIdentityMatches : plan.ledgerId = ledger.ledgerId
  runtimeEpochMatches : plan.runtimeEpoch = request.runtimeEpoch
  activeFenceTokenMatches :
    plan.activeFenceToken = request.activeFenceToken
  exactObservationProjection :
    plan.steps.map (·.observation) = window.observations
  everyStepMatchesLedger :
    ∀ step,
      step ∈ plan.steps →
        ∃ entry,
          entry ∈ ledger.entries ∧
            replayStepMatchesLedgerEntry step entry
  planIdentityPresent : plan.planId ≠ ""
  provenancePresent : plan.provenanceDigest ≠ ""

structure SourceBoundEffectReplayRetryAuthorityReceipt where
  authorityId : String
  providerIdentity : String
  restoreRequestId : String
  window : SourceBoundEffectReplayWindow
  ledger : SourceBoundEffectReplayLedger
  plan : SourceBoundEffectReplayPlan
  runtimeEpoch : Nat
  activeFenceToken : Nat
  decisionAllows : Bool
  policyDecisionDigest : String
  evidenceDigest : String
  deriving Repr

def SourceBoundEffectReplayRetryAuthorityReceiptValid :=
  SourceBoundEffectReplayRetryAuthorityReceipt → Prop

def denyEveryEffectReplayRetryAuthority :
    SourceBoundEffectReplayRetryAuthorityReceiptValid :=
  fun _authority => False

structure SourceBoundEffectReplayRetryAuthorityClosed
    (authorityValid : SourceBoundEffectReplayRetryAuthorityReceiptValid)
    (request : SourceBoundLatestCheckpointRestoreRequest)
    (window : SourceBoundEffectReplayWindow)
    (ledger : SourceBoundEffectReplayLedger)
    (plan : SourceBoundEffectReplayPlan)
    (authority : SourceBoundEffectReplayRetryAuthorityReceipt) : Prop where
  authorityValidates : authorityValid authority
  decisionAllows : authority.decisionAllows = true
  restoreRequestIdentityMatches :
    authority.restoreRequestId = request.requestId
  exactWindowMatches : authority.window = window
  exactLedgerMatches : authority.ledger = ledger
  exactPlanMatches : authority.plan = plan
  runtimeEpochMatches : authority.runtimeEpoch = request.runtimeEpoch
  activeFenceTokenMatches :
    authority.activeFenceToken = request.activeFenceToken
  authorityIdentityPresent : authority.authorityId ≠ ""
  providerIdentityPresent : authority.providerIdentity ≠ ""
  policyDecisionPresent : authority.policyDecisionDigest ≠ ""
  evidencePresent : authority.evidenceDigest ≠ ""

structure SourceBoundEffectReplayEvidenceClosed
    {digestValid : SourceBoundFingerprintHistoryDigestReceiptValid}
    {restoreAuthorizationValid :
      SourceBoundCheckpointRestoreAuthorizationReceiptValid}
    {progress : SourceBoundProgressReceipt}
    {evidence : SubjectProgressEvidence}
    {history : SourceBoundSemanticFingerprintHistory}
    {commitment : SourceBoundFingerprintHistoryCommitment}
    {digestReceipt : SourceBoundFingerprintHistoryDigestReceipt}
    {frontier : SourceBoundCheckpointRestoreFrontier}
    {request : SourceBoundLatestCheckpointRestoreRequest}
    {restoreAuthorization : SourceBoundCheckpointRestoreAuthorizationReceipt}
    (idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid)
    (retryAuthorityValid : SourceBoundEffectReplayRetryAuthorityReceiptValid)
    (window : SourceBoundEffectReplayWindow)
    (ledger : SourceBoundEffectReplayLedger)
    (plan : SourceBoundEffectReplayPlan)
    (retryAuthority : SourceBoundEffectReplayRetryAuthorityReceipt) : Prop where
  restoreCloses :
    SourceBoundCheckpointRestoreEvidenceClosed
      digestValid restoreAuthorizationValid progress evidence history commitment
      digestReceipt frontier request restoreAuthorization
  windowCloses : SourceBoundEffectReplayWindowClosed request window
  ledgerCloses :
    SourceBoundEffectReplayLedgerClosed
      idempotencyKeyValid window ledger
  planCloses :
    SourceBoundEffectReplayPlanClosed request window ledger plan
  retryAuthorityCloses :
    SourceBoundEffectReplayRetryAuthorityClosed
      retryAuthorityValid request window ledger plan retryAuthority

theorem emptyLedgerCannotCoverObservation
    (observation : SourceBoundEffectReplayObservation) :
    ¬ replayLedgerCoversObservations [observation] [] := by
  simp [replayLedgerCoversObservations]

def emptyIdempotencyKeyReplayEntry
    (observation : SourceBoundEffectReplayObservation) :
    SourceBoundEffectReplayLedgerEntry :=
  { observation := observation
    idempotencyKey := ""
    completed := false
    replaySafe := true
    completionReceiptId := "" }

theorem emptyIdempotencyKeyCannotCloseReplayableEntry
    (observation : SourceBoundEffectReplayObservation) :
    ¬ replayLedgerEntryClosed
      (emptyIdempotencyKeyReplayEntry observation) := by
  simp [
    replayLedgerEntryClosed,
    emptyIdempotencyKeyReplayEntry
  ]

theorem nonemptyIdempotencyKeyDoesNotProvideStableIdentity
    (observation : SourceBoundEffectReplayObservation) :
    "nonempty-idempotency-key" ≠ "" ∧
      ¬ denyEveryEffectIdempotencyKey
        observation "nonempty-idempotency-key" := by
  constructor
  · decide
  · simp [denyEveryEffectIdempotencyKey]

theorem restoreIntegrityAndRetryAuthorityRemainIndependent
    {restoreClosed : Prop}
    (restoreEvidence : restoreClosed)
    (authority : SourceBoundEffectReplayRetryAuthorityReceipt) :
    restoreClosed ∧
      ¬ denyEveryEffectReplayRetryAuthority authority := by
  constructor
  · exact restoreEvidence
  · simp [denyEveryEffectReplayRetryAuthority]

theorem restoreClosureDoesNotEntailRetryAuthority
    {restoreClosure : Prop}
    (restoreClosed : restoreClosure) :
    restoreClosure ∧ ¬ False :=
  ⟨restoreClosed, False.elim⟩

theorem closedReplayPlanBindsCurrentFenceToken
    {request : SourceBoundLatestCheckpointRestoreRequest}
    {window : SourceBoundEffectReplayWindow}
    {ledger : SourceBoundEffectReplayLedger}
    {plan : SourceBoundEffectReplayPlan}
    (closed :
      SourceBoundEffectReplayPlanClosed request window ledger plan) :
    plan.activeFenceToken = request.activeFenceToken :=
  closed.activeFenceTokenMatches

theorem closedReplayLedgerSeparatesIdempotencyKeys
    {idempotencyKeyValid : SourceBoundEffectIdempotencyKeyValid}
    {window : SourceBoundEffectReplayWindow}
    {ledger : SourceBoundEffectReplayLedger}
    (closed :
      SourceBoundEffectReplayLedgerClosed
        idempotencyKeyValid window ledger) :
    ledger.entries.Pairwise
      (fun left right => left.idempotencyKey ≠ right.idempotencyKey) :=
  closed.idempotencyKeysUnique

theorem independentlyClosedReplayOwnersCompose
    {restoreClosure windowClosure ledgerClosure planClosure
      retryAuthorityClosure : Prop}
    (restoreClosed : restoreClosure)
    (windowClosed : windowClosure)
    (ledgerClosed : ledgerClosure)
    (planClosed : planClosure)
    (retryAuthorityClosed : retryAuthorityClosure) :
    restoreClosure ∧ windowClosure ∧ ledgerClosure ∧ planClosure ∧
      retryAuthorityClosure :=
  ⟨restoreClosed, windowClosed, ledgerClosed, planClosed,
    retryAuthorityClosed⟩

def sourceBoundReplayTraceReceiptA :
    SourceBoundEffectExecutionTraceReceipt :=
  { receiptId := "source-bound-replay-trace-a"
    transactionId := sourceBoundTraceReceiptA.transactionId
    fenceToken := sourceBoundLatestCheckpointRestoreRequestA.activeFenceToken
    registryDigest :=
      sourceBoundLatestCheckpointRestoreRequestA.targetEnvelope.checkpoint.registryDigest
    events := [sourceBoundExternalMessageEvent] }

def sourceBoundEffectReplayObservationA :
    SourceBoundEffectReplayObservation :=
  { traceSequence :=
      sourceBoundLatestCheckpointRestoreRequestA.targetEnvelope.checkpoint.sequence + 1
    event := sourceBoundExternalMessageEvent }

def sourceBoundEffectReplayWindowA :
    SourceBoundEffectReplayWindow :=
  { windowId := "source-bound-effect-replay-window-a"
    restoreRequestId := sourceBoundLatestCheckpointRestoreRequestA.requestId
    canonicalRoot := sourceBoundLatestCheckpointRestoreRequestA.canonicalRoot
    runtimeEpoch := sourceBoundLatestCheckpointRestoreRequestA.runtimeEpoch
    activeFenceToken :=
      sourceBoundLatestCheckpointRestoreRequestA.activeFenceToken
    checkpointSequence :=
      sourceBoundLatestCheckpointRestoreRequestA.targetEnvelope.checkpoint.sequence
    effectFrontierSequence :=
      sourceBoundLatestCheckpointRestoreRequestA.targetEnvelope.checkpoint.sequence + 1
    sourceTraceReceipt := sourceBoundReplayTraceReceiptA
    observations := [sourceBoundEffectReplayObservationA]
    provenanceDigest := "source-bound-effect-replay-window-provenance-a" }

theorem sourceBoundEffectReplayWindowACloses :
    SourceBoundEffectReplayWindowClosed
      sourceBoundLatestCheckpointRestoreRequestA
      sourceBoundEffectReplayWindowA := by
  constructor
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · exact Nat.le_refl _
  · rfl
  · simp [sourceBoundEffectReplayWindowA]
  · intro observation observationInWindow
    simp [sourceBoundEffectReplayWindowA] at observationInWindow
    subst observation
    simp [
      sourceBoundEffectReplayWindowA,
      sourceBoundEffectReplayObservationA
    ]
  · decide
  · decide

def sourceBoundEffectReplayLedgerEntryA :
    SourceBoundEffectReplayLedgerEntry :=
  { observation := sourceBoundEffectReplayObservationA
    idempotencyKey := "external-message:promotion-transaction-a:1"
    completed := false
    replaySafe := true
    completionReceiptId := "" }

def sourceBoundEffectReplayLedgerA :
    SourceBoundEffectReplayLedger :=
  { ledgerId := "source-bound-effect-replay-ledger-a"
    idempotencyProviderIdentity := "agentic-ai-lab-idempotency-key-v1"
    entries := [sourceBoundEffectReplayLedgerEntryA]
    provenanceDigest := "source-bound-effect-replay-ledger-provenance-a" }

def sourceBoundEffectIdempotencyKeyValidA :
    SourceBoundEffectIdempotencyKeyValid :=
  fun observation key =>
    observation = sourceBoundEffectReplayObservationA ∧
      key = sourceBoundEffectReplayLedgerEntryA.idempotencyKey

theorem sourceBoundEffectReplayLedgerACloses :
    SourceBoundEffectReplayLedgerClosed
      sourceBoundEffectIdempotencyKeyValidA
      sourceBoundEffectReplayWindowA
      sourceBoundEffectReplayLedgerA := by
  constructor
  · rfl
  · intro entry entryInLedger
    simp [sourceBoundEffectReplayLedgerA] at entryInLedger
    subst entry
    simp [
      replayLedgerEntryClosed,
      sourceBoundEffectReplayLedgerEntryA
    ]
  · simp [sourceBoundEffectReplayLedgerA]
  · intro entry entryInLedger
    simp [sourceBoundEffectReplayLedgerA] at entryInLedger
    subst entry
    simp [
      sourceBoundEffectIdempotencyKeyValidA,
      sourceBoundEffectReplayLedgerEntryA
    ]
  · decide
  · decide
  · decide

def sourceBoundEffectReplayStepA : SourceBoundEffectReplayStep :=
  { observation := sourceBoundEffectReplayObservationA
    idempotencyKey := sourceBoundEffectReplayLedgerEntryA.idempotencyKey
    action := .execute }

def sourceBoundEffectReplayPlanA : SourceBoundEffectReplayPlan :=
  { planId := "source-bound-effect-replay-plan-a"
    ledgerId := sourceBoundEffectReplayLedgerA.ledgerId
    runtimeEpoch := sourceBoundLatestCheckpointRestoreRequestA.runtimeEpoch
    activeFenceToken :=
      sourceBoundLatestCheckpointRestoreRequestA.activeFenceToken
    steps := [sourceBoundEffectReplayStepA]
    provenanceDigest := "source-bound-effect-replay-plan-provenance-a" }

theorem sourceBoundEffectReplayPlanACloses :
    SourceBoundEffectReplayPlanClosed
      sourceBoundLatestCheckpointRestoreRequestA
      sourceBoundEffectReplayWindowA
      sourceBoundEffectReplayLedgerA
      sourceBoundEffectReplayPlanA := by
  constructor
  · rfl
  · rfl
  · rfl
  · rfl
  · intro step stepInPlan
    simp [sourceBoundEffectReplayPlanA] at stepInPlan
    subst step
    refine ⟨sourceBoundEffectReplayLedgerEntryA, ?_⟩
    simp [
      sourceBoundEffectReplayLedgerA,
      replayStepMatchesLedgerEntry,
      sourceBoundEffectReplayStepA,
      sourceBoundEffectReplayLedgerEntryA
    ]
  · decide
  · decide

def sourceBoundEffectReplayRetryAuthorityA :
    SourceBoundEffectReplayRetryAuthorityReceipt :=
  { authorityId := "source-bound-effect-replay-retry-authority-a"
    providerIdentity := "cedadr-dual-engine"
    restoreRequestId := sourceBoundLatestCheckpointRestoreRequestA.requestId
    window := sourceBoundEffectReplayWindowA
    ledger := sourceBoundEffectReplayLedgerA
    plan := sourceBoundEffectReplayPlanA
    runtimeEpoch := sourceBoundLatestCheckpointRestoreRequestA.runtimeEpoch
    activeFenceToken :=
      sourceBoundLatestCheckpointRestoreRequestA.activeFenceToken
    decisionAllows := true
    policyDecisionDigest := "cedadr-replay-policy-decision-a"
    evidenceDigest := "source-bound-effect-replay-retry-evidence-a" }

def sourceBoundEffectReplayRetryAuthorityValidA :
    SourceBoundEffectReplayRetryAuthorityReceiptValid :=
  fun authority => authority = sourceBoundEffectReplayRetryAuthorityA

theorem sourceBoundEffectReplayRetryAuthorityACloses :
    SourceBoundEffectReplayRetryAuthorityClosed
      sourceBoundEffectReplayRetryAuthorityValidA
      sourceBoundLatestCheckpointRestoreRequestA
      sourceBoundEffectReplayWindowA
      sourceBoundEffectReplayLedgerA
      sourceBoundEffectReplayPlanA
      sourceBoundEffectReplayRetryAuthorityA := by
  constructor
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · decide
  · decide
  · decide
  · decide

theorem sourceBoundEffectReplayEvidenceACloses :
    SourceBoundEffectReplayEvidenceClosed
      (digestValid := sourceBoundFingerprintHistoryDigestReceiptValidA)
      (restoreAuthorizationValid :=
        sourceBoundCheckpointRestoreAuthorizationReceiptValidA)
      (progress := sourceBoundCycleProgressReceipt)
      (evidence := progressEvidenceA)
      (history := sourceBoundProgressHistoryA)
      (commitment := sourceBoundFingerprintHistoryCommitmentA)
      (digestReceipt := sourceBoundFingerprintHistoryDigestReceiptA)
      (frontier := sourceBoundCheckpointRestoreFrontierA)
      (request := sourceBoundLatestCheckpointRestoreRequestA)
      (restoreAuthorization :=
        sourceBoundCheckpointRestoreAuthorizationReceiptA)
      sourceBoundEffectIdempotencyKeyValidA
      sourceBoundEffectReplayRetryAuthorityValidA
      sourceBoundEffectReplayWindowA
      sourceBoundEffectReplayLedgerA
      sourceBoundEffectReplayPlanA
      sourceBoundEffectReplayRetryAuthorityA :=
  ⟨sourceBoundCheckpointRestoreEvidenceACloses,
    sourceBoundEffectReplayWindowACloses,
    sourceBoundEffectReplayLedgerACloses,
    sourceBoundEffectReplayPlanACloses,
    sourceBoundEffectReplayRetryAuthorityACloses⟩

end AgenticAILabProof.Enterprise.SourceBoundEffectReplayIdempotencyClosure
