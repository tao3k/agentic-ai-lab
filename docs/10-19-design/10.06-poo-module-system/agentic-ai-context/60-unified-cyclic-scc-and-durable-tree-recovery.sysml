// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package UnifiedCyclicSccAndDurableRecovery {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    doc /* Formalizes Tarjan SCC condensation of mixed acyclic/cyclic graphs
           (bounded feedback Loops as governed SCC specializations inside
           GraphEngine) and real SQLite WAL crash/restart recovery fencing
           with monotonic owner epoch checks and tamper-evident hash chains. */

    item def CyclicSccExecutionSpec {
        attribute sccId : String;
        attribute isCyclic : Boolean;
        attribute hasTerminationContract : Boolean;
        attribute maxIterations : Integer;
    }

    item def DurableRecoveryDecision {
        attribute recovered : Boolean;
        attribute liveJournalEpoch : Integer;
        attribute openRequiredBranches : Integer;
        attribute postCrashApexAdmitted : Boolean;
    }

    port def SccRecoveryPort {
        in item sccSpec : CyclicSccExecutionSpec;
        out item recoveryDecision : DurableRecoveryDecision;
    }

    part def TarjanSccCondensationGate {
        doc /* Partitions any directed graph into a Condensation DAG: trivial
               SCCs execute once as acyclic DAG nodes; non-trivial cyclic SCCs
               require an explicit CycleTerminationContract with oscillation
               and iteration-budget guards. */
    }

    part def DurableSqliteWalRecoveryGate {
        port recoveryPort : SccRecoveryPort;
        doc /* Persists inert POO Convergent Tree snapshots in SQLite WAL with
               monotonic owner epoch fencing, immutable evidence, tamper-evident
               hash chains, and post-crash unclosed-branch Apex gating. */
    }

    part def CyclicSccAndDurableRecoverySystem {
        part sccCondensationGate : TarjanSccCondensationGate;
        part durableRecoveryGate : DurableSqliteWalRecoveryGate;
        part verifierSuite : OrthogonalVerificationSuite;
    }

    part cyclicRecoverySystem : CyclicSccAndDurableRecoverySystem;

    // 1. Lean Algebraic Laws for Governed Cyclic SCCs & Durable Crash Recovery
    requirement cyclicSccTerminationLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "60-unified-cyclic-scc-and-durable-tree-recovery.lean";
        attribute :>> leanTheorems = "ungovernedCyclicScc_always_refused, repeatedStateDigest_immediately_halts_oscillation, budgetExhaustedCycle_halts_fail_closed, revokedCedarGrant_blocks_unified_graph";
        doc /* Ungoverned cyclic SCCs are unconditionally refused, repeated state
               digests immediately halt oscillation, exhausted budgets halt
               fail-closed, and revoked Cedar grants block all SCC execution. */
    }

    requirement durableSqliteWalRecoveryLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "60-unified-cyclic-scc-and-durable-tree-recovery.lean";
        attribute :>> leanTheorems = "supersededJournalEpoch_rejected_fail_closed, tamperedJournalHashChain_refuses_recovery, recoveredOpenRequiredBranches_block_premature_apex";
        doc /* Superseded journal owner epochs are rejected fail-closed, tampered
               hash chains refuse recovery, and recovered open required branches
               block premature post-crash Apex completion. */
    }

    // 2. Quint Nondeterministic SCC Convergence & Crash-Takeover Races
    requirement cyclicSccAndCrashTakeoverRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "60-unified-cyclic-scc-and-durable-tree-recovery.qnt";
        attribute :>> quintInvariants = "ungovernedCycleNeverExecutes, oscillatingCycleNeverContinues, supersededEpochNeverWritesJournal, postCrashApexRequiresZeroOpenBranchesAndConvergedScc";
        doc /* Under concurrent cyclic SCC iteration, downstream DAG release,
               crash/restart SQLite epoch takeover, and post-crash branch
               reconciliation, all four safety invariants hold exhaustively. */
    }

    allocation ownSccLaw allocate cyclicSccTerminationLaw to cyclicRecoverySystem.sccCondensationGate;
    allocation verifySccInLean allocate cyclicSccTerminationLaw to cyclicRecoverySystem.verifierSuite.leanEngine;

    allocation ownDurLaw allocate durableSqliteWalRecoveryLaw to cyclicRecoverySystem.durableRecoveryGate;
    allocation verifyDurInLean allocate durableSqliteWalRecoveryLaw to cyclicRecoverySystem.verifierSuite.leanEngine;

    allocation ownRecRace allocate cyclicSccAndCrashTakeoverRace to cyclicRecoverySystem.durableRecoveryGate;
    allocation verifyRecRaceInQuint allocate cyclicSccAndCrashTakeoverRace to cyclicRecoverySystem.verifierSuite.quintEngine;

    verification def CyclicSccDurableRecoveryDispatchContract {
        subject target : CyclicSccAndDurableRecoverySystem default = cyclicRecoverySystem;
        in leanAlgebraicLawsProven : Boolean;
        in quintConcurrencyRacesChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in sccRecoveryBoundaryClosed : Boolean;
        in mode : Integer;

        attribute dispatchOk : Boolean := false;
        attribute boundaryOk : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditSccRecoveryBoundary;
        action auditSccRecoveryBoundary {
            assign dispatchOk := leanAlgebraicLawsProven and quintConcurrencyRacesChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign boundaryOk := sccRecoveryBoundaryClosed or mode == 2;
            assign admitted := dispatchOk and boundaryOk;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not admitted
            or (leanAlgebraicLawsProven
                and quintConcurrencyRacesChecked
                and enginesStrictlyDisjoint
                and sccRecoveryBoundaryClosed)
        );
    }
}
