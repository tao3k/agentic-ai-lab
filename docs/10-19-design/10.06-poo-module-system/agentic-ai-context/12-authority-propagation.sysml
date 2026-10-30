package ContextAuthorityPropagation {
    private import ScalarValues::*;
    private import VerificationCases::*;
    part def Fixture;
    part fixture : Fixture;
    // This is a contract fixture. Actual concurrency is the native owner corpus.
    verification def Dispatch {
        subject target : Fixture default = fixture;
        in eventKind : Integer; // 0 grant revoke; 1 policy revision; 2 deadline
        in observed : Integer;
        in mode : Integer; // 0 safe; 1 query only; 2 broad; 3 reset; 4 duplicate
        attribute ticketEnd : Integer := 4;
        attribute originalEvidence : Integer := 17;
        attribute retainedEvidence : Integer := 0;
        attribute published : Boolean := false;
        attribute prepared : Boolean := false;
        attribute invalidA : Boolean := false;
        attribute invalidB : Boolean := false;
        attribute invalidC : Boolean := false;
        attribute terminalCount : Integer := 0;
        attribute oldResultAllowed : Boolean := false;
        attribute cResultAllowed : Boolean := false;
        attribute phase : Integer := 0;
        first start then registerBeforeExpiry;
        action registerBeforeExpiry {
            assign retainedEvidence := originalEvidence;
            assign prepared := eventKind != 2 or observed >= ticketEnd;
            assign phase := 1;
        }
        then action prepareAndPublish {
            assign published := prepared;
            assign invalidA := published and mode != 1;
            // B's own safe authority survives; its captured A version does not.
            assign invalidB := invalidA;
            assign invalidC := published and mode == 2;
            assign phase := 2;
        }
        then action cancelAndRecover {
            assign terminalCount := 1;
            assign invalidA := if mode == 3 ? false else invalidA;
            assign invalidB := if mode == 3 ? false else invalidB;
            assign phase := 3;
        }
        then action lateResult {
            assign oldResultAllowed := published and not invalidA;
            assign terminalCount := if published and mode == 4 ? 2 else terminalCount;
            assign cResultAllowed := not invalidC;
            assign phase := 4;
        }
        then done;
        out sourcePublished : Boolean = published;
        out affectedA : Boolean = invalidA;
        out affectedB : Boolean = invalidB;
        out unaffectedC : Boolean = not invalidC;
        out evidenceRetained : Boolean = originalEvidence == retainedEvidence;
        out processed : Integer = phase;
        return verdict : VerdictKind = PassIf(phase == 4 and originalEvidence == retainedEvidence
            and (not published or (invalidA and invalidB)) and not invalidC
            and terminalCount == 1 and not oldResultAllowed and cResultAllowed);
    }
}
