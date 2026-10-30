// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextHybridAllocation {
    private import ScalarValues::*;
    // Proposed deployment allocation. Structural validation is separate from
    // the executable 28-hybrid-runtime handoff and QNT concurrency contracts.
    part def OriginalEvidenceStore;
    part def AscentProofOwner;
    part def ReverseSupportIndex;
    part def DurableJournal;
    part def SessionEndpoint {
        // Independent lifecycle and actual terminal CAS, not an IO completion.
        attribute attemptRevision : Integer;
    }
    part def SchedulingContract {
        attribute semanticRevision : Integer := 1;
        attribute dataCredits : Integer;
        attribute controlCredits : Integer;
        attribute controlBurst : Integer;
    }
    part def NativeContextOwner {
        part scheduling : SchedulingContract;
        part reverseSupport : ReverseSupportIndex;
        part journal : DurableJournal;
        ref part proof : AscentProofOwner;
        ref part evidence : OriginalEvidenceStore;
        ref part sessions : SessionEndpoint[1..*];
        attribute ownerEpoch : Integer;
    }
    part def SchemeVm {
        // Heap, continuations, roots and Actor scheduling stay in this VM.
        part contexts : NativeContextOwner[1..*];
        part proof : AscentProofOwner;
        attribute maximumHeapBytes : Integer := 2147483648;
    }
    part def NativeServiceBoundary {
        // Compiler-produced C ABI; transfer copied bytes, never borrowed roots.
        attribute productionContextExportImplemented : Boolean := false;
        attribute preSetupHeapPolicyImplemented : Boolean := false;
    }
    part def FixedNativeOwner {
        part vm : SchemeVm;
        part service : NativeServiceBoundary;
        // A route identifies a pinned native owner, not a Session or grant.
        attribute route : Integer;
    }
    part def TokioExecutor;
    part def BoundedIoFeed {
        // The host reservation must preserve controls before Scheme ingress.
        attribute endToEndControlReserveImplemented : Boolean := false;
    }
    part def OptionalCpuPool;
    part def RustAdapter {
        part asyncIo : TokioExecutor;
        part input : BoundedIoFeed;
        part nativeOwners : FixedNativeOwner[2..*];
        part compute : OptionalCpuPool[0..1];
    }
    part def HybridNode {
        part runtime : RustAdapter;
        part evidence : OriginalEvidenceStore;
        part sessions : SessionEndpoint[1..*];
    }
}
