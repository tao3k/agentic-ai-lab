// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextOwnerLifecycle {
    private import ScalarValues::*;
    private import VerificationCases::*;
    part def Fixture;
    part fixture : Fixture;
    verification def Close {
        subject target : Fixture default = fixture;
        in e1 : Integer;
        in e2 : Integer;
        in e3 : Integer;
        in e4 : Integer;
        in e5 : Integer;
        in pending : Integer;
        in mode : Integer; // 0 safe; 1 omit journal close; 2 keep subscriber;
                           // 3 restore frozen clock; 4 ACK before owner join;
                           // 5 lose pending inbox; 6 invent endpoint terminal;
                           // 7 leave client admission open
        attribute stage : Integer := 0;
        attribute refused : Boolean := false;
        attribute quiesced : Boolean := false;
        attribute timerJoined : Boolean := false;
        attribute subscribers : Integer := 1;
        attribute clockRetired : Boolean := false;
        attribute journalClosed : Boolean := false;
        attribute retainedPending : Integer := pending;
        attribute terminals : Integer := 1;
        attribute processed : Integer := 0;
        first start then release;
        action release {
            for move in (e1,e2,e3,e4,e5) {
                // Illegal release orders are refused, never acknowledged closed.
                assign refused := refused or move != stage + 1;
                assign quiesced := quiesced or (not refused and move == 1 and mode != 7);
                assign timerJoined := timerJoined or (not refused and move == 2);
                assign subscribers := if not refused and move == 3 and mode != 2 ? 0 else subscribers;
                assign clockRetired := clockRetired or (not refused and move == 3 and mode != 3);
                assign terminals := if not refused and move == 3 and mode == 6 and pending > 0 ? 2 else terminals;
                assign journalClosed := journalClosed or (not refused and move == 4 and mode != 1);
                assign retainedPending := if not refused and move == 4 and mode == 5 ? 0 else retainedPending;
                assign stage := if not refused ? stage + 1 else stage;
                assign processed := processed + 1;
            }
        }
        then done;
        out steps : Integer = processed;
        out phase : Integer = stage;
        out closedAck : Boolean = stage == 5 or mode == 4;
        out pendingRetained : Integer = retainedPending;
        out terminalCount : Integer = terminals;
        out originalEvidenceRetained : Boolean = true;
        return verdict : VerdictKind = PassIf(processed == 5
            and retainedPending == pending and terminals == 1
            and ((stage != 5 and mode != 4)
                or (stage == 5 and mode != 4 and quiesced and timerJoined
                    and subscribers == 0 and clockRetired and journalClosed)));
    }
}
