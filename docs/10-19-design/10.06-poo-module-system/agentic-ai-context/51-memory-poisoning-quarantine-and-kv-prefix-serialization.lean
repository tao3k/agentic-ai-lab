-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
Slice 51 — Lean Unbounded Algebraic & Prefix-Preservation Laws ONLY:
Per `FormalVerificationTaxonomy` in
`51-memory-poisoning-quarantine-and-kv-prefix-serialization.sysml`, this module
proves:
1. Quarantine-Before-Recall & Typed Memory Contracts defending against
   AgentPoison, MINJA, and MemoryGraft experience-imitation hijacking.
2. Two-Zone KV-Prefix-Stable Serialization (`Frozen Canonical Prefix` ++
   `Dynamic Suffix`) guaranteeing zero radix-tree fracturing across detour
   opens/folds and canonical arrival-order invariance for distinct node keys.
Concurrent interleavings belong exclusively to `51-*.qnt`.
-/

namespace MemoryQuarantineAndKvPrefixSerialization

/-! ## 1. Quarantine-Before-Recall & Typed Memory Contracts -/

inductive OriginTrust where
  | trustedInternal
  | untrustedIngest
  deriving DecidableEq, Repr

inductive MemoryTier where
  | quarantined
  | recallable
  | rejected
  deriving DecidableEq, Repr

structure MemoryEntry (EntryId : Type) where
  id : EntryId
  origin : OriginTrust
  selfClaimedSuccess : Bool
  independentEndorsement : Bool
  openDefeaters : Nat
  tier : MemoryTier
  deriving DecidableEq, Repr

def productionRecall {EntryId : Type} (store : List (MemoryEntry EntryId)) :
    List (MemoryEntry EntryId) :=
  store.filter (fun e => e.tier == .recallable)

theorem quarantinedCandidate_never_recalled {EntryId : Type}
    (store : List (MemoryEntry EntryId))
    (e : MemoryEntry EntryId)
    (hQuar : e.tier = .quarantined) :
    e ∉ productionRecall store := by
  unfold productionRecall
  intro hMem
  rw [List.mem_filter] at hMem
  have hEq := hMem.2
  rw [hQuar] at hEq
  cases hEq

def evaluatePromotion {EntryId : Type} (e : MemoryEntry EntryId) : MemoryTier :=
  if e.tier == .rejected then
    .rejected
  else if e.openDefeaters > 0 then
    .quarantined
  else match e.origin with
    | .trustedInternal => .recallable
    | .untrustedIngest =>
        if e.independentEndorsement then .recallable else .quarantined

theorem untrustedOrigin_selfClaimedSuccess_cannot_promote {EntryId : Type}
    (e : MemoryEntry EntryId)
    (hNotRej : e.tier ≠ .rejected)
    (hUntrusted : e.origin = .untrustedIngest)
    (_hSelf : e.selfClaimedSuccess = true)
    (hNoEndor : e.independentEndorsement = false) :
    evaluatePromotion e = .quarantined := by
  unfold evaluatePromotion
  have hRejFalse : (e.tier == .rejected) = false := beq_false_of_ne hNotRej
  simp [hRejFalse, hUntrusted, hNoEndor]

theorem endorsedAndDefeaterFree_promotes_to_recallable {EntryId : Type}
    (e : MemoryEntry EntryId)
    (hNotRej : e.tier ≠ .rejected)
    (hNoDef : e.openDefeaters = 0)
    (hEndor : e.independentEndorsement = true) :
    evaluatePromotion e = .recallable := by
  unfold evaluatePromotion
  have hRejFalse : (e.tier == .rejected) = false := beq_false_of_ne hNotRej
  cases hOrig : e.origin <;> simp [hRejFalse, hNoDef, hEndor]

/-! ## 2. Two-Zone KV-Prefix-Stable Serialization & Order Invariance -/

def serializeTwoZone {Token : Type} (frozenPrefix dynamicSuffix : List Token) : List Token :=
  frozenPrefix ++ dynamicSuffix

theorem appendDynamicSuffix_preserves_frozen_kv_prefix {Token : Type}
    (frozenPrefix dynamicSuffix : List Token) :
    (serializeTwoZone frozenPrefix dynamicSuffix).take frozenPrefix.length = frozenPrefix := by
  unfold serializeTwoZone
  induction frozenPrefix with
  | nil => rfl
  | cons head tail ih =>
      simp [ih]

theorem detourSuffixSwap_preserves_prefix_commitment {Token Digest : Type}
    (commit : List Token → Digest)
    (frozenPrefix suffixA suffixB : List Token) :
    commit ((serializeTwoZone frozenPrefix suffixA).take frozenPrefix.length) =
      commit ((serializeTwoZone frozenPrefix suffixB).take frozenPrefix.length) := by
  rw [appendDynamicSuffix_preserves_frozen_kv_prefix,
      appendDynamicSuffix_preserves_frozen_kv_prefix]

def insertCanonical (x : Nat) : List Nat → List Nat
  | [] => [x]
  | y :: ys =>
      if x ≤ y then x :: y :: ys
      else y :: insertCanonical x ys

def canonicalPrefixSort : List Nat → List Nat
  | [] => []
  | x :: xs => insertCanonical x (canonicalPrefixSort xs)

theorem insertCanonical_comm (a b : Nat) (xs : List Nat) :
    insertCanonical a (insertCanonical b xs) = insertCanonical b (insertCanonical a xs) := by
  induction xs with
  | nil =>
      by_cases h1 : a ≤ b
      · by_cases h2 : b ≤ a
        · have hEq : a = b := Nat.le_antisymm h1 h2
          subst hEq
          rfl
        · simp [insertCanonical, h1, h2]
      · have h2 : b ≤ a := Nat.le_of_lt (Nat.lt_of_not_ge h1)
        simp [insertCanonical, h1, h2]
  | cons y ys ih =>
      by_cases hab : a ≤ b
      · by_cases hba : b ≤ a
        · have hEq : a = b := Nat.le_antisymm hab hba
          subst hEq
          rfl
        · by_cases hay : a ≤ y
          · by_cases hby : b ≤ y
            · simp [insertCanonical, hab, hba, hay, hby]
            · simp [insertCanonical, hba, hay, hby]
          · have hby : ¬ (b ≤ y) := fun h => hay (Nat.le_trans hab h)
            simp [insertCanonical, hay, hby, ih]
      · have hba : b ≤ a := Nat.le_of_lt (Nat.lt_of_not_ge hab)
        by_cases hby : b ≤ y
        · by_cases hay : a ≤ y
          · simp [insertCanonical, hab, hba, hay, hby]
          · simp [insertCanonical, hab, hay, hby]
        · have hay : ¬ (a ≤ y) := fun h => hby (Nat.le_trans hba h)
          simp [insertCanonical, hay, hby, ih]

theorem canonicalPrefixSort_order_invariant (a b : Nat) (rest : List Nat) :
    canonicalPrefixSort (a :: b :: rest) = canonicalPrefixSort (b :: a :: rest) := by
  simp [canonicalPrefixSort, insertCanonical_comm]

end MemoryQuarantineAndKvPrefixSerialization
