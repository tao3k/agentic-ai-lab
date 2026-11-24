// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package YuanxuC4ProfileConvergence {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    doc /* Formalizes Yuanxu Design 165: Two-Tier Interface (`yuanxu!` + per-module
           `interface.ss`), native POO dotted-path `enabled?:` and `.o` Profile
           dispatch tables, `slot-observation` read-set capture, 7-band C4 Profile
           convergence, and `INV-1..INV-6` under FormalVerificationTaxonomy XOR dispatch. */

    item def InterfaceSlotObservation {
        attribute moduleId : String;
        attribute slotPath : String;
        attribute stage : String;       // assembly | runtime
        attribute combiner : String;    // exclusive | refine | union | meet
    }

    item def ProfileActivationReceipt {
        attribute identity : String;
        attribute band : String;        // core-defaults | implied-bridge | explicit-feature | derived-profiles | global-profiles | module-profiles | governance-floor
        attribute activation : String;  // explicit | implied | derived | tag-targeted | vetoed
        attribute conflictFree : Boolean;
    }

    port def SlotObservationPort {
        in item observedSlot : InterfaceSlotObservation;
        out item receipt : ProfileActivationReceipt;
    }

    part def YuanxuAssemblyEntrypoint {
        port assembly : SlotObservationPort;
        doc /* Tier 1 (`yuanxu!` in `init.ss`): closed explicit module universe,
               plural Global `:profiles`, and per-module `+feat` / `-feat` / `profiles:`. */
    }

    part def ModuleInterfaceConvergenceEngine {
        port convergence : ~SlotObservationPort;
        doc /* Tier 2 (`interface.ss` + `slot-observation`): evaluates dotted-path
               `enabled?:`, `.o` Profile dispatch tables, C4 bands, and peer combiners. */
    }

    part def YuanxuC4ProfileConvergenceSystem {
        part assemblyEntry : YuanxuAssemblyEntrypoint;
        part convergenceEngine : ModuleInterfaceConvergenceEngine;
        part verifierSuite : OrthogonalVerificationSuite;
        connection wireAssembly connect assemblyEntry.assembly to convergenceEngine.convergence;
    }

    part convergenceSystem : YuanxuC4ProfileConvergenceSystem;

    // 1. Lean Unbounded Algebraic & Structural Preservation Laws
    requirement closureVetoPeerAndFloorLaws : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "53-yuanxu-c4-profile-convergence-and-interface-slots.lean";
        attribute :>> leanTheorems = "impliedFeature_subset_admitted, tagTarget_subset_admitted, impliedRuleFires_monotone, explicitVeto_dominates_implied, impliedActivates_when_prereq_and_no_veto, peerExclusive_disagreement_conflicts, peerExclusive_agreement_collapses, foldGovernanceFloor_no_escalation, inactiveFeature_excluded_from_compiledClosure, runtimeStageSlot_never_expands_assemblyClosure";
        doc /* Proves INV-1..INV-6 universally over arbitrary module graphs,
               tag catalogs, peer scalar combinations, governance envelope folds,
               and assembly/runtime feature stages. */
    }

    // 2. Quint State-Machine Convergence & Fault-Injection Controls
    requirement convergenceInterleavingAndFaultControls : QuintInterleavingObligation {
        attribute :>> quintArtifact = "53-yuanxu-c4-profile-convergence-and-interface-slots.qnt";
        attribute :>> quintInvariants = "invExplicitClosure, invVetoDominance, invPeerConflictFailClosed, invGovernanceFloorMonotonic, invRuntimeStageNoCompileExpansion";
        doc /* Explores nondeterministic module admission, `-feature` veto,
               same-band peer conflicts, trust-ceiling narrowing, and runtime
               detour C4 overlays with negative-control fault injections. */
    }

    allocation ownAlgebraicLaws allocate closureVetoPeerAndFloorLaws to convergenceSystem.convergenceEngine;
    allocation verifyAlgebraicLawsInLean allocate closureVetoPeerAndFloorLaws to convergenceSystem.verifierSuite.leanEngine;

    allocation ownConvergenceModel allocate convergenceInterleavingAndFaultControls to convergenceSystem.assemblyEntry;
    allocation verifyConvergenceModelInQuint allocate convergenceInterleavingAndFaultControls to convergenceSystem.verifierSuite.quintEngine;

    verification def YuanxuC4ProfileConvergenceContract {
        subject target : YuanxuC4ProfileConvergenceSystem default = convergenceSystem;
        in leanAlgebraicLawsProven : Boolean;
        in quintInvariantsChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in zeroMagicPriorityIntegers : Boolean;
        in mode : Integer;

        attribute dispatchOk : Boolean := false;
        attribute disciplineOk : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditConvergenceBoundary;
        action auditConvergenceBoundary {
            assign dispatchOk := leanAlgebraicLawsProven and quintInvariantsChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign disciplineOk := zeroMagicPriorityIntegers or mode == 2;
            assign admitted := dispatchOk and disciplineOk;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not admitted
            or (leanAlgebraicLawsProven
                and quintInvariantsChecked
                and enginesStrictlyDisjoint
                and zeroMagicPriorityIntegers)
        );
    }
}
