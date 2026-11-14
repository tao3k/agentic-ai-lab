-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundProgressEvidenceClosure

namespace AgenticAILabProof.Enterprise.SourceBoundFingerprintHistoryClosure

open AgenticAILabProof.Enterprise.CompositionalEffectUniverse
open AgenticAILabProof.Enterprise.SourceBoundCompositionalEffectClosure
open AgenticAILabProof.Enterprise.SourceBoundCompositionalFixedPointClosure
open AgenticAILabProof.Enterprise.SourceBoundCycleObservationClosure
open AgenticAILabProof.Enterprise.SourceBoundProgressEvidenceClosure

abbrev FingerprintHistoryId := String

structure SourceBoundSemanticFingerprintCheckpoint where
  subject : CompositionObjectSubject
  registryDigest : CompositionRegistryDigest
  generation : Nat
  sequence : Nat
  semanticFingerprint : String
  remainingObligationsDigest : String
  provenanceDigest : String
  deriving DecidableEq, Repr

structure SourceBoundSemanticFingerprintHistory where
  historyId : FingerprintHistoryId
  subject : CompositionObjectSubject
  registryDigest : CompositionRegistryDigest
  checkpoints : List SourceBoundSemanticFingerprintCheckpoint
  provenanceDigest : String
  deriving Repr

def checkpointPrecedes
    (first second : SourceBoundSemanticFingerprintCheckpoint) : Prop :=
  first.sequence < second.sequence ∧
    first.generation ≤ second.generation

def historyCheckpointsSourceBound
    (history : SourceBoundSemanticFingerprintHistory) : Prop :=
  ∀ checkpoint,
    checkpoint ∈ history.checkpoints →
      checkpoint.subject = history.subject ∧
        checkpoint.registryDigest = history.registryDigest

def historyIdentityAndProvenanceClosed
    (history : SourceBoundSemanticFingerprintHistory) : Prop :=
  history.historyId ≠ "" ∧
    history.provenanceDigest ≠ "" ∧
      ∀ checkpoint,
        checkpoint ∈ history.checkpoints →
          checkpoint.provenanceDigest ≠ ""

def historyCheckpointsOrdered
    (history : SourceBoundSemanticFingerprintHistory) : Prop :=
  history.checkpoints.Pairwise checkpointPrecedes

def historyFingerprintProjection
    (history : SourceBoundSemanticFingerprintHistory) : List String :=
  history.checkpoints.map (·.semanticFingerprint)

def historyGenerationBound
    (progress : SourceBoundProgressReceipt)
    (history : SourceBoundSemanticFingerprintHistory) : Prop :=
  ∀ checkpoint,
    checkpoint ∈ history.checkpoints →
      checkpoint.generation ≤ progress.generation

def historyEndsWithEvidenceTransition
    (progress : SourceBoundProgressReceipt)
    (evidence : SubjectProgressEvidence)
    (history : SourceBoundSemanticFingerprintHistory) : Prop :=
  ∃ before previous current,
    history.checkpoints = before ++ [previous, current] ∧
      previous.semanticFingerprint =
        evidence.previousSemanticFingerprint ∧
      current.semanticFingerprint =
        evidence.currentSemanticFingerprint ∧
      previous.remainingObligationsDigest =
        evidence.previousRemainingObligationsDigest ∧
      current.remainingObligationsDigest =
        evidence.currentRemainingObligationsDigest ∧
      previous.subject = evidence.subject ∧
      current.subject = evidence.subject ∧
      current.generation = progress.generation

structure SourceBoundFingerprintHistoryEvidenceClosed
    (progress : SourceBoundProgressReceipt)
    (evidence : SubjectProgressEvidence)
    (history : SourceBoundSemanticFingerprintHistory) : Prop where
  evidenceBelongsToProgress : evidence ∈ progress.subjectEvidence
  historySubjectMatches : history.subject = evidence.subject
  historyRegistryMatches : history.registryDigest = progress.registryDigest
  historyIdentityAndProvenanceCloses :
    historyIdentityAndProvenanceClosed history
  checkpointsSourceBound : historyCheckpointsSourceBound history
  checkpointsOrdered : historyCheckpointsOrdered history
  checkpointsGenerationBound : historyGenerationBound progress history
  fingerprintProjectionMatches :
    evidence.fingerprintHistory = historyFingerprintProjection history
  transitionEndpointMatches :
    historyEndsWithEvidenceTransition progress evidence history

def progressFingerprintHistorySubjects
    (histories : List SourceBoundSemanticFingerprintHistory) :
    List CompositionObjectSubject :=
  histories.map (·.subject)

