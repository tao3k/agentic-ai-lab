-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
Slice 41 — Lean Unbounded Structural Induction & Map-Frame Laws ONLY:
Per `FormalVerificationTaxonomy` in `41-epistemic-consolidation-governance.sysml`,
this module proves pure universal properties over unbounded lists and catalogs:
1. Cost additivity (`sumHypothesisCost_append`), universal defeater-kernel
   preservation (`admitted_projection_preserves_every_active_defeater`), and
   fail-closed sub-kernel budget refusal (`budget_below_kernel_refuses_projection`).
2. Soundness of `omittedLiveIds` over arbitrary `List Hypothesis`
   (`omitted_live_competitor_forces_receipt_and_non_exhaustive`).
3. Functional retraction frame law (`retract_frame_preserves_unrelated_insights`)
   over unbounded insight catalogs: retracting premise `p` withdraws dependent
   entries while leaving every disjoint insight strictly identical.
Cross-session consolidation, retraction and ORG-promotion races live in `41-*.qnt`.
-/

namespace ContextEpistemicConsolidationGovernance

structure Hypothesis (HId DId : Type) where
  id : HId
  undefeated : Bool
  cost : Nat
  activeDefeaters : List DId

structure OmittedAlternativesReceipt (HId : Type) where
  omittedIds : List HId
  deriving Repr

structure AdmittedProjection (HId DId RMeta : Type) where
  restrictions : RMeta
  retainedHypotheses : List (Hypothesis HId DId)
  retainedDefeaters : List DId
  omissionReceipt : Option (OmittedAlternativesReceipt HId)
  claimsExhaustive : Bool
  consumedCost : Nat

inductive ProjectionOutcome (HId DId RMeta : Type) where
  | refusedOverBudget (requiredCost budget : Nat)
  | admitted (view : AdmittedProjection HId DId RMeta)

def collectDefeaters {HId DId : Type} : List (Hypothesis HId DId) → List DId
  | [] => []
  | h :: hs => h.activeDefeaters ++ collectDefeaters hs

def sumHypothesisCost {HId DId : Type} : List (Hypothesis HId DId) → Nat
  | [] => 0
  | h :: hs => h.cost + sumHypothesisCost hs

theorem sumHypothesisCost_append {HId DId : Type}
    (xs ys : List (Hypothesis HId DId)) :
    sumHypothesisCost (xs ++ ys) = sumHypothesisCost xs + sumHypothesisCost ys := by
  induction xs with
  | nil => simp [sumHypothesisCost]
  | cons x tail ih =>
      simp [sumHypothesisCost, ih, Nat.add_assoc]

def omittedLiveIds {HId DId : Type} [DecidableEq HId]
    (selectedIds : List HId) : List (Hypothesis HId DId) → List HId
  | [] => []
  | h :: hs =>
      if h.undefeated && !(selectedIds.contains h.id) then
        h.id :: omittedLiveIds selectedIds hs
      else
        omittedLiveIds selectedIds hs

def projectGoverned {HId DId RMeta : Type} [DecidableEq HId]
    (restrictions : RMeta)
    (restrictionCost : Nat)
    (allHypotheses selected : List (Hypothesis HId DId))
    (budget : Nat) : ProjectionOutcome HId DId RMeta :=
  let defs := collectDefeaters selected
  let totalCost := restrictionCost + sumHypothesisCost selected + defs.length
  if totalCost ≤ budget then
    let selIds := selected.map (·.id)
    let omitted := omittedLiveIds selIds allHypotheses
    match omitted with
    | [] =>
        .admitted {
          restrictions := restrictions
          retainedHypotheses := selected
          retainedDefeaters := defs
          omissionReceipt := none
          claimsExhaustive := true
          consumedCost := totalCost
        }
    | _ :: _ =>
        .admitted {
          restrictions := restrictions
          retainedHypotheses := selected
          retainedDefeaters := defs
          omissionReceipt := some ⟨omitted⟩
          claimsExhaustive := false
          consumedCost := totalCost
        }
  else
    .refusedOverBudget totalCost budget

theorem mem_collectDefeaters_of_mem_selected {HId DId : Type}
    {h : Hypothesis HId DId} {selected : List (Hypothesis HId DId)} {d : DId}
    (hSel : h ∈ selected) (hDef : d ∈ h.activeDefeaters) :
    d ∈ collectDefeaters selected := by
  induction selected with
  | nil => cases hSel
  | cons head tail ih =>
      simp only [collectDefeaters, List.mem_append]
      cases hSel with
      | head => exact Or.inl hDef
      | tail _ hTail => exact Or.inr (ih hTail)

theorem admitted_projection_respects_budget_and_restrictions
    {HId DId RMeta : Type} [DecidableEq HId]
    (restrictions : RMeta) (restrictionCost : Nat)
    (allH selected : List (Hypothesis HId DId)) (budget : Nat)
    (view : AdmittedProjection HId DId RMeta)
    (hAdmit : projectGoverned restrictions restrictionCost allH selected budget = .admitted view) :
    view.consumedCost ≤ budget ∧ view.restrictions = restrictions := by
  unfold projectGoverned at hAdmit
  dsimp at hAdmit
  split at hAdmit
  · rename_i hBudget
    split at hAdmit <;> injection hAdmit with hView <;> subst hView <;> exact ⟨hBudget, rfl⟩
  · cases hAdmit

