// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package RecoveryFirstObservation {
    private import ScalarValues::*;
    doc /* Proposed semantic model and explanatory fixture, not an executable
           workspace recovery workflow or an exactly-once effect guarantee. */
    enum def ContentKnowledge { unobserved; matchesDesired; matchesBase; other; unstable; }
    enum def HistoryKnowledge { unresolved; applied; notApplied; conflicting; }
    enum def AcceptanceKnowledge { open; accepted; refused; }
    part def RetainedIntent {
        attribute taskIdentity : String;
        attribute specificationRevision : String;
        attribute attemptIdentity : String;
        attribute commandIdentity : String;
        attribute originalOwnerEpoch : String;
        attribute workspaceScope : String;
        attribute beforeDigest : String;
        attribute desiredChangeDigest : String;
        attribute illustrativeEdit : String = "mode: slow -> mode: fast";
    }
    part def JournalObservation {
        attribute recoveredCut : String;
        attribute currentOwnerEpoch : String;
        attribute coverage : String = "complete for this command";
        attribute receipt : String = "missing";
        doc /* Missing at a qualified cut does not mean the write never happened.
               Unknown/partial coverage cannot establish this absence. */
    }
    part def WorkspaceObservation {
        attribute sourceIdentity : String;
        attribute readScope : String;
        attribute coherentCut : String;
        attribute content : ContentKnowledge;
        attribute observedText : String = "mode: fast";
        doc /* An admitted coherent read supplies current content only. It does
               not establish provenance, whole-change coverage or permission. */
    }
    part def HistoricalWitness {
        attribute commandIdentity : String;
        attribute originalAttempt : String;
        attribute originalEpoch : String;
        attribute sourceBinding : String;
        attribute outcome : HistoryKnowledge;
    }
    part def OpenResponsibility {
        attribute responsibilitySubject : String;
        attribute owner : String;
        attribute requiredEvidence : String;
        attribute dischargeCondition : String;
        doc /* A responsibility is retained through recovery. Its discharge
               cannot be inferred from model confidence or matching text. */
    }
    part def ModelExploration {
        attribute initialQuestion : String = "The file says fast. Did our edit do it?";
        attribute alternative : String = "Could another writer explain the same text?";
        doc /* Questions and hypotheses are extensible proposals. They need not
               become Tasks, and do not authorize a probe or external effect. */
    }
    part def RecoveryContext {
        attribute identity : String;
        attribute revision : String;
        attribute currentContent : ContentKnowledge = ContentKnowledge::unobserved;
        attribute originalEffect : HistoryKnowledge = HistoryKnowledge::unresolved;
        attribute taskAcceptance : AcceptanceKnowledge = AcceptanceKnowledge::open;
        part intent : RetainedIntent;
        part journal : JournalObservation;
        part observed : WorkspaceObservation;
        part historicalEvidence : HistoricalWitness;
        part contentDuty : OpenResponsibility { doc /* Context source owner and admitted workspace read Host. */ }
        part historyDuty : OpenResponsibility { doc /* Original Session/Attempt effect owner; preserve conflicting witnesses. */ }
        part writerDuty : OpenResponsibility { doc /* Existing effect Host and Session owner; an epoch fence is not physical termination. */ }
        part wholeChangeDuty : OpenResponsibility { doc /* Existing Task contract owner and all required result ports. */ }
        part acceptanceDuty : OpenResponsibility { doc /* Existing Task/Session publication owner; independently qualified acceptance. */ }
        part model : ModelExploration;
        connection intentBindsHistory connect intent to historyDuty;
        connection gapRequiresReconciliation connect journal to writerDuty;
        connection readMayAnswerContent connect observed to contentDuty;
        connection witnessMayAnswerHistory connect historicalEvidence to historyDuty;
        connection unresolvedHistoryInvitesQuestions connect historyDuty to model;
        connection wholeChangeRemainsIndependent connect wholeChangeDuty to acceptanceDuty;
        doc /* These named duties illustrate retained contract requirements; other
               Tasks may declare other ports without a new workflow rule.
               Responsibilities exist before journal coverage is established.
               These relations are not execution edges. Matching observed text
               can coexist with unresolved originalEffect and open acceptance.
               Previous Context revisions and conflicting witnesses survive.
               Independently accepting a newly verified present state need not
               resolve the old effect; never fabricate an original terminal. */
    }
    part fixture : RecoveryContext;
}
