// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package GraphEngineConvergentTree {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    doc /* Formalizes the unified GraphEngine architecture where DAGs,
           convergent trees, relational obligation graphs, and bounded cyclic
           feedback subgraphs are all governed graph patterns:
           - Disjoint read/write FunFlow C4 DAG fan-out executes with 0 subagents
             and 0 LLM orchestration calls; overlapping write footprints serialize.
           - Every subagent is a subordinate branch anchored strictly to the
             shared ContextTrunk (liveCut, kvPrefixDigest, servingApexId) across
             3 kinds: ContextEnrichmentDetour, DivergentExplorationBranch, and
             SubordinateTaskBranch.
           - A branch can complete a local task, NEVER directly finalize the Trunk;
             all branches serve the Trunk and converge into the Apex via C4
             priority + Slice 50 absorption + ASCENT obligation reconciliation. */

    item def SharedContextBranchSpec {
        attribute branchId : String;
        attribute branchKind : String;
        attribute sharedContextCut : Integer;
        attribute kvPrefixDigest : String;
        attribute servingApexId : String;
        attribute canFinalizeTrunk : Boolean;
    }

    item def ApexConvergenceDecision {
        attribute converged : Boolean;
        attribute subagentsFromDag : Integer;
        attribute counterexamplesPreserved : Boolean;
        attribute optionalBranchesSuperseded : Boolean;
    }

    port def ConvergentTreePort {
        in item branchSpec : SharedContextBranchSpec;
        out item decision : ApexConvergenceDecision;
    }

    part def FunflowC4DagFrontierGate {
        doc /* Executes disjoint read/write FunFlow tasks in parallel DAG waves
               with 0 subagents and 0 LLM calls; serializes write conflicts and
               causal edges under C4 strategy. */
    }

    part def SharedContextTrunkAndApexGate {
        port treePort : ConvergentTreePort;
        doc /* Anchors every subordinate branch to the shared ContextTrunk,
               refuses direct branch trunk-finality, absorbs contributions in C4
               order, preserves counterexample-core, and supersedes optional
               branches upon Apex convergence. */
    }

    part def UnifiedGraphEngineSystem {
        part dagFrontierGate : FunflowC4DagFrontierGate;
        part trunkApexGate : SharedContextTrunkAndApexGate;
        part verifierSuite : OrthogonalVerificationSuite;
    }

    part unifiedGraphEngine : UnifiedGraphEngineSystem;

    // 1. Lean Algebraic Laws for DAG/Branch Separation & Trunk-Serving Convergent Tree
    requirement dagFrontierAndBranchSeparationLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "59-graph-engine-convergent-tree-and-apex-join.lean";
        attribute :>> leanTheorems = "disjointParallelDagFrontier_spawns_zero_subagents, overlappingWriteFootprint_never_parallelized, isolatedOrDetachedBranch_always_refused";
        doc /* Disjoint FunFlow DAG fan-out spawns zero subagents and uses zero
               LLM calls; write conflicts strictly serialize; isolated or detached
               subagent branch spawns are unconditionally refused. */
    }

    requirement subordinateBranchAndApexConvergenceLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "59-graph-engine-convergent-tree-and-apex-join.lean";
        attribute :>> leanTheorems = "branchCompletion_never_finalizes_trunk_directly, staleBranchContribution_never_pollutes_trunk_yet_preserves_counterexamples, unclosedRequiredBranch_blocks_apex_convergence, apexConvergence_supersedes_remaining_optional_branches";
        doc /* Subordinate branches can complete local tasks yet never finalize
               the Trunk directly; stale cut/epoch submissions never pollute Trunk
               evidence while monotonically keeping counterexamples; active
               required branches block Apex convergence and converged Apex
               supersedes remaining optional branches. */
    }

    // 2. Quint Nondeterministic DAG, Branch & Apex Interleaving Races
    requirement convergentTreeApexInterleavingRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "59-graph-engine-convergent-tree-and-apex-join.qnt";
        attribute :>> quintInvariants = "parallelDagNeverSpawnsSubagents, noIsolatedUnsharedSubagentSpawned, subordinateBranchNeverDirectlyFinalizesTrunk, apexConvergenceClearsOptionalAndRequiresZeroActiveBranches";
        doc /* Under concurrent disjoint DAG fan-out, subordinate branch spawning,
               local task completion, Trunk cut advances, and Apex convergence,
               all four GraphEngine safety invariants hold exhaustively. */
    }

    allocation ownDagSepLaw allocate dagFrontierAndBranchSeparationLaw to unifiedGraphEngine.dagFrontierGate;
    allocation verifyDagSepInLean allocate dagFrontierAndBranchSeparationLaw to unifiedGraphEngine.verifierSuite.leanEngine;

    allocation ownApexLaw allocate subordinateBranchAndApexConvergenceLaw to unifiedGraphEngine.trunkApexGate;
    allocation verifyApexInLean allocate subordinateBranchAndApexConvergenceLaw to unifiedGraphEngine.verifierSuite.leanEngine;

    allocation ownTreeRace allocate convergentTreeApexInterleavingRace to unifiedGraphEngine.trunkApexGate;
    allocation verifyTreeRaceInQuint allocate convergentTreeApexInterleavingRace to unifiedGraphEngine.verifierSuite.quintEngine;

    verification def ConvergentTreeDispatchContract {
        subject target : UnifiedGraphEngineSystem default = unifiedGraphEngine;
        in leanAlgebraicLawsProven : Boolean;
        in quintConcurrencyRacesChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in treeBoundaryClosed : Boolean;
        in mode : Integer;

        attribute dispatchOk : Boolean := false;
        attribute boundaryOk : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditTreeBoundary;
        action auditTreeBoundary {
            assign dispatchOk := leanAlgebraicLawsProven and quintConcurrencyRacesChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign boundaryOk := treeBoundaryClosed or mode == 2;
            assign admitted := dispatchOk and boundaryOk;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not admitted
            or (leanAlgebraicLawsProven
                and quintConcurrencyRacesChecked
                and enginesStrictlyDisjoint
                and treeBoundaryClosed)
        );
    }
}
