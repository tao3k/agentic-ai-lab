-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.PromotionTransactionAtomicity

namespace AgenticAILabProof.Enterprise.PromotionTransactionRecovery

open PromotionTransactionAtomicity

abbrev ExternalEffectDigest := String
abbrev WorkerId := String
abbrev RecoveryReceiptId := String

structure TransactionRegistryEntry where
  request : PromotionCommitRequest
  deriving DecidableEq, Repr

def registryEntriesCompatible
    (left right : TransactionRegistryEntry) : Prop :=
  left.request.transactionId ≠ right.request.transactionId ∨
    left.request = right.request

def transactionRegistryUnique
    (entries : List TransactionRegistryEntry) : Prop :=
  entries.Pairwise registryEntriesCompatible

def TransactionRegistryValid :=
  List TransactionRegistryEntry → Prop

def conflictingCommitRequest : PromotionCommitRequest :=
  { commitRequestA with
    targetPostStateDigest := "sha256:runtime-conflicting-target" }

def conflictingCommittedReceipt : PromotionCommitReceipt :=
  { committedReceiptA with
    receiptId := "commit-conflicting"
    postStateDigest := "sha256:runtime-conflicting-target" }

theorem conflictingCommitAlsoClosesIndividually :
    promotionCommitEvidenceClosed
      (fun _receipt => True)
      (fun _receipt => True)
      governanceAtAdmission
      acceptedAdmissionA
      conflictingCommitRequest
      conflictingCommittedReceipt := by
  simp [
    promotionCommitEvidenceClosed,
    commitSubjectMatchesSnapshot,
    outcomePreservesAtomicState,
    governanceAtAdmission,
    acceptedAdmissionA,
    admissionSubjectA,
    CedarDualEngineAuthorization.subjectA,
    conflictingCommitRequest,
    conflictingCommittedReceipt,
    commitRequestA,
    committedReceiptA
  ]

def registryEntryA : TransactionRegistryEntry where
  request := commitRequestA

def conflictingRegistryEntry : TransactionRegistryEntry where
  request := conflictingCommitRequest

theorem individualCommitClosureDoesNotEnforceTransactionIdUniqueness :
    promotionCommitEvidenceClosed
        (fun _receipt => True)
        (fun _receipt => True)
        governanceAtAdmission
        acceptedAdmissionA
        commitRequestA
        committedReceiptA ∧
      promotionCommitEvidenceClosed
        (fun _receipt => True)
        (fun _receipt => True)
        governanceAtAdmission
        acceptedAdmissionA
        conflictingCommitRequest
        conflictingCommittedReceipt ∧
      commitRequestA.transactionId =
        conflictingCommitRequest.transactionId ∧
      commitRequestA ≠ conflictingCommitRequest ∧
      ¬ transactionRegistryUnique
        [registryEntryA, conflictingRegistryEntry] := by
  refine ⟨commitEvidenceClosedAtAdmissionSnapshot,
    conflictingCommitAlsoClosesIndividually, ?_⟩
  simp [
    transactionRegistryUnique,
    registryEntriesCompatible,
    registryEntryA,
    conflictingRegistryEntry,
    conflictingCommitRequest,
    commitRequestA
  ]

def receiptBindsCanonicalRequest
    (request : PromotionCommitRequest)
    (receipt : PromotionCommitReceipt) : Prop :=
  receipt.transactionId = request.transactionId ∧
    receipt.admissionReceiptId = request.admissionReceiptId ∧
    receipt.subject = request.subject ∧
    receipt.preStateDigest = request.expectedPreStateDigest ∧
    receipt.postStateDigest = request.targetPostStateDigest

def priorCommitExists
    (commitValid : CommitReceiptValid)
    (ledger : List PromotionCommitReceipt)
    (request : PromotionCommitRequest) : Prop :=
  ∃ prior ∈ ledger,
    commitValid prior ∧
      prior.outcome = .committed ∧
      receiptBindsCanonicalRequest request prior

def orphanDuplicateReceipt : PromotionCommitReceipt :=
  { committedReceiptA with
    receiptId := "duplicate-without-prior-commit"
    outcome := .duplicate }

