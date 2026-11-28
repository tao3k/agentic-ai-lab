// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package DetourTaintConfinementAndCausalAudit {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    doc /* Formalizes three mechanisms absorbed from 2025-2026 community
           literature into agentic-ai-lab:
           1. APPA-inspired Scoped Detour Taint Confinement (recoverable IFC
              with bounded-schema attestation preventing mainline label creep).
           2. NeuroTaint-inspired zero-LLM offline causal counterfactual
              dependence auditing over DeterministicAuditCapsule.
           3. Deterministic stall / divergence advisory signals proposing
              Park or Cancel to ASCENT / Human with zero auto-mutation authority. */

    item def ConfinedDetourEnvelope {
        attribute detourId : String;
        attribute mainlineTainted : Boolean;
        attribute detourTainted : Boolean;
        attribute egressEnabled : Boolean;
        attribute schemaAttested : Boolean;
        attribute declassificationCertified : Boolean;
    }

    item def CausalAuditVerdict {
        attribute sensitiveInputObserved : Boolean;
        attribute counterfactualDecisionFlipped : Boolean;
        attribute declassificationCertified : Boolean;
        attribute implicitCausalLeakFlagged : Boolean;
    }

    item def StallAdvisoryReceipt {
        attribute repeatedFailureCount : Integer;
        attribute consecutivePremiseInvalidations : Integer;
        attribute suggestParkOrCancel : Boolean;
        attribute authorizesAutoMutation : Boolean;
    }

    port def DetourConfinementPort {
        in item detourEnvelope : ConfinedDetourEnvelope;
        out item causalVerdict : CausalAuditVerdict;
    }

    port def StallAdvisoryPort {
        out item advisory : StallAdvisoryReceipt;
    }

    part def ConfinedDetourTaintMonitor {
        port confinement : DetourConfinementPort;
        doc /* Enforces APPA-style trajectory confinement: untrusted reads stay
               inside no-egress detours and return only via attestSchema or
               3-party DeclassificationCert without polluting mainline taint. */
    }

    part def OfflineCausalCapsuleAuditor {
        port audit : ~DetourConfinementPort;
        doc /* Runs NeuroTaint-inspired zero-LLM counterfactual dependence
               checks to flag unendorsed implicit branch flips. */
    }

    part def DeterministicStallAdvisor {
        port advisory : StallAdvisoryPort;
        doc /* Emits pure advisory Park/Cancel signals on repeated failure
               signatures or premise churn with zero execution authority. */
    }

    part def LiteratureAbsorptionGovernanceSystem {
        part taintMonitor : ConfinedDetourTaintMonitor;
        part causalAuditor : OfflineCausalCapsuleAuditor;
        part stallAdvisor : DeterministicStallAdvisor;
        part verifierSuite : OrthogonalVerificationSuite;
        connection routeConfinementToAudit connect taintMonitor.confinement to causalAuditor.audit;
    }

    part absorptionSystem : LiteratureAbsorptionGovernanceSystem;

    // 1. Lean Unbounded Algebraic & Structural Preservation Laws
    requirement detourConfinementAndSchemaAttestationLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "50-literature-frontier-detour-confinement-and-causal-audit.lean";
        attribute :>> leanTheorems = "confinedDetour_isolates_untrusted_read_from_mainline, confinedDetour_no_egress_when_tainted, unattestedDetourReturn_rejected, attestedDetourReturn_preserves_mainline_taint_without_label_creep";
        doc /* Untrusted reads inside a confined detour never escalate mainline
               taint; tainted detours prohibit egress; raw unattested returns fail
               closed while schema-attested returns preserve mainline labels. */
    }

    requirement offlineCausalAuditAndAdvisoryPurityLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "50-literature-frontier-detour-confinement-and-causal-audit.lean";
        attribute :>> leanTheorems = "causalAudit_flags_unendorsed_branch_flip, causalAudit_clean_when_counterfactual_invariant, causalAudit_clean_when_declassification_certified, advisoryTrigger_fires_on_stall_threshold, advisoryTrigger_never_authorizes_auto_mutation";
        doc /* Offline counterfactual audit deterministically flags unendorsed
               sensitive branch flips; stall advisories fire at threshold while
               strictly carrying zero auto-mutation authority. */
    }

    // 2. Quint Nondeterministic Interleaving & Fault-Injection Races
    requirement detourConfinementCausalAndAdvisoryRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "50-literature-frontier-detour-confinement-and-causal-audit.qnt";
        attribute :>> quintInvariants = "confinedDetourNeverLeaksUnattestedToMainline, taintedConfinedDetourNeverEgresses, unendorsedCausalFlipAlwaysFlaggedByAudit, stallAdvisoryNeverAutoMutatesMainline";
        doc /* Under concurrent confined detour reads, schema attestations,
               offline counterfactual audits, and repeated failure streaks,
               unattested tainted merges and tainted egress never occur,
               unendorsed causal flips are always flagged, and advisories never
               auto-mutate mainline state. */
    }

    allocation ownConfinementLaw allocate detourConfinementAndSchemaAttestationLaw to absorptionSystem.taintMonitor;
    allocation verifyConfinementInLean allocate detourConfinementAndSchemaAttestationLaw to absorptionSystem.verifierSuite.leanEngine;

    allocation ownCausalAdvisoryLaw allocate offlineCausalAuditAndAdvisoryPurityLaw to absorptionSystem.causalAuditor;
    allocation verifyCausalAdvisoryInLean allocate offlineCausalAuditAndAdvisoryPurityLaw to absorptionSystem.verifierSuite.leanEngine;

    allocation ownConfinementRace allocate detourConfinementCausalAndAdvisoryRace to absorptionSystem.stallAdvisor;
    allocation verifyConfinementRaceInQuint allocate detourConfinementCausalAndAdvisoryRace to absorptionSystem.verifierSuite.quintEngine;

    verification def LiteratureAbsorptionDispatchAndBoundaryContract {
        subject target : LiteratureAbsorptionGovernanceSystem default = absorptionSystem;
        in leanAlgebraicLawsProven : Boolean;
        in quintConcurrencyRacesChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in confinementAndAuditEnforced : Boolean;
        in mode : Integer;

        attribute dispatchOk : Boolean := false;
        attribute boundaryOk : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditAbsorptionBoundary;
        action auditAbsorptionBoundary {
            assign dispatchOk := leanAlgebraicLawsProven and quintConcurrencyRacesChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign boundaryOk := confinementAndAuditEnforced or mode == 2;
            assign admitted := dispatchOk and boundaryOk;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not admitted
            or (leanAlgebraicLawsProven
                and quintConcurrencyRacesChecked
                and enginesStrictlyDisjoint
                and confinementAndAuditEnforced)
        );
    }
}
