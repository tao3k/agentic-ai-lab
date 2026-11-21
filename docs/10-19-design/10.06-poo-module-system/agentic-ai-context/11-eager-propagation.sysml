package ContextEagerPropagation {
    private import ScalarValues::*;
    private import VerificationCases::*;
    part def Fixture;
    part fixture : Fixture;
    verification def Propagate {
        subject target : Fixture default = fixture;
        in inventoryComplete : Boolean;
        in deliveryFails : Boolean;
        in mode : Integer;
        attribute originalRetained : Boolean := false;
        attribute sourcePublished : Boolean := false;
        attribute barrier : Boolean := false;
        attribute invalidA : Boolean := false;
        attribute invalidB : Boolean := false;
        attribute invalidC : Boolean := false;
        attribute activeA : Boolean := true;
        attribute activeB : Boolean := true;
        attribute activeC : Boolean := true;
        attribute pendingA : Boolean := false;
        attribute pendingB : Boolean := false;
        attribute terminalA : Integer := 0;
        attribute observedTerminalA : Boolean := false;
        attribute badPush : Boolean := false;
        attribute badUnaffected : Boolean := false;
        attribute badTerminal : Boolean := false;
        attribute acceptedOld : Boolean := false;
        attribute acceptedC : Boolean := false;
        attribute phase : Integer := 0;
        first start then retainAndPrepare;
        action retainAndPrepare {
            assign originalRetained := true;
            assign sourcePublished := inventoryComplete;
            assign barrier := inventoryComplete and deliveryFails;
            assign phase := 1;
        }
        then action synchronousPush {
            assign invalidA := inventoryComplete and not deliveryFails and mode != 1;
            assign invalidB := invalidA;
            assign invalidC := invalidA and mode == 2;
            assign pendingA := invalidA;
            assign pendingB := invalidB;
            assign activeA := not invalidA;
            assign activeB := not invalidB;
            assign activeC := not invalidC;
            assign badPush := sourcePublished and not barrier and (not invalidA or not invalidB);
            assign badUnaffected := invalidC;
            assign phase := 2;
        }
        then action cancellationAndActualTerminal {
            assign activeA := false;
            assign pendingA := false;
            assign terminalA := 1;
            assign observedTerminalA := true;
            assign phase := 3;
        }
        then action retryAgainstActualHead {
            assign invalidA := invalidA or (barrier and mode != 1);
            assign invalidB := invalidB or (barrier and mode != 1);
            assign invalidC := invalidC or (barrier and mode == 2);
            assign pendingB := pendingB or invalidB;
            assign activeB := activeB and not invalidB;
            assign activeC := activeC and not invalidC;
            assign barrier := false;
            assign phase := 4;
        }
        then action recoveryPreservesInvalidationAndTerminal {
            assign invalidA := if mode == 3 ? false else invalidA;
            assign invalidB := if mode == 3 ? false else invalidB;
            assign terminalA := if sourcePublished and mode == 4 ? 0 else terminalA;
            assign activeA := sourcePublished and mode == 4;
            assign badPush := badPush or (sourcePublished and (not invalidA or not invalidB));
            assign badUnaffected := badUnaffected or invalidC or not activeC;
            assign badTerminal := observedTerminalA and terminalA != 1;
            assign phase := 5;
        }
        then action conditionalResults {
            assign acceptedOld := activeA and not sourcePublished and not barrier and not invalidA;
            assign acceptedC := activeC and not invalidC and not barrier;
            assign phase := 6;
        }
        then done;
        out publishedSource : Boolean = sourcePublished;
        out retained : Boolean = originalRetained;
        out cachedViolation : Boolean = badPush;
        out unaffectedViolation : Boolean = badUnaffected;
        out terminalViolation : Boolean = badTerminal;
        out oldAccepted : Boolean = acceptedOld;
        out unaffectedAccepted : Boolean = acceptedC;
        out processed : Integer = phase;
        return verdict : VerdictKind = PassIf(phase == 6 and originalRetained and not badPush
            and not badUnaffected and not badTerminal and not acceptedOld and acceptedC);
    }

    verification def FrozenParent {
        subject target : Fixture default = fixture;
        in followHead : Boolean;
        attribute oldParentProof : Integer := 11;
        attribute liveHeadProof : Integer := 11;
        attribute requiredParentProof : Integer := 11;
        attribute oldVersionRetained : Boolean := false;
        attribute dependentInvalidated : Boolean := false;
        attribute liveHeadAllowed : Boolean := false;
        attribute phase : Integer := 0;
        first start then captureExactVersion;
        action captureExactVersion {
            assign requiredParentProof := oldParentProof;
            assign oldVersionRetained := true;
            assign phase := 1;
        }
        then action replaceLiveHead {
            assign liveHeadProof := 22;
            assign requiredParentProof := if followHead ? liveHeadProof else requiredParentProof;
            assign phase := 2;
        }
        then action withdrawOldRequiredPremise {
            assign dependentInvalidated := requiredParentProof == oldParentProof;
            assign liveHeadAllowed := liveHeadProof != oldParentProof;
            assign phase := 3;
        }
        then done;
        out originalRetained : Boolean = oldVersionRetained;
        out childInvalidated : Boolean = dependentInvalidated;
        out replacementAllowed : Boolean = liveHeadAllowed;
        out processed : Integer = phase;
        return verdict : VerdictKind = PassIf(phase == 3 and oldVersionRetained
            and dependentInvalidated and liveHeadAllowed);
    }
}
