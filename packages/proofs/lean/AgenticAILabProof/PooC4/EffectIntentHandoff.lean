-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.RecoveryPolicyAuthorization
import AgenticAILabProof.PooC4.AuthorizedEffectEvidence

namespace AgenticAILabProof.PooC4.EffectIntentHandoff

open AgenticAILabProof.PooC4
open AgenticAILabProof.PooC4.RecoveryPolicyAuthorization

universe u

structure StabilizedEffectIntent (Role : Type u) where
  semanticIdentity : Nat
  intentIdentity : Nat
  role : Role
  authorizationDigest : Nat
  payloadDigest : Nat
  observationDigest : Nat
deriving Repr, DecidableEq

structure IntentAuthorizationBinding
    {Role : Type u}
    (intent : StabilizedEffectIntent Role)
    (capability : RetryCapability) : Prop where
  authorizationMatches :
    intent.authorizationDigest =
      capability.evidence.receipt.decisionDigest
  payloadMatches :
    intent.payloadDigest =
      capability.evidence.receipt.selectedDecision.payloadDigest
  observationMatches :
    intent.observationDigest =
      capability.evidence.receipt.selectedDecision.observationDigest

structure StableIntentHandoff (Role : Type u) where
  intent : StabilizedEffectIntent Role
  capability : RetryCapability
  binding : IntentAuthorizationBinding intent capability
  evidenceFacts : AuthorizedEffectEvidenceFacts
  authorizedEvidence :
    authorizedEffectL2 evidenceFacts

structure EffectExecutionReceipt (Role : Type u) where
  handoff : StableIntentHandoff Role
  semanticIdentity : Nat
  intentIdentity : Nat
  outcomeDigest : Nat
  semanticIdentityMatches :
    semanticIdentity = handoff.intent.semanticIdentity
  intentIdentityMatches :
    intentIdentity = handoff.intent.intentIdentity

structure EffectReconciliation (Role : Type u) where
  execution : EffectExecutionReceipt Role
  observedOutcomeDigest : Nat
  reconciliationEvidenceDigest : Nat

def reconciledSemanticIdentity
    {Role : Type u}
    (reconciliation : EffectReconciliation Role) :
    Nat :=
  reconciliation.execution.semanticIdentity

def reconciledIntentIdentity
    {Role : Type u}
    (reconciliation : EffectReconciliation Role) :
    Nat :=
  reconciliation.execution.intentIdentity

theorem stableHandoffRequiresRetryCapability
    {Role : Type u}
    (handoff : StableIntentHandoff Role) :
    handoff.capability.evidence.receipt.outcome =
        RecoveryDecisionOutcome.committed ∧
      handoff.capability.evidence.receipt.selectedDecision.permitsRetry =
        true := by
  exact
    ⟨handoff.capability.receiptCommitted,
      handoff.capability.selectedDecisionPermitsRetry⟩

theorem stableHandoffRequiresAuthorizedEffectEvidence
    {Role : Type u}
    (handoff : StableIntentHandoff Role) :
    authorizedEffectL2 handoff.evidenceFacts :=
  handoff.authorizedEvidence

theorem stableHandoffBindsIntentToAuthorization
    {Role : Type u}
    (handoff : StableIntentHandoff Role) :
    handoff.intent.authorizationDigest =
        handoff.capability.evidence.receipt.decisionDigest ∧
      handoff.intent.payloadDigest =
        handoff.capability.evidence.receipt.selectedDecision.payloadDigest ∧
      handoff.intent.observationDigest =
        handoff.capability.evidence.receipt.selectedDecision.observationDigest := by
  exact
    ⟨handoff.binding.authorizationMatches,
      handoff.binding.payloadMatches,
      handoff.binding.observationMatches⟩

theorem executionReceiptRefinesStableIntent
    {Role : Type u}
    (receipt : EffectExecutionReceipt Role) :
    receipt.semanticIdentity = receipt.handoff.intent.semanticIdentity ∧
      receipt.intentIdentity = receipt.handoff.intent.intentIdentity := by
  exact
    ⟨receipt.semanticIdentityMatches,
      receipt.intentIdentityMatches⟩

theorem reconciliationPreservesSemanticIdentity
    {Role : Type u}
    (reconciliation : EffectReconciliation Role) :
    reconciledSemanticIdentity reconciliation =
      reconciliation.execution.handoff.intent.semanticIdentity :=
  reconciliation.execution.semanticIdentityMatches

theorem reconciliationPreservesIntentIdentity
    {Role : Type u}
    (reconciliation : EffectReconciliation Role) :
    reconciledIntentIdentity reconciliation =
      reconciliation.execution.handoff.intent.intentIdentity :=
  reconciliation.execution.intentIdentityMatches

inductive IntentLifecycleState where
  | stabilized
  | handedOff
  | committed
  | reconciled
deriving Repr, DecidableEq

inductive IntentLifecycleStep :
    IntentLifecycleState → IntentLifecycleState → Prop where
  | handoff :
      IntentLifecycleStep
        IntentLifecycleState.stabilized
        IntentLifecycleState.handedOff
  | commit :
      IntentLifecycleStep
        IntentLifecycleState.handedOff
        IntentLifecycleState.committed
  | reconcile :
      IntentLifecycleStep
        IntentLifecycleState.committed
        IntentLifecycleState.reconciled

theorem committedIntentCannotReturnToHandoff
    (step :
      IntentLifecycleStep
        IntentLifecycleState.committed
        IntentLifecycleState.handedOff) :
    False := by
  cases step

theorem reconciledIntentIsTerminal
    (target : IntentLifecycleState)
    (step :
      IntentLifecycleStep
        IntentLifecycleState.reconciled
        target) :
    False := by
  cases step

end AgenticAILabProof.PooC4.EffectIntentHandoff
