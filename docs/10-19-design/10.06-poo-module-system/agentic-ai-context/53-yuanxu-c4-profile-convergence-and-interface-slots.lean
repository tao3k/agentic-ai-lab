-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
Slice 53 — Lean Unbounded Algebraic & Structural Preservation Laws ONLY:
Machine-checks the six core invariants (`INV-1..INV-6`) of Yuanxu Design 165
(Two-Tier `yuanxu!` + per-module `interface.ss` POO `.o` dispatch tables,
`slot-observation` auto-bridging, and C4 Plural Profile Convergence).
-/

namespace YuanxuC4ProfileConvergence

/-! ## INV-1 & INV-2: Explicit Closure Conservation & Monotone Activation -/

structure ModuleId where
  id : Nat
  deriving DecidableEq, Repr

structure ImpliedRule where
  owner : ModuleId
  prereq : ModuleId
  deriving DecidableEq, Repr

def inClosure (admitted : List ModuleId) (m : ModuleId) : Bool :=
  admitted.contains m

def impliedRuleFires (admitted : List ModuleId) (rule : ImpliedRule) : Bool :=
  inClosure admitted rule.owner && inClosure admitted rule.prereq

def admitImpliedOwners (admitted : List ModuleId) (rules : List ImpliedRule) : List ModuleId :=
  (rules.filter (impliedRuleFires admitted)).map (fun r => r.owner)

theorem impliedFeature_subset_admitted
    (admitted : List ModuleId) (rules : List ImpliedRule) (m : ModuleId) :
    m ∈ admitImpliedOwners admitted rules → inClosure admitted m = true := by
  intro hMem
  unfold admitImpliedOwners at hMem
  rw [List.mem_map] at hMem
  rcases hMem with ⟨r, hFilt, hEq⟩
  rw [List.mem_filter] at hFilt
  have hFire := hFilt.2
  unfold impliedRuleFires at hFire
  simp [Bool.and_eq_true] at hFire
  subst hEq
  exact hFire.1

structure TaggedModule where
  mod : ModuleId
  tags : List Nat
  deriving DecidableEq, Repr

def selectTagTargets
    (admitted : List ModuleId) (catalog : List TaggedModule) (tag : Nat) : List ModuleId :=
  (catalog.filter (fun tm => inClosure admitted tm.mod && tm.tags.contains tag)).map (fun tm => tm.mod)

theorem tagTarget_subset_admitted
    (admitted : List ModuleId) (catalog : List TaggedModule) (tag : Nat) (m : ModuleId) :
    m ∈ selectTagTargets admitted catalog tag → inClosure admitted m = true := by
  intro hMem
  unfold selectTagTargets at hMem
  rw [List.mem_map] at hMem
  rcases hMem with ⟨tm, hFilt, hEq⟩
  rw [List.mem_filter] at hFilt
  have hCond := hFilt.2
  simp [Bool.and_eq_true] at hCond
  subst hEq
  exact hCond.1

theorem impliedRuleFires_monotone
    (a b : List ModuleId) (rule : ImpliedRule)
    (hSub : ∀ x, inClosure a x = true → inClosure b x = true) :
    impliedRuleFires a rule = true → impliedRuleFires b rule = true := by
  intro hA
  unfold impliedRuleFires at hA ⊢
  simp [Bool.and_eq_true] at hA ⊢
  exact ⟨hSub rule.owner hA.1, hSub rule.prereq hA.2⟩

/-! ## INV-3: Band 4b Explicit Veto Dominance over Band 1 Implied Bridge -/

inductive UserToggle where
  | none
  | explicitEnable
  | explicitVeto
  deriving DecidableEq, Repr

def resolveFeatureEnabled (impliedEnabled : Bool) (userToggle : UserToggle) : Bool :=
  match userToggle with
  | .explicitVeto => false
  | .explicitEnable => true
  | .none => impliedEnabled

theorem explicitVeto_dominates_implied (impliedEnabled : Bool) :
    resolveFeatureEnabled impliedEnabled .explicitVeto = false := by
  rfl

theorem impliedActivates_when_prereq_and_no_veto :
    resolveFeatureEnabled true .none = true := by
  rfl

/-! ## INV-4: Same-Band Peer Exclusive Conflict Fail-Closed -/

inductive PeerMerge (α : Type) where
  | ok (v : α)
  | conflict (left right : α)
  deriving DecidableEq, Repr

def combinePeerExclusive {α : Type} [DecidableEq α] (left right : α) : PeerMerge α :=
  if left = right then .ok left else .conflict left right

