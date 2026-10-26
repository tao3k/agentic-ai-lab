// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package SessionBoundaryContracts {
    private import ScalarValues::*;
    item def SessionInputRef {
        attribute producerIdentity : String;
        attribute contractVersion : String;
        attribute inputIdentity : String;
        attribute inputDigest : String;
        attribute scopeDigest : String;
        attribute admissionReceiptRef : String;
        doc /* Architectural subset of the Session-owned input contract, not
               a complete wire schema. Session preserves opaque producer bindings;
               Context interprets content and admission. No import of Context. */
    }
}

package AgenticAIContextArchitecture {
    private import ScalarValues::*;
    private import SessionBoundaryContracts::*;

    doc /* User direction, 2026-10-25: ai-agentic-context manages the whole
           Agent information context: content, interaction history and knowledge.
           Session remains an independent Module. This is an architecture model,
           not runtime classes, a second semantic authority or an API schema.
           Public implementation remains native POO values and pure functions. */

    part def Orgize {
        doc /* External owner of Org syntax, Elements and structural selection. */
    }
    part def Query {
        doc /* Unified POO Query with the selected GQL language and bounded
               result contracts. ORG Elements is Context Query's only content
               window; external artifacts are reached through admitted references,
               not a parallel filesystem/vector-store retrieval authority. */
    }
    part def Authority {
        doc /* External owner of grants and authority decisions. */
    }
    part def OriginalAscentProof {
        doc /* Existing temporal-causality/ascent-exchange and evaluator positive-
               proof/rule/derivation/proof-host owners bind source/event/Fact/rule,
               original ASCENT program replay, proof DAG/direct premises and
               registered proof/state/program/journal identities. Finite family
               lens classifications and positive proofs are distinct profiles;
               a possible hypothesis is not an authenticated original proof. */
    }
    part def SupportAndImpact {
        doc /* Existing truth-maintenance support/dependency owners and Impact
               refresh derive affected consumers from corrected/retracted premises.
               Complete negative/absence inventories have separate obligations.
               Keep original proof history while current applicability changes;
               unknown dependency coverage invalidates the whole affected scope. */
    }
    part def Temporal {
        part originalProof : OriginalAscentProof;
        part supportImpact : SupportAndImpact;
        doc /* Existing ASCENT-backed temporal-causality is the primary semantic
               foundation, not a timestamp helper. Compose causal cuts, declared
               inference profiles, original proofs, current registered owner
               applicability, support/retraction and Impact with time domains,
               leases and revisit obligations. Reuse native semantic owners. */
    }
    part def Evidence {
        doc /* External owner of assessment. Preserve competing hypotheses,
               evidence lineage, contradictions and open questions. */
    }
    part def Data {
        doc /* External owner of durable conditional storage and transactions. */
    }
    part def Content {
        doc /* ORG Elements/Contract anchor addressable content and revisions.
               Documents, observations, messages, tool results and external
               artifacts enter through source-qualified Element bindings/references.
               Non-Org adapters preserve actual identities; they do not introduce
               another public Context Query window or masquerade as Org receipts.
               Managing all information does not require ingesting it all. */
    }
    part def GraphContextComposition {
        doc /* Bounded versioned compositions of ORG-bound facts, hypotheses,
               goals, environments, outcomes and unresolved alternatives.
               Native POO / LeanPOO C3/C4 owns declared inheritance/override.
               Composition precedence, revision provenance and prompt ordering
               are distinct. Source, composition and consumer graphs are distinct.
               Project roots and Worktree/domain/task increments retain exact
               parent/source/Contract cuts; Sessions consume and contribute slices.
               Shared content never transfers another consumer's grants or reviews. */
    }
    part def ContextProjection {
        doc /* Purpose/scope-bound working input selected from the managed
               information space: demand, evidence envelope, restrictions,
               projection and use contracts. It is one product of the Context
               management system, not the definition of that entire system.
               Selection/composition is pure; use requires current owner checks.
               Inference-bearing inputs retain original proof/Derivation/premise,
               program/journal/profile and current support/owner bindings.
               Reasoning evidence, hypothetical fit and current authority differ. */
    }
    part def InteractionHistoryIntegration {
        doc /* Context owns selection, indexing and projection of admitted history
               for future use. Session owns canonical turns, interaction events,
               branch lineage and terminal outcomes. Retain exact source receipts;
               a summary or index never replaces the Session-owned event history. */
    }
    part def ShortTermKnowledge {
        doc /* Working observations and provisional/retained experience under a
               declared retention policy. Short-term is not synonymous with turn
               history, process memory, low confidence or an active Session. */
    }
    part def LongTermKnowledge {
        doc /* Retained reusable interpretations: mechanisms, constraints,
               procedures, decisions and failure patterns. A new versioned
               abstraction binds originating Contexts, actual uses/outcomes,
               counterexamples, assumptions and review/defeat conditions.
               Long-term is not merely text retained longer or a fixed use count;
               it never implies permanent truth, visibility or authority. */
    }
    part def Memory {
        part shortTerm : ShortTermKnowledge;
        part longTerm : LongTermKnowledge;
        doc /* Context-owned optional retention Feature spanning short- and
               long-term knowledge. Explicit consolidation proposes a new derived
               revision; age alone does not promote knowledge. Recall creates new
               Context candidates. Durable retention needs a selected Data adapter;
               scheduled revisit needs a qualified Temporal profile.
               Without retention, transient inputs and projections still exist. */
    }
    part def ContextCoordination {
        doc /* Overall composition owner: coordinate acquisition, history access,
               knowledge recall, projection, invalidation and recovery. Use the
               independent Session Module through its public contracts/adapters.
               Coordinate owners without taking over their semantics or grants. */
    }
    part def ContextModule {
        part coordination : ContextCoordination;
        part content : Content;
        part composition : GraphContextComposition;
        part projection : ContextProjection;
        part history : InteractionHistoryIntegration;
        part memory : Memory [0..1];
        dependency contentManagement from coordination to content;
        dependency graphManagement from coordination to composition;
        dependency inputConstruction from coordination to projection;
        dependency historyManagement from coordination to history;
        dependency knowledgeManagement from coordination to memory;
        dependency graphSources from composition to content;
        dependency selectedComposition from projection to composition;
        dependency historySources from history to content;
        dependency retainedSources from memory to content;
        dependency recallCandidates from projection to memory;
    }
    part def SessionModule {
        ref input : SessionInputRef [0..*];
        doc /* Independent Module: generic immutable input refs, turns, branches,
               handoff, cancellation and recovery. No import of Context or Memory
               implementation. Consuming a Context-produced value is a data
               binding through SessionInputRef, not a reverse Module dependency.
               Session/Task/Attempt/Turn are distinct units. Retry creates a fresh
               Attempt, not an implicit child Session; one Task may span Turns.
               Initial profile allows one active provider Turn per Session.
               A selected Module descriptor does not start an active Session. */
    }
    part def Host {
        doc /* Authenticate sources; coordinate current disclosure/consumption
               fences and explicit effect handoff. Pure orchestration produces
               intents; Host performs provider dispatch and owner publication.
               An observation of permission is not an atomic cross-owner fence. */
    }
    part def AgenticSystem {
        part contextModule : ContextModule;
        part sessionModule : SessionModule;
        part orgize : Orgize;
        part query : Query;
        part authority : Authority;
        part temporal : Temporal;
        part evidence : Evidence;
        part data : Data [0..1];
        part host : Host;

        dependency independentSessionComposition from contextModule::coordination to sessionModule;
        dependency canonicalInteractionHistory from contextModule::history to sessionModule;
        dependency contentGrammar from contextModule::content to orgize;
        dependency contentSelection from contextModule::projection to query;
        dependency useAuthority from contextModule::projection to authority;
        dependency proofAndTemporalApplicability from contextModule::projection to temporal;
        dependency evidenceDrivenComposition from contextModule::composition to temporal;
        dependency evidenceAssessment from contextModule::projection to evidence;
        dependency durableRetention from contextModule::memory to data;
        dependency revisitTime from contextModule::memory to temporal;
        dependency explicitEffects from contextModule::coordination to host;
        dependency consumptionFence from host to contextModule::projection;
        dependency interactionLifecycle from host to sessionModule;

        doc /* Dependencies here allocate responsibility, not all static imports.
               Static baseline: Context config imports Session descriptor; Session
               lifecycle contracts do not import Context implementation. Runtime
               adapters belong to Context. No additional upper manager is needed.
               Data/revisit dependencies apply to selected operations/profiles;
               no scheduler, durable store or active Session is implicitly started. */
    }

    requirement def OverallContextManagement {
        doc /* Coordinate all admitted Agent information categories, including
               content, interaction history and short-/long-term knowledge.
               Distinguish managed information from the selected model input. */
    }
    requirement def IndependentSessionOwnership {
        doc /* Context composes Session; Session independently owns interaction
               protocol, event lineage, revisions and terminal outcomes. */
    }
    requirement def ContextWithoutHistory {
        doc /* Construct/use Context without an active Session history or retained
               Memory. Disabling retention cannot disable mandatory use checks. */
    }
    requirement def RevisionQualifiedUse {
        doc /* Disclosure and consumption bind exact inputs and recheck current
               owners under a declared Host fence. Unknown currentness blocks use;
               historical replay never grants another disclosure or effect. */
    }
    requirement def KnowledgeRetentionIsNotTruth {
        doc /* Short-/long-term retention is independent of evidence assessment,
               revisit status, visibility and authorization. Consolidation retains
               uncertainty, conflicting inputs and source lineage. */
    }
    requirement def DistinctGraphRelations {
        doc /* Preserve source, composition and consumer relation roles; do not
               infer inheritance from Org/Git containment or prompt order.
               Only the declared inheritance subgraph obeys linearization rules. */
    }
    requirement def ExplicitSourcePromotion {
        doc /* Writing retained experience into Org is an authorized mutation
               using an expected revision and a new parse/query cycle.
               Long-term classification alone does not edit any source. */
    }

    part discussionSystem : AgenticSystem;
    requirement overallManagement : OverallContextManagement;
    requirement independentSession : IndependentSessionOwnership;
    requirement standaloneContext : ContextWithoutHistory;
    requirement currentUse : RevisionQualifiedUse;
    requirement knowledgeRetention : KnowledgeRetentionIsNotTruth;
    requirement sourcePromotion : ExplicitSourcePromotion;
    requirement graphRelations : DistinctGraphRelations;

    dependency graphObligation from discussionSystem::contextModule::composition to graphRelations;
    dependency overallObligation from discussionSystem::contextModule to overallManagement;
    dependency sessionObligation from discussionSystem::sessionModule to independentSession;
    dependency coreObligation from discussionSystem::contextModule to standaloneContext;
    dependency hostObligation from discussionSystem::host to currentUse;
    dependency memoryObligation from discussionSystem::contextModule::memory to knowledgeRetention;
    dependency promotionObligation from discussionSystem::contextModule::memory to sourcePromotion;

    doc /* Requirements allocate obligations, not satisfaction assertions.
           SysML acceptance is separate from requirement satisfaction and native
           correspondence. Existing Quint and Lean owners remain authoritative
           for their selected temporal questions and semantic laws. */
}
