-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.AgentActionEnterpriseInvariantClosure

namespace AgenticAILabProof.Enterprise.AgentRedTeamProofRegressionClosure

open AgentActionEvidenceEnvelopeClosure
open AgentActionEnterpriseInvariantClosure

inductive AgentAttackTechnique where
  | capabilityEscalation
  | toolIdentitySubstitution
  | undeclaredEffect
  | causalChainBreak
  deriving DecidableEq, Repr

structure AgentRedTeamScenario where
  scenarioId : String
  sourceId : String
  technique : AgentAttackTechnique
  envelope : AgentActionEvidenceEnvelope
  threatIntelligenceDigest : String
  provenanceDigest : String
  deriving Repr

structure AgentRedTeamCounterexampleCertificate
    (observationValid : AgentObservationEventValid)
    (recoveryValid : AgentRecoveryDecisionProjectionValid)
    (scenario : AgentRedTeamScenario) : Prop where
  scenarioIdentityPresent : scenario.scenarioId ≠ ""
  sourceIdentityPresent : scenario.sourceId ≠ ""
  threatIntelligencePresent : scenario.threatIntelligenceDigest ≠ ""
  provenancePresent : scenario.provenanceDigest ≠ ""
  violatesEnterpriseInvariant :
    ¬ AgentActionEnterpriseInvariantClosed
      observationValid recoveryValid scenario.envelope

structure AgentPolicyRefinement where
  policyId : String
  previousRevision : String
  policyRevision : String
  refinementDigest : String
  theoremDeclaration : String
  deriving DecidableEq, Repr

def AgentPolicyAdmits :=
  AgentPolicyRefinement → AgentActionEvidenceEnvelope → Prop

structure AgentProofRegressionReceipt where
  receiptId : String
  scenarioId : String
  policyId : String
  policyRevision : String
  theoremDeclaration : String
  independentBundleDigest : String
  counterexampleDigest : String
  passed : Bool
  provenanceDigest : String
  deriving DecidableEq, Repr

def AgentProofRegressionReceiptValid :=
  AgentProofRegressionReceipt → Prop

structure AgentProofRegressionClosed
    (observationValid : AgentObservationEventValid)
    (recoveryValid : AgentRecoveryDecisionProjectionValid)
    (policyAdmits : AgentPolicyAdmits)
    (receiptValid : AgentProofRegressionReceiptValid)
    (scenario : AgentRedTeamScenario)
    (refinement : AgentPolicyRefinement)
    (receipt : AgentProofRegressionReceipt) : Prop where
  counterexampleCloses :
    AgentRedTeamCounterexampleCertificate
      observationValid recoveryValid scenario
  policyRejectsCounterexample :
    ¬ policyAdmits refinement scenario.envelope
  receiptValidates : receiptValid receipt
  receiptIdentityPresent : receipt.receiptId ≠ ""
  independentBundlePresent : receipt.independentBundleDigest ≠ ""
  counterexampleDigestPresent : receipt.counterexampleDigest ≠ ""
  receiptProvenancePresent : receipt.provenanceDigest ≠ ""
  refinementIdentityPresent : refinement.policyId ≠ ""
  refinementRevisionPresent : refinement.policyRevision ≠ ""
  refinementDigestPresent : refinement.refinementDigest ≠ ""
  theoremDeclarationPresent : refinement.theoremDeclaration ≠ ""
  scenarioMatches : receipt.scenarioId = scenario.scenarioId
  policyMatches : receipt.policyId = refinement.policyId
  policyRevisionMatches :
    receipt.policyRevision = refinement.policyRevision
  theoremMatches :
    receipt.theoremDeclaration = refinement.theoremDeclaration
  regressionPassed : receipt.passed = true

inductive AgentRegressionEvidenceView where
  | detectionGuidance (guidance : String)
  | proofReceipt (receipt : AgentProofRegressionReceipt)
  deriving Repr

def EstablishesProofRegression : AgentRegressionEvidenceView → Prop
  | .detectionGuidance _ => False
  | .proofReceipt receipt => receipt.passed = true

theorem detectionGuidanceDoesNotEstablishProofRegression
    (guidance : String) :
    ¬ EstablishesProofRegression
      (.detectionGuidance guidance) := by
  intro established
  exact established

theorem closedRegressionRejectsKnownCounterexample
    {observationValid : AgentObservationEventValid}
    {recoveryValid : AgentRecoveryDecisionProjectionValid}
    {policyAdmits : AgentPolicyAdmits}
    {receiptValid : AgentProofRegressionReceiptValid}
    {scenario : AgentRedTeamScenario}
    {refinement : AgentPolicyRefinement}
    {receipt : AgentProofRegressionReceipt}
    (closed :
      AgentProofRegressionClosed
        observationValid
        recoveryValid
        policyAdmits
        receiptValid
        scenario
        refinement
        receipt) :
    ¬ policyAdmits refinement scenario.envelope :=
  closed.policyRejectsCounterexample

theorem closedRegressionCarriesTypedCounterexample
    {observationValid : AgentObservationEventValid}
    {recoveryValid : AgentRecoveryDecisionProjectionValid}
    {policyAdmits : AgentPolicyAdmits}
    {receiptValid : AgentProofRegressionReceiptValid}
    {scenario : AgentRedTeamScenario}
    {refinement : AgentPolicyRefinement}
    {receipt : AgentProofRegressionReceipt}
    (closed :
      AgentProofRegressionClosed
        observationValid
        recoveryValid
        policyAdmits
        receiptValid
        scenario
        refinement
        receipt) :
    ¬ AgentActionEnterpriseInvariantClosed
      observationValid recoveryValid scenario.envelope :=
  closed.counterexampleCloses.violatesEnterpriseInvariant

theorem stalePolicyRevisionRejectsRegressionReceipt
    (observationValid : AgentObservationEventValid)
    (recoveryValid : AgentRecoveryDecisionProjectionValid)
    (policyAdmits : AgentPolicyAdmits)
    (receiptValid : AgentProofRegressionReceiptValid)
    (scenario : AgentRedTeamScenario)
    (refinement : AgentPolicyRefinement)
    (receipt : AgentProofRegressionReceipt)
    (stale : receipt.policyRevision ≠ refinement.policyRevision) :
    ¬ AgentProofRegressionClosed
      observationValid
      recoveryValid
      policyAdmits
      receiptValid
      scenario
      refinement
      receipt := by
  intro closed
  exact stale closed.policyRevisionMatches

theorem theoremMismatchRejectsRegressionReceipt
    (observationValid : AgentObservationEventValid)
    (recoveryValid : AgentRecoveryDecisionProjectionValid)
    (policyAdmits : AgentPolicyAdmits)
    (receiptValid : AgentProofRegressionReceiptValid)
    (scenario : AgentRedTeamScenario)
    (refinement : AgentPolicyRefinement)
    (receipt : AgentProofRegressionReceipt)
    (mismatch :
      receipt.theoremDeclaration ≠ refinement.theoremDeclaration) :
    ¬ AgentProofRegressionClosed
      observationValid
      recoveryValid
      policyAdmits
      receiptValid
      scenario
      refinement
      receipt := by
  intro closed
  exact mismatch closed.theoremMatches

theorem failedRegressionReceiptDoesNotEstablishProofRegression
    (receipt : AgentProofRegressionReceipt)
    (failed : receipt.passed = false) :
    ¬ EstablishesProofRegression (.proofReceipt receipt) := by
  simpa [EstablishesProofRegression, failed]

end AgenticAILabProof.Enterprise.AgentRedTeamProofRegressionClosure
