-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityModel

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationModel

open
  AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityModel

abbrev HandoffIdentityRegistrySnapshotModel :=
  Nat → Option HandoffIdentityEvidenceModel

structure HandoffIdentityRegistrySnapshotClassifiedModel
    (snapshot : HandoffIdentityRegistrySnapshotModel) :
    Prop where
  acceptanceEvidenceNonreusing :
    ∀ {left right leftEvidence rightEvidence},
      snapshot left = some leftEvidence →
        snapshot right = some rightEvidence →
          leftEvidence.acceptanceEvidenceIdentity =
              rightEvidence.acceptanceEvidenceIdentity →
            left = right
  observationEvidenceNonreusing :
    ∀ {left right leftEvidence rightEvidence},
      snapshot left = some leftEvidence →
        snapshot right = some rightEvidence →
          leftEvidence.effectiveObservationIdentity =
              rightEvidence.effectiveObservationIdentity →
            left = right

def HandoffIdentityRegistrySnapshotRetains
    (before after : HandoffIdentityRegistrySnapshotModel) :
    Prop :=
  ∀ {key evidence}, before key = some evidence → after key = some evidence

def singletonHandoffIdentityRegistrySnapshot
    (key : Nat)
    (evidence : HandoffIdentityEvidenceModel) :
    HandoffIdentityRegistrySnapshotModel :=
  fun queriedKey =>
    if queriedKey = key then some evidence else none

theorem singletonHandoffIdentityRegistrySnapshotEntry
    {key queriedKey : Nat}
    {evidence found : HandoffIdentityEvidenceModel}
    (entry :
      singletonHandoffIdentityRegistrySnapshot key evidence queriedKey =
        some found) :
    queriedKey = key ∧ found = evidence := by
  by_cases queriedMatches : queriedKey = key
  · subst queriedKey
    have evidenceMatches : evidence = found := by
      simpa [singletonHandoffIdentityRegistrySnapshot] using entry
    exact ⟨rfl, evidenceMatches.symm⟩
  · simp [singletonHandoffIdentityRegistrySnapshot, queriedMatches] at entry

theorem singletonHandoffIdentityRegistrySnapshotClassified
    (key : Nat)
    (evidence : HandoffIdentityEvidenceModel) :
    HandoffIdentityRegistrySnapshotClassifiedModel
      (singletonHandoffIdentityRegistrySnapshot key evidence) := by
  constructor
  · intro left right leftEvidence rightEvidence leftEntry rightEntry _
    exact
      (singletonHandoffIdentityRegistrySnapshotEntry leftEntry).left.trans
        (singletonHandoffIdentityRegistrySnapshotEntry rightEntry).left.symm
  · intro left right leftEvidence rightEvidence leftEntry rightEntry _
    exact
      (singletonHandoffIdentityRegistrySnapshotEntry leftEntry).left.trans
        (singletonHandoffIdentityRegistrySnapshotEntry rightEntry).left.symm

def retainedHandoffIdentityEvidence : HandoffIdentityEvidenceModel where
  beforeCommitment := "commitment-a"
  afterCommitment := "commitment-b"
  transferContractIdentity := "contract-shared"
  authorityEvidenceIdentity := "authority-shared"
  acceptanceEvidenceIdentity := "acceptance-replayed"
  effectiveObservationIdentity := "observation-replayed"

def replayedHandoffIdentityEvidence : HandoffIdentityEvidenceModel where
  beforeCommitment := "commitment-c"
  afterCommitment := "commitment-d"
  transferContractIdentity := "contract-shared"
  authorityEvidenceIdentity := "authority-shared"
  acceptanceEvidenceIdentity := "acceptance-replayed"
  effectiveObservationIdentity := "observation-replayed"

theorem retainedHandoffIdentityEvidenceValid :
    retainedHandoffIdentityEvidence.Valid := by
  simp [HandoffIdentityEvidenceModel.Valid, retainedHandoffIdentityEvidence]

theorem replayedHandoffIdentityEvidenceValid :
    replayedHandoffIdentityEvidence.Valid := by
  simp [HandoffIdentityEvidenceModel.Valid, replayedHandoffIdentityEvidence]

