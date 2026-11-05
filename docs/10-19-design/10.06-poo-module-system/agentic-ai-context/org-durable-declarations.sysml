// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package OrgDurableDeclarations {
    private import ScalarValues::*;
    part def OrgDeclaration {
        attribute declarationKey : String;
        attribute selectedElement : String;
        attribute sourceCut : String;
    }
    part def AdmittedBinding {
        attribute bindingRef : String;
        attribute targetContract : String;
        attribute triggerStream : String;
        attribute authorizedScope : String;
    }
    part def TriggerObservation {
        attribute occurrenceKey : String;
        attribute deliveredBinding : String;
    }
    part def OwnerAdmission {
        attribute condition : String = "Current binding, enabled, current authority, unseen activation key";
        doc /* The fenced durable write accepts the activation and freezes its input together. */
    }
    part def AcceptedWork {
        attribute activationKey : String;
        attribute frozenBinding : String;
        attribute retainedEffectQuestion : String;
    }
    part def ContextInquiry {
        attribute outcome : String = "Unknown until attempt-bound evidence qualifies";
    }
    part def DeclarationBoundary {
        part heading : OrgDeclaration;
        part admittedInput : AdmittedBinding;
        part triggerFact : TriggerObservation;
        part admission : OwnerAdmission;
        part journal : AcceptedWork;
        part inquiry : ContextInquiry;
        connection qualifiesSource connect heading to admittedInput;
        connection scopesAdmission connect admittedInput to admission;
        connection proposesActivation connect triggerFact to admission;
        connection retainsAcceptance connect admission to journal;
        connection exposesEvidenceQuestion connect journal to inquiry;
    }
    part def ModelProposal {
        attribute questionRef : String;
        attribute relevantContextBasis : String;
        attribute candidateObservation : String;
        doc /* The model can offer alternatives or defer. A proposal carries no authority. */
    }
    part def InquiryWake {
        attribute reason : String = "New evidence, changed intent, or a due deadline";
    }
    part def EvidenceFinding {
        attribute applicability : String = "Candidate for Temporal assessment";
    }
    part def AgenticInquiry {
        part intentSource : OrgDeclaration;
        part wakeFact : InquiryWake;
        part workingInquiry : ContextInquiry;
        part proposal : ModelProposal;
        part guard : OwnerAdmission;
        part retainedDecision : AcceptedWork;
        part finding : EvidenceFinding;
        connection qualifiesIntent connect intentSource to workingInquiry;
        connection reconsidersQuestion connect wakeFact to workingInquiry;
        connection scopesAlternatives connect workingInquiry to proposal;
        connection requestsAdmission connect proposal to guard;
        connection retainsDecision connect guard to retainedDecision;
        connection correlatesFinding connect retainedDecision to finding;
        connection assessesFinding connect finding to workingInquiry;
        doc /* Edges bind causes, permissions and evidence. They do not prescribe exploration order. */
    }
    part def AgendaCommitment {
        attribute elementRef : String;
        attribute startsAt : String;
        attribute timeZone : String;
    }
    part def AgendaNotice {
        attribute elementRef : String;
        attribute notifyAt : String;
        attribute audienceRef : String;
        attribute sharingScope : String;
    }
    part def AgendaSelection {
        attribute sourceBasis : String;
        attribute normalizedAudience : String;
        doc /* Existing Context Org Element Query relates the notice and commitment. */
    }
    part def NoticePreparation {
        attribute candidateBasis : String;
        doc /* Revocable before owner-fenced consumption. */
    }
    part def NoticeHandoff {
        attribute deliveryKey : String;
        attribute frozenInput : String;
        doc /* The consumed per-recipient handoff survives changes and restart.
               Its key and frozen payload bind late provider receipts. */
    }
    part def NoticeEvidence {
        attribute outcome : String = "Unknown until a scoped provider result is admitted";
    }
    part def ProviderLookup {
        attribute boundHandoff : String;
        attribute coverage : String;
        doc /* A missing row is an observation; final nonacceptance requires a provider fence. */
    }
    part def RecipientReconciliation {
        attribute assessment : String = "Unknown, accepted, confirmed no send, or conflicted";
    }
    part def LinkedNoticeProposal {
        attribute kind : String = "Correction or replacement";
        attribute sourceHandoff : String;
        attribute evidenceBasis : String;
        doc /* A distinct notice key and current permission are checked at consumption. */
    }
    part def AgendaDraft {
        attribute sourceBase : String;
        attribute proposedIntent : String;
    }
    part def EffectEnvelope {
        attribute normalizedEffect : String;
        doc /* Includes both times, recipient, provider, disclosure and delivery policy. */
    }
    part def AgendaAuthority {
        attribute approvedEffect : String;
        attribute grantStatus : String;
        doc /* An Org property alone cannot create authority. */
    }
    part def CorrectionIdentity {
        attribute originalHandoff : String;
        attribute materialChange : String;
        doc /* Repeated evidence or proposals use the same key. Consumption retains its frozen payload. */
    }
    part def AgendaAutomation {
        part workElement : AgendaCommitment;
        part noticeElement : AgendaNotice;
        part selectedElements : AgendaSelection;
        part authoredDraft : AgendaDraft;
        part resolvedEffect : EffectEnvelope;
        part currentGrant : AgendaAuthority;
        part dueWake : TriggerObservation;
        part ownerAdmission : OwnerAdmission;
        part sendCandidate : NoticePreparation;
        part recipientDecision : NoticeHandoff;
        part outcomeEvidence : NoticeEvidence;
        part providerQuery : ProviderLookup;
        part recipientReview : RecipientReconciliation;
        part linkedNotice : LinkedNoticeProposal;
        part correctionKey : CorrectionIdentity;
        part inquiry : ContextInquiry;
        connection suppliesStart connect workElement to selectedElements;
        connection suppliesIntent connect noticeElement to selectedElements;
        connection projectsWrittenSource connect authoredDraft to selectedElements;
        connection normalizesEffect connect selectedElements to resolvedEffect;
        connection qualifiesBinding connect selectedElements to ownerAdmission;
        connection checksEffect connect resolvedEffect to ownerAdmission;
        connection checksAuthority connect currentGrant to ownerAdmission;
        connection qualifiesPreparation connect selectedElements to sendCandidate;
        connection checksBeforeConsumption connect sendCandidate to ownerAdmission;
        connection suppliesDueTime connect dueWake to ownerAdmission;
        connection retainsRecipientDecision connect ownerAdmission to recipientDecision;
        connection correlatesReceipt connect recipientDecision to outcomeEvidence;
        connection bindsLookup connect recipientDecision to providerQuery;
        connection assessesLookup connect providerQuery to recipientReview;
        connection assessesReceipt connect outcomeEvidence to recipientReview;
        connection returnsEvidence connect recipientReview to inquiry;
        connection informsProposal connect recipientReview to linkedNotice;
        connection bindsCorrectionKey connect linkedNotice to correctionKey;
        connection deduplicatesCorrection connect correctionKey to ownerAdmission;
        connection checksFollowup connect linkedNotice to ownerAdmission;
    }
    part agendaDesign : AgendaAutomation;
    part inquiryDesign : AgenticInquiry;
    part boundary : DeclarationBoundary;
}
