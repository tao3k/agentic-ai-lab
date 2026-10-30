-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.EffectDomainCoverage

namespace AgenticAILabProof.Enterprise.CompositionalEffectUniverse

open PromotionTransactionAtomicity
open EffectDomainCoverage

abbrev CompositionNodeId := String
abbrev CapabilityId := String
abbrev CompositionRegistryDigest := String
abbrev CompositionalEffectWitnessId := String
abbrev ExecutionTraceReceiptId := String

inductive CompositionNodeKind
  | moduleAsset
  | profileAsset
  | workflowAsset
  | knowledgeAsset
  | policyAsset
  | authAsset
  | evidenceAsset
  | providerAsset
  deriving DecidableEq, Repr

structure CompositionObject where
  identity : CompositionNodeId
  kind : CompositionNodeKind
  imports : List CompositionNodeId
  capabilities : List CapabilityId
  profiles : List CompositionNodeId
  submodules : List CompositionNodeId
  workflows : List CompositionNodeId
  delegations : List CompositionNodeId
  localEffects : List EffectId
  deriving DecidableEq, Repr

abbrev CompositionRegistry := List CompositionObject
abbrev UseCompositionProfiles := List CompositionNodeId

def compositionLink
    (registry : CompositionRegistry)
    (source target : CompositionNodeId) : Prop :=
  ∃ object ∈ registry,
    object.identity = source ∧
      (target ∈ object.imports ∨
        target ∈ object.profiles ∨
        target ∈ object.submodules ∨
        target ∈ object.workflows ∨
        target ∈ object.delegations)

inductive Reachable
    (registry : CompositionRegistry)
    (roots : UseCompositionProfiles) :
    CompositionNodeId → Prop
  | root {nodeId} :
      nodeId ∈ roots →
        Reachable registry roots nodeId
  | step {source target} :
      Reachable registry roots source →
        compositionLink registry source target →
        Reachable registry roots target

def rootDeclaredEffect
    (registry : CompositionRegistry)
    (roots : UseCompositionProfiles)
    (effectId : EffectId) : Prop :=
  ∃ object ∈ registry,
    object.identity ∈ roots ∧
      effectId ∈ object.localEffects

def reachableDeclaredEffect
    (registry : CompositionRegistry)
    (roots : UseCompositionProfiles)
    (effectId : EffectId) : Prop :=
  ∃ object ∈ registry,
    Reachable registry roots object.identity ∧
      effectId ∈ object.localEffects

def baseProfile : CompositionObject where
  identity := "base-profile"
  kind := .profileAsset
  imports := []
  capabilities := ["runtime"]
  profiles := []
  submodules := []
  workflows := []
  delegations := []
  localEffects := ["runtime"]

def wendaoEpistemeMix : CompositionObject where
  identity := "wendao-episteme-mix"
  kind := .profileAsset
  imports := []
  capabilities := ["knowledge"]
  profiles := []
  submodules := ["knowledge-module"]
  workflows := []
  delegations := []
  localEffects := ["knowledge-read"]

def productionProfile : CompositionObject where
  identity := "production-profile"
  kind := .profileAsset
  imports := []
  capabilities := ["production"]
  profiles := []
  submodules := []
  workflows := ["notification-workflow"]
  delegations := []
  localEffects := []

def knowledgeModule : CompositionObject where
  identity := "knowledge-module"
  kind := .knowledgeAsset
  imports := []
  capabilities := ["knowledge"]
  profiles := []
  submodules := []
  workflows := []
  delegations := []
  localEffects := ["knowledge-read"]

def notificationWorkflow : CompositionObject where
  identity := "notification-workflow"
  kind := .workflowAsset
  imports := []
  capabilities := ["notify"]
  profiles := []
  submodules := []
  workflows := []
  delegations := ["message-provider"]
  localEffects := []