structure SourceBoundProgressFingerprintHistoriesClosed
    (progress : SourceBoundProgressReceipt)
    (histories : List SourceBoundSemanticFingerprintHistory) : Prop where
  historySubjectsCoverExactEvidence :
    progressFingerprintHistorySubjects histories =
      progressEvidenceSubjects progress
  historySubjectsUnique :
    (progressFingerprintHistorySubjects histories).Nodup
  eachEvidenceHasClosedHistory :
    ∀ evidence,
      evidence ∈ progress.subjectEvidence →
        ∃ history,
          history ∈ histories ∧
            SourceBoundFingerprintHistoryEvidenceClosed
              progress evidence history

structure SourceBoundProgressFingerprintHistoryEvidenceClosed
    (contractValid : SourceBoundProgressContractValid)
    (progressValid : SourceBoundProgressReceiptValid)
    (cycleValid : SourceBoundCycleDetectedObservationValid)
    (contract : SourceBoundProgressContract)
    (registry : SourceBoundCompositionRegistry)
    (fixedPoint : SourceBoundFixedPointReceipt)
    (cycle : SourceBoundCycleDetectedObservation)
    (progress : SourceBoundProgressReceipt)
    (histories : List SourceBoundSemanticFingerprintHistory) : Prop where
  progressEvidenceCloses :
    SourceBoundProgressEvidenceClosed
      contractValid progressValid cycleValid
      contract registry fixedPoint cycle progress
  fingerprintHistoriesClose :
    SourceBoundProgressFingerprintHistoriesClosed progress histories

theorem progressAndFingerprintHistoryClosuresCompose
    {contractValid : SourceBoundProgressContractValid}
    {progressValid : SourceBoundProgressReceiptValid}
    {cycleValid : SourceBoundCycleDetectedObservationValid}
    {contract : SourceBoundProgressContract}
    {registry : SourceBoundCompositionRegistry}
    {fixedPoint : SourceBoundFixedPointReceipt}
    {cycle : SourceBoundCycleDetectedObservation}
    {progress : SourceBoundProgressReceipt}
    {histories : List SourceBoundSemanticFingerprintHistory}
    (progressClosed :
      SourceBoundProgressEvidenceClosed
        contractValid progressValid cycleValid
        contract registry fixedPoint cycle progress)
    (historiesClosed :
      SourceBoundProgressFingerprintHistoriesClosed progress histories) :
    SourceBoundProgressFingerprintHistoryEvidenceClosed
      contractValid progressValid cycleValid
      contract registry fixedPoint cycle progress histories :=
  ⟨progressClosed, historiesClosed⟩

theorem independentlyClosedProgressAndFingerprintHistoryOwnersCompose
    {progressClosure historyClosure : Prop}
    (progressClosed : progressClosure)
    (historyClosed : historyClosure) :
    progressClosure ∧ historyClosure :=
  ⟨progressClosed, historyClosed⟩

def forgedOscillatingProgressEvidence : SubjectProgressEvidence :=
  { progressEvidenceA with
    fingerprintHistory :=
      ["sha256:forged-a", "sha256:forged-b", "sha256:forged-a"] }

theorem rawFingerprintHistoryCanForgeOscillationWithoutCurrentFingerprint :
    fingerprintHistoryHasCanonicalOscillation
        forgedOscillatingProgressEvidence.fingerprintHistory ∧
      forgedOscillatingProgressEvidence.currentSemanticFingerprint ∉
        forgedOscillatingProgressEvidence.fingerprintHistory := by
  constructor
  · refine ⟨[], ["sha256:forged-b"], [], "sha256:forged-a", ?_, ?_⟩
    · rfl
    · exact ⟨"sha256:forged-b", by simp, by decide⟩
  · simp [forgedOscillatingProgressEvidence, progressEvidenceA]

theorem closedHistoryContainsCurrentFingerprint
    {progress : SourceBoundProgressReceipt}
    {evidence : SubjectProgressEvidence}
    {history : SourceBoundSemanticFingerprintHistory}
    (closed :
      SourceBoundFingerprintHistoryEvidenceClosed
        progress evidence history) :
    evidence.currentSemanticFingerprint ∈ evidence.fingerprintHistory := by
  rcases closed.transitionEndpointMatches with
    ⟨before, previous, current, historyEquation,
      _previousFingerprint, currentFingerprint,
      _previousObligations, _currentObligations,
      _previousSubject, _currentSubject, _currentGeneration⟩
  rw [closed.fingerprintProjectionMatches]
  unfold historyFingerprintProjection
  apply List.mem_map.mpr
  refine ⟨current, ?_, currentFingerprint⟩
  rw [historyEquation]
  simp

