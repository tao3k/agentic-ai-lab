-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundProgressEvidenceClosure

namespace AgenticAILabProof.Enterprise.SourceBoundProgressClassificationCoherenceClosure

open AgenticAILabProof.Enterprise.SourceBoundCompositionalEffectClosure
open AgenticAILabProof.Enterprise.SourceBoundCompositionalFixedPointClosure
open AgenticAILabProof.Enterprise.SourceBoundCycleObservationClosure
open AgenticAILabProof.Enterprise.SourceBoundProgressEvidenceClosure

abbrev ProgressClassification :=
  AgenticAILabProof.Enterprise.CompositionalFixedPointClosure.ProgressClass

inductive ProgressSemanticRelation where
  | equivalent
  | improving
  | regressing
  | incomparable
  | oscillating
  deriving DecidableEq, Repr

def progressSemanticRelationHolds
    (contract : SourceBoundProgressContract)
    (evidence : SubjectProgressEvidence) :
    ProgressSemanticRelation → Prop
  | .equivalent => contract.semanticEquivalent evidence
  | .improving => contract.monotoneImprovement evidence
  | .regressing => contract.semanticRegression evidence
  | .incomparable => contract.semanticIncomparable evidence
  | .oscillating =>
      fingerprintHistoryHasCanonicalOscillation evidence.fingerprintHistory ∧
        contract.semanticOscillation evidence

def progressContractRelationCoherentAt
    (contract : SourceBoundProgressContract)
    (evidence : SubjectProgressEvidence) : Prop :=
  ∀ left right,
    left ≠ right →
      progressSemanticRelationHolds contract evidence left →
        ¬ progressSemanticRelationHolds contract evidence right

def progressContractObligationsCoherentAt
    (contract : SourceBoundProgressContract)
    (evidence : SubjectProgressEvidence) : Prop :=
  ¬(contract.obligationsComplete evidence ∧
      contract.obligationsRemain evidence)

def SourceBoundProgressContractCoherenceClosed
    (contract : SourceBoundProgressContract)
    (receipt : SourceBoundProgressReceipt) : Prop :=
  ∀ evidence,
    evidence ∈ receipt.subjectEvidence →
      progressContractRelationCoherentAt contract evidence ∧
        progressContractObligationsCoherentAt contract evidence

def receiptWithProgressClassification
    (receipt : SourceBoundProgressReceipt)
    (classification : ProgressClassification) :
    SourceBoundProgressReceipt :=
  { receipt with classification := classification }

def progressClassificationSupportedAs
    (contract : SourceBoundProgressContract)
    (receipt : SourceBoundProgressReceipt)
    (classification : ProgressClassification) : Prop :=
  progressClassificationSupported
    contract (receiptWithProgressClassification receipt classification)

/--
The old opaque hooks can support contradictory classifications for the same
coordinates and evidence universe.
-/
def overlappingProgressContract : SourceBoundProgressContract :=
  { semanticEquivalent := fun _evidence => True
    monotoneImprovement := fun _evidence => True
    semanticRegression := fun _evidence => True
    semanticIncomparable := fun _evidence => True
    semanticOscillation := fun _evidence => True
    obligationsComplete := fun _evidence => True
    obligationsRemain := fun _evidence => True }

theorem opaqueContractHooksPermitConflictingClassifications :
    progressClassificationSupportedAs
        overlappingProgressContract sourceBoundCycleProgressReceipt
        .advancing ∧
      progressClassificationSupportedAs
        overlappingProgressContract sourceBoundCycleProgressReceipt
        .regressing := by
  simp [
    progressClassificationSupportedAs,
    receiptWithProgressClassification,
    progressClassificationSupported,
    overlappingProgressContract,
    sourceBoundCycleProgressReceipt
  ]