theorem duplicateOutcomeDoesNotProvePriorCommit :
    outcomePreservesAtomicState commitRequestA orphanDuplicateReceipt ∧
      ¬ priorCommitExists
        (fun _receipt => True)
        []
        commitRequestA := by
  constructor
  · simp [
      outcomePreservesAtomicState,
      orphanDuplicateReceipt,
      committedReceiptA,
      commitRequestA
    ]
  · simp [priorCommitExists]

theorem matchingPriorCommitFieldsDoNotProveCommitValidity :
    receiptBindsCanonicalRequest commitRequestA committedReceiptA ∧
      ¬ priorCommitExists
        (fun _receipt => False)
        [committedReceiptA]
        commitRequestA := by
  constructor
  · simp [
      receiptBindsCanonicalRequest,
      committedReceiptA,
      commitRequestA
    ]
  · simp [priorCommitExists]

structure EffectObservation where
  runtimeStateDigest : RuntimeStateDigest
  externalEffectDigest : ExternalEffectDigest
  uncompensatedApplicationCount : Nat
  deriving DecidableEq, Repr

def preEffectObservation : EffectObservation where
  runtimeStateDigest := "sha256:runtime-before"
  externalEffectDigest := "sha256:external-before"
  uncompensatedApplicationCount := 0

def leakedRollbackObservation : EffectObservation where
  runtimeStateDigest := "sha256:runtime-before"
  externalEffectDigest := "sha256:external-leaked-effect"
  uncompensatedApplicationCount := 1

def rolledBackReceiptWithLeakedEffect : PromotionCommitReceipt :=
  { committedReceiptA with
    receiptId := "rollback-with-leaked-effect"
    postStateDigest := "sha256:runtime-before"
    outcome := .rolledBack }

theorem runtimeDigestRollbackCanHideExternalEffect :
    promotionCommitEvidenceClosed
        (fun _receipt => True)
        (fun _receipt => True)
        governanceAtAdmission
        acceptedAdmissionA
        commitRequestA
        rolledBackReceiptWithLeakedEffect ∧
      preEffectObservation.runtimeStateDigest =
        leakedRollbackObservation.runtimeStateDigest ∧
      preEffectObservation ≠ leakedRollbackObservation := by
  constructor
  · simp [
      promotionCommitEvidenceClosed,
      commitSubjectMatchesSnapshot,
      outcomePreservesAtomicState,
      governanceAtAdmission,
      acceptedAdmissionA,
      admissionSubjectA,
      CedarDualEngineAuthorization.subjectA,
      commitRequestA,
      rolledBackReceiptWithLeakedEffect,
      committedReceiptA
    ]
  · decide

structure AtomicEffectReceipt where
  base : PromotionCommitReceipt
  preEffect : EffectObservation
  postEffect : EffectObservation
  deriving DecidableEq, Repr

def receiptIdentityMatchesRequest
    (request : PromotionCommitRequest)
    (receipt : PromotionCommitReceipt) : Prop :=
  receipt.transactionId = request.transactionId ∧
    receipt.admissionReceiptId = request.admissionReceiptId ∧
    receipt.subject = request.subject ∧
    receipt.preStateDigest = request.expectedPreStateDigest

def effectOutcomeClosed
    (commitValid : CommitReceiptValid)
    (ledger : List PromotionCommitReceipt)
    (request : PromotionCommitRequest)
    (receipt : AtomicEffectReceipt) : Prop :=
  receiptIdentityMatchesRequest request receipt.base ∧
    receipt.preEffect.runtimeStateDigest = receipt.base.preStateDigest ∧
    receipt.postEffect.runtimeStateDigest = receipt.base.postStateDigest ∧
    match receipt.base.outcome with
    | .committed =>
        receipt.base.postStateDigest = request.targetPostStateDigest ∧
          receipt.preEffect.uncompensatedApplicationCount = 0 ∧
          receipt.postEffect.uncompensatedApplicationCount = 1
    | .duplicate =>
        receipt.base.postStateDigest = request.targetPostStateDigest ∧
          priorCommitExists commitValid ledger request ∧
          receipt.postEffect = receipt.preEffect ∧
          receipt.postEffect.uncompensatedApplicationCount = 1
    | .rejected =>
        receipt.postEffect = receipt.preEffect
    | .rolledBack =>
        receipt.postEffect = receipt.preEffect

def committedEffectObservation : EffectObservation where
  runtimeStateDigest := "sha256:runtime-after"
  externalEffectDigest := "sha256:external-after"
  uncompensatedApplicationCount := 1

