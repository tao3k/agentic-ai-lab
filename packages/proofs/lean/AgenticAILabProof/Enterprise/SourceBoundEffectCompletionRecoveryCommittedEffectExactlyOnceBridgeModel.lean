-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.PromotionTransactionAtomicity

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCommittedEffectExactlyOnceBridgeModel

abbrev EffectId := String
abbrev TransactionId := String
abbrev RegistryDigest := String

inductive CommitOutcome
  | committed
  | duplicate
  | rejected
  | rolledBack
  deriving DecidableEq, Repr

structure EffectExecutionEvent where
  ownerSubject : String
  effectId : EffectId
  deriving DecidableEq, Repr

structure EffectExecutionTraceReceipt where
  transactionId : TransactionId
  fenceToken : Nat
  registryDigest : RegistryDigest
  events : List EffectExecutionEvent
  deriving DecidableEq, Repr

def traceRespectsUniverse
    (effectUniverse : List EffectId)
    (trace : List EffectExecutionEvent) : Prop :=
  ∀ event ∈ trace, event.effectId ∈ effectUniverse

def traceCoversUniverse
    (effectUniverse : List EffectId)
    (trace : List EffectExecutionEvent) : Prop :=
  ∀ effectId ∈ effectUniverse, ∃ event ∈ trace, event.effectId = effectId

def effectOccurrenceCount
    (effectId : EffectId)
    (trace : List EffectExecutionEvent) : Nat :=
  (trace.map EffectExecutionEvent.effectId).count effectId

def traceExecutesUniverseExactlyOnce
    (effectUniverse : List EffectId)
    (trace : List EffectExecutionEvent) : Prop :=
  effectUniverse.Nodup ∧
    traceRespectsUniverse effectUniverse trace ∧
    ∀ effectId ∈ effectUniverse, effectOccurrenceCount effectId trace = 1

structure CommittedEffectExactlyOnceBound
    (outcome : CommitOutcome)
    (effectUniverse : List EffectId)
    (receipt : EffectExecutionTraceReceipt) : Prop where
  committed :
    outcome = CommitOutcome.committed
  exactlyOnce :
    traceExecutesUniverseExactlyOnce effectUniverse receipt.events

def paymentEvent : EffectExecutionEvent :=
  { ownerSubject := "billing", effectId := "payment" }

def messageEvent : EffectExecutionEvent :=
  { ownerSubject := "messaging", effectId := "message" }

def completeUniverse : List EffectId :=
  ["payment", "message"]

def omittedMessageTrace : List EffectExecutionEvent :=
  [paymentEvent]

def duplicatedPaymentTrace : List EffectExecutionEvent :=
  [paymentEvent, paymentEvent, messageEvent]

theorem declaredTraceDoesNotProveUniverseCoverage :
    traceRespectsUniverse completeUniverse omittedMessageTrace ∧
      ¬ traceCoversUniverse completeUniverse omittedMessageTrace := by
  constructor
  · intro event eventInTrace
    simp [omittedMessageTrace] at eventInTrace
    subst event
    simp [paymentEvent, completeUniverse]
  · intro covers
    obtain ⟨event, eventInTrace, effectMatches⟩ :=
      covers "message" (by simp [completeUniverse])
    simp [omittedMessageTrace] at eventInTrace
    subst event
    simp [paymentEvent] at effectMatches

theorem declaredTraceDoesNotProveAtMostOnce :
    traceRespectsUniverse completeUniverse duplicatedPaymentTrace ∧
      effectOccurrenceCount "payment" duplicatedPaymentTrace = 2 := by
  constructor
  · simp [traceRespectsUniverse, duplicatedPaymentTrace, paymentEvent,
      messageEvent, completeUniverse]
  · simp [effectOccurrenceCount, duplicatedPaymentTrace, paymentEvent, messageEvent]

theorem matchingReceiptEnvelopeDoesNotProveExactlyOnce :
    let receipt : EffectExecutionTraceReceipt :=
      { transactionId := "tx-7"
        fenceToken := 11
        registryDigest := "registry-a"
        events := omittedMessageTrace }
    receipt.transactionId = "tx-7" ∧
      receipt.fenceToken = 11 ∧
      receipt.registryDigest = "registry-a" ∧
      ¬ traceExecutesUniverseExactlyOnce completeUniverse receipt.events := by
  dsimp
  refine ⟨rfl, rfl, rfl, ?_⟩
  intro exactlyOnce
  have messageOccurs :=
    exactlyOnce.2.2 "message" (by simp [completeUniverse])
  simp [effectOccurrenceCount, omittedMessageTrace, paymentEvent] at messageOccurs

theorem committedOutcomeDoesNotProvideExecutionTrace :
    ∃ outcome : CommitOutcome,
      outcome = CommitOutcome.committed := by
  exact ⟨CommitOutcome.committed, rfl⟩

theorem duplicateOutcomeIsNotCommitted :
    CommitOutcome.duplicate ≠ CommitOutcome.committed := by
  decide

theorem exactlyOnceClosureProvidesUniverseCoverage
    (effectUniverse : List EffectId)
    (trace : List EffectExecutionEvent)
    (closed : traceExecutesUniverseExactlyOnce effectUniverse trace) :
    traceCoversUniverse effectUniverse trace := by
  intro effectId effectInUniverse
  have countIsOne := closed.2.2 effectId effectInUniverse
  have countPositive : 0 < effectOccurrenceCount effectId trace := by
    simp [countIsOne]
  have memberInMappedTrace :
      effectId ∈ trace.map EffectExecutionEvent.effectId := by
    simpa [effectOccurrenceCount] using
      (List.count_pos_iff.mp countPositive)
  obtain ⟨event, eventInTrace, effectMatches⟩ :=
    List.mem_map.mp memberInMappedTrace
  exact ⟨event, eventInTrace, effectMatches⟩

theorem closedCommittedBridgeProvidesExactlyOnce
    (effectUniverse : List EffectId)
    (receipt : EffectExecutionTraceReceipt)
    (closed :
      CommittedEffectExactlyOnceBound
        CommitOutcome.committed
        effectUniverse
        receipt) :
    ∀ effectId ∈ effectUniverse,
      effectOccurrenceCount effectId receipt.events = 1 :=
  closed.exactlyOnce.2.2

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCommittedEffectExactlyOnceBridgeModel
