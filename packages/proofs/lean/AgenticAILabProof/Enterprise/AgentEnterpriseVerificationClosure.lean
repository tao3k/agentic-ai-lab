-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.AgentVerificationMetricsClosure
import AgenticAILabProof.Enterprise.BundleEvidenceBinding

namespace AgenticAILabProof.Enterprise.AgentEnterpriseVerificationClosure

open AgentActionEvidenceEnvelopeClosure
open AgentActionEnterpriseInvariantClosure
open AgentRedTeamProofRegressionClosure
open AgentVerificationMetricsClosure
open BundleEvidenceBinding

structure AgentEnterpriseVerificationClosed
    (observationValid : AgentObservationEventValid)
    (recoveryValid : AgentRecoveryDecisionProjectionValid)
    (policyAdmits : AgentPolicyAdmits)
    (regressionReceiptValid : AgentProofRegressionReceiptValid)
    (metricsReceiptValid : AgentVerificationMetricsReceiptValid)
    (proofSampleValid : AgentProofSampleValid)
    (escalationSampleValid : AgentEscalationSampleValid)
    (replaySampleValid : AgentReplaySampleValid)
    (resolutionReceiptValid : ResolutionReceiptValid)
    (envelope : AgentActionEvidenceEnvelope)
    (scenario : AgentRedTeamScenario)
    (refinement : AgentPolicyRefinement)
    (regressionReceipt : AgentProofRegressionReceipt)
    (samples : List AgentVerificationSample)
    (metricsReceipt : AgentVerificationMetricsReceipt)
    (bundleVerification : BoundVerificationReceipt)
    (sources : List ResolvedSourceClaim)
    (resolutionReceipts : List ResolutionReceipt) : Prop where
  actionInvariantsClose :
    AgentActionEnterpriseInvariantClosed
      observationValid recoveryValid envelope
  redTeamRegressionCloses :
    AgentProofRegressionClosed
      observationValid
      recoveryValid
      policyAdmits
      regressionReceiptValid
      scenario
      refinement
      regressionReceipt
  metricsClose :
    AgentVerificationMetricsClosed
      metricsReceiptValid
      proofSampleValid
      escalationSampleValid
      replaySampleValid
      samples
      metricsReceipt
  bundleEvidenceCloses :
    proofEvidenceClosed
      envelope.bundleSubject
      bundleVerification
      resolutionReceiptValid
      sources
      resolutionReceipts
  currentActionHasProvedSample :
    ∃ sample ∈ samples,
      sample.actionId = envelope.action.actionId ∧
        sample.decisionId = envelope.recovery.decisionId ∧
        sample.evidenceRoot = envelope.evidenceRoot ∧
        sample.proofDisposition = .proved
  metricsBundleMatchesEnvelope :
    metricsReceipt.independentBundleDigest = envelope.bundleDigest
  regressionBundleMatchesEnvelope :
    regressionReceipt.independentBundleDigest = envelope.bundleDigest

theorem enterpriseVerificationCarriesFourActionInvariants
    {observationValid : AgentObservationEventValid}
    {recoveryValid : AgentRecoveryDecisionProjectionValid}
    {policyAdmits : AgentPolicyAdmits}
    {regressionReceiptValid : AgentProofRegressionReceiptValid}
    {metricsReceiptValid : AgentVerificationMetricsReceiptValid}
    {proofSampleValid : AgentProofSampleValid}
    {escalationSampleValid : AgentEscalationSampleValid}
    {replaySampleValid : AgentReplaySampleValid}
    {resolutionReceiptValid : ResolutionReceiptValid}
    {envelope : AgentActionEvidenceEnvelope}
    {scenario : AgentRedTeamScenario}
    {refinement : AgentPolicyRefinement}
    {regressionReceipt : AgentProofRegressionReceipt}
    {samples : List AgentVerificationSample}
    {metricsReceipt : AgentVerificationMetricsReceipt}
    {bundleVerification : BoundVerificationReceipt}
    {sources : List ResolvedSourceClaim}
    {resolutionReceipts : List ResolutionReceipt}
    (closed :
      AgentEnterpriseVerificationClosed
        observationValid
        recoveryValid
        policyAdmits
        regressionReceiptValid
        metricsReceiptValid
        proofSampleValid
        escalationSampleValid
        replaySampleValid
        resolutionReceiptValid
        envelope
        scenario
        refinement
        regressionReceipt
        samples
        metricsReceipt
        bundleVerification
        sources
        resolutionReceipts) :
    capabilityConfinement envelope ∧
      toolIdentityClosed envelope ∧
      effectContainment envelope ∧
      causalContinuity envelope :=
  enterpriseInvariantClosureCarriesAllFourGuarantees
    closed.actionInvariantsClose

theorem enterpriseVerificationRejectsRegisteredCounterexample
    {observationValid : AgentObservationEventValid}
    {recoveryValid : AgentRecoveryDecisionProjectionValid}
    {policyAdmits : AgentPolicyAdmits}
    {regressionReceiptValid : AgentProofRegressionReceiptValid}
    {metricsReceiptValid : AgentVerificationMetricsReceiptValid}
    {proofSampleValid : AgentProofSampleValid}
    {escalationSampleValid : AgentEscalationSampleValid}
    {replaySampleValid : AgentReplaySampleValid}
    {resolutionReceiptValid : ResolutionReceiptValid}
    {envelope : AgentActionEvidenceEnvelope}
    {scenario : AgentRedTeamScenario}
    {refinement : AgentPolicyRefinement}
    {regressionReceipt : AgentProofRegressionReceipt}
    {samples : List AgentVerificationSample}
    {metricsReceipt : AgentVerificationMetricsReceipt}
    {bundleVerification : BoundVerificationReceipt}
    {sources : List ResolvedSourceClaim}
    {resolutionReceipts : List ResolutionReceipt}
    (closed :
      AgentEnterpriseVerificationClosed
        observationValid
        recoveryValid
        policyAdmits
        regressionReceiptValid
        metricsReceiptValid
        proofSampleValid
        escalationSampleValid
        replaySampleValid
        resolutionReceiptValid
        envelope
        scenario
        refinement
        regressionReceipt
        samples
        metricsReceipt
        bundleVerification
        sources
        resolutionReceipts) :
    ¬ policyAdmits refinement scenario.envelope :=
  closed.redTeamRegressionCloses.policyRejectsCounterexample

theorem enterpriseVerificationReportsDerivedMetrics
    {observationValid : AgentObservationEventValid}
    {recoveryValid : AgentRecoveryDecisionProjectionValid}
    {policyAdmits : AgentPolicyAdmits}
    {regressionReceiptValid : AgentProofRegressionReceiptValid}
    {metricsReceiptValid : AgentVerificationMetricsReceiptValid}
    {proofSampleValid : AgentProofSampleValid}
    {escalationSampleValid : AgentEscalationSampleValid}
    {replaySampleValid : AgentReplaySampleValid}
    {resolutionReceiptValid : ResolutionReceiptValid}
    {envelope : AgentActionEvidenceEnvelope}
    {scenario : AgentRedTeamScenario}
    {refinement : AgentPolicyRefinement}
    {regressionReceipt : AgentProofRegressionReceipt}
    {samples : List AgentVerificationSample}
    {metricsReceipt : AgentVerificationMetricsReceipt}
    {bundleVerification : BoundVerificationReceipt}
    {sources : List ResolvedSourceClaim}
    {resolutionReceipts : List ResolutionReceipt}
    (closed :
      AgentEnterpriseVerificationClosed
        observationValid
        recoveryValid
        policyAdmits
        regressionReceiptValid
        metricsReceiptValid
        proofSampleValid
        escalationSampleValid
        replaySampleValid
        resolutionReceiptValid
        envelope
        scenario
        refinement
        regressionReceipt
        samples
        metricsReceipt
        bundleVerification
        sources
        resolutionReceipts) :
    (proofCoverage metricsReceipt.population =
        ⟨proofCount samples, samples.length⟩) ∧
      (unknownEscalationRate metricsReceipt.population =
        ⟨unknownEscalationCount samples, samples.length⟩) ∧
      (replaySuccess metricsReceipt.population =
        ⟨replaySucceededCount samples, replayAttemptedCount samples⟩) :=
  closedMetricsReportAllThreeEnterpriseRates closed.metricsClose

theorem enterpriseVerificationCarriesReplayBoundProof
    {observationValid : AgentObservationEventValid}
    {recoveryValid : AgentRecoveryDecisionProjectionValid}
    {policyAdmits : AgentPolicyAdmits}
    {regressionReceiptValid : AgentProofRegressionReceiptValid}
    {metricsReceiptValid : AgentVerificationMetricsReceiptValid}
    {proofSampleValid : AgentProofSampleValid}
    {escalationSampleValid : AgentEscalationSampleValid}
    {replaySampleValid : AgentReplaySampleValid}
    {resolutionReceiptValid : ResolutionReceiptValid}
    {envelope : AgentActionEvidenceEnvelope}
    {scenario : AgentRedTeamScenario}
    {refinement : AgentPolicyRefinement}
    {regressionReceipt : AgentProofRegressionReceipt}
    {samples : List AgentVerificationSample}
    {metricsReceipt : AgentVerificationMetricsReceipt}
    {bundleVerification : BoundVerificationReceipt}
    {sources : List ResolvedSourceClaim}
    {resolutionReceipts : List ResolutionReceipt}
    (closed :
      AgentEnterpriseVerificationClosed
        observationValid
        recoveryValid
        policyAdmits
        regressionReceiptValid
        metricsReceiptValid
        proofSampleValid
        escalationSampleValid
        replaySampleValid
        resolutionReceiptValid
        envelope
        scenario
        refinement
        regressionReceipt
        samples
        metricsReceipt
        bundleVerification
        sources
        resolutionReceipts) :
    acceptsBound envelope.bundleSubject bundleVerification :=
  closed.bundleEvidenceCloses.1

theorem mismatchedMetricsBundleRejectsEnterpriseVerification
    (observationValid : AgentObservationEventValid)
    (recoveryValid : AgentRecoveryDecisionProjectionValid)
    (policyAdmits : AgentPolicyAdmits)
    (regressionReceiptValid : AgentProofRegressionReceiptValid)
    (metricsReceiptValid : AgentVerificationMetricsReceiptValid)
    (proofSampleValid : AgentProofSampleValid)
    (escalationSampleValid : AgentEscalationSampleValid)
    (replaySampleValid : AgentReplaySampleValid)
    (resolutionReceiptValid : ResolutionReceiptValid)
    (envelope : AgentActionEvidenceEnvelope)
    (scenario : AgentRedTeamScenario)
    (refinement : AgentPolicyRefinement)
    (regressionReceipt : AgentProofRegressionReceipt)
    (samples : List AgentVerificationSample)
    (metricsReceipt : AgentVerificationMetricsReceipt)
    (bundleVerification : BoundVerificationReceipt)
    (sources : List ResolvedSourceClaim)
    (resolutionReceipts : List ResolutionReceipt)
    (mismatch :
      metricsReceipt.independentBundleDigest ≠ envelope.bundleDigest) :
    ¬ AgentEnterpriseVerificationClosed
      observationValid
      recoveryValid
      policyAdmits
      regressionReceiptValid
      metricsReceiptValid
      proofSampleValid
      escalationSampleValid
      replaySampleValid
      resolutionReceiptValid
      envelope
      scenario
      refinement
      regressionReceipt
      samples
      metricsReceipt
      bundleVerification
      sources
      resolutionReceipts := by
  intro closed
  exact mismatch closed.metricsBundleMatchesEnvelope

end AgenticAILabProof.Enterprise.AgentEnterpriseVerificationClosure
