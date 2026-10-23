-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffModel

structure ResponsibilityAssignmentSnapshotModel where
  commitment : String
  subjectIdentity : String
  responsibilityScopeDigest : String
  accountablePrincipal : String
  effectiveEpoch : Nat
  deriving DecidableEq

def ResponsibilityAssignmentSnapshotModel.Valid
    (assignment : ResponsibilityAssignmentSnapshotModel) : Prop :=
  assignment.commitment ≠ "" ∧
    assignment.subjectIdentity ≠ "" ∧
      assignment.responsibilityScopeDigest ≠ "" ∧
        assignment.accountablePrincipal ≠ ""

structure ResponsibilityTransferModel where
  previousPrincipal : String
  successorPrincipal : String
  subjectIdentity : String
  responsibilityScopeDigest : String
  beforeCommitment : String
  afterCommitment : String
  effectiveEpoch : Nat
  transferContractIdentity : String
  authorityEvidenceIdentity : String
  acceptanceEvidenceIdentity : String
  effectiveObservationIdentity : String
  exactTransferContract : Prop
  transferAuthorityValid : Prop
  successorAccepted : Prop
  effectiveObservationCurrent : Prop
  responsibilityGap : Prop
  overlappingExclusiveAuthority : Prop

def ResponsibilityTransferModel.Admitted
    (before after : ResponsibilityAssignmentSnapshotModel)
    (transfer : ResponsibilityTransferModel) : Prop :=
  before.accountablePrincipal ≠ after.accountablePrincipal ∧
    transfer.previousPrincipal = before.accountablePrincipal ∧
      transfer.successorPrincipal = after.accountablePrincipal ∧
        transfer.subjectIdentity = before.subjectIdentity ∧
          transfer.subjectIdentity = after.subjectIdentity ∧
            transfer.responsibilityScopeDigest =
                before.responsibilityScopeDigest ∧
              transfer.responsibilityScopeDigest =
                  after.responsibilityScopeDigest ∧
                transfer.beforeCommitment = before.commitment ∧
                  transfer.afterCommitment = after.commitment ∧
                    transfer.effectiveEpoch = after.effectiveEpoch ∧
                      transfer.transferContractIdentity ≠ "" ∧
                        transfer.authorityEvidenceIdentity ≠ "" ∧
                          transfer.acceptanceEvidenceIdentity ≠ "" ∧
                            transfer.effectiveObservationIdentity ≠ "" ∧
                              transfer.exactTransferContract ∧
                                transfer.transferAuthorityValid ∧
                                  transfer.successorAccepted ∧
                                    transfer.effectiveObservationCurrent ∧
                                      ¬transfer.responsibilityGap ∧
                                        ¬transfer.overlappingExclusiveAuthority

def ResponsibilityContinuityModel
    (before after : ResponsibilityAssignmentSnapshotModel)
    (transfer : Option ResponsibilityTransferModel) : Prop :=
  (before.accountablePrincipal = after.accountablePrincipal ∧
      before.subjectIdentity = after.subjectIdentity ∧
        before.responsibilityScopeDigest =
          after.responsibilityScopeDigest) ∨
    ∃ handoff,
      transfer = some handoff ∧ handoff.Admitted before after

def detachedAssignmentBefore : ResponsibilityAssignmentSnapshotModel where
  commitment := "commitment-before"
  subjectIdentity := "subject-1"
  responsibilityScopeDigest := "scope-1"
  accountablePrincipal := "accountable-before"
  effectiveEpoch := 7

def detachedAssignmentAfter : ResponsibilityAssignmentSnapshotModel where
  commitment := "commitment-after"
  subjectIdentity := "subject-1"
  responsibilityScopeDigest := "scope-1"
  accountablePrincipal := "accountable-after"
  effectiveEpoch := 7

theorem validAdjacentAssignmentsDoNotImplyResponsibilityHandoff :
    detachedAssignmentBefore.Valid ∧
      detachedAssignmentAfter.Valid ∧
        detachedAssignmentBefore.subjectIdentity =
          detachedAssignmentAfter.subjectIdentity ∧
        detachedAssignmentBefore.responsibilityScopeDigest =
          detachedAssignmentAfter.responsibilityScopeDigest ∧
        detachedAssignmentBefore.accountablePrincipal ≠
          detachedAssignmentAfter.accountablePrincipal ∧
        ¬ResponsibilityContinuityModel
          detachedAssignmentBefore
          detachedAssignmentAfter
          none := by
  simp [
    ResponsibilityAssignmentSnapshotModel.Valid,
    ResponsibilityContinuityModel,
    detachedAssignmentBefore,
    detachedAssignmentAfter
  ]

theorem changedContinuityRequiresAdmittedTransfer
    {before after : ResponsibilityAssignmentSnapshotModel}
    {transfer : Option ResponsibilityTransferModel}
    (changed :
      before.accountablePrincipal ≠ after.accountablePrincipal)
    (continuous :
      ResponsibilityContinuityModel before after transfer) :
    ∃ handoff,
      transfer = some handoff ∧ handoff.Admitted before after := by
  rcases continuous with stable | handoff
  · exact False.elim (changed stable.left)
  · exact handoff

theorem admittedTransferClosesGapAndExclusiveOverlap
    {before after : ResponsibilityAssignmentSnapshotModel}
    {transfer : ResponsibilityTransferModel}
    (admitted : transfer.Admitted before after) :
    ¬transfer.responsibilityGap ∧
      ¬transfer.overlappingExclusiveAuthority := by
  rcases admitted with
    ⟨_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, noGap,
      noOverlap⟩
  exact ⟨noGap, noOverlap⟩

theorem continuityPreservesResponsibilitySubjectAndScope
    {before after : ResponsibilityAssignmentSnapshotModel}
    {transfer : Option ResponsibilityTransferModel}
    (continuous :
      ResponsibilityContinuityModel before after transfer) :
    before.subjectIdentity = after.subjectIdentity ∧
      before.responsibilityScopeDigest =
        after.responsibilityScopeDigest := by
  rcases continuous with stable | handoff
  · exact ⟨stable.right.left, stable.right.right⟩
  · rcases handoff with ⟨transfer, _, admitted⟩
    rcases admitted with
      ⟨_, _, _, subjectBefore, subjectAfter, scopeBefore, scopeAfter, _⟩
    exact
      ⟨subjectBefore.symm.trans subjectAfter,
        scopeBefore.symm.trans scopeAfter⟩

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryEnterpriseResponsibilityHandoffModel
