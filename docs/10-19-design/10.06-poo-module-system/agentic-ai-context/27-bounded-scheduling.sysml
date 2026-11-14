// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextBoundedScheduling {
    private import ScalarValues::*;
    private import VerificationCases::*;
    part def Fixture;
    part fixture : Fixture;
    // Projection: context.scheduling-contract.v1, semantic revision 1.
    // Modes 1/2/3/4 break capacity, selection, drain fencing and burst bounds.
    verification def Scheduling {
        subject target : Fixture default = fixture;
        in e1 : Integer; in e2 : Integer; in e3 : Integer;
        in e4 : Integer; in e5 : Integer; in e6 : Integer;
        in e7 : Integer; in e8 : Integer; in e9 : Integer;
        in e10 : Integer; in e11 : Integer; in e12 : Integer;
        in mode : Integer;
        attribute data : Integer := 0;
        attribute controls : Integer := 0;
        attribute busy : Integer := 0;
        attribute burst : Integer := 0;
        attribute phase : Integer := 0;
        attribute preferred : Boolean := false;
        attribute chosen : Integer := 0;
        attribute unsafe : Boolean := false;
        attribute processed : Integer := 0;
        first start then execute;
        action execute {
            for move in (e1,e2,e3,e4,e5,e6,e7,e8,e9,e10,e11,e12) {
                // Admission retains credits for work already dispatched.
                assign data := if move == 1 and phase == 0
                    and (data + (if busy == 1 ? 1 else 0) < 2 or mode == 1) ? data + 1 else data;
                assign controls := if move == 2 and phase == 0
                    and controls + (if busy == 2 ? 1 else 0) < 1 ? controls + 1 else controls;
                assign preferred := controls > 0 and (data == 0 or burst < 2);
                assign chosen := if move == 3 and phase != 2 and busy == 0 ?
                    (if (preferred or (mode == 4 and controls > 0)) and (mode != 2 or data == 0) ? 2 else (if data > 0 ? 1 else 0)) else 0;
                assign unsafe := unsafe or (chosen == 1 and preferred)
                    or (chosen == 2 and data > 0 and burst >= 2);
                assign data := if chosen == 1 ? data - 1 else data;
                assign controls := if chosen == 2 ? controls - 1 else controls;
                assign burst := if chosen == 1 ? 0 else (if chosen == 2 and burst < 2 ? burst + 1 else burst);
                assign busy := if chosen != 0 ? chosen else busy;
                assign busy := if move == 4 ? 0 else busy;
                assign phase := if move == 5 and phase == 0 ? 1 else phase;
                assign phase := if move == 6 and phase == 1
                    and ((data == 0 and controls == 0 and busy == 0) or mode == 3) ? 2 else phase;
                // Remember a bad prefix even if a later completion drains it.
                assign unsafe := unsafe or data + (if busy == 1 ? 1 else 0) > 2
                    or controls + (if busy == 2 ? 1 else 0) > 1
                    or (phase == 2 and (data != 0 or controls != 0 or busy != 0));
                assign processed := processed + 1;
            }
        }
        then done;
        out queuedData : Integer = data;
        out queuedControls : Integer = controls;
        out active : Integer = busy;
        out consecutiveControls : Integer = burst;
        out lifecycle : Integer = phase;
        out steps : Integer = processed;
        return verdict : VerdictKind = PassIf(not unsafe and processed == 12);
    }
}
