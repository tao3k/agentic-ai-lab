-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
Slice 45 — Lean Unbounded Recursive AST & Multi-Hop GQL Path Induction ONLY:
Per `FormalVerificationTaxonomy` in `45-org-sexpr-gql-candidate-exchange-search.sysml`,
this module proves pure structural-induction theorems over arbitrarily nested
ORG syntax trees and arbitrary-length GQL paths:
1. Recursive S-expression tree selection `selectAstTree` prunes `sourceBlock`
   subtrees (including spoofed children inside code blocks!) at any depth and
   preserves half-open UTF-8 byte bounds `0 ≤ start ≤ stop ≤ docLen`.
2. Multi-hop GQL walk induction `admittedWalk_stays_in_element_space` over
   arbitrary `List (RelationEdge NodeId)` and fuel additivity `walkFuel_append`.
Asynchronous GQL/ASCENT `CandidateExchange` provider arrivals, retry uniqueness,
and generation-advance races belong exclusively to `45-*.qnt`.
-/

namespace OrgSexprGqlCandidateExchange

inductive OrgElementKind where
  | headline
  | propertyDrawer
  | paragraph
  | table
  | link
  | sourceBlock
  deriving DecidableEq, Repr

structure SelectedElement (NodeId : Type) where
  id : NodeId
  kind : OrgElementKind
  byteStart : Nat
  byteEnd : Nat
  deriving DecidableEq, Repr

inductive OrgAstTree (NodeId : Type) where
  | leaf (id : NodeId) (kind : OrgElementKind) (byteStart byteEnd : Nat)
  | section (id : NodeId) (kind : OrgElementKind) (byteStart byteEnd : Nat)
      (children : List (OrgAstTree NodeId))

def validSpan (docByteLen startB endB : Nat) : Bool :=
  decide (startB ≤ endB ∧ endB ≤ docByteLen)

mutual
  def selectAstTree {NodeId : Type} (docByteLen : Nat) :
      OrgAstTree NodeId → List (SelectedElement NodeId)
    | .leaf id kind s e =>
        if kind != .sourceBlock && validSpan docByteLen s e then
          [⟨id, kind, s, e⟩]
        else
          []
    | .section id kind s e children =>
        if kind != .sourceBlock && validSpan docByteLen s e then
          ⟨id, kind, s, e⟩ :: selectAstForest docByteLen children
        else
          -- Pruning a `sourceBlock` section also prunes every nested spoofed child!
          []

  def selectAstForest {NodeId : Type} (docByteLen : Nat) :
      List (OrgAstTree NodeId) → List (SelectedElement NodeId)
    | [] => []
    | t :: ts => selectAstTree docByteLen t ++ selectAstForest docByteLen ts
end

mutual
  theorem selectAstTree_sound {NodeId : Type} (docByteLen : Nat) :
      (t : OrgAstTree NodeId) →
      ∀ x ∈ selectAstTree docByteLen t,
        x.kind ≠ .sourceBlock ∧ x.byteStart ≤ x.byteEnd ∧ x.byteEnd ≤ docByteLen
    | .leaf id kind s e, x, hMem => by
        unfold selectAstTree at hMem
        split at hMem
        · rename_i hCond
          rcases Bool.and_eq_true_iff.mp hCond with ⟨hNotSrc, hSpan⟩
          cases hMem with
          | head =>
              exact ⟨bne_iff_ne.mp hNotSrc, of_decide_eq_true hSpan⟩
          | tail _ hNil => cases hNil
        · cases hMem
    | .section id kind s e children, x, hMem => by
        unfold selectAstTree at hMem
        split at hMem
        · rename_i hCond
          rcases Bool.and_eq_true_iff.mp hCond with ⟨hNotSrc, hSpan⟩
          cases hMem with
          | head =>
              exact ⟨bne_iff_ne.mp hNotSrc, of_decide_eq_true hSpan⟩
          | tail _ hInChildren =>
              exact selectAstForest_sound docByteLen children x hInChildren
        · cases hMem

  theorem selectAstForest_sound {NodeId : Type} (docByteLen : Nat) :
      (ts : List (OrgAstTree NodeId)) →
      ∀ x ∈ selectAstForest docByteLen ts,
        x.kind ≠ .sourceBlock ∧ x.byteStart ≤ x.byteEnd ∧ x.byteEnd ≤ docByteLen
    | [], _, hMem => by cases hMem
    | t :: ts, x, hMem => by
        unfold selectAstForest at hMem
        rw [List.mem_append] at hMem
        cases hMem with
        | inl hHead => exact selectAstTree_sound docByteLen t x hHead
        | inr hTail => exact selectAstForest_sound docByteLen ts x hTail
end

theorem selectAstTree_excludes_source_blocks
    {NodeId : Type} (docByteLen : Nat) (t : OrgAstTree NodeId)
    (x : SelectedElement NodeId) (hMem : x ∈ selectAstTree docByteLen t) :
    x.kind ≠ .sourceBlock :=
  (selectAstTree_sound docByteLen t x hMem).1

theorem selectAstTree_preserves_byte_bounds
    {NodeId : Type} (docByteLen : Nat) (t : OrgAstTree NodeId)
    (x : SelectedElement NodeId) (hMem : x ∈ selectAstTree docByteLen t) :
    x.byteStart ≤ x.byteEnd ∧ x.byteEnd ≤ docByteLen :=
  (selectAstTree_sound docByteLen t x hMem).2

/-! ## Multi-Hop GQL Walk Induction & Fuel Additivity -/

structure RelationEdge (NodeId : Type) where
  src : NodeId
  dst : NodeId
  stepCost : Nat

def EdgeInSpace {NodeId : Type} [DecidableEq NodeId]
    (spaceIds : List NodeId) (e : RelationEdge NodeId) : Prop :=
  e.src ∈ spaceIds ∧ e.dst ∈ spaceIds

def WalkAdmissible {NodeId : Type} [DecidableEq NodeId]
    (spaceIds : List NodeId) : List (RelationEdge NodeId) → Prop
  | [] => True
  | e :: es => EdgeInSpace spaceIds e ∧ WalkAdmissible spaceIds es

theorem admittedWalk_stays_in_element_space
    {NodeId : Type} [DecidableEq NodeId]
    (spaceIds : List NodeId)
    (walk : List (RelationEdge NodeId))
    (hWalk : WalkAdmissible spaceIds walk)
    (e : RelationEdge NodeId)
    (hMem : e ∈ walk) :
    e.src ∈ spaceIds ∧ e.dst ∈ spaceIds := by
  induction walk with
  | nil => cases hMem
  | cons head tail ih =>
      rcases hWalk with ⟨hHead, hTail⟩
      cases hMem with
      | head => exact hHead
      | tail _ hInTail => exact ih hTail hInTail

def walkFuel {NodeId : Type} : List (RelationEdge NodeId) → Nat
  | [] => 0
  | e :: es => e.stepCost + walkFuel es

theorem walkFuel_append {NodeId : Type}
    (w1 w2 : List (RelationEdge NodeId)) :
    walkFuel (w1 ++ w2) = walkFuel w1 + walkFuel w2 := by
  induction w1 with
  | nil => simp [walkFuel]
  | cons head tail ih =>
      simp [walkFuel, ih, Nat.add_assoc]

end OrgSexprGqlCandidateExchange
