-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Batteries.Data.List.Perm
import AgenticAILabProof.Enterprise.CompositionalEffectUniverse

namespace AgenticAILabProof.Enterprise.CompositionalFixedPointClosure

open CompositionalEffectUniverse
open EffectDomainCoverage
open PromotionTransactionAtomicity

abbrev FixedPointReceiptId := String
abbrev ProgressReceiptId := String
abbrev CycleObservationId := String
abbrev SemanticFingerprint := String
abbrev RemainingObligationsDigest := String
abbrev ContinuationIdentity := String

structure FixedPointClosureReceipt where
  receiptId : FixedPointReceiptId
  registryDigest : CompositionRegistryDigest
  roots : UseCompositionProfiles
  visited : List CompositionNodeId
  pending : List CompositionNodeId
  effectUniverse : EffectUniverse
  generation : Nat
  iterationCount : Nat
  stable : Bool
  deriving DecidableEq, Repr

def stableFieldsAccepted
    (receipt : FixedPointClosureReceipt) : Prop :=
  receipt.stable = true ∧
    receipt.pending = []

def visitedLinkClosed
    (registry : CompositionRegistry)
    (receipt : FixedPointClosureReceipt) : Prop :=
  ∀ source,
    source ∈ receipt.visited →
      ∀ target,
        compositionLink registry source target →
          target ∈ receipt.visited

def rootsVisited
    (roots : UseCompositionProfiles)
    (receipt : FixedPointClosureReceipt) : Prop :=
  ∀ root,
    root ∈ roots →
      root ∈ receipt.visited

def visitedIsMinimal
    (registry : CompositionRegistry)
    (roots : UseCompositionProfiles)
    (receipt : FixedPointClosureReceipt) : Prop :=
  ∀ nodeId,
    nodeId ∈ receipt.visited →
      Reachable registry roots nodeId

def fakeStableRootReceipt : FixedPointClosureReceipt where
  receiptId := "fake-stable-root-only"
  registryDigest := "sha256:composition-registry"
  roots := useCompositionProfiles
  visited := useCompositionProfiles
  pending := []
  effectUniverse := ["runtime", "knowledge-read"]
  generation := 1
  iterationCount := 1
  stable := true

theorem stableFlagAndEmptyPendingDoNotProveLinkClosure :
    stableFieldsAccepted fakeStableRootReceipt ∧
      ¬ visitedLinkClosed
        compositionRegistry
        fakeStableRootReceipt := by
  constructor
  · simp [stableFieldsAccepted, fakeStableRootReceipt]
  · intro linkClosed
    have workflowVisited :=
      linkClosed
        "production-profile"
        (by
          simp [
            fakeStableRootReceipt,
            useCompositionProfiles
          ])
        "notification-workflow"
        (by
          refine
            ⟨productionProfile,
              by simp [compositionRegistry],
              rfl,
              ?_⟩
          simp [productionProfile])
    simp [
      fakeStableRootReceipt,
      useCompositionProfiles
    ] at workflowVisited

def compositionClosedCandidate
    (registry : CompositionRegistry)
    (roots : UseCompositionProfiles)
    (candidate : CompositionNodeId → Prop) : Prop :=
  (∀ root, root ∈ roots → candidate root) ∧
    (∀ source target,
      candidate source →
        compositionLink registry source target →
          candidate target)

theorem closedCandidateNeedNotBeLeast :
    compositionClosedCandidate
        []
        []
        (fun _nodeId => True) ∧
      (fun _nodeId : CompositionNodeId => True) "orphan" ∧
      ¬ Reachable [] [] "orphan" := by
  constructor
  · constructor
    · simp
    · intro source target sourceInCandidate link
      trivial
  · constructor
    · trivial
    · intro reachable
      cases reachable with
      | root rootInEmpty =>
          simp at rootInEmpty
      | step sourceReachable link =>
          rcases link with
            ⟨object, objectInEmpty, objectIdentity, targetInLinks⟩
          simp at objectInEmpty

def registeredNodeIds
    (registry : CompositionRegistry) :
    List CompositionNodeId :=
  registry.map CompositionObject.identity

def visitedRegistered
    (registry : CompositionRegistry)
    (receipt : FixedPointClosureReceipt) : Prop :=
  ∀ nodeId,
    nodeId ∈ receipt.visited →
      nodeId ∈ registeredNodeIds registry

def unregisteredRootReceipt : FixedPointClosureReceipt where
  receiptId := "unregistered-root"
  registryDigest := "sha256:empty-registry"
  roots := ["ghost-profile"]
  visited := ["ghost-profile"]
  pending := []
  effectUniverse := []
  generation := 1
  iterationCount := 1
  stable := true

