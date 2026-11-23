// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ProgressiveDisclosureAndOrgRepair {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    doc /* Formalizes ASCENT Progressive Disclosure (L0..L3), dynamic case-driven
           Org facets, and the Two-Stage Org AST Repair pipeline from
           docs/10-19-design/org-elements-gql-context-design.org under strict
           FormalVerificationTaxonomy XOR dispatch. No Scheme code is modified. */

    item def DisclosureDepthProjection {
        attribute elementId : String;
        attribute derivedDepthRank : Integer; // 0=L0, 1=L1, 2=L2, 3=L3
        attribute thinkingBlockFolded : Boolean;
        attribute hasActiveDefeater : Boolean;
    }

    item def StageOneAstRepairResult {
        attribute sourceCut : Integer;
        attribute zeroLlmTokensUsed : Boolean;
        attribute syntaxRepairedCleanly : Boolean;
        attribute preservesIdsAndDefeaters : Boolean;
    }

    item def StageTwoFlashRepairRequest {
        attribute boundSourceCut : Integer;
        attribute failingSubtreeId : String;
        attribute carriesDirectWriteAuthority : Boolean;
    }

    port def DisclosureDeriverPort {
        in item rawNode : DisclosureDepthProjection;
        out item projectedNode : DisclosureDepthProjection;
    }

    port def TwoStageRepairPort {
        in item stageOne : StageOneAstRepairResult;
        out item stageTwoRequest : StageTwoFlashRepairRequest;
    }

    part def AscentDisclosureDeriver {
        port disclosure : DisclosureDeriverPort;
        doc /* Derives L0..L3 disclosure depths at zero LLM token cost; active
               defeaters and explicit drill-downs force full L3 raw spans. */
    }

    part def DeterministicStageOneRepairer {
        port repair : ~TwoStageRepairPort;
        doc /* Stage-1 deterministic AST auto-repair (~90%, 0 tokens): converts
               nested :THINKING: drawers to #+BEGIN_THINKING blocks, closes
               drawers/blocks and recomputes statistics cookies idempotently. */
    }

    part def BoundedStageTwoFlashProposer {
        port intake : TwoStageRepairPort;
        doc /* Stage-2 diagnostic-guided Flash repair proposer (~10%): receives
               only the failing subtree + diagnostics and must re-enter Orgize
               parse and cut checks before publication. */
    }

    part def ProgressiveDisclosureGovernanceSystem {
        part disclosureDeriver : AscentDisclosureDeriver;
        part stageOneRepairer : DeterministicStageOneRepairer;
        part stageTwoProposer : BoundedStageTwoFlashProposer;
        part verifierSuite : OrthogonalVerificationSuite;
        connection escalateRepair connect stageOneRepairer.repair to stageTwoProposer.intake;
    }

    part disclosureSystem : ProgressiveDisclosureGovernanceSystem;

    // 1. Lean Unbounded Disclosure Join-Semilattice & Stage-1 Repair Purity Laws
    requirement disclosureLatticeAndDefeaterFloorLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "48-progressive-disclosure-and-two-stage-org-repair.lean";
        attribute :>> leanTheorems = "maxDepth_idem, maxDepth_comm, maxDepth_assoc, activeDefeater_forces_full_L3_disclosure, foldThinking_preserves_defeaters_and_results";
        doc /* DisclosureDepth forms a join-semilattice L0 <= L1 <= L2 <= L3;
               any active defeater unconditionally forces L3 unmasked output,
               and folding #+BEGIN_THINKING blocks at L2 preserves every
               active defeater and #+RESULTS: block over arbitrary subtrees. */
    }

    requirement stageOneRepairPurityAndNonEscalationLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "48-progressive-disclosure-and-two-stage-org-repair.lean";
        attribute :>> leanTheorems = "stageOneRepair_idem, stageOneRepair_preserves_ids_and_defeaters, stageTwoRequest_carries_zero_write_authority";
        doc /* Deterministic Stage-1 AST repair is idempotent over arbitrary
               Org node lists, preserves every element :ID: and active defeater,
               and Stage-2 Flash repair requests inhabit zero write authority. */
    }

    // 2. Quint Nondeterministic Defeater Arrival & Two-Stage Repair Cut Races
    requirement disclosureAndTwoStageRepairRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "48-progressive-disclosure-and-two-stage-org-repair.qnt";
        attribute :>> quintInvariants = "activeDefeaterNeverConsumedFolded, stageTwoPatchRequiresCurrentCutAndReParse";
        doc /* Under asynchronous active-defeater arrivals, drill-down requests,
               Stage-1 escalations to Stage-2 Flash repair, and concurrent
               source-cut advances, folded L0..L2 views never bypass a live
               defeater and stale/unparsed Stage-2 patches never publish. */
    }

    allocation ownDisclosureDomain allocate disclosureLatticeAndDefeaterFloorLaw to disclosureSystem.disclosureDeriver;
    allocation verifyDisclosureInLean allocate disclosureLatticeAndDefeaterFloorLaw to disclosureSystem.verifierSuite.leanEngine;

    allocation ownStageOneDomain allocate stageOneRepairPurityAndNonEscalationLaw to disclosureSystem.stageOneRepairer;
    allocation verifyStageOneInLean allocate stageOneRepairPurityAndNonEscalationLaw to disclosureSystem.verifierSuite.leanEngine;

    allocation ownRepairRaceDomain allocate disclosureAndTwoStageRepairRace to disclosureSystem.stageTwoProposer;
    allocation verifyRepairRaceInQuint allocate disclosureAndTwoStageRepairRace to disclosureSystem.verifierSuite.quintEngine;

    verification def ProgressiveDisclosureDispatchAndBoundaryContract {
        subject target : ProgressiveDisclosureGovernanceSystem default = disclosureSystem;
        in leanDisclosureAndRepairProven : Boolean;
        in quintDefeaterAndRepairRacesChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in stageTwoRequiresReParseFence : Boolean;
        in mode : Integer;

        attribute dispatchOk : Boolean := false;
        attribute reparseOk : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditDisclosureBoundary;
        action auditDisclosureBoundary {
            assign dispatchOk := leanDisclosureAndRepairProven and quintDefeaterAndRepairRacesChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign reparseOk := stageTwoRequiresReParseFence or mode == 2;
            assign admitted := dispatchOk and reparseOk;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not admitted
            or (leanDisclosureAndRepairProven
                and quintDefeaterAndRepairRacesChecked
                and enginesStrictlyDisjoint
                and stageTwoRequiresReParseFence)
        );
    }
}
