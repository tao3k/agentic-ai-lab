// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextQueryDurability {
    private import ScalarValues::*;
    private import VerificationCases::*;
    part def OwnerFixture;
    part fixture : OwnerFixture;

    // Bounded durable-owner contract. No native storage or worker is simulated
    // as a proof of implementation: the companion Org lists that open gate.
    verification def Recovery {
        subject target : OwnerFixture default = fixture;
        in e1 : Integer;
        in e2 : Integer;
        in e3 : Integer;
        in e4 : Integer;
        in e5 : Integer;
        in e6 : Integer;
        in crashStage : Integer;
        in mode : Integer;
        // Events: 1 source withdrawal/crash, 2 A result, 3 B result,
        // 4 cancellation request, 5 matching reconciliation, 6 owner restart.
        // Stages: 1 inbox committed, 2 provisional decision, 3 decision committed.
        // Modes: 0 safe, 1 lose pending source, 2 lose cached consumer fences,
        // 3 ACK provisional decision, 4 omit terminal deduplication.
        attribute running : Boolean := true;
        attribute durableWithdrawn : Boolean := false;
        attribute cachedA : Boolean := true;
        attribute cachedB : Boolean := true;
        attribute cachedC : Boolean := true;
        attribute cancelReceived : Boolean := false;
        attribute reconcileReceived : Boolean := false;
        attribute queuedA : Boolean := false;
        attribute queuedB : Boolean := false;
        attribute terminalA : Integer := 0;
        attribute terminalB : Integer := 0;
        attribute completedA : Boolean := false;
        attribute completedB : Boolean := false;
        attribute badAck : Boolean := false;
        attribute stalePublication : Boolean := false;
        attribute sourceReceived : Boolean := false;
        attribute stepsDone : Integer := 0;
        attribute sourceApplications : Integer := 0;

        first start then ownerTrace;
        action ownerTrace {
            for move in (e1,e2,e3,e4,e5,e6) {
                // Crash hides provisional memory. Only stage 3 has a committed
                // source decision; earlier stages retain the durable inbox.
                assign durableWithdrawn := durableWithdrawn or
                    (move == 1 and crashStage == 3);
                assign sourceReceived := sourceReceived or move == 1;
                assign sourceApplications := if move == 1 and crashStage == 3
                    ? 1 else sourceApplications;
                assign badAck := badAck or
                    (move == 1 and crashStage != 3 and mode == 3);
                assign running := if move == 1 ? false else running;

                // Restore/replay the source command before opening the owner.
                // Stage 3 retries acknowledge history without applying twice.
                assign sourceApplications := if move == 6 and not durableWithdrawn
                    and mode != 1 ? sourceApplications + 1 else sourceApplications;
                assign durableWithdrawn := durableWithdrawn or
                    (move == 6 and mode != 1);
                assign cachedA := if move == 6 ?
                    (mode == 2 or not durableWithdrawn) else cachedA;
                assign cachedB := if move == 6 ?
                    (mode == 2 or not durableWithdrawn) else cachedB;
                assign running := running or move == 6;

                // These flags are received envelopes while down, not fabricated
                // worker termination. Event 5 denotes matching native evidence
                // in the abstraction, rather than a mere recovery request.
                assign cancelReceived := cancelReceived or move == 4;
                assign reconcileReceived := reconcileReceived or move == 5;
                assign queuedA := queuedA or (move == 2 and not running);
                assign queuedB := queuedB or (move == 3 and not running);

                // Results processed before withdrawal may finish historically.
                // Queued old results are checked only after source replay.
                assign stalePublication := stalePublication or
                    (running and not durableWithdrawn and sourceReceived
                        and (move == 2 or move == 3 or
                            (move == 6 and (queuedA or queuedB))));
                assign completedA := completedA or
                    (running and not durableWithdrawn and not cancelReceived
                        and terminalA == 0 and (move == 2 or (move == 6 and queuedA)));
                assign completedB := completedB or
                    (running and not durableWithdrawn and terminalB == 0
                        and (move == 3 or (move == 6 and queuedB)));
                assign terminalA := if terminalA == 0 and
                    (completedA or (running and reconcileReceived)) ? 1 else terminalA;
                assign terminalB := if terminalB == 0 and completedB ? 1 else terminalB;
                assign stepsDone := stepsDone + 1;
            }
        }
        then duplicateDelivery;
        action duplicateDelivery {
            // Replaying an actual completed-result receipt cannot add a second
            // terminal. Reconciliation retains a different cancellation result.
            assign terminalA := if mode == 4 and completedA
                ? terminalA + 1 else terminalA;
            assign terminalB := if mode == 4 and completedB
                ? terminalB + 1 else terminalB;
        }
        then done;
        out steps : Integer = stepsDone;
        out sourceApplied : Integer = sourceApplications;
        out sourceRevoked : Boolean = durableWithdrawn;
        out aCurrent : Boolean = cachedA;
        out bCurrent : Boolean = cachedB;
        out cCurrent : Boolean = cachedC;
        out aCompletedHistorically : Boolean = completedA;
        out bCompletedHistorically : Boolean = completedB;
        out aTerminals : Integer = terminalA;
        out bTerminals : Integer = terminalB;
        out prematureAck : Boolean = badAck;
        return verdict : VerdictKind = PassIf(stepsDone == 6 and running
            and durableWithdrawn and sourceApplications == 1
            and not cachedA and not cachedB and cachedC
            and terminalA == 1 and terminalB <= 1
            and not badAck and not stalePublication);
    }
}
