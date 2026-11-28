-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
Slice 52 — FunFlow CAS Singleflight, Fail-Closed Premise Invalidation,
AuditCapsule-Pinned GC, and ExternalTask Sandbox Binding (Lean 4 Proofs ONLY):

Directly challenges and formally repairs five concrete logical bugs uncovered
by auditing `modules/funflow/{durable-dag,store,control-plane/*}.ss`:
1. `BUG-F3a`: Missing `stepCodeDigest` and `envDigest` in `funflow-cas-fingerprint`
   -> canonical 5-tuple key sensitivity & canonical input-order invariance.
2. `BUG-F2`: Fail-open premise invalidation in `funflow-invalidate-premises` when
   a premise is retracted (`live = #f`) -> proven bug witness vs fail-closed law.
3. `BUG-F3b`: `cas-hit?` ignoring `EffectClass` -> `FencedEffect` never reused
   by plain CAS fingerprint without an authoritative idempotency commit receipt.
4. `BUG-F5`: Unpinned CAS GC deleting `cut = 1` forensic artifacts ->
   `gc_never_evicts_capsule_pinned_entry`.
5. `BUG-F4`: Disjoint lease meet silently emitting inverted intervals &
   `ExternalTask` missing `envDigest` / Lethal-Trifecta sandbox enforcement.
-/

namespace FunflowCasSingleflightAndExternalSandbox

/-! ## 1. Canonical 5-Tuple CAS Key (BUG-F3a) -/

def insertSortedNat (x : Nat) : List Nat → List Nat
  | [] => [x]
  | y :: ys => if x ≤ y then x :: y :: ys else y :: insertSortedNat x ys

def sortNats : List Nat → List Nat
  | [] => []
  | x :: xs => insertSortedNat x (sortNats xs)

structure CanonicalCasKey where
  schemaVersion : Nat
  stepCodeDigest : Nat
  envDigest : Nat
  sortedInputHashes : List Nat
  sortedPremiseDigests : List Nat
  deriving DecidableEq, Repr

def computeCanonicalCasKey
    (schemaVersion stepCodeDigest envDigest : Nat)
    (rawInputHashes rawPremiseDigests : List Nat) : CanonicalCasKey :=
  { schemaVersion := schemaVersion
    stepCodeDigest := stepCodeDigest
    envDigest := envDigest
    sortedInputHashes := sortNats rawInputHashes
    sortedPremiseDigests := sortNats rawPremiseDigests }

theorem casKey_sensitive_to_code_and_env_drift
    (schemaVer code1 code2 env1 env2 : Nat)
    (inputs premises : List Nat)
    (hDrift : code1 ≠ code2 ∨ env1 ≠ env2) :
    computeCanonicalCasKey schemaVer code1 env1 inputs premises ≠
      computeCanonicalCasKey schemaVer code2 env2 inputs premises := by
  intro hEq
  cases hEq
  cases hDrift with
  | inl hCode => exact hCode rfl
  | inr hEnv => exact hEnv rfl

theorem casKey_input_order_invariant
    (schemaVer codeDigest envDigest a b : Nat)
    (premises : List Nat) :
    computeCanonicalCasKey schemaVer codeDigest envDigest [a, b] premises =
      computeCanonicalCasKey schemaVer codeDigest envDigest [b, a] premises := by
  by_cases hab : a ≤ b
  · by_cases hba : b ≤ a
    · have hEq : a = b := Nat.le_antisymm hab hba
      subst hEq
      rfl
    · simp [computeCanonicalCasKey, sortNats, insertSortedNat, hab, hba]
  · have hba : b ≤ a := Nat.le_of_not_ge hab
    simp [computeCanonicalCasKey, sortNats, insertSortedNat, hab, hba]

/-! ## 2. Fail-Closed Premise Retraction Invalidation (BUG-F2 Challenge & Repair) -/

def lookupPremise {K V : Type} [DecidableEq K] : List (K × V) → K → Option V
  | [], _ => none
  | (k', v') :: rest, k => if k' = k then some v' else lookupPremise rest k

/-- Models the real fail-open bug at `modules/funflow/durable-dag.ss:754`:
    `(and live (not (equal? (cdr live) expected)))` returns `false` when `live = none`! -/
def premiseDriftedBuggyFailOpen {K V : Type} [DecidableEq K] [DecidableEq V]
    (livePremises : List (K × V)) (k : K) (expected : V) : Bool :=
  match lookupPremise livePremises k with
  | none => false
  | some actual => decide (actual ≠ expected)

/-- Repaired fail-closed premise drift check: missing/retracted premise ALWAYS drifts. -/
def premiseDriftedFailClosed {K V : Type} [DecidableEq K] [DecidableEq V]
    (livePremises : List (K × V)) (k : K) (expected : V) : Bool :=
  match lookupPremise livePremises k with
  | none => true
  | some actual => decide (actual ≠ expected)

theorem buggyFailOpen_misses_retracted_premise
    {K V : Type} [DecidableEq K] [DecidableEq V]
    (livePremises : List (K × V)) (k : K) (expected : V)
    (hRetracted : lookupPremise livePremises k = none) :
    premiseDriftedBuggyFailOpen livePremises k expected = false := by
  unfold premiseDriftedBuggyFailOpen
  rw [hRetracted]