theorem rootLinkMinimalityDoNotProveVisitedRegistration :
    rootsVisited ["ghost-profile"] unregisteredRootReceipt ∧
      visitedLinkClosed [] unregisteredRootReceipt ∧
      visitedIsMinimal
        []
        ["ghost-profile"]
        unregisteredRootReceipt ∧
      ¬ visitedRegistered [] unregisteredRootReceipt := by
  constructor
  · intro root rootInRoots
    simpa [unregisteredRootReceipt] using rootInRoots
  · constructor
    · intro source sourceVisited target link
      rcases link with
        ⟨object, objectInRegistry, objectIdentity, targetInLinks⟩
      simp at objectInRegistry
    · constructor
      · intro nodeId nodeVisited
        have nodeIsGhost : nodeId = "ghost-profile" := by
          simpa [unregisteredRootReceipt] using nodeVisited
        subst nodeId
        exact .root (by simp)
      · intro registered
        have ghostRegistered :=
          registered "ghost-profile" (by
            simp [unregisteredRootReceipt])
        simp [registeredNodeIds] at ghostRegistered

structure FiniteWorklistState where
  visited : List CompositionNodeId
  pending : List CompositionNodeId
  generation : Nat
  semanticDiscoveries : Nat
  schedulingSteps : Nat
  deriving DecidableEq, Repr

def stateWithinRegistry
    (registry : CompositionRegistry)
    (state : FiniteWorklistState) : Prop :=
  state.visited.Subperm (registeredNodeIds registry)

def freshRegisteredDiscovery
    (registry : CompositionRegistry)
    (before after : FiniteWorklistState)
    (nodeId : CompositionNodeId) : Prop :=
  nodeId ∈ registeredNodeIds registry ∧
    nodeId ∉ before.visited ∧
    after.visited = nodeId :: before.visited ∧
    stateWithinRegistry registry after

theorem freshDiscoveryConsumesFiniteRegistryCapacity
    (registry : CompositionRegistry)
    (before after : FiniteWorklistState)
    (nodeId : CompositionNodeId)
    (_beforeWithin : stateWithinRegistry registry before)
    (fresh :
      freshRegisteredDiscovery registry before after nodeId) :
    before.visited.length < after.visited.length ∧
      after.visited.length ≤ (registeredNodeIds registry).length := by
  rcases fresh with
    ⟨_nodeRegistered, _nodeFresh, afterVisited, afterWithin⟩
  constructor
  · simp [afterVisited]
  · exact afterWithin.length_le

inductive BudgetOwner
  | semanticDiscovery
  | schedulingDispatch
  | runtimeWatchdog
  deriving DecidableEq, Repr

structure ScalarBudgetObservation where
  remaining : Nat
  exhaustedOwner : BudgetOwner
  deriving DecidableEq, Repr

def semanticBudgetExhaustion : ScalarBudgetObservation where
  remaining := 0
  exhaustedOwner := .semanticDiscovery

def schedulingBudgetExhaustion : ScalarBudgetObservation where
  remaining := 0
  exhaustedOwner := .schedulingDispatch

theorem oneScalarBudgetCannotIdentifyExhaustionOwner :
    semanticBudgetExhaustion.remaining =
        schedulingBudgetExhaustion.remaining ∧
      semanticBudgetExhaustion ≠
        schedulingBudgetExhaustion := by
  decide

inductive ProgressClass
  | converged
  | advancing
  | stalled
  | incomparable
  | regressing
  | oscillating
  | budgetExhausted
  deriving DecidableEq, Repr

structure ProgressReceipt where
  receiptId : ProgressReceiptId
  registryDigest : CompositionRegistryDigest
  generation : Nat
  classification : ProgressClass
  semanticFingerprint : SemanticFingerprint
  remainingObligationsDigest : RemainingObligationsDigest
  semanticBudgetRemaining : Nat
  schedulingBudgetRemaining : Nat
  watchdogObservationId : Option String
  deriving DecidableEq, Repr

structure CycleDetectedObservation where
  observationId : CycleObservationId
  registryDigest : CompositionRegistryDigest
  generation : Nat
  sccMembers : List CompositionNodeId
  causalPath : List CompositionNodeId
  provenanceDigest : String
  semanticBudgetConsumed : Nat
  schedulingBudgetConsumed : Nat
  continuationIdentity : ContinuationIdentity
  deriving DecidableEq, Repr

def FixedPointClosureReceiptValid :=
  FixedPointClosureReceipt → Prop

def ProgressReceiptValid :=
  ProgressReceipt → Prop

def CycleDetectedObservationValid :=
  CycleDetectedObservation → Prop

def RetryAuthority :=
  CycleDetectedObservation → Prop