def messageProvider : CompositionObject where
  identity := "message-provider"
  kind := .providerAsset
  imports := []
  capabilities := ["external-message"]
  profiles := []
  submodules := []
  workflows := []
  delegations := []
  localEffects := ["external-message"]

def compositionRegistry : CompositionRegistry :=
  [
    baseProfile,
    wendaoEpistemeMix,
    productionProfile,
    knowledgeModule,
    notificationWorkflow,
    messageProvider
  ]

def useCompositionProfiles : UseCompositionProfiles :=
  [
    "base-profile",
    "wendao-episteme-mix",
    "production-profile"
  ]

theorem productionProfileReachable :
    Reachable
      compositionRegistry
      useCompositionProfiles
      "production-profile" :=
  .root (by simp [useCompositionProfiles])

theorem notificationWorkflowReachable :
    Reachable
      compositionRegistry
      useCompositionProfiles
      "notification-workflow" :=
  .step
    productionProfileReachable
    (by
      refine ⟨productionProfile, by simp [compositionRegistry], rfl, ?_⟩
      simp [productionProfile])

theorem messageProviderReachable :
    Reachable
      compositionRegistry
      useCompositionProfiles
      "message-provider" :=
  .step
    notificationWorkflowReachable
    (by
      refine
        ⟨notificationWorkflow,
          by simp [compositionRegistry],
          rfl,
          ?_⟩
      simp [notificationWorkflow])

theorem rootOnlySummaryMissesNestedDelegatedEffect :
    ¬ rootDeclaredEffect
        compositionRegistry
        useCompositionProfiles
        "external-message" ∧
      reachableDeclaredEffect
        compositionRegistry
        useCompositionProfiles
        "external-message" := by
  constructor
  · intro rootEffect
    rcases rootEffect with
      ⟨object, objectInRegistry, objectIsRoot, effectIsLocal⟩
    simp [compositionRegistry] at objectInRegistry
    rcases objectInRegistry with
      rfl | rfl | rfl | rfl | rfl | rfl
    all_goals
      simp [
        useCompositionProfiles,
        baseProfile,
        wendaoEpistemeMix,
        productionProfile,
        knowledgeModule,
        notificationWorkflow,
        messageProvider
      ] at objectIsRoot effectIsLocal
  · exact
      ⟨messageProvider,
        by simp [compositionRegistry],
        messageProviderReachable,
        by simp [messageProvider]⟩

theorem reachableMonotone
    (registry : CompositionRegistry)
    (smaller larger : UseCompositionProfiles)
    (rootsIncluded :
      ∀ nodeId, nodeId ∈ smaller → nodeId ∈ larger)
    (nodeId : CompositionNodeId)
    (reachable : Reachable registry smaller nodeId) :
    Reachable registry larger nodeId := by
  induction reachable with
  | root nodeInSmaller =>
      exact .root (rootsIncluded _ nodeInSmaller)
  | step sourceReachable link inductionHypothesis =>
      exact .step inductionHypothesis link

theorem reachableEffectsMonotoneUnderProfileAddition
    (registry : CompositionRegistry)
    (smaller larger : UseCompositionProfiles)
    (rootsIncluded :
      ∀ nodeId, nodeId ∈ smaller → nodeId ∈ larger)
    (effectId : EffectId)
    (declared :
      reachableDeclaredEffect registry smaller effectId) :
    reachableDeclaredEffect registry larger effectId := by
  rcases declared with
    ⟨object, objectInRegistry, objectReachable, localEffect⟩
  exact
    ⟨object,
      objectInRegistry,
      reachableMonotone
        registry
        smaller
        larger
        rootsIncluded
        object.identity
        objectReachable,
      localEffect⟩

def cyclicMessageProvider : CompositionObject :=
  { messageProvider with delegations := ["production-profile"] }

def cyclicCompositionRegistry : CompositionRegistry :=
  [
    baseProfile,
    wendaoEpistemeMix,
    productionProfile,
    knowledgeModule,
    notificationWorkflow,
    cyclicMessageProvider
  ]

theorem cyclicProductionProfileReachable :
    Reachable
      cyclicCompositionRegistry
      useCompositionProfiles
      "production-profile" :=
  .root (by simp [useCompositionProfiles])

theorem cyclicNotificationWorkflowReachable :
    Reachable
      cyclicCompositionRegistry
      useCompositionProfiles
      "notification-workflow" :=
  .step
    cyclicProductionProfileReachable
    (by
      refine
        ⟨productionProfile,
          by simp [cyclicCompositionRegistry],
          rfl,
          ?_⟩
      simp [productionProfile])

theorem cyclicMessageProviderReachable :
    Reachable
      cyclicCompositionRegistry
      useCompositionProfiles
      "message-provider" :=
  .step
    cyclicNotificationWorkflowReachable
    (by
      refine
        ⟨notificationWorkflow,
          by simp [cyclicCompositionRegistry],
          rfl,
          ?_⟩
      simp [notificationWorkflow])

theorem cyclicCompositionHasFiniteReachabilityProofs :
    Reachable
        cyclicCompositionRegistry
        useCompositionProfiles
        "message-provider" ∧
      Reachable
        cyclicCompositionRegistry
        useCompositionProfiles
        "production-profile" := by
  exact
    ⟨cyclicMessageProviderReachable,
      cyclicProductionProfileReachable⟩

structure EffectExecutionEvent where
  ownerNodeId : CompositionNodeId
  effectId : EffectId
  deriving DecidableEq, Repr

abbrev EffectExecutionTrace := List EffectExecutionEvent

structure EffectExecutionTraceReceipt where
  receiptId : ExecutionTraceReceiptId
  transactionId : TransactionId
  fenceToken : Nat
  registryDigest : CompositionRegistryDigest
  events : EffectExecutionTrace
  deriving DecidableEq, Repr

def traceRespectsComposition
    (registry : CompositionRegistry)
    (roots : UseCompositionProfiles)
    (trace : EffectExecutionTrace) : Prop :=
  ∀ event ∈ trace,
    Reachable registry roots event.ownerNodeId ∧
      ∃ object ∈ registry,
        object.identity = event.ownerNodeId ∧
          event.effectId ∈ object.localEffects

def externalMessageEvent : EffectExecutionEvent where
  ownerNodeId := "message-provider"
  effectId := "external-message"

def undeclaredPaymentEvent : EffectExecutionEvent where
  ownerNodeId := "message-provider"
  effectId := "external-payment"

theorem undeclaredDynamicEffectIsRejected :
    ¬ traceRespectsComposition
      compositionRegistry
      useCompositionProfiles
      [undeclaredPaymentEvent] := by
  intro traceValid
  have eventValid :=
    traceValid undeclaredPaymentEvent (by simp)
  rcases eventValid.2 with
    ⟨object, objectInRegistry, objectIdentity, effectDeclared⟩
  simp [compositionRegistry] at objectInRegistry
  rcases objectInRegistry with
    rfl | rfl | rfl | rfl | rfl | rfl
  all_goals
    simp [
      undeclaredPaymentEvent,
      baseProfile,
      wendaoEpistemeMix,
      productionProfile,
      knowledgeModule,
      notificationWorkflow,
      messageProvider
    ] at objectIdentity effectDeclared

structure CompositionalEffectWitness where
  witnessId : CompositionalEffectWitnessId
  materializationPlanDigest : MaterializationPlanDigest
  registryDigest : CompositionRegistryDigest
  roots : UseCompositionProfiles
  effectUniverse : EffectUniverse
  deriving DecidableEq, Repr

def CompositionRegistryValid :=
  CompositionRegistryDigest → CompositionRegistry → Prop

def CompositionalEffectWitnessValid :=
  CompositionalEffectWitness → Prop

def NodeEffectContractValid :=
  CompositionObject → Prop

def ExecutionTraceOwnerValid :=
  EffectExecutionTraceReceipt → Prop

def witnessCoversReachableEffects
    (registry : CompositionRegistry)
    (roots : UseCompositionProfiles)
    (witness : CompositionalEffectWitness) : Prop :=
  ∀ effectId,
    reachableDeclaredEffect registry roots effectId →
      effectId ∈ witness.effectUniverse

def rootOnlyEffectWitness : CompositionalEffectWitness where
  witnessId := "root-only-effect-witness"
  materializationPlanDigest := "sha256:marlin-plan-a"
  registryDigest := "sha256:composition-registry"
  roots := useCompositionProfiles
  effectUniverse := ["runtime", "knowledge-read"]

def sameProfilesDifferentRegistryWitness : CompositionalEffectWitness :=
  { rootOnlyEffectWitness with
    witnessId := "different-registry-witness"
    registryDigest := "sha256:different-composition-registry" }

theorem profilesAndEffectListDoNotIdentifyRegistrySnapshot :
    rootOnlyEffectWitness.roots =
        sameProfilesDifferentRegistryWitness.roots ∧
      rootOnlyEffectWitness.effectUniverse =
        sameProfilesDifferentRegistryWitness.effectUniverse ∧
      rootOnlyEffectWitness ≠ sameProfilesDifferentRegistryWitness := by
  constructor
  · rfl
  · constructor
    · rfl
    · decide

theorem populatedRootOnlyWitnessDoesNotCoverComposition :
    rootOnlyEffectWitness.roots = useCompositionProfiles ∧
      ¬ witnessCoversReachableEffects
        compositionRegistry
        useCompositionProfiles
        rootOnlyEffectWitness := by
  constructor
  · rfl
  · intro covers
    have externalMessageCovered :=
      covers
        "external-message"
        rootOnlySummaryMissesNestedDelegatedEffect.2
    simp [rootOnlyEffectWitness] at externalMessageCovered

theorem matchingCompositionalFieldsDoNotProveWitnessValidity :
    rootOnlyEffectWitness.materializationPlanDigest =
        commitRequestA.subject.materializationPlanDigest ∧
      rootOnlyEffectWitness.roots = useCompositionProfiles ∧
      ¬ (fun _witness : CompositionalEffectWitness => False)
        rootOnlyEffectWitness := by
  simp [
    rootOnlyEffectWitness,
    commitRequestA,
    admissionSubjectA
  ]

structure CompositionalEffectClosure
    (request : PromotionCommitRequest)
    (activeFenceToken : Nat)
    (registryValid : CompositionRegistryValid)
    (witnessValid : CompositionalEffectWitnessValid)
    (contractValid : NodeEffectContractValid)
    (traceOwnerValid : ExecutionTraceOwnerValid)
    (registry : CompositionRegistry)
    (roots : UseCompositionProfiles)
    (witness : CompositionalEffectWitness)
    (traceReceipt : EffectExecutionTraceReceipt) : Prop where
  witnessPlanMatchesRequest :
    witness.materializationPlanDigest =
      request.subject.materializationPlanDigest
  witnessRootsMatch : witness.roots = roots
  registryValidates :
    registryValid witness.registryDigest registry
  witnessValidates : witnessValid witness
  everyReachableContractValid :
    ∀ object,
      object ∈ registry →
        Reachable registry roots object.identity →
          contractValid object
  universeCoversReachableEffects :
    witnessCoversReachableEffects registry roots witness
  traceTransactionMatches :
    traceReceipt.transactionId = request.transactionId
  traceFenceMatches :
    traceReceipt.fenceToken = activeFenceToken
  traceRegistryMatches :
    traceReceipt.registryDigest = witness.registryDigest
  traceOwnerValidates : traceOwnerValid traceReceipt
  traceRespectsDeclarations :
    traceRespectsComposition registry roots traceReceipt.events

def completeCompositionalEffectWitness : CompositionalEffectWitness where
  witnessId := "complete-compositional-effect-witness"
  materializationPlanDigest := "sha256:marlin-plan-a"
  registryDigest := "sha256:composition-registry"
  roots := useCompositionProfiles
  effectUniverse := ["runtime", "knowledge-read", "external-message"]