def committedAtomicEffectReceipt : AtomicEffectReceipt where
  base := committedReceiptA
  preEffect := preEffectObservation
  postEffect := committedEffectObservation

theorem committedAtomicEffectCloses :
    effectOutcomeClosed
      (fun _receipt => True)
      []
      commitRequestA
      committedAtomicEffectReceipt := by
  simp [
    effectOutcomeClosed,
    receiptIdentityMatchesRequest,
    committedAtomicEffectReceipt,
    committedEffectObservation,
    preEffectObservation,
    committedReceiptA,
    commitRequestA
  ]

theorem closedDuplicateRequiresPriorCommit
    (ledger : List PromotionCommitReceipt)
    (commitValid : CommitReceiptValid)
    (request : PromotionCommitRequest)
    (receipt : AtomicEffectReceipt)
    (closed : effectOutcomeClosed commitValid ledger request receipt)
    (duplicate : receipt.base.outcome = .duplicate) :
    priorCommitExists commitValid ledger request := by
  have outcomeClosed := closed.2.2.2
  simp [duplicate] at outcomeClosed
  exact outcomeClosed.2.1

theorem closedRollbackRestoresCompleteEffectObservation
    (ledger : List PromotionCommitReceipt)
    (commitValid : CommitReceiptValid)
    (request : PromotionCommitRequest)
    (receipt : AtomicEffectReceipt)
    (closed : effectOutcomeClosed commitValid ledger request receipt)
    (rolledBack : receipt.base.outcome = .rolledBack) :
    receipt.postEffect = receipt.preEffect := by
  have outcomeClosed := closed.2.2.2
  simp [rolledBack] at outcomeClosed
  exact outcomeClosed

inductive DurablePhase
  | prepared
  | applying
  | committed
  | rolledBack
  | rejected
  deriving DecidableEq, Repr

def isTerminalPhase : DurablePhase → Prop
  | .prepared => False
  | .applying => False
  | .committed => True
  | .rolledBack => True
  | .rejected => True

structure DurableTransactionRecord where
  request : PromotionCommitRequest
  phase : DurablePhase
  fenceToken : Nat
  preEffect : EffectObservation
  deriving DecidableEq, Repr

def DurableRecordValid :=
  DurableTransactionRecord → Prop

structure LegacyCrashObservation where
  durableRecord : Option DurableTransactionRecord
  runtimeStateDigest : RuntimeStateDigest
  deriving DecidableEq, Repr

structure CrashWorld where
  durableRecord : Option DurableTransactionRecord
  runtimeStateDigest : RuntimeStateDigest
  externalEffectDigest : ExternalEffectDigest
  deriving DecidableEq, Repr

def legacyCrashProjection
    (world : CrashWorld) : LegacyCrashObservation where
  durableRecord := world.durableRecord
  runtimeStateDigest := world.runtimeStateDigest

def crashBeforeEffect : CrashWorld where
  durableRecord := none
  runtimeStateDigest := "sha256:runtime-before"
  externalEffectDigest := "sha256:external-before"

def crashAfterUnrecordedEffect : CrashWorld where
  durableRecord := none
  runtimeStateDigest := "sha256:runtime-before"
  externalEffectDigest := "sha256:external-leaked-effect"

theorem missingDurableIntentAndEffectObservationAreAmbiguous :
    legacyCrashProjection crashBeforeEffect =
        legacyCrashProjection crashAfterUnrecordedEffect ∧
      crashBeforeEffect ≠ crashAfterUnrecordedEffect := by
  constructor
  · rfl
  · decide

def applyingRecordA : DurableTransactionRecord where
  request := commitRequestA
  phase := .applying
  fenceToken := 7
  preEffect := preEffectObservation

def unfencedRecoveryEligible
    (record : DurableTransactionRecord)
    (_worker : WorkerId) : Prop :=
  record.phase = .applying

theorem unfencedApplyingRecordAllowsConcurrentWorkers :
    unfencedRecoveryEligible applyingRecordA "worker-a" ∧
      unfencedRecoveryEligible applyingRecordA "worker-b" ∧
      ("worker-a" : WorkerId) ≠ "worker-b" := by
  simp [unfencedRecoveryEligible, applyingRecordA]

