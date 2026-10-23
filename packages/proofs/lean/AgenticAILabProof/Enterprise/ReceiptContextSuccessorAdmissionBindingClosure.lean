-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.ReceiptContextMonotonicityClosure
import AgenticAILabProof.Enterprise.ReceiptContextCheckpointClosure

namespace AgenticAILabProof.Enterprise.ReceiptContextSuccessorAdmissionBindingClosure

open AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure
open AgenticAILabProof.Enterprise.ReceiptContextMonotonicityClosure
open AgenticAILabProof.Enterprise.ReceiptContextCheckpointClosure

/-!
RFC45-107 requires successor authority widening and resumption without a fresh
coordinator admission to fail closed.  Context equality and generation
monotonicity alone cannot establish either property, so this module binds the
successor authority envelope, coordinator admission, and verifier watermark in
one closure.
-/

abbrev CapabilityIdentity := Nat
abbrev CoordinatorIdentity := Nat
abbrev AdmissionEpoch := Nat
abbrev ExecutionIdentity := Nat

structure AuthorityContextEnvelope where
  context : ReceiptValidationContext
  capabilities : List CapabilityIdentity
  deriving DecidableEq

def AuthorityDoesNotWiden
    (before after : AuthorityContextEnvelope) : Prop :=
  ∀ capability,
    capability ∈ after.capabilities →
      capability ∈ before.capabilities

structure CoordinatorSuccessorAdmission where
  coordinatorIdentity : CoordinatorIdentity
  admissionEpoch : AdmissionEpoch
  predecessorExecutionIdentity : ExecutionIdentity
  successorExecutionIdentity : ExecutionIdentity
  predecessorContext : ReceiptValidationContext
  successorContext : ReceiptValidationContext
  publicationDomainIdentity : Nat
  deriving DecidableEq

def AdmissionBindsTransition
    (admission : CoordinatorSuccessorAdmission)
    (before after : AuthorityContextEnvelope) : Prop :=
  admission.predecessorContext = before.context ∧
    admission.successorContext = after.context

def AdmissionIsFreshAfter
    (previousAdmissionEpoch : AdmissionEpoch)
    (admission : CoordinatorSuccessorAdmission) : Prop :=
  previousAdmissionEpoch < admission.admissionEpoch

def AdmissionCreatesNewExecution
    (admission : CoordinatorSuccessorAdmission) : Prop :=
  admission.predecessorExecutionIdentity ≠
    admission.successorExecutionIdentity

def AdmissionBindsCoordinator
    (expectedCoordinatorIdentity : CoordinatorIdentity)
    (admission : CoordinatorSuccessorAdmission) : Prop :=
  admission.coordinatorIdentity = expectedCoordinatorIdentity

def AdmissionBindsCheckpoint
    (watermark : TrustedCheckpointWatermark)
    (admission : CoordinatorSuccessorAdmission)
    (after : AuthorityContextEnvelope) : Prop :=
  watermark.publicationDomainIdentity =
      admission.publicationDomainIdentity ∧
    watermark.authorityIdentity = after.context.authorityIdentity ∧
    watermark.minimumGeneration ≤ after.context.authorityGeneration

structure SuccessorAdmissionClosure where
  before : AuthorityContextEnvelope
  after : AuthorityContextEnvelope
  previousAdmissionEpoch : AdmissionEpoch
  admission : CoordinatorSuccessorAdmission
  expectedCoordinatorIdentity : CoordinatorIdentity
  verifierWatermark : TrustedCheckpointWatermark
  contextTransition :
    validAuthorityContextTransition before.context after.context
  noAuthorityWidening : AuthorityDoesNotWiden before after
  exactTransitionBinding : AdmissionBindsTransition admission before after
  freshCoordinatorAdmission :
    AdmissionIsFreshAfter previousAdmissionEpoch admission
  newExecutionIdentity : AdmissionCreatesNewExecution admission
  exactCoordinatorBinding :
    AdmissionBindsCoordinator expectedCoordinatorIdentity admission
  checkpointBinding :
    AdmissionBindsCheckpoint verifierWatermark admission after

theorem closedSuccessorCannotWidenAuthority
    (closure : SuccessorAdmissionClosure)
    (capability : CapabilityIdentity)
    (grantedAfter : capability ∈ closure.after.capabilities) :
    capability ∈ closure.before.capabilities :=
  closure.noAuthorityWidening capability grantedAfter

theorem closedSuccessorRequiresFreshCoordinatorAdmission
    (closure : SuccessorAdmissionClosure) :
    closure.previousAdmissionEpoch < closure.admission.admissionEpoch :=
  closure.freshCoordinatorAdmission

theorem closedAdmissionCreatesNewExecutionIdentity
    (closure : SuccessorAdmissionClosure) :
    closure.admission.predecessorExecutionIdentity ≠
      closure.admission.successorExecutionIdentity :=
  closure.newExecutionIdentity

theorem closedAdmissionTargetsExactSuccessorContext
    (closure : SuccessorAdmissionClosure) :
    closure.admission.predecessorContext = closure.before.context ∧
      closure.admission.successorContext = closure.after.context :=
  closure.exactTransitionBinding

theorem closedAdmissionUsesExpectedCoordinator
    (closure : SuccessorAdmissionClosure) :
    closure.admission.coordinatorIdentity =
      closure.expectedCoordinatorIdentity :=
  closure.exactCoordinatorBinding

theorem closedSuccessorIsCheckpointAdmissible
    (closure : SuccessorAdmissionClosure) :
    closure.verifierWatermark.authorityIdentity =
        closure.after.context.authorityIdentity ∧
      closure.verifierWatermark.minimumGeneration ≤
        closure.after.context.authorityGeneration := by
  exact ⟨closure.checkpointBinding.2.1, closure.checkpointBinding.2.2⟩

def predecessorContext : ReceiptValidationContext :=
  {
    authorityIdentity := 7
    authorityGeneration := 10
    policySnapshotIdentity := 20
    authorizationSnapshotIdentity := 30
    revocationSnapshotIdentity := 40
  }

def successorContext : ReceiptValidationContext :=
  {
    authorityIdentity := 7
    authorityGeneration := 11
    policySnapshotIdentity := 21
    authorizationSnapshotIdentity := 31
    revocationSnapshotIdentity := 41
  }

def predecessorAuthority : AuthorityContextEnvelope :=
  { context := predecessorContext, capabilities := [101] }

def widenedSuccessorAuthority : AuthorityContextEnvelope :=
  { context := successorContext, capabilities := [101, 202] }

theorem contextMonotonicityAlonePermitsAuthorityWidening :
    validAuthorityContextTransition
        predecessorAuthority.context
        widenedSuccessorAuthority.context ∧
      ¬ AuthorityDoesNotWiden
        predecessorAuthority
        widenedSuccessorAuthority := by
  constructor
  · constructor
    · rfl
    · exact Nat.lt_succ_self 10
  · intro noWidening
    have successorHasNewCapability :
        202 ∈ widenedSuccessorAuthority.capabilities := by
      change 202 ∈ [101, 202]
      simp
    have predecessorHasNewCapability :=
      noWidening 202 successorHasNewCapability
    change 202 ∈ [101] at predecessorHasNewCapability
    simp at predecessorHasNewCapability

def narrowedSuccessorAuthority : AuthorityContextEnvelope :=
  { context := successorContext, capabilities := [101] }

def replayedAdmission : CoordinatorSuccessorAdmission :=
  {
    coordinatorIdentity := 9
    admissionEpoch := 5
    predecessorExecutionIdentity := 100
    successorExecutionIdentity := 101
    predecessorContext
    successorContext
    publicationDomainIdentity := 12
  }

theorem exactContextAndNoWideningStillPermitStaleAdmission :
    validAuthorityContextTransition
        predecessorAuthority.context
        narrowedSuccessorAuthority.context ∧
      AuthorityDoesNotWiden
        predecessorAuthority
        narrowedSuccessorAuthority ∧
      AdmissionBindsTransition
        replayedAdmission
        predecessorAuthority
        narrowedSuccessorAuthority ∧
      ¬ AdmissionIsFreshAfter 5 replayedAdmission := by
  constructor
  · constructor
    · rfl
    · exact Nat.lt_succ_self 10
  · constructor
    · intro capability grantedAfter
      change capability ∈ [101] at grantedAfter ⊢
      exact grantedAfter
    · constructor
      · exact ⟨rfl, rfl⟩
      · exact Nat.lt_irrefl 5

def validSuccessorAdmissionClosure : SuccessorAdmissionClosure :=
  {
    before := predecessorAuthority
    after := narrowedSuccessorAuthority
    previousAdmissionEpoch := 5
    admission := {
      coordinatorIdentity := 9
      admissionEpoch := 6
      predecessorExecutionIdentity := 100
      successorExecutionIdentity := 101
      predecessorContext
      successorContext
      publicationDomainIdentity := 12
    }
    expectedCoordinatorIdentity := 9
    verifierWatermark := {
      publicationDomainIdentity := 12
      authorityIdentity := 7
      minimumGeneration := 11
    }
    contextTransition := by
      exact ⟨rfl, Nat.lt_succ_self 10⟩
    noAuthorityWidening := by
      intro capability grantedAfter
      change capability ∈ [101] at grantedAfter ⊢
      exact grantedAfter
    exactTransitionBinding := by exact ⟨rfl, rfl⟩
    freshCoordinatorAdmission := by exact Nat.lt_succ_self 5
    newExecutionIdentity := by
      intro sameExecution
      cases sameExecution
    exactCoordinatorBinding := by rfl
    checkpointBinding := by exact ⟨rfl, rfl, Nat.le_refl 11⟩
  }

theorem concreteSuccessorAdmissionClosureIsClosed :
    validSuccessorAdmissionClosure.after.context.authorityGeneration = 11 ∧
      validSuccessorAdmissionClosure.admission.admissionEpoch = 6 ∧
      AuthorityDoesNotWiden
        validSuccessorAdmissionClosure.before
        validSuccessorAdmissionClosure.after := by
  exact ⟨rfl, rfl, validSuccessorAdmissionClosure.noAuthorityWidening⟩

end AgenticAILabProof.Enterprise.ReceiptContextSuccessorAdmissionBindingClosure
