-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundCycleObservationClosure

namespace AgenticAILabProof.Enterprise.SourceBoundProgressEvidenceClosure

open CompositionalEffectUniverse
open CompositionalFixedPointClosure
open SourceBoundCompositionalEffectClosure
open SourceBoundCompositionalFixedPointClosure
open SourceBoundCycleObservationClosure

def progressMatchesCycleCoordinates
    (progress : ProgressReceipt)
    (observation : SourceBoundCycleDetectedObservation) : Prop :=
  progress.registryDigest = observation.registryDigest ∧
    progress.generation = observation.generation

def coordinateOnlyProgressReceipt : ProgressReceipt where
  receiptId := "coordinate-only-progress"
  registryDigest := "sha256:source-bound-cycle-registry"
  generation := 2
  classification := .converged
  semanticFingerprint := "sha256:coordinate-only-fingerprint"
  remainingObligationsDigest := "sha256:coordinate-only-obligations"
  semanticBudgetRemaining := 8
  schedulingBudgetRemaining := 32
  watchdogObservationId := none

def revisionAOnlyCycleCoordinates :
    SourceBoundCycleDetectedObservation where
  observationId := "revision-a-only-cycle-coordinates"
  registryDigest := coordinateOnlyProgressReceipt.registryDigest
  generation := coordinateOnlyProgressReceipt.generation
  closingSource := messageProviderSubjectA
  closingTarget := messageProviderSubjectA
  sccMembers := [messageProviderSubjectA]
  causalPath := [messageProviderSubjectA, messageProviderSubjectA]
  provenanceDigest := "sha256:revision-a-cycle-coordinates"
  semanticBudgetConsumed := 1
  schedulingBudgetConsumed := 1
  continuationIdentity := "continuation-revision-a-cycle-coordinates"

def revisionBOnlyCycleCoordinates :
    SourceBoundCycleDetectedObservation where
  observationId := "revision-b-only-cycle-coordinates"
  registryDigest := coordinateOnlyProgressReceipt.registryDigest
  generation := coordinateOnlyProgressReceipt.generation
  closingSource := messageProviderSubjectB
  closingTarget := messageProviderSubjectB
  sccMembers := [messageProviderSubjectB]
  causalPath := [messageProviderSubjectB, messageProviderSubjectB]
  provenanceDigest := "sha256:revision-b-cycle-coordinates"
  semanticBudgetConsumed := 1
  schedulingBudgetConsumed := 1
  continuationIdentity := "continuation-revision-b-cycle-coordinates"

theorem progressCoordinatesCannotBindCompleteCycleSubject :
    progressMatchesCycleCoordinates
        coordinateOnlyProgressReceipt
        revisionAOnlyCycleCoordinates ∧
      progressMatchesCycleCoordinates
        coordinateOnlyProgressReceipt
        revisionBOnlyCycleCoordinates ∧
      revisionAOnlyCycleCoordinates.sccMembers ≠
        revisionBOnlyCycleCoordinates.sccMembers := by
  constructor
  · exact ⟨rfl, rfl⟩
  · constructor
    · exact ⟨rfl, rfl⟩
    · decide

def convergedLabelOnlyProgressReceipt : ProgressReceipt :=
  coordinateOnlyProgressReceipt

def regressingLabelOnlyProgressReceipt : ProgressReceipt :=
  { coordinateOnlyProgressReceipt with
    receiptId := "coordinate-only-progress-regressing"
    classification := .regressing }

theorem identicalProgressPayloadCanCarryContradictoryClassifications :
    convergedLabelOnlyProgressReceipt.classification = .converged ∧
      regressingLabelOnlyProgressReceipt.classification = .regressing ∧
      convergedLabelOnlyProgressReceipt.registryDigest =
        regressingLabelOnlyProgressReceipt.registryDigest ∧
      convergedLabelOnlyProgressReceipt.generation =
        regressingLabelOnlyProgressReceipt.generation ∧
      convergedLabelOnlyProgressReceipt.semanticFingerprint =
        regressingLabelOnlyProgressReceipt.semanticFingerprint ∧
      convergedLabelOnlyProgressReceipt.remainingObligationsDigest =
        regressingLabelOnlyProgressReceipt.remainingObligationsDigest := by
  decide

