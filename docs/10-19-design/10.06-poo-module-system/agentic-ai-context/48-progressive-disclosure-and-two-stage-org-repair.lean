-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
Slice 48 — Lean Unbounded Progressive Disclosure Join-Semilattice &
Stage-1 Deterministic Org AST Repair Laws ONLY:
Per `FormalVerificationTaxonomy` in
`48-progressive-disclosure-and-two-stage-org-repair.sysml`, this module proves
pure universal algebraic and structural-induction properties:
1. `DisclosureDepth` (`L0 < L1 < L2 < L3`) forms a join-semilattice (`idem`,
   `comm`, `assoc`), and any active defeater unconditionally forces full `L3`
   unmasked disclosure (`activeDefeater_forces_full_L3_disclosure`).
2. Folding `#+BEGIN_THINKING` special blocks at `L2` preserves every
   `activeDefeater` and `resultsBody` element over arbitrary `List OrgBlock`
   (`foldThinking_preserves_defeaters_and_results`).
3. Stage-1 deterministic AST repair (`stageOneRepair`) is idempotent over
   arbitrary node lists (`stageOneRepair_idem`), preserves every `:ID:` and
   `hasActiveDefeater` bit (`stageOneRepair_preserves_ids_and_defeaters`), and
   Stage-2 Flash repair requests inhabit zero direct write authority
   (`stageTwoRequest_carries_zero_write_authority`).
Asynchronous defeater arrival vs folded views and Stage-2 repair cut races
belong exclusively to `48-*.qnt`.
-/

namespace ProgressiveDisclosureAndOrgRepair

inductive DisclosureDepth where
  | L0_skeleton
  | L1_propertiesAndChecklists
  | L2_resultsThinkingFolded
  | L3_fullRawSpan
  deriving DecidableEq, Repr

def DisclosureDepth.rank : DisclosureDepth → Nat
  | .L0_skeleton => 0
  | .L1_propertiesAndChecklists => 1
  | .L2_resultsThinkingFolded => 2
  | .L3_fullRawSpan => 3

def DisclosureDepth.le (a b : DisclosureDepth) : Prop :=
  a.rank ≤ b.rank

instance : LE DisclosureDepth := ⟨DisclosureDepth.le⟩

def maxDepth (a b : DisclosureDepth) : DisclosureDepth :=
  if a.rank ≤ b.rank then b else a

theorem maxDepth_idem (a : DisclosureDepth) : maxDepth a a = a := by
  cases a <;> rfl

theorem maxDepth_comm (a b : DisclosureDepth) : maxDepth a b = maxDepth b a := by
  cases a <;> cases b <;> rfl

theorem maxDepth_assoc (a b c : DisclosureDepth) :
    maxDepth (maxDepth a b) c = maxDepth a (maxDepth b c) := by
  cases a <;> cases b <;> cases c <;> rfl

def deriveDisclosureDepth
    (baseRequested : DisclosureDepth)
    (explicitDrillDown : Bool)
    (hasActiveDefeater : Bool) : DisclosureDepth :=
  if hasActiveDefeater || explicitDrillDown then
    .L3_fullRawSpan
  else
    baseRequested

theorem activeDefeater_forces_full_L3_disclosure
    (baseRequested : DisclosureDepth) (explicitDrillDown : Bool) :
    deriveDisclosureDepth baseRequested explicitDrillDown true = .L3_fullRawSpan := by
  rfl

/-! ## L2 Thinking-Block Folding Preserves Defeaters & Results -/

inductive OrgBlockKind where
  | thinkingBlock
  | nestedThinkingDrawer
  | resultsBody
  | activeDefeaterBlock
  | checklistItem
  deriving DecidableEq, Repr

structure OrgNode (NodeId : Type) where
  id : NodeId
  kind : OrgBlockKind
  drawerClosed : Bool
  cookieSynced : Bool
  hasActiveDefeater : Bool
  deriving DecidableEq, Repr

def foldThinkingAtL2 {NodeId : Type} (xs : List (OrgNode NodeId)) : List (OrgNode NodeId) :=
  xs.filter (fun n => n.kind != .thinkingBlock && n.kind != .nestedThinkingDrawer)

theorem foldThinking_preserves_defeaters_and_results
    {NodeId : Type} (xs : List (OrgNode NodeId)) (n : OrgNode NodeId)
    (hMem : n ∈ xs)
    (hKeep : n.kind = .activeDefeaterBlock ∨ n.kind = .resultsBody) :
    n ∈ foldThinkingAtL2 xs := by
  unfold foldThinkingAtL2
  rw [List.mem_filter]
  refine ⟨hMem, ?_⟩
  cases hKeep with
  | inl hDef => rw [hDef]; rfl
  | inr hRes => rw [hRes]; rfl

/-! ## Stage-1 Deterministic AST Auto-Repair (0 LLM Tokens): Idempotence & Preservation -/

def repairKind : OrgBlockKind → OrgBlockKind
  | .nestedThinkingDrawer => .thinkingBlock
  | other => other

def stageOneRepairNode {NodeId : Type} (n : OrgNode NodeId) : OrgNode NodeId :=
  { id := n.id
    kind := repairKind n.kind
    drawerClosed := true
    cookieSynced := true
    hasActiveDefeater := n.hasActiveDefeater }

def stageOneRepair {NodeId : Type} (xs : List (OrgNode NodeId)) : List (OrgNode NodeId) :=
  xs.map stageOneRepairNode

theorem repairKind_idem (k : OrgBlockKind) : repairKind (repairKind k) = repairKind k := by
  cases k <;> rfl

theorem stageOneRepairNode_idem {NodeId : Type} (n : OrgNode NodeId) :
    stageOneRepairNode (stageOneRepairNode n) = stageOneRepairNode n := by
  unfold stageOneRepairNode
  simp [repairKind_idem]

theorem stageOneRepair_idem {NodeId : Type} (xs : List (OrgNode NodeId)) :
    stageOneRepair (stageOneRepair xs) = stageOneRepair xs := by
  induction xs with
  | nil => rfl
  | cons head tail ih =>
      unfold stageOneRepair at ih ⊢
      simp only [List.map_cons]
      rw [stageOneRepairNode_idem, ih]

theorem stageOneRepair_preserves_ids_and_defeaters
    {NodeId : Type} (xs : List (OrgNode NodeId)) :
    (stageOneRepair xs).map (fun n => (n.id, n.hasActiveDefeater)) =
      xs.map (fun n => (n.id, n.hasActiveDefeater)) := by
  induction xs with
  | nil => rfl
  | cons head tail ih =>
      simp only [stageOneRepair, List.map_cons, stageOneRepairNode]
      exact congrArg ((head.id, head.hasActiveDefeater) :: ·) ih

inductive StageTwoDirectWriteAuthority : Type where
  -- Intentionally uninhabited: Stage-2 Flash repair requests never self-authorize Org writes.

theorem stageTwoRequest_carries_zero_write_authority
    (witness : StageTwoDirectWriteAuthority) : False := by
  cases witness

end ProgressiveDisclosureAndOrgRepair