def sampleCycleObservation : CycleDetectedObservation where
  observationId := "cycle-observation-a"
  registryDigest := "sha256:cyclic-composition-registry"
  generation := 3
  sccMembers := ["production-profile", "message-provider"]
  causalPath :=
    [
      "production-profile",
      "notification-workflow",
      "message-provider",
      "production-profile"
    ]
  provenanceDigest := "sha256:cycle-provenance"
  semanticBudgetConsumed := 2
  schedulingBudgetConsumed := 4
  continuationIdentity := "continuation-cycle-a"

theorem cycleObservationDoesNotAuthorizeRetry :
    sampleCycleObservation.continuationIdentity =
        "continuation-cycle-a" ∧
      ¬ (fun _observation : CycleDetectedObservation => False)
        sampleCycleObservation := by
  simp [sampleCycleObservation]

structure FixedPointEvidenceClosed
    (request : PromotionCommitRequest)
    (registryValid : CompositionRegistryValid)
    (witnessValid : CompositionalEffectWitnessValid)
    (closureValid : FixedPointClosureReceiptValid)
    (progressValid : ProgressReceiptValid)
    (cycleValid : CycleDetectedObservationValid)
    (registry : CompositionRegistry)
    (roots : UseCompositionProfiles)
    (witness : CompositionalEffectWitness)
    (receipt : FixedPointClosureReceipt)
    (progress : ProgressReceipt)
    (cycles : List CycleDetectedObservation) : Prop where
  witnessPlanMatchesRequest :
    witness.materializationPlanDigest =
      request.subject.materializationPlanDigest
  witnessRootsMatch : witness.roots = roots
  registryValidates :
    registryValid witness.registryDigest registry
  witnessValidates : witnessValid witness
  receiptValidates : closureValid receipt
  receiptRegistryMatches :
    receipt.registryDigest = witness.registryDigest
  receiptRootsMatch : receipt.roots = roots
  receiptUniverseMatches :
    receipt.effectUniverse = witness.effectUniverse
  receiptStable : receipt.stable = true
  receiptPendingEmpty : receipt.pending = []
  receiptContainsRoots : rootsVisited roots receipt
  receiptLinkClosed : visitedLinkClosed registry receipt
  receiptMinimal : visitedIsMinimal registry roots receipt
  receiptVisitedRegistered : visitedRegistered registry receipt
  progressValidates : progressValid progress
  progressRegistryMatches :
    progress.registryDigest = receipt.registryDigest
  progressGenerationMatches :
    progress.generation = receipt.generation
  everyCycleValid :
    ∀ observation ∈ cycles,
      cycleValid observation
  everyCycleRegistryMatches :
    ∀ observation ∈ cycles,
      observation.registryDigest = receipt.registryDigest
  everyCycleGenerationBound :
    ∀ observation ∈ cycles,
      observation.generation ≤ receipt.generation

theorem closedReceiptContainsEveryReachableNode
    (request : PromotionCommitRequest)
    (registryValid : CompositionRegistryValid)
    (witnessValid : CompositionalEffectWitnessValid)
    (closureValid : FixedPointClosureReceiptValid)
    (progressValid : ProgressReceiptValid)
    (cycleValid : CycleDetectedObservationValid)
    (registry : CompositionRegistry)
    (roots : UseCompositionProfiles)
    (witness : CompositionalEffectWitness)
    (receipt : FixedPointClosureReceipt)
    (progress : ProgressReceipt)
    (cycles : List CycleDetectedObservation)
    (closed :
      FixedPointEvidenceClosed
        request
        registryValid
        witnessValid
        closureValid
        progressValid
        cycleValid
        registry
        roots
        witness
        receipt
        progress
        cycles)
    (nodeId : CompositionNodeId)
    (reachable : Reachable registry roots nodeId) :
    nodeId ∈ receipt.visited := by
  induction reachable with
  | root rootInRoots =>
      exact closed.receiptContainsRoots _ rootInRoots
  | step sourceReachable link inductionHypothesis =>
      exact closed.receiptLinkClosed
        _
        inductionHypothesis
        _
        link

theorem closedReceiptIsLeastFixedPoint
    (request : PromotionCommitRequest)
    (registryValid : CompositionRegistryValid)
    (witnessValid : CompositionalEffectWitnessValid)
    (closureValid : FixedPointClosureReceiptValid)
    (progressValid : ProgressReceiptValid)
    (cycleValid : CycleDetectedObservationValid)
    (registry : CompositionRegistry)
    (roots : UseCompositionProfiles)
    (witness : CompositionalEffectWitness)
    (receipt : FixedPointClosureReceipt)
    (progress : ProgressReceipt)
    (cycles : List CycleDetectedObservation)
    (closed :
      FixedPointEvidenceClosed
        request
        registryValid
        witnessValid
        closureValid
        progressValid
        cycleValid
        registry
        roots
        witness
        receipt
        progress
        cycles)
    (nodeId : CompositionNodeId) :
    nodeId ∈ receipt.visited ↔
      Reachable registry roots nodeId := by
  constructor
  · exact closed.receiptMinimal nodeId
  · exact closedReceiptContainsEveryReachableNode
      request
      registryValid
      witnessValid
      closureValid
      progressValid
      cycleValid
      registry
      roots
      witness
      receipt
      progress
      cycles
      closed
      nodeId

