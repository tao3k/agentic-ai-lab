// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextExecutableScenarios {
    private import ScalarValues::*;
    private import VerificationCases::*;

    doc /* Executable finite fixtures refining the owner crossings in 03.
               Integers stand for exact owner generations/identities, Booleans for
               explicitly enrolled owner observations. No cryptography, real
               provider, CAS implementation or source authentication is modeled.
               unsafe inputs deliberately remove one gate while preserving the
               verification oracle. See 04-executable-scenarios.org for Org owners. */
    part def ProtocolFixture;
    part fixture : ProtocolFixture;

    verification def ResultAdmission {
        subject target : ProtocolFixture;
        in changeSource : Boolean;
        in revokeGrant : Boolean;
        in wrongResponse : Boolean;
        in unsafeSkipFence : Boolean;
        attribute sourceGeneration : Integer := 1;
        attribute grantGeneration : Integer := 1;
        attribute inputSource : Integer := 0;
        attribute inputGrant : Integer := 0;
        attribute requestId : Integer := 11;
        attribute responseId : Integer := 0;
        attribute disclosed : Boolean := false;
        attribute historicalRecorded : Boolean := false;
        attribute resultAccepted : Boolean := false;
        attribute phase : Integer := 0;
        first start then prepareInput;
        action prepareInput {
            assign inputSource := sourceGeneration;
            assign inputGrant := grantGeneration;
            assign phase := 1;
        }
        then action dispatchUnderFence {
            assign disclosed := inputSource == sourceGeneration and inputGrant == grantGeneration;
            assign phase := 2;
        }
        then action ownerChanges {
            assign sourceGeneration := if changeSource ? 2 else 1;
            assign grantGeneration := if revokeGrant ? 2 else 1;
            assign phase := 3;
        }
        then action sessionRecordsResponse {
            assign responseId := if wrongResponse ? 99 else requestId;
            assign historicalRecorded := true;
            assign phase := 4;
        }
        then action contextAdmitsResult {
            assign resultAccepted := disclosed and historicalRecorded and responseId == requestId
                and (unsafeSkipFence or (inputSource == sourceGeneration and inputGrant == grantGeneration));
            assign phase := 5;
        }
        then done;
        out accepted : Boolean = resultAccepted;
        out historyPreserved : Boolean = historicalRecorded;
        out currentSource : Integer = sourceGeneration;
        out finished : Integer = phase;
        return verdict : VerdictKind = PassIf(phase == 5 and historicalRecorded and disclosed
            and (not resultAccepted or (responseId == requestId
                and inputSource == sourceGeneration and inputGrant == grantGeneration)));
    }

    verification def CancellationRecovery {
        subject target : ProtocolFixture;
        in terminalObserved : Boolean;
        in matchingWorker : Boolean;
        in closedSession : Boolean;
        in currentRecoveryFence : Boolean;
        in unsafeCancelIsTerminal : Boolean;
        in unsafeReopenClosed : Boolean;
        attribute sessionRevision : Integer := 7;
        attribute checkpointRevision : Integer := 0;
        attribute checkpointPending : Boolean := true;
        attribute claimGeneration : Integer := 3;
        attribute workerId : Integer := 41;
        attribute receiptWorker : Integer := 0;
        attribute cancelRequested : Boolean := false;
        attribute pendingWorker : Boolean := true;
        attribute oldAllowRestored : Boolean := false;
        attribute recoveryCurrent : Boolean := false;
        attribute resumed : Boolean := false;
        attribute historicalLateResponse : Boolean := false;
        attribute terminalOutcomeCount : Integer := 0;
        attribute phase : Integer := 0;
        first start then requestCancellation;
        action requestCancellation {
            assign cancelRequested := true;
            // Requesting cancellation is not a terminal worker observation.
            assign phase := 1;
        }
        then action checkpointAndRestart {
            assign checkpointRevision := sessionRevision;
            assign checkpointPending := pendingWorker;
            assign pendingWorker := checkpointPending;
            assign oldAllowRestored := false;
            assign phase := 2;
        }
        then action observeWorkerEvidence {
            assign receiptWorker := if matchingWorker ? workerId else 99;
            assign pendingWorker := not ((terminalObserved and receiptWorker == workerId)
                or (unsafeCancelIsTerminal and cancelRequested));
            assign terminalOutcomeCount := if pendingWorker ? 0 else 1;
            assign phase := 3;
        }
        then action reenrollAndResume {
            assign recoveryCurrent := not pendingWorker and currentRecoveryFence;
            assign sessionRevision := if recoveryCurrent ? checkpointRevision + 1 else checkpointRevision;
            assign claimGeneration := if recoveryCurrent ? 4 else 3;
            assign resumed := recoveryCurrent and (not closedSession or unsafeReopenClosed);
            assign phase := 4;
        }
        then action recordLateCompletion {
            assign historicalLateResponse := true;
            // Late observation does not overwrite or add a terminal outcome.
            assign phase := 5;
        }
        then done;
        out pending : Boolean = pendingWorker;
        out didResume : Boolean = resumed;
        out revision : Integer = sessionRevision;
        out generation : Integer = claimGeneration;
        out lateHistory : Boolean = historicalLateResponse;
        out outcomeCount : Integer = terminalOutcomeCount;
        out restoredOldAllow : Boolean = oldAllowRestored;
        return verdict : VerdictKind = PassIf(phase == 5 and cancelRequested
            and historicalLateResponse and checkpointPending and not oldAllowRestored
            and terminalOutcomeCount == (if pendingWorker ? 0 else 1)
            and (pendingWorker or (terminalObserved and receiptWorker == workerId))
            and (not resumed or (not closedSession and not pendingWorker
                and currentRecoveryFence and sessionRevision > checkpointRevision and claimGeneration > 3)));
    }

    verification def KnowledgeConsolidation {
        subject target : ProtocolFixture;
        in lineageAvailable : Boolean;
        in contraryEvidenceRetained : Boolean;
        in obligationsMet : Boolean;
        in unsafeSummaryPromotes : Boolean;
        attribute originalEpisode : Integer := 101;
        attribute episodeRetained : Boolean := false;
        attribute assessedRevision : Integer := 0;
        attribute interpretationRevision : Integer := 0;
        attribute scopedAssumptions : Boolean := false;
        attribute longTermAccepted : Boolean := false;
        attribute authorityGeneration : Integer := 5;
        attribute phase : Integer := 0;
        first start then captureExactEpisode;
        action captureExactEpisode {
            assign episodeRetained := true;
            assign phase := 1;
        }
        then action reassessAgainstCurrentCut {
            assign assessedRevision := originalEpisode;
            assign scopedAssumptions := true;
            assign phase := 2;
        }
        then action proposeAndAdmitAbstraction {
            assign longTermAccepted := unsafeSummaryPromotes or (lineageAvailable
                and contraryEvidenceRetained and obligationsMet and scopedAssumptions
                and assessedRevision == originalEpisode);
            assign interpretationRevision := if longTermAccepted ? 102 else 0;
            assign phase := 3;
        }
        then done;
        out promoted : Boolean = longTermAccepted;
        out originalRetained : Boolean = episodeRetained;
        out derivedRevision : Integer = interpretationRevision;
        out grantGeneration : Integer = authorityGeneration;
        return verdict : VerdictKind = PassIf(phase == 3 and episodeRetained
            and authorityGeneration == 5 and (not longTermAccepted or
                (lineageAvailable and contraryEvidenceRetained and obligationsMet
                    and scopedAssumptions and assessedRevision == originalEpisode
                    and interpretationRevision != originalEpisode)));
    }

    verification def CrossSessionRecall {
        subject target : ProtocolFixture;
        in freshTargetReview : Boolean;
        in currentPermission : Boolean;
        in sourceChanges : Boolean;
        in policyChanges : Boolean;
        in unsafeInheritOldAdmission : Boolean;
        attribute originSession : Integer := 1;
        attribute destinationSession : Integer := 2;
        attribute reviewSession : Integer := 1;
        attribute reviewPolicy : Integer := 8;
        attribute currentPolicy : Integer := 8;
        attribute retainedSource : Integer := 12;
        attribute currentSource : Integer := 12;
        attribute candidateSource : Integer := 0;
        attribute projectionSession : Integer := 0;
        attribute lineagePreserved : Boolean := false;
        attribute recallAdmitted : Boolean := false;
        attribute providerDispatched : Boolean := false;
        attribute phase : Integer := 0;
        first start then recallHistoricalCandidate;
        action recallHistoricalCandidate {
            assign lineagePreserved := true;
            assign candidateSource := retainedSource;
            assign phase := 1;
        }
        then action observeCurrentOwners {
            assign currentSource := if sourceChanges ? 13 else 12;
            assign currentPolicy := if policyChanges ? 9 else 8;
            assign reviewSession := if freshTargetReview ? destinationSession else originSession;
            // The sealed review policy stays at 8; a policy change requires another review.
            assign phase := 2;
        }
        then action projectForDestination {
            assign projectionSession := destinationSession;
            assign phase := 3;
        }
        then action admitNewConsumption {
            assign recallAdmitted := unsafeInheritOldAdmission or (lineagePreserved
                and projectionSession == destinationSession and reviewSession == destinationSession
                and reviewPolicy == currentPolicy and candidateSource == currentSource and currentPermission);
            assign phase := 4;
        }
        then done;
        out admittedForB : Boolean = recallAdmitted;
        out originPreserved : Boolean = lineagePreserved;
        out reviewOwner : Integer = reviewSession;
        out projectionOwner : Integer = projectionSession;
        out dispatched : Boolean = providerDispatched;
        return verdict : VerdictKind = PassIf(phase == 4 and lineagePreserved
            and originSession != destinationSession and not providerDispatched
            and (not recallAdmitted or (reviewSession == destinationSession
                and projectionSession == destinationSession and reviewPolicy == currentPolicy
                and candidateSource == currentSource and currentPermission)));
    }

    verification freshResult : ResultAdmission {
        subject :>> target = fixture;
        in changeSource = false; in revokeGrant = false; in wrongResponse = false; in unsafeSkipFence = false;
    }
    verification staleSourceResult : ResultAdmission {
        subject :>> target = fixture;
        in changeSource = true; in revokeGrant = false; in wrongResponse = false; in unsafeSkipFence = false;
    }
    verification revokedGrantResult : ResultAdmission {
        subject :>> target = fixture;
        in changeSource = false; in revokeGrant = true; in wrongResponse = false; in unsafeSkipFence = false;
    }
    verification wrongRequestResult : ResultAdmission {
        subject :>> target = fixture;
        in changeSource = false; in revokeGrant = false; in wrongResponse = true; in unsafeSkipFence = false;
    }
    verification unsafeStaleResult : ResultAdmission {
        subject :>> target = fixture;
        in changeSource = true; in revokeGrant = false; in wrongResponse = false; in unsafeSkipFence = true;
    }

    verification cancelStillPending : CancellationRecovery {
        subject :>> target = fixture;
        in terminalObserved = false; in matchingWorker = true; in closedSession = false; in currentRecoveryFence = true;
        in unsafeCancelIsTerminal = false; in unsafeReopenClosed = false;
    }
    verification recoveredWithTerminalEvidence : CancellationRecovery {
        subject :>> target = fixture;
        in terminalObserved = true; in matchingWorker = true; in closedSession = false; in currentRecoveryFence = true;
        in unsafeCancelIsTerminal = false; in unsafeReopenClosed = false;
    }
    verification foreignWorkerReceipt : CancellationRecovery {
        subject :>> target = fixture;
        in terminalObserved = true; in matchingWorker = false; in closedSession = false; in currentRecoveryFence = true;
        in unsafeCancelIsTerminal = false; in unsafeReopenClosed = false;
    }
    verification closedSessionRecovery : CancellationRecovery {
        subject :>> target = fixture;
        in terminalObserved = true; in matchingWorker = true; in closedSession = true; in currentRecoveryFence = true;
        in unsafeCancelIsTerminal = false; in unsafeReopenClosed = false;
    }
    verification deniedRecoveryFence : CancellationRecovery {
        subject :>> target = fixture;
        in terminalObserved = true; in matchingWorker = true; in closedSession = false;
        in currentRecoveryFence = false;
        in unsafeCancelIsTerminal = false; in unsafeReopenClosed = false;
    }
    verification unsafeCancelAcknowledgement : CancellationRecovery {
        subject :>> target = fixture;
        in terminalObserved = false; in matchingWorker = true; in closedSession = false; in currentRecoveryFence = true;
        in unsafeCancelIsTerminal = true; in unsafeReopenClosed = false;
    }
    verification unsafeClosedResume : CancellationRecovery {
        subject :>> target = fixture;
        in terminalObserved = true; in matchingWorker = true; in closedSession = true; in currentRecoveryFence = true;
        in unsafeCancelIsTerminal = false; in unsafeReopenClosed = true;
    }

    verification qualifiedConsolidation : KnowledgeConsolidation {
        subject :>> target = fixture;
        in lineageAvailable = true; in contraryEvidenceRetained = true;
        in obligationsMet = true; in unsafeSummaryPromotes = false;
    }
    verification missingLineage : KnowledgeConsolidation {
        subject :>> target = fixture;
        in lineageAvailable = false; in contraryEvidenceRetained = true;
        in obligationsMet = true; in unsafeSummaryPromotes = false;
    }
    verification erasedCounterevidence : KnowledgeConsolidation {
        subject :>> target = fixture;
        in lineageAvailable = true; in contraryEvidenceRetained = false;
        in obligationsMet = true; in unsafeSummaryPromotes = false;
    }
    verification unmetConsolidationObligations : KnowledgeConsolidation {
        subject :>> target = fixture;
        in lineageAvailable = true; in contraryEvidenceRetained = true;
        in obligationsMet = false; in unsafeSummaryPromotes = false;
    }
    verification unsafeSummaryPromotion : KnowledgeConsolidation {
        subject :>> target = fixture;
        in lineageAvailable = true; in contraryEvidenceRetained = false;
        in obligationsMet = true; in unsafeSummaryPromotes = true;
    }

    verification freshReviewForB : CrossSessionRecall {
        subject :>> target = fixture;
        in freshTargetReview = true; in currentPermission = true; in sourceChanges = false;
        in policyChanges = false; in unsafeInheritOldAdmission = false;
    }
    verification copiedReviewFromA : CrossSessionRecall {
        subject :>> target = fixture;
        in freshTargetReview = false; in currentPermission = true; in sourceChanges = false;
        in policyChanges = false; in unsafeInheritOldAdmission = false;
    }
    verification deniedPermissionForB : CrossSessionRecall {
        subject :>> target = fixture;
        in freshTargetReview = true; in currentPermission = false; in sourceChanges = false;
        in policyChanges = false; in unsafeInheritOldAdmission = false;
    }
    verification changedSourceOnRecall : CrossSessionRecall {
        subject :>> target = fixture;
        in freshTargetReview = true; in currentPermission = true; in sourceChanges = true;
        in policyChanges = false; in unsafeInheritOldAdmission = false;
    }
    verification changedPolicyOnRecall : CrossSessionRecall {
        subject :>> target = fixture;
        in freshTargetReview = true; in currentPermission = true; in sourceChanges = false;
        in policyChanges = true; in unsafeInheritOldAdmission = false;
    }
    verification unsafeCopiedAdmission : CrossSessionRecall {
        subject :>> target = fixture;
        in freshTargetReview = false; in currentPermission = false; in sourceChanges = false;
        in policyChanges = false; in unsafeInheritOldAdmission = true;
    }
}
