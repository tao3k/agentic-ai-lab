// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package OrgContextModules {
    private import ScalarValues::*;
    private import VerificationCases::*;

    // These types describe semantic roles, not a replacement runtime API.
    part def ModuleRevision { attribute identity : String; attribute revision : String; }
    part def ProjectView :> ModuleRevision;
    part def RepoView :> ModuleRevision;
    part def WorktreeView :> ModuleRevision;
    part def OrgView :> ModuleRevision;
    part def GitOpsFeature;
    part def GitOpsWorktreeFeature :> GitOpsFeature;
    part def GitOpsWorkFeature :> GitOpsFeature;
    part def GitOpsWorkTrunkFeature :> GitOpsFeature;
    part def WorktreeOrgContract {
        attribute family : String;
        attribute revision : String;
        attribute identity : String;
    }
    part def WorktreeContextFeature :> GitOpsWorktreeFeature {
        part orgContract : WorktreeOrgContract;
        doc /* Inherits the GitOps Worktree dependency and adds Task and Org
               declarations through the effective Context receiver. */
    }
    part def WorkContextFeature :> GitOpsWorkFeature;
    part def WorkTrunkContextFeature :> GitOpsWorkTrunkFeature {
        doc /* When enabled, refine the Worktree Org Contract family in the
               effective Context scope. */
    }
    part def GitOpsDependencyRevision {
        part feature : GitOpsFeature;
        attribute project : String;
        attribute identity : String;
        attribute revision : String;
    }
    part def Interface { attribute identity : String; attribute contractRevision : String; }
    part def SourceCut { attribute repository : String; attribute worktree : String; attribute observation : String; }
    part def OrgAnchorIdentity { attribute source : String; attribute anchor : String; }
    part def OrgAnchor :> OrgAnchorIdentity { attribute sourceRevision : String; }
    part def OrgElement {
        attribute qualifiedIdentity : String;
        attribute elementKind : String;
        attribute byteStart : Integer;
        attribute byteEnd : Integer;
    }
    part def OrgElementGraph {
        part source : SourceCut;
        attribute parserRevision : String;
        part elements : OrgElement[0..*];
        doc /* Orgize supplies Elements and their structural parent relations. */
    }
    part def OrgSearchWindow {
        part graph : OrgElementGraph;
        part rootAnchor : OrgAnchor;
        attribute queryRevision : String;
        attribute traversalBound : Integer;
        attribute resultBound : Integer;
        doc /* Bounded GQL window over descendant tables, paragraphs and
               links in one admitted Org cut. */
    }
    part def OrgLinkReceipt {
        part sourceAnchor : OrgAnchor;
        part link : OrgElement;
        attribute linkPath : String;
        part targetAnchor : OrgAnchor;
        attribute sourceDigest : String;
        attribute targetDigest : String;
        attribute sourceQueryReceipt : String;
        attribute targetQueryReceipt : String;
    }
    requirement rootContextSearchInOrgElements {
        doc /* Bind every projected Element to the admitted source revision and
               parser. For a bounded structural window, retain ancestry and
               source range. Resolve linked sources separately under their
               own read grants. Treat source blocks as evidence content. */
    }
    requirement admitCrossFileOrgLink {
        doc /* The Orgize query discovers link Elements in the admitted
               source window. Resolve its file field through the Worktree
               Module namespace.
               Require the pinned source and anchor, matching custom ID,
               current generation and independent target read grant. Bind
               both Query receipts in the Task batch. */
    }
    requirement admitOrgLinkLineage {
        doc /* Follow discovered links reachable from Task root anchors.
               Apply cross-file link admission at every hop. Reject a repeat
               of a qualified anchor on the active path. Allow paths to
               converge at the same admitted anchor and Query receipt.
               Retain the roots and every hop in the Task batch. Recheck
               every source cut and read grant before publishing or using
               the batch, including those of intermediate anchors. */
    }
    part def Derivation {
        part base : ModuleRevision;
        part successor : ModuleRevision;
        doc /* A versioned base relation, distinct from access and invocation. */
    }
    part def ImportBinding {
        part importer : ModuleRevision;
        part provider : ModuleRevision;
        part offered : Interface;
    }
    part def Invocation {
        part importedBinding : ImportBinding;
        part cut : SourceCut;
        attribute request : String;
        attribute authority : String;
        attribute implementationRevision : String;
        doc /* A request and a selected implementation do not themselves grant execution. */
    }
    part def Projection {
        attribute demand : String;
        attribute selectedRevisionClosure : String;
        attribute effectiveDefinitions : String;
        attribute renderedTokens : String;
        doc /* Demand closure and definition precedence precede serialization. */
    }
    part def TaskDemand {
        attribute task : String;
        attribute readScope : String;
        attribute requestedInterfaces : String[1..*];
        part worktree : WorktreeView;
    }
    part def DependencyRevision {
        attribute inputIdentity : String;
        attribute revision : String;
    }
    part def DemandDependencies {
        part selectionInputs : DependencyRevision[0..*];
        part actualReads : DependencyRevision[0..*];
        attribute complete : Boolean;
    }
    part def OrgModuleDemand {
        part selected : OrgAnchor;
        part pinnedOrigin : OrgAnchor[0..1];
        attribute queryRevision : String;
        attribute readGrantEpoch : String;
    }
    part def WorktreeModuleResolution {
        part worktree : WorktreeView;
        part contextFeature : WorktreeContextFeature;
        part task : TaskDemand;
        attribute requestedOrgRoots : String[1..32];
        attribute selectedModuleGeneration : String;
        attribute declarationSourceDigests : String[1..32];
        part selectedGitOpsDependencies : GitOpsDependencyRevision[0..2];
        doc /* Yuanxu resolves the Task's roots and the original dependencies
               declared by the selected Org Elements. */
    }
    part def ResolvedDemand {
        part demand : TaskDemand;
        part moduleResolution : WorktreeModuleResolution[0..1];
        part parentCuts : ModuleRevision[1..*];
        part source : SourceCut;
        part router : ModuleRevision;
        part orgModules : OrgModuleDemand[1..32];
        part search : ImportBinding;
        attribute implementationRevision : String;
        part selectionInputs : DependencyRevision[0..*];
        doc /* GQL defines selection and projection over source-qualified
               Org Elements. Search coordinates the request and observation. */
    }
    part def ProjectionEvaluation {
        part selection : ResolvedDemand;
        attribute request : String;
    }
    part def OrgQueryReceipt {
        part selected : OrgModuleDemand;
        part observedSource : SourceCut;
        attribute queryReceipt : String;
        attribute originalAnchorReceipt : String[0..1];
    }
    part def ProjectionReceipt {
        part evaluation : ProjectionEvaluation;
        part orgQueries : OrgQueryReceipt[1..32];
        part orgLinkRoots : OrgAnchorIdentity[0..32];
        part orgLinks : OrgLinkReceipt[0..32];
        part observedInterface : Interface;
        attribute observedImplementationRevision : String;
        part dependencies : DemandDependencies;
        attribute providerEvidence : String;
    }
    part def TaskPublication {
        part receipt : ProjectionReceipt;
        part result : Projection;
    }
    requirement captureEffectiveDemand {
        doc /* Resolve the Task and its read scope to one Worktree cut, qualified
               Org anchors, effective Router, Search binding, query and Contract.
               A conflict blocks evaluation. Check read authority before access. */
    }
    requirement resolveWorktreeModules {
        doc /* Demand only the Org roots selected by the Task and their
               declared original dependencies. Verify the pinned source
               and anchor when following a Module name. Check the loader's
               current generation and the selected declaration sources at
               issuance, publication and use. */
    }
    requirement selectWorktreeOrgContract {
        doc /* Scheme derives the Contract identity and revision through the
               effective Worktree and WorkTrunk features. The selected
               worktree.org root drawer must identify that same Contract.
               Orgize owns the file-local Scheme Contract assertions. */
    }
    requirement refreshWorktreeAtTaskStart {
        doc /* The existing Task entry re-resolves a stale selection through
               the current GitOps Worktree dependency and inherited Context
               declarations. Demand only the effective roots and selected
               dependencies. Reuse Org declarations with unchanged source
               identities and digests. */
    }
    requirement checkSelectedGitOpsDependencies {
        doc /* A Task may select Work and WorkTrunk independently. An effective
               dependency contributes its Org roots and version. Check selected
               versions at issuance, publication and use. A changed unselected
               dependency leaves the current Task projection eligible. */
    }
    requirement supersedeStaleEvaluation {
        doc /* Once a current selection is available, a stale evaluation
               releases the active request. Retain the receipt binding only
               for evaluations with an issued Query receipt. A matching late
               delivery settles once in history and preserves both the newer
               pending request and the current publication. */
    }
    requirement compareBeforePublish {
        doc /* Bind a returned receipt to its pending evaluation and compare
               that evaluation to the live resolution and active read grant
               when publishing. A mismatched request or scope leaves pending
               work and the previous publication intact. */
    }
    requirement bindDerivedOrigin {
        doc /* Resolve both anchors through their own Org Element spaces.
               The selected original must match source identity, generation
               and anchor and supply a receipt in the same evaluation. */
    }
    requirement admitCompleteOrgProjection {
        doc /* Publish the ordered group of selected Org Query receipts
               as a unit. The Search observation binds the full group and
               every pinned origin to one Worktree evaluation. */
    }
    requirement preserveIndependentProjection {
        doc /* An unrelated declaration may leave a projection current when
               the read cuts, selection inputs and effective definitions are
               unchanged and the dependency receipt is complete. */
    }
    requirement withdrawCurrentUse {
        doc /* Compare captured and live inputs at final use. Preserve the
               historical publication after a selected source, origin pin
               or grant changes. A revised original requires an explicit
               new pin and a new evaluation. */
    }
    part def Example {
        part project : ProjectView;
        part repo : RepoView;
        part worktree : WorktreeView;
        part original : OrgView;
        part findings : OrgView;
        part origin : OrgAnchor;
        part router : ModuleRevision;
        part search : ModuleRevision;
        part projection : Projection;
        connection projectIncludesRepo connect project to repo;
        connection worktreeDerivedFromRepo connect repo to worktree;
        connection containsOriginal connect worktree to original;
        connection containsFindings connect worktree to findings;
        connection findingsReferencesAnchor connect findings to origin;
        connection routerAvailable connect worktree to router;
        connection searchAvailable connect worktree to search;
        connection taskProjection connect worktree to projection;
    }
    part fixture : Example;

    // Bounded truth-table contract, not a model of the actual runtime or tokenizer.
    verification def AdmissionAndReuse {
        subject target : Example default = fixture;
        in imported : Boolean;
        in sourceCurrent : Boolean;
        in authorized : Boolean;
        in sameTokens : Boolean;
        in cacheCompatible : Boolean;
        in mode : Integer; // 0 guarded; 1 import alone; 2 token equality alone
        attribute invoked : Boolean := false;
        attribute reused : Boolean := false;
        first start then evaluateCase;
        action evaluateCase {
            assign invoked := imported and (mode == 1 or (sourceCurrent and authorized));
            assign reused := sameTokens and (mode == 2 or (cacheCompatible and authorized));
        }
        then done;
        return verdict : VerdictKind = PassIf((not invoked or (imported and sourceCurrent and authorized))
            and (not reused or (sameTokens and cacheCompatible and authorized)));
    }
}
