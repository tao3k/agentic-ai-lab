// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package MemoryQuarantineAndKvPrefixSerialization {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    doc /* Formalizes two structural mechanisms closing the 2025-2026 memory
           poisoning (AgentPoison, MINJA, MemoryGraft) and KV-cache context-rot
           (RadixAttention, CacheBlend, Request-Order-Matters) literature gaps
           under strict FormalVerificationTaxonomy XOR dispatch. */

    item def MemoryContractCandidate {
        attribute candidateId : String;
        attribute originTrust : String;      // trusted-internal | untrusted-ingest
        attribute selfClaimedSuccess : Boolean;
        attribute independentEndorsement : Boolean;
        attribute openDefeaters : Integer;
        attribute memoryTier : String;       // quarantined | recallable | rejected
    }

    item def TwoZonePromptFrame {
        attribute epoch : Integer;
        attribute frozenPrefixDigest : String;
        attribute dynamicSuffixCount : Integer;
        attribute prefixPreserved : Boolean;
    }

    port def MemoryQuarantinePort {
        in item candidate : MemoryContractCandidate;
        out item promptFrame : TwoZonePromptFrame;
    }

    part def MemoryQuarantineGate {
        port quarantine : MemoryQuarantinePort;
        doc /* Holds untrusted or external-taint memory candidates in quarantine;
               blocks self-claimed procedural success from auto-promoting into
               production recall (MINJA / MemoryGraft defense). */
    }

    part def PrefixStablePromptSerializer {
        port serialize : ~MemoryQuarantinePort;
        doc /* Separates Frozen Canonical Prefix (epoch-sealed L0/L1 spine) from
               Dynamic Suffix (active L2/L3 drill-downs & Scoped Detours) so
               detour opens/folds never fracture the KV radix prefix. */
    }

    part def MemoryQuarantineAndKvPrefixSystem {
        part quarantineGate : MemoryQuarantineGate;
        part prefixSerializer : PrefixStablePromptSerializer;
        part verifierSuite : OrthogonalVerificationSuite;
        connection routeQuarantineToSerializer connect quarantineGate.quarantine to prefixSerializer.serialize;
    }

    part memoryKvSystem : MemoryQuarantineAndKvPrefixSystem;

    // 1. Lean Unbounded Algebraic & Prefix-Preservation Laws
    requirement memoryQuarantineAndContractLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "51-memory-poisoning-quarantine-and-kv-prefix-serialization.lean";
        attribute :>> leanTheorems = "quarantinedCandidate_never_recalled, untrustedOrigin_selfClaimedSuccess_cannot_promote, endorsedAndDefeaterFree_promotes_to_recallable";
        doc /* Quarantined candidates are strictly excluded from recall; untrusted
               self-claimed success cannot auto-promote; only independently endorsed,
               defeater-free candidates enter the recallable tier. */
    }

    requirement kvPrefixPreservationAndOrderInvarianceLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "51-memory-poisoning-quarantine-and-kv-prefix-serialization.lean";
        attribute :>> leanTheorems = "appendDynamicSuffix_preserves_frozen_kv_prefix, detourSuffixSwap_preserves_prefix_commitment, canonicalPrefixSort_order_invariant";
        doc /* Appending or swapping dynamic suffix frames never alters the frozen
               KV prefix tokens or digest, and canonical prefix ordering is invariant
               to arrival permutation of distinct peer entries. */
    }

    // 2. Quint Nondeterministic Poisoning Quarantine & Rolling-Suffix Races
    requirement memoryPoisoningQuarantineAndKvPrefixRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "51-memory-poisoning-quarantine-and-kv-prefix-serialization.qnt";
        attribute :>> quintInvariants = "productionRecallNeverContainsQuarantinedOrPoisoned, untrustedExperienceNeverAutoPromotes, rollingDetourSuffixNeverFracturesFrozenKvPrefix";
        doc /* Under concurrent untrusted MemoryGraft/MINJA ingestion, independent
               endorsement/rejection, production recall, and rolling detour suffix
               updates, quarantined or poisoned entries never reach production recall
               and frozen KV prefixes never fracture mid-epoch. */
    }

    allocation ownQuarantineLaw allocate memoryQuarantineAndContractLaw to memoryKvSystem.quarantineGate;
    allocation verifyQuarantineInLean allocate memoryQuarantineAndContractLaw to memoryKvSystem.verifierSuite.leanEngine;

    allocation ownKvPrefixLaw allocate kvPrefixPreservationAndOrderInvarianceLaw to memoryKvSystem.prefixSerializer;
    allocation verifyKvPrefixInLean allocate kvPrefixPreservationAndOrderInvarianceLaw to memoryKvSystem.verifierSuite.leanEngine;

    allocation ownQuarantineKvRace allocate memoryPoisoningQuarantineAndKvPrefixRace to memoryKvSystem.quarantineGate;
    allocation verifyQuarantineKvRaceInQuint allocate memoryPoisoningQuarantineAndKvPrefixRace to memoryKvSystem.verifierSuite.quintEngine;

    verification def MemoryQuarantineAndKvPrefixContract {
        subject target : MemoryQuarantineAndKvPrefixSystem default = memoryKvSystem;
        in leanAlgebraicLawsProven : Boolean;
        in quintConcurrencyRacesChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in quarantineAndPrefixEnforced : Boolean;
        in mode : Integer;

        attribute dispatchOk : Boolean := false;
        attribute contractOk : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditMemoryAndPrefixBoundary;
        action auditMemoryAndPrefixBoundary {
            assign dispatchOk := leanAlgebraicLawsProven and quintConcurrencyRacesChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign contractOk := quarantineAndPrefixEnforced or mode == 2;
            assign admitted := dispatchOk and contractOk;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not admitted
            or (leanAlgebraicLawsProven
                and quintConcurrencyRacesChecked
                and enginesStrictlyDisjoint
                and quarantineAndPrefixEnforced)
        );
    }
}
