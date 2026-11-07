-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.AISecurityCapabilityConformanceAttestationClosure

namespace AgenticAILabProof.Enterprise

/-!
Data and knowledge are first-class protection objects.  This profile keeps
classification, retention, residency, purpose, memory lineage, and erasure
obligations attached to transformations instead of treating them as a
control-plane annotation.
-/

structure DataPolicyLabel where
  classificationRank : Nat
  retentionDeadline : Nat
  residencyZone : String
  purposeId : String
  policyRoot : String
  owner : String
  deriving DecidableEq, Repr

def derivedClassificationRank
    (left right : DataPolicyLabel) : Nat :=
  max left.classificationRank right.classificationRank

def derivedRetentionDeadline
    (left right : DataPolicyLabel) : Nat :=
  min left.retentionDeadline right.retentionDeadline

theorem DerivedDataCannotLowerLeftClassification
    (left right : DataPolicyLabel) :
    left.classificationRank ≤ derivedClassificationRank left right := by
  exact Nat.le_max_left _ _

theorem DerivedDataCannotLowerRightClassification
    (left right : DataPolicyLabel) :
    right.classificationRank ≤ derivedClassificationRank left right := by
  exact Nat.le_max_right _ _

theorem DerivedDataCannotExtendLeftRetention
    (left right : DataPolicyLabel) :
    derivedRetentionDeadline left right ≤ left.retentionDeadline := by
  exact Nat.min_le_left _ _

theorem DerivedDataCannotExtendRightRetention
    (left right : DataPolicyLabel) :
    derivedRetentionDeadline left right ≤ right.retentionDeadline := by
  exact Nat.min_le_right _ _

structure DeclassificationFacts where
  sourceRank : Nat
  targetRank : Nat
  authorityPresent : Bool
  authorityEvidenceBound : Bool
  deriving DecidableEq, Repr

def declassificationAdmitted
    (facts : DeclassificationFacts) : Bool :=
  if facts.targetRank < facts.sourceRank then
    facts.authorityPresent && facts.authorityEvidenceBound
  else
    true

theorem UnauthorizedDeclassificationFailsClosed
    (facts : DeclassificationFacts)
    (isDowngrade : facts.targetRank < facts.sourceRank)
    (missingAuthority : facts.authorityPresent = false) :
    declassificationAdmitted facts = false := by
  simp [declassificationAdmitted, isDowngrade, missingAuthority]

theorem UnboundDeclassificationEvidenceFailsClosed
    (facts : DeclassificationFacts)
    (isDowngrade : facts.targetRank < facts.sourceRank)
    (unboundEvidence : facts.authorityEvidenceBound = false) :
    declassificationAdmitted facts = false := by
  simp [declassificationAdmitted, isDowngrade, unboundEvidence]

structure DataMovementFacts where
  crossesResidencyBoundary : Bool
  residencyAuthorityPresent : Bool
  movementEvidenceBound : Bool
  deriving DecidableEq, Repr

def dataMovementAdmitted
    (facts : DataMovementFacts) : Bool :=
  if facts.crossesResidencyBoundary then
    facts.residencyAuthorityPresent && facts.movementEvidenceBound
  else
    true

theorem UnauthorizedCrossResidencyMovementFailsClosed
    (facts : DataMovementFacts)
    (crossesBoundary : facts.crossesResidencyBoundary = true)
    (missingAuthority : facts.residencyAuthorityPresent = false) :
    dataMovementAdmitted facts = false := by
  simp [dataMovementAdmitted, crossesBoundary, missingAuthority]

theorem CrossResidencyMovementWithoutEvidenceFailsClosed
    (facts : DataMovementFacts)
    (crossesBoundary : facts.crossesResidencyBoundary = true)
    (unboundEvidence : facts.movementEvidenceBound = false) :
    dataMovementAdmitted facts = false := by
  simp [dataMovementAdmitted, crossesBoundary, unboundEvidence]

def retainedDataUseAdmitted
    (currentEpoch retentionDeadline : Nat) : Bool :=
  decide (currentEpoch ≤ retentionDeadline)

theorem ExpiredDataUseFailsClosed
    (currentEpoch retentionDeadline : Nat)
    (expired : retentionDeadline < currentEpoch) :
    retainedDataUseAdmitted currentEpoch retentionDeadline = false := by
  simp [retainedDataUseAdmitted, Nat.not_le_of_gt expired]

structure PurposeUseFacts where
  purposeChanged : Bool
  purposeAuthorityPresent : Bool
  purposeEvidenceBound : Bool
  deriving DecidableEq, Repr

def purposeUseAdmitted
    (facts : PurposeUseFacts) : Bool :=
  if facts.purposeChanged then
    facts.purposeAuthorityPresent && facts.purposeEvidenceBound
  else
    true

theorem UnauthorizedPurposeChangeFailsClosed
    (facts : PurposeUseFacts)
    (changed : facts.purposeChanged = true)
    (missingAuthority : facts.purposeAuthorityPresent = false) :
    purposeUseAdmitted facts = false := by
  simp [purposeUseAdmitted, changed, missingAuthority]

structure MemoryWriteReceipt where
  inputPolicyRoot : String
  outputPolicyRoot : String
  inputLineageRoot : String
  outputParentLineageRoot : String
  policyPreserved : outputPolicyRoot = inputPolicyRoot
  lineageParentBound : outputParentLineageRoot = inputLineageRoot
  deriving Repr

theorem MemoryWritePreservesPolicyAndLineage
    (receipt : MemoryWriteReceipt) :
    receipt.outputPolicyRoot = receipt.inputPolicyRoot ∧
      receipt.outputParentLineageRoot = receipt.inputLineageRoot := by
  exact ⟨receipt.policyPreserved, receipt.lineageParentBound⟩

def dataRetrievalAdmittedAfterErasure
    (erased : Bool) : Bool :=
  !erased

theorem ErasedDataCannotBeRetrieved :
    dataRetrievalAdmittedAfterErasure true = false := by
  rfl

structure DataLineageReplayBundle where
  artifactId : String
  sourceRoot : String
  lineageRoot : String
  policyRoot : String
  evidenceRoot : String
  deriving DecidableEq, Repr

structure DataLineageReplaySummary where
  artifactId : String
  sourceRoot : String
  lineageRoot : String
  policyRoot : String
  evidenceRoot : String
  deriving DecidableEq, Repr

def replayDataLineage
    (bundle : DataLineageReplayBundle) : DataLineageReplaySummary :=
  {
    artifactId := bundle.artifactId
    sourceRoot := bundle.sourceRoot
    lineageRoot := bundle.lineageRoot
    policyRoot := bundle.policyRoot
    evidenceRoot := bundle.evidenceRoot
  }

theorem DataLineageReplayUsesOnlyBundle
    (left right : DataLineageReplayBundle)
    (sameBundle : left = right) :
    replayDataLineage left = replayDataLineage right := by
  cases sameBundle
  rfl

end AgenticAILabProof.Enterprise