structure SubjectProgressEvidence where
  subject : CompositionObjectSubject
  previousSemanticFingerprint : SemanticFingerprint
  currentSemanticFingerprint : SemanticFingerprint
  fingerprintHistory : List SemanticFingerprint
  previousRemainingObligationsDigest : RemainingObligationsDigest
  currentRemainingObligationsDigest : RemainingObligationsDigest
  deriving DecidableEq, Repr

structure SourceBoundProgressReceipt where
  receiptId : ProgressReceiptId
  registryDigest : CompositionRegistryDigest
  generation : Nat
  cycleObservationId : CycleObservationId
  classification : ProgressClass
  subjectEvidence : List SubjectProgressEvidence
  semanticBudgetRemaining : Nat
  schedulingBudgetRemaining : Nat
  watchdogObservationId : Option String
  deriving DecidableEq, Repr

/--
A canonical fingerprint oscillation returns to the same fingerprint only after
passing through at least one different fingerprint.  The decomposition is an
explicit witness; an opaque domain predicate cannot manufacture it.
-/
def fingerprintHistoryHasCanonicalOscillation
    (history : List SemanticFingerprint) : Prop :=
  ∃ before middle suffix fingerprint,
    history = before ++ (fingerprint :: (middle ++ (fingerprint :: suffix))) ∧
      ∃ changed, changed ∈ middle ∧ changed ≠ fingerprint

theorem arbitraryOscillationPredicateDoesNotProveCanonicalHistory :
    ∃ classify : List SemanticFingerprint → Prop,
      ∃ history,
        classify history ∧
          ¬ fingerprintHistoryHasCanonicalOscillation history := by
  refine ⟨fun _history => True, [], ?_⟩
  simp [fingerprintHistoryHasCanonicalOscillation]

structure SourceBoundProgressContract where
  semanticEquivalent : SubjectProgressEvidence → Prop
  monotoneImprovement : SubjectProgressEvidence → Prop
  semanticRegression : SubjectProgressEvidence → Prop
  semanticIncomparable : SubjectProgressEvidence → Prop
  semanticOscillation : SubjectProgressEvidence → Prop
  obligationsComplete : SubjectProgressEvidence → Prop
  obligationsRemain : SubjectProgressEvidence → Prop

def SourceBoundProgressContractValid :=
  SourceBoundProgressContract → Prop

def SourceBoundProgressReceiptValid :=
  SourceBoundProgressReceipt → Prop

def progressClassificationSupported
    (contract : SourceBoundProgressContract)
    (receipt : SourceBoundProgressReceipt) : Prop :=
  match receipt.classification with
  | .converged =>
      ∀ evidence,
        evidence ∈ receipt.subjectEvidence →
          contract.semanticEquivalent evidence ∧
            contract.obligationsComplete evidence
  | .advancing =>
      (∀ evidence,
        evidence ∈ receipt.subjectEvidence →
          contract.semanticEquivalent evidence ∨
            contract.monotoneImprovement evidence) ∧
        ∃ evidence,
          evidence ∈ receipt.subjectEvidence ∧
            contract.monotoneImprovement evidence
  | .stalled =>
      (∀ evidence,
        evidence ∈ receipt.subjectEvidence →
          contract.semanticEquivalent evidence) ∧
        ∃ evidence,
          evidence ∈ receipt.subjectEvidence ∧
            contract.obligationsRemain evidence
  | .incomparable =>
      ∃ evidence,
        evidence ∈ receipt.subjectEvidence ∧
          contract.semanticIncomparable evidence
  | .regressing =>
      ∃ evidence,
        evidence ∈ receipt.subjectEvidence ∧
          contract.semanticRegression evidence
  | .oscillating =>
      ∃ evidence,
        evidence ∈ receipt.subjectEvidence ∧
          fingerprintHistoryHasCanonicalOscillation evidence.fingerprintHistory ∧
            contract.semanticOscillation evidence
  | .budgetExhausted =>
      receipt.semanticBudgetRemaining = 0 ∨
        receipt.schedulingBudgetRemaining = 0

theorem oscillatingClassificationCarriesCanonicalHistory
    (contract : SourceBoundProgressContract)
    (receipt : SourceBoundProgressReceipt)
    (closed : progressClassificationSupported contract receipt)
    (classification : receipt.classification = .oscillating) :
    ∃ evidence,
      evidence ∈ receipt.subjectEvidence ∧
        fingerprintHistoryHasCanonicalOscillation evidence.fingerprintHistory := by
  unfold progressClassificationSupported at closed
  rw [classification] at closed
  rcases closed with ⟨evidence, member, history, _semantic⟩
  exact ⟨evidence, member, history⟩

def progressEvidenceSubjects
    (receipt : SourceBoundProgressReceipt) :
    List CompositionObjectSubject :=
  receipt.subjectEvidence.map SubjectProgressEvidence.subject

structure SourceBoundProgressEvidenceClosed
    (contractValid : SourceBoundProgressContractValid)
    (progressValid : SourceBoundProgressReceiptValid)
    (observationValid : SourceBoundCycleDetectedObservationValid)
    (contract : SourceBoundProgressContract)
    (registry : SourceBoundCompositionRegistry)
    (fixedPointReceipt : SourceBoundFixedPointReceipt)
    (observation : SourceBoundCycleDetectedObservation)
    (progress : SourceBoundProgressReceipt) : Prop where
  contractValidates : contractValid contract
  progressValidates : progressValid progress
  cycleEvidenceCloses :
    SourceBoundCycleEvidenceClosed
      observationValid
      registry
      fixedPointReceipt
      observation
  progressRegistryMatches :
    progress.registryDigest = observation.registryDigest
  progressGenerationMatches :
    progress.generation = observation.generation
  progressCycleMatches :
    progress.cycleObservationId = observation.observationId
  progressEvidenceCoversExactScc :
    progressEvidenceSubjects progress = observation.sccMembers
  progressEvidenceSubjectsUnique :
    (progressEvidenceSubjects progress).Nodup
  classificationHasContractEvidence :
    progressClassificationSupported contract progress

theorem closedProgressEvidenceSubjectIsVisited
    (contractValid : SourceBoundProgressContractValid)
    (progressValid : SourceBoundProgressReceiptValid)
    (observationValid : SourceBoundCycleDetectedObservationValid)
    (contract : SourceBoundProgressContract)
    (registry : SourceBoundCompositionRegistry)
    (fixedPointReceipt : SourceBoundFixedPointReceipt)
    (observation : SourceBoundCycleDetectedObservation)
    (progress : SourceBoundProgressReceipt)
    (closed :
      SourceBoundProgressEvidenceClosed
        contractValid
        progressValid
        observationValid
        contract
        registry
        fixedPointReceipt
        observation
        progress)
    (evidence : SubjectProgressEvidence)
    (evidenceInReceipt : evidence ∈ progress.subjectEvidence) :
    evidence.subject ∈ fixedPointReceipt.visited := by
  have evidenceSubjectInScope :
      evidence.subject ∈ progressEvidenceSubjects progress := by
    exact List.mem_map.mpr ⟨evidence, evidenceInReceipt, rfl⟩
  have evidenceSubjectInScc : evidence.subject ∈ observation.sccMembers := by
    rw [← closed.progressEvidenceCoversExactScc]
    exact evidenceSubjectInScope
  exact
    closed.cycleEvidenceCloses.observationSubjectClosed.1.2.1
      evidence.subject
      evidenceSubjectInScc