def beforeForgettingRegistry : HandoffIdentityRegistrySnapshotModel :=
  singletonHandoffIdentityRegistrySnapshot 0 retainedHandoffIdentityEvidence

def afterForgettingRegistry : HandoffIdentityRegistrySnapshotModel :=
  singletonHandoffIdentityRegistrySnapshot 1 replayedHandoffIdentityEvidence

theorem snapshotClassificationDoesNotPreventReplayAfterForgetting :
    HandoffIdentityRegistrySnapshotClassifiedModel beforeForgettingRegistry ∧
      HandoffIdentityRegistrySnapshotClassifiedModel afterForgettingRegistry ∧
        retainedHandoffIdentityEvidence.acceptanceEvidenceIdentity =
            replayedHandoffIdentityEvidence.acceptanceEvidenceIdentity ∧
          retainedHandoffIdentityEvidence.effectiveObservationIdentity =
              replayedHandoffIdentityEvidence.effectiveObservationIdentity ∧
            ¬ HandoffIdentityRegistrySnapshotRetains
                beforeForgettingRegistry
                afterForgettingRegistry := by
  refine
    ⟨singletonHandoffIdentityRegistrySnapshotClassified
        0
        retainedHandoffIdentityEvidence,
      singletonHandoffIdentityRegistrySnapshotClassified
        1
        replayedHandoffIdentityEvidence,
      rfl,
      rfl,
      ?_⟩
  intro retains
  have retainedEntry :
      afterForgettingRegistry 0 =
        some retainedHandoffIdentityEvidence :=
    retains (by simp [beforeForgettingRegistry,
      singletonHandoffIdentityRegistrySnapshot])
  simp [afterForgettingRegistry,
    singletonHandoffIdentityRegistrySnapshot] at retainedEntry

def leftForkRegistry : HandoffIdentityRegistrySnapshotModel :=
  singletonHandoffIdentityRegistrySnapshot 0 retainedHandoffIdentityEvidence

def rightForkRegistry : HandoffIdentityRegistrySnapshotModel :=
  singletonHandoffIdentityRegistrySnapshot 1 replayedHandoffIdentityEvidence

def mergedForkRegistry : HandoffIdentityRegistrySnapshotModel :=
  fun key =>
    if key = 0 then
      some retainedHandoffIdentityEvidence
    else if key = 1 then
      some replayedHandoffIdentityEvidence
    else
      none

theorem separatelyClassifiedForksCanConflictWhenMerged :
    HandoffIdentityRegistrySnapshotClassifiedModel leftForkRegistry ∧
      HandoffIdentityRegistrySnapshotClassifiedModel rightForkRegistry ∧
        ¬ HandoffIdentityRegistrySnapshotClassifiedModel mergedForkRegistry := by
  refine
    ⟨singletonHandoffIdentityRegistrySnapshotClassified
        0
        retainedHandoffIdentityEvidence,
      singletonHandoffIdentityRegistrySnapshotClassified
        1
        replayedHandoffIdentityEvidence,
      ?_⟩
  intro mergedClassified
  have collapsed :
      (0 : Nat) = 1 :=
    mergedClassified.acceptanceEvidenceNonreusing
      (leftEvidence := retainedHandoffIdentityEvidence)
      (rightEvidence := replayedHandoffIdentityEvidence)
      (by simp [mergedForkRegistry])
      (by simp [mergedForkRegistry])
      (by rfl)
  exact Nat.zero_ne_one collapsed

structure RecoveryExecutionIdentityModel where
  executionSerial : Nat
  recoveryId : String
  deriving DecidableEq

def recoveryExecutionA : RecoveryExecutionIdentityModel where
  executionSerial := 0
  recoveryId := "recovery-shared"

def recoveryExecutionB : RecoveryExecutionIdentityModel where
  executionSerial := 1
  recoveryId := "recovery-shared"

theorem distinctRecoveryExecutionsCanCollapseToOneStringKey :
    recoveryExecutionA ≠ recoveryExecutionB ∧
      (recoveryExecutionA.recoveryId, 0) =
        (recoveryExecutionB.recoveryId, 0) := by
  decide

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffIdentityRegistryPublicationModel
