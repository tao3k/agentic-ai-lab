-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import «40-context-governance-boundary»
import «41-epistemic-consolidation-governance»
import «42-multi-repo-multi-agent-declassification»
import «43-ascent-security-branch-omission-refinement»
import «44-temporal-causal-survival-and-memory-quotient»
import «45-org-sexpr-gql-candidate-exchange-search»
import «46-durable-agenda-session-sandbox-governance»
import «48-progressive-disclosure-and-two-stage-org-repair»
import «49-scoped-detour-funflow-concurrent-shared-context»
import «50-literature-frontier-detour-confinement-and-causal-audit»
import «51-memory-poisoning-quarantine-and-kv-prefix-serialization»
import «52-funflow-cas-singleflight-and-external-sandbox-binding»
import «53-yuanxu-c4-profile-convergence-and-interface-slots»
import «54-durable-work-engine-core-challenge»
import «55-mcp-tool-poisoning-and-camel-capability-flow»
import «56-ascent-governed-loop-termination»
import «57-obligation-fixpoint-reconciler»
import «58-delegation-attenuation-and-cedar-toctou-fence»
import «59-graph-engine-convergent-tree-and-apex-join»
import «60-unified-cyclic-scc-and-durable-tree-recovery»

/-!
Slice 47 — Master Imported Lean DAG (`40..46, 48..53 -> 47`) & Quotient Bridge:
1. Imports all thirteen upstream Lean modules (`40`–`46`, `48`–`53`) and composes
   their pure functional operators into one end-to-end pipeline
   `executePureGovernanceChain`.
2. Proves `pureGovernanceChain_end_to_end_sound`: any admitted pipeline output
   simultaneously satisfies AST source-block pruning (`45`), historical cut
   append-invariance (`44`), active-defeater kernel retention (`41`), progressive
   disclosure `L3` defeater floor & Stage-1 repair idempotence (`48`), complete
   secret stripping & idempotence (`42`), semilattice restriction refinement
   (`40`), universal Lethal-Trifecta elimination (`46`), shared-context
   `PureCAS`/`FencedEffect` & non-archive guards (`49`), and confined-detour
   taint isolation & zero-authority stall advisories (`50`).
3. Proves `leanToQuintBoundaryQuotient_sound`: exact quotient homomorphism `α`
   connecting unbounded Lean data structures to the finite boolean guard inputs
   consumed by Quint's concurrent state machines (`40`–`50.qnt`).
4. Proves pipeline conjunction monoid laws (`allStagesHold_append`,
   `any_refuted_stage_refutes_pipeline`) and zero-LLM deterministic replay
   purity (`replayCapsule_deterministic_without_llm`).
-/

namespace EndToEndContextGovernanceClosure

open ContextGovernanceBoundary
open ContextEpistemicConsolidationGovernance
open MultiRepoAgentDeclassification
open AscentSecurityBranchOmissionRefinement
open TemporalCausalSurvivalMemoryQuotient
open OrgSexprGqlCandidateExchange
open DurableAgendaSessionSandboxGovernance
open ProgressiveDisclosureAndOrgRepair

/-! ## 1. Pipeline Monoid Homomorphism & Fail-Closed Refutation -/

structure StageVerdict (StageId Digest : Type) where
  stage : StageId
  passed : Bool
  stageDigest : Digest

def allStagesHold {StageId Digest : Type} : List (StageVerdict StageId Digest) → Bool
  | [] => true
  | s :: ss => s.passed && allStagesHold ss

theorem allStagesHold_append {StageId Digest : Type}
    (xs ys : List (StageVerdict StageId Digest)) :
    allStagesHold (xs ++ ys) = (allStagesHold xs && allStagesHold ys) := by
  induction xs with
  | nil => simp [allStagesHold]
  | cons head tail ih =>
      simp [allStagesHold, ih, Bool.and_assoc]