structure RecoveryClaim where
  transactionId : TransactionId
  workerId : WorkerId
  observedFenceToken : Nat
  acquiredFenceToken : Nat
  deriving DecidableEq, Repr

def recoveryClaimFieldsMatch
    (record : DurableTransactionRecord)
    (claim : RecoveryClaim) : Prop :=
  claim.transactionId = record.request.transactionId ∧
    claim.observedFenceToken = record.fenceToken ∧
    record.fenceToken < claim.acquiredFenceToken

def claimA : RecoveryClaim where
  transactionId := "promotion-transaction-a"
  workerId := "worker-a"
  observedFenceToken := 7
  acquiredFenceToken := 8

def claimB : RecoveryClaim where
  transactionId := "promotion-transaction-a"
  workerId := "worker-b"
  observedFenceToken := 7
  acquiredFenceToken := 8

theorem matchingFenceFieldsDoNotProvideExclusiveOwnership :
    recoveryClaimFieldsMatch applyingRecordA claimA ∧
      recoveryClaimFieldsMatch applyingRecordA claimB ∧
      claimA ≠ claimB := by
  simp [
    recoveryClaimFieldsMatch,
    applyingRecordA,
    commitRequestA,
    claimA,
    claimB
  ]

def RecoveryClaimValid :=
  DurableTransactionRecord → RecoveryClaim → Prop

def recoveryClaimAuthorityExclusive
    (valid : RecoveryClaimValid) : Prop :=
  ∀ record left right,
    valid record left →
      valid record right →
      left = right

def claimAValid
    (_record : DurableTransactionRecord)
    (claim : RecoveryClaim) : Prop :=
  claim = claimA

theorem claimAValidityIsExclusive :
    recoveryClaimAuthorityExclusive claimAValid := by
  intro record left right leftValid rightValid
  exact leftValid.trans rightValid.symm

def terminalPhaseMatchesOutcome
    (phase : DurablePhase)
    (outcome : CommitOutcome) : Prop :=
  match outcome with
  | .committed => phase = .committed
  | .duplicate => phase = .committed
  | .rejected => phase = .rejected
  | .rolledBack => phase = .rolledBack

structure RecoveryReceipt where
  receiptId : RecoveryReceiptId
  transactionId : TransactionId
  fenceToken : Nat
  recoveredFromPhase : DurablePhase
  terminalPhase : DurablePhase
  effectReceipt : AtomicEffectReceipt
  deriving DecidableEq, Repr

def RecoveryReceiptValid :=
  RecoveryReceipt → Prop

def registryContainsRequest
    (registry : List TransactionRegistryEntry)
    (request : PromotionCommitRequest) : Prop :=
  ∃ entry ∈ registry, entry.request = request

structure RecoveryEvidenceClosed
    (registry : List TransactionRegistryEntry)
    (registryValid : TransactionRegistryValid)
    (recordValid : DurableRecordValid)
    (commitValid : CommitReceiptValid)
    (claimValid : RecoveryClaimValid)
    (receiptValid : RecoveryReceiptValid)
    (ledger : List PromotionCommitReceipt)
    (record : DurableTransactionRecord)
    (claim : RecoveryClaim)
    (receipt : RecoveryReceipt) : Prop where
  registryUnique : transactionRegistryUnique registry
  registryValidates : registryValid registry
  requestRegistered : registryContainsRequest registry record.request
  recordValidates : recordValid record
  recordApplying : record.phase = .applying
  claimAuthorityExclusive : recoveryClaimAuthorityExclusive claimValid
  claimMatches : recoveryClaimFieldsMatch record claim
  claimValidates : claimValid record claim
  receiptTransactionMatches :
    receipt.transactionId = record.request.transactionId
  receiptFenceMatches :
    receipt.fenceToken = claim.acquiredFenceToken
  receiptRecoversApplying :
    receipt.recoveredFromPhase = record.phase
  receiptIsTerminal :
    isTerminalPhase receipt.terminalPhase
  receiptPhaseMatchesOutcome :
    terminalPhaseMatchesOutcome
      receipt.terminalPhase
      receipt.effectReceipt.base.outcome
  effectCloses :
    effectOutcomeClosed
      commitValid
      ledger
      record.request
      receipt.effectReceipt
  receiptValidates : receiptValid receipt

