-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeModel

abbrev TransactionId := String
abbrev ReceiptId := String
abbrev WorkerId := String
abbrev Digest := String

structure AtomicCommitEvidence where
  transactionId : TransactionId
  receiptId : ReceiptId
  requestDigest : Digest
  materializationPlanDigest : Digest
  deriving DecidableEq, Repr

structure DurableIntent where
  transactionId : TransactionId
  requestDigest : Digest
  fenceToken : Nat
  deriving DecidableEq, Repr

structure RecoveryExpectation where
  recoveryId : String
  providerIdentity : String
  requestDigest : Digest
  runtimeEpoch : Nat
  activeFenceToken : Nat
  provenanceDigest : Digest
  deriving DecidableEq, Repr

structure RecoveryAuthorization where
  commitment : Digest
  authorityIdentity : String
  accountabilityIdentity : String
  responsibilityScopeDigest : Digest
  runtimeEpoch : Nat
  activeFenceToken : Nat
  admitted : Bool
  deriving DecidableEq, Repr

structure RecoveryClaim where
  transactionId : TransactionId
  workerId : WorkerId
  acquiredFenceToken : Nat
  deriving DecidableEq, Repr

structure RecoveryReceipt where
  recoveryId : String
  transactionId : TransactionId
  commitReceiptId : ReceiptId
  fenceToken : Nat
  terminal : Bool
  deriving DecidableEq, Repr

def AtomicCommitClosed (commit : AtomicCommitEvidence) : Prop :=
  commit.transactionId ≠ "" ∧
    commit.receiptId ≠ "" ∧
      commit.requestDigest ≠ "" ∧
        commit.materializationPlanDigest ≠ ""

def RecoveryClosed
    (claim : RecoveryClaim)
    (receipt : RecoveryReceipt) : Prop :=
  claim.transactionId = receipt.transactionId ∧
    claim.acquiredFenceToken = receipt.fenceToken ∧
      receipt.terminal = true

def RecoveryAuthorizationFresh
    (authorization : RecoveryAuthorization)
    (expectation : RecoveryExpectation) : Prop :=
  authorization.admitted = true ∧
    authorization.runtimeEpoch = expectation.runtimeEpoch ∧
      authorization.activeFenceToken = expectation.activeFenceToken

def AuthorizedRecoveryBound
    (commit : AtomicCommitEvidence)
    (expectation : RecoveryExpectation)
    (authorization : RecoveryAuthorization)
    (claim : RecoveryClaim)
    (receipt : RecoveryReceipt) : Prop :=
  AtomicCommitClosed commit ∧
    RecoveryClosed claim receipt ∧
      RecoveryAuthorizationFresh authorization expectation ∧
        claim.transactionId = commit.transactionId ∧
          receipt.commitReceiptId = commit.receiptId ∧
            receipt.recoveryId = expectation.recoveryId ∧
              claim.acquiredFenceToken = expectation.activeFenceToken

theorem atomicCommitDoesNotProvideDurableIntent :
    ∃ commit : AtomicCommitEvidence,
      AtomicCommitClosed commit ∧
        ¬ ∃ intent : DurableIntent, (fun _commit _intent => False) commit intent := by
  refine ⟨
    {
      transactionId := "transaction-a"
      receiptId := "commit-receipt-a"
      requestDigest := "request-a"
      materializationPlanDigest := "plan-a"
    },
    ?_,
    ?_
  ⟩
  · simp [AtomicCommitClosed]
  · simp

theorem recoveryClosureDoesNotIdentifyAtomicCommit :
    ∃ commit : AtomicCommitEvidence,
      ∃ claim : RecoveryClaim,
        ∃ receipt : RecoveryReceipt,
          AtomicCommitClosed commit ∧
            RecoveryClosed claim receipt ∧
              receipt.commitReceiptId ≠ commit.receiptId := by
  refine ⟨
    {
      transactionId := "transaction-a"
      receiptId := "commit-receipt-a"
      requestDigest := "request-a"
      materializationPlanDigest := "plan-a"
    },
    {
      transactionId := "transaction-a"
      workerId := "worker-a"
      acquiredFenceToken := 8
    },
    {
      recoveryId := "recovery-a"
      transactionId := "transaction-a"
      commitReceiptId := "commit-receipt-b"
      fenceToken := 8
      terminal := true
    },
    ?_
  ⟩
  simp [AtomicCommitClosed, RecoveryClosed]

theorem commitAuthorizationDoesNotAuthorizeRecoveryWorker :
    ∃ commitAuthorization recoveryAuthorization : RecoveryAuthorization,
      commitAuthorization.admitted = true ∧
        recoveryAuthorization.admitted = false := by
  refine ⟨
    {
      commitment := "commitment-a"
      authorityIdentity := "authority-a"
      accountabilityIdentity := "accountability-a"
      responsibilityScopeDigest := "scope-a"
      runtimeEpoch := 7
      activeFenceToken := 3
      admitted := true
    },
    {
      commitment := "commitment-a"
      authorityIdentity := "authority-a"
      accountabilityIdentity := "accountability-a"
      responsibilityScopeDigest := "scope-a"
      runtimeEpoch := 8
      activeFenceToken := 4
      admitted := false
    },
    rfl,
    rfl
  ⟩

theorem staleRecoveryEpochRejectsAuthorization
    {authorization : RecoveryAuthorization}
    {expectation : RecoveryExpectation}
    (stale : authorization.runtimeEpoch ≠ expectation.runtimeEpoch) :
    ¬ RecoveryAuthorizationFresh authorization expectation := by
  intro closed
  exact stale closed.2.1

theorem matchingFenceDoesNotBindProviderToWorker :
    ∃ expectation : RecoveryExpectation,
      ∃ claim : RecoveryClaim,
        expectation.activeFenceToken = claim.acquiredFenceToken ∧
          ¬ (fun _provider _worker => False)
            expectation.providerIdentity
            claim.workerId := by
  refine ⟨
    {
      recoveryId := "recovery-a"
      providerIdentity := "provider-a"
      requestDigest := "source-request-a"
      runtimeEpoch := 8
      activeFenceToken := 4
      provenanceDigest := "provenance-a"
    },
    {
      transactionId := "transaction-a"
      workerId := "worker-a"
      acquiredFenceToken := 4
    },
    rfl,
    ?_
  ⟩
  simp

theorem matchingTransactionIdentityDoesNotBindSourceRequest :
    ∃ commit : AtomicCommitEvidence,
      ∃ claim : RecoveryClaim,
        claim.transactionId = commit.transactionId ∧
          ¬ (fun _sourceRequest _promotionRequest => False)
            "source-request-a"
            commit.requestDigest := by
  refine ⟨
    {
      transactionId := "transaction-a"
      receiptId := "commit-receipt-a"
      requestDigest := "promotion-request-a"
      materializationPlanDigest := "plan-a"
    },
    {
      transactionId := "transaction-a"
      workerId := "worker-a"
      acquiredFenceToken := 4
    },
    rfl,
    ?_
  ⟩
  simp

theorem authorizedRecoveryBindsCanonicalCommit
    {commit : AtomicCommitEvidence}
    {expectation : RecoveryExpectation}
    {authorization : RecoveryAuthorization}
    {claim : RecoveryClaim}
    {receipt : RecoveryReceipt}
    (closed : AuthorizedRecoveryBound commit expectation authorization claim receipt) :
    receipt.commitReceiptId = commit.receiptId :=
  closed.2.2.2.2.1

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeModel
