// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package ContextRepeatedRecovery {
    private import ScalarValues::*;
    private import VerificationCases::*;
    // Current conceptual design. Connections express dependencies, not steps.
    // Temporal references below are views of existing contracts, not a second
    // Evidence model or a claim that an executable integration exists.
    part def TemporalEvidenceLineageView {
        attribute contractOwner : String = "Temporal Causality";
        attribute admissionCut : String;
        attribute validTimeProjection : String;
        attribute retrievalIdentities : String;
        attribute evidenceUseIdentities : String;
        attribute assessmentIdentities : String;
        attribute revisionAndDependencyIdentities : String;
        doc /* See modules/temporal-causality/evidence/model.org and framework.org.
               Uses bind exact source and claim digests. Assessments bind exact
               uses, assessor, method, verdict and basis. Supplied assessments
               are not admitted claims. Revisions preserve previous evidence.
               Admission time and valid time answer different questions. */
    }
    part def RetainedRecoveryAttempt {
        attribute taskIdentity : String;
        attribute attemptIdentity : String;
        attribute effectIdentity : String;
        attribute intendedChange : String = "Append the intended text to the scoped workspace file";
        attribute retainedResponsibility : String = "Original effect outcome unresolved";
    }
    part def RecoveryClaimView {
        attribute question : String;
        attribute conclusion : String;
        attribute unresolvedReasons : String;
        attribute temporalUseAndAssessmentReferences : String;
        attribute admissionCut : String;
        attribute policyRevision : String;
        attribute predecessorJudgmentIdentity : String;
        doc /* Conclusions are scoped and versioned. Missing evidence is not a
               negative outcome. Correction marks dependents for reevaluation,
               not automatically false. Previous conclusions remain history. */
    }
    part def RecoveryHypothesisView {
        attribute temporalHypothesisReferences : String;
        attribute candidateExplanations : String = "Original Attempt wrote; another writer produced matching bytes; partial completion";
        attribute familySemantics : String = "Open and potentially overlapping";
        attribute unresolvedQuestion : String = "Which admitted evidence ties the change to the original effect?";
        doc /* These are candidates. Temporal order and matching bytes do not
               establish causation. Model confidence cannot admit a claim. */
    }
    part def ReconciliationResponsibility {
        attribute identityBasis : String = "Original Attempt, question and scope";
        attribute question : String;
        attribute responsibleRole : String;
        attribute derivationPremises : String;
        attribute derivationRuleIdentity : String;
        attribute disposition : String default = "Open; may be assigned, blocked, resolved or reopened";
        attribute dischargeBasis : String = "Admitted evidence answering this exact question";
        doc /* Repeated recovery retains the same question and adds reasons.
               A completed exploration task does not discharge its parent.
               Unassigned responsibility stays visible and grants no access. */
    }
    part def AscentRecoveryRelationView {
        attribute inputScope : String = "Finite Context snapshot bound to the Temporal cut";
        attribute derivedRelations : String = "Needs attribution; needs source coverage; affected judgment; responsible role";
        attribute justification : String = "Rule identity and exact premise identities";
        attribute exchangeBoundary : String = "Cut-bound candidate exchange remains a design requirement";
        doc /* Derive responsibilities from explicit unresolved assessments.
               Open-world absence cannot prove non-execution. Derivations are
               candidates for admission, not receipt authentication or grants.
               No fixed next action or required exploration sequence. */
    }
    part def ModelRecoveryExploration {
        attribute addressedQuestion : String;
        attribute proposedObservation : String;
        attribute expectedHypothesisDistinctions : String;
        attribute requiredAuthorityAndCost : String;
        attribute openFrontier : String;
        doc /* The model may branch, inspect independent sources concurrently,
               change a hypothesis, wait or report a blocked frontier. Actual
               findings return to Temporal lineage. A proposal is not evidence.
               Budget exhaustion never establishes an outcome. */
    }
    part def RecoveryCutReading {
        attribute cut : String;
        attribute evidenceBasis : String;
        attribute contextOutcome : String;
        attribute outcomeDuty : String;
        attribute suggestedInquiry : String;
        attribute retainedHistory : String;
    }
    part def InterruptedWriteEvidenceComparison {
        doc /* Three admission cuts for the same Attempt and effect.
               The file observation persists. R1 was the sole qualifying
               success support. The source owner's admitted correction R2
               attributes R1 to another Attempt. Inquiry entries are examples. */
        part initial : RecoveryCutReading {
            :>> cut = "A";
            :>> evidenceBasis = "Matching file bytes; no admitted result for this Attempt";
            :>> contextOutcome = "Unknown";
            :>> outcomeDuty = "Open: Task owner must reconcile the original effect";
            :>> suggestedInquiry = "Locate a receipt source or examine another writer";
            :>> retainedHistory = "First file observation and original Attempt";
        }
        part admitted : RecoveryCutReading {
            :>> cut = "B";
            :>> evidenceBasis = "R1 admitted for the original effect";
            :>> contextOutcome = "Succeeded at B";
            :>> outcomeDuty = "Resolved at B for the same outcome question";
            :>> suggestedInquiry = "Optionally inspect claims that use the result";
            :>> retainedHistory = "Cut A remains queryable";
        }
        part corrected : RecoveryCutReading {
            :>> cut = "C";
            :>> evidenceBasis = "R2 attributes R1 to another Attempt; no independent valid support";
            :>> contextOutcome = "Unknown at C";
            :>> outcomeDuty = "Reopened: same Attempt, question and scope";
            :>> suggestedInquiry = "Compare Attempt identities or seek an independent effect record";
            :>> retainedHistory = "Cut B success and R1 remain historical alongside R2";
        }
    }
    part def CorrectionSupportReading {
        attribute admittedUsesBefore : String;
        attribute withdrawnUses : String;
        attribute survivingUses : String;
        attribute contextOutcome : String;
        attribute originalOutcomeDuty : String;
        attribute affectedUseReview : String;
        attribute suggestedInquiry : String;
    }
    part def InterruptedWriteCorrectionComparison {
        doc /* Both alternatives apply admitted correction R2 to the same
               R1 attribution. The derived copy depends on R1. W1 independently
               establishes the exact effect. Neither alternative has an
               unresolved competing admission. Keep the prior success at B. */
        part copiedOnly : CorrectionSupportReading {
            :>> admittedUsesBefore = "R1 and R1-copy";
            :>> withdrawnUses = "R1 and R1-copy";
            :>> survivingUses = "None";
            :>> contextOutcome = "Unknown at C";
            :>> originalOutcomeDuty = "Reopen the same Attempt outcome question";
            :>> affectedUseReview = "Review claims that cited withdrawn uses";
            :>> suggestedInquiry = "Compare Attempt identities or seek an independent effect record";
        }
        part independentSurvives : CorrectionSupportReading {
            :>> admittedUsesBefore = "R1, R1-copy and W1";
            :>> withdrawnUses = "R1 and R1-copy";
            :>> survivingUses = "W1 for the same Attempt and effect";
            :>> contextOutcome = "Succeeded at C on W1";
            :>> originalOutcomeDuty = "Keep the outcome question resolved";
            :>> affectedUseReview = "Review claims that cited withdrawn uses";
            :>> suggestedInquiry = "Check affected citations against the surviving support";
        }
    }
    part def CorrectionLineageNode {
        attribute lineageKey : String;
    }
    part def InterruptedWriteIndirectAttribution {
        part r1Attribution : CorrectionLineageNode { :>> lineageKey = "R1-attribution"; }
        part receiptUse : CorrectionLineageNode { :>> lineageKey = "R1"; }
        part receiptCopyUse : CorrectionLineageNode { :>> lineageKey = "R1-copy"; }
        part attemptCrosswalk : CorrectionLineageNode { :>> lineageKey = "attempt-crosswalk"; }
        part w1Attribution : CorrectionLineageNode { :>> lineageKey = "W1-attribution"; }
        part w1RawRecord : CorrectionLineageNode { :>> lineageKey = "W1-record"; }
        part w1Use : CorrectionLineageNode { :>> lineageKey = "W1"; }
        part outcomeAtB : CorrectionLineageNode { :>> lineageKey = "outcome-B"; }
        part summaryAtB : CorrectionLineageNode { :>> lineageKey = "summary-B"; }
        connection receiptPremise connect r1Attribution to receiptUse;
        connection copiedReceipt connect receiptUse to receiptCopyUse;
        connection crosswalkPremise connect r1Attribution to attemptCrosswalk;
        connection bindingPremise connect attemptCrosswalk to w1Attribution;
        connection effectBinding connect w1Attribution to w1Use;
        connection rawObservation connect w1RawRecord to w1Use;
        connection originalSupport connect receiptUse to outcomeAtB;
        connection copiedSupport connect receiptCopyUse to outcomeAtB;
        connection alternateSupport connect w1Use to outcomeAtB;
        connection downstreamConclusion connect outcomeAtB to summaryAtB;
        part currentOutcome : RecoveryClaimView {
            :>> conclusion = "Unknown at C after the admitted correction to R1 attribution";
            :>> predecessorJudgmentIdentity = "outcome-B";
            :>> unresolvedReasons = "Neither prior use establishes the original effect at C";
        }
        part outcomeDuty : ReconciliationResponsibility {
            :>> question = "Reconcile the original effect outcome";
            :>> disposition = "Reopened for the same Attempt and question";
            :>> responsibleRole = "Original Task owner";
        }
        part bindingDuty : ReconciliationResponsibility {
            :>> question = "Can W1 be bound to the original Attempt and effect?";
            :>> derivationPremises = "R2 targets R1-attribution; the crosswalk and W1 binding depend on it";
            :>> responsibleRole = "W1 evidence custodian or scoped investigator";
        }
        part inquiry : ModelRecoveryExploration {
            :>> proposedObservation = "Inspect crosswalk provenance, validate a direct binding, or find independent write evidence";
        }
        connection reassessesPriorJudgment connect outcomeAtB to currentOutcome;
        connection reopensOriginalQuestion connect currentOutcome to outcomeDuty;
        connection bindingNeedsReview connect w1Attribution to bindingDuty;
        connection exposesOutcomeQuestion connect outcomeDuty to inquiry;
        connection exposesBindingQuestion connect bindingDuty to inquiry;
        doc /* Arrows express dependency and obligation scope. R2 targets the
               versioned R1 attribution premise. The original W1 record and
               B judgments remain available as history. At C the affected
               judgments are outcome-B and summary-B. R1-copy is reached in
               the graph even when it was not an active use in the case. */
    }
    part def DirectBindingAdmissionReading {
        part candidate : CorrectionLineageNode { :>> lineageKey = "D1"; }
        part originalIntent : CorrectionLineageNode { :>> lineageKey = "original-attempt/append-effect"; }
        part retainedRecord : CorrectionLineageNode { :>> lineageKey = "W1-record-digest"; }
        part previousUse : CorrectionLineageNode { :>> lineageKey = "W1-v1"; }
        part replacementUse : CorrectionLineageNode { :>> lineageKey = "W1-v2"; }
        part priorCut : RecoveryClaimView {
            :>> conclusion = "Unknown at C; W1-v1 cannot support the original effect";
        }
        part verifiedAdmission : RecoveryClaimView {
            :>> question = "Does D1 justify use of the retained W1 record for the original effect?";
            :>> conclusion = "Admit exact Attempt, effect, write and record only on a current qualified assessment";
            :>> unresolvedReasons = "Check issuer scope, complete lineage without R1 and committed effect";
        }
        part currentOutcome : RecoveryClaimView {
            :>> conclusion = "Succeeded at D on W1-v2 if the result is uncontested";
            :>> predecessorJudgmentIdentity = "outcome-C";
        }
        part bindingDuty : ReconciliationResponsibility {
            :>> question = "Can W1 be bound to the original Attempt and effect?";
            :>> disposition = "Close on selection of W1-v2";
        }
        part outcomeDuty : ReconciliationResponsibility {
            :>> question = "Reconcile the original effect outcome";
            :>> disposition = "Close on a current uncontested success judgment";
        }
        part summaryReview : ReconciliationResponsibility {
            :>> question = "Do the claims in summary-B still have valid support?";
            :>> disposition = "Remains open until independently reassessed";
        }
        connection proposedBinding connect candidate to verifiedAdmission;
        connection checksExpectedSubject connect originalIntent to verifiedAdmission;
        connection checksExactWriteAndDigest connect retainedRecord to verifiedAdmission;
        connection checksAssessmentCut connect priorCut to verifiedAdmission;
        connection selectionBasis connect verifiedAdmission to replacementUse;
        connection reusesImmutableRecord connect retainedRecord to replacementUse;
        connection replacesUseWithoutRewriting connect previousUse to replacementUse;
        connection qualifiesExactBinding connect replacementUse to bindingDuty;
        connection suppliesNewSuccessSupport connect replacementUse to currentOutcome;
        connection revisesCurrentView connect priorCut to currentOutcome;
        connection resolvesOriginalQuestion connect currentOutcome to outcomeDuty;
        doc /* D1 is a candidate from discovery. Temporal verifies the exact
               content-bound claim and use. Write identity is storage scoped
               and must match W1's original record, including its digest.
               D1 must establish the intended effect through independent
               lineage. W1-v2 has its own basis. The supersession association
               to W1-v1 is historical and does not supply proof. Summary-B
               needs its own review. These are relations, not a workflow. */
    }
    part def SummaryClaimReview {
        attribute claimKey : String;
        attribute claimText : String;
        attribute requiredBasis : String;
        attribute disposition : String;
    }
    part def InterruptedWriteSummaryReview {
        part historicalSummary : CorrectionLineageNode { :>> lineageKey = "summary-B"; }
        part effectUse : CorrectionLineageNode { :>> lineageKey = "W1-v2"; }
        part commitAudit : CorrectionLineageNode { :>> lineageKey = "storage-commit-audit-v2"; }
        part dispatchAudit : CorrectionLineageNode { :>> lineageKey = "dispatch-audit-v2"; }
        part committed : SummaryClaimReview {
            :>> claimKey = "append-committed";
            :>> claimText = "The original append effect committed";
            :>> requiredBasis = "Current claim assessment against W1-v2 for the exact effect";
            :>> disposition = "Close on verified claim-specific assessment";
        }
        part singleCommit : SummaryClaimReview {
            :>> claimKey = "single-commit";
            :>> claimText = "Exactly one commit for this effect in the recovery window";
            :>> requiredBasis = "Complete independently attributed storage audit showing one commit";
            :>> disposition = "Open until a matching audit proves the count";
        }
        part noReplay : SummaryClaimReview {
            :>> claimKey = "no-replay-dispatch";
            :>> claimText = "No replay dispatch for this effect in the recovery window";
            :>> requiredBasis = "Complete independently scoped dispatch journal showing zero replay dispatches";
            :>> disposition = "Open until a matching audit proves the absence";
        }
        part candidate : CorrectionLineageNode { :>> lineageKey = "summary-v2-draft"; }
        part selection : RecoveryClaimView {
            :>> question = "Do the draft's exact assertions and disclosed open items match the current reviewed inventory?";
            :>> conclusion = "Admit a new version with a current basis, stable parent and explicit coverage";
            :>> unresolvedReasons = "Unassessed claims are pending. Full coverage requires every manifest claim.";
        }
        part admitted : CorrectionLineageNode { :>> lineageKey = "summary-v2"; }
        connection exactEffectBasis connect effectUse to committed;
        connection countBasis connect commitAudit to singleCommit;
        connection dispatchBasis connect dispatchAudit to noReplay;
        connection checksEffectClaim connect committed to selection;
        connection checksCountClaim connect singleCommit to selection;
        connection checksReplayClaim connect noReplay to selection;
        connection verifiesDraft connect candidate to selection;
        connection admitsRevision connect selection to admitted;
        connection retainsPredecessor connect historicalSummary to admitted;
        doc /* Three illustrative claims materialize summary-B's inventory.
               The three reviews may proceed independently. A partial
               version may assert the checked effect and list unresolved
               keys, subject to the declared summary policy. Publication
               neither closes those keys nor revises the archived B
               snapshot. A later version can extend current coverage. */
    }
    part def SummaryAuditRefutation {
        part storageAudit : CorrectionLineageNode { :>> lineageKey = "storage-commit-audit-v2"; }
        part dispatchAudit : CorrectionLineageNode { :>> lineageKey = "dispatch-audit-v2"; }
        part retainedAppend : SummaryClaimReview {
            :>> claimKey = "append-committed";
            :>> claimText = "The original append effect committed";
            :>> requiredBasis = "W1-v2 assessed for the exact append claim";
            :>> disposition = "Supported; close its review";
        }
        part retainedCount : SummaryClaimReview {
            :>> claimKey = "single-commit";
            :>> claimText = "Exactly one commit in the recovery window";
            :>> requiredBasis = "Complete storage audit reports one matching commit";
            :>> disposition = "Supported; close its review";
        }
        part withdrawnReplay : SummaryClaimReview {
            :>> claimKey = "no-replay-dispatch";
            :>> claimText = "No replay dispatch in the recovery window";
            :>> requiredBasis = "One admitted matching replay dispatch refutes absence";
            :>> disposition = "Refuted; close fact review and require withdrawal in the revision";
        }
        part rewrite : SummaryClaimReview {
            :>> claimKey = "one-replay-dispatch";
            :>> claimText = "Exactly one replay dispatch in the recovery window";
            :>> requiredBasis = "Complete dispatch coverage and a fresh assessment of the replacement digest";
            :>> disposition = "Assert only when separately verified";
        }
        part admission : RecoveryClaimView {
            :>> question = "Does the revised summary preserve supported claims and disclose the refutation?";
            :>> conclusion = "Append a current scoped revision; keep B and its original basis in history";
        }
        connection verifiesCount connect storageAudit to retainedCount;
        connection refutesAbsence connect dispatchAudit to withdrawnReplay;
        connection verifiesRewrite connect dispatchAudit to rewrite;
        connection keepsAppend connect retainedAppend to admission;
        connection keepsCount connect retainedCount to admission;
        connection recordsWithdrawal connect withdrawnReplay to admission;
        connection considersRewrite connect rewrite to admission;
        doc /* Review of a fact closes when its disposition is assessed.
               The correction still needs a current admitted publication.
               A complete count of commits does not count dispatches.
               Admission may disclose withdrawal without asserting an exact
               replacement count. These are evidence relations. */
    }
    part def DispatchCoverageCut {
        attribute expectedSlots : String;
        attribute qualifiedSlots : String;
        attribute replayIds : String;
        attribute coverageDisposition : String;
        attribute summaryAuthority : String;
    }
    part def DispatchCoverageComparison {
        part manifest : CorrectionLineageNode { :>> lineageKey = "dispatch-manifest/A+B"; }
        part gap : DispatchCoverageCut {
            :>> expectedSlots = "A/early, A/late, B/early, B/late";
            :>> qualifiedSlots = "A/early, A/late";
            :>> replayIds = "replay-42 witnessed";
            :>> coverageDisposition = "B is missing; coverage and exact-count reviews open";
            :>> summaryAuthority = "Withdraw zero replay; no exact total";
        }
        part closed : DispatchCoverageCut {
            :>> expectedSlots = "A/early, A/late, B/early, B/late";
            :>> qualifiedSlots = "All four sealed slots at the same scope and cut";
            :>> replayIds = "One distinct identity, replay-42";
            :>> coverageDisposition = "Close coverage; close count only after exact claim assessment";
            :>> summaryAuthority = "Admit exact-one with complete coverage basis and current assessment";
        }
        part historical : CorrectionLineageNode { :>> lineageKey = "summary-B and any admitted withdrawal version"; }
        part revised : CorrectionLineageNode { :>> lineageKey = "new summary with exact replay count"; }
        connection definesGapScope connect manifest to gap;
        connection definesClosedScope connect manifest to closed;
        connection suppliesVerifiedCount connect closed to revised;
        connection retainsVersions connect historical to revised;
        doc /* The manifest enumerates all authorized dispatch ranges for the
               exact Attempt, effect and window. Each slot has a verified,
               sealed, non-conflicting receipt for its complete range.
               Count canonical dispatch IDs, not rows. The states compare
               evidence cuts; they do not prescribe an execution order. */
    }
    part def DispatchSealCorrection {
        part priorExact : CorrectionLineageNode { :>> lineageKey = "summary-v3"; }
        part correction : CorrectionLineageNode { :>> lineageKey = "B/late-seal-revocation"; }
        part currentWitness : CorrectionLineageNode { :>> lineageKey = "replay-42-current-qualification"; }
        part coverageDuty : ReconciliationResponsibility {
            :>> question = "Is the corrected B range covered at the current dispatch cut?";
            :>> disposition = "Reopen; require a current qualified seal";
        }
        part countDuty : ReconciliationResponsibility {
            :>> question = "What exact replay count is supported at the current dispatch cut?";
            :>> disposition = "Reopen; assess the count on a fresh complete basis";
        }
        part current : RecoveryClaimView {
            :>> conclusion = "At least one after the A witness is requalified; exact count unresolved";
            :>> predecessorJudgmentIdentity = "summary-v3";
        }
        connection invalidatesCurrentCoverage connect correction to coverageDuty;
        connection coverageChangeAffectsCount connect coverageDuty to countDuty;
        connection supportsLowerBound connect currentWitness to current;
        connection preservesPriorVersion connect priorExact to current;
        doc /* A later correction opens a new dispatch evidence cut for the
               same effect. The prior exact-one snapshot remains historical.
               Requalification of A can support a lower bound independently.
               A new B seal can contain replay-43, which rules out exact-one
               even after coverage is restored. The relations express basis,
               not ordered work. */
    }
    part def DispatchExactTwoAdmission {
        part r42Binding : CorrectionLineageNode { :>> lineageKey = "R42-authority-binding"; }
        part r43Binding : CorrectionLineageNode { :>> lineageKey = "R43-authority-binding"; }
        part completeRanges : CorrectionLineageNode { :>> lineageKey = "current-manifest-and-four-qualified-ranges"; }
        part assessed : RecoveryClaimView {
            :>> question = "Do both authenticated replay identities belong to the original Attempt, effect and recovery window?";
            :>> conclusion = "Exactly two only if distinct canonical IDs exhaust the qualified event set";
            :>> unresolvedReasons = "Check the exact source range, current cut and half-open time window for each identity";
        }
        part countDuty : ReconciliationResponsibility {
            :>> question = "Resolve the original replay count question";
            :>> disposition = "Close on qualified exact-two assessment";
        }
        part publication : ReconciliationResponsibility {
            :>> question = "Select a current summary with the assessed count";
            :>> disposition = "Close on Temporal admission against unchanged assessment basis";
        }
        part historical : CorrectionLineageNode { :>> lineageKey = "summary-v3"; }
        part revised : CorrectionLineageNode { :>> lineageKey = "new-exact-two-summary"; }
        connection bindsFirst connect r42Binding to assessed;
        connection bindsSecond connect r43Binding to assessed;
        connection verifiesExhaustiveness connect completeRanges to assessed;
        connection resolvesCount connect assessed to countDuty;
        connection bindsPublication connect assessed to revised;
        connection appendsRevision connect revised to publication;
        connection keepsPriorBasis connect historical to revised;
        doc /* Both identities are verified against the same current manifest,
               range inventory, original Attempt and effect. A copied receipt
               for the same canonical ID supplies one event. Scope and
               assessment relations express conditions, not a workflow. */
    }
    part def DispatchAliasCorrection {
        part forwardedCopy : CorrectionLineageNode { :>> lineageKey = "B-late-R43-observes-A-early-R42"; }
        part withdrawnCount : RecoveryClaimView {
            :>> question = "Does the selected v4 basis still support two dispatches?";
            :>> conclusion = "Withdraw exact two when the scoped identity correction is admitted";
        }
        part countReview : ReconciliationResponsibility {
            :>> question = "How many distinct replays occurred in the original window?";
            :>> disposition = "Reopen on withdrawal; close on fresh exact-one assessment";
        }
        part freshRanges : CorrectionLineageNode { :>> lineageKey = "corrected-cut-complete-four-range-singleton-R42"; }
        part historicalV3 : CorrectionLineageNode { :>> lineageKey = "summary-v3-immutable"; }
        part historicalV4 : CorrectionLineageNode { :>> lineageKey = "summary-v4-immutable"; }
        part admittedV5 : RecoveryClaimView {
            :>> question = "May Temporal admit a new exact-one summary?";
            :>> conclusion = "Select v5 only while its fresh assessment basis remains current";
        }
        connection correctsBasis connect forwardedCopy to withdrawnCount;
        connection reopensReview connect withdrawnCount to countReview;
        connection qualifiesSingleton connect freshRanges to countReview;
        connection supportsAdmission connect freshRanges to admittedV5;
        connection retainsCopyLineage connect forwardedCopy to admittedV5;
        connection preservesV3 connect historicalV3 to admittedV5;
        connection preservesV4 connect historicalV4 to admittedV5;
    }
    part def DispatchCountRevision {
        part scopeKey : CorrectionLineageNode { :>> lineageKey = "original-attempt-append-effect-occurrence-window"; }
        part observationLedger : CorrectionLineageNode { :>> lineageKey = "records-and-canonical-dispatch-bindings"; }
        part contradictedBasis : RecoveryClaimView {
            :>> question = "Does the current evidence still support an exact count?";
            :>> conclusion = "Withdraw exact support on an admitted correction or independent counterexample";
        }
        part countDuty : ReconciliationResponsibility {
            :>> question = "How many distinct replays occurred in the original window?";
            :>> disposition = "Keep the same duty; reopen on refutation and close on current exhaustive assessment";
        }
        part exactBasis : CorrectionLineageNode { :>> lineageKey = "current-complete-ranges-and-canonical-dispatch-set"; }
        part currentAnswer : RecoveryClaimView {
            :>> question = "What can the scoped count say now?";
            :>> conclusion = "Select a lower bound or current exact assessment; repeated basis adds no history";
        }
        part retainedHistory : CorrectionLineageNode { :>> lineageKey = "earlier-judgments-and-their-evidence"; }
        connection scopesQuestion connect scopeKey to countDuty;
        connection recordsCopies connect scopeKey to observationLedger;
        connection reopensCount connect contradictedBasis to countDuty;
        connection closesCount connect exactBasis to countDuty;
        connection qualifiesSelection connect exactBasis to currentAnswer;
        connection retainsPriorBases connect currentAnswer to retainedHistory;
        doc /* A confirmed copy that changes no support affects observation provenance only.
               Canonical identity correction and independent counterevidence can change the answer
               while the scope and identity of the count duty remain stable. */
    }
    part def InterruptedWriteRecoveryDesign {
        part originalAttempt : RetainedRecoveryAttempt;
        part evidenceComparison : InterruptedWriteEvidenceComparison;
        part correctionComparison : InterruptedWriteCorrectionComparison;
        part indirectAttribution : InterruptedWriteIndirectAttribution;
        part directBindingAdmission : DirectBindingAdmissionReading;
        part summaryReview : InterruptedWriteSummaryReview;
        part auditRefutation : SummaryAuditRefutation;
        part dispatchCoverage : DispatchCoverageComparison;
        part dispatchSealCorrection : DispatchSealCorrection;
        part dispatchExactTwo : DispatchExactTwoAdmission;
        part dispatchAliasCorrection : DispatchAliasCorrection;
        part dispatchCountRevision : DispatchCountRevision;
        part moduleComposition : DurableFeatureComposition;
        part domainPolicy : DurableEngineConfig {
            :>> outcomeInterpreter = "Interpret admitted Temporal uses for the exact effect";
            :>> outcomeInput = "Version-bound observations, receipt uses and causal assessments";
            :>> retryPolicy = "Propose repetition with scoped justification";
            :>> retryInputs = "Outcome, current permission, effect-specific repeat safety";
            :>> decisionBoundary = "Success veto; eligibility is not dispatch authority";
        }
        part temporalLineage : TemporalEvidenceLineageView;
        part hypotheses : RecoveryHypothesisView;
        part compositionJudgment : RecoveryClaimView {
            :>> question = "Can the retained composition be interpreted now?";
            :>> conclusion = "Requires saved/current contract comparison";
        }
        part outcomeJudgment : RecoveryClaimView {
            :>> question = "Did the original effect complete?";
            :>> conclusion = "Unknown at first recovery observation";
            :>> unresolvedReasons = "No admitted result; changed bytes alone do not establish attribution";
        }
        part repeatJudgment : RecoveryClaimView {
            :>> question = "Is another dispatch eligible now?";
            :>> conclusion = "Withheld until all applicable guards are established";
            :>> unresolvedReasons = "Current permission and scoped repeat safety require independent evidence";
        }
        part outcomeResponsibility : ReconciliationResponsibility {
            :>> question = "Reconcile the original effect outcome";
            :>> responsibleRole = "Session/Task owner retains responsibility; capable investigators may supply evidence";
        }
        part attributionResponsibility : ReconciliationResponsibility {
            :>> question = "Does the observed change establish this effect's completion?";
            :>> responsibleRole = "Evidence investigator and configured evidence evaluator";
        }
        part relationReasoning : AscentRecoveryRelationView;
        part exploration : ModelRecoveryExploration;
        connection comparesSameAttempt connect evidenceComparison to originalAttempt;
        connection scopesCorrection connect correctionComparison to originalAttempt;
        connection scopesIndirectAttribution connect indirectAttribution to originalAttempt;
        connection scopesReadmission connect directBindingAdmission to originalAttempt;
        connection offersNewSummaryBasis connect directBindingAdmission to summaryReview;
        connection refinesSummaryDispositions connect summaryReview to auditRefutation;
        connection scopesExactReplayEvidence connect auditRefutation to dispatchCoverage;
        connection correctsCoverageBasis connect dispatchCoverage to dispatchSealCorrection;
        connection reassessesCorrectedCount connect dispatchSealCorrection to dispatchExactTwo;
        connection retainsBinding connect originalAttempt to moduleComposition.savedComposition;
        connection comparesBindings connect moduleComposition to compositionJudgment;
        connection domainInterpretsUses connect domainPolicy to outcomeJudgment;
        connection evidenceAssessesOutcome connect temporalLineage to outcomeJudgment;
        connection evidenceConstrainsHypotheses connect temporalLineage to hypotheses;
        connection alternativesInformAssessment connect hypotheses to outcomeJudgment;
        connection outcomeConstrainsRepeat connect outcomeJudgment to repeatJudgment;
        connection compositionConstrainsRepeat connect compositionJudgment to repeatJudgment;
        connection policyRequiresIndependentGuards connect domainPolicy to repeatJudgment;
        connection outcomePremises connect outcomeJudgment to relationReasoning;
        connection compositionPremises connect compositionJudgment to relationReasoning;
        connection retryPremises connect repeatJudgment to relationReasoning;
        connection temporalCutAndChanges connect temporalLineage to relationReasoning;
        connection alternativePremises connect hypotheses to relationReasoning;
        connection derivesOutcomeDuty connect relationReasoning to outcomeResponsibility;
        connection derivesAttributionDuty connect relationReasoning to attributionResponsibility;
        connection retainsOriginalQuestion connect outcomeResponsibility to originalAttempt;
        connection offersOutcomeQuestion connect outcomeResponsibility to exploration;
        connection offersAttributionQuestion connect attributionResponsibility to exploration;
        connection suppliesExplorationContext connect temporalLineage to exploration;
        connection proposesDiscriminators connect exploration to hypotheses;
        connection findingsRequireTemporalAdmission connect exploration to temporalLineage;
        doc /* Scenario truth: bytes changed, receipt not retained before crash.
               Recovered knowledge: original Attempt retained, outcome unknown.
               These connections are semantic dependencies, not action ordering.
               A late admitted success revises outcome and vetoes redispatch.
               A correction preserves history and reopens affected questions.
               Permission changes can affect eligibility without changing outcome.
               Source coverage, conflict resolution and binding compatibility
               may derive further responsibilities under the ORG contract. */
    }
    // Cross-artifact semantic mapping, not an execution or refinement claim.
    // workspace-recovery.qnt :: RecoveryEvidenceInquiry models knowledge changes.
    // workspace-recovery.lean :: RecoveryEvidenceInquiry proves scoped safety.
    // outcomeJudgment <-> outcome; outcomeResponsibility <-> outcomeDuty/duties.
    // temporalLineage revisions <-> revise/priorCuts; exploration <-> InquiryTrace.
    // The D2 RecoveryEvidenceView exposes this exact instance.
    part interruptedWriteDesign : InterruptedWriteRecoveryDesign;

    // Historical bounded repeated-boot verification, separate from the design above.
    part def OwnerFixture;
    part fixture : OwnerFixture;

    // Five failed boots followed by a sixth boot that opens the owner.
    // Cut 0 rolls back before a new decision, cut 1 commits pending source
    // work but dies before readiness, cut 2 commits readiness then dies.
    // This abstracts storage/proof replay; runtime process deaths qualify those.
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
        // Terminal bytes are immutable input in this model. Runtime SQL checks
        // retain the actual payload hashes through every failed recovery.
        out retainedTerminals : Integer = if consumerKind == 0 ? 1 else if consumerKind == 1 ? 3 else 0;
        return verdict : VerdictKind = PassIf(processed == 6 and sourceApplied
            and sourceDecisions == 1 and ownerEpoch == 7 and readyEpoch == ownerEpoch
            and durablePending == (if consumerKind == 0 ? 1 else 0) and not bAdmitted);
    }

    // Proposed composition ownership, not a replacement verification engine.
    part def ContextModule {
        attribute extensionPoint : String = "Context reconstruction contributions";
    }
    part def RecoveryFeature {
        attribute contribution : String = "Context state projection and reconstruction";
        attribute requiredContract : String = "Durable provider contract";
    }
    part def DurableModule {
        attribute responsibility : String = "Journal, commit and writer fence";
    }
    part def SessionModule {
        attribute responsibility : String = "Original Attempt and unresolved worker responsibility";
    }
    part def CoreFeatureBinding {
        attribute responsibility : String = "Resolve contributions and bind declared contracts";
        attribute execution : String = "Inert until explicit runtime handoff";
    }
    part def CompositionRecord {
        attribute extensionRevision : String;
        attribute selectedOptions : String;
        attribute durableProvider : String;
        attribute contractVersion : String;
        attribute checkpointSchema : String;
        doc /* Match the retained binding before interpreting the checkpoint. */
    }
    part def DurableFeatureComposition {
        part context : ContextModule;
        part recovery : RecoveryFeature;
        part durable : DurableModule;
        part session : SessionModule;
        part contractBinding : CoreFeatureBinding;
        part savedComposition : CompositionRecord;
        connection retainsComposition connect contractBinding to savedComposition;
        connection extendsContext connect recovery to context;
        connection requiresDurable connect recovery to durable;
        connection contributesToBinding connect recovery to contractBinding;
        connection suppliesContract connect durable to contractBinding;
        connection keepsTaskOwnership connect session to context;
    }
    part compositionDesign : DurableFeatureComposition;
    part def OwnerState {
        attribute ownerIdentity : String;
        attribute readiness : String;
    }
    part def JournalState {
        attribute sourceDecision : String = "Committed; retain without rerunning";
        attribute attemptResponsibility : String = "Original Attempt unresolved";
        attribute readinessEvidence : String = "Historical previous owner";
    }
    part def RecoveryExplanation {
        part previous : OwnerState { :>> ownerIdentity = "previous"; :>> readiness = "historical READY"; }
        part retained : JournalState;
        part rebuilding : OwnerState { :>> ownerIdentity = "new"; :>> readiness = "not current-ready"; }
        part current : OwnerState { :>> ownerIdentity = "new"; :>> readiness = "current READY; old Attempt still unresolved"; }
        connection ownerChanges connect previous to rebuilding;
        connection committedStateRemains connect previous to retained;
        connection reconstructFromJournal connect retained to rebuilding;
        connection currentReadinessRequiresReconstruction connect rebuilding to current;
    }
    part recoveryExplanation : RecoveryExplanation;
    part def RecoveryJudgment {
        attribute evidence : String;
        attribute conclusion : String;
    }
    part def DurableEngineConfig {
        attribute outcomeInterpreter : String;
        attribute outcomeInput : String;
        attribute retryInputs : String;
        attribute decisionBoundary : String;
        attribute retryPolicy : String;
    }
    part def ProjectedRecoveryDecision {
        attribute originalAttemptId : String;
        attribute originalEffectId : String;
        attribute policyRevision : String;
        attribute evidenceCut : String;
        attribute recordedOutcome : String;
        attribute interpretation : String;
        attribute effectiveOutcome : String;
        attribute currentPermission : Boolean;
        attribute repeatSafe : Boolean;
        attribute retryProposed : Boolean;
        attribute retryEligible : Boolean;
        doc /* Eligible requires a matching binding, a non-successful outcome,
               a retry proposal, current permission and repeat safety.
               The host checks the current scope and consumes a capability. */
    }
    part def HostRecoveryHandoff {
        attribute receiptDigest : String;
        attribute lastRefusal : String;
        attribute currentOwnerEpoch : Integer;
        attribute capabilitySpent : Boolean;
        attribute precedingSpendDigest : String;
        attribute reconciledSpendDigest : String;
        attribute liveHandoff : Boolean;
        attribute issuerConsumedTokenIdentity : String;
        attribute liveObservationMatchesReceipt : Boolean;
        attribute originalIntentDigest : String;
        attribute qualifiedWorkerReceipt : Boolean;
        doc /* The fenced owner exports the exact applied decision at its current cut.
               Require a fresh coherent workspace read matching the receipt at consume and dispatch.
               Retain the journal spend before consuming the issuer grant.
               Call the endpoint only with the consumed issuer handoff.
               Takeover clears live handoff authority and preserves unresolved effects.
               Fresh retry evidence must name the latest preceding spend. */
    }
    part def RecoveryExtensionLayers {
        part assembly : DurableFeatureComposition;
        part engineConfig : DurableEngineConfig {
            :>> outcomeInterpreter = "Trust evidence tied to the original effect";
            :>> retryPolicy = "Propose whether to retry";
            :>> outcomeInput = "Admitted observations for the original effect";
            :>> retryInputs = "Effect outcome, current permission and repeat safety";
            :>> decisionBoundary = "Eligibility only; host capability required for dispatch";
        }
        part recoveredAttempt : AttemptJudgments;
        part hostHandoff : HostRecoveryHandoff;
        part projectedDecision : ProjectedRecoveryDecision {
            :>> recordedOutcome = "Unknown";
            :>> interpretation = "Unknown";
            :>> effectiveOutcome = "Unknown";
            :>> currentPermission = false;
            :>> repeatSafe = false;
            :>> retryProposed = true;
            :>> retryEligible = false;
        }
        connection checksCommittedDecision connect projectedDecision to hostHandoff;
        connection projectsAttemptEvidence connect recoveredAttempt to projectedDecision;
        connection suppliesDecisionPolicy connect engineConfig to projectedDecision;
        connection suppliesConfig connect assembly to engineConfig;
        connection interpretsOutcome connect engineConfig to recoveredAttempt.effectCheck;
        connection evaluatesRetry connect engineConfig to recoveredAttempt.retryCheck;
    }
    part recoveryExtensionLayers : RecoveryExtensionLayers;
    part def AttemptJudgments {
        part retained : JournalState;
        part savedBinding : CompositionRecord;
        part currentBinding : CompositionRecord;
        part compositionCheck : RecoveryJudgment {
            :>> evidence = "Saved binding matches current binding";
            :>> conclusion = "Checkpoint can be interpreted";
        }
        part effectCheck : RecoveryJudgment {
            :>> evidence = "No trusted outcome tied to the original effect";
            :>> conclusion = "Effect completion unknown";
        }
        part retryCheck : RecoveryJudgment {
            :>> evidence = "Current permission and repeat safety not established";
            :>> conclusion = "Withhold redispatch";
        }
        connection savedEvidence connect savedBinding to compositionCheck;
        connection currentEvidence connect currentBinding to compositionCheck;
        connection compositionQuestion connect retained to compositionCheck;
        connection effectQuestion connect retained to effectCheck;
        connection retryQuestion connect retained to retryCheck;
    }
    part attemptJudgments : AttemptJudgments;
}
