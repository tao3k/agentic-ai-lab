-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundProgressEvidenceClosure

namespace AgenticAILabProof.Enterprise.SourceBoundRuntimeWatchdogClosure

open CompositionalEffectUniverse
open CompositionalFixedPointClosure
open SourceBoundCompositionalEffectClosure
open SourceBoundCompositionalFixedPointClosure
open SourceBoundCycleObservationClosure
open SourceBoundProgressEvidenceClosure

inductive RuntimeWatchdogMetric
  | wallClockNanoseconds
  | processCpuNanoseconds
  | schedulingSilenceSteps
  | processTreeResidentSetBytes
  deriving DecidableEq, Repr

inductive RuntimeWatchdogUnit
  | nanoseconds
  | steps
  | bytes
  deriving DecidableEq, Repr

structure RuntimeMemoryAttribution where
  processTreeRssBytes : Nat
  largestProcessId : Nat
  largestProcessRssBytes : Nat
  proportionalSetSizeBytes : Option Nat
  footprintBytes : Option Nat
  deriving DecidableEq, Repr

structure SourceBoundRuntimeWatchdogObservation where
  observationId : String
  registryDigest : CompositionRegistryDigest
  generation : Nat
  cycleObservationId : CycleObservationId
  continuationIdentity : ContinuationIdentity
  runtimeOwnerIdentity : String
  phaseIdentity : String
  metric : RuntimeWatchdogMetric
  unit : RuntimeWatchdogUnit
  observedValue : Nat
  thresholdValue : Nat
  memoryAttribution : Option RuntimeMemoryAttribution
  provenanceDigest : String
  deriving DecidableEq, Repr

def SourceBoundRuntimeWatchdogObservationValid :=
  SourceBoundRuntimeWatchdogObservation → Prop

def SourceBoundRuntimeWatchdogRetryAuthority :=
  SourceBoundRuntimeWatchdogObservation → Prop

def watchdogUnitMatches
    (metric : RuntimeWatchdogMetric)
    (unit : RuntimeWatchdogUnit) : Prop :=
  match metric with
  | .wallClockNanoseconds => unit = .nanoseconds
  | .processCpuNanoseconds => unit = .nanoseconds
  | .schedulingSilenceSteps => unit = .steps
  | .processTreeResidentSetBytes => unit = .bytes

def runtimeMemoryAttributionClosed
    (observedValue : Nat)
    (attribution : RuntimeMemoryAttribution) : Prop :=
  attribution.processTreeRssBytes = observedValue ∧
    attribution.largestProcessRssBytes ≤
      attribution.processTreeRssBytes ∧
    (attribution.proportionalSetSizeBytes ≠ none ∨
      attribution.footprintBytes ≠ none)

def watchdogMetricEvidenceClosed
    (observation : SourceBoundRuntimeWatchdogObservation) : Prop :=
  watchdogUnitMatches observation.metric observation.unit ∧
    observation.thresholdValue < observation.observedValue ∧
    match observation.metric with
    | .processTreeResidentSetBytes =>
        ∃ attribution,
          observation.memoryAttribution = some attribution ∧
            runtimeMemoryAttributionClosed
              observation.observedValue
              attribution
    | _ => observation.memoryAttribution = none

def watchdogReferenceClosed
    (progress : SourceBoundProgressReceipt)
    (observations : List SourceBoundRuntimeWatchdogObservation) : Prop :=
  match progress.watchdogObservationId with
  | none => True
  | some observationId =>
      ∃ observation ∈ observations,
        observation.observationId = observationId

def watchdogCoordinatesMatch
    (progress : SourceBoundProgressReceipt)
    (cycle : SourceBoundCycleDetectedObservation)
    (watchdog : SourceBoundRuntimeWatchdogObservation) : Prop :=
  watchdog.registryDigest = progress.registryDigest ∧
    watchdog.generation = progress.generation ∧
    watchdog.cycleObservationId = cycle.observationId ∧
    watchdog.continuationIdentity = cycle.continuationIdentity

def danglingWatchdogProgressReceipt : SourceBoundProgressReceipt :=
  { sourceBoundCycleProgressReceipt with
    receiptId := "dangling-watchdog-progress"
    watchdogObservationId := some "ghost-watchdog-observation" }

theorem watchdogObservationIdDoesNotProveObservationExists :
    danglingWatchdogProgressReceipt.watchdogObservationId =
        some "ghost-watchdog-observation" ∧
      ¬ watchdogReferenceClosed danglingWatchdogProgressReceipt [] := by
  simp [
    danglingWatchdogProgressReceipt,
    watchdogReferenceClosed
  ]

def coordinateMismatchWatchdogObservation :
    SourceBoundRuntimeWatchdogObservation where
  observationId := "coordinate-mismatch-watchdog"
  registryDigest := "sha256:other-registry"
  generation := sourceBoundProgressCycleObservation.generation + 1
  cycleObservationId := "other-cycle-observation"
  continuationIdentity := "other-continuation"
  runtimeOwnerIdentity := "agentic-ai-lab-runtime"
  phaseIdentity := "fixed-point-evaluation"
  metric := .schedulingSilenceSteps
  unit := .steps
  observedValue := 101
  thresholdValue := 100
  memoryAttribution := none
  provenanceDigest := "sha256:coordinate-mismatch-watchdog"

def coordinateMismatchProgressReceipt : SourceBoundProgressReceipt :=
  { sourceBoundCycleProgressReceipt with
    receiptId := "coordinate-mismatch-progress"
    watchdogObservationId :=
      some coordinateMismatchWatchdogObservation.observationId }

theorem matchingWatchdogIdDoesNotProveCoordinateBinding :
    watchdogReferenceClosed
        coordinateMismatchProgressReceipt
        [coordinateMismatchWatchdogObservation] ∧
      ¬ watchdogCoordinatesMatch
        coordinateMismatchProgressReceipt
        sourceBoundProgressCycleObservation
        coordinateMismatchWatchdogObservation := by
  constructor
  · exact
      ⟨coordinateMismatchWatchdogObservation,
        by simp,
        rfl⟩
  · simp [
      watchdogCoordinatesMatch,
      coordinateMismatchProgressReceipt,
      coordinateMismatchWatchdogObservation,
      sourceBoundCycleProgressReceipt,
      sourceBoundProgressCycleObservation,
      sourceBoundProgressCycleFixedPointReceipt
    ]

def bareProcessTreeRssObservation :
    SourceBoundRuntimeWatchdogObservation where
  observationId := "bare-process-tree-rss"
  registryDigest := sourceBoundProgressCycleObservation.registryDigest
  generation := sourceBoundProgressCycleObservation.generation
  cycleObservationId := sourceBoundProgressCycleObservation.observationId
  continuationIdentity :=
    sourceBoundProgressCycleObservation.continuationIdentity
  runtimeOwnerIdentity := "agentic-ai-lab-runtime"
  phaseIdentity := "fixed-point-evaluation"
  metric := .processTreeResidentSetBytes
  unit := .bytes
  observedValue := 5_348_691_968
  thresholdValue := 5_000_000_000
  memoryAttribution := none
  provenanceDigest := "sha256:bare-process-tree-rss"

theorem scalarTreeRssExceedanceDoesNotProveMemoryAttribution :
    bareProcessTreeRssObservation.thresholdValue <
        bareProcessTreeRssObservation.observedValue ∧
      watchdogUnitMatches
        bareProcessTreeRssObservation.metric
        bareProcessTreeRssObservation.unit ∧
      ¬ watchdogMetricEvidenceClosed bareProcessTreeRssObservation := by
  constructor
  · decide
  · constructor
    · rfl
    · intro closed
      rcases closed with
        ⟨_unitMatches,
          _thresholdExceeded,
          attribution,
          attributionSome,
          _attributionClosed⟩
      simp [bareProcessTreeRssObservation] at attributionSome

structure SourceBoundRuntimeWatchdogBindingClosed
    (watchdogValid : SourceBoundRuntimeWatchdogObservationValid)
    (cycle : SourceBoundCycleDetectedObservation)
    (progress : SourceBoundProgressReceipt)
    (watchdog : SourceBoundRuntimeWatchdogObservation) : Prop where
  watchdogValidates : watchdogValid watchdog
  progressReferencesWatchdog :
    progress.watchdogObservationId = some watchdog.observationId
  watchdogRegistryMatches :
    watchdog.registryDigest = progress.registryDigest
  watchdogGenerationMatches :
    watchdog.generation = progress.generation
  watchdogCycleMatches :
    watchdog.cycleObservationId = cycle.observationId
  watchdogContinuationMatches :
    watchdog.continuationIdentity = cycle.continuationIdentity
  metricEvidenceCloses :
    watchdogMetricEvidenceClosed watchdog

structure SourceBoundRuntimeWatchdogEvidenceClosed
    (contractValid : SourceBoundProgressContractValid)
    (progressValid : SourceBoundProgressReceiptValid)
    (cycleValid : SourceBoundCycleDetectedObservationValid)
    (watchdogValid : SourceBoundRuntimeWatchdogObservationValid)
    (contract : SourceBoundProgressContract)
    (registry : SourceBoundCompositionRegistry)
    (fixedPointReceipt : SourceBoundFixedPointReceipt)
    (cycle : SourceBoundCycleDetectedObservation)
    (progress : SourceBoundProgressReceipt)
    (watchdog : SourceBoundRuntimeWatchdogObservation) : Prop where
  progressEvidenceCloses :
    SourceBoundProgressEvidenceClosed
      contractValid
      progressValid
      cycleValid
      contract
      registry
      fixedPointReceipt
      cycle
      progress
  watchdogBindingCloses :
    SourceBoundRuntimeWatchdogBindingClosed
      watchdogValid
      cycle
      progress
      watchdog

theorem closedWatchdogReferenceBindsRuntimeCoordinates
    (watchdogValid : SourceBoundRuntimeWatchdogObservationValid)
    (cycle : SourceBoundCycleDetectedObservation)
    (progress : SourceBoundProgressReceipt)
    (watchdog : SourceBoundRuntimeWatchdogObservation)
    (closed :
      SourceBoundRuntimeWatchdogBindingClosed
        watchdogValid
        cycle
        progress
        watchdog) :
    progress.watchdogObservationId = some watchdog.observationId ∧
      watchdogCoordinatesMatch progress cycle watchdog ∧
      watchdogMetricEvidenceClosed watchdog := by
  exact
    ⟨closed.progressReferencesWatchdog,
      ⟨closed.watchdogRegistryMatches,
        closed.watchdogGenerationMatches,
        closed.watchdogCycleMatches,
        closed.watchdogContinuationMatches⟩,
      closed.metricEvidenceCloses⟩

def sourceBoundWatchdogProgressReceipt : SourceBoundProgressReceipt :=
  { sourceBoundCycleProgressReceipt with
    receiptId := "source-bound-progress-with-watchdog"
    watchdogObservationId := some "source-bound-memory-watchdog" }

