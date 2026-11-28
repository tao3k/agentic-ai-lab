-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
Slice 49 — Lean Unbounded Algebraic & Structural Preservation Laws ONLY:
Per `FormalVerificationTaxonomy` in
`49-scoped-detour-funflow-concurrent-shared-context.sysml`, this module proves
pure universal algebraic and structural-induction properties:
1. C4 `OrgOverlay(g)` `RestrictionEnvelope` meet never escalates trust ceiling,
   lease window, or write/push capabilities (`orgOverlayMeet_*`).
2. Three-State FunFlow Effect admission enforces the asymmetric safety gate:
   `FencedEffect` requires `claimsExhaustive ∧ hasAuthorizedToken ∧ hasEndorsement`,
   while `PureCAS` admits unconditionally (`fencedEffect_requires_exhaustive_token_and_endorsement`,
   `pureCAS_admitted_without_exhaustiveness`).
3. Reconciling a `CancelledExit` detour preserves every prior mainline defeater
   and every newly discovered defeat condition over arbitrary lists
   (`cancelledDetour_preserves_mainline_and_new_defeaters`), and zero-token
   `reanchorMainline` blocks Auto-Archive whenever any blocker detour or
   mainline invariant remains open
   (`reanchorMainline_blocks_archive_if_blocker_or_invariant_open`).
4. Zero-SubAgent concurrent Shared-Context `:ID:` ownership rejects every
   direct overwrite by a non-owner (`directWrite_nonOwner_rejected`), while a
   disjoint child extension leaves the claimed parent node's owner, lease epoch,
   and payload strictly invariant (`extendChild_preserves_claimed_node_invariant`).
Concurrent interleavings and fault-injection traces belong exclusively to `49-*.qnt`.
-/

namespace ScopedDetourFunflowConcurrentContext

/-! ## 1. Monotonic C4 `OrgOverlay(g)` RestrictionEnvelope Meet -/

structure RestrictionEnvelope where
  trustCeiling : Nat
  leaseStart : Nat
  leaseEnd : Nat
  canWrite : Bool
  canPush : Bool
  deriving DecidableEq, Repr

def envelopeMeet (parent overlay : RestrictionEnvelope) : RestrictionEnvelope :=
  { trustCeiling := Nat.min parent.trustCeiling overlay.trustCeiling
    leaseStart := Nat.max parent.leaseStart overlay.leaseStart
    leaseEnd := Nat.min parent.leaseEnd overlay.leaseEnd
    canWrite := parent.canWrite && overlay.canWrite
    canPush := parent.canPush && overlay.canPush }

theorem orgOverlayMeet_no_trust_escalation (parent overlay : RestrictionEnvelope) :
    (envelopeMeet parent overlay).trustCeiling ≤ parent.trustCeiling := by
  unfold envelopeMeet
  exact Nat.min_le_left parent.trustCeiling overlay.trustCeiling

theorem orgOverlayMeet_lease_contained (parent overlay : RestrictionEnvelope) :
    parent.leaseStart ≤ (envelopeMeet parent overlay).leaseStart ∧
    (envelopeMeet parent overlay).leaseEnd ≤ parent.leaseEnd := by
  unfold envelopeMeet
  exact ⟨Nat.le_max_left parent.leaseStart overlay.leaseStart,
         Nat.min_le_left parent.leaseEnd overlay.leaseEnd⟩

theorem orgOverlayMeet_capabilities_monotonic (parent overlay : RestrictionEnvelope) :
    (parent.canWrite = false → (envelopeMeet parent overlay).canWrite = false) ∧
    (parent.canPush = false → (envelopeMeet parent overlay).canPush = false) := by
  unfold envelopeMeet
  constructor
  · intro hW
    simp [hW]
  · intro hP
    simp [hP]

/-! ## 2. Three-State FunFlow Effect Algebra & Asymmetric Safety Gate -/

inductive EffectClass where
  | pureCAS
  | verifiedEpistemic
  | fencedEffect
  deriving DecidableEq, Repr

def admitNodeEffect
    (eff : EffectClass)
    (claimsExhaustive hasAuthorizedToken hasEndorsement : Bool) : Bool :=
  match eff with
  | .pureCAS => true
  | .verifiedEpistemic => hasEndorsement
  | .fencedEffect => claimsExhaustive && hasAuthorizedToken && hasEndorsement

theorem fencedEffect_requires_exhaustive_token_and_endorsement
    (ex tok endor : Bool) :
    admitNodeEffect .fencedEffect ex tok endor = true ↔
      ex = true ∧ tok = true ∧ endor = true := by
  unfold admitNodeEffect
  cases ex <;> cases tok <;> cases endor <;> simp

theorem pureCAS_admitted_without_exhaustiveness :
    admitNodeEffect .pureCAS false false false = true := by
  rfl

/-! ## 3. Scoped Detour 4-Exit Counterexample Core & Zero-Token Re-Anchor Guard -/

inductive DetourExit where
  | completed
  | parkedCustody
  | cancelled
  | promotedToTask
  deriving DecidableEq, Repr

def reconcileCounterexampleCore {DefeaterId : Type}
    (mainlineCore detourDefeaters : List DefeaterId)
    (exitKind : DetourExit) : List DefeaterId :=
  match exitKind with
  | .completed => mainlineCore ++ detourDefeaters
  | .parkedCustody => mainlineCore ++ detourDefeaters
  | .cancelled => mainlineCore ++ detourDefeaters
  | .promotedToTask => mainlineCore

