-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCommittedEffectExactlyOnceBridgeCore
import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEffectDomainRollbackTraceEvidence

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCommittedEffectExactlyOnceBridgeClosure

open AgenticAILabProof.Enterprise.CommittedEffectApplicationExactlyOnce
open AgenticAILabProof.Enterprise.PromotionTransactionAtomicity
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryAuthorizedTransactionRecoveryBridgeCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCommittedEffectExactlyOnceBridgeCore
open AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEffectDomainRollbackTraceEvidence

structure SourceBoundEffectCompletionRecoveryCommittedEffectExactlyOnceBridgeEvidence
    (effectDomainTrace :
      SourceBoundEffectCompletionRecoveryEffectDomainRollbackTraceEvidence)
    (sourceEvidenceRegistry :
      String → SourceBoundCommittedEffectExactlyOnceEvidence)
    (observationTraceBindingValid :
      CommittedEffectObservationTraceBindingValid)
    (committedEffectProvenanceBindingValid :
      CommittedEffectProvenanceBindingValid) : Prop where
  committedBindings :
    ∀ (index : Nat),
      sourceBoundEffectCompletionTransactionRecoveryRequired
          (effectDomainTrace.trace index) →
        let commitment := effectDomainTrace.CommitmentAt index
        effectDomainTrace.OutcomeAt index = CommitOutcome.committed →
          SourceBoundEffectCompletionRecoveryCommittedEffectExactlyOnceBridge
            (effectDomainTrace.AuthorizedRecoveryAt index)
            (effectDomainTrace.requestRegistry commitment)
            (effectDomainTrace.RecoveryFenceAt index)
            (effectDomainTrace.RecoveryReceiptAt index)
            effectDomainTrace.effectCoverageWitnessValid
            effectDomainTrace.effectWorldValid
            effectDomainTrace.compensationReceiptValid
            effectDomainTrace.planEffectUniverseBindingValid
            effectDomainTrace.observationWorldBindingValid
            effectDomainTrace.compensationFenceBindingValid
            effectDomainTrace.effectCompensationProvenanceBindingValid
            commitment
            (effectDomainTrace.effectCoverageWitnessRegistry commitment)
            (effectDomainTrace.effectObligationRegistry commitment)
            (effectDomainTrace.compensationReceiptRegistry commitment)
            (effectDomainTrace.effectWorldBeforeRegistry commitment)
            (effectDomainTrace.effectWorldAfterRegistry commitment)
            (sourceEvidenceRegistry commitment)
            observationTraceBindingValid
            committedEffectProvenanceBindingValid

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCommittedEffectExactlyOnceBridgeClosure
