package ContextDurableRecovery {
    private import ScalarValues::*;
    private import VerificationCases::*;
    part def Fixture;
    part fixture : Fixture;
    verification def Crash {
        subject target : Fixture default = fixture;
        in crashWindow : Integer; // 0 after inbox; 1 before commit; 2 before ack
        in replacement : Boolean;
        in mode : Integer; // 0 safe, 1 volatile, 2 early ack, 3 stale, 4 dup, 5 reset, 6 release, 7 old owner
        attribute originalRetained : Boolean := true;
        attribute ticketDurable : Boolean := false;
        attribute appliedDurable : Boolean := false;
        attribute acknowledged : Boolean := false;
        attribute terminals : Integer := 0;
        attribute currentGeneration : Integer := 1;
        attribute clockNow : Integer := 1;
        attribute invalidA : Boolean := false;
        attribute invalidB : Boolean := false;
        attribute invalidNew : Boolean := false;
        attribute invalidC : Boolean := false;
        attribute pending : Boolean := false;
        attribute oldResultAccepted : Boolean := false;
        attribute oldOwnerWrote : Boolean := false;
        attribute phase : Integer := 0;
        first start then receiveAndDecide;
        action receiveAndDecide {
            assign ticketDurable := mode != 1;
            assign appliedDurable := crashWindow == 2 and mode != 1;
            assign acknowledged := crashWindow == 2 or mode == 2;
            assign terminals := if appliedDurable ? 1 else 0;
            assign currentGeneration := if replacement ? 3 else 1;
            assign phase := 1;
        }
        then action realCrashAndRestart {
            assign clockNow := if mode == 5 ? 1 else 4;
            assign pending := terminals == 0 and mode != 6;
            assign invalidA := replacement or (ticketDurable and clockNow >= 4);
            assign invalidB := invalidA;
            assign invalidNew := replacement and mode == 3;
            assign phase := 2;
        }
        then action duplicateLateInputAndOwnerFence {
            assign terminals := if mode == 4 ? 2 else terminals;
            assign oldResultAccepted := not invalidA;
            assign oldOwnerWrote := mode == 7;
            assign phase := 3;
        }
        then done;
        out retained : Boolean = originalRetained;
        out pendingObligation : Boolean = pending;
        out terminalCount : Integer = terminals;
        out processed : Integer = phase;
        return verdict : VerdictKind = PassIf(phase == 3 and originalRetained and ticketDurable
            and (not acknowledged or appliedDurable) and clockNow >= 4 and invalidA and invalidB
            and not invalidNew and not invalidC and terminals <= 1 and (terminals == 1 or pending)
            and not oldResultAccepted and not oldOwnerWrote);
    }
}
