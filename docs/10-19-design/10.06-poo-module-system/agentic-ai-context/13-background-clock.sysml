package ContextBackgroundClock {
    private import ScalarValues::*;
    private import VerificationCases::*;
    part def Fixture;
    part fixture : Fixture;
    verification def Deadline {
        subject target : Fixture default = fixture;
        in replacementFirst : Boolean;
        in delayed : Boolean;
        in mode : Integer; // 0 safe, 1 no timer, 2 stale applies, 3 clears, 4 duplicate
        attribute original : Integer := 17;
        attribute retained : Integer := 17;
        attribute generation : Integer := 1;
        attribute ticketGeneration : Integer := 1;
        attribute posted : Boolean := false;
        attribute invalidA : Boolean := false;
        attribute invalidB : Boolean := false;
        attribute invalidNew : Boolean := false;
        attribute invalidC : Boolean := false;
        attribute noPush : Boolean := false;
        attribute oldAccepted : Boolean := false;
        attribute terminalCount : Integer := 0;
        attribute phase : Integer := 0;
        first start then realDeadline;
        action realDeadline {
            assign generation := if replacementFirst ? 3 else 1;
            assign invalidA := replacementFirst;
            assign invalidB := replacementFirst;
            assign posted := mode != 1;
            assign noPush := not posted and not replacementFirst;
            assign phase := 1;
        }
        then action independentBackgroundDelivery {
            assign invalidA := invalidA or (posted and not delayed and generation == ticketGeneration);
            assign invalidB := invalidB or invalidA;
            assign generation := if invalidA and not replacementFirst ? 2 else generation;
            assign invalidNew := posted and not delayed and replacementFirst and mode == 2;
            assign phase := 2;
        }
        then action currentClockResultFence {
            // A live clock fence supplements the timer, including delayed delivery.
            assign invalidA := true;
            assign invalidB := true;
            assign oldAccepted := not invalidA;
            assign phase := 3;
        }
        then action delayedAndDuplicate {
            assign invalidNew := invalidNew or (posted and replacementFirst and mode == 2);
            assign terminalCount := if posted and mode == 4 ? 2 else 1;
            assign invalidA := if mode == 3 ? false else invalidA;
            assign invalidB := if mode == 3 ? false else invalidB;
            assign phase := 4;
        }
        then done;
        out noQueryViolation : Boolean = noPush;
        out newPolicyDamaged : Boolean = invalidNew;
        out evidenceRetained : Boolean = original == retained;
        out processed : Integer = phase;
        return verdict : VerdictKind = PassIf(phase == 4 and original == retained and not noPush
            and invalidA and invalidB and not invalidNew and not invalidC and not oldAccepted
            and terminalCount == 1);
    }
}