theorem retractedPremise_always_invalidates_fail_closed
    {K V : Type} [DecidableEq K] [DecidableEq V]
    (livePremises : List (K × V)) (k : K) (expected : V)
    (hRetracted : lookupPremise livePremises k = none) :
    premiseDriftedFailClosed livePremises k expected = true := by
  unfold premiseDriftedFailClosed
  rw [hRetracted]

/-! ## 3. Effect-Class-Aware CAS Skip Admission (BUG-F3b) -/

inductive NodeEffectClass where
  | pureCAS
  | verifiedEpistemic
  | fencedEffect
  deriving DecidableEq, Repr

def casSkipAdmitted
    (eff : NodeEffectClass)
    (hasPlainCasHit : Bool)
    (liveCutAndEndorsed : Bool)
    (hasIdempotencyCommitReceipt : Bool) : Bool :=
  match eff with
  | .pureCAS => hasPlainCasHit
  | .verifiedEpistemic => hasPlainCasHit && liveCutAndEndorsed
  | .fencedEffect => hasIdempotencyCommitReceipt

theorem fencedEffect_never_reused_by_plain_cas
    (hasPlainCasHit liveCutAndEndorsed : Bool) :
    casSkipAdmitted .fencedEffect hasPlainCasHit liveCutAndEndorsed false = false := by
  rfl

/-! ## 4. AuditCapsule-Pinned CAS Garbage Collection (BUG-F5) -/

structure CasStoreEntry (Key : Type) where
  key : Key
  capsulePinned : Bool
  liveInActiveDag : Bool
  deriving DecidableEq, Repr

def retainUnderGc {Key : Type} (entry : CasStoreEntry Key) : Bool :=
  entry.capsulePinned || entry.liveInActiveDag

def gcSweep {Key : Type} (entries : List (CasStoreEntry Key)) : List (CasStoreEntry Key) :=
  entries.filter retainUnderGc

theorem gc_never_evicts_capsule_pinned_entry
    {Key : Type}
    (entries : List (CasStoreEntry Key))
    (e : CasStoreEntry Key)
    (hMem : e ∈ entries)
    (hPinned : e.capsulePinned = true) :
    e ∈ gcSweep entries := by
  unfold gcSweep
  rw [List.mem_filter]
  refine ⟨hMem, ?_⟩
  unfold retainUnderGc
  rw [hPinned]
  rfl

/-! ## 5. Disjoint Lease Meet & ExternalTask Sandbox Binding (BUG-F4) -/

structure LeaseWindow where
  leaseStart : Nat
  leaseEnd : Nat
  deriving DecidableEq, Repr

def leaseMeet (p o : LeaseWindow) : LeaseWindow :=
  { leaseStart := max p.leaseStart o.leaseStart
    leaseEnd := min p.leaseEnd o.leaseEnd }

def leaseAdmits (w : LeaseWindow) (now : Nat) : Bool :=
  decide (w.leaseStart ≤ now ∧ now ≤ w.leaseEnd)

theorem disjointLeaseMeet_is_unsatisfiable
    (p o : LeaseWindow) (now : Nat)
    (hDisjoint : p.leaseEnd < o.leaseStart) :
    leaseAdmits (leaseMeet p o) now = false := by
  unfold leaseAdmits leaseMeet
  simp only [decide_eq_false_iff_not, not_and]
  intro hGe hLe
  have h1 : o.leaseStart ≤ now := Nat.le_trans (Nat.le_max_right p.leaseStart o.leaseStart) hGe
  have h2 : now ≤ p.leaseEnd := Nat.le_trans hLe (Nat.min_le_left p.leaseEnd o.leaseEnd)
  have h3 : o.leaseStart ≤ p.leaseEnd := Nat.le_trans h1 h2
  exact Nat.not_lt_of_ge h3 hDisjoint

structure ExternalTaskSandboxProfile where
  envPinned : Bool
  leaseValid : Bool
  hasUntrustedInput : Bool
  hasPrivateData : Bool
  egressEnabled : Bool
  egressEndorsed : Bool
  deriving DecidableEq, Repr

def lethalTrifectaExposed (prof : ExternalTaskSandboxProfile) : Bool :=
  prof.hasUntrustedInput && prof.hasPrivateData && prof.egressEnabled && !prof.egressEndorsed

def admitExternalTaskSandbox (prof : ExternalTaskSandboxProfile) : Bool :=
  prof.envPinned && prof.leaseValid && !lethalTrifectaExposed prof

theorem externalTask_rejects_unpinned_or_trifecta_sandbox
    (prof : ExternalTaskSandboxProfile)
    (hBad : prof.envPinned = false ∨ prof.leaseValid = false ∨ lethalTrifectaExposed prof = true) :
    admitExternalTaskSandbox prof = false := by
  unfold admitExternalTaskSandbox
  cases hBad with
  | inl hUnpinned =>
      rw [hUnpinned]
      rfl
  | inr hRest =>
      cases hRest with
      | inl hLease =>
          rw [hLease]
          simp
      | inr hTri =>
          rw [hTri]
          simp

end FunflowCasSingleflightAndExternalSandbox
