// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package AscentObligationFixpointReconciler {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    doc /* Formalizes the Post-ReAct Declarative Obligation-Fixpoint Reconciler
           replacing imperative LLM-driven ReAct loops: ASCENT Datalog fixed-point
           reconciliation over typed Obligation & Epistemic Graphs, strict
           deterministic-first FunFlow dispatch, (holeId, premiseDigest) tuple
           idempotence, stateless typed SynthesisOracle boundary (forbidding raw
           single-step tool calls), competing-hypothesis preservation, and
           bitemporal incremental premise retraction. */

    item def ObligationNode {
        attribute obligationId : String;
        attribute premiseDigest : String;
        attribute discharged : Boolean;
        attribute activeDefeaterCount : Integer;
    }

    item def TypedOracleProposal {
        attribute proposalKind : String;      // typedFunflowDagPatch | boundedCompetingBranches
        attribute contractValid : Boolean;
        attribute camelAndMcpSafe : Boolean;
        attribute branchCount : Integer;
    }

    port def ReconciliationFrontierPort {
        in item obligation : ObligationNode;
        out item oracleProposal : TypedOracleProposal;
    }

    part def AscentObligationReconcilerCore {
        port frontierPort : ReconciliationFrontierPort;
        doc /* Evaluates gerbil-ascent relational fixed point over obligations,
               competing hypotheses, evidence, defeaters, deterministic FunFlow
               tasks, and attempted (holeId, premiseDigest) tuples. */
    }

    part def TypedSynthesisOracleGate {
        port proposalPort : ~ReconciliationFrontierPort;
        doc /* Stateless leaf synthesis boundary rejecting raw ReAct tool calls
               and admitting only contract-verified FunFlow DAG patches or
               bounded competing hypothesis branches. */
    }

    part def ObligationFixpointReconcilerSystem {
        part reconcilerCore : AscentObligationReconcilerCore;
        part synthesisGate : TypedSynthesisOracleGate;
        part verifierSuite : OrthogonalVerificationSuite;
    }

    part obligationReconcilerSystem : ObligationFixpointReconcilerSystem;

    // 1. Lean Unbounded Relational Idempotence, Epistemic Preservation & Quiescence Laws
    requirement obligationIdempotenceAndFixedPointLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "57-obligation-fixpoint-reconciler.lean";
        attribute :>> leanTheorems = "attemptedHole_idempotent_on_unchanged_premises, deterministicFrontier_takes_strict_precedence_over_llm, premiseRetraction_preserves_independent_nodes, reconciler_reaches_quiescent_fixed_point_on_all_holes";
        doc /* Attempting (holeId, premiseDigest) permanently prevents re-firing
               on unchanged premises; deterministic FunFlow work strictly preempts
               LLM synthesis with 0 LLM calls; premise retraction preserves
               independent nodes; finite hole queues reach quiescent fixed point. */
    }

    requirement epistemicAndTypedOracleBoundaryLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "57-obligation-fixpoint-reconciler.lean";
        attribute :>> leanTheorems = "refutedHypothesis_never_discharges_obligation, competingHypotheses_preserved_without_greedy_collapse, rawToolCallOracleOutput_rejected_fail_closed";
        doc /* Refuted or defeated hypotheses cannot discharge obligations;
               multiple unrefuted competing hypotheses remain explicitly open
               without greedy collapse; raw ReAct single-step tool calls from the
               synthesis oracle are rejected fail-closed. */
    }

    // 2. Quint Nondeterministic Reconciler & Event-Driven Retraction Races
    requirement obligationReconcilerConcurrencyRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "57-obligation-fixpoint-reconciler.qnt";
        attribute :>> quintInvariants = "sameHolePremiseNeverReinvokesOracle, llmOracleNeverCalledWhileDeterministicFrontierNonEmpty, rawSingleStepToolCallNeverAdmittedFromOracle, competingHypothesesNeverCollapsedWhenUnrefuted";
        doc /* Across deterministic FunFlow execution, typed synthesis hole
               evaluation, quiescent convergence, and event-driven bitemporal
               premise retraction, all four Post-ReAct safety invariants hold
               exhaustively with zero state-queue remainder. */
    }

    allocation ownIdempLaw allocate obligationIdempotenceAndFixedPointLaw to obligationReconcilerSystem.reconcilerCore;
    allocation verifyIdempInLean allocate obligationIdempotenceAndFixedPointLaw to obligationReconcilerSystem.verifierSuite.leanEngine;

    allocation ownOracleLaw allocate epistemicAndTypedOracleBoundaryLaw to obligationReconcilerSystem.synthesisGate;
    allocation verifyOracleInLean allocate epistemicAndTypedOracleBoundaryLaw to obligationReconcilerSystem.verifierSuite.leanEngine;

    allocation ownRecRace allocate obligationReconcilerConcurrencyRace to obligationReconcilerSystem.reconcilerCore;
    allocation verifyRecRaceInQuint allocate obligationReconcilerConcurrencyRace to obligationReconcilerSystem.verifierSuite.quintEngine;

    verification def ObligationReconcilerDispatchContract {
        subject target : ObligationFixpointReconcilerSystem default = obligationReconcilerSystem;
        in leanAlgebraicLawsProven : Boolean;
        in quintConcurrencyRacesChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in reconcilerBoundaryClosed : Boolean;
        in mode : Integer;

        attribute dispatchOk : Boolean := false;
        attribute boundaryOk : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditObligationReconciler;
        action auditObligationReconciler {
            assign dispatchOk := leanAlgebraicLawsProven and quintConcurrencyRacesChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign boundaryOk := reconcilerBoundaryClosed or mode == 2;
            assign admitted := dispatchOk and boundaryOk;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not admitted
            or (leanAlgebraicLawsProven
                and quintConcurrencyRacesChecked
                and enginesStrictlyDisjoint
                and reconcilerBoundaryClosed)
        );
    }
}
