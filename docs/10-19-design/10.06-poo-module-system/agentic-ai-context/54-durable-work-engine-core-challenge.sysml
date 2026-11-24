// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package DurableWorkEngineCoreChallenge {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    doc /* Challenges and repairs five concrete logical bugs uncovered by auditing
           modules/durable/work/{contracts,detour-engine,claims-engine,scheduler}.ss
           and modules/ai-agentic-context/features/durable/org-adapter.ss (BUG-D1..BUG-D5):
           monotonic overlay budget meet, confined tainted-detour CompletedExit gate,
           authorized explicit handover & expected-epoch CAS fencing, unclosed-attempt
           archive quiescence fence, and fail-closed cancelled-invariant projection. */

    item def WorkOverlayBudgetSpec {
        attribute parentMaxConcurrency : Integer;
        attribute overlayMaxConcurrency : Integer;
        attribute parentRetryBudget : Integer;
        attribute overlayRetryBudget : Integer;
        attribute parentMaxDetourDepth : Integer;
        attribute overlayMaxDetourDepth : Integer;
        attribute parentAllowDrillDown : Boolean;
        attribute overlayAllowDrillDown : Boolean;
    }

    item def ConfinedDetourExitPacket {
        attribute detourTainted : Boolean;
        attribute hasReceiptDigest : Boolean;
        attribute schemaAttested : Boolean;
        attribute hasDeclassCert : Boolean;
    }

    item def LeaseHandoverRequest {
        attribute liveEpoch : Integer;
        attribute expectedEpoch : Integer;
        attribute leaseExpired : Boolean;
        attribute forceExplicit : Boolean;
        attribute hasNonSelfEndorsement : Boolean;
        attribute hasCustodyOid : Boolean;
    }

    port def OverlayBudgetPort {
        in item overlaySpec : WorkOverlayBudgetSpec;
        out attribute budgetMonotonic : Boolean;
    }

    port def DetourExitGatePort {
        in item exitPacket : ConfinedDetourExitPacket;
        out attribute exitAdmitted : Boolean;
    }

    port def LeaseHandoverPort {
        in item handoverReq : LeaseHandoverRequest;
        out attribute handoverAdmitted : Boolean;
    }

    part def MonotonicWorkOverlayAndDetourGate {
        port overlayIn : OverlayBudgetPort;
        port detourExitIn : DetourExitGatePort;
        doc /* Enforces monotonic min/and narrowing on hot work overlays (BUG-D1),
               APPA confined-detour return gating on CompletedExit (BUG-D2), and
               fail-closed cancelled-invariant tracking (BUG-D5). */
    }

    part def QuiescentSchedulerAndClaimsEngine {
        port handoverIn : LeaseHandoverPort;
        doc /* Enforces unclosed-attempt quiescence before auto-archive (BUG-D4),
               authorized explicit early handover with non-self endorsement and
               expected-epoch CAS fencing (BUG-D3). */
    }

    part def DurableWorkChallengeSystem {
        part overlayAndDetourGate : MonotonicWorkOverlayAndDetourGate;
        part schedulerAndClaims : QuiescentSchedulerAndClaimsEngine;
        part verifierSuite : OrthogonalVerificationSuite;
    }

    part durableWorkChallengeSystem : DurableWorkChallengeSystem;

    // 1. Lean Unbounded Algebraic & Structural Repair Laws
    requirement monotonicWorkOverlayAndConfinedExitLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "54-durable-work-engine-core-challenge.lean";
        attribute :>> leanTheorems = "overlayBudgetMeet_never_escalates, taintedDetourCompletedExit_requires_attestation_or_cert, cancelledInvariant_remains_unsatisfied_fail_closed";
        doc /* Monotonic overlay budget meet never exceeds parent concurrency,
               retry, detour-depth, or drill-down bounds (BUG-D1); tainted
               detours cannot merge via CompletedExit without schema attestation
               or 3-party declassification (BUG-D2); cancelled invariants remain
               unsatisfied fail-closed (BUG-D5). */
    }

    requirement quiescentArchiveAndAuthorizedHandoverLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "54-durable-work-engine-core-challenge.lean";
        attribute :>> leanTheorems = "unclosedAttempt_blocks_autoArchive_fail_closed, explicitEarlyHandover_requires_nonSelf_endorsement, staleEpochCas_rejected_by_claim_and_handover";
        doc /* Any non-empty unclosed-attempt list blocks auto-archive (BUG-D4);
               explicit early handover requires non-self endorsement and custody
               (BUG-D3); stale expected-epoch CAS attempts are universally
               rejected (BUG-D3). */
    }

    // 2. Quint Nondeterministic Archive, Handover, Taint & Overlay Races
    requirement durableWorkArchiveHandoverAndTaintRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "54-durable-work-engine-core-challenge.qnt";
        attribute :>> quintInvariants = "archiveNeverCommitsWithUnclosedAttemptOrOpenBlocker, activeLeaseNeverHijackedWithoutExpiryOrEndorsement, staleEpochWriteOrHandoverAlwaysRejected, taintedDetourNeverMergesUnattestedIntoMainline, overlayBudgetNeverExceedsParentPolicyFloor";
        doc /* Under concurrent crash-unclosed attempts, premature auto-archive,
               active-lease handover races, stale-epoch writes, tainted detour
               exits, and hot overlay escalations, all five BUG-D1..BUG-D5 safety
               invariants hold across the entire reachable state space. */
    }

    allocation ownOverlayDetourLaw allocate monotonicWorkOverlayAndConfinedExitLaw to durableWorkChallengeSystem.overlayAndDetourGate;
    allocation verifyOverlayDetourInLean allocate monotonicWorkOverlayAndConfinedExitLaw to durableWorkChallengeSystem.verifierSuite.leanEngine;

    allocation ownArchiveHandoverLaw allocate quiescentArchiveAndAuthorizedHandoverLaw to durableWorkChallengeSystem.schedulerAndClaims;
    allocation verifyArchiveHandoverInLean allocate quiescentArchiveAndAuthorizedHandoverLaw to durableWorkChallengeSystem.verifierSuite.leanEngine;

    allocation ownWorkRace allocate durableWorkArchiveHandoverAndTaintRace to durableWorkChallengeSystem.schedulerAndClaims;
    allocation verifyWorkRaceInQuint allocate durableWorkArchiveHandoverAndTaintRace to durableWorkChallengeSystem.verifierSuite.quintEngine;

    verification def DurableWorkChallengeDispatchContract {
        subject target : DurableWorkChallengeSystem default = durableWorkChallengeSystem;
        in leanAlgebraicLawsProven : Boolean;
        in quintConcurrencyRacesChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in durableWorkBugsClosed : Boolean;
        in mode : Integer;

        attribute dispatchOk : Boolean := false;
        attribute contractOk : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditDurableWorkChallengeBoundary;
        action auditDurableWorkChallengeBoundary {
            assign dispatchOk := leanAlgebraicLawsProven and quintConcurrencyRacesChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign contractOk := durableWorkBugsClosed or mode == 2;
            assign admitted := dispatchOk and contractOk;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not admitted
            or (leanAlgebraicLawsProven
                and quintConcurrencyRacesChecked
                and enginesStrictlyDisjoint
                and durableWorkBugsClosed)
        );
    }
}
