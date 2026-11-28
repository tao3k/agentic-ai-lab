// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package DelegationAttenuationAndCedarToctou {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    doc /* Formalizes multi-agent delegated obligation capability attenuation,
           parent denylist dominance, concurrent Cedar revocation TOCTOU fencing,
           stale child cut rejection, and unclosed subagent crash-recovery
           quiescence, grounded in documented Claude Code (#25000, #23983,
           #107019, #6036) and Codex (#34043, #54855, #15305, #51116) issues. */

    item def AttenuatedDelegationEnvelope {
        attribute parentId : String;
        attribute childId : String;
        attribute boundCut : Integer;
        attribute boundGrantEpoch : Integer;
        attribute denyListInherited : Boolean;
    }

    item def DelegationFenceDecision {
        attribute admitted : Boolean;
        attribute revocationDetected : Boolean;
        attribute staleCutDetected : Boolean;
        attribute recoveryRequired : Boolean;
    }

    port def DelegationFencePort {
        in item envelope : AttenuatedDelegationEnvelope;
        out item decision : DelegationFenceDecision;
    }

    part def CapabilityAttenuationLatticeGate {
        port fencePort : DelegationFencePort;
        doc /* Enforces monotonic capability intersection and parent denylist
               union across arbitrary multi-hop obligation delegations. */
    }

    part def ConcurrentCedarToctouFence {
        port fenceIn : ~DelegationFencePort;
        doc /* Atomically verifies live parent Cedar grant, grantEpoch equality,
               workspace cut equality, and unclosed subagent attempt recovery. */
    }

    part def DelegationAndToctouGovernanceSystem {
        part attenuationGate : CapabilityAttenuationLatticeGate;
        part toctouFence : ConcurrentCedarToctouFence;
        part verifierSuite : OrthogonalVerificationSuite;
    }

    part delegationToctouSystem : DelegationAndToctouGovernanceSystem;

    // 1. Lean Unbounded Monotonic Attenuation & Atomic TOCTOU Laws
    requirement delegationCapabilityAttenuationLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "58-delegation-attenuation-and-cedar-toctou-fence.lean";
        attribute :>> leanTheorems = "delegatedCapability_never_exceeds_parent, parentDenylist_dominates_child_delegation, multiHopDelegation_never_escalates";
        doc /* Across single-hop and multi-hop obligation delegations, child
               capabilities never exceed the parent envelope and parent denylist
               entries strictly dominate child requests. */
    }

    requirement cedarToctouAndResumeRecoveryLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "58-delegation-attenuation-and-cedar-toctou-fence.lean";
        attribute :>> leanTheorems = "revokedParentGrant_immediately_blocks_child_toctou, grantEpochAdvance_invalidates_inflight_delegation, staleChildContextCut_rejected_fail_closed, unclosedSubagentAttempt_blocks_silent_hang_or_completion";
        doc /* Parent Cedar grant revocation, grantEpoch advance, or stale child
               workspace cut immediately fails closed at the execution fence;
               unclosed child attempts unconditionally block silent completion. */
    }

    // 2. Quint Nondeterministic Delegation, Revocation & Recovery Races
    requirement delegationRevocationToctouRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "58-delegation-attenuation-and-cedar-toctou-fence.qnt";
        attribute :>> quintInvariants = "delegatedChildNeverBypassesParentDenylist, revokedGrantOrStaleCutNeverAdmitsChildToctou, parentNeverCompletesWhileChildAttemptUnclosed, childBoundEpochNeverExceedsLiveGrantEpoch";
        doc /* Under concurrent delegation, parent Cedar grant revocation,
               workspace cut transition, and interrupted-child recovery, all
               four attenuation and TOCTOU safety invariants hold exhaustively. */
    }

    allocation ownAttenLaw allocate delegationCapabilityAttenuationLaw to delegationToctouSystem.attenuationGate;
    allocation verifyAttenInLean allocate delegationCapabilityAttenuationLaw to delegationToctouSystem.verifierSuite.leanEngine;

    allocation ownToctouLaw allocate cedarToctouAndResumeRecoveryLaw to delegationToctouSystem.toctouFence;
    allocation verifyToctouInLean allocate cedarToctouAndResumeRecoveryLaw to delegationToctouSystem.verifierSuite.leanEngine;

    allocation ownDelRace allocate delegationRevocationToctouRace to delegationToctouSystem.toctouFence;
    allocation verifyDelRaceInQuint allocate delegationRevocationToctouRace to delegationToctouSystem.verifierSuite.quintEngine;

    verification def DelegationToctouDispatchContract {
        subject target : DelegationAndToctouGovernanceSystem default = delegationToctouSystem;
        in leanAlgebraicLawsProven : Boolean;
        in quintConcurrencyRacesChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in delegationBoundaryClosed : Boolean;
        in mode : Integer;

        attribute dispatchOk : Boolean := false;
        attribute boundaryOk : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditDelegationBoundary;
        action auditDelegationBoundary {
            assign dispatchOk := leanAlgebraicLawsProven and quintConcurrencyRacesChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign boundaryOk := delegationBoundaryClosed or mode == 2;
            assign admitted := dispatchOk and boundaryOk;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not admitted
            or (leanAlgebraicLawsProven
                and quintConcurrencyRacesChecked
                and enginesStrictlyDisjoint
                and delegationBoundaryClosed)
        );
    }
}