def externalMessageTraceReceipt : EffectExecutionTraceReceipt where
  receiptId := "trace-external-message"
  transactionId := "promotion-transaction-a"
  fenceToken := 8
  registryDigest := "sha256:composition-registry"
  events := [externalMessageEvent]

theorem completeCompositionalEffectClosure :
    CompositionalEffectClosure
      commitRequestA
      8
      (fun _digest _registry => True)
      (fun _witness => True)
      (fun _object => True)
      (fun _traceReceipt => True)
      compositionRegistry
      useCompositionProfiles
      completeCompositionalEffectWitness
      externalMessageTraceReceipt := by
  constructor
  · rfl
  · rfl
  · trivial
  · trivial
  · intro object objectInRegistry objectReachable
    trivial
  · intro effectId declaredEffect
    rcases declaredEffect with
      ⟨object, objectInRegistry, objectReachable, effectIsLocal⟩
    simp [compositionRegistry] at objectInRegistry
    rcases objectInRegistry with
      rfl | rfl | rfl | rfl | rfl | rfl
    all_goals
      simp [
        baseProfile,
        wendaoEpistemeMix,
        productionProfile,
        knowledgeModule,
        notificationWorkflow,
        messageProvider
      ] at effectIsLocal
    all_goals
      simp [
        completeCompositionalEffectWitness,
        effectIsLocal
      ]
  · rfl
  · rfl
  · rfl
  · trivial
  · intro event eventInTrace
    have eventIsExternalMessage :
        event = externalMessageEvent := by
      simpa [externalMessageTraceReceipt] using eventInTrace
    rw [eventIsExternalMessage]
    constructor
    · exact messageProviderReachable
    · exact
        ⟨messageProvider,
          by simp [compositionRegistry],
          rfl,
          by simp [externalMessageEvent, messageProvider]⟩

theorem closedCompositionCoversEveryRuntimeEvent
    (request : PromotionCommitRequest)
    (activeFenceToken : Nat)
    (registryValid : CompositionRegistryValid)
    (witnessValid : CompositionalEffectWitnessValid)
    (contractValid : NodeEffectContractValid)
    (traceOwnerValid : ExecutionTraceOwnerValid)
    (registry : CompositionRegistry)
    (roots : UseCompositionProfiles)
    (witness : CompositionalEffectWitness)
    (traceReceipt : EffectExecutionTraceReceipt)
    (closed :
      CompositionalEffectClosure
        request
        activeFenceToken
        registryValid
        witnessValid
        contractValid
        traceOwnerValid
        registry
        roots
        witness
        traceReceipt)
    (event : EffectExecutionEvent)
    (eventInTrace : event ∈ traceReceipt.events) :
    event.effectId ∈ witness.effectUniverse := by
  have eventValid :=
    closed.traceRespectsDeclarations event eventInTrace
  rcases eventValid.2 with
    ⟨object, objectInRegistry, objectIdentity, effectIsLocal⟩
  apply closed.universeCoversReachableEffects
  exact
    ⟨object,
      objectInRegistry,
      objectIdentity.symm ▸ eventValid.1,
      effectIsLocal⟩

theorem matchingTraceFieldsDoNotProveTraceAuthority :
    externalMessageTraceReceipt.transactionId =
        commitRequestA.transactionId ∧
      externalMessageTraceReceipt.fenceToken = 8 ∧
      externalMessageTraceReceipt.registryDigest =
        completeCompositionalEffectWitness.registryDigest ∧
      ¬ (fun _receipt : EffectExecutionTraceReceipt => False)
        externalMessageTraceReceipt := by
  simp [
    externalMessageTraceReceipt,
    commitRequestA,
    completeCompositionalEffectWitness
  ]

end AgenticAILabProof.Enterprise.CompositionalEffectUniverse
