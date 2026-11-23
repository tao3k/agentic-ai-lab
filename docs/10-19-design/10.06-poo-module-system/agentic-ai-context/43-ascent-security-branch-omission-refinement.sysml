// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package AscentSecurityBranchOmissionRefinement {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    item def SecurityHypothesisNode {
        attribute hypothesisId : String;
        attribute missingClaimCount : Integer;
        attribute hypotheticalModelFit : Boolean;
    }

    item def InvestigatorProposedBranch {
        attribute branchId : String;
        attribute isReadOnlyProbe : Boolean;
        attribute destructiveUnderOmittedHypothesis : Boolean;
    }

    item def BranchHypothesisMatrixEvaluation {
        attribute evaluatedHypothesisCount : Integer;
        attribute omissionReceiptPresent : Boolean;
    }

    item def BranchGovernanceVerdict {
        attribute readDiscriminatorEligible : Boolean;
        attribute destructiveRemediationEligible : Boolean;
        attribute carriesActionAuthority : Boolean;
    }

    port def SecurityBranchAssessmentPort {
        in item hypothesis : SecurityHypothesisNode;
        in item branch : InvestigatorProposedBranch;
        in item matrix : BranchHypothesisMatrixEvaluation;
        out item verdict : BranchGovernanceVerdict;
    }

    part def AscentSecurityInferencePlane {
        port branchEval : ~SecurityBranchAssessmentPort;
    }

    part def SecurityBranchGovernanceGate {
        port assessment : SecurityBranchAssessmentPort;
    }

    part def GovernedSecurityInvestigation {
        part inferencePlane : AscentSecurityInferencePlane;
        part governanceGate : SecurityBranchGovernanceGate;
        part verifierSuite : OrthogonalVerificationSuite;
        connection governBranches connect inferencePlane.branchEval to governanceGate.assessment;
    }

    part investigationSystem : GovernedSecurityInvestigation;

    // 1. Lean Unbounded Matrix Antitonicity & Invariance Algebra
    requirement branchMatrixAntitonicityAndInvariance : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "43-ascent-security-branch-omission-refinement.lean";
        attribute :>> leanTheorems = "safeForAll_antitone_in_hypotheses, missing_claim_count_irrelevant_to_discriminator, hypothetical_fit_irrelevant_to_safety";
        doc /* Over unbounded hypothesis lists, universal branch safety is
               antitone as competing hypotheses grow, and perturbing
               missing-claim counts or hypothetical fit scores leaves both
               pair discrimination and destructive-cell safety strictly invariant. */
    }

    requirement matrixCompletenessAndOmissionQuotient : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "43-ascent-security-branch-omission-refinement.lean";
        attribute :>> leanTheorems = "all_projected_evaluated_iff_matrix_complete, omissionFlag_true_iff_nonempty_gap";
        doc /* Exact equivalence between decidable boolean matrix scans and
               universal set membership over arbitrarily many projected and
               omitted hypotheses. */
    }

    // 2. Quint Nondeterministic Dynamic Hypothesis Discovery & Remediation Race
    requirement lateHypothesisDiscoveryVsRemediationRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "43-ascent-security-branch-omission-refinement.qnt";
        attribute :>> quintInvariants = "destructiveRemediationBlockedUnderOmittedCompetitors, readProbePermittedUnderOmissionWithLiveReadGrant, omissionReceiptAccuratelyTracksUnprojectedCompetitors";
        doc /* When ASCENT discovers a new undefeated competing hypothesis
               exceeding the projection budget while destructive remediation is
               prepared, consumption fails closed while read-only discriminating
               probes remain eligible until they resolve the omitted hypothesis. */
    }

    allocation ownMatrixDomain allocate branchMatrixAntitonicityAndInvariance to investigationSystem.inferencePlane;
    allocation verifyMatrixInLean allocate branchMatrixAntitonicityAndInvariance to investigationSystem.verifierSuite.leanEngine;

    allocation ownQuotientDomain allocate matrixCompletenessAndOmissionQuotient to investigationSystem.governanceGate;
    allocation verifyQuotientInLean allocate matrixCompletenessAndOmissionQuotient to investigationSystem.verifierSuite.leanEngine;

    allocation ownDiscoveryRaceDomain allocate lateHypothesisDiscoveryVsRemediationRace to investigationSystem.governanceGate;
    allocation verifyDiscoveryRaceInQuint allocate lateHypothesisDiscoveryVsRemediationRace to investigationSystem.verifierSuite.quintEngine;

    verification def SecurityBranchDispatchAndBoundaryContract {
        subject target : GovernedSecurityInvestigation default = investigationSystem;
        in leanMatrixAlgebraProven : Boolean;
        in quintDiscoveryRaceChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in inferenceCarriesZeroAuthority : Boolean;
        in mode : Integer;

        attribute dispatchValid : Boolean := false;
        attribute nonAuthorityValid : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditBranchBoundary;
        action auditBranchBoundary {
            assign dispatchValid := leanMatrixAlgebraProven and quintDiscoveryRaceChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign nonAuthorityValid := inferenceCarriesZeroAuthority and mode != 2;
            assign admitted := dispatchValid and (nonAuthorityValid or mode == 2);
        }
        then done;

        return verdict : VerdictKind = PassIf(
            nonAuthorityValid
            and (not admitted
                or (leanMatrixAlgebraProven
                    and quintDiscoveryRaceChecked
                    and enginesStrictlyDisjoint
                    and inferenceCarriesZeroAuthority))
        );
    }
}
