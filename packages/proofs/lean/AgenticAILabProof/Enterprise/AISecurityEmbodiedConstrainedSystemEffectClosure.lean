-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.AISecurityArchitectureCompositionClosure
import AgenticAILabProof.Enterprise.EffectDomainCoverage
import AgenticAILabProof.Enterprise.PromotionTransactionRecovery

namespace AgenticAILabProof.Enterprise.AISecurityEmbodiedConstrainedSystemEffectClosure

/--
EASE-001 closes over the whole effect consequence envelope.  Authorization is
necessary, but it cannot substitute domain coverage, replay safety, fenced
recovery, terminal recovery evidence, or compensation evidence.
-/
def constrainedSystemEffectClosed
    (facts : AgenticAILabProof.PooC4.AuthorizedEffectEvidenceFacts)
    (effectDomainCovered : Prop)
    (duplicateSafe : Prop)
    (recoveryFenced : Prop)
    (recoveryTerminal : Prop)
    (compensationValidated : Prop) : Prop :=
  AgenticAILabProof.PooC4.authorizedEffectL1 facts ∧
    effectDomainCovered ∧
    duplicateSafe ∧
    recoveryFenced ∧
    recoveryTerminal ∧
    compensationValidated

theorem authorizedEffectAloneDoesNotClose
    (facts : AgenticAILabProof.PooC4.AuthorizedEffectEvidenceFacts)
    (_authorized : AgenticAILabProof.PooC4.authorizedEffectL1 facts) :
    ¬constrainedSystemEffectClosed facts False True True True True := by
  simp [constrainedSystemEffectClosed]

theorem ease001FormalBound
    (facts : AgenticAILabProof.PooC4.AuthorizedEffectEvidenceFacts)
    (effectDomainCovered duplicateSafe recoveryFenced recoveryTerminal
      compensationValidated : Prop)
    (closed : constrainedSystemEffectClosed facts effectDomainCovered
      duplicateSafe recoveryFenced recoveryTerminal compensationValidated) :
    AgenticAILabProof.PooC4.authorizedEffectL1 facts ∧
      effectDomainCovered ∧
      duplicateSafe ∧
      recoveryFenced ∧
      recoveryTerminal ∧
      compensationValidated :=
  closed

/-- Reuse the exactly-once owner: duplicate closure has a prior commit. -/
theorem duplicateClosureRequiresPriorCommit
    (ledger : List
      AgenticAILabProof.Enterprise.PromotionTransactionAtomicity.PromotionCommitReceipt)
    (commitValid :
      AgenticAILabProof.Enterprise.PromotionTransactionAtomicity.CommitReceiptValid)
    (request :
      AgenticAILabProof.Enterprise.PromotionTransactionAtomicity.PromotionCommitRequest)
    (receipt :
      AgenticAILabProof.Enterprise.PromotionTransactionRecovery.AtomicEffectReceipt)
    (closed :
      AgenticAILabProof.Enterprise.PromotionTransactionRecovery.effectOutcomeClosed
        commitValid ledger request receipt)
    (duplicate : receipt.base.outcome =
      AgenticAILabProof.Enterprise.PromotionTransactionAtomicity.CommitOutcome.duplicate) :
    AgenticAILabProof.Enterprise.PromotionTransactionRecovery.priorCommitExists
      commitValid ledger request :=
  AgenticAILabProof.Enterprise.PromotionTransactionRecovery.closedDuplicateRequiresPriorCommit
    ledger commitValid request receipt closed duplicate

/-- Reuse the rollback owner: closed rollback restores observed effects. -/
theorem rollbackClosureRestoresObservedEffect
    (ledger : List
      AgenticAILabProof.Enterprise.PromotionTransactionAtomicity.PromotionCommitReceipt)
    (commitValid :
      AgenticAILabProof.Enterprise.PromotionTransactionAtomicity.CommitReceiptValid)
    (request :
      AgenticAILabProof.Enterprise.PromotionTransactionAtomicity.PromotionCommitRequest)
    (receipt :
      AgenticAILabProof.Enterprise.PromotionTransactionRecovery.AtomicEffectReceipt)
    (closed :
      AgenticAILabProof.Enterprise.PromotionTransactionRecovery.effectOutcomeClosed
        commitValid ledger request receipt)
    (rolledBack : receipt.base.outcome =
      AgenticAILabProof.Enterprise.PromotionTransactionAtomicity.CommitOutcome.rolledBack) :
    receipt.postEffect = receipt.preEffect :=
  AgenticAILabProof.Enterprise.PromotionTransactionRecovery.closedRollbackRestoresCompleteEffectObservation
    ledger commitValid request receipt closed rolledBack

/-- Reuse the effect-domain owner: closure covers every declared plan effect. -/
theorem rollbackClosureCoversEffectUniverse
    (request :
      AgenticAILabProof.Enterprise.PromotionTransactionAtomicity.PromotionCommitRequest)
    (witnessValid :
      AgenticAILabProof.Enterprise.EffectDomainCoverage.EffectCoverageWitnessValid)
    (worldValid : AgenticAILabProof.Enterprise.EffectDomainCoverage.EffectWorldValid)
    (compensationValid :
      AgenticAILabProof.Enterprise.EffectDomainCoverage.CompensationReceiptValid)
    (witness : AgenticAILabProof.Enterprise.EffectDomainCoverage.EffectCoverageWitness)
    (obligations : List
      AgenticAILabProof.Enterprise.EffectDomainCoverage.EffectObligation)
    (compensationReceipts : List
      AgenticAILabProof.Enterprise.EffectDomainCoverage.CompensationReceipt)
    (before after : AgenticAILabProof.Enterprise.EffectDomainCoverage.EffectWorld)
    (closed : AgenticAILabProof.Enterprise.EffectDomainCoverage.EffectRollbackEvidenceClosed
      request witnessValid worldValid compensationValid witness obligations
        compensationReceipts before after) :
    AgenticAILabProof.Enterprise.EffectDomainCoverage.worldsAgreeOn
      witness.effectUniverse before after :=
  AgenticAILabProof.Enterprise.EffectDomainCoverage.coveredRollbackAgreesOnEveryPlanEffect
    request witnessValid worldValid compensationValid witness obligations
      compensationReceipts before after closed

end AgenticAILabProof.Enterprise.AISecurityEmbodiedConstrainedSystemEffectClosure