theorem forgedOscillatingEvidenceCannotCloseAnyHistory
    (progress : SourceBoundProgressReceipt) :
    ¬∃ history,
      SourceBoundFingerprintHistoryEvidenceClosed
        progress forgedOscillatingProgressEvidence history := by
  intro existsClosed
  rcases existsClosed with ⟨history, closed⟩
  exact
    rawFingerprintHistoryCanForgeOscillationWithoutCurrentFingerprint.2
      (closedHistoryContainsCurrentFingerprint closed)

def sourceBoundProgressPreviousCheckpointA :
    SourceBoundSemanticFingerprintCheckpoint :=
  { subject := progressEvidenceA.subject
    registryDigest := sourceBoundCycleProgressReceipt.registryDigest
    generation := sourceBoundCycleProgressReceipt.generation
    sequence := 0
    semanticFingerprint := progressEvidenceA.previousSemanticFingerprint
    remainingObligationsDigest :=
      progressEvidenceA.previousRemainingObligationsDigest
    provenanceDigest := "progress-history-a-previous-provenance" }

def sourceBoundProgressCurrentCheckpointA :
    SourceBoundSemanticFingerprintCheckpoint :=
  { subject := progressEvidenceA.subject
    registryDigest := sourceBoundCycleProgressReceipt.registryDigest
    generation := sourceBoundCycleProgressReceipt.generation
    sequence := 1
    semanticFingerprint := progressEvidenceA.currentSemanticFingerprint
    remainingObligationsDigest :=
      progressEvidenceA.currentRemainingObligationsDigest
    provenanceDigest := "progress-history-a-current-provenance" }

def sourceBoundProgressHistoryA : SourceBoundSemanticFingerprintHistory :=
  { historyId := "source-bound-progress-history-a"
    subject := progressEvidenceA.subject
    registryDigest := sourceBoundCycleProgressReceipt.registryDigest
    checkpoints :=
      [sourceBoundProgressPreviousCheckpointA,
        sourceBoundProgressCurrentCheckpointA]
    provenanceDigest := "source-bound-progress-history-a-provenance" }

theorem sourceBoundProgressHistoryACloses :
    SourceBoundFingerprintHistoryEvidenceClosed
      sourceBoundCycleProgressReceipt progressEvidenceA
      sourceBoundProgressHistoryA := by
  constructor
  · simp [sourceBoundCycleProgressReceipt]
  · rfl
  · rfl
  · simp [
      historyIdentityAndProvenanceClosed,
      sourceBoundProgressHistoryA,
      sourceBoundProgressPreviousCheckpointA,
      sourceBoundProgressCurrentCheckpointA
    ]
  · intro checkpoint member
    simp [
      sourceBoundProgressHistoryA,
      sourceBoundProgressPreviousCheckpointA,
      sourceBoundProgressCurrentCheckpointA
    ] at member
    rcases member with rfl | rfl <;>
      simp [
        sourceBoundProgressHistoryA,
        sourceBoundProgressPreviousCheckpointA,
        sourceBoundProgressCurrentCheckpointA
      ]
  · simp [
      historyCheckpointsOrdered,
      checkpointPrecedes,
      sourceBoundProgressHistoryA,
      sourceBoundProgressPreviousCheckpointA,
      sourceBoundProgressCurrentCheckpointA
    ]
  · intro checkpoint member
    simp [
      sourceBoundProgressHistoryA,
      sourceBoundProgressPreviousCheckpointA,
      sourceBoundProgressCurrentCheckpointA
    ] at member
    rcases member with rfl | rfl <;>
      simp
  · simp [
      historyFingerprintProjection,
      sourceBoundProgressHistoryA,
      sourceBoundProgressPreviousCheckpointA,
      sourceBoundProgressCurrentCheckpointA,
      progressEvidenceA
    ]
  · refine ⟨[], sourceBoundProgressPreviousCheckpointA,
      sourceBoundProgressCurrentCheckpointA, ?_⟩
    simp [
      sourceBoundProgressHistoryA,
      sourceBoundProgressPreviousCheckpointA,
      sourceBoundProgressCurrentCheckpointA
    ]

theorem sourceBoundProgressHistoriesCloseExactEvidence :
    SourceBoundProgressFingerprintHistoriesClosed
      sourceBoundCycleProgressReceipt [sourceBoundProgressHistoryA] := by
  constructor
  · simp [
      progressFingerprintHistorySubjects,
      progressEvidenceSubjects,
      sourceBoundCycleProgressReceipt,
      sourceBoundProgressHistoryA
    ]
  · simp [
      progressFingerprintHistorySubjects,
      sourceBoundProgressHistoryA
    ]
  · intro evidence member
    simp [sourceBoundCycleProgressReceipt] at member
    subst evidence
    exact ⟨sourceBoundProgressHistoryA, by simp,
      sourceBoundProgressHistoryACloses⟩

end AgenticAILabProof.Enterprise.SourceBoundFingerprintHistoryClosure
