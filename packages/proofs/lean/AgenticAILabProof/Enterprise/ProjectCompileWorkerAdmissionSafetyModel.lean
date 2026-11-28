-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Init

namespace AgenticAILabProof.Enterprise.ProjectCompileWorkerAdmissionSafetyModel

structure WorkerAdmission where
  admittedMemory : Nat
  reservationPerWorker : Nat
  workerCount : Nat
  actualPeakPerWorker : Nat
deriving DecidableEq, Repr

def reservationAdmits (admission : WorkerAdmission) : Prop :=
  admission.workerCount * admission.reservationPerWorker ≤
    admission.admittedMemory

def peakIsSafe (admission : WorkerAdmission) : Prop :=
  admission.workerCount * admission.actualPeakPerWorker ≤
    admission.admittedMemory

theorem underReservedWorkersCanPassAdmissionAndExceedTheEnvelope :
    let admission : WorkerAdmission :=
      { admittedMemory := 4864
        reservationPerWorker := 768
        workerCount := 3
        actualPeakPerWorker := 1700 }
    reservationAdmits admission ∧ ¬ peakIsSafe admission := by
  simp [reservationAdmits, peakIsSafe]

theorem reservationUpperBoundsPeak
    (admission : WorkerAdmission)
    (peakBounded :
      admission.actualPeakPerWorker ≤ admission.reservationPerWorker)
    (admitted : reservationAdmits admission) :
    peakIsSafe admission := by
  exact
    Nat.le_trans
      (Nat.mul_le_mul_left admission.workerCount peakBounded)
      admitted

def selectedWorkerCount
    (configured admittedMemory reservationPerWorker hardMaximum : Nat) : Nat :=
  min configured (min (admittedMemory / reservationPerWorker) hardMaximum)

theorem twoGiBReservationSelectsAtMostTwoWorkersAtTheHardEnvelope :
    selectedWorkerCount 12 4864 2048 3 = 2 := by
  decide

def effectiveReservation (safeDefault requested : Nat) : Nat :=
  max safeDefault requested

theorem environmentOverrideCannotLowerSafeReservation
    (safeDefault requested : Nat) :
    safeDefault ≤ effectiveReservation safeDefault requested := by
  exact Nat.le_max_left _ _

def legacyMachineHardRssCap (minimumCap systemMemory : Nat) : Nat :=
  max minimumCap (systemMemory / 4)

def memoryEvidenceConsistent
    (systemMemory availableMemory baselineRss : Nat) : Prop :=
  availableMemory ≤ systemMemory ∧ baselineRss ≤ systemMemory

inductive MemoryEvidenceReason where
  | availableMemoryExceedsSystemMemory
  | baselineRssExceedsSystemMemory
deriving DecidableEq, Repr

def memoryEvidenceReasons
    (systemMemory availableMemory baselineRss : Nat) :
    List MemoryEvidenceReason :=
  (if availableMemory > systemMemory then
      [MemoryEvidenceReason.availableMemoryExceedsSystemMemory]
    else
      []) ++
  (if baselineRss > systemMemory then
      [MemoryEvidenceReason.baselineRssExceedsSystemMemory]
    else
      [])

def memoryEvidenceAdmitted
    (systemMemory availableMemory baselineRss : Nat) : Prop :=
  memoryEvidenceReasons systemMemory availableMemory baselineRss = []

theorem admittedMemoryEvidenceIsConsistent
    (systemMemory availableMemory baselineRss : Nat)
    (admitted :
      memoryEvidenceAdmitted systemMemory availableMemory baselineRss) :
    memoryEvidenceConsistent systemMemory availableMemory baselineRss := by
  simpa [memoryEvidenceAdmitted, memoryEvidenceReasons,
    memoryEvidenceConsistent] using admitted

theorem contradictoryOverrideEvidenceIsNotConsistent :
    ¬ memoryEvidenceConsistent 1024 4096 2048 := by
  simp [memoryEvidenceConsistent]

theorem contradictoryOverrideEvidenceHasExactTypedReasons :
    memoryEvidenceReasons 1024 4096 2048 =
      [ MemoryEvidenceReason.availableMemoryExceedsSystemMemory,
        MemoryEvidenceReason.baselineRssExceedsSystemMemory ] := by
  decide

theorem contradictoryOverrideEvidenceIsNotAdmitted :
    ¬ memoryEvidenceAdmitted 1024 4096 2048 := by
  simp [memoryEvidenceAdmitted, memoryEvidenceReasons]

theorem legacyGuardCanAdmitContradictoryEvidenceAbovePhysical :
    let systemMemory := 1024
    let availableMemory := 4096
    let headroom := 1
    let baselineRss := 2048
    let machineCap := legacyMachineHardRssCap 5632 systemMemory
    let allocatable := max 1 (availableMemory - headroom)
    let requestedMax := min machineCap (baselineRss + max 768 allocatable)
    let admittedMemory := min allocatable (requestedMax - baselineRss)
    let maxRss := baselineRss + admittedMemory
    availableMemory ≥ headroom + 768 ∧
      requestedMax ≥ baselineRss + 768 ∧
      maxRss > systemMemory := by
  decide

def machineHardRssCap (minimumCap systemMemory : Nat) : Nat :=
  min systemMemory (max minimumCap (systemMemory / 4))

theorem machineHardRssCapNeverExceedsPhysical
    (minimumCap systemMemory : Nat) :
    machineHardRssCap minimumCap systemMemory ≤ systemMemory := by
  exact Nat.min_le_left _ _

theorem guardEnvelopeNeverExceedsPhysical
    (minimumCap systemMemory maxRss : Nat)
    (boundedByMachineCap :
      maxRss ≤ machineHardRssCap minimumCap systemMemory) :
    maxRss ≤ systemMemory := by
  exact Nat.le_trans boundedByMachineCap
    (machineHardRssCapNeverExceedsPhysical minimumCap systemMemory)

theorem oneGiBHostCannotAdvertiseTheProjectMinimum :
    machineHardRssCap 5632 1024 = 1024 := by
  decide

theorem fixedFiveAndHalfGiBCapRejectsOtherwiseSafeThirtyTwoGiBHostPeak :
    5900 > 5632 ∧ 5900 ≤ machineHardRssCap 5632 32768 := by
  decide

theorem eightGiBHostRetainsTheProjectMinimumCap :
    machineHardRssCap 5632 8192 = 5632 := by
  decide

theorem thirtyTwoGiBHostAdmitsEightGiBCap :
    machineHardRssCap 5632 32768 = 8192 := by
  decide

end AgenticAILabProof.Enterprise.ProjectCompileWorkerAdmissionSafetyModel
