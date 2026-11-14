// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextRuntimeCredential {
    private import ScalarValues::*;
    private import VerificationCases::*;
    part def Fixture;
    part fixture : Fixture;
    verification def Read {
        subject target : Fixture default = fixture;
        in e1 : Integer;
        in e2 : Integer;
        in e3 : Integer;
        in e4 : Integer;
        in e5 : Integer;
        in foreign : Integer;
        in mode : Integer; // 0 owner-sealed historical read; 1 historical-as-current;
                           // 2 bypass owner; 3 expose mutable private digest
        attribute supported : Boolean := true;
        attribute replayValid : Boolean := true;
        attribute originalRetained : Boolean := true;
        attribute denied : Boolean := false;
        attribute unsafeRead : Boolean := false;
        attribute unsafePublish : Boolean := false;
        attribute terminals : Integer := 0;
        attribute currentResult : Boolean := false;
        attribute processed : Integer := 0;
        first start then execute;
        action execute {
            for move in (e1,e2,e3,e4,e5) {
                // Only step 1 is a direct read of a possessed host capability.
                // Result submission is delivered to the real serialized owner.
                assign denied := denied or (move == 1 and foreign == 1 and mode != 2);
                assign unsafeRead := unsafeRead or (move == 1 and foreign == 1 and mode == 2);
                assign supported := supported and move != 2;
                assign replayValid := replayValid and move != 3;
                assign currentResult := currentResult and move != 2 and move != 3;
                assign originalRetained := originalRetained and not (move == 5 and mode == 3);
                if move == 4 and (mode == 1 or (supported and replayValid)) {
                    assign unsafePublish := unsafePublish or not (supported and replayValid);
                    assign terminals := terminals + 1;
                    assign currentResult := true;
                }
                assign processed := processed + 1;
            }
        }
        then done;
        out steps : Integer = processed;
        out terminalCount : Integer = terminals;
        out foreignReadDenied : Boolean = denied;
        out originalEvidenceRetained : Boolean = originalRetained;
        out resultCurrent : Boolean = currentResult;
        return verdict : VerdictKind = PassIf(processed == 5 and terminals <= 1
            and originalRetained and not unsafeRead and not unsafePublish
            and (not currentResult or (supported and replayValid)));
    }
}
