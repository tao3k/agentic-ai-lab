// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package FunflowCasSingleflightAndExternalSandbox {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    doc /* Challenges and repairs five concrete logical bugs uncovered by auditing
           modules/funflow/{durable-dag,store,control-plane/*}.ss (BUG-F1..BUG-F5):
           canonical 5-tuple CAS fingerprinting, fail-closed premise retraction,
           EffectClass-gated CAS reuse, after-start finalizer ordering/SCC,
           disjoint lease bottom & ExternalTask sandbox Lethal-Trifecta binding,
           concurrent lookupOrWait singleflight, atomic temp-rename publication,
           and AuditCapsule-pinned CAS GC. */

    item def CanonicalCasKey5Tuple {
        attribute schemaVersion : String;
        attribute stepCodeDigest : String;
        attribute envDigest : String;
        attribute sortedInputHashesDigest : String;
        attribute sortedPremiseDigestsHash : String;
        attribute effectClass : String;      // PureCAS | VerifiedEpistemic | FencedEffect
    }

    item def ExternalTaskSandboxBinding {
        attribute envPinned : Boolean;
        attribute hasUntrustedInput : Boolean;
        attribute hasPrivateData : Boolean;
        attribute egressEnabled : Boolean;
        attribute egressEndorsed : Boolean;
        attribute leaseValid : Boolean;
    }

    item def SingleflightCasEntry {
        attribute keyDigest : String;
        attribute publishedAtomically : Boolean;
        attribute capsulePinned : Boolean;
        attribute premiseGen : Integer;
    }

    port def CasKeyPort {
        in item casKey : CanonicalCasKey5Tuple;
        out item casEntry : SingleflightCasEntry;
    }

    port def SandboxBindingPort {
        in item sandboxProfile : ExternalTaskSandboxBinding;
        out attribute sandboxAdmitted : Boolean;
    }

    part def CasCompilerAndKeyGate {
        port casOut : ~CasKeyPort;
        doc /* Compiles declarative Flows into DurableDAG nodes with canonical
               5-tuple CAS keys (including stepCodeDigest & envDigest), enforces
               fail-closed premise retraction invalidation (BUG-F2), includes
               after-start edges in SCC/topological scheduling (BUG-F1), and
               forbids plain CAS reuse of FencedEffect nodes (BUG-F3). */
    }

    part def SingleflightStoreAndGc {
        port casIn : CasKeyPort;
        doc /* Enforces multi-agent lookupOrWait singleflight deduplication,
               atomic temp-write-then-rename publication under crashes, and
               AuditCapsule-pinned CAS GC preserving historical cut=1 forensic
               artifacts (BUG-F5). */
    }

    part def ExternalSandboxGate {
        port sandboxIn : SandboxBindingPort;
        doc /* Rejects ExternalTasks with unpinned Nix/Docker/Sandbox envDigest,
               inverted/disjoint lease intervals, or unendorsed Lethal-Trifecta
               exposure (BUG-F4). */
    }

    part def FunflowCasSandboxSystem {
        part casCompilerAndKeyGate : CasCompilerAndKeyGate;
        part singleflightStoreAndGc : SingleflightStoreAndGc;
        part externalSandboxGate : ExternalSandboxGate;
        part verifierSuite : OrthogonalVerificationSuite;
        connection routeKeyToStore connect casCompilerAndKeyGate.casOut to singleflightStoreAndGc.casIn;
    }

    part funflowCasSandboxSystem : FunflowCasSandboxSystem;

    // 1. Lean Unbounded Algebraic & Structural Repair Laws
    requirement canonicalCasKeyAndFailClosedPremiseLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "52-funflow-cas-singleflight-and-external-sandbox-binding.lean";
        attribute :>> leanTheorems = "casKey_sensitive_to_code_and_env_drift, casKey_input_order_invariant, retractedPremise_always_invalidates_fail_closed, fencedEffect_never_reused_by_plain_cas";
        doc /* Canonical 5-tuple CAS keys change whenever stepCodeDigest or envDigest
               drifts, remain invariant under distinct input arrival permutations,
               retracted premises always invalidate fail-closed (closing BUG-F2),
               and FencedEffect nodes are never skipped via plain CAS hits without
               an idempotency commit receipt (closing BUG-F3). */
    }

    requirement capsulePinnedGcAndExternalSandboxLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "52-funflow-cas-singleflight-and-external-sandbox-binding.lean";
        attribute :>> leanTheorems = "gc_never_evicts_capsule_pinned_entry, disjointLeaseMeet_is_unsatisfiable, externalTask_rejects_unpinned_or_trifecta_sandbox";
        doc /* CAS GC preserves every AuditCapsule-pinned entry over unbounded lists
               (closing BUG-F5), disjoint lease intersection admits zero timestamps,
               and ExternalTask admission rejects unpinned environments or unendorsed
               Lethal-Trifecta sandbox profiles (closing BUG-F4). */
    }

    // 2. Quint Nondeterministic Singleflight, Crash-Atomic Publish, Pinned GC & Finalizer Races
    requirement singleflightAtomicPublishGcAndFinalizerRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "52-funflow-cas-singleflight-and-external-sandbox-binding.qnt";
        attribute :>> quintInvariants = "singleflightAtMostOneActiveComputePerKey, atomicPublishNeverExposesPartialEntryOnCrash, gcNeverEvictsCapsulePinnedForensicEntry, fencedEffectExecutesAtMostOnceAndFinalizerNeverDropped";
        doc /* Under concurrent two-agent lookupOrWait arrivals, mid-write crashes
               before atomic rename, premise generation advances, concurrent CAS GC
               sweeps, and failed FencedEffect triggers with after-start finalizers,
               at most one compute runs per key, crashes leave CAS uncorrupted,
               pinned forensic entries survive GC, and FencedEffect/finalizer safety
               never degrades. */
    }

    allocation ownCasKeyLaw allocate canonicalCasKeyAndFailClosedPremiseLaw to funflowCasSandboxSystem.casCompilerAndKeyGate;
    allocation verifyCasKeyInLean allocate canonicalCasKeyAndFailClosedPremiseLaw to funflowCasSandboxSystem.verifierSuite.leanEngine;

    allocation ownGcSandboxLaw allocate capsulePinnedGcAndExternalSandboxLaw to funflowCasSandboxSystem.externalSandboxGate;
    allocation verifyGcSandboxInLean allocate capsulePinnedGcAndExternalSandboxLaw to funflowCasSandboxSystem.verifierSuite.leanEngine;

    allocation ownSingleflightRace allocate singleflightAtomicPublishGcAndFinalizerRace to funflowCasSandboxSystem.singleflightStoreAndGc;
    allocation verifySingleflightRaceInQuint allocate singleflightAtomicPublishGcAndFinalizerRace to funflowCasSandboxSystem.verifierSuite.quintEngine;

    verification def FunflowCasSandboxDispatchContract {
        subject target : FunflowCasSandboxSystem default = funflowCasSandboxSystem;
        in leanAlgebraicLawsProven : Boolean;
        in quintConcurrencyRacesChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in casSandboxBugsClosed : Boolean;
        in mode : Integer;

        attribute dispatchOk : Boolean := false;
        attribute contractOk : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditFunflowCasSandboxBoundary;
        action auditFunflowCasSandboxBoundary {
            assign dispatchOk := leanAlgebraicLawsProven and quintConcurrencyRacesChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign contractOk := casSandboxBugsClosed or mode == 2;
            assign admitted := dispatchOk and contractOk;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not admitted
            or (leanAlgebraicLawsProven
                and quintConcurrencyRacesChecked
                and enginesStrictlyDisjoint
                and casSandboxBugsClosed)
        );
    }
}
