-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Std

namespace AgenticAILabProof.Enterprise

/-!
Agentic AI Lab does not fix one enterprise security layer count.  This file models
industry frameworks as typed coordinates and proves the conservative closure
properties required when their guarantees are composed.
-/

inductive AISecurityCoordinateKind where
  | protectionObjectTopology
  | referenceArchitectureTopology
  | threatPathTopology
  | secureDesignPillar
  | lifecycleGovernance
  | controlPlaneTopology
  | evidenceTopology
  | responseTopology
  | accountabilityTopology
  deriving DecidableEq, Repr

inductive CoordinateMappingStatus where
  | exact
  | refinement
  | projection
  | partialMapping
  | conflicting
  | unknown
  deriving DecidableEq, Repr

structure CoordinateMapping where
  sourceFramework : String
  targetFramework : String
  sourceKind : AISecurityCoordinateKind
  targetKind : AISecurityCoordinateKind
  status : CoordinateMappingStatus
  deriving Repr

def CoordinateMapping.coordinatePair
    (mapping : CoordinateMapping) :
    AISecurityCoordinateKind × AISecurityCoordinateKind :=
  (mapping.sourceKind, mapping.targetKind)

theorem CoordinateMappingDoesNotCollapseKinds
    (mapping : CoordinateMapping) :
    mapping.coordinatePair = (mapping.sourceKind, mapping.targetKind) := by
  rfl

structure EnterpriseGuaranteeClaim
    (Subject Authority Evidence Response Owner : Type) where
  claimId : String
  source : String
  coordinate : AISecurityCoordinateKind
  subject : Subject
  invariantId : String
  authority : Authority
  enforcementId : String
  evidence : Evidence
  response : Response
  owner : Owner

def EnterpriseGuaranteeClaim.sourceOwner
    {Subject Authority Evidence Response Owner : Type}
    (claim : EnterpriseGuaranteeClaim
      Subject Authority Evidence Response Owner) :
    String × Owner :=
  (claim.source, claim.owner)

theorem GuaranteeClaimPreservesSourceAndOwner
    {Subject Authority Evidence Response Owner : Type}
    (claim : EnterpriseGuaranteeClaim
      Subject Authority Evidence Response Owner) :
    claim.sourceOwner = (claim.source, claim.owner) := by
  rfl

structure AuthorityBound where
  rank : Nat
  deriving DecidableEq, Repr

def composeAuthority
    (delegated requested : AuthorityBound) : AuthorityBound :=
  ⟨min delegated.rank requested.rank⟩

theorem CrossCoordinateCompositionDoesNotAmplifyAuthority
    (delegated requested : AuthorityBound) :
    (composeAuthority delegated requested).rank ≤ delegated.rank := by
  exact Nat.min_le_left delegated.rank requested.rank

def mappingProofContribution
    (status : CoordinateMappingStatus)
    (claimedCoverage : Nat) : Nat :=
  match status with
  | .conflicting => 0
  | .unknown => 0
  | _ => claimedCoverage

theorem UnknownMappingCannotIncreaseProofCoverage
    (claimedCoverage : Nat) :
    mappingProofContribution .unknown claimedCoverage = 0 := by
  rfl

structure ClaimExecutionEvidenceProjection where
  claimId : String
  executionId : String
  evidenceRoot : String
  deriving DecidableEq, Repr

def ClaimExecutionEvidenceProjection.binds
    (projection : ClaimExecutionEvidenceProjection)
    (claimId executionId : String) : Prop :=
  projection.claimId = claimId ∧
    projection.executionId = executionId

theorem EvidenceProjectionBindsClaimAndExecution
    (projection : ClaimExecutionEvidenceProjection) :
    projection.binds projection.claimId projection.executionId := by
  constructor <;> rfl

structure RecoveryContinuityReceipt where
  actionId : String
  parentActionId : String
  observationId : String
  recoveryDecisionId : String
  evidenceRoot : String
  deriving DecidableEq, Repr

def RecoveryContinuityReceipt.closesCausalContinuity
    (receipt : RecoveryContinuityReceipt)
    (actionId parentActionId observationId recoveryDecisionId evidenceRoot :
      String) : Prop :=
  receipt.actionId = actionId ∧
    receipt.parentActionId = parentActionId ∧
    receipt.observationId = observationId ∧
    receipt.recoveryDecisionId = recoveryDecisionId ∧
    receipt.evidenceRoot = evidenceRoot

theorem RecoveryReceiptClosesCausalContinuity
    (receipt : RecoveryContinuityReceipt) :
    receipt.closesCausalContinuity
      receipt.actionId
      receipt.parentActionId
      receipt.observationId
      receipt.recoveryDecisionId
      receipt.evidenceRoot := by
  simp [RecoveryContinuityReceipt.closesCausalContinuity]

structure DataTransformationPolicyReceipt where
  inputEvidenceRoot : String
  outputEvidenceRoot : String
  requiredPolicyEvidenceRoot : String
  outputPolicyEvidenceRoot : String
  preservesRequiredPolicyEvidence :
    outputPolicyEvidenceRoot = requiredPolicyEvidenceRoot
  deriving Repr

theorem DataTransformationPreservesRequiredPolicyEvidence
    (receipt : DataTransformationPolicyReceipt) :
    receipt.outputPolicyEvidenceRoot =
      receipt.requiredPolicyEvidenceRoot :=
  receipt.preservesRequiredPolicyEvidence

structure IndependentReplayBundle where
  evidenceRoot : String
  decisionRoot : String
  policyVersion : String
  actionDigest : String
  deriving DecidableEq, Repr

structure IndependentReplayDecision where
  decisionRoot : String
  evidenceRoot : String
  policyVersion : String
  actionDigest : String
  deriving DecidableEq, Repr

def replayDecision
    (bundle : IndependentReplayBundle) : IndependentReplayDecision :=
  {
    decisionRoot := bundle.decisionRoot
    evidenceRoot := bundle.evidenceRoot
    policyVersion := bundle.policyVersion
    actionDigest := bundle.actionDigest
  }

theorem ReplayDecisionDoesNotDependOnHiddenSessionState
    (left right : IndependentReplayBundle)
    (sameBundle : left = right) :
    replayDecision left = replayDecision right := by
  cases sameBundle
  rfl

end AgenticAILabProof.Enterprise
