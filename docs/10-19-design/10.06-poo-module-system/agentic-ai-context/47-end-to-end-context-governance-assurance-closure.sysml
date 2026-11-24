// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package EndToEndContextGovernanceClosure {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;
    private import ContextGovernanceBoundary::*;
    private import ContextEpistemicConsolidationGovernance::*;
    private import MultiRepoAgentDeclassification::*;
    private import AscentSecurityBranchOmissionRefinement::*;
    private import TemporalCausalSurvivalMemoryQuotient::*;
    private import OrgSexprGqlCandidateExchange::*;
    private import DurableAgendaSessionSandboxGovernance::*;
    private import ProgressiveDisclosureAndOrgRepair::*;
    private import ScopedDetourFunflowConcurrentContext::*;
    private import DetourTaintConfinementAndCausalAudit::*;
    private import MemoryQuarantineAndKvPrefixSerialization::*;
    private import FunflowCasSingleflightAndExternalSandbox::*;

    doc /* Capstone SysML v2 horizontal & vertical chain closure across all twelve
           upstream planes (Slices 40-46 + Slices 48-52):
           1. Horizontally imports and instantiates all twelve upstream Context
              Governance subsystem models inside the five-station pipeline.
           2. Defines `AuditCapsuleLifecycle` governing hot O(1) cut-stamp use,
              push invalidation on source-cut advance, and zero-LLM cold replay.
           3. Vertically dispatches composed pure pipeline and quotient bridge
              theorems to `47-*.lean` (importing `40..46, 48..52`) and cross-plane
              concurrent races to `47-*.qnt` (importing `s40..s46, s48..s52`), plus
              real Quint ITF trace-replay verification (`QuintTraceScalarReplayContract`). */

    item def DeterministicAuditCapsule {
        attribute orgCutVectorDigest : String;
        attribute sexprGqlExchangeDigest : String;
        attribute bitemporalSurvivalKey : String;
        attribute epistemicProjectionDigest : String;
        attribute governanceThreatAndSodDigest : String;
        attribute sandboxCapIntersectionDigest : String;
        attribute replayableWithoutLlm : Boolean;
    }

    attribute def AllUpstreamStationsQualified;
    attribute def SourceCutOrGrantAdvanced;
    attribute def ColdForensicAuditRequested;

    state def AuditCapsuleLifecycle {
        first start then assembling;
        state assembling;
        state hotApplicableAtLiveCut;
        state invalidatedForLiveDispatch;
        state coldForensicVerified;
        transition sealCapsule first assembling accept AllUpstreamStationsQualified then hotApplicableAtLiveCut;
        transition pushInvalidate first hotApplicableAtLiveCut accept SourceCutOrGrantAdvanced then invalidatedForLiveDispatch;
        transition coldReplayFromHot first hotApplicableAtLiveCut accept ColdForensicAuditRequested then coldForensicVerified;
        transition coldReplayAfterInvalidation first invalidatedForLiveDispatch accept ColdForensicAuditRequested then coldForensicVerified;
    }

    port def StageChainPort {
        out attribute stagePassed : Boolean;
    }

    port def FinalHostIntakePort {
        in item capsule : DeterministicAuditCapsule;
        out attribute cedarAndHostAdmitted : Boolean;
    }

    part def SearchAndExchangeStage {
        part searchSubsystem : HybridSearchAndExchangeSystem;
        port next : StageChainPort;
    }

    part def TemporalSurvivalStage {
        part survivalSubsystem : CausalSurvivalMemorySystem;
        port prev : ~StageChainPort;
        port next : StageChainPort;
    }

    part def EpistemicAndBranchStage {
        part epistemicSubsystem : GovernedEpistemicSystem;
        part branchSubsystem : GovernedSecurityInvestigation;
        part disclosureSubsystem : ProgressiveDisclosureGovernanceSystem;
        part memoryKvSubsystem : MemoryQuarantineAndKvPrefixSystem;
        port prev : ~StageChainPort;
        port next : StageChainPort;
    }

    part def BoundaryAndSandboxStage {
        part boundarySubsystem : GovernedContextSystem;
        part multiRepoSubsystem : MultiRepoCollaborativeSystem;
        part controlAxesSubsystem : GovernedRuntimeControlAxes;
        part concurrentContextSubsystem : ConcurrentSharedContextOrchestrationSystem;
        part absorptionSubsystem : LiteratureAbsorptionGovernanceSystem;
        part funflowCasSandboxSubsystem : FunflowCasSandboxSystem;
        port prev : ~StageChainPort;
        port handoff : ~FinalHostIntakePort;
    }

    part def IndependentCedarRuntimeHost {
        port intake : FinalHostIntakePort;
    }

    part def EndToEndGovernedAgenticPipeline {
        part stageSearch : SearchAndExchangeStage;
        part stageTemporal : TemporalSurvivalStage;
        part stageEpistemic : EpistemicAndBranchStage;
        part stageGovernance : BoundaryAndSandboxStage;
        part cedarHost : IndependentCedarRuntimeHost;
        part verifierSuite : OrthogonalVerificationSuite;
        connection c1 connect stageSearch.next to stageTemporal.prev;
        connection c2 connect stageTemporal.next to stageEpistemic.prev;
        connection c3 connect stageEpistemic.next to stageGovernance.prev;
        connection c4 connect stageGovernance.handoff to cedarHost.intake;
    }

    part pipelineSystem : EndToEndGovernedAgenticPipeline;

    // 1. Lean Cross-Slice Imported Composition & Quotient-Bridge Obligations
    requirement crossSlicePurePipelineCompositionLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "47-end-to-end-context-governance-assurance-closure.lean";
        attribute :>> leanTheorems = "allStagesHold_append, any_refuted_stage_refutes_pipeline, pureGovernanceChain_end_to_end_sound, leanToQuintBoundaryQuotient_sound";
        doc /* Importing Slices 40-46 and 48 in Lean 4, the composed pure
               functional pipeline simultaneously guarantees AST source-block
               pruning, historical cut invariance, defeater retention, L3
               defeater disclosure floor, Stage-1 repair idempotence, secret
               stripping, semilattice restriction refinement, Lethal-Trifecta
               elimination, and exact quotient projection onto Quint guard inputs. */
    }

    requirement deterministicCapsuleReplayPurity : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "47-end-to-end-context-governance-assurance-closure.lean";
        attribute :>> leanTheorems = "replayCapsule_deterministic_without_llm, cut_inequality_invalidates_hot_capsule, assurance_carries_zero_authority";
        doc /* Reconstructing an AuditCapsule is a pure deterministic fold over
               immutable ORG bytes and journal entries (zero LLM parameter),
               cut inequality invalidates hot reuse in O(1), and Governance
               carries zero execution authority. */
    }

    // 2. Quint Cross-Module Composed Push-Invalidation, Host CAS & Cold-Replay Race
    requirement composedMultiPlaneCasAndColdReplayRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "47-end-to-end-context-governance-assurance-closure.qnt";
        attribute :>> quintInvariants = "hostCasRequiresCurrentCapsuleAndLiveUpstreamPlanes, coldAuditReplayPreservedWithoutReopeningStaleLiveHandoff, allTwelveUpstreamSliceInvariantsHold";
        doc /* Importing all twelve upstream Quint protocol modules (s40..s46, s48..s52),
               concurrent source-cut advances, generation advances, omitted-hypothesis
               discoveries, active-defeater disclosure arrivals, shared-context claims,
               confined-detour taint checks, memory-poisoning quarantine, KV-prefix
               stability, FunFlow singleflight/pinned-GC/finalizer guards, cited-evidence
               retractions or grant revocations block stale Host CAS while cold forensic
               replay at cut 1 remains valid. */
    }

    allocation ownPipelineChainDomain allocate crossSlicePurePipelineCompositionLaw to pipelineSystem.stageGovernance;
    allocation verifyPipelineChainInLean allocate crossSlicePurePipelineCompositionLaw to pipelineSystem.verifierSuite.leanEngine;

    allocation ownCapsuleDomain allocate deterministicCapsuleReplayPurity to pipelineSystem.cedarHost;
    allocation verifyCapsuleInLean allocate deterministicCapsuleReplayPurity to pipelineSystem.verifierSuite.leanEngine;

    allocation ownCasRaceDomain allocate composedMultiPlaneCasAndColdReplayRace to pipelineSystem.cedarHost;
    allocation verifyCasRaceInQuint allocate composedMultiPlaneCasAndColdReplayRace to pipelineSystem.verifierSuite.quintEngine;

    verification def EndToEndDispatchAndClosureContract {
        subject target : EndToEndGovernedAgenticPipeline default = pipelineSystem;
        in allNineLeanModulesVerified : Boolean;
        in allNineQuintRaceModelsVerified : Boolean;
        in sysmlDisjointDispatchVerified : Boolean;
        in coldReplayUsesZeroLlmCalls : Boolean;
        in mode : Integer;

        attribute leanOk : Boolean := false;
        attribute quintOk : Boolean := false;
        attribute disjointOk : Boolean := false;
        attribute replayOk : Boolean := false;
        attribute closureQualified : Boolean := false;

        first start then auditEndToEndAssurance;
        action auditEndToEndAssurance {
            assign leanOk := allNineLeanModulesVerified or mode == 1;
            assign quintOk := allNineQuintRaceModelsVerified or mode == 2;
            assign disjointOk := sysmlDisjointDispatchVerified or mode == 3;
            assign replayOk := coldReplayUsesZeroLlmCalls or mode == 4;
            assign closureQualified := leanOk and quintOk and disjointOk and replayOk;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not closureQualified
            or (allNineLeanModulesVerified
                and allNineQuintRaceModelsVerified
                and sysmlDisjointDispatchVerified
                and coldReplayUsesZeroLlmCalls)
        );
    }

    // Real Quint ITF trace-replay oracle: consumes scalar end-state projections
    // extracted directly from Quint ITF JSON traces (positive & counterexample)
    // and checks structural/state safety inside SysML -engine run.
    // sliceId: 40, 41, 42, 43, 44, 45, 46, 47, 48
    verification def QuintTraceScalarReplayContract {
        subject target : EndToEndGovernedAgenticPipeline default = pipelineSystem;
        in sliceId : Integer;
        in traceSteps : Integer;
        in actionConsumed : Boolean;
        in cutOrGenMatched : Boolean;
        in grantOrAuthValid : Boolean;
        in epistemicOrDefeaterSafe : Boolean;

        attribute replayAdmitted : Boolean := false;
        attribute traceNonEmpty : Boolean := false;

        first start then evaluateProjectedTraceState;
        action evaluateProjectedTraceState {
            assign traceNonEmpty := traceSteps >= 1;
            assign replayAdmitted := not actionConsumed
                or (cutOrGenMatched and grantOrAuthValid and epistemicOrDefeaterSafe);
        }
        then done;

        out replayedSlice : Integer = sliceId;
        out observedSteps : Integer = traceSteps;
        return verdict : VerdictKind = PassIf(traceNonEmpty and replayAdmitted);
    }
}
