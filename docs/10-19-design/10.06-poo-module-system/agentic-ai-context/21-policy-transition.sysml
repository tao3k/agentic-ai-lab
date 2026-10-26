// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextPolicyTransition {
    private import ScalarValues::*;
    private import VerificationCases::*;
    part def Fixture;
    part fixture : Fixture;

    // Admission contract only. Actual owner crashes, workers and native
    // support propagation are separate Scheme qualification obligations.
    verification def Control {
        subject target : Fixture default = fixture;
        in generationSame : Boolean;
        in digestSame : Boolean;
        in alreadyApplied : Boolean;
        in inputSame : Boolean;
        in oldTicketArrives : Boolean;
        in mode : Integer; // 0 safe; 1 skip generation; 2 skip digest;
                           // 3 substitute bytes; 4 retract evidence;
                           // 5 omit push; 6 fire stale deadline
        attribute accepted : Boolean := false;
        attribute historicalAck : Boolean := false;
        attribute cachedA : Boolean := true;
        attribute cachedB : Boolean := true;
        attribute sourceSupported : Boolean := true;
        attribute replacementUsable : Boolean := true;
        attribute processed : Integer := 0;
        first start then applyControl;
        action applyControl {
            assign historicalAck := alreadyApplied and (inputSame or mode == 3);
            assign accepted := not alreadyApplied and (inputSame or mode == 3)
                and (generationSame or mode == 1) and (digestSame or mode == 2);
            assign cachedA := not accepted or mode == 5;
            assign cachedB := not accepted or mode == 5;
            assign sourceSupported := not (accepted and mode == 4);
            assign replacementUsable := not (accepted and oldTicketArrives and mode == 6);
            assign processed := 1;
        }
        then done;
        out steps : Integer = processed;
        out replacedNow : Boolean = accepted;
        out ackIsHistorical : Boolean = historicalAck;
        out affectedACurrent : Boolean = cachedA;
        out affectedBCurrent : Boolean = cachedB;
        out unrelatedCCurrent : Boolean = true;
        out originalSourceSupported : Boolean = sourceSupported;
        out newPolicyUsable : Boolean = replacementUsable;
        return verdict : VerdictKind = PassIf(processed == 1
            and accepted == (not alreadyApplied and inputSame and generationSame and digestSame)
            and historicalAck == (alreadyApplied and inputSame)
            and cachedA == not accepted and cachedB == not accepted
            and sourceSupported and replacementUsable);
    }
}