theorem cancelledDetour_preserves_mainline_and_new_defeaters
    {DefeaterId : Type}
    (mainlineCore detourDefeaters : List DefeaterId)
    (d : DefeaterId)
    (hMem : d ∈ mainlineCore ∨ d ∈ detourDefeaters) :
    d ∈ reconcileCounterexampleCore mainlineCore detourDefeaters .cancelled := by
  unfold reconcileCounterexampleCore
  rw [List.mem_append]
  exact hMem

def readyToAutoArchive
    (rootDone : Bool)
    (openBlockerDetours : Nat)
    (unsatisfiedInvariants : Nat)
    (inFlightAttempts : Nat) : Bool :=
  rootDone && (openBlockerDetours == 0) && (unsatisfiedInvariants == 0) && (inFlightAttempts == 0)

theorem reanchorMainline_blocks_archive_if_blocker_or_invariant_open
    (rootDone : Bool) (openBlockers openInvariants inFlight : Nat)
    (hOpen : openBlockers > 0 ∨ openInvariants > 0) :
    readyToAutoArchive rootDone openBlockers openInvariants inFlight = false := by
  unfold readyToAutoArchive
  cases hOpen with
  | inl hB =>
    have hNe : (openBlockers == 0) = false := by
      cases openBlockers with
      | zero => exact False.elim (Nat.lt_irrefl 0 hB)
      | succ _ => rfl
    simp [hNe]
  | inr hI =>
    have hNe : (openInvariants == 0) = false := by
      cases openInvariants with
      | zero => exact False.elim (Nat.lt_irrefl 0 hI)
      | succ _ => rfl
    simp [hNe]

/-! ## 4. Zero-SubAgent Concurrent Shared Context (`:ID:` Ownership & Extend-Never-Overwrite) -/

structure ClaimedNode (NodeId ActorId Payload : Type) where
  id : NodeId
  owner : Option ActorId
  leaseEpoch : Nat
  payload : Payload
  deriving DecidableEq, Repr

def directWriteNode {NodeId ActorId Payload : Type} [DecidableEq ActorId]
    (actor : ActorId) (newPayload : Payload) (node : ClaimedNode NodeId ActorId Payload) :
    Option (ClaimedNode NodeId ActorId Payload) :=
  match node.owner with
  | none => some { node with owner := some actor, leaseEpoch := node.leaseEpoch + 1, payload := newPayload }
  | some currentOwner =>
    if currentOwner = actor then
      some { node with payload := newPayload }
    else
      none

theorem directWrite_nonOwner_rejected
    {NodeId ActorId Payload : Type} [DecidableEq ActorId]
    (actor owner : ActorId) (newPayload : Payload)
    (node : ClaimedNode NodeId ActorId Payload)
    (hOwner : node.owner = some owner)
    (hDiff : owner ≠ actor) :
    directWriteNode actor newPayload node = none := by
  unfold directWriteNode
  rw [hOwner]
  simp [hDiff]

def extendSharedContext {NodeId ActorId Payload : Type}
    (ctx : List (ClaimedNode NodeId ActorId Payload))
    (extensionNode : ClaimedNode NodeId ActorId Payload) :
    List (ClaimedNode NodeId ActorId Payload) :=
  ctx ++ [extensionNode]

theorem extendChild_preserves_claimed_node_invariant
    {NodeId ActorId Payload : Type}
    (ctx : List (ClaimedNode NodeId ActorId Payload))
    (claimedNode extensionNode : ClaimedNode NodeId ActorId Payload)
    (hMem : claimedNode ∈ ctx) :
    claimedNode ∈ extendSharedContext ctx extensionNode := by
  unfold extendSharedContext
  rw [List.mem_append]
  exact Or.inl hMem

/-! ## 5. Fenced Heartbeat-Expiry Custody Takeover (Anti-Split-Brain) -/

structure LeaseClaim (ActorId : Type) where
  owner : ActorId
  leaseEpoch : Nat
  heartbeatAt : Nat
  leaseTtl : Nat
  deriving DecidableEq, Repr

def leaseExpired (now : Nat) {ActorId : Type} (c : LeaseClaim ActorId) : Bool :=
  decide (c.heartbeatAt + c.leaseTtl ≤ now)

def expiredLeaseTakeover {ActorId : Type}
    (now : Nat) (nextActor : ActorId) (c : LeaseClaim ActorId) :
    Option (LeaseClaim ActorId) :=
  if leaseExpired now c then
    some { owner := nextActor, leaseEpoch := c.leaseEpoch + 1, heartbeatAt := now, leaseTtl := c.leaseTtl }
  else
    none

theorem activeLeaseTakeover_rejected_before_expiry
    {ActorId : Type} (now : Nat) (nextActor : ActorId) (c : LeaseClaim ActorId)
    (hLive : now < c.heartbeatAt + c.leaseTtl) :
    expiredLeaseTakeover now nextActor c = none := by
  unfold expiredLeaseTakeover leaseExpired
  have hNotLe : ¬ (c.heartbeatAt + c.leaseTtl ≤ now) := Nat.not_le.mpr hLive
  simp [hNotLe]

theorem expiredLeaseTakeover_strictly_advances_epoch
    {ActorId : Type} (now : Nat) (nextActor : ActorId) (c nextC : LeaseClaim ActorId)
    (hTake : expiredLeaseTakeover now nextActor c = some nextC) :
    c.leaseEpoch < nextC.leaseEpoch ∧ nextC.owner = nextActor := by
  unfold expiredLeaseTakeover at hTake
  split at hTake
  · injection hTake with hEq
    subst hEq
    exact ⟨Nat.lt_succ_self c.leaseEpoch, rfl⟩
  · contradiction

end ScopedDetourFunflowConcurrentContext
