-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundProgressEvidenceClosure

namespace AgenticAILabProof.Enterprise.SourceBoundDeterministicBudgetClosure

open AgenticAILabProof.Enterprise.CompositionalEffectUniverse
open AgenticAILabProof.Enterprise.SourceBoundCompositionalEffectClosure
open AgenticAILabProof.Enterprise.SourceBoundCompositionalFixedPointClosure
open AgenticAILabProof.Enterprise.SourceBoundCycleObservationClosure
open AgenticAILabProof.Enterprise.SourceBoundProgressEvidenceClosure

abbrev DeterministicBudgetPlanId := String
abbrev DeterministicBudgetReceiptId := String

inductive DeterministicBudgetKind where
  | semantic
  | scheduling
  deriving DecidableEq, Repr

/--
A deterministic budget plan is authorized for one fixed-point receipt and one
maximum generation.  Runtime watchdog metrics are deliberately absent.
-/
structure SourceBoundDeterministicBudgetPlan where
  planId : DeterministicBudgetPlanId
  registryDigest : CompositionRegistryDigest
  fixedPointReceiptId : String
  maxGeneration : Nat
  ownerIdentity : String
  semanticLimit : Nat
  schedulingLimit : Nat
  provenanceDigest : String
  deriving Repr

/--
A budget receipt records conservation, not merely a pair of unowned remaining
values.  Its coordinates bind the accounting to a progress receipt and cycle
continuation.
-/
structure SourceBoundDeterministicBudgetReceipt where
  receiptId : DeterministicBudgetReceiptId
  planId : DeterministicBudgetPlanId
  registryDigest : CompositionRegistryDigest
  fixedPointReceiptId : String
  generation : Nat
  cycleObservationId : String
  continuationIdentity : String
  progressReceiptId : String
  semanticConsumed : Nat
  semanticRemaining : Nat
  schedulingConsumed : Nat
  schedulingRemaining : Nat
  provenanceDigest : String
  deriving Repr

def SourceBoundDeterministicBudgetPlanValid :=
  SourceBoundDeterministicBudgetPlan → Prop

def SourceBoundDeterministicBudgetReceiptValid :=
  SourceBoundDeterministicBudgetReceipt → Prop

def deterministicBudgetLimit
    (plan : SourceBoundDeterministicBudgetPlan) :
    DeterministicBudgetKind → Nat
  | .semantic => plan.semanticLimit
  | .scheduling => plan.schedulingLimit

def deterministicBudgetConsumed
    (receipt : SourceBoundDeterministicBudgetReceipt) :
    DeterministicBudgetKind → Nat
  | .semantic => receipt.semanticConsumed
  | .scheduling => receipt.schedulingConsumed

def deterministicBudgetRemaining
    (receipt : SourceBoundDeterministicBudgetReceipt) :
    DeterministicBudgetKind → Nat
  | .semantic => receipt.semanticRemaining
  | .scheduling => receipt.schedulingRemaining

def deterministicBudgetAccountingClosed
    (plan : SourceBoundDeterministicBudgetPlan)
    (receipt : SourceBoundDeterministicBudgetReceipt) : Prop :=
  ∀ kind,
    deterministicBudgetConsumed receipt kind +
        deterministicBudgetRemaining receipt kind =
      deterministicBudgetLimit plan kind

def deterministicBudgetExhausted
    (receipt : SourceBoundDeterministicBudgetReceipt) : Prop :=
  ∃ kind, deterministicBudgetRemaining receipt kind = 0

