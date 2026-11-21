// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextPolicyEcosystem {
    private import ScalarValues::*;
    item def CapabilityContract {
        attribute identity : String;
        attribute revision : String;
        attribute supportedOperations : String;
        attribute evidenceObligations : String;
    }
    item def PolicyValue {
        attribute identity : String;
        attribute revision : String;
        attribute restrictions : String;
    }
    item def ContextCut {
        attribute project : String;
        attribute worktree : String;
        attribute orgAnchor : String;
        attribute sourceRevision : String;
    }
    item def Decision {
        attribute selectedCapability : String;
        attribute obligations : String;
        attribute unresolvedAlternatives : String;
    }
    item def Observation {
        attribute request : String;
        attribute originalOwner : String;
        attribute sourceRevision : String;
        attribute outcome : String;
    }
    port def SemanticUse {
        in item capability : CapabilityContract;
        in item parentPolicy : PolicyValue;
        in item context : ContextCut;
        in item observation : Observation;
        out item specializedPolicy : PolicyValue;
        out item decision : Decision;
    }
    part def LabModuleLibrary {
        port semantics : SemanticUse;
        doc /* Owns reusable POO Policy, Contract and evidence interpretation.
               Capability implementations are supplied through interfaces. */
    }
    part def PackageAdapter;
    part def PhysicalOwner;
    part def DownstreamPackage {
        port semantics : ~SemanticUse;
        part adapter : PackageAdapter;
        part implementation : PhysicalOwner;
        doc /* Chooses its implementation ecosystem. AITIA, Marlin, MRR/Data,
               jj and gix are possible consumers or capabilities, not required
               components instantiated by the Lab library. */
    }
    part ecosystem {
        part lab : LabModuleLibrary;
        part consumer : DownstreamPackage;
        connection semanticUse connect consumer.semantics to lab.semantics;
    }
    requirement policyPreservation {
        doc /* Functional specialization preserves parent restrictions and
               evidence obligations. Importing a capability grants no effect. */
    }
    requirement physicalAdmission {
        doc /* The selected physical owner checks versions, authority, resources
               and budgets, executes, and retains its original observations. */
    }
    requirement correspondence {
        doc /* The adapter maps its actual types and original observations to
               the chosen Contract without inventing success or authority. */
    }
    allocation ownSemantics allocate policyPreservation to ecosystem.lab;
    allocation ownEffects allocate physicalAdmission to ecosystem.consumer.implementation;
    allocation ownMapping allocate correspondence to ecosystem.consumer.adapter;
}