theorem admitted_projection_preserves_every_active_defeater
    {HId DId RMeta : Type} [DecidableEq HId]
    (restrictions : RMeta) (restrictionCost : Nat)
    (allH selected : List (Hypothesis HId DId)) (budget : Nat)
    (view : AdmittedProjection HId DId RMeta)
    (hAdmit : projectGoverned restrictions restrictionCost allH selected budget = .admitted view)
    (h : Hypothesis HId DId) (d : DId)
    (hRetained : h ∈ view.retainedHypotheses)
    (hActive : d ∈ h.activeDefeaters) :
    d ∈ view.retainedDefeaters := by
  unfold projectGoverned at hAdmit
  dsimp at hAdmit
  split at hAdmit
  · split at hAdmit <;>
      injection hAdmit with hView <;>
      subst hView <;>
      exact mem_collectDefeaters_of_mem_selected hRetained hActive
  · cases hAdmit

theorem budget_below_kernel_refuses_projection
    {HId DId RMeta : Type} [DecidableEq HId]
    (restrictions : RMeta) (restrictionCost : Nat)
    (allH selected : List (Hypothesis HId DId)) (budget : Nat)
    (hInsufficient : budget < restrictionCost + sumHypothesisCost selected + (collectDefeaters selected).length) :
    ∃ req, projectGoverned restrictions restrictionCost allH selected budget = .refusedOverBudget req budget := by
  unfold projectGoverned
  dsimp
  split
  · rename_i hLe
    exact False.elim ((Nat.not_le_of_gt hInsufficient) hLe)
  · exact ⟨_, rfl⟩

theorem mem_omittedLiveIds {HId DId : Type} [DecidableEq HId]
    {selectedIds : List HId} {allH : List (Hypothesis HId DId)} {cand : Hypothesis HId DId}
    (hInAll : cand ∈ allH)
    (hLive : cand.undefeated = true)
    (hOmitted : selectedIds.contains cand.id = false) :
    cand.id ∈ omittedLiveIds selectedIds allH := by
  induction allH with
  | nil => cases hInAll
  | cons head tail ih =>
      unfold omittedLiveIds
      cases hInAll with
      | head =>
          rw [hLive, hOmitted]
          exact List.Mem.head _
      | tail _ hTail =>
          split
          · exact List.Mem.tail _ (ih hTail)
          · exact ih hTail

theorem omitted_live_competitor_forces_receipt_and_non_exhaustive
    {HId DId RMeta : Type} [DecidableEq HId]
    (restrictions : RMeta) (restrictionCost : Nat)
    (allH selected : List (Hypothesis HId DId)) (budget : Nat)
    (view : AdmittedProjection HId DId RMeta)
    (cand : Hypothesis HId DId)
    (hAdmit : projectGoverned restrictions restrictionCost allH selected budget = .admitted view)
    (hInAll : cand ∈ allH)
    (hLive : cand.undefeated = true)
    (hNotSelected : (selected.map (·.id)).contains cand.id = false) :
    view.claimsExhaustive = false ∧
      ∃ receipt, view.omissionReceipt = some receipt ∧ cand.id ∈ receipt.omittedIds := by
  have hMemOmit : cand.id ∈ omittedLiveIds (selected.map (·.id)) allH :=
    mem_omittedLiveIds hInAll hLive hNotSelected
  unfold projectGoverned at hAdmit
  dsimp at hAdmit
  split at hAdmit
  · generalize hList : omittedLiveIds (selected.map (·.id)) allH = omitted at hAdmit hMemOmit
    cases omitted with
    | nil => cases hMemOmit
    | cons first rest =>
        injection hAdmit with hView
        subst hView
        exact ⟨rfl, ⟨⟨first :: rest⟩, rfl, hMemOmit⟩⟩
  · cases hAdmit

/-! ## Pure Catalog Retraction Map-Frame Law (Historical Preservation + Non-Interference) -/

structure CatalogEntry (PremiseId Payload : Type) where
  payload : Payload
  premises : List PremiseId
  active : Bool

def retractPremiseInCatalog {InsightId PremiseId Payload : Type}
    [DecidableEq PremiseId]
    (cat : InsightId → Option (CatalogEntry PremiseId Payload))
    (retracted : PremiseId) : InsightId → Option (CatalogEntry PremiseId Payload) :=
  fun k =>
    match cat k with
    | none => none
    | some entry =>
        if entry.premises.contains retracted then
          some { entry with active := false }
        else
          some entry

theorem retract_deactivates_dependent_insight_preserving_payload
    {InsightId PremiseId Payload : Type} [DecidableEq PremiseId]
    (cat : InsightId → Option (CatalogEntry PremiseId Payload))
    (k : InsightId) (entry : CatalogEntry PremiseId Payload) (p : PremiseId)
    (hPresent : cat k = some entry)
    (hDep : p ∈ entry.premises) :
    retractPremiseInCatalog cat p k = some { entry with active := false } := by
  simp [retractPremiseInCatalog, hPresent, hDep]

theorem retract_frame_preserves_unrelated_insights
    {InsightId PremiseId Payload : Type} [DecidableEq PremiseId]
    (cat : InsightId → Option (CatalogEntry PremiseId Payload))
    (k : InsightId) (entry : CatalogEntry PremiseId Payload) (p : PremiseId)
    (hPresent : cat k = some entry)
    (hDisjoint : p ∉ entry.premises) :
    retractPremiseInCatalog cat p k = cat k := by
  simp [retractPremiseInCatalog, hPresent, hDisjoint]

end ContextEpistemicConsolidationGovernance
