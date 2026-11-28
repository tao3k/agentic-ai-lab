// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextPolicyMigration {
    private import ScalarValues::*;
    private import VerificationCases::*;
    part def Fixture;
    part fixture : Fixture;
    verification def Race {
        subject target : Fixture default = fixture;
        in e1 : Integer;
        in e2 : Integer;
        in e3 : Integer;
        in e4 : Integer;
        in e5 : Integer;
        in profile : Integer; // 0 canonical, 1 old name with CAS, 2 old missing cut
        in expiredBefore : Boolean; // queued timer versus live-clock abstract cut
        in mode : Integer; // 0 safe; 1 skip generation; 2 guess legacy cut;
                           // 3 stale ticket; 4 duplicate terminal;
                           // 5 revive old result; 6 execute legacy callback
        attribute generation : Integer := 1;
        attribute newPolicy : Boolean := false;
        attribute accepted : Boolean := false;
        attribute active : Boolean := true;
        attribute invalid : Boolean := false;
        attribute terminal : Integer := 0;
        attribute unsafeTicket : Boolean := false;
        attribute unsafeCallback : Boolean := false;
        attribute processed : Integer := 0;
        first start then execute;
        action execute {
            for move in (e1,e2,e3,e4,e5) {
                // The old ticket may affect only its captured generation 1.
                assign unsafeTicket := unsafeTicket or (move == 1 and newPolicy and mode == 3);
                assign invalid := invalid or (move == 1 and generation == 1);
                assign generation := if move == 1 and generation == 1 ? 2 else generation;
                // Missing historical expectations cannot be invented at replay.
                assign accepted := if move == 2 ?
                    ((profile != 2 or mode == 2) and (generation == 1 or mode == 1 or mode == 2))
                    else accepted;
                assign newPolicy := newPolicy or (move == 2 and accepted);
                assign invalid := invalid or (move == 2 and accepted);
                assign generation := if move == 2 and accepted ? generation + 1 else generation;
                assign unsafeCallback := unsafeCallback or (move == 2 and profile != 0 and mode == 6);
                // Current-use guards also catch a delayed timer at actual time.
                assign invalid := invalid or (move == 3 and expiredBefore and not newPolicy);
                assign generation := if move == 3 and expiredBefore and not newPolicy and generation == 1 ? 2 else generation;
                assign terminal := if move == 3 and active and not invalid and terminal == 0 ? 1 else terminal;
                assign active := active and move != 4 and move != 5 and terminal == 0;
                assign processed := processed + 1;
            }
            assign terminal := if mode == 4 and terminal > 0 ? 2 else terminal;
        }
        then done;
        out steps : Integer = processed;
        out replacementAccepted : Boolean = accepted;
        out finalGeneration : Integer = generation;
        out terminalCount : Integer = terminal;
        out oldCurrent : Boolean = mode == 5 and terminal > 0;
        out affectedInvalid : Boolean = invalid;
        out independentCurrent : Boolean = true;
        out originalEvidenceRetained : Boolean = true;
        return verdict : VerdictKind = PassIf(processed == 5 and generation == 2
            and terminal <= 1 and not (mode == 5 and terminal > 0)
            and not unsafeTicket and not unsafeCallback
            and not (profile == 2 and accepted) and invalid);
    }
}