theorem conflictingContractFailsCoherence :
    ¬ SourceBoundProgressContractCoherenceClosed
        overlappingProgressContract sourceBoundCycleProgressReceipt := by
  intro closed
  have coherentAtA :=
    closed progressEvidenceA (by simp [sourceBoundCycleProgressReceipt])
  have equivalentExcludesRegression :=
    coherentAtA.1 .equivalent .regressing (by decide) (by
      simp [
        progressSemanticRelationHolds,
        overlappingProgressContract
      ])
  exact equivalentExcludesRegression (by
    simp [
      progressSemanticRelationHolds,
      overlappingProgressContract
    ])

structure SourceBoundProgressClassificationPolicy where
  rank : ProgressClassification → Nat
  rankInjective : Function.Injective rank
  budgetExhaustedDominates :
    ∀ classification,
      classification ≠ .budgetExhausted →
        rank classification < rank .budgetExhausted

def riskFirstProgressClassificationRank : ProgressClassification → Nat
  | .converged => 0
  | .advancing => 1
  | .stalled => 2
  | .incomparable => 3
  | .regressing => 4
  | .oscillating => 5
  | .budgetExhausted => 6

def riskFirstProgressClassificationPolicy :
    SourceBoundProgressClassificationPolicy where
  rank := riskFirstProgressClassificationRank
  rankInjective := by
    intro first second equalRank
    cases first <;> cases second <;>
      simp [riskFirstProgressClassificationRank] at equalRank ⊢
  budgetExhaustedDominates := by
    intro classification notExhausted
    cases classification <;>
      simp [riskFirstProgressClassificationRank] at notExhausted ⊢

theorem sourceBoundCycleProgressContractCoherenceCloses :
    SourceBoundProgressContractCoherenceClosed
      sourceBoundCycleProgressContract sourceBoundCycleProgressReceipt := by
  intro evidence member
  simp [sourceBoundCycleProgressReceipt] at member
  subst evidence
  constructor
  · intro left right different leftHolds
    cases left <;> cases right <;>
      simp [
        progressSemanticRelationHolds,
        sourceBoundCycleProgressContract,
        progressEvidenceA,
        fingerprintHistoryHasCanonicalOscillation
      ] at different leftHolds ⊢
  · simp [
      progressContractObligationsCoherentAt,
      sourceBoundCycleProgressContract,
      progressEvidenceA
    ]

structure SourceBoundProgressClassificationSelectionClosed
    (policy : SourceBoundProgressClassificationPolicy)
    (contract : SourceBoundProgressContract)
    (receipt : SourceBoundProgressReceipt) : Prop where
  contractCoherenceCloses :
    SourceBoundProgressContractCoherenceClosed contract receipt
  selectedSupported :
    progressClassificationSupportedAs
      contract receipt receipt.classification
  selectedMaximal :
    ∀ candidate,
      progressClassificationSupportedAs contract receipt candidate →
        policy.rank candidate ≤ policy.rank receipt.classification

theorem sourceBoundRiskFirstProgressClassificationSelectionCloses :
    SourceBoundProgressClassificationSelectionClosed
      riskFirstProgressClassificationPolicy
      sourceBoundCycleProgressContract
      sourceBoundCycleProgressReceipt := by
  constructor
  · exact sourceBoundCycleProgressContractCoherenceCloses
  · simp [
      progressClassificationSupportedAs,
      receiptWithProgressClassification,
      progressClassificationSupported,
      sourceBoundCycleProgressContract,
      sourceBoundCycleProgressReceipt,
      progressEvidenceA
    ]
  · intro candidate supported
    cases candidate <;>
      simp [
        progressClassificationSupportedAs,
        receiptWithProgressClassification,
        progressClassificationSupported,
        riskFirstProgressClassificationPolicy,
        riskFirstProgressClassificationRank,
        sourceBoundCycleProgressContract,
        sourceBoundCycleProgressReceipt,
        progressEvidenceA,
        fingerprintHistoryHasCanonicalOscillation
      ] at supported ⊢