def sourceBoundProgressCycleObject : SourceBoundCompositionObject :=
  { sourceBoundMessageProviderA with
    delegations := [messageProviderSubjectA] }

def sourceBoundProgressCycleRegistry : SourceBoundCompositionRegistry :=
  [sourceBoundProgressCycleObject]

def sourceBoundProgressCycleFixedPointReceipt :
    SourceBoundFixedPointReceipt where
  receiptId := "source-bound-progress-cycle-fixed-point"
  registryDigest := "sha256:source-bound-progress-cycle-registry"
  roots := [messageProviderSubjectA]
  visited := [messageProviderSubjectA]
  pending := []
  effectUniverse := ["external-message"]
  generation := 1
  iterationCount := 1
  stable := true

def sourceBoundProgressCycleObservation :
    SourceBoundCycleDetectedObservation where
  observationId := "source-bound-progress-cycle-observation"
  registryDigest := sourceBoundProgressCycleFixedPointReceipt.registryDigest
  generation := sourceBoundProgressCycleFixedPointReceipt.generation
  closingSource := messageProviderSubjectA
  closingTarget := messageProviderSubjectA
  sccMembers := [messageProviderSubjectA]
  causalPath := [messageProviderSubjectA, messageProviderSubjectA]
  provenanceDigest := "sha256:source-bound-progress-cycle-provenance"
  semanticBudgetConsumed := 1
  schedulingBudgetConsumed := 1
  continuationIdentity := "continuation-source-bound-progress-cycle"

theorem sourceBoundProgressCycleEvidenceCloses :
    SourceBoundCycleEvidenceClosed
      (fun _observation => True)
      sourceBoundProgressCycleRegistry
      sourceBoundProgressCycleFixedPointReceipt
      sourceBoundProgressCycleObservation := by
  constructor
  · trivial
  · rfl
  · exact Nat.le_refl _
  · constructor
    · constructor
      · simp [sourceBoundProgressCycleObservation]
      · constructor
        · intro subject subjectInScc
          simpa [
            sourceBoundProgressCycleObservation,
            sourceBoundProgressCycleFixedPointReceipt
          ] using subjectInScc
        · constructor
          · intro subject subjectInPath
            simpa [
              sourceBoundProgressCycleObservation,
              sourceBoundProgressCycleFixedPointReceipt
            ] using subjectInPath
          · constructor
            · intro subject subjectInPath
              simpa [sourceBoundProgressCycleObservation] using subjectInPath
            · constructor
              · constructor
                · refine
                    ⟨sourceBoundProgressCycleObject,
                      by simp [sourceBoundProgressCycleRegistry],
                      rfl,
                      ?_⟩
                  simp [sourceBoundProgressCycleObject]
                · trivial
              · constructor
                · exact ⟨messageProviderSubjectA, [], rfl⟩
                · constructor
                  · exact ⟨[], rfl⟩
                  · refine
                      ⟨sourceBoundProgressCycleObject,
                        by simp [sourceBoundProgressCycleRegistry],
                        rfl,
                        ?_⟩
                    simp [
                      sourceBoundProgressCycleObservation,
                      sourceBoundProgressCycleObject
                    ]
    · constructor
      · intro source sourceInScc target targetInScc
        have sourceIsA : source = messageProviderSubjectA := by
          simpa [sourceBoundProgressCycleObservation] using sourceInScc
        have targetIsA : target = messageProviderSubjectA := by
          simpa [sourceBoundProgressCycleObservation] using targetInScc
        subst source
        subst target
        exact .refl (by simp [sourceBoundProgressCycleObservation])
      · decide

def progressEvidenceA : SubjectProgressEvidence where
  subject := messageProviderSubjectA
  previousSemanticFingerprint := "sha256:message-a-pending"
  currentSemanticFingerprint := "sha256:message-a-resolved"
  fingerprintHistory :=
    ["sha256:message-a-pending", "sha256:message-a-resolved"]
  previousRemainingObligationsDigest := "sha256:message-a-obligation"
  currentRemainingObligationsDigest := "sha256:no-obligations"

def progressEvidenceB : SubjectProgressEvidence where
  subject := messageProviderSubjectB
  previousSemanticFingerprint := "sha256:message-b-stable"
  currentSemanticFingerprint := "sha256:message-b-stable"
  fingerprintHistory := ["sha256:message-b-stable"]
  previousRemainingObligationsDigest := "sha256:no-obligations"
  currentRemainingObligationsDigest := "sha256:no-obligations"

def sourceBoundCycleProgressContract : SourceBoundProgressContract where
  semanticEquivalent :=
    fun evidence =>
      evidence.previousSemanticFingerprint =
        evidence.currentSemanticFingerprint
  monotoneImprovement :=
    fun evidence =>
      evidence.previousSemanticFingerprint =
          "sha256:message-a-pending" ∧
        evidence.currentSemanticFingerprint =
          "sha256:message-a-resolved"
  semanticRegression := fun _evidence => False
  semanticIncomparable := fun _evidence => False
  semanticOscillation := fun _evidence => False
  obligationsComplete :=
    fun evidence =>
      evidence.currentRemainingObligationsDigest =
        "sha256:no-obligations"
  obligationsRemain :=
    fun evidence =>
      evidence.currentRemainingObligationsDigest ≠
        "sha256:no-obligations"

def sourceBoundCycleProgressReceipt : SourceBoundProgressReceipt where
  receiptId := "source-bound-cycle-progress"
  registryDigest := sourceBoundProgressCycleObservation.registryDigest
  generation := sourceBoundProgressCycleObservation.generation
  cycleObservationId := sourceBoundProgressCycleObservation.observationId
  classification := .advancing
  subjectEvidence := [progressEvidenceA]
  semanticBudgetRemaining := 8
  schedulingBudgetRemaining := 32
  watchdogObservationId := none

theorem completeSourceBoundProgressEvidenceCloses :
    SourceBoundProgressEvidenceClosed
      (fun _contract => True)
      (fun _progress => True)
      (fun _observation => True)
      sourceBoundCycleProgressContract
      sourceBoundProgressCycleRegistry
      sourceBoundProgressCycleFixedPointReceipt
      sourceBoundProgressCycleObservation
      sourceBoundCycleProgressReceipt := by
  constructor
  · trivial
  · trivial
  · exact sourceBoundProgressCycleEvidenceCloses
  · rfl
  · rfl
  · rfl
  · rfl
  · decide
  · constructor
    · intro evidence evidenceInReceipt
      simp [sourceBoundCycleProgressReceipt] at evidenceInReceipt
      subst evidence
      exact Or.inr (by
          simp [
            sourceBoundCycleProgressContract,
            progressEvidenceA
          ])
    · exact
        ⟨progressEvidenceA,
          by simp [sourceBoundCycleProgressReceipt],
          by
            simp [
              sourceBoundCycleProgressContract,
              progressEvidenceA
            ]⟩

theorem closedProgressClassificationHasOwnerEvidence
    (contractValid : SourceBoundProgressContractValid)
    (progressValid : SourceBoundProgressReceiptValid)
    (observationValid : SourceBoundCycleDetectedObservationValid)
    (contract : SourceBoundProgressContract)
    (registry : SourceBoundCompositionRegistry)
    (fixedPointReceipt : SourceBoundFixedPointReceipt)
    (observation : SourceBoundCycleDetectedObservation)
    (progress : SourceBoundProgressReceipt)
    (closed :
      SourceBoundProgressEvidenceClosed
        contractValid
        progressValid
        observationValid
        contract
        registry
        fixedPointReceipt
        observation
        progress) :
    progressClassificationSupported contract progress :=
  closed.classificationHasContractEvidence

end AgenticAILabProof.Enterprise.SourceBoundProgressEvidenceClosure