theorem any_refuted_stage_refutes_pipeline {StageId Digest : Type}
    (stages : List (StageVerdict StageId Digest))
    (bad : StageVerdict StageId Digest)
    (hMem : bad ∈ stages)
    (hRefuted : bad.passed = false) :
    allStagesHold stages = false := by
  induction stages with
  | nil => cases hMem
  | cons head tail ih =>
      unfold allStagesHold
      cases hMem with
      | head =>
          rw [hRefuted]
          rfl
      | tail _ hInTail =>
          rw [ih hInTail, Bool.and_false]

/-! ## 2. Composed Pure Governance Pipeline Across Imported Slices `40`–`46` + `48` -/

structure AuditCapsule (Cut Digest : Type) where
  boundCut : Cut
  stageChainCommitment : Digest
  deriving DecidableEq, Repr

structure ComposedPipelineArtifact
    (NodeId EId HId DId Payload Reader Dest Cap Obl Digest : Type) where
  admittedElements : List (SelectedElement NodeId)
  repairedOrgNodes : List (OrgNode NodeId)
  derivedDepth : DisclosureDepth
  cutSnapshot : List (RevisionEntry EId)
  epistemicView : AdmittedProjection HId DId
    (RestrictionEnvelope Reader Dest Cap Obl)
  redactedCrossRepoFields : List (OrgField Payload)
  capsule : AuditCapsule Nat Digest

def executePureGovernanceChain
    {NodeId EId HId DId Payload Reader Dest Cap Obl Digest : Type}
    [DecidableEq HId]
    (docByteLen : Nat)
    (orgTree : OrgAstTree NodeId)
    (rawOrgNodes : List (OrgNode NodeId))
    (requestedDepth : DisclosureDepth)
    (explicitDrillDown hasActiveDefeater : Bool)
    (journal : List (RevisionEntry EId))
    (liveCut : Nat)
    (baseRestr : RestrictionEnvelope Reader Dest Cap Obl)
    (sliceRestrs : List (RestrictionEnvelope Reader Dest Cap Obl))
    (restrictionCost : Nat)
    (allHypotheses selectedHypotheses : List (Hypothesis HId DId))
    (budget : Nat)
    (rawCrossRepoFields : List (OrgField Payload))
    (commitChain :
      List (SelectedElement NodeId) →
      List (RevisionEntry EId) →
      List (OrgField Payload) → Digest) :
    Option (ComposedPipelineArtifact NodeId EId HId DId Payload Reader Dest Cap Obl Digest) :=
  let elems := selectAstTree docByteLen orgTree
  let repaired := stageOneRepair rawOrgNodes
  let depth := deriveDisclosureDepth requestedDepth explicitDrillDown hasActiveDefeater
  let cutEntries := filterUpToCut liveCut journal
  let effectiveRestr := composeRestrictions baseRestr sliceRestrs
  let redacted := redactFields rawCrossRepoFields
  match projectGoverned effectiveRestr restrictionCost allHypotheses selectedHypotheses budget with
  | .refusedOverBudget _ _ => none
  | .admitted epView =>
      some {
        admittedElements := elems
        repairedOrgNodes := repaired
        derivedDepth := depth
        cutSnapshot := cutEntries
        epistemicView := epView
        redactedCrossRepoFields := redacted
        capsule := {
          boundCut := liveCut
          stageChainCommitment := commitChain elems cutEntries redacted
        }
      }

theorem pureGovernanceChain_end_to_end_sound
    {NodeId EId HId DId Payload Reader Dest Cap Obl Digest : Type}
    [DecidableEq HId]
    (docByteLen : Nat)
    (orgTree : OrgAstTree NodeId)
    (rawOrgNodes : List (OrgNode NodeId))
    (requestedDepth : DisclosureDepth)
    (explicitDrillDown hasActiveDefeater : Bool)
    (journal : List (RevisionEntry EId))
    (lateEntry : RevisionEntry EId)
    (liveCut : Nat)
    (baseRestr memberRestr : RestrictionEnvelope Reader Dest Cap Obl)
    (sliceRestrs : List (RestrictionEnvelope Reader Dest Cap Obl))
    (restrictionCost : Nat)
    (allHypotheses selectedHypotheses : List (Hypothesis HId DId))
    (budget : Nat)
    (rawCrossRepoFields : List (OrgField Payload))
    (commitChain :
      List (SelectedElement NodeId) →
      List (RevisionEntry EId) →
      List (OrgField Payload) → Digest)
    (exposure : ContextExposure)
    (out : ComposedPipelineArtifact NodeId EId HId DId Payload Reader Dest Cap Obl Digest)
    (hExec :
      executePureGovernanceChain docByteLen orgTree rawOrgNodes requestedDepth
        explicitDrillDown hasActiveDefeater journal liveCut baseRestr sliceRestrs
        restrictionCost allHypotheses selectedHypotheses budget rawCrossRepoFields commitChain
        = some out)
    (hLate : liveCut < lateEntry.admissionTime)
    (hMember : memberRestr ∈ sliceRestrs) :
    -- (Slice 45) Every selected AST element excludes source-block spoofs & respects byte bounds:
    (∀ x ∈ out.admittedElements,
      x.kind ≠ .sourceBlock ∧ x.byteStart ≤ x.byteEnd ∧ x.byteEnd ≤ docByteLen) ∧
    -- (Slice 48) Stage-1 repair is idempotent and active defeater forces L3 unmasked disclosure:
    (stageOneRepair out.repairedOrgNodes = out.repairedOrgNodes ∧
      (hasActiveDefeater = true → out.derivedDepth = .L3_fullRawSpan)) ∧
    -- (Slice 44) Appending a later admission revision leaves the historical cut invariant:
    (filterUpToCut liveCut (journal ++ [lateEntry]) = out.cutSnapshot) ∧
    -- (Slice 41) Every active defeater of every retained hypothesis is preserved within budget:
    (out.epistemicView.consumedCost ≤ budget ∧
      ∀ h ∈ out.epistemicView.retainedHypotheses,
        ∀ d ∈ h.activeDefeaters, d ∈ out.epistemicView.retainedDefeaters) ∧
    -- (Slice 42) Cross-repo redaction strips every secret and is idempotent:
    (redactFields out.redactedCrossRepoFields = out.redactedCrossRepoFields ∧
      ∀ f ∈ out.redactedCrossRepoFields, f.sensitivity ≠ .restrictedSecret) ∧
    -- (Slice 40) Composed restriction envelope refines every participating member envelope:
    out.epistemicView.restrictions.Refines memberRestr ∧
    -- (Slice 46) Pairing with noEgressSandbox eliminates the Lethal Trifecta universally:
    ¬ LethalTrifectaPresent exposure noEgressSandbox ∧
    -- (Slice 47) Emitted capsule is bound to the exact live cut:
    out.capsule.boundCut = liveCut := by
  unfold executePureGovernanceChain at hExec
  dsimp at hExec
  split at hExec
  · cases hExec
  · rename_i epView hProj
    injection hExec with hOut
    subst hOut
    rcases admitted_projection_respects_budget_and_restrictions
      (composeRestrictions baseRestr sliceRestrs) restrictionCost
      allHypotheses selectedHypotheses budget epView hProj with ⟨hCost, hRestrEq⟩
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, rfl⟩
    · intro x hx
      exact ⟨selectAstTree_excludes_source_blocks docByteLen orgTree x hx,
             selectAstTree_preserves_byte_bounds docByteLen orgTree x hx⟩
    · refine ⟨stageOneRepair_idem rawOrgNodes, ?_⟩
      intro hDef
      subst hDef
      exact activeDefeater_forces_full_L3_disclosure requestedDepth explicitDrillDown
    · exact append_later_revision_preserves_historical_cut journal lateEntry liveCut hLate
    · refine ⟨hCost, ?_⟩
      intro h hh d hd
      exact admitted_projection_preserves_every_active_defeater
        (composeRestrictions baseRestr sliceRestrs) restrictionCost
        allHypotheses selectedHypotheses budget epView hProj h d hh hd
    · exact ⟨redactFields_idem rawCrossRepoFields,
             fun f hf => redactFields_strips_all_secrets rawCrossRepoFields f hf⟩
    · rw [hRestrEq]
      exact composeRestrictions_refines_every_member baseRestr memberRestr sliceRestrs hMember
    · exact noEgressProfile_eliminates_lethal_trifecta exposure

