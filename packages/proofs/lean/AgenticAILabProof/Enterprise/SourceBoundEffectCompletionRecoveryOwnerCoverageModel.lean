-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Init

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerCoverageModel

/-!
# Atomic recovery progress owner coverage

The earlier weak algebra allowed non-owner coordinates to decrease.  One
budget transition could therefore carry receipts for two different owners.
This independent model records that counterexample and the stronger atomic
algebra used by the owner-coverage closure.
-/

inductive ProgressOwnerModel where
  | runtimeCrashBudget
  | schedulerAdmission
  | completionStorageAdmission
deriving DecidableEq, Repr

structure ProgressBudgetModel where
  remainingCrashes : Nat
  remainingSchedulingDeferrals : Nat
  remainingStorageDeferrals : Nat
deriving DecidableEq, Repr

def ProgressBudgetModel.rank (budget : ProgressBudgetModel) : Nat :=
  budget.remainingCrashes
    + budget.remainingSchedulingDeferrals
    + budget.remainingStorageDeferrals

inductive WeakProgressReceiptModel
    (before after : ProgressBudgetModel) :
    ProgressOwnerModel → Prop where
  | crashBudgetDecreased
      (crashes :
        after.remainingCrashes < before.remainingCrashes)
      (scheduling :
        after.remainingSchedulingDeferrals ≤
          before.remainingSchedulingDeferrals)
      (storage :
        after.remainingStorageDeferrals ≤
          before.remainingStorageDeferrals) :
      WeakProgressReceiptModel before after .runtimeCrashBudget
  | schedulingDeferralDecreased
      (crashes :
        after.remainingCrashes ≤ before.remainingCrashes)
      (scheduling :
        after.remainingSchedulingDeferrals <
          before.remainingSchedulingDeferrals)
      (storage :
        after.remainingStorageDeferrals ≤
          before.remainingStorageDeferrals) :
      WeakProgressReceiptModel before after .schedulerAdmission
  | storageDeferralDecreased
      (crashes :
        after.remainingCrashes ≤ before.remainingCrashes)
      (scheduling :
        after.remainingSchedulingDeferrals ≤
          before.remainingSchedulingDeferrals)
      (storage :
        after.remainingStorageDeferrals <
          before.remainingStorageDeferrals) :
      WeakProgressReceiptModel before after .completionStorageAdmission

theorem weakProgressAlgebraAllowsMultipleOwners :
    ∃ before after,
      WeakProgressReceiptModel before after .runtimeCrashBudget ∧
      WeakProgressReceiptModel before after .schedulerAdmission := by
  let before : ProgressBudgetModel :=
    {
      remainingCrashes := 1
      remainingSchedulingDeferrals := 1
      remainingStorageDeferrals := 0
    }
  let after : ProgressBudgetModel :=
    {
      remainingCrashes := 0
      remainingSchedulingDeferrals := 0
      remainingStorageDeferrals := 0
    }
  refine ⟨before, after, ?_, ?_⟩
  · exact .crashBudgetDecreased (by decide) (by decide) (by decide)
  · exact .schedulingDeferralDecreased (by decide) (by decide) (by decide)

inductive AtomicProgressReceiptModel
    (before after : ProgressBudgetModel) :
    ProgressOwnerModel → Prop where
  | crashBudgetDecreased
      (crashes :
        after.remainingCrashes < before.remainingCrashes)
      (scheduling :
        after.remainingSchedulingDeferrals =
          before.remainingSchedulingDeferrals)
      (storage :
        after.remainingStorageDeferrals =
          before.remainingStorageDeferrals) :
      AtomicProgressReceiptModel before after .runtimeCrashBudget
  | schedulingDeferralDecreased
      (crashes :
        after.remainingCrashes = before.remainingCrashes)
      (scheduling :
        after.remainingSchedulingDeferrals <
          before.remainingSchedulingDeferrals)
      (storage :
        after.remainingStorageDeferrals =
          before.remainingStorageDeferrals) :
      AtomicProgressReceiptModel before after .schedulerAdmission
  | storageDeferralDecreased
      (crashes :
        after.remainingCrashes = before.remainingCrashes)
      (scheduling :
        after.remainingSchedulingDeferrals =
          before.remainingSchedulingDeferrals)
      (storage :
        after.remainingStorageDeferrals <
          before.remainingStorageDeferrals) :
      AtomicProgressReceiptModel before after .completionStorageAdmission

