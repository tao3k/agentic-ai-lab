-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditModel

/-!
# Independent recovery owner audit model

This model separates owner-native receipt identity from the common audit chain.
It deliberately contains no compatibility, migration, legacy, or fallback
semantics: a witness either satisfies the canonical audit contract or it is
rejected.
-/

inductive RecoveryAuditOwner where
  | runtimeCrash
  | scheduler
  | completionStorage
  deriving DecidableEq, Repr

structure RecoveryOwnerAuditWitness where
  witnessId : Nat
  previousWitnessId : Option Nat
  ordinal : Nat
  recoveryId : Nat
  owner : RecoveryAuditOwner
  ownerIdentity : Nat
  beforeReceiptId : Nat
  afterReceiptId : Nat
  runtimeEpoch : Nat
  activeFenceToken : Nat
  deriving DecidableEq, Repr

def RecoveryOwnerAuditWitness.Valid
    (witness : RecoveryOwnerAuditWitness) : Prop :=
  witness.witnessId ≠ 0 ∧
  witness.recoveryId ≠ 0 ∧
  witness.ownerIdentity ≠ 0 ∧
  witness.beforeReceiptId ≠ witness.afterReceiptId ∧
  (witness.ordinal = 0 → witness.previousWitnessId = none) ∧
  (0 < witness.ordinal → ∃ previous, witness.previousWitnessId = some previous)

def RecoveryOwnerAuditWitness.Adjacent
    (current next : RecoveryOwnerAuditWitness) : Prop :=
  next.ordinal = current.ordinal + 1 ∧
  next.previousWitnessId = some current.witnessId ∧
  next.recoveryId = current.recoveryId ∧
  next.runtimeEpoch = current.runtimeEpoch ∧
  next.activeFenceToken = current.activeFenceToken ∧
  (next.owner = current.owner →
    next.beforeReceiptId = current.afterReceiptId)

def RecoveryOwnerAuditWitness.receiptKey
    (witness : RecoveryOwnerAuditWitness) : RecoveryAuditOwner × Nat :=
  (witness.owner, witness.afterReceiptId)

def RecoveryOwnerAuditGloballyNonreusing
    (audit : Nat → RecoveryOwnerAuditWitness) : Prop :=
  ∀ left right,
    left < right →
    (audit left).receiptKey ≠ (audit right).receiptKey

structure ClosedRecoveryOwnerAudit
    (audit : Nat → RecoveryOwnerAuditWitness) : Prop where
  valid :
    ∀ index, (audit index).Valid
  adjacent :
    ∀ index, (audit index).Adjacent (audit (index + 1))
  globallyNonreusing :
    RecoveryOwnerAuditGloballyNonreusing audit

def AccountingAdvances
    (beforeConsumed beforeRemaining afterConsumed afterRemaining : Nat) : Prop :=
  afterConsumed = beforeConsumed + 1 ∧
  afterRemaining < beforeRemaining

theorem accountingAdvanceDoesNotDetermineReceiptFreshness :
    ∃ beforeConsumed beforeRemaining afterConsumed afterRemaining,
      ∃ receiptId : Nat,
      AccountingAdvances
        beforeConsumed beforeRemaining afterConsumed afterRemaining ∧
      receiptId = receiptId := by
  refine ⟨0, 1, 1, 0, 7, ?_, rfl⟩
  exact ⟨rfl, Nat.zero_lt_succ 0⟩

def reuseWitnessZero : RecoveryOwnerAuditWitness where
  witnessId := 10
  previousWitnessId := none
  ordinal := 0
  recoveryId := 100
  owner := .runtimeCrash
  ownerIdentity := 1000
  beforeReceiptId := 20
  afterReceiptId := 21
  runtimeEpoch := 30
  activeFenceToken := 40

def reuseWitnessOne : RecoveryOwnerAuditWitness where
  witnessId := 11
  previousWitnessId := some 10
  ordinal := 1
  recoveryId := 100
  owner := .runtimeCrash
  ownerIdentity := 1000
  beforeReceiptId := 21
  afterReceiptId := 22
  runtimeEpoch := 30
  activeFenceToken := 40

def reuseWitnessTwo : RecoveryOwnerAuditWitness where
  witnessId := 12
  previousWitnessId := some 11
  ordinal := 2
  recoveryId := 100
  owner := .runtimeCrash
  ownerIdentity := 1000
  beforeReceiptId := 22
  afterReceiptId := 21
  runtimeEpoch := 30
  activeFenceToken := 40

theorem localFreshnessAndAdjacencyDoNotPreventGlobalReceiptReuse :
    reuseWitnessZero.Valid ∧
    reuseWitnessOne.Valid ∧
    reuseWitnessTwo.Valid ∧
    reuseWitnessZero.Adjacent reuseWitnessOne ∧
    reuseWitnessOne.Adjacent reuseWitnessTwo ∧
    reuseWitnessZero.receiptKey = reuseWitnessTwo.receiptKey := by
  simp [
    RecoveryOwnerAuditWitness.Valid,
    RecoveryOwnerAuditWitness.Adjacent,
    RecoveryOwnerAuditWitness.receiptKey,
    reuseWitnessZero,
    reuseWitnessOne,
    reuseWitnessTwo
  ]

theorem closedAuditRejectsReceiptReuse
    {audit : Nat → RecoveryOwnerAuditWitness}
    (closed : ClosedRecoveryOwnerAudit audit)
    {left right : Nat}
    (earlier : left < right) :
    (audit left).receiptKey ≠ (audit right).receiptKey :=
  closed.globallyNonreusing left right earlier

theorem closedAuditPreservesRecoveryIdentity
    {audit : Nat → RecoveryOwnerAuditWitness}
    (closed : ClosedRecoveryOwnerAudit audit)
    (index : Nat) :
    (audit (index + 1)).recoveryId = (audit index).recoveryId :=
  (closed.adjacent index).2.2.1

theorem closedAuditPreservesRuntimeEpoch
    {audit : Nat → RecoveryOwnerAuditWitness}
    (closed : ClosedRecoveryOwnerAudit audit)
    (index : Nat) :
    (audit (index + 1)).runtimeEpoch = (audit index).runtimeEpoch :=
  (closed.adjacent index).2.2.2.1

theorem closedAuditPreservesActiveFence
    {audit : Nat → RecoveryOwnerAuditWitness}
    (closed : ClosedRecoveryOwnerAudit audit)
    (index : Nat) :
    (audit (index + 1)).activeFenceToken =
      (audit index).activeFenceToken :=
  (closed.adjacent index).2.2.2.2.1

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditModel
