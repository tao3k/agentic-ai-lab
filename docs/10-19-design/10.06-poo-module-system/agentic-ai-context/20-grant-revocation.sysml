// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextGrantRevocation {
    private import ScalarValues::*;
    private import VerificationCases::*;
    part def Fixture;
    part fixture : Fixture;

    // Authority is separate from original source/proof support. B captures A's
    // old authority; C is independent. Native gates exercise actual worker races.
    verification def Control {
        subject target : Fixture default = fixture;
        in expectedSame : Boolean;
        in enabledBefore : Boolean;
        in proposalExact : Boolean;
        in alreadyApplied : Boolean;
        in inputSame : Boolean;
        in mode : Integer; // 0 safe, 1 ignore expected cut, 2 substitute input,
                           // 3 delete source support, 4 omit push, 5 resurrect
        attribute accepted : Boolean := false;
        attribute historicalAck : Boolean := false;
        attribute grantEnabled : Boolean := false;
        attribute cachedA : Boolean := false;
        attribute cachedB : Boolean := false;
        attribute sourceSupported : Boolean := true;
        attribute processed : Integer := 0;
        first start then applyControl;
        action applyControl {
            assign grantEnabled := enabledBefore;
            assign cachedA := enabledBefore;
            assign cachedB := enabledBefore;
            assign historicalAck := alreadyApplied and (inputSame or mode == 2);
            assign accepted := not alreadyApplied and (inputSame or mode == 2)
                and enabledBefore and (expectedSame or mode == 1) and proposalExact;
            assign grantEnabled := grantEnabled and not accepted;
            assign cachedA := cachedA and (not accepted or mode == 4);
            assign cachedB := cachedB and (not accepted or mode == 4);
            assign sourceSupported := not (accepted and mode == 3);
            assign grantEnabled := grantEnabled or mode == 5;
            assign processed := 1;
        }
        then done;
        out steps : Integer = processed;
        out revokedNow : Boolean = accepted;
        out ackIsHistorical : Boolean = historicalAck;
        out currentGrantEnabled : Boolean = grantEnabled;
        out affectedACurrent : Boolean = cachedA;
        out affectedBCurrent : Boolean = cachedB;
        out unrelatedCCurrent : Boolean = true;
        out originalSourceSupported : Boolean = sourceSupported;
        return verdict : VerdictKind = PassIf(processed == 1
            and accepted == (not alreadyApplied and inputSame and enabledBefore and expectedSame and proposalExact)
            and historicalAck == (alreadyApplied and inputSame)
            and grantEnabled == (enabledBefore and not accepted)
            and cachedA == grantEnabled and cachedB == grantEnabled and sourceSupported);
    }
}