theorem atomicProgressReceiptStrictlyDecreasesRank
    {owner : ProgressOwnerModel}
    {before after : ProgressBudgetModel}
    (receipt : AtomicProgressReceiptModel before after owner) :
    after.rank < before.rank := by
  cases receipt with
  | crashBudgetDecreased crashes scheduling storage =>
      exact
        Nat.add_lt_add_of_lt_of_le
          (Nat.add_lt_add_of_lt_of_le crashes (Nat.le_of_eq scheduling))
          (Nat.le_of_eq storage)
  | schedulingDeferralDecreased crashes scheduling storage =>
      exact
        Nat.add_lt_add_of_lt_of_le
          (Nat.add_lt_add_of_le_of_lt (Nat.le_of_eq crashes) scheduling)
          (Nat.le_of_eq storage)
  | storageDeferralDecreased crashes scheduling storage =>
      exact
        Nat.add_lt_add_of_le_of_lt
          (Nat.add_le_add
            (Nat.le_of_eq crashes)
            (Nat.le_of_eq scheduling))
          storage

theorem atomicProgressReceiptOwnerUnique
    {before after : ProgressBudgetModel}
    {leftOwner rightOwner : ProgressOwnerModel}
    (left : AtomicProgressReceiptModel before after leftOwner)
    (right : AtomicProgressReceiptModel before after rightOwner) :
    leftOwner = rightOwner := by
  cases left <;> cases right <;> simp_all

structure OwnerEvidenceModel (owner : ProgressOwnerModel) where
  ownerIdentity : String
  ownerReceiptIdentity : String
  ownerIdentityPresent : ownerIdentity ≠ ""
  ownerReceiptIdentityPresent : ownerReceiptIdentity ≠ ""

structure AtomicOwnerCoverageModel
    (before after : ProgressBudgetModel)
    (owner : ProgressOwnerModel) where
  progress : AtomicProgressReceiptModel before after owner
  evidence : OwnerEvidenceModel owner

theorem atomicOwnerCoverageOwnerUnique
    {before after : ProgressBudgetModel}
    {leftOwner rightOwner : ProgressOwnerModel}
    (left : AtomicOwnerCoverageModel before after leftOwner)
    (right : AtomicOwnerCoverageModel before after rightOwner) :
    leftOwner = rightOwner :=
  atomicProgressReceiptOwnerUnique left.progress right.progress

theorem atomicProgressReceiptDoesNotDetermineOwnerEvidence :
    ∃ (before after : ProgressBudgetModel)
        (left right : OwnerEvidenceModel .runtimeCrashBudget),
      AtomicProgressReceiptModel
          before after .runtimeCrashBudget ∧
        left.ownerIdentity ≠ right.ownerIdentity := by
  let before : ProgressBudgetModel :=
    {
      remainingCrashes := 1
      remainingSchedulingDeferrals := 0
      remainingStorageDeferrals := 0
    }
  let after : ProgressBudgetModel :=
    {
      remainingCrashes := 0
      remainingSchedulingDeferrals := 0
      remainingStorageDeferrals := 0
    }
  let receipt :
      AtomicProgressReceiptModel
        before after .runtimeCrashBudget :=
    .crashBudgetDecreased (by decide) rfl rfl
  let left : OwnerEvidenceModel .runtimeCrashBudget :=
    {
      ownerIdentity := "runtime-owner-a"
      ownerReceiptIdentity := "runtime-receipt-a"
      ownerIdentityPresent := by decide
      ownerReceiptIdentityPresent := by decide
    }
  let right : OwnerEvidenceModel .runtimeCrashBudget :=
    {
      ownerIdentity := "runtime-owner-b"
      ownerReceiptIdentity := "runtime-receipt-b"
      ownerIdentityPresent := by decide
      ownerReceiptIdentityPresent := by decide
    }
  exact ⟨before, after, left, right, receipt, by decide⟩

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerCoverageModel
