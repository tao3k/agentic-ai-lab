-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.EffectDomainCoverage
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeCore

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridgeCore

open AgenticAILabProof.Enterprise
open AgenticAILabProof.Enterprise.EffectDomainCoverage
open AgenticAILabProof.Enterprise.PromotionTransactionAtomicity
open AgenticAILabProof.Enterprise.PromotionTransactionRecovery

abbrev MaterializationPlanEffectUniverseBindingValid :=
  MaterializationPlanDigest → EffectUniverse → Prop

abbrev RecoveryEffectObservationWorldBindingValid :=
  EffectObservation → EffectWorld → Prop

abbrev CompensationFenceBindingValid :=
  Nat → List CompensationReceipt → Prop

abbrev EffectCompensationProvenanceBindingValid :=
  String →
    RecoveryReceipt →
    EffectCoverageWitness →
    List EffectObligation →
    List CompensationReceipt →
    EffectWorld →
    EffectWorld →
    Prop

structure SourceBoundEffectCompletionRecoveryEffectDomainCoverageClosed
    (request : PromotionCommitRequest)
    (witnessValid : EffectCoverageWitnessValid)
    (worldValid : EffectWorldValid)
    (planEffectUniverseBindingValid : MaterializationPlanEffectUniverseBindingValid)
    (witness : EffectCoverageWitness)
    (before after : EffectWorld) : Prop where
  witnessPlanMatchesSubject :
    witness.materializationPlanDigest = request.subject.materializationPlanDigest
  witnessValidates :
    witnessValid witness
  planEffectUniverseBinds :
    planEffectUniverseBindingValid
      request.subject.materializationPlanDigest
      witness.effectUniverse
  domainCoversUniverse :
    effectDomainCoversUniverse witness.effectUniverse witness.observedDomain
  beforeWorldValidates :
    worldValid before
  afterWorldValidates :
    worldValid after
  beforeWorldCoversDomain :
    effectWorldCoversDomain witness.observedDomain before
  afterWorldCoversDomain :
    effectWorldCoversDomain witness.observedDomain after
  beforeWorldFunctional :
    effectWorldFunctional before
  afterWorldFunctional :
    effectWorldFunctional after

structure SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridge
    (authorizedRecovery : Prop)
    (request : PromotionCommitRequest)
    (recoveryFenceToken : Nat)
    (recoveryReceipt : RecoveryReceipt)
    (witnessValid : EffectCoverageWitnessValid)
    (worldValid : EffectWorldValid)
    (compensationValid : CompensationReceiptValid)
    (planEffectUniverseBindingValid : MaterializationPlanEffectUniverseBindingValid)
    (observationWorldBindingValid : RecoveryEffectObservationWorldBindingValid)
    (compensationFenceBindingValid : CompensationFenceBindingValid)
    (effectCompensationProvenanceBindingValid :
      EffectCompensationProvenanceBindingValid)
    (expectedCommitment : String)
    (witness : EffectCoverageWitness)
    (obligations : List EffectObligation)
    (compensationReceipts : List CompensationReceipt)
    (before after : EffectWorld) : Prop where
  authorizedRecoveryCloses :
    authorizedRecovery
  effectDomainCoverageCloses :
    SourceBoundEffectCompletionRecoveryEffectDomainCoverageClosed
      request
      witnessValid
      worldValid
      planEffectUniverseBindingValid
      witness
      before
      after
  preEffectObservationBinds :
    observationWorldBindingValid recoveryReceipt.effectReceipt.preEffect before
  postEffectObservationBinds :
    observationWorldBindingValid recoveryReceipt.effectReceipt.postEffect after
  effectCompensationProvenanceBinds :
    effectCompensationProvenanceBindingValid
      expectedCommitment
      recoveryReceipt
      witness
      obligations
      compensationReceipts
      before
      after
  rollbackCompensationFenceBinds :
    recoveryReceipt.effectReceipt.base.outcome = CommitOutcome.rolledBack →
      compensationFenceBindingValid recoveryFenceToken compensationReceipts
  rollbackEvidenceCloses :
    recoveryReceipt.effectReceipt.base.outcome = CommitOutcome.rolledBack →
      EffectRollbackEvidenceClosed
        request
        witnessValid
        worldValid
        compensationValid
        witness
        obligations
        compensationReceipts
        before
        after

theorem bridgeProvidesAuthorizedRecovery
    {authorizedRecovery : Prop}
    {request : PromotionCommitRequest}
    {recoveryFenceToken : Nat}
    {recoveryReceipt : RecoveryReceipt}
    {witnessValid : EffectCoverageWitnessValid}
    {worldValid : EffectWorldValid}
    {compensationValid : CompensationReceiptValid}
    {planEffectUniverseBindingValid : MaterializationPlanEffectUniverseBindingValid}
    {observationWorldBindingValid : RecoveryEffectObservationWorldBindingValid}
    {compensationFenceBindingValid : CompensationFenceBindingValid}
    {effectCompensationProvenanceBindingValid :
      EffectCompensationProvenanceBindingValid}
    {expectedCommitment : String}
    {witness : EffectCoverageWitness}
    {obligations : List EffectObligation}
    {compensationReceipts : List CompensationReceipt}
    {before after : EffectWorld}
    (closed :
      SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridge
        authorizedRecovery
        request
        recoveryFenceToken
        recoveryReceipt
        witnessValid
        worldValid
        compensationValid
        planEffectUniverseBindingValid
        observationWorldBindingValid
        compensationFenceBindingValid
        effectCompensationProvenanceBindingValid
        expectedCommitment
        witness
        obligations
        compensationReceipts
        before
        after) :
    authorizedRecovery :=
  closed.authorizedRecoveryCloses

theorem rolledBackBridgeProvidesWholeEffectUniverseAgreement
    {authorizedRecovery : Prop}
    {request : PromotionCommitRequest}
    {recoveryFenceToken : Nat}
    {recoveryReceipt : RecoveryReceipt}
    {witnessValid : EffectCoverageWitnessValid}
    {worldValid : EffectWorldValid}
    {compensationValid : CompensationReceiptValid}
    {planEffectUniverseBindingValid : MaterializationPlanEffectUniverseBindingValid}
    {observationWorldBindingValid : RecoveryEffectObservationWorldBindingValid}
    {compensationFenceBindingValid : CompensationFenceBindingValid}
    {effectCompensationProvenanceBindingValid :
      EffectCompensationProvenanceBindingValid}
    {expectedCommitment : String}
    {witness : EffectCoverageWitness}
    {obligations : List EffectObligation}
    {compensationReceipts : List CompensationReceipt}
    {before after : EffectWorld}
    (closed :
      SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridge
        authorizedRecovery
        request
        recoveryFenceToken
        recoveryReceipt
        witnessValid
        worldValid
        compensationValid
        planEffectUniverseBindingValid
        observationWorldBindingValid
        compensationFenceBindingValid
        effectCompensationProvenanceBindingValid
        expectedCommitment
        witness
        obligations
        compensationReceipts
        before
        after)
    (rolledBack :
      recoveryReceipt.effectReceipt.base.outcome = CommitOutcome.rolledBack) :
    worldsAgreeOn witness.effectUniverse before after :=
  coveredRollbackAgreesOnEveryPlanEffect
    request
    witnessValid
    worldValid
    compensationValid
    witness
    obligations
    compensationReceipts
    before
    after
    (closed.rollbackEvidenceCloses rolledBack)

theorem rolledBackBridgeBindsCompensationToRecoveryFence
    {authorizedRecovery : Prop}
    {request : PromotionCommitRequest}
    {recoveryFenceToken : Nat}
    {recoveryReceipt : RecoveryReceipt}
    {witnessValid : EffectCoverageWitnessValid}
    {worldValid : EffectWorldValid}
    {compensationValid : CompensationReceiptValid}
    {planEffectUniverseBindingValid : MaterializationPlanEffectUniverseBindingValid}
    {observationWorldBindingValid : RecoveryEffectObservationWorldBindingValid}
    {compensationFenceBindingValid : CompensationFenceBindingValid}
    {effectCompensationProvenanceBindingValid :
      EffectCompensationProvenanceBindingValid}
    {expectedCommitment : String}
    {witness : EffectCoverageWitness}
    {obligations : List EffectObligation}
    {compensationReceipts : List CompensationReceipt}
    {before after : EffectWorld}
    (closed :
      SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridge
        authorizedRecovery
        request
        recoveryFenceToken
        recoveryReceipt
        witnessValid
        worldValid
        compensationValid
        planEffectUniverseBindingValid
        observationWorldBindingValid
        compensationFenceBindingValid
        effectCompensationProvenanceBindingValid
        expectedCommitment
        witness
        obligations
        compensationReceipts
        before
        after)
    (rolledBack :
      recoveryReceipt.effectReceipt.base.outcome = CommitOutcome.rolledBack) :
    compensationFenceBindingValid recoveryFenceToken compensationReceipts :=
  closed.rollbackCompensationFenceBinds rolledBack

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEffectDomainRollbackBridgeCore
