-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Cedar.Thm.Authorization
import YuanxuProof.ProfileComposition.BundleIdentity

namespace AgenticAILabProof.PooC4.CedarDualEngineArbitration

/-!
Risk-tiered Cedar arbitration.

Elevated authority requires a per-request Lean/Rust witness.  Ordinary
authority may use a pinned DRT conformance receipt and a bounded Lean shadow,
but that receipt must never claim that both engines witnessed the request.
-/

inductive AuthorityRisk where
  | ordinary
  | elevated
deriving DecidableEq, Repr

inductive ArbitrationMode where
  | strictLockstep
  | rustWithLeanShadow
deriving DecidableEq, Repr

def requiredMode : AuthorityRisk → ArbitrationMode
  | .ordinary => .rustWithLeanShadow
  | .elevated => .strictLockstep

inductive CedarDecision where
  | allow
  | deny
  | indeterminate
deriving DecidableEq, Repr

structure AuthorizationOutcome (PolicyIdentity ErrorClass : Type) where
  decision : CedarDecision
  determiningPermits : List PolicyIdentity
  determiningForbids : List PolicyIdentity
  errorClass : Option ErrorClass
deriving DecidableEq, Repr

class AuthorizationDecisionProjection (Outcome : Type) where
  decision : Outcome → CedarDecision

instance
    {PolicyIdentity ErrorClass : Type} :
    AuthorizationDecisionProjection
      (AuthorizationOutcome PolicyIdentity ErrorClass) where
  decision outcome := outcome.decision

inductive EngineRun (Outcome : Type) where
  | completed (outcome : Outcome)
  | timeout
  | unavailable
deriving DecidableEq, Repr

inductive ShadowRun (Outcome : Type) where
  | notSelected
  | completed (outcome : Outcome)
  | timeout
  | unavailable
deriving DecidableEq, Repr

inductive ArbitrationEvidence (Outcome : Type) where
  | strict (lean : EngineRun Outcome) (rust : EngineRun Outcome)
  | conformanceBacked
      (drtAdmitted : Bool)
      (rust : EngineRun Outcome)
      (leanShadow : ShadowRun Outcome)
deriving DecidableEq, Repr

inductive AuthorityDecision where
  | allow
  | deny
deriving DecidableEq, Repr

inductive ActivationState where
  | active
  | suspended
deriving DecidableEq, Repr

inductive ReceiptKind where
  | dualWitnessed
  | conformanceBacked
  | engineDisagreement
  | engineTimeout
  | engineUnavailable
  | missingConformance
  | invalidMode
  | indeterminate
deriving DecidableEq, Repr

inductive ShadowEvidenceState where
  | notApplicable
  | notSelected
  | agreed
  | timeout
  | unavailable
deriving DecidableEq, Repr

structure ArbitrationResult where
  authority : AuthorityDecision
  activation : ActivationState
  receipt : ReceiptKind
  perRequestDualWitness : Bool
  shadowEvidence : ShadowEvidenceState
deriving DecidableEq, Repr

def failClosed
    (receipt : ReceiptKind)
    (shadowEvidence : ShadowEvidenceState := .notApplicable) :
    ArbitrationResult :=
  { authority := .deny
    activation := .suspended
    receipt := receipt
    perRequestDualWitness := false
    shadowEvidence := shadowEvidence }

def projectOutcome
    (receipt : ReceiptKind)
    (perRequestDualWitness : Bool)
    (shadowEvidence : ShadowEvidenceState)
    {Outcome : Type}
    [AuthorizationDecisionProjection Outcome]
    (outcome : Outcome) :
    ArbitrationResult :=
  match AuthorizationDecisionProjection.decision outcome with
  | .allow =>
      { authority := .allow
        activation := .active
        receipt := receipt
        perRequestDualWitness := perRequestDualWitness
        shadowEvidence := shadowEvidence }
  | .deny =>
      { authority := .deny
        activation := .active
        receipt := receipt
        perRequestDualWitness := perRequestDualWitness
        shadowEvidence := shadowEvidence }
  | .indeterminate =>
      failClosed .indeterminate shadowEvidence

def arbitrateStrict
    {Outcome : Type}
    [DecidableEq Outcome]
    [AuthorizationDecisionProjection Outcome]
    (lean rust : EngineRun Outcome) :
    ArbitrationResult :=
  match lean, rust with
  | .completed leanOutcome, .completed rustOutcome =>
      if leanOutcome = rustOutcome then
        projectOutcome .dualWitnessed true .agreed leanOutcome
      else
        failClosed .engineDisagreement
  | .timeout, _ | _, .timeout =>
      failClosed .engineTimeout
  | .unavailable, _ | _, .unavailable =>
      failClosed .engineUnavailable

def arbitrateConformanceBacked
    {Outcome : Type}
    [DecidableEq Outcome]
    [AuthorizationDecisionProjection Outcome]
    (drtAdmitted : Bool)
    (rust : EngineRun Outcome)
    (leanShadow : ShadowRun Outcome) :
    ArbitrationResult :=
  if ¬drtAdmitted then
    failClosed .missingConformance
  else
    match rust with
    | .timeout => failClosed .engineTimeout
    | .unavailable => failClosed .engineUnavailable
    | .completed rustOutcome =>
        match leanShadow with
        | .notSelected =>
            projectOutcome .conformanceBacked false .notSelected rustOutcome
        | .timeout =>
            projectOutcome .conformanceBacked false .timeout rustOutcome
        | .unavailable =>
            projectOutcome .conformanceBacked false .unavailable rustOutcome
        | .completed leanOutcome =>
            if leanOutcome = rustOutcome then
              projectOutcome .dualWitnessed true .agreed rustOutcome
            else
              failClosed .engineDisagreement

def arbitrate
    {Outcome : Type}
    [DecidableEq Outcome]
    [AuthorizationDecisionProjection Outcome]
    (risk : AuthorityRisk)
    (evidence : ArbitrationEvidence Outcome) :
    ArbitrationResult :=
  match risk, evidence with
  | .elevated, .strict lean rust =>
      arbitrateStrict lean rust
  | .elevated, .conformanceBacked _ _ _ =>
      failClosed .invalidMode
  | .ordinary, .strict lean rust =>
      arbitrateStrict lean rust
  | .ordinary, .conformanceBacked drtAdmitted rust leanShadow =>
      arbitrateConformanceBacked drtAdmitted rust leanShadow

theorem elevated_requires_strict_lockstep :
    requiredMode .elevated = .strictLockstep := by
  rfl

theorem ordinary_selects_conformance_backed_shadow :
    requiredMode .ordinary = .rustWithLeanShadow := by
  rfl

theorem elevated_rejects_conformance_only
    {PolicyIdentity ErrorClass : Type}
    [DecidableEq PolicyIdentity]
    [DecidableEq ErrorClass]
    (drtAdmitted : Bool)
    (rust : EngineRun (AuthorizationOutcome PolicyIdentity ErrorClass))
    (shadow : ShadowRun (AuthorizationOutcome PolicyIdentity ErrorClass)) :
    arbitrate .elevated
        (.conformanceBacked drtAdmitted rust shadow) =
      failClosed .invalidMode := by
  rfl

theorem strict_lean_timeout_fails_closed
    {PolicyIdentity ErrorClass : Type}
    [DecidableEq PolicyIdentity]
    [DecidableEq ErrorClass]
    (rust : EngineRun (AuthorizationOutcome PolicyIdentity ErrorClass)) :
    arbitrateStrict (.timeout) rust = failClosed .engineTimeout := by
  cases rust <;> rfl

theorem strict_rust_timeout_fails_closed
    {PolicyIdentity ErrorClass : Type}
    [DecidableEq PolicyIdentity]
    [DecidableEq ErrorClass]
    (lean : EngineRun (AuthorizationOutcome PolicyIdentity ErrorClass)) :
    arbitrateStrict lean (.timeout) = failClosed .engineTimeout := by
  cases lean <;> rfl

theorem strict_unavailable_with_completed_peer_fails_closed
    {PolicyIdentity ErrorClass : Type}
    [DecidableEq PolicyIdentity]
    [DecidableEq ErrorClass]
    (rustOutcome : AuthorizationOutcome PolicyIdentity ErrorClass) :
    arbitrateStrict (.unavailable) (.completed rustOutcome) =
      failClosed .engineUnavailable := by
  rfl

