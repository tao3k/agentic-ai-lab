// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package DurableAgendaSessionSandboxGovernance {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    item def DurableAgendaWake {
        attribute declarationAnchor : String;
        attribute nominalOccurrenceKey : String;
        attribute wakeCarriesExecutionAuthority : Boolean;
    }

    item def SandboxPlacementProfile {
        attribute sandboxIdentity : String;
        attribute allowsExternalEgress : Boolean;
    }

    item def SessionAttemptFenceState {
        attribute attemptGeneration : Integer;
        attribute handoffConsumed : Boolean;
        attribute outcomeAmbiguous : Boolean;
    }

    port def WakeToSessionPort {
        in item wake : DurableAgendaWake;
        out item attemptState : SessionAttemptFenceState;
    }

    port def ContextToSandboxGatePort {
        in item requestedSandbox : SandboxPlacementProfile;
        out attribute sandboxAdmitted : Boolean;
    }

    part def DurableAgendaPlane {
        port trigger : ~WakeToSessionPort;
    }

    part def IndependentSessionAndReconciler {
        port wakeIntake : WakeToSessionPort;
    }

    part def ContextSandboxRequestor {
        port requestSandbox : ~ContextToSandboxGatePort;
    }

    part def SandboxTrifectaGovernanceGate {
        port sandboxCheck : ContextToSandboxGatePort;
    }

    part def GovernedRuntimeControlAxes {
        part agendaPlane : DurableAgendaPlane;
        part sessionPlane : IndependentSessionAndReconciler;
        part contextRequestor : ContextSandboxRequestor;
        part sandboxGate : SandboxTrifectaGovernanceGate;
        part verifierSuite : OrthogonalVerificationSuite;
        connection routeWake connect agendaPlane.trigger to sessionPlane.wakeIntake;
        connection checkSandbox connect contextRequestor.requestSandbox to sandboxGate.sandboxCheck;
    }

    part controlAxesSystem : GovernedRuntimeControlAxes;

    // 1. Lean Unbounded Capability-Intersection Algebra & Journal Frame Obligations
    requirement sandboxIntersectionAndTrifectaAlgebra : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "46-durable-agenda-session-sandbox-governance.lean";
        attribute :>> leanTheorems = "effectiveCap_idem, effectiveCap_comm, effectiveCap_monotone_ctx, noEgressProfile_eliminates_lethal_trifecta";
        doc /* Over arbitrary capability domains, Context x Sandbox intersection
               is idempotent, commutative and monotone under restriction
               tightening, and intersecting with a no-egress Sandbox profile
               universally eliminates the Lethal Trifecta. */
    }

    requirement perRecipientJournalFrameLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "46-durable-agenda-session-sandbox-governance.lean";
        attribute :>> leanTheorems = "recordOutcome_frame_preserves_other_recipients";
        doc /* Recording or reconciling an Attempt outcome for recipient r1 in
               an unbounded delivery map preserves every other recipient r2 != r1. */
    }

    // 2. Quint Nondeterministic Wake, Revocation & Crash-Reconciliation Races
    requirement wakeRevocationAndCrashReconciliationRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "46-durable-agenda-session-sandbox-governance.qnt";
        attribute :>> quintInvariants = "wakeNeverDispatchesWithoutLiveGrant, lethalTrifectaExcludedAtFence, crashAmbiguityBlocksBlindRetryAndAdvancesGen";
        doc /* Under asynchronous Agenda wakes, mid-preparation grant revocations,
               post-handoff crashes, late provider receipts and attested no-send
               fences, blind non-idempotent retries and ungranted wakes never fire. */
    }

    allocation ownSandboxDomain allocate sandboxIntersectionAndTrifectaAlgebra to controlAxesSystem.sandboxGate;
    allocation verifySandboxInLean allocate sandboxIntersectionAndTrifectaAlgebra to controlAxesSystem.verifierSuite.leanEngine;

    allocation ownJournalFrameDomain allocate perRecipientJournalFrameLaw to controlAxesSystem.sessionPlane;
    allocation verifyJournalFrameInLean allocate perRecipientJournalFrameLaw to controlAxesSystem.verifierSuite.leanEngine;

    allocation ownCrashRaceDomain allocate wakeRevocationAndCrashReconciliationRace to controlAxesSystem.sessionPlane;
    allocation verifyCrashRaceInQuint allocate wakeRevocationAndCrashReconciliationRace to controlAxesSystem.verifierSuite.quintEngine;

    verification def ControlAxesDispatchAndBoundaryContract {
        subject target : GovernedRuntimeControlAxes default = controlAxesSystem;
        in leanIntersectionAndFrameProven : Boolean;
        in quintCrashAndWakeRacesChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in agendaWakeCarriesZeroAuthority : Boolean;
        in mode : Integer;

        attribute dispatchValid : Boolean := false;
        attribute wakeInertValid : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditControlAxesBoundary;
        action auditControlAxesBoundary {
            assign dispatchValid := leanIntersectionAndFrameProven and quintCrashAndWakeRacesChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign wakeInertValid := agendaWakeCarriesZeroAuthority and mode != 2;
            assign admitted := dispatchValid and (wakeInertValid or mode == 2);
        }
        then done;

        return verdict : VerdictKind = PassIf(
            wakeInertValid
            and (not admitted
                or (leanIntersectionAndFrameProven
                    and quintCrashAndWakeRacesChecked
                    and enginesStrictlyDisjoint
                    and agendaWakeCarriesZeroAuthority))
        );
    }
}