theorem peerExclusive_disagreement_conflicts {α : Type} [DecidableEq α]
    (left right : α) (hNe : left ≠ right) :
    combinePeerExclusive left right = .conflict left right := by
  unfold combinePeerExclusive
  simp [hNe]

theorem peerExclusive_agreement_collapses {α : Type} [DecidableEq α] (v : α) :
    combinePeerExclusive v v = .ok v := by
  unfold combinePeerExclusive
  simp

/-! ## INV-5: Band 5 GovernanceFloor Monotonic Lattice Meet -/

structure GovernanceEnvelope where
  trustCeiling : Nat
  allowNetwork : Bool
  allowWrite : Bool
  deriving DecidableEq, Repr

def envLe (a b : GovernanceEnvelope) : Prop :=
  a.trustCeiling ≤ b.trustCeiling ∧
  (b.allowNetwork = false → a.allowNetwork = false) ∧
  (b.allowWrite = false → a.allowWrite = false)

def envMeet (a b : GovernanceEnvelope) : GovernanceEnvelope :=
  { trustCeiling := Nat.min a.trustCeiling b.trustCeiling
    allowNetwork := a.allowNetwork && b.allowNetwork
    allowWrite := a.allowWrite && b.allowWrite }

theorem envMeet_le_left (a b : GovernanceEnvelope) : envLe (envMeet a b) a := by
  unfold envLe envMeet
  refine ⟨Nat.min_le_left _ _, ?_, ?_⟩
  · intro h; simp [h]
  · intro h; simp [h]

theorem envLe_trans {a b c : GovernanceEnvelope}
    (hab : envLe a b) (hbc : envLe b c) : envLe a c := by
  refine ⟨Nat.le_trans hab.1 hbc.1, ?_, ?_⟩
  · intro h; exact hab.2.1 (hbc.2.1 h)
  · intro h; exact hab.2.2 (hbc.2.2 h)

def foldGovernanceFloor (base : GovernanceEnvelope) (profiles : List GovernanceEnvelope) :
    GovernanceEnvelope :=
  profiles.foldl envMeet base

theorem foldGovernanceFloor_no_escalation
    (base : GovernanceEnvelope) (profiles : List GovernanceEnvelope) :
    envLe (foldGovernanceFloor base profiles) base := by
  unfold foldGovernanceFloor
  induction profiles generalizing base with
  | nil =>
    exact ⟨Nat.le_refl _, fun h => h, fun h => h⟩
  | cons p ps ih =>
    simp only [List.foldl_cons]
    exact envLe_trans (ih (envMeet base p)) (envMeet_le_left base p)

/-! ## INV-6: Stage Separation & Zero Cost for Inactive Units -/

inductive SlotStage where
  | assembly
  | runtime
  deriving DecidableEq, Repr

structure FeatureUnit where
  id : Nat
  stage : SlotStage
  enabledAtAssembly : Bool
  deriving DecidableEq, Repr

def compiledClosure (units : List FeatureUnit) : List Nat :=
  (units.filter (fun u => u.stage == .assembly && u.enabledAtAssembly)).map (fun u => u.id)

theorem inactiveFeature_excluded_from_compiledClosure
    (units : List FeatureUnit) (u : FeatureUnit)
    (hUnique : ∀ x ∈ units, x.id = u.id → x = u)
    (hOff : u.enabledAtAssembly = false) :
    u.id ∉ compiledClosure units := by
  intro hMem
  unfold compiledClosure at hMem
  rw [List.mem_map] at hMem
  rcases hMem with ⟨x, hFilt, hId⟩
  rw [List.mem_filter] at hFilt
  have hEq := hUnique x hFilt.1 hId
  subst hEq
  have hCond := hFilt.2
  simp [hOff] at hCond

theorem runtimeStageSlot_never_expands_assemblyClosure
    (units : List FeatureUnit) (u : FeatureUnit)
    (hUnique : ∀ x ∈ units, x.id = u.id → x = u)
    (hRt : u.stage = .runtime) :
    u.id ∉ compiledClosure units := by
  intro hMem
  unfold compiledClosure at hMem
  rw [List.mem_map] at hMem
  rcases hMem with ⟨x, hFilt, hId⟩
  rw [List.mem_filter] at hFilt
  have hEq := hUnique x hFilt.1 hId
  subst hEq
  have hCond := hFilt.2
  simp [hRt] at hCond

end YuanxuC4ProfileConvergence