theorem maximalSupportedProgressClassificationUnique
    (policy : SourceBoundProgressClassificationPolicy)
    (contract : SourceBoundProgressContract)
    (receipt : SourceBoundProgressReceipt)
    {first second : ProgressClassification}
    (firstSupported :
      progressClassificationSupportedAs contract receipt first)
    (secondSupported :
      progressClassificationSupportedAs contract receipt second)
    (firstMaximal :
      ∀ candidate,
        progressClassificationSupportedAs contract receipt candidate →
          policy.rank candidate ≤ policy.rank first)
    (secondMaximal :
      ∀ candidate,
        progressClassificationSupportedAs contract receipt candidate →
          policy.rank candidate ≤ policy.rank second) :
    first = second := by
  apply policy.rankInjective
  apply Nat.le_antisymm
  · exact secondMaximal first firstSupported
  · exact firstMaximal second secondSupported

theorem zeroRemainingForcesBudgetExhaustedSelection
    (policy : SourceBoundProgressClassificationPolicy)
    (contract : SourceBoundProgressContract)
    (receipt : SourceBoundProgressReceipt)
    (closed :
      SourceBoundProgressClassificationSelectionClosed
        policy contract receipt)
    (zeroRemaining :
      receipt.semanticBudgetRemaining = 0 ∨
        receipt.schedulingBudgetRemaining = 0) :
    receipt.classification = .budgetExhausted := by
  have budgetSupported :
      progressClassificationSupportedAs
        contract receipt .budgetExhausted :=
    zeroRemaining
  exact Classical.byContradiction fun notExhausted =>
    (Nat.not_lt_of_ge
      (closed.selectedMaximal .budgetExhausted budgetSupported))
      (policy.budgetExhaustedDominates
        receipt.classification notExhausted)

structure SourceBoundProgressClassificationEvidenceClosed
    (contractValid : SourceBoundProgressContractValid)
    (progressValid : SourceBoundProgressReceiptValid)
    (cycleValid : SourceBoundCycleDetectedObservationValid)
    (policy : SourceBoundProgressClassificationPolicy)
    (contract : SourceBoundProgressContract)
    (registry : SourceBoundCompositionRegistry)
    (fixedPoint : SourceBoundFixedPointReceipt)
    (cycle : SourceBoundCycleDetectedObservation)
    (progress : SourceBoundProgressReceipt) : Prop where
  progressEvidenceCloses :
    SourceBoundProgressEvidenceClosed
      contractValid progressValid cycleValid
      contract registry fixedPoint cycle progress
  classificationSelectionCloses :
    SourceBoundProgressClassificationSelectionClosed
      policy contract progress

theorem progressAndClassificationSelectionClosuresCompose
    {contractValid : SourceBoundProgressContractValid}
    {progressValid : SourceBoundProgressReceiptValid}
    {cycleValid : SourceBoundCycleDetectedObservationValid}
    {policy : SourceBoundProgressClassificationPolicy}
    {contract : SourceBoundProgressContract}
    {registry : SourceBoundCompositionRegistry}
    {fixedPoint : SourceBoundFixedPointReceipt}
    {cycle : SourceBoundCycleDetectedObservation}
    {progress : SourceBoundProgressReceipt}
    (progressClosed :
      SourceBoundProgressEvidenceClosed
        contractValid progressValid cycleValid
        contract registry fixedPoint cycle progress)
    (selectionClosed :
      SourceBoundProgressClassificationSelectionClosed
        policy contract progress) :
    SourceBoundProgressClassificationEvidenceClosed
      contractValid progressValid cycleValid policy
      contract registry fixedPoint cycle progress :=
  ⟨progressClosed, selectionClosed⟩

theorem independentlyClosedProgressAndClassificationOwnersCompose
    {progressClosure classificationClosure : Prop}
    (progressClosed : progressClosure)
    (classificationClosed : classificationClosure) :
    progressClosure ∧ classificationClosure :=
  ⟨progressClosed, classificationClosed⟩

end AgenticAILabProof.Enterprise.SourceBoundProgressClassificationCoherenceClosure
