// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package FormalVerificationTaxonomy {
    private import ScalarValues::*;

    doc /* Master SysML v2 verification dispatch taxonomy for Context Governance
           (Slices 40-47). SysML v2 partitions every formal obligation into
           strictly disjoint verification engines so Lean 4 and Quint never
           duplicate responsibilities:
           1. LeanUnboundedAlgebraicEngine: pure, state-machine-free universal
              theorems (lattice/semilattice algebra, recursive AST/list/path
              induction, functional map-frame non-interference, and quotient
              homomorphisms).
           2. QuintTemporalInterleavingEngine: nondeterministic (nondet) stateful
              protocols (prepare/consume vs edit/revoke/retract races, out-of-order
              arrivals, and crash-before-receipt uncertainty intervals). */

    enum def ProofObligationClass {
        enum LeanUnboundedAlgebraicLaw;
        enum QuintConcurrentInterleavingLaw;
    }

    part def LeanUnboundedAlgebraicEngine {
        doc /* Discharges unbounded universal theorems over arbitrary lists,
               trees, capability domains and maps without finite step bounds. */
    }

    part def QuintTemporalInterleavingEngine {
        doc /* Explores nondeterministic concurrent protocol transitions, races,
               out-of-order arrivals and crash recovery via Apalache. */
    }

    part def OrthogonalVerificationSuite {
        part leanEngine : LeanUnboundedAlgebraicEngine;
        part quintEngine : QuintTemporalInterleavingEngine;
    }

    requirement def LeanAlgebraicObligation {
        attribute obligationClass : ProofObligationClass = ProofObligationClass::LeanUnboundedAlgebraicLaw;
        attribute leanArtifact : String;
        attribute leanTheorems : String;
    }

    requirement def QuintInterleavingObligation {
        attribute obligationClass : ProofObligationClass = ProofObligationClass::QuintConcurrentInterleavingLaw;
        attribute quintArtifact : String;
        attribute quintInvariants : String;
    }
}

