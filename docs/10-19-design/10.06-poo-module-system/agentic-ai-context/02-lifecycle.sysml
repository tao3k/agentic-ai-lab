// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package AgenticAIContextLifecycle {
    private import ScalarValues::*;
    private import AgenticAIContextArchitecture::*;

    doc /* Allocation of existing Org lifecycle contracts; see 00-design-map.org.
           These are orthogonal state axes, not one required Agent route.
           Accepted event types abbreviate qualified owner observations/receipts;
           an arbitrary sender cannot establish their preconditions. This model
           does not implement receipt authentication, CAS or distributed fences. */

    attribute def AdmissionPassed;
    attribute def PreparationPassed;
    attribute def InputInvalidated;
    attribute def SuccessorSelected;
    attribute def RetirementPublished;
    state def ProjectionLifecycle {
        doc /* Context-owned selection/applicability of an immutable revision.
               Admission is source/Query/evidence qualification; preparation binds
               the joint envelope. Neither grants future disclosure permission.
               Source/Contract/policy/grant changes or lease expiry invalidate use.
               Refresh creates a successor revision, not a rewrite of old content. */
        first start then proposed;
        state proposed;
        state admitted;
        state prepared;
        state invalidated;
        state superseded;
        state retired;
        transition admit first proposed accept AdmissionPassed then admitted;
        transition prepare first admitted accept PreparationPassed then prepared;
        transition invalidateAdmission first admitted accept InputInvalidated then invalidated;
        transition invalidatePreparation first prepared accept InputInvalidated then invalidated;
        transition replaceAdmission first admitted accept SuccessorSelected then superseded;
        transition replacePreparation first prepared accept SuccessorSelected then superseded;
        transition replaceInvalidated first invalidated accept SuccessorSelected then superseded;
        transition retireProposal first proposed accept RetirementPublished then retired;
        transition retireAdmission first admitted accept RetirementPublished then retired;
        transition retirePreparation first prepared accept RetirementPublished then retired;
        transition retireInvalidated first invalidated accept RetirementPublished then retired;
        transition retireSuperseded first superseded accept RetirementPublished then retired;
    }

    attribute def CloseRequested;
    attribute def ClosureQualified;
    state def SessionLifecycle {
        doc /* Session-owned open/closing/closed axis from the joint lifecycle
               contract. This abstracts the finer created/preparing/active/
               suspended states in Session's protocol; it does not replace them.
               ClosureQualified requires terminal/isolation and resource evidence
               for pending obligations, not merely a cancellation request.
               Closed cannot reopen. Continuation uses explicit new lineage. */
        first start then open;
        state open;
        state closing;
        state closed;
        transition requestClose first open accept CloseRequested then closing;
        transition close first closing accept ClosureQualified then closed;
    }

    attribute def DispatchAdmitted;
    attribute def MatchingResponseObserved;
    attribute def ResultAdmissionPassed;
    attribute def RecoveryRequired;
    attribute def MatchingTerminalOrIsolationObserved;
    state def AttemptLifecycle {
        doc /* Session owns Attempt identity/revisions; Context gates exact input
               disclosure and result use; Host executes and supplies observations.
               Start abstracts an already accepted owner-CAS claim.
               DispatchAdmitted includes a current exact-envelope fence and the
               qualified outbox/gateway boundary. A response is not acceptance.
               Invalidation preserves worker/effect obligations. Reconciliation
               requires matching real evidence; retry uses a fresh Attempt.
               An admitted result can later lose applicability while its immutable
               receipt remains historical. No transition here erases that receipt. */
        first start then claimed;
        state claimed;
        state disclosed;
        state resultReceived;
        state admitted;
        state invalidated;
        state recoveryPending;
        state reconciled;
        transition disclose first claimed accept DispatchAdmitted then disclosed;
        transition receive first disclosed accept MatchingResponseObserved then resultReceived;
        transition acceptResult first resultReceived accept ResultAdmissionPassed then admitted;
        transition invalidateClaim first claimed accept InputInvalidated then invalidated;
        transition invalidateDisclosed first disclosed accept InputInvalidated then invalidated;
        transition invalidateResult first resultReceived accept InputInvalidated then invalidated;
        transition invalidateAccepted first admitted accept InputInvalidated then invalidated;
        transition recoverClaim first claimed accept RecoveryRequired then recoveryPending;
        transition recoverDisclosed first disclosed accept RecoveryRequired then recoveryPending;
        transition recoverResult first resultReceived accept RecoveryRequired then recoveryPending;
        transition recoverInvalidated first invalidated accept RecoveryRequired then recoveryPending;
        transition reconcile first recoveryPending accept MatchingTerminalOrIsolationObserved then reconciled;
        doc /* Late responses in invalidated/recoveryPending/reconciled remain
               historical observations. They cannot trigger acceptResult.
               Evidence that nothing was dispatched may discharge an undispatched
               claim; an unreachable worker is not terminal evidence. */
    }

    enum def EvidenceVerdict {
        supported; refuted; uncertain; notAssessed;
    }
    enum def RetentionAssessment {
        untested; unstable; improving; stableUnderPolicy;
    }
    enum def RetentionHorizon {
        shortTerm; longTerm;
    }
    attribute def ReviewBecameDue;
    attribute def ReviewClaimed;
    attribute def AssessmentPublished;
    attribute def ReviewDeferred;
    attribute def NextReviewScheduled;
    state def RevisitLifecycle {
        doc /* Memory owns intent/assessment; Temporal owns due/lease coordinates;
               Session owns execution Attempt; Data/Host publish conditionally.
               Claimed completion requires exact current claim generation/source/
               policy and fresh assessment. This does not change evidence verdict
               or retention assessment automatically. Fresh reviews use new Attempts. */
        first start then scheduled;
        state scheduled;
        state due;
        state claimed;
        state completed;
        state deferred;
        transition dueNow first scheduled accept ReviewBecameDue then due;
        transition claim first due accept ReviewClaimed then claimed;
        transition complete first claimed accept AssessmentPublished then completed;
        transition deferDue first due accept ReviewDeferred then deferred;
        transition deferClaim first claimed accept ReviewDeferred then deferred;
        transition rescheduleCompletion first completed accept NextReviewScheduled then scheduled;
        transition rescheduleDeferral first deferred accept NextReviewScheduled then scheduled;
        doc /* Expiry/reclaim of a review claim requires a new generation before
               publication. A deferred worker may still have an Attempt obligation;
               revisit deferral never asserts worker termination. */
    }

    item def ContextRevisionRef {
        attribute identity : String;
        attribute sourceCut : String;
        attribute contractCut : String;
        attribute compositionRevision : String;
        doc /* Abstract architectural binding, not a replacement wire schema. */
    }
    item def AssessmentRef {
        attribute evidence : EvidenceVerdict;
        attribute retention : RetentionAssessment;
        attribute horizon : RetentionHorizon;
        doc /* Orthogonal observations under an explicit policy and cut.
               Long-term horizon alone cannot establish stable recall or truth.
               Full assessments also separate relevance, credibility, current
               applicability, retention value, uncertainty and current authority. */
    }
    action def Form {
        in item selectedSources : ContextRevisionRef;
        out item situatedContext : ContextRevisionRef;
        doc /* Demand-led Query and pure POO graph composition. Captured is not
               accepted; no whole-repository ingestion or mandatory next action. */
    }
    action def Use {
        in item exactContext : ContextRevisionRef;
        out item actualOutcome : AssessmentRef;
        doc /* Context coordinates current gates and Session/Host handoff.
               Record attempted action/environment/outcome, failures and budget
               exhaustion. Retrieved, displayed, applied and successful differ.
               This action allocates behavior; it executes no external tool. */
    }
    action def Reassess {
        in item priorContext : ContextRevisionRef;
        out item currentAssessment : AssessmentRef;
        doc /* Changed source/Contract/environment, counterevidence or review
               intent reopens affected obligations. No universal time-decay law.
               Unknown dependency coverage dirties the whole affected scope. */
    }
    action def Consolidate {
        in item originatingContext : ContextRevisionRef;
        in item useAssessment : AssessmentRef;
        out item reusableInterpretation : ContextRevisionRef;
        doc /* New scoped abstraction under declared domain obligations: original
               episodes/outcomes, contrary evidence, alternatives, assumptions,
               applicability and defeat/review conditions remain attributable.
               Failed consolidation retains short-term/history inputs. This is
               not an irreversible short-to-long enum update or automatic Org edit. */
    }
    action def Retrieve {
        in item retainedInterpretation : ContextRevisionRef;
        out item newCandidate : ContextRevisionRef;
        doc /* New question, scope and demand require relevance/applicability and
               current-use admission; historical permission is not inherited. */
    }
    action def ReviseOrWithdraw {
        in item previousInterpretation : ContextRevisionRef;
        in item changedAssessment : AssessmentRef;
        out item successorInterpretation : ContextRevisionRef;
        doc /* Record correction/withdrawal lineage and preserve historical
               observations. Retirement differs from authorized deletion.
               Org mutation requires expected-revision authorization and reparse. */
    }

    dependency formationOwner from Form to ContextModule;
    dependency useCoordinator from Use to ContextCoordination;
    dependency projectionOwner from ProjectionLifecycle to ContextProjection;
    dependency sessionOwner from SessionLifecycle to SessionModule;
    dependency attemptOwner from AttemptLifecycle to SessionModule;
    dependency reassessmentOwner from Reassess to ContextModule;
    dependency consolidationOwner from Consolidate to Memory;
    dependency recallOwner from Retrieve to ContextModule;
    dependency revisionOwner from ReviseOrWithdraw to ContextModule;
    dependency revisitOwner from RevisitLifecycle to Memory;

    doc /* Source lineage, Evidence applicability, Strategy, Effect ambiguity and
               Durable-head publication remain separate owner axes. This file
               expands selected axes only; it does not replace the joint envelope,
               support/retraction, physical-resource or transaction protocols. */
}
