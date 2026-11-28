// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ScopedDetourFunflowConcurrentContext {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    doc /* Formalizes Zero-SubAgent concurrent Shared-Context `:ID:` ownership
           (Extend-Never-Overwrite), Scoped Detours with 0-token Org-Elements
           re-anchoring and 4 fail-closed CLOS exit states, Three-State FunFlow
           Effect Algebra, and monotonic C4 `OrgOverlay(g)` meet under strict
           FormalVerificationTaxonomy XOR dispatch. */

    item def SharedContextIdClaim {
        attribute nodeId : String;
        attribute ownerActor : String;
        attribute claimState : String; // unclaimed | claimed-active | handed-off | parked-custody | completed
        attribute claimLeaseEpoch : Integer;
        attribute scopeDigest : String;
    }

    item def ScopedDetourTransition {
        attribute detourId : String;
        attribute detourKind : String; // blocker | side-quest
        attribute returnAnchorId : String;
        attribute exitKind : String;   // completed | parked-custody | cancelled | promoted-to-task
        attribute preservesCounterexampleCore : Boolean;
    }

    item def ThreeStateEffectAdmission {
        attribute effectClass : String; // pure-cas | verified-epistemic | fenced-effect
        attribute claimsExhaustive : Boolean;
        attribute hasAuthorizedToken : Boolean;
        attribute hasEndorsement : Boolean;
        attribute admitted : Boolean;
    }

    port def SharedOwnershipPort {
        in item requestedOp : SharedContextIdClaim;
        out item admittedClaim : SharedContextIdClaim;
    }

    port def DetourReanchorPort {
        in item detourExit : ScopedDetourTransition;
        out item effectGate : ThreeStateEffectAdmission;
    }

    part def SharedContextOwnershipArbiter {
        port ownership : SharedOwnershipPort;
        doc /* Enforces single active `:OWNER_ACTOR:` per `:ID:` in Shared Org
               `:PROPERTIES:` and Extend-Never-Overwrite for peer Agents and Humans. */
    }

    part def ScopedDetourReanchorArbiter {
        port detour : ~DetourReanchorPort;
        doc /* Executes 0-token Org-Elements re-anchoring and fail-closed CLOS
               `(reconcile-detour-exit ...)` across all four exit states. */
    }

    part def ThreeStateFunflowEffectGate {
        port gate : DetourReanchorPort;
        doc /* Enforces monotonic `OrgOverlay(g)` meet and asymmetric CLOS
               `(admit-node-effect ...)` across PureCAS, VerifiedEpistemic, and
               FencedEffect nodes. */
    }

    part def ConcurrentSharedContextOrchestrationSystem {
        part ownershipArbiter : SharedContextOwnershipArbiter;
        part detourArbiter : ScopedDetourReanchorArbiter;
        part effectGate : ThreeStateFunflowEffectGate;
        part verifierSuite : OrthogonalVerificationSuite;
        connection routeDetourToEffect connect detourArbiter.detour to effectGate.gate;
    }

    part concurrentContextSystem : ConcurrentSharedContextOrchestrationSystem;

    // 1. Lean Unbounded Algebraic & Structural Preservation Laws
    requirement monotonicOverlayAndThreeStateEffectLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "49-scoped-detour-funflow-concurrent-shared-context.lean";
        attribute :>> leanTheorems = "orgOverlayMeet_no_trust_escalation, orgOverlayMeet_lease_contained, orgOverlayMeet_capabilities_monotonic, fencedEffect_requires_exhaustive_token_and_endorsement, pureCAS_admitted_without_exhaustiveness";
        doc /* C4 `OrgOverlay(g)` meet never escalates trust ceiling, lease window,
               or capabilities; `FencedEffect` requires exhaustiveness, one-shot
               token, and non-self endorsement while `PureCAS` admits unconditionally. */
    }

    requirement detourCounterexampleAndExtendNotOverwriteLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "49-scoped-detour-funflow-concurrent-shared-context.lean";
        attribute :>> leanTheorems = "cancelledDetour_preserves_mainline_and_new_defeaters, reanchorMainline_blocks_archive_if_blocker_or_invariant_open, directWrite_nonOwner_rejected, extendChild_preserves_claimed_node_invariant, activeLeaseTakeover_rejected_before_expiry, expiredLeaseTakeover_strictly_advances_epoch";
        doc /* Cancelled detours preserve every prior and newly discovered defeater;
               open blocker detours or invariants unconditionally block Auto-Archive;
               non-owner direct overwrites fail closed while disjoint child extensions
               leave the claimed parent node strictly invariant. */
    }

    // 2. Quint Nondeterministic Peer-Actor Concurrency & Detour Races
    requirement concurrentPeerOwnershipAndDetourRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "49-scoped-detour-funflow-concurrent-shared-context.qnt";
        attribute :>> quintInvariants = "noNonOwnerOverwrite, fencedEffectRequiresExhaustiveAndValidPremise, autoArchiveRequiresNoBlockerAndAllInvariants, cancelledDetourNeverDropsDefeaters";
        doc /* Under concurrent Human and peer-Agent claims, disjoint child
               extensions, custody handovers, detour exits, and premise-cut shifts,
               claimed nodes are never overwritten by non-owners, unexhaustive
               FencedEffects never commit, and premature Auto-Archive never fires. */
    }

    allocation ownOverlayAndEffect allocate monotonicOverlayAndThreeStateEffectLaw to concurrentContextSystem.effectGate;
    allocation verifyOverlayAndEffectInLean allocate monotonicOverlayAndThreeStateEffectLaw to concurrentContextSystem.verifierSuite.leanEngine;

    allocation ownDetourAndOwnership allocate detourCounterexampleAndExtendNotOverwriteLaw to concurrentContextSystem.ownershipArbiter;
    allocation verifyDetourAndOwnershipInLean allocate detourCounterexampleAndExtendNotOverwriteLaw to concurrentContextSystem.verifierSuite.leanEngine;

    allocation ownConcurrentRaces allocate concurrentPeerOwnershipAndDetourRace to concurrentContextSystem.detourArbiter;
    allocation verifyConcurrentRacesInQuint allocate concurrentPeerOwnershipAndDetourRace to concurrentContextSystem.verifierSuite.quintEngine;

    verification def ScopedDetourAndConcurrentSharedContextContract {
        subject target : ConcurrentSharedContextOrchestrationSystem default = concurrentContextSystem;
        in leanAlgebraicLawsProven : Boolean;
        in quintConcurrencyRacesChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in extendNeverOverwriteEnforced : Boolean;
        in mode : Integer;

        attribute dispatchOk : Boolean := false;
        attribute ownershipOk : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditConcurrentContextBoundary;
        action auditConcurrentContextBoundary {
            assign dispatchOk := leanAlgebraicLawsProven and quintConcurrencyRacesChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign ownershipOk := extendNeverOverwriteEnforced or mode == 2;
            assign admitted := dispatchOk and ownershipOk;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not admitted
            or (leanAlgebraicLawsProven
                and quintConcurrencyRacesChecked
                and enginesStrictlyDisjoint
                and extendNeverOverwriteEnforced)
        );
    }
}