package ContextGovernanceBoundary {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    item def TrustRoleSlice {
        attribute elementAnchor : String;
        attribute sourceCut : String;
        attribute originTrustRank : Integer;
        attribute effectiveTrustRank : Integer;
    }

    item def EndorsementReceipt {
        attribute endorsementIdentity : String;
        attribute boundElementDigest : String;
        attribute boundSourceCut : String;
        attribute proposerPrincipal : String;
        attribute endorserPrincipal : String;
        attribute targetTrustRank : Integer;
    }

    item def RestrictionEnvelope {
        attribute allowedReaders : String;
        attribute allowedDestinations : String;
        attribute allowedCapabilities : String;
        attribute leaseStart : Integer;
        attribute leaseEnd : Integer;
        attribute maxTrustRank : Integer;
        attribute accumulatedObligations : String;
    }

    item def ContextThreatRecord {
        attribute threatIdentity : String;
        attribute severityRank : Integer;
        attribute phase : String;
        attribute residualAuthority : String;
        attribute acceptedAtCut : String;
    }

    item def ContextGovernanceAssessment {
        attribute profileIdentity : String;
        attribute projectionDigest : String;
        attribute sourceCutVector : String;
        attribute restrictionDigest : String;
        attribute handoffEligible : Boolean;
        attribute carriesActionAuthority : Boolean;
    }

    item def KvPrefixEnvelope {
        attribute tenantScope : String;
        attribute principalScope : String;
        attribute restrictionDigest : String;
        attribute modelTokenizerProfile : String;
        attribute renderedTokenPrefix : String;
    }

    port def ContextGovernanceGate {
        in item rawSlice : TrustRoleSlice;
        in item endorsement : EndorsementReceipt;
        in item parentRestriction : RestrictionEnvelope;
        in item threat : ContextThreatRecord;
        out item composedRestriction : RestrictionEnvelope;
        out item assessment : ContextGovernanceAssessment;
    }

    port def ProviderHandoffPort {
        in item assessment : ContextGovernanceAssessment;
        in item prefixEnvelope : KvPrefixEnvelope;
        out attribute consumptionAdmitted : Boolean;
    }

    part def ContextPlane {
        port governance : ~ContextGovernanceGate;
    }

    part def GovernancePlane {
        port gate : ContextGovernanceGate;
        port handoff : ~ProviderHandoffPort;
    }

    part def RuntimeAuthorizationPlane {
        port handoff : ProviderHandoffPort;
    }

    part def GovernedContextSystem {
        part contextPlane : ContextPlane;
        part governancePlane : GovernancePlane;
        part runtimePlane : RuntimeAuthorizationPlane;
        part verifierSuite : OrthogonalVerificationSuite;
        connection assessContext connect contextPlane.governance to governancePlane.gate;
        connection admitHandoff connect governancePlane.handoff to runtimePlane.handoff;
    }

    part governedSystem : GovernedContextSystem;

    // 1. Lean Unbounded Algebraic & Inductive Obligations
    requirement roleSemilatticeAlgebra : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "40-context-governance-boundary.lean";
        attribute :>> leanTheorems = "minRole_idem, minRole_comm, minRole_assoc, foldRoles_le_every_premise";
        doc /* TrustRole forms a bounded meet-semilattice; folding any finite
               provenance chain never exceeds the minimum premise trust rank. */
    }

    requirement monotonicRestrictionSemilattice : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "40-context-governance-boundary.lean";
        attribute :>> leanTheorems = "RestrictionEnvelope.meet_refines_left, composeRestrictions_refines_every_member";
        doc /* Product lower-semilattice meet refines every member across
               arbitrarily long Context composition lists regardless of C4 order. */
    }

    requirement kvDomainKeyInjectivityAndZeroAuthority : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "40-context-governance-boundary.lean";
        attribute :>> leanTheorems = "kvDomainKey_injective, governance_value_carries_zero_authority";
        doc /* Domain-isolated KV cache keys are injective over security tuples
               independent of rendered token equality, and Governance values
               inhabit zero execution-authority witnesses. */
    }

    // 2. Quint Nondeterministic Concurrent Interleaving Obligations
    requirement endorsementAndCutDriftRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "40-context-governance-boundary.qnt";
        attribute :>> quintInvariants = "noUnendorsedOrStaleEscalation";
        doc /* Under asynchronous endorsement arrivals, self-endorsement attempts
               and concurrent source-cut advances between prepare and consume,
               no stale or self-endorsed escalation crosses the handoff fence. */
    }

    requirement concurrentThreatAndRevocationFence : QuintInterleavingObligation {
        attribute :>> quintArtifact = "40-context-governance-boundary.qnt";
        attribute :>> quintInvariants = "handoffFencedAgainstThreatAndCutRaces, kvReuseFencedAgainstRevocation";
        doc /* Concurrent threat exposure, cut drift invalidating residual risk
               acceptance, and grant revocation race safely against prepared
               handoffs and KV-prefix cache admissions. */
    }

    // Domain + Verification Engine Allocations (strictly disjoint)
    allocation ownRoleDomain allocate roleSemilatticeAlgebra to governedSystem.governancePlane;
    allocation verifyRoleInLean allocate roleSemilatticeAlgebra to governedSystem.verifierSuite.leanEngine;

    allocation ownMeetDomain allocate monotonicRestrictionSemilattice to governedSystem.contextPlane;
    allocation verifyMeetInLean allocate monotonicRestrictionSemilattice to governedSystem.verifierSuite.leanEngine;

    allocation ownKvDomain allocate kvDomainKeyInjectivityAndZeroAuthority to governedSystem.runtimePlane;
    allocation verifyKvInLean allocate kvDomainKeyInjectivityAndZeroAuthority to governedSystem.verifierSuite.leanEngine;

    allocation ownEndorseRaceDomain allocate endorsementAndCutDriftRace to governedSystem.governancePlane;
    allocation verifyEndorseRaceInQuint allocate endorsementAndCutDriftRace to governedSystem.verifierSuite.quintEngine;

    allocation ownThreatRaceDomain allocate concurrentThreatAndRevocationFence to governedSystem.runtimePlane;
    allocation verifyThreatRaceInQuint allocate concurrentThreatAndRevocationFence to governedSystem.verifierSuite.quintEngine;

    // SysML architectural boundary & verification-dispatch contract (not a state-machine clone).
    // mode 0: disjoint Lean/Quint dispatch and inert Governance -> Host crossing
    // mode 1: collapse Lean algebraic obligation into Quint or leave unallocated
    // mode 2: let GovernancePlane claim direct execution authority bypassing RuntimeAuthorizationPlane
    verification def GovernanceArchitectureAndDispatchContract {
        subject target : GovernedContextSystem default = governedSystem;
        in leanAlgebraicDischarged : Boolean;
        in quintInterleavingDischarged : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in hostFenceConsulted : Boolean;
        in mode : Integer;

        attribute leanCovered : Boolean := false;
        attribute quintCovered : Boolean := false;
        attribute disjointOk : Boolean := false;
        attribute governanceClaimsExec : Boolean := false;
        attribute architectureQualified : Boolean := false;

        first start then auditDispatchAndBoundary;
        action auditDispatchAndBoundary {
            assign leanCovered := leanAlgebraicDischarged;
            assign quintCovered := quintInterleavingDischarged;
            assign disjointOk := enginesStrictlyDisjoint and mode != 1;
            assign governanceClaimsExec := mode == 2;
            assign architectureQualified := leanCovered and quintCovered
                and (disjointOk or mode == 1)
                and (hostFenceConsulted or mode == 2);
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not governanceClaimsExec
            and (not architectureQualified
                or (leanAlgebraicDischarged
                    and quintInterleavingDischarged
                    and enginesStrictlyDisjoint
                    and disjointOk
                    and hostFenceConsulted))
        );
    }
}
