-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
Slice 50 — Lean Unbounded Algebraic & Structural Preservation Laws ONLY:
Per `FormalVerificationTaxonomy` in
`50-literature-frontier-detour-confinement-and-causal-audit.sysml`, this module
proves universal algebraic and safety-preservation laws for three mechanisms
absorbed from 2025-2026 literature:
1. APPA-inspired Scoped Detour Taint Confinement (recoverable IFC without
   mainline label creep via shape-bounded `attestSchema` or 3-party
   `DeclassificationCert`).
2. NeuroTaint-inspired zero-LLM offline counterfactual causal dependence audit.
3. Deterministic stall / divergence advisory signals carrying strictly zero
   auto-mutation authority.
Concurrent interleavings belong exclusively to `50-*.qnt`.
-/

namespace DetourTaintConfinementAndCausalAudit

/-! ## 1. APPA-Inspired Scoped Detour Taint Confinement -/

structure MainlineContext (Payload : Type) where
  tainted : Bool
  acceptedReceipts : List Payload
  deriving DecidableEq, Repr

structure ConfinedDetour (Payload : Type) where
  tainted : Bool
  egressAllowed : Bool
  schemaAttested : Bool
  declassCertified : Bool
  returnReceipt : Payload
  deriving DecidableEq, Repr

def readUntrustedInsideDetour {Payload : Type}
    (mainline : MainlineContext Payload)
    (detour : ConfinedDetour Payload) :
    MainlineContext Payload × ConfinedDetour Payload :=
  (mainline, { detour with tainted := true, egressAllowed := false })

theorem confinedDetour_isolates_untrusted_read_from_mainline
    {Payload : Type}
    (mainline : MainlineContext Payload)
    (detour : ConfinedDetour Payload) :
    (readUntrustedInsideDetour mainline detour).1.tainted = mainline.tainted ∧
    (readUntrustedInsideDetour mainline detour).2.tainted = true := by
  unfold readUntrustedInsideDetour
  exact ⟨rfl, rfl⟩

def admitDetourEgress {Payload : Type} (detour : ConfinedDetour Payload) : Bool :=
  detour.egressAllowed && !detour.tainted

theorem confinedDetour_no_egress_when_tainted
    {Payload : Type}
    (detour : ConfinedDetour Payload)
    (hTainted : detour.tainted = true) :
    admitDetourEgress detour = false := by
  unfold admitDetourEgress
  simp [hTainted]

def mergeConfinedDetourReturn {Payload : Type}
    (mainline : MainlineContext Payload)
    (detour : ConfinedDetour Payload) :
    Option (MainlineContext Payload) :=
  if !detour.tainted || detour.schemaAttested || detour.declassCertified then
    some { mainline with acceptedReceipts := mainline.acceptedReceipts ++ [detour.returnReceipt] }
  else
    none

theorem unattestedDetourReturn_rejected
    {Payload : Type}
    (mainline : MainlineContext Payload)
    (detour : ConfinedDetour Payload)
    (hTainted : detour.tainted = true)
    (hNoSchema : detour.schemaAttested = false)
    (hNoCert : detour.declassCertified = false) :
    mergeConfinedDetourReturn mainline detour = none := by
  unfold mergeConfinedDetourReturn
  simp [hTainted, hNoSchema, hNoCert]

theorem attestedDetourReturn_preserves_mainline_taint_without_label_creep
    {Payload : Type}
    (mainline nextMainline : MainlineContext Payload)
    (detour : ConfinedDetour Payload)
    (hMerged : mergeConfinedDetourReturn mainline detour = some nextMainline) :
    nextMainline.tainted = mainline.tainted ∧
    detour.returnReceipt ∈ nextMainline.acceptedReceipts := by
  unfold mergeConfinedDetourReturn at hMerged
  split at hMerged
  · injection hMerged with hEq
    subst hEq
    refine ⟨rfl, ?_⟩
    rw [List.mem_append]
    exact Or.inr (List.mem_singleton.mpr rfl)
  · contradiction

/-! ## 2. NeuroTaint-Inspired Zero-LLM Offline Causal Counterfactual Audit -/

def auditCausalDependence {Decision : Type} [DecidableEq Decision]
    (decisionWithSecret decisionWithoutSecret : Decision)
    (declassCertified : Bool) : Bool :=
  decide (decisionWithSecret ≠ decisionWithoutSecret) && !declassCertified

theorem causalAudit_flags_unendorsed_branch_flip
    {Decision : Type} [DecidableEq Decision]
    (dWith dWithout : Decision)
    (hFlip : dWith ≠ dWithout) :
    auditCausalDependence dWith dWithout false = true := by
  unfold auditCausalDependence
  simp [hFlip]

theorem causalAudit_clean_when_counterfactual_invariant
    {Decision : Type} [DecidableEq Decision]
    (d : Decision) (cert : Bool) :
    auditCausalDependence d d cert = false := by
  unfold auditCausalDependence
  simp

theorem causalAudit_clean_when_declassification_certified
    {Decision : Type} [DecidableEq Decision]
    (dWith dWithout : Decision) :
    auditCausalDependence dWith dWithout true = false := by
  unfold auditCausalDependence
  simp

/-! ## 3. Deterministic Stall & Divergence Advisory Signal (Zero Auto-Mutation) -/

structure StallAdvisory where
  suggestParkOrCancel : Bool
  authorizesAutoMutation : Bool
  deriving DecidableEq, Repr

def evaluateStallAdvisory
    (repeatedFailureCount consecutiveInvalidations threshold : Nat) : StallAdvisory :=
  let triggered := decide (threshold ≤ repeatedFailureCount ∨ threshold ≤ consecutiveInvalidations)
  { suggestParkOrCancel := triggered, authorizesAutoMutation := false }

theorem advisoryTrigger_fires_on_stall_threshold
    (rep inv thr : Nat)
    (hHit : thr ≤ rep ∨ thr ≤ inv) :
    (evaluateStallAdvisory rep inv thr).suggestParkOrCancel = true := by
  unfold evaluateStallAdvisory
  simp [hHit]

theorem advisoryTrigger_never_authorizes_auto_mutation
    (rep inv thr : Nat) :
    (evaluateStallAdvisory rep inv thr).authorizesAutoMutation = false := by
  rfl

end DetourTaintConfinementAndCausalAudit
