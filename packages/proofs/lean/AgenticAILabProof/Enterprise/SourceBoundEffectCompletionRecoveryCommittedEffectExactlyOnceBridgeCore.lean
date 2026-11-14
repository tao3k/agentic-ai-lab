-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.CommittedEffectApplicationExactlyOnce
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridgeCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCommittedEffectExactlyOnceBridgeCore

open AgenticAILabProof.Enterprise.CommittedEffectApplicationExactlyOnce
open AgenticAILabProof.Enterprise.EffectDomainCoverage
open AgenticAILabProof.Enterprise.PromotionTransactionAtomicity
open AgenticAILabProof.Enterprise.PromotionTransactionRecovery
open AgenticAILabProof.Enterprise.SourceBoundCompositionalEffectClosure
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridgeCore

abbrev CommittedEffectObservationTraceBindingValid :=
  EffectObservation → SourceBoundEffectExecutionTraceReceipt → Prop

abbrev CommittedEffectProvenanceBindingValid :=
  String →
    RecoveryReceipt →
    SourceBoundCompositionalEffectWitness →
    SourceBoundEffectExecutionTraceReceipt →
    Prop

structure SourceBoundEffectCompletionRecoveryCommittedEffectExactlyOnceBridge
    (authorizedRecovery : Prop)
    (request : PromotionCommitRequest)
    (recoveryFenceToken : Nat)
    (recoveryReceipt : RecoveryReceipt)
    (effectCoverageWitnessValid : EffectCoverageWitnessValid)
    (effectWorldValid : EffectWorldValid)
    (compensationValid : CompensationReceiptValid)
    (planEffectUniverseBindingValid : MaterializationPlanEffectUniverseBindingValid)
    (observationWorldBindingValid : RecoveryEffectObservationWorldBindingValid)
    (compensationFenceBindingValid : CompensationFenceBindingValid)
    (effectCompensationProvenanceBindingValid :
      EffectCompensationProvenanceBindingValid)
    (expectedCommitment : String)
    (effectCoverageWitness : EffectCoverageWitness)
    (effectObligations : List EffectObligation)
    (compensationReceipts : List CompensationReceipt)
    (effectWorldBefore effectWorldAfter : EffectWorld)
    (sourceEvidence : SourceBoundCommittedEffectExactlyOnceEvidence)
    (observationTraceBindingValid :
      CommittedEffectObservationTraceBindingValid)
    (committedEffectProvenanceBindingValid :
      CommittedEffectProvenanceBindingValid) : Prop where
  effectDomainBridge :
    SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridge
      authorizedRecovery
      request
      recoveryFenceToken
      recoveryReceipt
      effectCoverageWitnessValid
      effectWorldValid
      compensationValid
      planEffectUniverseBindingValid
      observationWorldBindingValid
      compensationFenceBindingValid
      effectCompensationProvenanceBindingValid
      expectedCommitment
      effectCoverageWitness
      effectObligations
      compensationReceipts
      effectWorldBefore
      effectWorldAfter
  committedOutcome :
    recoveryReceipt.effectReceipt.base.outcome = CommitOutcome.committed
  sourceTransactionMatches :
    sourceEvidence.request.transactionId = request.transactionId
  sourcePlanMatches :
    sourceEvidence.request.materializationPlanDigest =
      request.subject.materializationPlanDigest
  sourceFenceMatches :
    sourceEvidence.activeFenceToken = recoveryFenceToken
  sourceUniverseMatchesEffectDomain :
    sourceEvidence.witness.effectUniverse =
      effectCoverageWitness.effectUniverse
  postObservationTraceBinds :
    observationTraceBindingValid
      recoveryReceipt.effectReceipt.postEffect
      sourceEvidence.traceReceipt
  committedEffectProvenanceBinds :
    committedEffectProvenanceBindingValid
      expectedCommitment
      recoveryReceipt
      sourceEvidence.witness
      sourceEvidence.traceReceipt

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCommittedEffectExactlyOnceBridgeCore
