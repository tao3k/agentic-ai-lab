// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package AscentGovernedLoopTermination {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    doc /* Formalizes the ASCENT-Governed Loop Engine v2 termination guarantee,
           exact-cycle & A <-> B oscillation detection, zero-progress stall
           escalation, upstream governance safety dominance (Slices 50-55),
           and absorbing halt / human-endorsed reopen boundary under
           FormalVerificationTaxonomy XOR dispatch. */

    item def LoopTurnFingerprint {
        attribute turnId : Integer;
        attribute stateDigest : String;
        attribute actionDigest : String;
        attribute failureSignature : String;
        attribute progressMeasure : Integer;
        attribute stepBudgetRemaining : Integer;
    }

    item def AscentLoopVerdictPacket {
        attribute verdictKind : String;       // haltGovernanceBlocked | haltConverged | haltCycleDetected | haltStalledNoProgress | haltBudgetExhausted | admitNextStep
        attribute halted : Boolean;
        attribute escalateHumanInbox : Boolean;
        attribute actionAuthorized : Boolean;
    }

    port def LoopTurnObservationPort {
        in item turnFp : LoopTurnFingerprint;
        out item verdict : AscentLoopVerdictPacket;
    }

    part def AscentTerminationGovernor {
        port turnIn : LoopTurnObservationPort;
        doc /* Evaluates gerbil-ascent relational fixpoint over visited states,
               directed transition edges, failure signatures, progress measure
               deltas, monotonic budgets, and upstream governance gates. */
    }

    part def GovernedLoopExecutionBoundary {
        port verdictIn : LoopTurnObservationPort;
        doc /* Mediates ContextAssemblyPipeline, MCP/CaMeL guards,
               GovernedFunflowRunner (CAS + nono-sandbox), and zero-LLM
               AuditCapsule sealing under absorbing-halt discipline. */
    }

    part def AscentLoopTerminationSystem {
        part ascentGovernor : AscentTerminationGovernor;
        part loopBoundary : GovernedLoopExecutionBoundary;
        part verifierSuite : OrthogonalVerificationSuite;
    }

    part ascentLoopSystem : AscentLoopTerminationSystem;

    // 1. Lean Unbounded Well-Founded Termination & Safety Dominance Laws
    requirement loopTerminationAndAntiOscillationLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "56-ascent-governed-loop-termination.lean";
        attribute :>> leanTheorems = "exactCycle_or_oscillation_always_halts, repeatedFailure_or_zeroProgress_always_halts, budgetExhausted_always_halts, adversarialLoop_universally_terminates";
        doc /* Exact state cycles, A <-> B oscillations, repeated failure
               signatures, zero-progress stalls, and zero remaining budget
               unconditionally halt; every adversarial LLM transition function
               terminates in finite bounded steps by structural induction. */
    }

    requirement loopSafetyDominanceAndAbsorbingHaltLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "56-ascent-governed-loop-termination.lean";
        attribute :>> leanTheorems = "governanceBlock_dominates_retry_and_convergence, haltedLoop_absorbing_without_human_reopen, convergedQuiescent_halts_cleanly";
        doc /* Upstream governance blocks (MCP/CaMeL/sandbox/Cedar/lease)
               strictly dominate retry and convergence; once halted, a loop
               cannot self-reset without explicit non-self human reopen
               endorsement; clean quiescent zero-frontier states halt cleanly. */
    }

    // 2. Quint Nondeterministic Adversarial Loop & Reopen Interleaving Races
    requirement ascentLoopAdversarialTerminationRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "56-ascent-governed-loop-termination.qnt";
        attribute :>> quintInvariants = "cycleOrOscillationNeverAdmitsNextStep, governanceBlockNeverOverriddenByRetry, haltedLoopNeverSelfResetsWithoutHumanReopen, stepsTakenNeverExceedsInitialBudget";
        doc /* Under adversarial cycles, A <-> B oscillations, zero-progress
               stalls, mid-loop governance blocks, budget exhaustion, and human
               reopen interleavings, all four termination and safety invariants
               hold exhaustively across the reachable state space. */
    }

    allocation ownTermLaw allocate loopTerminationAndAntiOscillationLaw to ascentLoopSystem.ascentGovernor;
    allocation verifyTermInLean allocate loopTerminationAndAntiOscillationLaw to ascentLoopSystem.verifierSuite.leanEngine;

    allocation ownDomLaw allocate loopSafetyDominanceAndAbsorbingHaltLaw to ascentLoopSystem.loopBoundary;
    allocation verifyDomInLean allocate loopSafetyDominanceAndAbsorbingHaltLaw to ascentLoopSystem.verifierSuite.leanEngine;

    allocation ownLoopRace allocate ascentLoopAdversarialTerminationRace to ascentLoopSystem.ascentGovernor;
    allocation verifyLoopRaceInQuint allocate ascentLoopAdversarialTerminationRace to ascentLoopSystem.verifierSuite.quintEngine;

    verification def AscentLoopTerminationDispatchContract {
        subject target : AscentLoopTerminationSystem default = ascentLoopSystem;
        in leanAlgebraicLawsProven : Boolean;
        in quintConcurrencyRacesChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in loopBoundaryClosed : Boolean;
        in mode : Integer;

        attribute dispatchOk : Boolean := false;
        attribute boundaryOk : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditLoopTermination;
        action auditLoopTermination {
            assign dispatchOk := leanAlgebraicLawsProven and quintConcurrencyRacesChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign boundaryOk := loopBoundaryClosed or mode == 2;
            assign admitted := dispatchOk and boundaryOk;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not admitted
            or (leanAlgebraicLawsProven
                and quintConcurrencyRacesChecked
                and enginesStrictlyDisjoint
                and loopBoundaryClosed)
        );
    }
}