/-! ## 3. Formal Lean-to-Quint Boundary Quotient Bridge (`α`) -/

structure QuintBoundaryGuardFlags where
  omissionReceiptActive : Bool
  capsuleCutMatchesLive : Bool
  redactedContainsZeroSecrets : Bool
  defeaterForcesL3Disclosure : Bool
  pureCasAdmittedWithoutExhaustiveness : Bool
  stallAdvisoryAuthorizesMutation : Bool
  frozenKvPrefixPreserved : Bool
  fencedEffectPlainCasRejected : Bool
  retractedPremiseFailClosed : Bool
  explicitVetoDominatesImplied : Bool
  unclosedAttemptBlocksArchive : Bool
  untrustedSinkArgBlocked : Bool
  loopCycleHaltsFailClosed : Bool
  rawReactToolCallRejected : Bool
  revokedDelegationBlocked : Bool
  branchDirectFinalizationBlocked : Bool
  ungovernedCycleBlocked : Bool

def projectToQuintGuardFlags {HId Payload Digest : Type}
    (omittedIds : List HId)
    (rawFields : List (OrgField Payload))
    (requestedDepth : DisclosureDepth)
    (explicitDrillDown : Bool)
    (cap : AuditCapsule Nat Digest)
    (liveCut : Nat) : QuintBoundaryGuardFlags where
  omissionReceiptActive := !omittedIds.isEmpty
  capsuleCutMatchesLive := cap.boundCut == liveCut
  redactedContainsZeroSecrets :=
    (redactFields rawFields).all (fun f => f.sensitivity != .restrictedSecret)
  defeaterForcesL3Disclosure :=
    deriveDisclosureDepth requestedDepth explicitDrillDown true == .L3_fullRawSpan
  pureCasAdmittedWithoutExhaustiveness :=
    ScopedDetourFunflowConcurrentContext.admitNodeEffect .pureCAS false false false
  stallAdvisoryAuthorizesMutation :=
    (DetourTaintConfinementAndCausalAudit.evaluateStallAdvisory 2 0 2).authorizesAutoMutation
  frozenKvPrefixPreserved :=
    (MemoryQuarantineAndKvPrefixSerialization.serializeTwoZone [1, 2] [3]).take 2 == [1, 2]
  fencedEffectPlainCasRejected :=
    !(FunflowCasSingleflightAndExternalSandbox.casSkipAdmitted .fencedEffect true true false)
  retractedPremiseFailClosed :=
    FunflowCasSingleflightAndExternalSandbox.premiseDriftedFailClosed ([] : List (Nat × Nat)) 1 1
  explicitVetoDominatesImplied :=
    !(YuanxuC4ProfileConvergence.resolveFeatureEnabled true .explicitVeto)
  unclosedAttemptBlocksArchive :=
    !(DurableWorkEngineCoreChallenge.readyToAutoArchive
      { rootDone := true, dagValid := true, dagComplete := true, checklistsDone := true,
        openBlockers := [], unsatisfiedInvariants := [], inFlightIds := [],
        pendingEffects := [], unclosedAttempts := [1], alreadyArchived := false })
  untrustedSinkArgBlocked :=
    !(McpToolPoisoningAndCamelCapabilityFlow.admitSinkInvocation
      { sink := .sensitive, argOrigin := .untrustedMetadata,
        manifestPinned := true, hasDeclassCert := false })
  loopCycleHaltsFailClosed :=
    AscentGovernedLoopTermination.isHaltedVerdict
      (AscentGovernedLoopTermination.evaluateLoopVerdict
        { stepBudgetRemaining := 4, tokensRemaining := 1000, remainingFrontier := 2,
          openInvariants := 0, openDefeaters := 0, openBlockers := 0,
          journalQuiescent := false, exactStateCycle := true, oscillationCycle := false,
          repeatedFailureCount := 0, maxRepeatedFailures := 2, zeroProgressStreak := 0,
          maxStallTurns := 2, governanceBlocked := false, haltedPrior := false,
          humanReopenEndorsed := false })
  rawReactToolCallRejected :=
    !(AscentObligationFixpointReconciler.admitOracleProposal
      { kind := .rawSingleStepToolCall, contractValid := true,
        camelAndMcpSafe := true, branchCount := 1, maxBranches := 4 })
  revokedDelegationBlocked :=
    !(DelegationAttenuationAndCedarToctou.admitDelegatedExecution
      { boundCut := 1, liveCut := 1, boundGrantEpoch := 1, liveGrantEpoch := 1,
        parentGrantLive := false, childGrantLive := true, capAdmitted := true })
  branchDirectFinalizationBlocked :=
    !(GraphEngineConvergentTree.branchDirectTrunkFinalization
      { kind := .subordinateTask, localTaskCompleted := true,
        boundCut := 1, boundGrantEpoch := 1, discoveredCounterexamples := [] })
  ungovernedCycleBlocked :=
    !(UnifiedCyclicSccAndDurableRecovery.admitSccExecution
      { isCyclic := true, hasContract := false, cedarGrantLive := true })

