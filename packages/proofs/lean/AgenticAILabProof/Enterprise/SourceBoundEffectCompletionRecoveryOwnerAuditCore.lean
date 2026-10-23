-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryProgressEvidenceClosure

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCore

open SourceBoundEffectCompletionRecoveryProgressEvidenceClosure

/-!
# Canonical recovery owner audit algebra

This lightweight module owns identity continuity and non-reuse.  Native crash,
scheduler, and storage bindings depend on it; the audit algebra does not depend
on those heavy transition families.
-/

structure SourceBoundEffectCompletionRecoveryOwnerAuditWitness where
  witnessId : String
  previousWitnessId : Option String
  ordinal : Nat
  recoveryId : String
  owner : SourceBoundEffectCompletionRecoveryProgressOwner
  ownerIdentity : String
  beforeReceiptId : String
  afterReceiptId : String
  runtimeEpoch : Nat
  activeFenceToken : Nat

def SourceBoundEffectCompletionRecoveryOwnerAuditWitness.Valid
    (witness : SourceBoundEffectCompletionRecoveryOwnerAuditWitness) : Prop :=
  witness.witnessId ≠ "" ∧
  witness.recoveryId ≠ "" ∧
  witness.ownerIdentity ≠ "" ∧
  witness.beforeReceiptId ≠ witness.afterReceiptId ∧
  (witness.ordinal = 0 → witness.previousWitnessId = none) ∧
  (0 < witness.ordinal →
    ∃ previous, witness.previousWitnessId = some previous)

def SourceBoundEffectCompletionRecoveryOwnerAuditWitness.Adjacent
    (current next :
      SourceBoundEffectCompletionRecoveryOwnerAuditWitness) : Prop :=
  next.ordinal = current.ordinal + 1 ∧
  next.previousWitnessId = some current.witnessId ∧
  next.recoveryId = current.recoveryId ∧
  next.runtimeEpoch = current.runtimeEpoch ∧
  next.activeFenceToken = current.activeFenceToken ∧
  (next.owner = current.owner →
    next.beforeReceiptId = current.afterReceiptId)

def SourceBoundEffectCompletionRecoveryOwnerAuditWitness.receiptKey
    (witness : SourceBoundEffectCompletionRecoveryOwnerAuditWitness) :
    SourceBoundEffectCompletionRecoveryProgressOwner × String :=
  (witness.owner, witness.afterReceiptId)

def SourceBoundEffectCompletionRecoveryOwnerAuditGloballyNonreusing
    (witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness) : Prop :=
  ∀ left right,
    left < right →
    (witnesses left).receiptKey ≠ (witnesses right).receiptKey

theorem globallyNonreusingRejectsOwnerReceiptReuse
    {witnesses :
      Nat → SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    (nonreusing :
      SourceBoundEffectCompletionRecoveryOwnerAuditGloballyNonreusing
        witnesses)
    {left right : Nat}
    (earlier : left < right) :
    (witnesses left).receiptKey ≠ (witnesses right).receiptKey :=
  nonreusing left right earlier

theorem adjacentPreservesPredecessorIdentity
    {current next :
      SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    (adjacent : current.Adjacent next) :
    next.previousWitnessId = some current.witnessId :=
  adjacent.2.1

theorem adjacentPreservesRecoveryIdentity
    {current next :
      SourceBoundEffectCompletionRecoveryOwnerAuditWitness}
    (adjacent : current.Adjacent next) :
    next.recoveryId = current.recoveryId :=
  adjacent.2.2.1

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerAuditCore
