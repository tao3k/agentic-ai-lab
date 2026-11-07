// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextConcurrentEvidence {
    private import ScalarValues::*;
    private import VerificationCases::*;
    part def RegisteredEvidenceFixture;
    part fixture : RegisteredEvidenceFixture;

    verification def Interleaving {
        subject target : RegisteredEvidenceFixture default = fixture;
        in e0 : Integer; in e1 : Integer; in e2 : Integer; in e3 : Integer;
        in e4 : Integer; in e5 : Integer; in e6 : Integer; in e7 : Integer;
        in bugMode : Integer;
        doc /* R=1 receive; Q=2 qualify result; P=3 publish result;
               S=4 withdraw source/premise; G=5 revoke grant;
               C=6 prepare cancellation; T=7 matching worker terminal observation
               and cancellation publication; H=8 crash/checkpoint recovery.
               Partial orders: R<Q<P, C<T, C<H. One of each event, one Attempt.
               Reducer event is an atomic linearization point; Q and P are separate.
               Modes 1/2/3/4 remove owner CAS/evidence fence/recovery fencing/
               pending-obligation preservation respectively. 0 is the safe reducer.
               Python enumerates all linear extensions; SysML executes all gates. */
        attribute sourceGeneration : Integer := 1;
        attribute grantGeneration : Integer := 1;
        attribute journalRevision : Integer := 1;
        attribute ruleProgramRevision : Integer := 3;
        attribute registeredProofRoot : Integer := 1;
        attribute selectedDerivation : Integer := 1;
        attribute premiseOneActive : Boolean := true;
        attribute premiseTwoActive : Boolean := true;
        attribute alternateRootAvailable : Boolean := true;
        attribute originalProofRetained : Boolean := true;
        attribute immutableInputSource : Integer := 1;
        attribute immutableInputJournal : Integer := 1;
        attribute immutableInputGrant : Integer := 1;
        attribute immutableInputRoot : Integer := 1;
        attribute ownerRevision : Integer := 7;
        attribute resultExpectedOwner : Integer := 0;
        attribute cancelExpectedOwner : Integer := 0;
        attribute resultObserved : Boolean := false;
        attribute cachedEligibility : Boolean := false;
        attribute cancelRequested : Boolean := false;
        attribute workerPending : Boolean := true;
        attribute terminalReceiptObserved : Boolean := false;
        attribute terminalCount : Integer := 0;
        attribute terminalKind : Integer := 0;
        attribute firstTerminalKind : Integer := 0;
        attribute historicalAccepted : Boolean := false;
        attribute currentUse : Boolean := false;
        attribute everInvalidated : Boolean := false;
        attribute evidenceCurrent : Boolean := true;
        attribute publishResultNow : Boolean := false;
        attribute publishCancelNow : Boolean := false;
        attribute badTerminal : Boolean := false;
        attribute badReactivation : Boolean := false;
        attribute badObligation : Boolean := false;
        attribute pathCode : Integer := 0;
        attribute steps : Integer := 0;
        attribute firstBadPrefix : Integer := 0;
        first start then reduceTrace;
        action reduceTrace {
            for move in (e0,e1,e2,e3,e4,e5,e6,e7) {
                assign pathCode := pathCode * 10 + move;
                assign steps := steps + 1;
                // Original positive proof DAG requires both original premises.
                // Another hypothesis/root being possible cannot repair this root.
                assign resultObserved := resultObserved or move == 1;
                assign sourceGeneration := if move == 4 ? 2 else sourceGeneration;
                assign journalRevision := if move == 4 ? 2 else journalRevision;
                assign premiseOneActive := premiseOneActive and move != 4;
                assign grantGeneration := if move == 5 ? 2 else grantGeneration;
                assign everInvalidated := everInvalidated or move == 4 or move == 5;
                assign evidenceCurrent := immutableInputSource == sourceGeneration
                    and immutableInputJournal == journalRevision
                    and immutableInputRoot == registeredProofRoot
                    and selectedDerivation == 1 and ruleProgramRevision == 3
                    and premiseOneActive and premiseTwoActive;
                assign currentUse := if move == 4 or move == 5 ? false else currentUse;
                // Qualification is a snapshot; it does not authorize later publication.
                assign cachedEligibility := if move == 2 ? resultObserved and evidenceCurrent
                    and immutableInputGrant == grantGeneration else cachedEligibility;
                assign resultExpectedOwner := if move == 2 ? ownerRevision else resultExpectedOwner;
                assign cancelRequested := cancelRequested or move == 6;
                assign cancelExpectedOwner := if move == 6 ? ownerRevision else cancelExpectedOwner;
                // Reconcile exactly this worker. Recovery cannot invent this evidence.
                assign terminalReceiptObserved := terminalReceiptObserved or move == 7;
                assign workerPending := if move == 7 ? false else workerPending;
                assign publishResultNow := move == 3 and cachedEligibility and resultObserved
                    and (bugMode == 1 or (terminalCount == 0 and ownerRevision == resultExpectedOwner))
                    and (if bugMode == 2 ? alternateRootAvailable else
                        evidenceCurrent and immutableInputGrant == grantGeneration);
                assign publishCancelNow := move == 7 and cancelRequested and terminalReceiptObserved
                    and (bugMode == 1 or (terminalCount == 0 and ownerRevision == cancelExpectedOwner));
                assign terminalCount := if publishResultNow or publishCancelNow ? terminalCount + 1 else terminalCount;
                assign terminalKind := if publishResultNow ? 1 else if publishCancelNow ? 2 else terminalKind;
                assign firstTerminalKind := if firstTerminalKind == 0 and terminalCount > 0 ? terminalKind else firstTerminalKind;
                assign historicalAccepted := historicalAccepted or publishResultNow;
                assign currentUse := if publishResultNow ? true else if publishCancelNow ? false else currentUse;
                assign ownerRevision := if publishResultNow or publishCancelNow or move == 8 ? ownerRevision + 1 else ownerRevision;
                // H restores obligations and historical references, not old permission.
                assign currentUse := if move == 8 ?
                    (if bugMode == 3 ? historicalAccepted else currentUse and evidenceCurrent
                        and immutableInputGrant == grantGeneration and terminalKind == 1)
                    else currentUse;
                assign workerPending := if move == 8 and bugMode == 4 ? false else workerPending;
                // Sticky per-prefix violations cannot be hidden by a later correction.
                assign badTerminal := badTerminal or terminalCount > 1
                    or (firstTerminalKind != 0 and terminalKind != firstTerminalKind);
                assign badReactivation := badReactivation or (currentUse and
                    (everInvalidated or not evidenceCurrent or immutableInputGrant != grantGeneration
                        or terminalCount != 1 or terminalKind != 1));
                assign badObligation := badObligation or (not workerPending and not terminalReceiptObserved);
                assign firstBadPrefix := if firstBadPrefix == 0 and
                    (badTerminal or badReactivation or badObligation) ? steps else firstBadPrefix;
            }
        }
        then done;
        out traceCode : Integer = pathCode;
        out processed : Integer = steps;
        out terminals : Integer = terminalCount;
        out outcome : Integer = terminalKind;
        out acceptedHistorically : Boolean = historicalAccepted;
        out currentAllowed : Boolean = currentUse;
        out retainedProof : Boolean = originalProofRetained;
        out originalRoot : Integer = registeredProofRoot;
        out currentJournal : Integer = journalRevision;
        out pending : Boolean = workerPending;
        out terminalViolation : Boolean = badTerminal;
        out staleViolation : Boolean = badReactivation;
        out obligationViolation : Boolean = badObligation;
        out violatingPrefix : Integer = firstBadPrefix;
        return verdict : VerdictKind = PassIf(steps == 8 and originalProofRetained
            and not badTerminal and not badReactivation and not badObligation);
    }
}