/--
The complete v1 budget closure binds authorization, accounting, progress
classification, and source coordinates.  It neither consumes nor derives
runtime-watchdog authority.
-/
structure SourceBoundDeterministicBudgetEvidenceClosed
    (planValid : SourceBoundDeterministicBudgetPlanValid)
    (receiptValid : SourceBoundDeterministicBudgetReceiptValid)
    (fixedPoint : SourceBoundFixedPointReceipt)
    (cycle : SourceBoundCycleDetectedObservation)
    (progress : SourceBoundProgressReceipt)
    (plan : SourceBoundDeterministicBudgetPlan)
    (receipt : SourceBoundDeterministicBudgetReceipt) : Prop where
  planValidates : planValid plan
  receiptValidates : receiptValid receipt
  planRegistryMatches : plan.registryDigest = fixedPoint.registryDigest
  planFixedPointMatches : plan.fixedPointReceiptId = fixedPoint.receiptId
  planGenerationMatches : plan.maxGeneration = fixedPoint.generation
  receiptPlanMatches : receipt.planId = plan.planId
  receiptRegistryMatches : receipt.registryDigest = progress.registryDigest
  receiptFixedPointMatches : receipt.fixedPointReceiptId = fixedPoint.receiptId
  receiptGenerationMatches : receipt.generation = progress.generation
  receiptGenerationBound : receipt.generation ≤ plan.maxGeneration
  receiptCycleMatches : receipt.cycleObservationId = cycle.observationId
  receiptContinuationMatches :
    receipt.continuationIdentity = cycle.continuationIdentity
  receiptProgressMatches : receipt.progressReceiptId = progress.receiptId
  accountingCloses : deterministicBudgetAccountingClosed plan receipt
  progressSemanticRemainingMatches :
    progress.semanticBudgetRemaining = receipt.semanticRemaining
  progressSchedulingRemainingMatches :
    progress.schedulingBudgetRemaining = receipt.schedulingRemaining
  classificationMatchesExhaustion :
    progress.classification = .budgetExhausted ↔
      deterministicBudgetExhausted receipt

/--
Full source-bound closure composes the already-proved progress evidence with
the independent deterministic-budget owner.  Neither component may substitute
for the other.
-/
structure SourceBoundDeterministicBudgetProgressEvidenceClosed
    (contractValid : SourceBoundProgressContractValid)
    (progressValid : SourceBoundProgressReceiptValid)
    (cycleValid : SourceBoundCycleDetectedObservationValid)
    (planValid : SourceBoundDeterministicBudgetPlanValid)
    (receiptValid : SourceBoundDeterministicBudgetReceiptValid)
    (contract : SourceBoundProgressContract)
    (registry : SourceBoundCompositionRegistry)
    (fixedPoint : SourceBoundFixedPointReceipt)
    (cycle : SourceBoundCycleDetectedObservation)
    (progress : SourceBoundProgressReceipt)
    (plan : SourceBoundDeterministicBudgetPlan)
    (receipt : SourceBoundDeterministicBudgetReceipt) : Prop where
  progressEvidenceCloses :
    SourceBoundProgressEvidenceClosed
      contractValid progressValid cycleValid
      contract registry fixedPoint cycle progress
  deterministicBudgetEvidenceCloses :
    SourceBoundDeterministicBudgetEvidenceClosed
      planValid receiptValid fixedPoint cycle progress plan receipt

theorem progressAndDeterministicBudgetClosuresCompose
    {contractValid : SourceBoundProgressContractValid}
    {progressValid : SourceBoundProgressReceiptValid}
    {cycleValid : SourceBoundCycleDetectedObservationValid}
    {planValid : SourceBoundDeterministicBudgetPlanValid}
    {receiptValid : SourceBoundDeterministicBudgetReceiptValid}
    {contract : SourceBoundProgressContract}
    {registry : SourceBoundCompositionRegistry}
    {fixedPoint : SourceBoundFixedPointReceipt}
    {cycle : SourceBoundCycleDetectedObservation}
    {progress : SourceBoundProgressReceipt}
    {plan : SourceBoundDeterministicBudgetPlan}
    {receipt : SourceBoundDeterministicBudgetReceipt}
    (progressClosed :
      SourceBoundProgressEvidenceClosed
        contractValid progressValid cycleValid
        contract registry fixedPoint cycle progress)
    (budgetClosed :
      SourceBoundDeterministicBudgetEvidenceClosed
        planValid receiptValid fixedPoint cycle progress plan receipt) :
    SourceBoundDeterministicBudgetProgressEvidenceClosed
      contractValid progressValid cycleValid planValid receiptValid
      contract registry fixedPoint cycle progress plan receipt :=
  ⟨progressClosed, budgetClosed⟩

/--
AXLE verifies this owner-level composition law independently of the concrete
progress and budget declaration graphs.  The concrete instantiation remains
the theorem above and is checked by the project Lean build.
-/
theorem independentlyClosedProgressAndBudgetOwnersCompose
    {progressClosure budgetClosure : Prop}
    (progressClosed : progressClosure)
    (budgetClosed : budgetClosure) :
    progressClosure ∧ budgetClosure :=
  ⟨progressClosed, budgetClosed⟩

theorem closedBudgetExhaustionIsTyped
    {planValid : SourceBoundDeterministicBudgetPlanValid}
    {receiptValid : SourceBoundDeterministicBudgetReceiptValid}
    {fixedPoint : SourceBoundFixedPointReceipt}
    {cycle : SourceBoundCycleDetectedObservation}
    {progress : SourceBoundProgressReceipt}
    {plan : SourceBoundDeterministicBudgetPlan}
    {receipt : SourceBoundDeterministicBudgetReceipt}
    (closed :
      SourceBoundDeterministicBudgetEvidenceClosed
        planValid receiptValid fixedPoint cycle progress plan receipt)
    (classified : progress.classification = .budgetExhausted) :
    ∃ kind, deterministicBudgetRemaining receipt kind = 0 :=
  closed.classificationMatchesExhaustion.mp classified

theorem closedBudgetAccountingBindsAuthorizedLimits
    {planValid : SourceBoundDeterministicBudgetPlanValid}
    {receiptValid : SourceBoundDeterministicBudgetReceiptValid}
    {fixedPoint : SourceBoundFixedPointReceipt}
    {cycle : SourceBoundCycleDetectedObservation}
    {progress : SourceBoundProgressReceipt}
    {plan : SourceBoundDeterministicBudgetPlan}
    {receipt : SourceBoundDeterministicBudgetReceipt}
    (closed :
      SourceBoundDeterministicBudgetEvidenceClosed
        planValid receiptValid fixedPoint cycle progress plan receipt) :
    ∀ kind,
      deterministicBudgetConsumed receipt kind +
          deterministicBudgetRemaining receipt kind =
        deterministicBudgetLimit plan kind :=
  closed.accountingCloses

def firstBudgetPlanFor
    (fixedPoint : SourceBoundFixedPointReceipt) :
    SourceBoundDeterministicBudgetPlan :=
  { planId := "deterministic-budget-plan-a"
    registryDigest := fixedPoint.registryDigest
    fixedPointReceiptId := fixedPoint.receiptId
    maxGeneration := fixedPoint.generation
    ownerIdentity := "agentic-ai-lab-budget-owner-a"
    semanticLimit := 8
    schedulingLimit := 32
    provenanceDigest := "budget-plan-a-provenance" }

def secondBudgetPlanFor
    (fixedPoint : SourceBoundFixedPointReceipt) :
    SourceBoundDeterministicBudgetPlan :=
  { planId := "deterministic-budget-plan-b"
    registryDigest := fixedPoint.registryDigest
    fixedPointReceiptId := fixedPoint.receiptId
    maxGeneration := fixedPoint.generation
    ownerIdentity := "agentic-ai-lab-budget-owner-b"
    semanticLimit := 8
    schedulingLimit := 32
    provenanceDigest := "budget-plan-b-provenance" }

theorem fixedPointReceiptDoesNotDetermineBudgetPlanIdentity
    (fixedPoint : SourceBoundFixedPointReceipt) :
    (firstBudgetPlanFor fixedPoint).fixedPointReceiptId = fixedPoint.receiptId ∧
      (secondBudgetPlanFor fixedPoint).fixedPointReceiptId =
        fixedPoint.receiptId ∧
      (firstBudgetPlanFor fixedPoint).planId ≠
        (secondBudgetPlanFor fixedPoint).planId := by
  simp [firstBudgetPlanFor, secondBudgetPlanFor]

end AgenticAILabProof.Enterprise.SourceBoundDeterministicBudgetClosure
