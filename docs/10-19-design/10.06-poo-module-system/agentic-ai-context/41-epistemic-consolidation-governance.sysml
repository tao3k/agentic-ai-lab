// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextEpistemicConsolidationGovernance {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    item def CompetingHypothesis {
        attribute hypothesisId : String;
        attribute undefeated : Boolean;
        attribute tokenCost : Integer;
    }

    item def ActiveDefeater {
        attribute defeaterId : String;
        attribute targetHypothesisId : String;
    }

    item def OmittedAlternativesReceipt {
        attribute receiptIdentity : String;
        attribute omittedHypothesisCount : Integer;
        attribute claimsExhaustiveCoverage : Boolean;
    }

    item def ConsolidationProposal {
        attribute candidateInsightId : String;
        attribute proposerPrincipal : String;
        attribute evidenceOwnerPrincipal : String;
        attribute approverPrincipal : String;
        attribute boundOutcomeReceiptId : String;
    }

    item def RecallCandidate {
        attribute insightId : String;
        attribute consumerSession : String;
        attribute recalledAsCurrent : Boolean;
        attribute retainedInHistory : Boolean;
    }

    port def EpistemicProjectionPort {
        in item hypothesis : CompetingHypothesis;
        in item defeater : ActiveDefeater;
        out item omissionReceipt : OmittedAlternativesReceipt;
    }

    port def ConsolidationGovernancePort {
        in item proposal : ConsolidationProposal;
        out item recallState : RecallCandidate;
    }

    part def EpistemicContextPlane {
        port projection : ~EpistemicProjectionPort;
    }

    part def MemoryConsolidationPlane {
        port consolidation : ~ConsolidationGovernancePort;
    }

    part def EpistemicGovernanceGate {
        port projectionGate : EpistemicProjectionPort;
        port consolidationGate : ConsolidationGovernancePort;
    }

    part def GovernedEpistemicSystem {
        part epistemicPlane : EpistemicContextPlane;
        part memoryPlane : MemoryConsolidationPlane;
        part governanceGate : EpistemicGovernanceGate;
        part verifierSuite : OrthogonalVerificationSuite;
        connection checkProjection connect epistemicPlane.projection to governanceGate.projectionGate;
        connection checkConsolidation connect memoryPlane.consolidation to governanceGate.consolidationGate;
    }

    part epistemicSystem : GovernedEpistemicSystem;

    // 1. Lean Unbounded Inductive & Frame Obligations
    requirement defeaterKernelListInduction : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "41-epistemic-consolidation-governance.lean";
        attribute :>> leanTheorems = "sumHypothesisCost_append, admitted_projection_preserves_every_active_defeater, budget_below_kernel_refuses_projection";
        doc /* Over arbitrarily long hypothesis and defeater lists, cost is
               additive, every active defeater of a selected hypothesis is
               retained, and sub-kernel budgets refuse fail-closed. */
    }

    requirement omissionPartitionAndRetractionFrame : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "41-epistemic-consolidation-governance.lean";
        attribute :>> leanTheorems = "omitted_live_competitor_forces_receipt_and_non_exhaustive, retract_frame_preserves_unrelated_insights";
        doc /* Omitting any undefeated competitor forces a non-exhaustive
               OmittedAlternativesReceipt, and retracting an outcome premise in
               an unbounded catalog preserves all disjoint insights (frame law). */
    }

    // 2. Quint Nondeterministic Concurrent Interleaving Obligations
    requirement consolidationThreeWaySodRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "41-epistemic-consolidation-governance.qnt";
        attribute :>> quintInvariants = "consolidatedInsightsBindLiveOutcomeAndDistinctRoles";
        doc /* Under asynchronous outcome arrivals, premature consolidation
               requests and self-approval races, only 3-way SoD insights with
               live outcome receipts enter durable memory. */
    }

    requirement crossSessionRecallAndOrgPromotionRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "41-epistemic-consolidation-governance.qnt";
        attribute :>> quintInvariants = "activeRecallFencedAgainstRetractionAndGrantLoss, orgPromotionRequiresExpectedRevisionAndWriteGrant";
        doc /* Concurrent outcome retraction or Session-2 grant revocation
               between recall preparation and consumption withdraws active recall
               while preserving historical lineage, and ORG writes require
               expected-revision CAS. */
    }

    allocation ownKernelDomain allocate defeaterKernelListInduction to epistemicSystem.governanceGate;
    allocation verifyKernelInLean allocate defeaterKernelListInduction to epistemicSystem.verifierSuite.leanEngine;

    allocation ownFrameDomain allocate omissionPartitionAndRetractionFrame to epistemicSystem.memoryPlane;
    allocation verifyFrameInLean allocate omissionPartitionAndRetractionFrame to epistemicSystem.verifierSuite.leanEngine;

    allocation ownSodRaceDomain allocate consolidationThreeWaySodRace to epistemicSystem.governanceGate;
    allocation verifySodRaceInQuint allocate consolidationThreeWaySodRace to epistemicSystem.verifierSuite.quintEngine;

    allocation ownRecallRaceDomain allocate crossSessionRecallAndOrgPromotionRace to epistemicSystem.memoryPlane;
    allocation verifyRecallRaceInQuint allocate crossSessionRecallAndOrgPromotionRace to epistemicSystem.verifierSuite.quintEngine;

    verification def EpistemicDispatchAndBoundaryContract {
        subject target : GovernedEpistemicSystem default = epistemicSystem;
        in leanListAndFrameProven : Boolean;
        in quintCrossSessionRacesChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in orgWriteUsesExplicitGate : Boolean;
        in mode : Integer;

        attribute dispatchValid : Boolean := false;
        attribute orgFenceValid : Boolean := false;
        attribute admitted : Boolean := false;

        first start then checkEpistemicAllocation;
        action checkEpistemicAllocation {
            assign dispatchValid := leanListAndFrameProven and quintCrossSessionRacesChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign orgFenceValid := orgWriteUsesExplicitGate or mode == 2;
            assign admitted := dispatchValid and orgFenceValid;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not admitted
            or (leanListAndFrameProven
                and quintCrossSessionRacesChecked
                and enginesStrictlyDisjoint
                and orgWriteUsesExplicitGate)
        );
    }
}
