package ContextContractComparison {
    private import ScalarValues::*;
    private import VerificationCases::*;
    doc /* Contract omission experiments, NOT executable implementations of Scroll,
           CarryOn or CLM. External owner changes leave candidate revision fixed.
           Native companions exercise real proof/journal/grant/Session Hosts. */
    part def Fixture;
    part fixture : Fixture;
    verification def EvidenceUse {
        subject target : Fixture default = fixture;
        in withdraw : Boolean;
        in revoke : Boolean;
        in foreignConsumer : Boolean;
        in reboundAttempt : Boolean;
        in mode : Integer;
        attribute retained : Boolean := false;
        attribute historicalProof : Boolean := false;
        attribute currentProof : Boolean := true;
        attribute currentGrant : Boolean := true;
        attribute consumer : Integer := 1;
        attribute attemptOwner : Integer := 1;
        attribute capturedCandidateRevision : Integer := 0;
        attribute candidateRevision : Integer := 7;
        attribute modelClaimsAllow : Boolean := false;
        attribute published : Boolean := false;
        attribute terminals : Integer := 0;
        attribute phase : Integer := 0;
        first start then retainOriginal;
        action retainOriginal {
            assign retained := true;
            assign historicalProof := true;
            assign phase := 1;
        }
        then action selectWorkingContext {
            assign capturedCandidateRevision := candidateRevision;
            assign modelClaimsAllow := true;
            assign phase := 2;
        }
        then action independentOwnersChange {
            assign currentProof := not withdraw;
            assign currentGrant := not revoke;
            assign consumer := if foreignConsumer ? 2 else 1;
            assign attemptOwner := if reboundAttempt ? 2 else 1;
            assign phase := 3;
        }
        then action conditionalFinalPublication {
            assign published := if mode == 1 ? (retained and historicalProof)
                else if mode == 2 ? (capturedCandidateRevision == candidateRevision and consumer == 1 and attemptOwner == 1)
                else if mode == 3 ? modelClaimsAllow
                else if mode == 4 ? (retained and currentProof and currentGrant)
                else (retained and currentProof and currentGrant and capturedCandidateRevision == candidateRevision
                    and consumer == 1 and attemptOwner == 1);
            assign terminals := if published ? 1 else 0;
            assign phase := 4;
        }
        then done;
        out accepted : Boolean = published;
        out historyRetained : Boolean = retained;
        out revisionUnchanged : Boolean = capturedCandidateRevision == candidateRevision;
        out terminalCount : Integer = terminals;
        out processed : Integer = phase;
        return verdict : VerdictKind = PassIf(phase == 4 and retained and historicalProof
            and terminals <= 1 and (not published or (currentProof and currentGrant
                and consumer == 1 and attemptOwner == 1 and capturedCandidateRevision == candidateRevision)));
    }
}
