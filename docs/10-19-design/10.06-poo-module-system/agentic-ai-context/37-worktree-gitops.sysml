// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package OrgWorktreeGitOpsProtocol {
    private import ScalarValues::*;

    item def OrgCut {
        attribute project : String;
        attribute worktree : String;
        attribute path : String;
        attribute text : String;
        attribute gitHead : String;
    }
    item def PolicyValue {
        attribute revision : String[0..1];
        attribute allowedCapabilities : String[*];
        attribute preferredCapability : String;
        attribute selectorIdentity : String;
        attribute anchor : String[0..1];
        item source : OrgCut[0..1];
    }
    item def Availability {
        attribute capability : String;
        attribute available : Boolean;
    }
    item def Selection {
        attribute selectedCapability : String[0..1];
    }
    item def WorkingCopyBinding {
        attribute path : String;
        attribute branch : String[0..1];
    }
    item def CurrentFacts {
        item source : OrgCut;
        attribute request : String;
        attribute provider : String;
        attribute policyRevision : String;
        attribute authorized : Boolean;
        attribute fenceCurrent : Boolean;
        doc /* The consumer supplies observations from its execution owner.
               Lab neither observes the repository nor issues grants. */
    }
    item def ExecutionReceipt {
        item source : OrgCut;
        attribute request : String;
        attribute policyRevision : String;
        attribute anchor : String;
        attribute provider : String;
        attribute custodyValid : Boolean;
        attribute executed : Boolean;
        attribute outcome : String;
        item workingCopy : WorkingCopyBinding[0..1];
    }
    item def EvidenceState {
        item receipts : ExecutionReceipt[*];
        attribute spentRequests : String[*];
        item activePolicy : PolicyValue[0..1];
        attribute activeRequest : String[0..1];
        attribute activeProvider : String[0..1];
        attribute admitted : Boolean;
        attribute accepted : Boolean;
        item 'binding' : WorkingCopyBinding[0..1];
    }
    port def PolicyPort {
        in item parent : PolicyValue;
        in item context : OrgCut;
        in attribute anchor : String;
        in attribute policyRevision : String;
        in item availability : Availability[*];
        out item specialized : PolicyValue;
        out item selection : Selection;
    }
    port def EvidencePort {
        in item policy : PolicyValue;
        in item current : CurrentFacts;
        in item receipt : ExecutionReceipt;
        in item previous : EvidenceState;
        out item successor : EvidenceState;
    }
    part def PolicyComposition;
    part def EvidenceInterpretation;
    part def CreateContract {
        attribute identity : String = "agentic-ai-lab.gitops.create";
        attribute revision : Integer = 4;
        doc /* Input Types: OrgCut, PolicyValue, CurrentFacts, ExecutionReceipt
               and EvidenceState. Shape admission does not establish custody. */
    }
    part def LabGitOpsLibrary {
        port policy : PolicyPort;
        port evidence : EvidencePort;
        part composition : PolicyComposition;
        part interpretation : EvidenceInterpretation;
        part contract : CreateContract;
        doc /* Public Yuanxu GitOps Module. POO/functional values only.
               No concrete downstream package, worker, scheduler or transport. */
    }
    part def ExecutionOwner {
        doc /* Selected by the consumer. Owns observation, pre-effect version
               fencing, custody, actual effects and original receipt retention. */
    }
    part def ConsumerPackage {
        port policy : ~PolicyPort;
        port evidence : ~EvidencePort;
        part execution : ExecutionOwner;
        doc /* An application supplies its adapter and chooses an execution
               ecosystem. It can use the library without a particular runtime. */
    }
    part architecture {
        part semantics : LabGitOpsLibrary;
        part consumer : ConsumerPackage;
        connection policyUse connect consumer.policy to semantics.policy;
        connection receiptUse connect consumer.evidence to semantics.evidence;
    }

    requirement inputValidity {
        doc /* Public operations admit POO inputs through named Type descriptors.
               Source/request/revision identities are nonempty. Grant, fence,
               custody and executed facts are Boolean, not truthy declarations.
               Malformed inputs produce no successor evidence state. */
    }
    requirement capabilityRestriction {
        doc /* Derived allowed = parent allowed intersect Org declarations.
               Overridden selectors cannot grant an unavailable capability. */
    }
    requirement policyDerivation {
        doc /* Binding intersects the supplied parent's capabilities with Org
               declarations, inherits the named selector, and captures source,
               anchor, preference and a nonempty revision. It leaves the parent
               unchanged; deriving again cannot restore removed capabilities. */
    }
    requirement policyReplacement {
        doc /* The caller selects a new Policy value explicitly. Refresh under
               a different active Policy withdraws current use. A definition
               change carries an author-supplied new revision; the library
               compares revisions, not arbitrary procedure equivalence. Old
               receipts remain historical and are reconsidered against the
               selected source/revision/anchor/provider and current facts. */
    }
    requirement semanticAdmission {
        doc /* Accept only a fresh matching request, source, anchor and policy,
               current grant and fence, valid custody, execution and applied
               outcome with an actual returned binding and the provider selected
               for that request. Retain contract-compatible refused evidence. */
    }
    requirement evidenceHistory {
        doc /* Redelivery never admits twice. Revocation withdraws current use
               without deleting history or resurrecting a spent request.
               Current use retains the exact active request, provider and Policy. */
    }
    requirement physicalFence {
        doc /* The execution owner checks current source/version/grant before
               an effect and establishes the authenticity of returned facts.
               Scheme admission is conditional on this external obligation. */
    }
    requirement boundedRefinement {
        doc /* For Type-admitted inputs in the named finite partition, alpha of
               the actual Scheme successor equals the Quint library transition.
               Ordered history, spent identities, active Policy/request/provider,
               binding, new admission and current use all belong to alpha.
               External observation/execution steps are outside this relation. */
    }
    allocation compose allocate capabilityRestriction to architecture.semantics.composition;
    allocation bindOrg allocate policyDerivation to architecture.semantics.composition;
    allocation replacePolicy allocate policyReplacement to architecture.semantics.interpretation;
    allocation defineInputs allocate inputValidity to architecture.semantics.contract;
    allocation interpret allocate semanticAdmission to architecture.semantics.interpretation;
    allocation retain allocate evidenceHistory to architecture.semantics.interpretation;
    allocation fence allocate physicalFence to architecture.consumer.execution;
    allocation projectSemantics allocate boundedRefinement to architecture.semantics.contract;

    // These are verification objectives traced to actual Scheme cases, not
    // synthesized verdicts. The Scheme harness supplies execution evidence.
    verification def ContractCases {
        subject target : LabGitOpsLibrary;
        objective { verify inputValidity; }
        doc /* working-copy-test.ss: C01, C02, C03. */
    }
    verification def PolicyCases {
        subject target : LabGitOpsLibrary;
        objective { verify capabilityRestriction; }
        doc /* working-copy-test.ss: P01, P02, P03, P04, P05. */
    }
    verification def PolicyLifecycleCases {
        subject target : LabGitOpsLibrary;
        objective { verify policyDerivation; verify policyReplacement; }
        doc /* refinement-test.ss: the derived Policy value projection and
               replacementTest's old-revision, new-revision, old-Org and new-Org
               receipt transitions. These are supplied observations, not effects. */
    }
    verification def AdmissionCases {
        subject target : LabGitOpsLibrary;
        objective { verify semanticAdmission; }
        doc /* working-copy-test.ss: E01, E02, E04. */
    }
    verification def HistoryCases {
        subject target : LabGitOpsLibrary;
        objective { verify evidenceHistory; }
        doc /* working-copy-test.ss: E01, E03, E04, E05. */
    }
    verification def RefinementCases {
        subject target : LabGitOpsLibrary;
        objective { verify boundedRefinement; }
        doc /* refinement-test.ss R01 consumes Quint ITF witnesses and executes
               the public Scheme operations: 49,556 finite cases, with an
               independent corruption control for each of alpha's eight fields
               and two identity-preserving-value reconstruction controls.
               This is bounded correspondence, not an unbounded source theorem. */
    }

    attribute def Composed;
    attribute def Selected;
    attribute def EffectObserved;
    attribute def Accepted;
    attribute def Refused;
    attribute def Withdrawn;
    state def LibraryUse {
        first start then requested;
        state requested;
        state bound;
        state selected;
        state observed;
        state admitted;
        state retained;
        state withdrawn;
        transition bindPolicy first requested accept Composed then bound;
        transition selectProvider first bound accept Selected then selected;
        // Physical execution is external; this transition receives its evidence.
        transition receiveEvidence first selected accept EffectObserved then observed;
        transition admitReceipt first observed accept Accepted then admitted;
        transition preserveEvidence first observed accept Refused then retained;
        transition withdrawBinding first admitted accept Withdrawn then withdrawn;
    }
}