theorem sourceBoundWatchdogProgressEvidenceCloses :
    SourceBoundProgressEvidenceClosed
      (fun _contract => True)
      (fun _progress => True)
      (fun _cycle => True)
      sourceBoundCycleProgressContract
      sourceBoundProgressCycleRegistry
      sourceBoundProgressCycleFixedPointReceipt
      sourceBoundProgressCycleObservation
      sourceBoundWatchdogProgressReceipt := by
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
      have evidenceIsA : evidence = progressEvidenceA := by
        simpa [
          sourceBoundWatchdogProgressReceipt,
          sourceBoundCycleProgressReceipt
        ] using evidenceInReceipt
      subst evidence
      exact Or.inr (by
        simp [
          sourceBoundCycleProgressContract,
          progressEvidenceA
        ])
    · exact
        ⟨progressEvidenceA,
          by
            simp [
              sourceBoundWatchdogProgressReceipt,
              sourceBoundCycleProgressReceipt
            ],
          by
            simp [
              sourceBoundCycleProgressContract,
              progressEvidenceA
            ]⟩

def sourceBoundMemoryAttribution : RuntimeMemoryAttribution where
  processTreeRssBytes := 5_348_691_968
  largestProcessId := 4242
  largestProcessRssBytes := 2_147_483_648
  proportionalSetSizeBytes := some 4_294_967_296
  footprintBytes := none

def sourceBoundMemoryWatchdogObservation :
    SourceBoundRuntimeWatchdogObservation where
  observationId := "source-bound-memory-watchdog"
  registryDigest := sourceBoundWatchdogProgressReceipt.registryDigest
  generation := sourceBoundWatchdogProgressReceipt.generation
  cycleObservationId := sourceBoundProgressCycleObservation.observationId
  continuationIdentity :=
    sourceBoundProgressCycleObservation.continuationIdentity
  runtimeOwnerIdentity := "agentic-ai-lab-runtime"
  phaseIdentity := "fixed-point-evaluation"
  metric := .processTreeResidentSetBytes
  unit := .bytes
  observedValue := sourceBoundMemoryAttribution.processTreeRssBytes
  thresholdValue := 5_000_000_000
  memoryAttribution := some sourceBoundMemoryAttribution
  provenanceDigest := "sha256:source-bound-memory-watchdog"

theorem completeSourceBoundRuntimeWatchdogEvidenceCloses :
    SourceBoundRuntimeWatchdogEvidenceClosed
      (fun _contract => True)
      (fun _progress => True)
      (fun _cycle => True)
      (fun _watchdog => True)
      sourceBoundCycleProgressContract
      sourceBoundProgressCycleRegistry
      sourceBoundProgressCycleFixedPointReceipt
      sourceBoundProgressCycleObservation
      sourceBoundWatchdogProgressReceipt
      sourceBoundMemoryWatchdogObservation := by
  constructor
  · exact sourceBoundWatchdogProgressEvidenceCloses
  · constructor
    · trivial
    · rfl
    · rfl
    · rfl
    · rfl
    · rfl
    · constructor
      · rfl
      · constructor
        · decide
        · exact
            ⟨sourceBoundMemoryAttribution,
              rfl,
              by
                constructor
                · rfl
                · constructor
                  · decide
                  · exact Or.inl (by
                      simp [sourceBoundMemoryAttribution])⟩

theorem completeSourceBoundRuntimeWatchdogBindingCloses :
    SourceBoundRuntimeWatchdogBindingClosed
      (fun _watchdog => True)
      sourceBoundProgressCycleObservation
      sourceBoundWatchdogProgressReceipt
      sourceBoundMemoryWatchdogObservation := by
  constructor
  · trivial
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · constructor
    · rfl
    · constructor
      · decide
      · exact
          ⟨sourceBoundMemoryAttribution,
            rfl,
            by
              constructor
              · rfl
              · constructor
                · decide
                · exact Or.inl (by
                    simp [sourceBoundMemoryAttribution])⟩