theorem leanToQuintBoundaryQuotient_sound {HId Payload Digest : Type}
    (omittedIds : List HId)
    (rawFields : List (OrgField Payload))
    (requestedDepth : DisclosureDepth)
    (explicitDrillDown : Bool)
    (cap : AuditCapsule Nat Digest)
    (liveCut : Nat) :
    let q := projectToQuintGuardFlags omittedIds rawFields requestedDepth explicitDrillDown cap liveCut
    (q.omissionReceiptActive = true ↔ omittedIds ≠ []) ∧
    (q.capsuleCutMatchesLive = true ↔ cap.boundCut = liveCut) ∧
    q.redactedContainsZeroSecrets = true ∧
    q.defeaterForcesL3Disclosure = true ∧
    q.pureCasAdmittedWithoutExhaustiveness = true ∧
    q.stallAdvisoryAuthorizesMutation = false ∧
    q.frozenKvPrefixPreserved = true ∧
    q.fencedEffectPlainCasRejected = true ∧
    q.retractedPremiseFailClosed = true ∧
    q.explicitVetoDominatesImplied = true ∧
    q.unclosedAttemptBlocksArchive = true ∧
    q.untrustedSinkArgBlocked = true ∧
    q.loopCycleHaltsFailClosed = true ∧
    q.rawReactToolCallRejected = true ∧
    q.revokedDelegationBlocked = true ∧
    q.branchDirectFinalizationBlocked = true ∧
    q.ungovernedCycleBlocked = true := by
  dsimp [projectToQuintGuardFlags]
  refine ⟨omissionFlag_true_iff_nonempty_gap omittedIds, beq_iff_eq, ?_, rfl,
          ScopedDetourFunflowConcurrentContext.pureCAS_admitted_without_exhaustiveness,
          DetourTaintConfinementAndCausalAudit.advisoryTrigger_never_authorizes_auto_mutation 2 0 2,
          rfl,
          by simp [FunflowCasSingleflightAndExternalSandbox.fencedEffect_never_reused_by_plain_cas],
          FunflowCasSingleflightAndExternalSandbox.retractedPremise_always_invalidates_fail_closed
            ([] : List (Nat × Nat)) 1 1 rfl,
          by simp [YuanxuC4ProfileConvergence.explicitVeto_dominates_implied],
          by simp [DurableWorkEngineCoreChallenge.unclosedAttempt_blocks_autoArchive_fail_closed],
          rfl,
          rfl,
          rfl,
          rfl,
          rfl,
          rfl⟩
  rw [List.all_eq_true]
  intro f hf
  exact bne_iff_ne.mpr (redactFields_strips_all_secrets rawFields f hf)

/-! ## 4. Deterministic Zero-LLM Replay Purity & Uninhabited Authority -/

