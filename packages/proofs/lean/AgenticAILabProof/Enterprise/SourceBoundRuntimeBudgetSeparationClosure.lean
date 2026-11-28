-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundDeterministicBudgetClosure
import AgenticAILabProof.Enterprise.SourceBoundRuntimeWatchdogClosure

namespace AgenticAILabProof.Enterprise.SourceBoundRuntimeBudgetSeparationClosure

open AgenticAILabProof.Enterprise.SourceBoundDeterministicBudgetClosure
open AgenticAILabProof.Enterprise.SourceBoundRuntimeWatchdogClosure

/--
Runtime and deterministic-budget receipts may share source coordinates without
sharing evidence semantics or authority.
-/
def runtimeWatchdogBudgetCoordinatesMatch
    (watchdog : SourceBoundRuntimeWatchdogObservation)
    (budget : SourceBoundDeterministicBudgetReceipt) : Prop :=
  watchdog.registryDigest = budget.registryDigest ∧
    watchdog.generation = budget.generation ∧
      watchdog.cycleObservationId = budget.cycleObservationId ∧
        watchdog.continuationIdentity = budget.continuationIdentity

def positiveBudgetReceiptForWatchdog
    (watchdog : SourceBoundRuntimeWatchdogObservation) :
    SourceBoundDeterministicBudgetReceipt :=
  { receiptId := "positive-budget-receipt"
    planId := "positive-budget-plan"
    registryDigest := watchdog.registryDigest
    fixedPointReceiptId := "independent-fixed-point-receipt"
    generation := watchdog.generation
    cycleObservationId := watchdog.cycleObservationId
    continuationIdentity := watchdog.continuationIdentity
    progressReceiptId := "independent-progress-receipt"
    semanticConsumed := 0
    semanticRemaining := 1
    schedulingConsumed := 0
    schedulingRemaining := 1
    provenanceDigest := "positive-budget-provenance" }

theorem matchingRuntimeWatchdogThresholdDoesNotExhaustDeterministicBudget
    (watchdog : SourceBoundRuntimeWatchdogObservation)
    (thresholdExceeded :
      watchdog.thresholdValue < watchdog.observedValue) :
    watchdog.thresholdValue < watchdog.observedValue ∧
      runtimeWatchdogBudgetCoordinatesMatch
        watchdog (positiveBudgetReceiptForWatchdog watchdog) ∧
      ¬ deterministicBudgetExhausted
        (positiveBudgetReceiptForWatchdog watchdog) := by
  refine ⟨thresholdExceeded, ?_, ?_⟩
  · simp [
      runtimeWatchdogBudgetCoordinatesMatch,
      positiveBudgetReceiptForWatchdog
    ]
  · intro exhausted
    rcases exhausted with ⟨kind, zero⟩
    cases kind <;>
      simp [
        deterministicBudgetRemaining,
        positiveBudgetReceiptForWatchdog
      ] at zero

def exhaustedBudgetReceiptForWatchdog
    (watchdog : SourceBoundRuntimeWatchdogObservation) :
    SourceBoundDeterministicBudgetReceipt :=
  { receiptId := "exhausted-budget-receipt"
    planId := "exhausted-budget-plan"
    registryDigest := watchdog.registryDigest
    fixedPointReceiptId := "independent-fixed-point-receipt"
    generation := watchdog.generation
    cycleObservationId := watchdog.cycleObservationId
    continuationIdentity := watchdog.continuationIdentity
    progressReceiptId := "independent-progress-receipt"
    semanticConsumed := 1
    semanticRemaining := 0
    schedulingConsumed := 0
    schedulingRemaining := 1
    provenanceDigest := "exhausted-budget-provenance" }

def SourceBoundDeterministicBudgetRetryAuthority :=
  SourceBoundDeterministicBudgetReceipt → Prop

theorem deterministicBudgetExhaustionDoesNotAuthorizeRetry
    (watchdog : SourceBoundRuntimeWatchdogObservation) :
    deterministicBudgetExhausted
        (exhaustedBudgetReceiptForWatchdog watchdog) ∧
      ¬(fun _budget => False)
        (exhaustedBudgetReceiptForWatchdog watchdog) := by
  constructor
  · exact ⟨.semantic, rfl⟩
  · simp

end AgenticAILabProof.Enterprise.SourceBoundRuntimeBudgetSeparationClosure
