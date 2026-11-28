-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
Slice 46 — Lean Unbounded Capability-Intersection Algebra & Journal Frame Laws ONLY:
Per `FormalVerificationTaxonomy` in `46-durable-agenda-session-sandbox-governance.sysml`,
this module proves pure universal set/boolean algebra and map-frame theorems:
1. Sandbox capability intersection (`effectiveCap_idem`, `effectiveCap_comm`,
   `effectiveCap_monotone_ctx`) over arbitrary `Cap : Type`.
2. Universal Lethal-Trifecta elimination (`noEgressProfile_eliminates_lethal_trifecta`):
   composing any `ContextExposure` with a `noEgress` Sandbox profile makes
   `LethalTrifectaPresent` algebraically uninhabitable.
3. Per-recipient Attempt journal map-frame non-interference
   (`recordOutcome_frame_preserves_other_recipients`).
Asynchronous Agenda wakes, mid-flight grant revocations, crash-before-receipt
uncertainty intervals, and late provider receipts belong exclusively to `46-*.qnt`.
-/

namespace DurableAgendaSessionSandboxGovernance

def EffectiveCap {Cap : Type} (ctxAllows sbAllows : Cap → Prop) : Cap → Prop :=
  fun c => ctxAllows c ∧ sbAllows c

theorem effectiveCap_idem {Cap : Type} (p : Cap → Prop) (c : Cap) :
    EffectiveCap p p c ↔ p c :=
  ⟨fun h => h.1, fun h => ⟨h, h⟩⟩

theorem effectiveCap_comm {Cap : Type} (a b : Cap → Prop) (c : Cap) :
    EffectiveCap a b c ↔ EffectiveCap b a c :=
  And.comm

theorem effectiveCap_subset_both {Cap : Type} (ctxAllows sbAllows : Cap → Prop) (c : Cap)
    (hEff : EffectiveCap ctxAllows sbAllows c) :
    ctxAllows c ∧ sbAllows c :=
  hEff

theorem effectiveCap_monotone_ctx {Cap : Type}
    (tighterCtx widerCtx sbAllows : Cap → Prop)
    (hTighter : ∀ c, tighterCtx c → widerCtx c)
    (c : Cap)
    (hEff : EffectiveCap tighterCtx sbAllows c) :
    EffectiveCap widerCtx sbAllows c :=
  ⟨hTighter c hEff.1, hEff.2⟩

/-! ## Algebraic Elimination of the Lethal Trifecta -/

structure ContextExposure where
  hasUntrustedExternalInput : Bool
  hasRestrictedPrivateData : Bool
  hasIndependentEgressEndorsement : Bool

structure SandboxNetworkPolicy where
  allowsExternalEgress : Bool

def noEgressSandbox : SandboxNetworkPolicy :=
  { allowsExternalEgress := false }

def LethalTrifectaPresent (ctx : ContextExposure) (net : SandboxNetworkPolicy) : Prop :=
  ctx.hasUntrustedExternalInput = true ∧
    ctx.hasRestrictedPrivateData = true ∧
    net.allowsExternalEgress = true ∧
    ctx.hasIndependentEgressEndorsement = false

theorem noEgressProfile_eliminates_lethal_trifecta (ctx : ContextExposure) :
    ¬ LethalTrifectaPresent ctx noEgressSandbox := by
  intro hTri
  have hFalse : false = true := hTri.2.2.1
  cases hFalse

/-! ## Per-Recipient Attempt Journal Frame Non-Interference -/

inductive HandoffAssessment where
  | unstarted
  | unknownAfterCrash
  | providerAccepted
  | attestedNoSend
  deriving DecidableEq, Repr

def recordRecipientOutcome {Recipient : Type} [DecidableEq Recipient]
    (journal : Recipient → HandoffAssessment)
    (target : Recipient)
    (outcome : HandoffAssessment) : Recipient → HandoffAssessment :=
  fun r => if r = target then outcome else journal r

theorem recordOutcome_updates_target {Recipient : Type} [DecidableEq Recipient]
    (journal : Recipient → HandoffAssessment)
    (target : Recipient) (outcome : HandoffAssessment) :
    recordRecipientOutcome journal target outcome target = outcome := by
  simp [recordRecipientOutcome]

theorem recordOutcome_frame_preserves_other_recipients
    {Recipient : Type} [DecidableEq Recipient]
    (journal : Recipient → HandoffAssessment)
    (target other : Recipient)
    (outcome : HandoffAssessment)
    (hDiff : other ≠ target) :
    recordRecipientOutcome journal target outcome other = journal other := by
  simp [recordRecipientOutcome, hDiff]

end DurableAgendaSessionSandboxGovernance