theorem strict_disagreement_fails_closed
    {PolicyIdentity ErrorClass : Type}
    [DecidableEq PolicyIdentity]
    [DecidableEq ErrorClass]
    (leanOutcome rustOutcome :
      AuthorizationOutcome PolicyIdentity ErrorClass)
    (different : leanOutcome ≠ rustOutcome) :
    arbitrateStrict
        (.completed leanOutcome)
        (.completed rustOutcome) =
      failClosed .engineDisagreement := by
  simp [arbitrateStrict, different]

theorem strict_agreement_is_dual_witnessed
    {PolicyIdentity ErrorClass : Type}
    [DecidableEq PolicyIdentity]
    [DecidableEq ErrorClass]
    (outcome : AuthorizationOutcome PolicyIdentity ErrorClass) :
    arbitrateStrict (.completed outcome) (.completed outcome) =
      projectOutcome .dualWitnessed true .agreed outcome := by
  simp [arbitrateStrict]

theorem missing_drt_conformance_fails_closed
    {PolicyIdentity ErrorClass : Type}
    [DecidableEq PolicyIdentity]
    [DecidableEq ErrorClass]
    (rust : EngineRun (AuthorizationOutcome PolicyIdentity ErrorClass))
    (shadow : ShadowRun (AuthorizationOutcome PolicyIdentity ErrorClass)) :
    arbitrateConformanceBacked false rust shadow =
      failClosed .missingConformance := by
  rfl

theorem unselected_shadow_is_not_dual_witnessed
    {PolicyIdentity ErrorClass : Type}
    [DecidableEq PolicyIdentity]
    [DecidableEq ErrorClass]
    (outcome : AuthorizationOutcome PolicyIdentity ErrorClass) :
    arbitrateConformanceBacked true
        (.completed outcome)
        (.notSelected) =
      projectOutcome .conformanceBacked false .notSelected outcome := by
  rfl

theorem timed_out_shadow_is_not_dual_witnessed
    {PolicyIdentity ErrorClass : Type}
    [DecidableEq PolicyIdentity]
    [DecidableEq ErrorClass]
    (outcome : AuthorizationOutcome PolicyIdentity ErrorClass) :
    arbitrateConformanceBacked true
        (.completed outcome)
        (.timeout) =
      projectOutcome .conformanceBacked false .timeout outcome := by
  rfl

theorem shadow_disagreement_fails_closed
    {PolicyIdentity ErrorClass : Type}
    [DecidableEq PolicyIdentity]
    [DecidableEq ErrorClass]
    (rustOutcome leanOutcome :
      AuthorizationOutcome PolicyIdentity ErrorClass)
    (different : leanOutcome ≠ rustOutcome) :
    arbitrateConformanceBacked true
        (.completed rustOutcome)
        (.completed leanOutcome) =
      failClosed .engineDisagreement := by
  simp [arbitrateConformanceBacked, different]

theorem shadow_agreement_is_dual_witnessed
    {PolicyIdentity ErrorClass : Type}
    [DecidableEq PolicyIdentity]
    [DecidableEq ErrorClass]
    (outcome : AuthorizationOutcome PolicyIdentity ErrorClass) :
    arbitrateConformanceBacked true
        (.completed outcome)
        (.completed outcome) =
      projectOutcome .dualWitnessed true .agreed outcome := by
  simp [arbitrateConformanceBacked]

theorem conformance_receipt_never_claims_per_request_dual_witness
    (shadowEvidence : ShadowEvidenceState)
    {PolicyIdentity ErrorClass : Type}
    (outcome : AuthorizationOutcome PolicyIdentity ErrorClass) :
    (projectOutcome .conformanceBacked false shadowEvidence outcome).perRequestDualWitness =
      false := by
  rcases outcome with ⟨decision, permits, forbids, errorClass⟩
  cases decision <;> rfl

theorem indeterminate_never_grants_authority
    (receipt : ReceiptKind)
    (dualWitness : Bool)
    (shadowEvidence : ShadowEvidenceState)
    {PolicyIdentity ErrorClass : Type}
    (permits forbids : List PolicyIdentity)
    (errorClass : Option ErrorClass) :
    (projectOutcome receipt dualWitness shadowEvidence
      (show AuthorizationOutcome PolicyIdentity ErrorClass from
        { decision := .indeterminate
          determiningPermits := permits
          determiningForbids := forbids
          errorClass := errorClass })).authority = .deny := by
  rfl

end AgenticAILabProof.PooC4.CedarDualEngineArbitration
