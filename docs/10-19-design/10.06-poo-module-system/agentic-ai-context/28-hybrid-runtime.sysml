// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextHybridRuntime {
    private import ScalarValues::*;
    private import VerificationCases::*;
    part def Fixture;
    part fixture : Fixture;
    // Runtime allocation: Tokio IO/arrival -> fixed Scheme VM owner ->
    // Context authority commit -> independent Session terminal CAS.
    // Only owned copied bytes cross the foreign boundary; proof remains native.
    verification def Handoff {
        subject target : Fixture default = fixture;
        in e1 : Integer;
        in e2 : Integer;
        in e3 : Integer;
        in e4 : Integer;
        in e5 : Integer;
        in e6 : Integer;
        in e7 : Integer;
        in e8 : Integer;
        in e9 : Integer;
        in e10 : Integer;
        in e11 : Integer;
        in e12 : Integer;
        in e13 : Integer;
        in e14 : Integer;
        in e15 : Integer;
        in e16 : Integer;
        in mode : Integer;
        attribute work : Integer := 0;
        attribute credit : Integer := 0;
        attribute joined : Boolean := false;
        attribute data : Integer := 0;
        attribute controls : Integer := 0;
        attribute busy : Integer := 0;
        attribute burst : Integer := 0;
        attribute phase : Integer := 0;
        attribute source : Integer := 1;
        attribute policy : Integer := 1;
        attribute owner : Integer := 1;
        attribute attempt : Integer := 0;
        attribute terminals : Integer := 0;
        attribute expired : Integer := 0;
        attribute revoked : Boolean := false;
        attribute aValid : Boolean := true;
        attribute bValid : Boolean := true;
        attribute pendingA : Boolean := false;
        attribute pendingB : Boolean := false;
        attribute acknowledged : Boolean := false;
        attribute cancelled : Boolean := false;
        attribute recovered : Boolean := false;
        attribute unsafe : Boolean := false;
        attribute preferred : Boolean := false;
        attribute chosen : Integer := 0;
        attribute allowed : Boolean := false;
        attribute processed : Integer := 0;
        first start then execute;
        action execute {
            for move in (e1,e2,e3,e4,e5,e6,e7,e8,e9,e10,e11,e12,e13,e14,e15,e16) {
                // Foreign wait expiry is observation, never execution return.
                assign credit := if move == 1 and work == 0 and not joined and phase == 0 ? 1 else credit;
                assign work := if move == 1 and work == 0 and not joined and phase == 0 ? 1 else work;
                assign credit := if move == 2 and work == 1 and mode == 2 ? 0 else credit;
                assign credit := if move == 3 and work == 1 ? 0 else credit;
                assign work := if move == 3 and work == 1 ? 2 else work;
                // Candidate bytes can outlive their native execution credit.
                assign data := if move == 4 and work >= 2 and not joined and phase == 0
                    and data + (if busy == 1 ? 1 else 0) < 2 ? data + 1 else data;
                assign work := if move == 4 and work >= 2 and not joined ? 3 else work;
                assign preferred := controls > 0 and (data == 0 or burst < 2);
                assign chosen := if move == 5 and phase != 2 and busy == 0 ?
                    (if preferred ? 2 else (if data > 0 ? 1 else 0)) else 0;
                assign data := if chosen == 1 ? data - 1 else data;
                assign controls := if chosen == 2 ? controls - 1 else controls;
                assign burst := if chosen == 1 ? 0 else (if chosen == 2 and burst < 2 ? burst + 1 else burst);
                assign busy := if chosen != 0 ? chosen else busy;
                // The source fence precedes delivery. A full queue cannot ACK it.
                assign source := if move == 6 and not revoked ? 2 else source;
                assign pendingA := pendingA or (move == 6 and not revoked);
                assign pendingB := pendingB or (move == 6 and not revoked);
                assign controls := if move == 6 and not revoked and phase == 0
                    and controls + (if busy == 2 ? 1 else 0) < 1 ? controls + 1 else controls;
                assign revoked := revoked or move == 6;
                // Original candidate captured owner/source/policy=1, Attempt=0.
                assign allowed := move == 7 and busy == 1 and owner == 1 and policy == 1
                    and expired != 1 and attempt == 0 and (terminals == 0 or mode == 4)
                    and (if mode == 1 ? aValid else not revoked and source == 1);
                assign unsafe := unsafe or (allowed and revoked);
                assign terminals := if allowed ? terminals + 1 else terminals;
                assign busy := if move == 7 and busy == 1 ? 0 else busy;
                assign phase := if move == 8 and phase == 0 ? 1 else phase;
                assign joined := joined or (move == 9 and phase == 1 and data == 0
                    and controls == 0 and busy == 0 and (work != 1 or mode == 3));
                assign phase := if joined ? 2 else phase;
                assign policy := if move == 10 and policy == 1 ? 2 else policy;
                assign cancelled := cancelled or (move == 11 and attempt == 0);
                assign attempt := if move == 12 and not recovered and (owner == 2 or cancelled) ? 1 else attempt;
                assign recovered := recovered or (move == 12 and (owner == 2 or cancelled));
                // Consumers A/B share this authority; independent C is unchanged.
                assign aValid := aValid and not (move == 13 and busy == 2 and revoked);
                assign pendingA := pendingA and not (move == 13 and busy == 2 and revoked);
                assign bValid := bValid and not (move == 21 and busy == 2 and revoked);
                assign pendingB := pendingB and not (move == 21 and busy == 2 and revoked);
                assign busy := if (move == 13 or move == 21) and busy == 2 and revoked ? 0 else busy;
                assign owner := if move == 14 and owner == 1 ? 2 else owner;
                assign expired := if move == 15 and policy == 1 ? 1 else expired;
                assign controls := if move == 16 and revoked and (pendingA or pendingB) and phase == 0
                    and controls + (if busy == 2 ? 1 else 0) < 1 ? controls + 1 else controls;
                assign acknowledged := acknowledged or (move == 17 and revoked and not pendingA and not pendingB);
                assign terminals := if move == 18 and cancelled and terminals == 0 ? 1 else terminals;
                // Prefix failures remain failures after a later normal completion.
                assign unsafe := unsafe or terminals > 1 or (work == 1 and credit != 1)
                    or (joined and work == 1) or (acknowledged and (aValid or bValid))
                    or data + (if busy == 1 ? 1 else 0) > 2
                    or controls + (if busy == 2 ? 1 else 0) > 1;
                assign processed := processed + 1;
            }
        }
        then done;
        out workPhase : Integer = work;
        out nativeCredit : Integer = credit;
        out ownerJoined : Boolean = joined;
        out queuedData : Integer = data;
        out queuedControls : Integer = controls;
        out activeHandler : Integer = busy;
        out queuePhase : Integer = phase;
        out sourceVersion : Integer = source;
        out policyVersion : Integer = policy;
        out ownerEpoch : Integer = owner;
        out activeAttempt : Integer = attempt;
        out terminalCount : Integer = terminals;
        out steps : Integer = processed;
        return verdict : VerdictKind = PassIf(not unsafe and processed == 16);
    }
}
