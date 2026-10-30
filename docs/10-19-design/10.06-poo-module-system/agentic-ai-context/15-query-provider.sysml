package ContextQueryProvider {
    private import ScalarValues::*;
    private import VerificationCases::*;
    part def Fixture;
    part fixture : Fixture;

    // Admission and current-use are separate. Same local Property ID is
    // intentionally true even in the source/version substitution countercases.
    verification def Binding {
        subject target : Fixture default = fixture;
        in sourceSame : Boolean;
        in versionSame : Boolean;
        in contractSame : Boolean;
        in querySame : Boolean;
        in sessionSame : Boolean;
        in nativeProof : Boolean;
        in mode : Integer; // 0 safe; 1 ID-only; 2 trust a claimed native proof
        attribute admitted : Boolean := false;
        attribute processed : Integer := 0;
        first start then admitCandidate;
        action admitCandidate {
            assign admitted := if mode == 1 ? true else
                sourceSame and versionSame and contractSame and querySame and sessionSame
                and (nativeProof or mode == 2);
            assign processed := 1;
        }
        then done;
        out steps : Integer = processed;
        return verdict : VerdictKind = PassIf(processed == 1 and admitted ==
            (sourceSame and versionSame and contractSame and querySame and sessionSame and nativeProof));
    }

    // Owner linearizations of real native source/result/control producer inputs.
    // This is a bounded contract, not a proof of all OS schedules or source truth.
    verification def Race {
        subject target : Fixture default = fixture;
        in o1 : Integer;
        in o2 : Integer;
        in o3 : Integer;
        in o4 : Integer;
        in o5 : Integer;
        in changeKind : Integer; // 0 replacement, 1 withdrawal then fresh admission
        in mode : Integer; // 0 safe, 1 ID-only, 2 no push, 3 unguarded commit,
                           // 4 lost parent, 5 namespace alias, 6 duplicate, 7 content Session ID
        attribute sourceOldValid : Boolean := true;
        attribute supportOld : Boolean := true;
        attribute originalProof : Boolean := true;
        attribute invalidA : Boolean := false;
        attribute invalidB : Boolean := false;
        attribute invalidC : Boolean := false;
        attribute cancelledA : Boolean := false;
        attribute terminalA : Integer := 0;
        attribute terminalB : Integer := 0;
        attribute stalePublished : Boolean := false;
        attribute stableSession : Boolean := true;
        attribute freshTerminal : Integer := 0;
        attribute freshVersion : Integer := 0;
        attribute processed : Integer := 0;
        first start then step1;
        action step1 {
            assign stalePublished := stalePublished or
                (o1 == 2 and terminalA == 0 and not cancelledA and not sourceOldValid and mode == 3) or
                (o1 == 3 and terminalB == 0 and not sourceOldValid and mode == 3);
            assign terminalA := if o1 == 2 and terminalA == 0 and not cancelledA
                and (sourceOldValid or mode == 1 or mode == 3) ? 1 else terminalA;
            assign terminalB := if o1 == 3 and terminalB == 0
                and (sourceOldValid or mode == 1 or mode == 3 or mode == 4) ? 1 else terminalB;
            assign cancelledA := cancelledA or o1 == 4 or o1 == 5;
            assign sourceOldValid := sourceOldValid and o1 != 1;
            assign supportOld := supportOld and o1 != 1;
            assign invalidA := invalidA or (o1 == 1 and mode != 1 and mode != 2);
            assign invalidB := invalidB or (o1 == 1 and mode != 1 and mode != 2 and mode != 4);
            assign invalidC := invalidC or (o1 == 1 and mode == 5);
            assign stableSession := stableSession and not (o1 == 1 and mode == 7);
            assign processed := 1;
        }
        then step2;
        action step2 {
            assign stalePublished := stalePublished or
                (o2 == 2 and terminalA == 0 and not cancelledA and not sourceOldValid and mode == 3) or
                (o2 == 3 and terminalB == 0 and not sourceOldValid and mode == 3);
            assign terminalA := if o2 == 2 and terminalA == 0 and not cancelledA
                and (sourceOldValid or mode == 1 or mode == 3) ? 1 else terminalA;
            assign terminalB := if o2 == 3 and terminalB == 0
                and (sourceOldValid or mode == 1 or mode == 3 or mode == 4) ? 1 else terminalB;
            assign cancelledA := cancelledA or o2 == 4 or o2 == 5;
            assign sourceOldValid := sourceOldValid and o2 != 1;
            assign supportOld := supportOld and o2 != 1;
            assign invalidA := invalidA or (o2 == 1 and mode != 1 and mode != 2);
            assign invalidB := invalidB or (o2 == 1 and mode != 1 and mode != 2 and mode != 4);
            assign invalidC := invalidC or (o2 == 1 and mode == 5);
            assign stableSession := stableSession and not (o2 == 1 and mode == 7);
            assign processed := 2;
        }
        then step3;
        action step3 {
            assign stalePublished := stalePublished or
                (o3 == 2 and terminalA == 0 and not cancelledA and not sourceOldValid and mode == 3) or
                (o3 == 3 and terminalB == 0 and not sourceOldValid and mode == 3);
            assign terminalA := if o3 == 2 and terminalA == 0 and not cancelledA
                and (sourceOldValid or mode == 1 or mode == 3) ? 1 else terminalA;
            assign terminalB := if o3 == 3 and terminalB == 0
                and (sourceOldValid or mode == 1 or mode == 3 or mode == 4) ? 1 else terminalB;
            assign cancelledA := cancelledA or o3 == 4 or o3 == 5;
            assign sourceOldValid := sourceOldValid and o3 != 1;
            assign supportOld := supportOld and o3 != 1;
            assign invalidA := invalidA or (o3 == 1 and mode != 1 and mode != 2);
            assign invalidB := invalidB or (o3 == 1 and mode != 1 and mode != 2 and mode != 4);
            assign invalidC := invalidC or (o3 == 1 and mode == 5);
            assign stableSession := stableSession and not (o3 == 1 and mode == 7);
            assign processed := 3;
        }
        then step4;
        action step4 {
            assign stalePublished := stalePublished or
                (o4 == 2 and terminalA == 0 and not cancelledA and not sourceOldValid and mode == 3) or
                (o4 == 3 and terminalB == 0 and not sourceOldValid and mode == 3);
            assign terminalA := if o4 == 2 and terminalA == 0 and not cancelledA
                and (sourceOldValid or mode == 1 or mode == 3) ? 1 else terminalA;
            assign terminalB := if o4 == 3 and terminalB == 0
                and (sourceOldValid or mode == 1 or mode == 3 or mode == 4) ? 1 else terminalB;
            assign cancelledA := cancelledA or o4 == 4 or o4 == 5;
            assign sourceOldValid := sourceOldValid and o4 != 1;
            assign supportOld := supportOld and o4 != 1;
            assign invalidA := invalidA or (o4 == 1 and mode != 1 and mode != 2);
            assign invalidB := invalidB or (o4 == 1 and mode != 1 and mode != 2 and mode != 4);
            assign invalidC := invalidC or (o4 == 1 and mode == 5);
            assign stableSession := stableSession and not (o4 == 1 and mode == 7);
            assign processed := 4;
        }
        then step5;
        action step5 {
            assign stalePublished := stalePublished or
                (o5 == 2 and terminalA == 0 and not cancelledA and not sourceOldValid and mode == 3) or
                (o5 == 3 and terminalB == 0 and not sourceOldValid and mode == 3);
            assign terminalA := if o5 == 2 and terminalA == 0 and not cancelledA
                and (sourceOldValid or mode == 1 or mode == 3) ? 1 else terminalA;
            assign terminalB := if o5 == 3 and terminalB == 0
                and (sourceOldValid or mode == 1 or mode == 3 or mode == 4) ? 1 else terminalB;
            assign cancelledA := cancelledA or o5 == 4 or o5 == 5;
            assign sourceOldValid := sourceOldValid and o5 != 1;
            assign supportOld := supportOld and o5 != 1;
            assign invalidA := invalidA or (o5 == 1 and mode != 1 and mode != 2);
            assign invalidB := invalidB or (o5 == 1 and mode != 1 and mode != 2 and mode != 4);
            assign invalidC := invalidC or (o5 == 1 and mode == 5);
            assign stableSession := stableSession and not (o5 == 1 and mode == 7);
            assign processed := 5;
        }
        then freshAdmission;
        // New Context version, same Session, new Attempt. Old B keeps its
        // captured old parent; fresh A cannot reactivate that version.
        action freshAdmission {
            assign terminalA := if mode == 6 and terminalA == 1 ? 2 else terminalA;
            assign freshVersion := if changeKind == 0 ? 2 else 3;
            assign freshTerminal := 1;
        }
        then done;
        out steps : Integer = processed;
        out oldTerminalCount : Integer = terminalA;
        out originalRetained : Boolean = originalProof;
        return verdict : VerdictKind = PassIf(processed == 5 and originalProof
            and not sourceOldValid and not supportOld
            and invalidA and invalidB and not invalidC and stableSession
            and not stalePublished and terminalA <= 1 and terminalB <= 1
            and freshTerminal == 1 and freshVersion >= 2);
    }
}
