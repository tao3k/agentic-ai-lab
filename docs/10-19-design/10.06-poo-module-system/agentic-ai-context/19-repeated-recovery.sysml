// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextRepeatedRecovery {
    private import ScalarValues::*;
    private import VerificationCases::*;
    part def OwnerFixture;
    part fixture : OwnerFixture;

    // Five failed boots followed by a sixth boot that opens the owner.
    // Cut 0 rolls back before a new decision, cut 1 commits pending source
    // work but dies before readiness, cut 2 commits readiness then dies.
    // This abstracts storage/proof replay; native process deaths qualify those.
    verification def Restart {
        subject target : OwnerFixture default = fixture;
        in e1 : Integer;
        in e2 : Integer;
        in e3 : Integer;
        in e4 : Integer;
        in e5 : Integer;
        in consumerKind : Integer; // 0 pending A/B, 1 completed A/B, 2 no consumers
        in mode : Integer; // 0 safe, 1 repeat decided source input,
                           // 2 trust old readiness, 3 duplicate A obligation,
                           // 4 lose B's captured A dependency
        attribute ownerEpoch : Integer := 1;
        attribute readyEpoch : Integer := 0;
        attribute sourceApplied : Boolean := false;
        attribute sourceDecisions : Integer := 0;
        attribute durableActive : Boolean := false;
        attribute durablePending : Integer := 0;
        attribute workingPending : Integer := 0;
        attribute processed : Integer := 0;
        attribute bAdmitted : Boolean := false;

        first start then initialize;
        action initialize {
            assign durableActive := consumerKind == 0;
        }
        then failedBoots;
        action failedBoots {
            for cut in (e1,e2,e3,e4,e5) {
                assign ownerEpoch := ownerEpoch + 1;
                // Recover the active Attempt once, or retain its already
                // pending obligation. A crash is not termination evidence.
                assign workingPending := if consumerKind == 0 ?
                    (if durableActive ? 1 else durablePending) else 0;
                assign workingPending := if mode == 3 and consumerKind == 0
                    and not durableActive ? workingPending + 1 else workingPending;

                // Provisional work at cut 0 disappears. Committed source work
                // and its obligations survive the next owner's reconstruction.
                assign sourceDecisions := if cut > 0 and
                    (not sourceApplied or mode == 1) ? sourceDecisions + 1 else sourceDecisions;
                assign sourceApplied := sourceApplied or cut > 0;
                assign durablePending := if cut > 0 ? workingPending else durablePending;
                assign durableActive := durableActive and cut == 0;
                assign readyEpoch := if cut == 2 ? ownerEpoch else readyEpoch;
                assign processed := processed + 1;
            }
        }
        then finalBoot;
        action finalBoot {
            assign ownerEpoch := ownerEpoch + 1;
            assign workingPending := if consumerKind == 0 ?
                (if durableActive ? 1 else durablePending) else 0;
            assign workingPending := if mode == 3 and consumerKind == 0
                and not durableActive ? workingPending + 1 else workingPending;
            assign sourceDecisions := if not sourceApplied or mode == 1
                ? sourceDecisions + 1 else sourceDecisions;
            assign sourceApplied := true;
            assign durablePending := workingPending;
            assign readyEpoch := if mode == 2 and readyEpoch > 0
                ? readyEpoch else ownerEpoch;
            assign bAdmitted := mode == 4 and consumerKind != 2;
            assign processed := processed + 1;
        }
        then done;
        out steps : Integer = processed;
        out decisions : Integer = sourceDecisions;
        out pendingA : Integer = durablePending;
        out currentOwner : Integer = ownerEpoch;
        out readyOwner : Integer = readyEpoch;
        out affectedBAdmitted : Boolean = bAdmitted;
        out unaffectedCAdmitted : Boolean = consumerKind != 2;
        // Terminal bytes are immutable input in this model. Native SQL checks
        // retain the actual payload hashes through every failed recovery.
        out retainedTerminals : Integer = if consumerKind == 0 ? 1 else if consumerKind == 1 ? 3 else 0;
        return verdict : VerdictKind = PassIf(processed == 6 and sourceApplied
            and sourceDecisions == 1 and ownerEpoch == 7 and readyEpoch == ownerEpoch
            and durablePending == (if consumerKind == 0 ? 1 else 0) and not bAdmitted);
    }
}