def completeVisited : List CompositionNodeId :=
  [
    "base-profile",
    "wendao-episteme-mix",
    "production-profile",
    "knowledge-module",
    "notification-workflow",
    "message-provider"
  ]

def completeFixedPointReceipt : FixedPointClosureReceipt where
  receiptId := "fixed-point-complete"
  registryDigest := "sha256:composition-registry"
  roots := useCompositionProfiles
  visited := completeVisited
  pending := []
  effectUniverse := ["runtime", "knowledge-read", "external-message"]
  generation := 4
  iterationCount := 6
  stable := true

def convergedProgressReceipt : ProgressReceipt where
  receiptId := "progress-converged"
  registryDigest := "sha256:composition-registry"
  generation := 4
  classification := .converged
  semanticFingerprint := "sha256:semantic-fixed-point"
  remainingObligationsDigest := "sha256:no-obligations"
  semanticBudgetRemaining := 8
  schedulingBudgetRemaining := 32
  watchdogObservationId := none

theorem baseProfileReachable :
    Reachable
      compositionRegistry
      useCompositionProfiles
      "base-profile" :=
  .root (by simp [useCompositionProfiles])

theorem wendaoEpistemeMixReachable :
    Reachable
      compositionRegistry
      useCompositionProfiles
      "wendao-episteme-mix" :=
  .root (by simp [useCompositionProfiles])

theorem knowledgeModuleReachable :
    Reachable
      compositionRegistry
      useCompositionProfiles
      "knowledge-module" :=
  .step
    wendaoEpistemeMixReachable
    (by
      refine
        ⟨wendaoEpistemeMix,
          by simp [compositionRegistry],
          rfl,
          ?_⟩
      simp [wendaoEpistemeMix])

theorem completeFixedPointEvidenceCloses :
    FixedPointEvidenceClosed
      commitRequestA
      (fun _digest _registry => True)
      (fun _witness => True)
      (fun _receipt => True)
      (fun _progress => True)
      (fun _cycle => True)
      compositionRegistry
      useCompositionProfiles
      completeCompositionalEffectWitness
      completeFixedPointReceipt
      convergedProgressReceipt
      [] := by
  constructor
  · rfl
  · rfl
  · trivial
  · trivial
  · trivial
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · intro root rootInRoots
    simp [useCompositionProfiles] at rootInRoots
    rcases rootInRoots with rfl | rfl | rfl
    all_goals
      simp [
        completeFixedPointReceipt,
        completeVisited
      ]
  · intro source sourceVisited target link
    rcases link with
      ⟨object, objectInRegistry, objectIdentity, targetInLinks⟩
    simp [compositionRegistry] at objectInRegistry
    rcases objectInRegistry with
      rfl | rfl | rfl | rfl | rfl | rfl
    all_goals
      simp_all [
        completeFixedPointReceipt,
        completeVisited,
        baseProfile,
        wendaoEpistemeMix,
        productionProfile,
        knowledgeModule,
        notificationWorkflow,
        messageProvider
      ]
  · intro nodeId nodeVisited
    simp [
      completeFixedPointReceipt,
      completeVisited
    ] at nodeVisited
    rcases nodeVisited with
      rfl | rfl | rfl | rfl | rfl | rfl
    · exact baseProfileReachable
    · exact wendaoEpistemeMixReachable
    · exact productionProfileReachable
    · exact knowledgeModuleReachable
    · exact notificationWorkflowReachable
    · exact messageProviderReachable
  · intro nodeId nodeVisited
    simpa [
      completeFixedPointReceipt,
      completeVisited,
      registeredNodeIds,
      compositionRegistry,
      baseProfile,
      wendaoEpistemeMix,
      productionProfile,
      knowledgeModule,
      notificationWorkflow,
      messageProvider
    ] using nodeVisited
  · trivial
  · rfl
  · rfl
  · intro observation observationInEmpty
    simp at observationInEmpty
  · intro observation observationInEmpty
    simp at observationInEmpty
  · intro observation observationInEmpty
    simp at observationInEmpty

theorem matchingFixedPointFieldsDoNotProveOwnerValidity :
    stableFieldsAccepted completeFixedPointReceipt ∧
      ¬ (fun _receipt : FixedPointClosureReceipt => False)
        completeFixedPointReceipt := by
  simp [
    stableFieldsAccepted,
    completeFixedPointReceipt
  ]

end AgenticAILabProof.Enterprise.CompositionalFixedPointClosure
