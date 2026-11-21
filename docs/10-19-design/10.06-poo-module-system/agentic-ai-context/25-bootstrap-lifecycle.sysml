// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextBootstrapLifecycle {
    private import ScalarValues::*;
    private import VerificationCases::*;
    part def Fixture;
    part fixture : Fixture;
    // Scope: resource handover succeeded, anchor failed before timer enrollment.
    // The other models retain their concurrent event/publication obligations.
    verification def Abort {
        subject target : Fixture default = fixture;
        in e1 : Integer;
        in e2 : Integer;
        in e3 : Integer;
        in e4 : Integer;
        in e5 : Integer;
        in pending : Integer;
        // 1 omit rollback; 2 omit close; 3 omit join; 4 lose pending;
        // 5 invent a Session terminal; 6 remove original evidence.
        in mode : Integer;
        attribute stage : Integer := 0;
        attribute refused : Boolean := false;
        attribute activeTransaction : Boolean := true;
        attribute journalOpen : Boolean := true;
        attribute ownerJoined : Boolean := false;
        attribute retainedPending : Integer := pending;
        attribute terminals : Integer := 0;
        attribute originalRetained : Boolean := true;
        attribute processed : Integer := 0;
        first start then release;
        action release {
            for move in (e1,e2,e3,e4,e5) {
                assign refused := refused or move != stage + 1;
                assign activeTransaction := if not refused and move == 2 and mode != 1 ? false else activeTransaction;
                assign originalRetained := originalRetained and not (not refused and move == 2 and mode == 6);
                assign journalOpen := if not refused and move == 3 and mode != 2 ? false else journalOpen;
                assign retainedPending := if not refused and move == 3 and mode == 4 ? 0 else retainedPending;
                assign ownerJoined := ownerJoined or (not refused and move == 4 and mode != 3);
                assign terminals := if not refused and move == 4 and mode == 5 ? 1 else terminals;
                assign stage := if not refused ? stage + 1 else stage;
                assign processed := processed + 1;
            }
        }
        then done;
        out steps : Integer = processed;
        out phase : Integer = stage;
        out closedAck : Boolean = stage == 5;
        out pendingRetained : Integer = retainedPending;
        out terminalCount : Integer = terminals;
        out originalEvidenceRetained : Boolean = originalRetained;
        return verdict : VerdictKind = PassIf(processed == 5
            and retainedPending == pending and terminals == 0 and originalRetained
            and (stage != 5 or (not activeTransaction and not journalOpen and ownerJoined)));
    }
}
