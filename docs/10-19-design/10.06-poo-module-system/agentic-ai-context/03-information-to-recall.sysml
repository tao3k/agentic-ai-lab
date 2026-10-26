// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package AgenticAIContextRoundTrip {
    private import ScalarValues::*;
    private import AgenticAIContextArchitecture::*;
    private import AgenticAIContextLifecycle::*;
    private import SessionBoundaryContracts::*;

    doc /* Org-derived architectural activity/flow model, not executable admission
               algorithms. Leaf outputs stand for owner-produced values; no leaf
               authenticates a source or computes a trusted verdict in this file.
               03-information-to-recall.org maps every stage to its Org source.
               Control paths describe qualified successful observations and named
               refusal branches, not a universal mandatory Agent workflow. */

    item def DemandRef {
        attribute questionIdentity : String;
        attribute scopeDigest : String;
        attribute purpose : String;
        attribute budgetProfile : String;
    }
    item def SourcePacket {
        attribute sourceIdentity : String;
        attribute sourceCut : String;
        attribute elementContractCut : String;
        attribute producerReceiptRef : String;
        doc /* Bounded authenticated source proposal through ORG Element bindings
               or admitted external-artifact refs; observations remain distinct
               from facts/hypotheses/instructions. Not every packet is a Claim. */
    }
    item def InteractionObservation {
        attribute sessionIdentity : String;
        attribute taskRevision : String;
        attribute attemptIdentity : String;
        attribute turnRevision : String;
        attribute exactInputDigest : String;
        attribute providerReceiptRef : String;
        attribute outcomeReceiptRef : String;
        doc /* Session-owned interaction/outcome reference, including failed,
               blocked, cancelled and historical-only results; separate from a
               domain assessment of whether the claimed result is supported. */
    }
    item def ExperienceRef {
        ref inputContext : ContextRevisionRef;
        ref interaction : InteractionObservation;
        attribute experienceRevision : String;
        doc /* Memory-owned retained experience references the original Context
               and canonical Session outcome; capture does not rewrite history. */
    }
    item def RetainedKnowledgeRef {
        ref origin : ExperienceRef;
        ref interpretation : ContextRevisionRef [0..1];
        ref assessment : AssessmentRef;
        attribute retentionReceiptRef : String;
        doc /* May retain an episode without abstraction or reference a new
               admitted long-term interpretation with originating episodes,
               outcomes, alternative explanations and defeat conditions. */
    }

    action def AcquireAndBindInformation {
        in item demand : DemandRef;
        out item packet : SourcePacket;
        doc /* Context chooses the bounded acquisition intent. Host authenticates
               source/read scope and exact bytes; Orgize supplies Element/Contract
               projections. A transcript input is selected from Session's original
               event refs, not an unbounded copy of its message array. */
    }
    action def SelectAndComposeWorkingContext {
        in item demand : DemandRef;
        in item source : SourcePacket;
        in item recalled : ContextRevisionRef [0..1];
        out item working : ContextRevisionRef;
        doc /* Unified Query/GQL selects ORG-bound closure; Context composes native
               POO graph inputs under declared parent/source/Contract cuts, then
               admits the scoped working projection. Preserve hypotheses,
               contradictions, unknown coverage, mandatory inputs and budgets.
               Any unsupported/denied/incomplete required input yields refusal;
               the success path does not fall back to stale admitted content. */
    }
    action def PrepareSessionInput {
        in item demand : DemandRef;
        in item working : ContextRevisionRef;
        out item inputRef : SessionInputRef;
        doc /* Context renders the exact projection and issues producer binding /
               admission references in the independent Session-owned input contract.
               Pure preparation alone permits neither dispatch nor future reuse. */
    }
    action def ClaimSessionAttempt {
        in item inputRef : SessionInputRef;
        out item claimed : InteractionObservation;
        doc /* Session owns task/Attempt/Turn identity and expected-revision claim,
               pending obligations and parent/child lineage. Coordinator validates
               exact producer/input refs. Retry creates a fresh Attempt; it does
               not implicitly allocate another child Session. */
    }
    action def DispatchUnderCurrentFence {
        in item claimed : InteractionObservation;
        out item dispatched : InteractionObservation;
        doc /* Context composes current input/source/policy/Temporal/Authority
               checks; Host uses the qualified outbox/gateway/provider boundary.
               Session records the exact request/disclosure receipt. If dispatch
               admission fails, no new disclosure occurs; keep claim obligations. */
    }
    action def ObserveMatchingCompletion {
        in item dispatched : InteractionObservation;
        out item observed : InteractionObservation;
        doc /* Host supplies actual matching provider observations. Session records
               them against the original Attempt/Turn/input and pending obligations.
               A response is neither an admitted result nor proof of effect cleanup. */
    }
    action def CheckCurrentResult {
        in item observed : InteractionObservation;
        out attribute currentUsePassed : Boolean;
        doc /* Abstract result of qualified current-owner result admission checks,
               not a caller-supplied authorization bit. Include exact producer /
               Attempt/input and current source, evidence, policy and authority.
               The branch below is descriptive; this file computes no such check. */
    }
    action def PublishAcceptedSessionOutcome {
        in item observed : InteractionObservation;
        out item outcome : InteractionObservation;
        doc /* Context owns content/result semantic admission; Session publishes
               one protocol outcome under expected revision with its receipt.
               Data/Host execute conditional publication where configured.
               A competing cancellation cannot silently acquire another outcome. */
    }
    action def PreserveHistoricalOutcome {
        in item observed : InteractionObservation;
        out item outcome : InteractionObservation;
        doc /* Preserve failed/stale/uncertain response without current-result use.
               Context invalidates affected projections; Session retains exact
               cancellation/recovery obligations. Host must provide real terminal /
               isolation and resource evidence; timeout is not reconciliation.
               Any later retry reenters with fresh inputs and a new Attempt. */
    }
    action def SessionBoundUse {
        in item inputRef : SessionInputRef;
        out item outcome : InteractionObservation;
        action claim : ClaimSessionAttempt;
        action dispatch : DispatchUnderCurrentFence;
        action receive : ObserveMatchingCompletion;
        action check : CheckCurrentResult;
        decide resultDisposition;
        action acceptResult : PublishAcceptedSessionOutcome;
        action preserveHistory : PreserveHistoricalOutcome;
        merge outcomeMerge;
        action selectOutcome {
            in item accepted : InteractionObservation [0..1];
            in item historical : InteractionObservation [0..1];
            out item selected : InteractionObservation;
            doc /* Preserve the single branch-selected protocol reference and its
                   disposition, without treating a historical result as accepted.
                   Abstract selection contract; not a second outcome publisher. */
        }
        first start then claim;
        first claim then dispatch;
        first dispatch then receive;
        first receive then check;
        first check then resultDisposition;
        first resultDisposition if check.currentUsePassed then acceptResult;
        first resultDisposition if not check.currentUsePassed then preserveHistory;
        first acceptResult then outcomeMerge;
        first preserveHistory then outcomeMerge;
        first outcomeMerge then selectOutcome;
        first selectOutcome then done;
        bind inputRef = claim.inputRef;
        flow from claim.claimed to dispatch.claimed;
        flow from dispatch.dispatched to receive.dispatched;
        flow from receive.observed to check.observed;
        flow from receive.observed to acceptResult.observed;
        flow from receive.observed to preserveHistory.observed;
        flow from acceptResult.outcome to selectOutcome.accepted;
        flow from preserveHistory.outcome to selectOutcome.historical;
        bind outcome = selectOutcome.selected;
        doc /* Cancellation/absence of response uses 02 Attempt recovery, not the
               receive-success sequence. Failed dispatch stops before receive. */
    }
    action def CaptureExperience {
        in item working : ContextRevisionRef;
        in item outcome : InteractionObservation;
        out item experience : ExperienceRef;
        doc /* Context's Memory Feature captures under explicit retention intent,
               current visibility and policy. Include exact Session/turn receipt,
               failures and uncertainty. Session need not remain open after capture.
               Declining retention does not erase original Session history. */
    }
    action def ReassessExperience {
        in item experience : ExperienceRef;
        out item assessment : AssessmentRef;
        out attribute consolidationAdmitted : Boolean;
        doc /* Context owns relevance/applicability and domain interpretation;
               Memory owns retention/revisit policy; Evidence/Temporal/MRR supply
               their original admissions/applicability. Bind current environment,
               source cut, actual outcomes, alternatives and review obligations.
               consolidationAdmitted abbreviates qualified domain acceptance, not
               age, read count, one confidence score or permission to write Org. */
    }
    action def ConsolidateKnowledge {
        in item experience : ExperienceRef;
        in item assessment : AssessmentRef;
        out item retained : RetainedKnowledgeRef;
        doc /* Memory creates a new versioned reusable mechanism/constraint/
               procedure/decision with origins, contrary evidence, scope and
               defeat conditions. Host/Data conditionally publish if durable.
               No source mutation or broader grant is implied. */
    }
    action def RetainEpisodeWithoutGeneralization {
        in item experience : ExperienceRef;
        in item assessment : AssessmentRef;
        out item retained : RetainedKnowledgeRef;
        doc /* Retention can preserve an episode or disputed hypothesis without
               admitting a reusable abstraction. Uncertain/failed uses remain
               visible. Original evidence and Session protocol outcomes are intact. */
    }
    action def RecallUnderNewDemand {
        in item newDemand : DemandRef;
        in item retained : RetainedKnowledgeRef;
        out item candidate : ContextRevisionRef;
        doc /* Explicit new question/change/review intent triggers recall; no
               automatic scheduler follows from retention. Context/Memory query
               permitted retained information through the canonical source route,
               recheck provenance, relevance/applicability and restrictions, and
               return candidates. Unsupported/withdrawn interpretation is refused
               or historical-only according to demand; never silently trusted. */
    }
    action def KnowledgeReentry {
        in item experience : ExperienceRef;
        in item newDemand : DemandRef;
        out item candidate : ContextRevisionRef;
        action reassess : ReassessExperience;
        decide consolidationDisposition;
        action consolidate : ConsolidateKnowledge;
        action retainEpisode : RetainEpisodeWithoutGeneralization;
        action recallInterpretation : RecallUnderNewDemand;
        action recallEpisode : RecallUnderNewDemand;
        merge recallMerge;
        action selectCandidate {
            in item fromInterpretation : ContextRevisionRef [0..1];
            in item fromEpisode : ContextRevisionRef [0..1];
            out item selected : ContextRevisionRef;
            doc /* Select the actually taken recall branch's candidate, preserving
                   origin and assessment; no current-use grant is produced. */
        }
        first start then reassess;
        first reassess then consolidationDisposition;
        first consolidationDisposition if reassess.consolidationAdmitted then consolidate;
        first consolidationDisposition if not reassess.consolidationAdmitted then retainEpisode;
        first consolidate then recallInterpretation;
        first retainEpisode then recallEpisode;
        first recallInterpretation then recallMerge;
        first recallEpisode then recallMerge;
        first recallMerge then selectCandidate;
        first selectCandidate then done;
        bind experience = reassess.experience;
        bind experience = consolidate.experience;
        bind experience = retainEpisode.experience;
        flow from reassess.assessment to consolidate.assessment;
        flow from reassess.assessment to retainEpisode.assessment;
        flow from consolidate.retained to recallInterpretation.retained;
        flow from retainEpisode.retained to recallEpisode.retained;
        bind newDemand = recallInterpretation.newDemand;
        bind newDemand = recallEpisode.newDemand;
        flow from recallInterpretation.candidate to selectCandidate.fromInterpretation;
        flow from recallEpisode.candidate to selectCandidate.fromEpisode;
        bind candidate = selectCandidate.selected;
        doc /* A new question is independently supplied and may occur much later.
               Existing long-term knowledge can enter directly at recall without
               repeating capture/consolidation. Revision/withdrawal and optional
               revisit are the independent activities/axes defined in 02. */
    }
    action def InformationToRecall {
        in item initialDemand : DemandRef;
        in item nextDemand : DemandRef;
        out item nextWorkingContext : ContextRevisionRef;
        action acquire : AcquireAndBindInformation;
        action formWorking : SelectAndComposeWorkingContext;
        action prepare : PrepareSessionInput;
        action useInSession : SessionBoundUse;
        action capture : CaptureExperience;
        action knowledge : KnowledgeReentry;
        action refreshSources : AcquireAndBindInformation;
        action formNextWorking : SelectAndComposeWorkingContext;
        first start then acquire;
        first acquire then formWorking;
        first formWorking then prepare;
        first prepare then useInSession;
        first useInSession then capture;
        first capture then knowledge;
        first knowledge then refreshSources;
        first refreshSources then formNextWorking;
        first formNextWorking then done;
        bind initialDemand = acquire.demand;
        bind initialDemand = formWorking.demand;
        bind initialDemand = prepare.demand;
        flow from acquire.packet to formWorking.source;
        flow from formWorking.working to prepare.working;
        flow from prepare.inputRef to useInSession.inputRef;
        flow from formWorking.working to capture.working;
        flow from useInSession.outcome to capture.outcome;
        flow from capture.experience to knowledge.experience;
        bind nextDemand = knowledge.newDemand;
        bind nextDemand = refreshSources.demand;
        bind nextDemand = formNextWorking.demand;
        flow from knowledge.candidate to formNextWorking.recalled;
        flow from refreshSources.packet to formNextWorking.source;
        bind formNextWorking.working = nextWorkingContext;
        doc /* Illustrative Session-use + opted-in Memory round trip. Leaf success
               presupposes required owner admission. End is a newly formed working
               Context, not an automatic dispatch or continuation of an old Session.
               For another provider use, prepare again and bind an explicitly
               enrolled Session/Task/Attempt/Turn under current checks.
               Standalone formation can stop after formWorking without an active
               Session. Memory capture/consolidation is optional; formation and
               current-use checks remain available without retained Memory.
               Work may form many Contexts and recall many sources; this one-item
               architectural route does not constrain production cardinalities. */
    }

    dependency acquisitionCoordinator from AcquireAndBindInformation to ContextModule;
    dependency sourceExecution from AcquireAndBindInformation to Host;
    dependency formationOwner from SelectAndComposeWorkingContext to ContextModule;
    dependency inputProducer from PrepareSessionInput to ContextModule;
    dependency interactionOwner from ClaimSessionAttempt to SessionModule;
    dependency dispatchExecution from DispatchUnderCurrentFence to Host;
    dependency responseRecording from ObserveMatchingCompletion to SessionModule;
    dependency resultSemantics from CheckCurrentResult to ContextModule;
    dependency terminalOutcome from PublishAcceptedSessionOutcome to SessionModule;
    dependency historicalOutcome from PreserveHistoricalOutcome to SessionModule;
    dependency experienceOwner from CaptureExperience to Memory;
    dependency reassessmentCoordinator from ReassessExperience to ContextModule;
    dependency longTermKnowledge from ConsolidateKnowledge to Memory;
    dependency episodeRetention from RetainEpisodeWithoutGeneralization to Memory;
    dependency recallCoordinator from RecallUnderNewDemand to ContextModule;
}