theorem progressAndRuntimeWatchdogClosuresCompose
    (contractValid : SourceBoundProgressContractValid)
    (progressValid : SourceBoundProgressReceiptValid)
    (cycleValid : SourceBoundCycleDetectedObservationValid)
    (watchdogValid : SourceBoundRuntimeWatchdogObservationValid)
    (contract : SourceBoundProgressContract)
    (registry : SourceBoundCompositionRegistry)
    (fixedPointReceipt : SourceBoundFixedPointReceipt)
    (cycle : SourceBoundCycleDetectedObservation)
    (progress : SourceBoundProgressReceipt)
    (watchdog : SourceBoundRuntimeWatchdogObservation)
    (progressClosed :
      SourceBoundProgressEvidenceClosed
        contractValid
        progressValid
        cycleValid
        contract
        registry
        fixedPointReceipt
        cycle
        progress)
    (watchdogClosed :
      SourceBoundRuntimeWatchdogBindingClosed
        watchdogValid
        cycle
        progress
        watchdog) :
    SourceBoundRuntimeWatchdogEvidenceClosed
      contractValid
      progressValid
      cycleValid
      watchdogValid
      contract
      registry
      fixedPointReceipt
      cycle
      progress
      watchdog :=
  ⟨progressClosed, watchdogClosed⟩

theorem independentlyClosedProgressAndWatchdogEvidenceCompose
    (contract : SourceBoundProgressContract)
    (progress : SourceBoundProgressReceipt)
    (cycle : SourceBoundCycleDetectedObservation)
    (watchdog : SourceBoundRuntimeWatchdogObservation)
    (classificationSupported :
      progressClassificationSupported contract progress)
    (watchdogClosed :
      SourceBoundRuntimeWatchdogBindingClosed
        (fun _observation => True)
        cycle
        progress
        watchdog) :
    progressClassificationSupported contract progress ∧
      progress.watchdogObservationId = some watchdog.observationId ∧
      watchdogCoordinatesMatch progress cycle watchdog ∧
      watchdogMetricEvidenceClosed watchdog := by
  exact
    ⟨classificationSupported,
      watchdogClosed.progressReferencesWatchdog,
      ⟨watchdogClosed.watchdogRegistryMatches,
        watchdogClosed.watchdogGenerationMatches,
        watchdogClosed.watchdogCycleMatches,
        watchdogClosed.watchdogContinuationMatches⟩,
      watchdogClosed.metricEvidenceCloses⟩

def watchdogConvergedLabelReceipt : SourceBoundProgressReceipt :=
  { sourceBoundWatchdogProgressReceipt with
    receiptId := "watchdog-converged-label"
    classification := .converged }

def watchdogRegressingLabelReceipt : SourceBoundProgressReceipt :=
  { sourceBoundWatchdogProgressReceipt with
    receiptId := "watchdog-regressing-label"
    classification := .regressing }

theorem matchingWatchdogObservationDoesNotDetermineSemanticClass :
    watchdogReferenceClosed
        watchdogConvergedLabelReceipt
        [sourceBoundMemoryWatchdogObservation] ∧
      watchdogReferenceClosed
        watchdogRegressingLabelReceipt
        [sourceBoundMemoryWatchdogObservation] ∧
      watchdogConvergedLabelReceipt.classification = .converged ∧
      watchdogRegressingLabelReceipt.classification = .regressing := by
  simp [
    watchdogReferenceClosed,
    watchdogConvergedLabelReceipt,
    watchdogRegressingLabelReceipt,
    sourceBoundWatchdogProgressReceipt,
    sourceBoundMemoryWatchdogObservation
  ]

theorem runtimeWatchdogObservationDoesNotAuthorizeRetry :
    sourceBoundMemoryWatchdogObservation.runtimeOwnerIdentity =
        "agentic-ai-lab-runtime" ∧
      sourceBoundMemoryWatchdogObservation.phaseIdentity =
        "fixed-point-evaluation" ∧
      ¬ (fun _watchdog : SourceBoundRuntimeWatchdogObservation => False)
        sourceBoundMemoryWatchdogObservation := by
  simp [sourceBoundMemoryWatchdogObservation]

end AgenticAILabProof.Enterprise.SourceBoundRuntimeWatchdogClosure