def recoveryReceiptA : RecoveryReceipt where
  receiptId := "recovery-a"
  transactionId := "promotion-transaction-a"
  fenceToken := 8
  recoveredFromPhase := .applying
  terminalPhase := .committed
  effectReceipt := committedAtomicEffectReceipt

theorem recoveryEvidenceClosesForExclusiveClaim :
    RecoveryEvidenceClosed
      [registryEntryA]
      (fun _registry => True)
      (fun _record => True)
      (fun _receipt => True)
      claimAValid
      (fun _receipt => True)
      []
      applyingRecordA
      claimA
      recoveryReceiptA := by
  constructor
  · simp [
      transactionRegistryUnique,
      registryEntriesCompatible
    ]
  · trivial
  · simp [
      registryContainsRequest,
      registryEntryA,
      applyingRecordA
    ]
  · trivial
  · rfl
  · exact claimAValidityIsExclusive
  · simp [
      recoveryClaimFieldsMatch,
      applyingRecordA,
      commitRequestA,
      claimA
    ]
  · rfl
  · rfl
  · rfl
  · rfl
  · simp [isTerminalPhase, recoveryReceiptA]
  · simp [
      terminalPhaseMatchesOutcome,
      recoveryReceiptA,
      committedAtomicEffectReceipt,
      committedReceiptA
    ]
  · exact committedAtomicEffectCloses
  · trivial

theorem uniqueRegistryFieldsDoNotProveRegistryAuthority :
    transactionRegistryUnique [registryEntryA] ∧
      ¬ (fun _registry : List TransactionRegistryEntry => False)
        [registryEntryA] := by
  constructor
  · simp [
      transactionRegistryUnique,
      registryEntriesCompatible
    ]
  · simp

theorem matchingDurableRecordFieldsDoNotProveRecordAuthority :
    applyingRecordA.phase = .applying ∧
      ¬ (fun _record : DurableTransactionRecord => False)
        applyingRecordA := by
  simp [applyingRecordA]

theorem closedRecoveryProvidesExclusiveFence
    (registry : List TransactionRegistryEntry)
    (registryValid : TransactionRegistryValid)
    (recordValid : DurableRecordValid)
    (commitValid : CommitReceiptValid)
    (claimValid : RecoveryClaimValid)
    (receiptValid : RecoveryReceiptValid)
    (ledger : List PromotionCommitReceipt)
    (record : DurableTransactionRecord)
    (claim other : RecoveryClaim)
    (receipt : RecoveryReceipt)
    (closed :
      RecoveryEvidenceClosed
        registry
        registryValid
        recordValid
        commitValid
        claimValid
        receiptValid
        ledger
        record
        claim
        receipt)
    (otherValid : claimValid record other) :
    claim = other :=
  closed.claimAuthorityExclusive
    record
    claim
    other
    closed.claimValidates
    otherValid

theorem closedRecoveryEndsInTerminalPhase
    (registry : List TransactionRegistryEntry)
    (registryValid : TransactionRegistryValid)
    (recordValid : DurableRecordValid)
    (commitValid : CommitReceiptValid)
    (claimValid : RecoveryClaimValid)
    (receiptValid : RecoveryReceiptValid)
    (ledger : List PromotionCommitReceipt)
    (record : DurableTransactionRecord)
    (claim : RecoveryClaim)
    (receipt : RecoveryReceipt)
    (closed :
      RecoveryEvidenceClosed
        registry
        registryValid
        recordValid
        commitValid
        claimValid
        receiptValid
        ledger
        record
        claim
        receipt) :
    isTerminalPhase receipt.terminalPhase :=
  closed.receiptIsTerminal

theorem matchingRecoveryFieldsDoNotProveRecoveryAuthority :
    recoveryClaimFieldsMatch applyingRecordA claimA ∧
      ¬ RecoveryEvidenceClosed
        [registryEntryA]
        (fun _registry => True)
        (fun _record => True)
        (fun _receipt => True)
        (fun _record _claim => False)
        (fun _receipt => True)
        []
        applyingRecordA
        claimA
        recoveryReceiptA := by
  constructor
  · simp [
      recoveryClaimFieldsMatch,
      applyingRecordA,
      commitRequestA,
      claimA
    ]
  · intro closed
    exact closed.claimValidates

end AgenticAILabProof.Enterprise.PromotionTransactionRecovery