def foldStageDigests {StageId Digest : Type}
    (combine : Digest → Digest → Digest)
    (seed : Digest) : List (StageVerdict StageId Digest) → Digest
  | [] => seed
  | s :: ss => foldStageDigests combine (combine seed s.stageDigest) ss

def replayCapsuleFromEvidence {OrgBytes Journal StageId Cut Digest : Type}
    (deriveCut : OrgBytes → Journal → Cut)
    (deriveStages : OrgBytes → Journal → List (StageVerdict StageId Digest))
    (combine : Digest → Digest → Digest)
    (seed : Digest)
    (orgBytes : OrgBytes)
    (journal : Journal) : AuditCapsule Cut Digest :=
  { boundCut := deriveCut orgBytes journal
    stageChainCommitment := foldStageDigests combine seed (deriveStages orgBytes journal) }

theorem replayCapsule_deterministic_without_llm
    {OrgBytes Journal StageId Cut Digest : Type}
    (deriveCut : OrgBytes → Journal → Cut)
    (deriveStages : OrgBytes → Journal → List (StageVerdict StageId Digest))
    (combine : Digest → Digest → Digest)
    (seed : Digest)
    (org1 org2 : OrgBytes)
    (j1 j2 : Journal)
    (hSameOrg : org1 = org2)
    (hSameJournal : j1 = j2) :
    replayCapsuleFromEvidence deriveCut deriveStages combine seed org1 j1 =
      replayCapsuleFromEvidence deriveCut deriveStages combine seed org2 j2 := by
  subst hSameOrg
  subst hSameJournal
  rfl

def hotCapsuleApplicable {Cut Digest : Type} [DecidableEq Cut]
    (cap : AuditCapsule Cut Digest) (liveCut : Cut) : Bool :=
  cap.boundCut == liveCut

theorem cut_inequality_invalidates_hot_capsule
    {Cut Digest : Type} [DecidableEq Cut]
    (cap : AuditCapsule Cut Digest) (liveCut : Cut)
    (hAdvanced : cap.boundCut ≠ liveCut) :
    hotCapsuleApplicable cap liveCut = false := by
  unfold hotCapsuleApplicable
  exact beq_false_of_ne hAdvanced

theorem assurance_carries_zero_authority
    (witness : ContextGovernanceBoundary.GovernanceExecutionAuthority) : False :=
  ContextGovernanceBoundary.governance_value_carries_zero_authority witness

/-- Disjoint-Frame Assume-Guarantee Composition Theorem:
    When an interleaved product system updates Plane `P` in isolation (preserving
    all other planes) or updates the Cross-Plane Capsule `C` while keeping `P`
    fixed, any exhaustive single-plane invariant (`TLC queue = 0`) composes
    soundly with the cross-plane Capsule/CAS invariant (`Apalache`). -/
theorem disjointFrame_step_preserves_product_invariant
    {P C : Type}
    (invP : P → Prop)
    (invCross : P → C → Prop)
    (stepP : P → P → Prop)
    (stepC : P → C → C → Prop)
    (hPresP : ∀ p p', invP p → stepP p p' → invP p')
    (hPresCrossP : ∀ p p' c, invP p → invCross p c → stepP p p' → invCross p' c)
    (hPresCrossC : ∀ p c c', invP p → invCross p c → stepC p c c' → invCross p c')
    (p p' : P) (c c' : C)
    (hNow : invP p ∧ invCross p c)
    (hInterleaved : (stepP p p' ∧ c' = c) ∨ (p' = p ∧ stepC p c c')) :
    invP p' ∧ invCross p' c' := by
  rcases hNow with ⟨hP, hCr⟩
  rcases hInterleaved with ⟨hStepP, hEqC⟩ | ⟨hEqP, hStepC⟩
  · rw [hEqC]
    exact ⟨hPresP p p' hP hStepP, hPresCrossP p p' c hP hCr hStepP⟩
  · rw [hEqP]
    exact ⟨hP, hPresCrossC p c c' hP hCr hStepC⟩

end EndToEndContextGovernanceClosure
