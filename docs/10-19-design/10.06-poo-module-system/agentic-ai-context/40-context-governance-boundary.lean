-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
Slice 40 — Lean Unbounded Algebraic & Inductive Laws ONLY:
Per `FormalVerificationTaxonomy` in `40-context-governance-boundary.sysml`,
this module proves pure, state-machine-free universal properties:
1. `TrustRole` bounded meet-semilattice (`idem`, `comm`, `assoc`, lower bounds)
   and structural induction over arbitrary-length provenance chains `foldRoles`.
2. `RestrictionEnvelope` product lower-semilattice (`Refines` preorder, `meet`
   universal lower bounds, and `composeRestrictions_refines_every_member` over
   unbounded `List RestrictionEnvelope`).
3. Domain-isolated KV cache key injectivity (`kvDomainKey_injective`) and
   uninhabited execution authority (`governance_value_carries_zero_authority`).
Concurrent endorsement/threat/cut races belong exclusively to `40-*.qnt`.
-/

namespace ContextGovernanceBoundary

inductive TrustRole where
  | untrustedData
  | observedFact
  | modelProposal
  | userIntent
  | systemPolicy
  deriving DecidableEq, Repr

def TrustRole.rank : TrustRole → Nat
  | .untrustedData => 0
  | .observedFact => 1
  | .modelProposal => 2
  | .userIntent => 3
  | .systemPolicy => 4

theorem TrustRole.rank_injective {a b : TrustRole} (h : a.rank = b.rank) : a = b := by
  cases a <;> cases b <;> simp [TrustRole.rank] at h <;> rfl

def TrustRole.le (a b : TrustRole) : Prop :=
  a.rank ≤ b.rank

instance : LE TrustRole := ⟨TrustRole.le⟩

def TrustRole.minRole (a b : TrustRole) : TrustRole :=
  if a.rank ≤ b.rank then a else b

theorem minRole_rank (a b : TrustRole) :
    (TrustRole.minRole a b).rank = Nat.min a.rank b.rank := by
  unfold TrustRole.minRole
  split
  · rename_i h
    exact (Nat.min_eq_left h).symm
  · rename_i h
    exact (Nat.min_eq_right (Nat.le_of_lt (Nat.gt_of_not_le h))).symm

theorem minRole_idem (a : TrustRole) : TrustRole.minRole a a = a := by
  cases a <;> rfl

theorem minRole_comm (a b : TrustRole) :
    TrustRole.minRole a b = TrustRole.minRole b a := by
  cases a <;> cases b <;> rfl

theorem minRole_assoc (a b c : TrustRole) :
    TrustRole.minRole (TrustRole.minRole a b) c =
      TrustRole.minRole a (TrustRole.minRole b c) := by
  cases a <;> cases b <;> cases c <;> rfl

theorem minRole_le_left (a b : TrustRole) : (TrustRole.minRole a b) ≤ a := by
  change (TrustRole.minRole a b).rank ≤ a.rank
  cases a <;> cases b <;> decide

theorem minRole_le_right (a b : TrustRole) : (TrustRole.minRole a b) ≤ b := by
  change (TrustRole.minRole a b).rank ≤ b.rank
  cases a <;> cases b <;> decide

def foldRoles (seed : TrustRole) : List TrustRole → TrustRole
  | [] => seed
  | r :: rs => foldRoles (TrustRole.minRole seed r) rs

theorem foldRoles_le_seed (seed : TrustRole) (rs : List TrustRole) :
    foldRoles seed rs ≤ seed := by
  induction rs generalizing seed with
  | nil => exact Nat.le_refl _
  | cons r tail ih =>
      exact Nat.le_trans (ih (TrustRole.minRole seed r)) (minRole_le_left seed r)

theorem foldRoles_le_every_premise (seed r : TrustRole) (rs : List TrustRole)
    (hMem : r ∈ rs) :
    foldRoles seed rs ≤ r := by
  induction rs generalizing seed with
  | nil => cases hMem
  | cons head tail ih =>
      cases hMem with
      | head =>
          exact Nat.le_trans
            (foldRoles_le_seed (TrustRole.minRole seed r) tail)
            (minRole_le_right seed r)
      | tail _ hTail =>
          exact ih (TrustRole.minRole seed head) hTail

/-! ## Restriction Envelope Product Lower-Semilattice -/

structure RestrictionEnvelope (Reader Dest Cap Obl : Type) where
  allowsReader : Reader → Prop
  allowsDest : Dest → Prop
  allowsCap : Cap → Prop
  leaseStart : Nat
  leaseEnd : Nat
  maxRole : TrustRole
  requiresObligation : Obl → Prop

def RestrictionEnvelope.Refines {Reader Dest Cap Obl : Type}
    (child parent : RestrictionEnvelope Reader Dest Cap Obl) : Prop :=
  (∀ r, child.allowsReader r → parent.allowsReader r) ∧
  (∀ d, child.allowsDest d → parent.allowsDest d) ∧
  (∀ c, child.allowsCap c → parent.allowsCap c) ∧
  parent.leaseStart ≤ child.leaseStart ∧
  child.leaseEnd ≤ parent.leaseEnd ∧
  child.maxRole ≤ parent.maxRole ∧
  (∀ o, parent.requiresObligation o → child.requiresObligation o)

theorem RestrictionEnvelope.refines_refl {Reader Dest Cap Obl : Type}
    (x : RestrictionEnvelope Reader Dest Cap Obl) :
    x.Refines x := by
  refine ⟨?_, ?_, ?_, Nat.le_refl _, Nat.le_refl _, Nat.le_refl _, ?_⟩ <;>
    intro _ h <;> exact h

