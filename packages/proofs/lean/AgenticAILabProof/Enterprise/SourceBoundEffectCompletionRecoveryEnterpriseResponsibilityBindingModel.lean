-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityBindingModel

structure DetachedResponsibilityEvidenceModel where
  commitment : String
  authorityIdentity : String
  accountabilityIdentity : String
  responsibilityScopeDigest : String
  deriving DecidableEq

def DetachedResponsibilityEvidenceModel.Valid
    (evidence : DetachedResponsibilityEvidenceModel) : Prop :=
  evidence.commitment ≠ "" ∧
    evidence.authorityIdentity ≠ "" ∧
      evidence.accountabilityIdentity ≠ "" ∧
        evidence.responsibilityScopeDigest ≠ ""

def detachedResponsibilityEvidenceA : DetachedResponsibilityEvidenceModel where
  commitment := "commitment-1"
  authorityIdentity := "authority-1"
  accountabilityIdentity := "accountable-a"
  responsibilityScopeDigest := "scope-a"

def detachedResponsibilityEvidenceB : DetachedResponsibilityEvidenceModel where
  commitment := "commitment-1"
  authorityIdentity := "authority-1"
  accountabilityIdentity := "accountable-b"
  responsibilityScopeDigest := "scope-b"

theorem nonemptyResponsibilityFieldsDoNotDetermineAssignment :
    detachedResponsibilityEvidenceA.Valid ∧
      detachedResponsibilityEvidenceB.Valid ∧
        detachedResponsibilityEvidenceA.commitment =
          detachedResponsibilityEvidenceB.commitment ∧
        detachedResponsibilityEvidenceA.authorityIdentity =
          detachedResponsibilityEvidenceB.authorityIdentity ∧
        detachedResponsibilityEvidenceA.accountabilityIdentity ≠
          detachedResponsibilityEvidenceB.accountabilityIdentity ∧
        detachedResponsibilityEvidenceA.responsibilityScopeDigest ≠
          detachedResponsibilityEvidenceB.responsibilityScopeDigest := by
  simp [
    DetachedResponsibilityEvidenceModel.Valid,
    detachedResponsibilityEvidenceA,
    detachedResponsibilityEvidenceB
  ]

structure ResponsibilityAssignmentModel where
  assignmentIdentity : String
  commitment : String
  authorityIdentity : String
  accountableIdentity : String
  responsibilityScopeDigest : String
  subjectIdentity : String
  authorityReceiptIdentity : String
  acceptanceEvidenceIdentity : String
  effectiveEpoch : Nat
  deriving DecidableEq

def ResponsibilityAssignmentModel.Valid
    (assignment : ResponsibilityAssignmentModel) : Prop :=
  assignment.assignmentIdentity ≠ "" ∧
    assignment.commitment ≠ "" ∧
      assignment.authorityIdentity ≠ "" ∧
        assignment.accountableIdentity ≠ "" ∧
          assignment.accountableIdentity ≠ assignment.authorityIdentity ∧
            assignment.responsibilityScopeDigest ≠ "" ∧
              assignment.subjectIdentity ≠ "" ∧
                assignment.authorityReceiptIdentity ≠ "" ∧
                  assignment.acceptanceEvidenceIdentity ≠ ""

structure ResponsibilityBindingModel where
  assignment : ResponsibilityAssignmentModel
  authenticityCommitment : String
  cedarCommitment : String
  authenticityAuthorityIdentity : String
  cedarAuthorityIdentity : String
  authenticityAccountabilityIdentity : String
  cedarAccountabilityIdentity : String
  authenticityResponsibilityScopeDigest : String
  cedarResponsibilityScopeDigest : String
  authorizationSubjectIdentity : String
  recoveryEpoch : Nat
  assignmentValid : assignment.Valid
  authenticityCommitmentMatches :
    authenticityCommitment = assignment.commitment
  cedarCommitmentMatches :
    cedarCommitment = assignment.commitment
  authenticityAuthorityMatches :
    authenticityAuthorityIdentity = assignment.authorityIdentity
  cedarAuthorityMatches :
    cedarAuthorityIdentity = assignment.authorityIdentity
  authenticityAccountabilityMatches :
    authenticityAccountabilityIdentity = assignment.accountableIdentity
  cedarAccountabilityMatches :
    cedarAccountabilityIdentity = assignment.accountableIdentity
  authenticityResponsibilityMatches :
    authenticityResponsibilityScopeDigest =
      assignment.responsibilityScopeDigest
  cedarResponsibilityMatches :
    cedarResponsibilityScopeDigest = assignment.responsibilityScopeDigest
  subjectMatches :
    authorizationSubjectIdentity = assignment.subjectIdentity
  epochMatches :
    recoveryEpoch = assignment.effectiveEpoch

theorem responsibilityBindingDeterminesAccountability
    (binding : ResponsibilityBindingModel) :
    binding.authenticityAccountabilityIdentity =
        binding.cedarAccountabilityIdentity ∧
      binding.cedarAccountabilityIdentity =
        binding.assignment.accountableIdentity := by
  constructor
  · exact binding.authenticityAccountabilityMatches.trans
      binding.cedarAccountabilityMatches.symm
  · exact binding.cedarAccountabilityMatches

theorem responsibilityBindingDeterminesScope
    (binding : ResponsibilityBindingModel) :
    binding.authenticityResponsibilityScopeDigest =
        binding.cedarResponsibilityScopeDigest ∧
      binding.cedarResponsibilityScopeDigest =
        binding.assignment.responsibilityScopeDigest := by
  constructor
  · exact binding.authenticityResponsibilityMatches.trans
      binding.cedarResponsibilityMatches.symm
  · exact binding.cedarResponsibilityMatches

theorem responsibilityBindingDeterminesCommitment
    (binding : ResponsibilityBindingModel) :
    binding.authenticityCommitment = binding.cedarCommitment ∧
      binding.cedarCommitment = binding.assignment.commitment := by
  constructor
  · exact binding.authenticityCommitmentMatches.trans
      binding.cedarCommitmentMatches.symm
  · exact binding.cedarCommitmentMatches

theorem responsibilityBindingEnforcesDistinctAccountability
    (binding : ResponsibilityBindingModel) :
    binding.assignment.accountableIdentity ≠
      binding.assignment.authorityIdentity :=
  binding.assignmentValid.right.right.right.right.left

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityBindingModel
