// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextCAbi {
    private import ScalarValues::*;
    private import VerificationCases::*;
    part def Fixture;
    part fixture : Fixture;
    // C lifetime/control projection. Context authority is owned by model 26;
    // executable paths below are imported from its composed QNT ITF traces.
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
        attribute bound : Boolean := false;
        attribute work : Integer := 0;
        attribute buffer : Boolean := false;
        attribute closed : Boolean := false;
        attribute owner : Integer := 1;
        attribute source : Integer := 1;
        attribute policy : Integer := 1;
        attribute active : Integer := 0;
        attribute expired : Integer := 0;
        attribute cancelRequested : Boolean := false;
        attribute recovered : Boolean := false;
        attribute terminals : Integer := 0;
        attribute unsafe : Boolean := false;
        attribute allowed : Boolean := false;
        first start then execute;
        action execute {
            for move in (e1,e2,e3,e4,e5,e6,e7,e8,e9,e10,e11,e12,e13,e14,e15,e16) {
                assign bound := if move == 1 and not closed ? true else bound;
                assign work := if move == 2 and bound and not closed and work == 0 ? 1 else work;
                assign allowed := (move == 3 and work == 1 or move == 4 and work == 2)
                    and not closed;
                assign terminals := if allowed and owner == 1 and source == 1
                    and policy == 1 and expired != 1 and active == 0
                    and (terminals == 0 or mode == 3) ? terminals + 1 else terminals;
                assign buffer := if allowed ? true else buffer;
                assign work := if move == 3 and allowed ? 2 else work;
                assign unsafe := unsafe or (move == 5 and mode == 1);
                assign allowed := move == 6 and (work != 1 or mode == 2);
                assign bound := if allowed ? false else bound;
                assign closed := if allowed ? true else closed;
                assign buffer := if move == 7 ? false else buffer;
                assign source := if move == 8 ? 2 else source;
                assign cancelRequested := if move == 9 and active == 0 ? true else cancelRequested;
                assign allowed := move == 10 and not recovered and (owner == 2 or cancelRequested);
                assign active := if allowed ? 1 else active;
                assign recovered := if allowed ? true else recovered;
                assign owner := if move == 11 ? 2 else owner;
                assign policy := if move == 12 ? 2 else policy;
                assign expired := if move == 13 and policy == 1 ? 1 else expired;
                assign unsafe := unsafe or terminals > 1 or closed and work == 1;
            }
        }
        then done;
        out boundService : Boolean = bound;
        out callPhase : Integer = work;
        out ownedBuffer : Boolean = buffer;
        out vmClosed : Boolean = closed;
        out ownerEpoch : Integer = owner;
        out sourceVersion : Integer = source;
        out policyVersion : Integer = policy;
        out activeAttempt : Integer = active;
        out expiredVersion : Integer = expired;
        out terminalCount : Integer = terminals;
        out steps : Integer = 16;
        return verdict : VerdictKind = PassIf(not unsafe);
    }
}
