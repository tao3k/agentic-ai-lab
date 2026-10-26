// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextRuntimeTopology {
    private import ScalarValues::*;
    // Structural allocation. Behavioral obligations execute in Quint and the
    // existing SysML verification cases; these parts do not instantiate nodes.
    part def ImmutableEvidenceStore;
    part def NativeAscentVerifier;
    part def ReverseSupportIndex;
    part def DurableOutbox;
    part def Transport;
    part def SessionEndpoint;
    part def WorkerPool {
        attribute maxInFlight : Integer;
    }
    part def AuthorityProvider {
        attribute ownerEpoch : Integer;
        attribute sourceVersion : Integer;
        attribute policyVersion : Integer;
    }
    part def JournalProvider {
        attribute fencingEpoch : Integer;
    }
    part def ClockProvider {
        attribute clockDomain : String;
        attribute bootIdentity : String;
    }
    part def ContextShard {
        part verifier : NativeAscentVerifier;
        part support : ReverseSupportIndex;
        part journal : JournalProvider;
        part outbox : DurableOutbox;
        part scheduler : WorkerPool;
        part clock : ClockProvider;
        ref part authority : AuthorityProvider;
        ref part evidence : ImmutableEvidenceStore;
        // Session owns endpoint lifecycle and terminal CAS, independently of
        // Context admission, proof lineage and cross-Session invalidation.
        ref part sessions : SessionEndpoint[1..*];
    }
    part def Node {
        part shards : ContextShard[1..*];
        ref part transport : Transport;
    }
    part def Runtime {
        part nodes : Node[2];
        part authorities : AuthorityProvider[1..*];
        part originalEvidence : ImmutableEvidenceStore;
        part delivery : Transport;
        part sessionEndpoints : SessionEndpoint[1..*];
    }
}