theorem RestrictionEnvelope.refines_trans {Reader Dest Cap Obl : Type}
    {a b c : RestrictionEnvelope Reader Dest Cap Obl}
    (hab : a.Refines b) (hbc : b.Refines c) :
    a.Refines c := by
  rcases hab with ⟨hr1, hd1, hc1, hs1, he1, hm1, ho1⟩
  rcases hbc with ⟨hr2, hd2, hc2, hs2, he2, hm2, ho2⟩
  refine ⟨fun x h => hr2 x (hr1 x h),
          fun x h => hd2 x (hd1 x h),
          fun x h => hc2 x (hc1 x h),
          Nat.le_trans hs2 hs1,
          Nat.le_trans he1 he2,
          Nat.le_trans hm1 hm2,
          fun x h => ho1 x (ho2 x h)⟩

def RestrictionEnvelope.meet {Reader Dest Cap Obl : Type}
    (a b : RestrictionEnvelope Reader Dest Cap Obl) :
    RestrictionEnvelope Reader Dest Cap Obl where
  allowsReader r := a.allowsReader r ∧ b.allowsReader r
  allowsDest d := a.allowsDest d ∧ b.allowsDest d
  allowsCap c := a.allowsCap c ∧ b.allowsCap c
  leaseStart := Nat.max a.leaseStart b.leaseStart
  leaseEnd := Nat.min a.leaseEnd b.leaseEnd
  maxRole := TrustRole.minRole a.maxRole b.maxRole
  requiresObligation o := a.requiresObligation o ∨ b.requiresObligation o

theorem RestrictionEnvelope.meet_refines_left {Reader Dest Cap Obl : Type}
    (a b : RestrictionEnvelope Reader Dest Cap Obl) :
    (a.meet b).Refines a := by
  refine ⟨fun _ h => h.1,
          fun _ h => h.1,
          fun _ h => h.1,
          Nat.le_max_left _ _,
          Nat.min_le_left _ _,
          minRole_le_left _ _,
          fun _ h => Or.inl h⟩

theorem RestrictionEnvelope.meet_refines_right {Reader Dest Cap Obl : Type}
    (a b : RestrictionEnvelope Reader Dest Cap Obl) :
    (a.meet b).Refines b := by
  refine ⟨fun _ h => h.2,
          fun _ h => h.2,
          fun _ h => h.2,
          Nat.le_max_right _ _,
          Nat.min_le_right _ _,
          minRole_le_right _ _,
          fun _ h => Or.inr h⟩

def composeRestrictions {Reader Dest Cap Obl : Type}
    (base : RestrictionEnvelope Reader Dest Cap Obl) :
    List (RestrictionEnvelope Reader Dest Cap Obl) → RestrictionEnvelope Reader Dest Cap Obl
  | [] => base
  | r :: rs => composeRestrictions (base.meet r) rs

theorem composeRestrictions_refines_base {Reader Dest Cap Obl : Type}
    (base : RestrictionEnvelope Reader Dest Cap Obl)
    (rs : List (RestrictionEnvelope Reader Dest Cap Obl)) :
    (composeRestrictions base rs).Refines base := by
  induction rs generalizing base with
  | nil => exact RestrictionEnvelope.refines_refl base
  | cons r tail ih =>
      exact RestrictionEnvelope.refines_trans
        (ih (base.meet r))
        (RestrictionEnvelope.meet_refines_left base r)

theorem composeRestrictions_refines_every_member {Reader Dest Cap Obl : Type}
    (base m : RestrictionEnvelope Reader Dest Cap Obl)
    (rs : List (RestrictionEnvelope Reader Dest Cap Obl))
    (hMem : m ∈ rs) :
    (composeRestrictions base rs).Refines m := by
  induction rs generalizing base with
  | nil => cases hMem
  | cons r tail ih =>
      cases hMem with
      | head =>
          exact RestrictionEnvelope.refines_trans
            (composeRestrictions_refines_base (base.meet m) tail)
            (RestrictionEnvelope.meet_refines_right base m)
      | tail _ hInTail =>
          exact ih (base.meet r) hInTail

/-! ## Domain-Isolated KV Prefix Key Homomorphism & Uninhabited Authority -/

structure SecurityDomain (Tenant Principal RestrDigest TokProfile : Type) where
  tenant : Tenant
  principal : Principal
  restrictionDigest : RestrDigest
  tokenizer : TokProfile
  deriving DecidableEq

structure KvCacheKey (Tenant Principal RestrDigest TokProfile Tokens : Type) where
  domain : SecurityDomain Tenant Principal RestrDigest TokProfile
  renderedPrefix : Tokens
  deriving DecidableEq

def buildKvKey {Tenant Principal RestrDigest TokProfile Tokens : Type}
    (dom : SecurityDomain Tenant Principal RestrDigest TokProfile)
    (toks : Tokens) : KvCacheKey Tenant Principal RestrDigest TokProfile Tokens :=
  ⟨dom, toks⟩

theorem kvDomainKey_injective
    {Tenant Principal RestrDigest TokProfile Tokens : Type}
    (d1 d2 : SecurityDomain Tenant Principal RestrDigest TokProfile)
    (toks : Tokens)
    (hDiff : d1 ≠ d2) :
    buildKvKey d1 toks ≠ buildKvKey d2 toks := by
  intro hEq
  injection hEq with hSame _
  exact hDiff hSame

inductive GovernanceExecutionAuthority : Type where
  -- Intentionally uninhabited: Governance values carry zero runtime execution authority.

theorem governance_value_carries_zero_authority
    (witness : GovernanceExecutionAuthority) : False := by
  cases witness

end ContextGovernanceBoundary
