-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.BundleEvidenceBinding
import AgenticAILabProof.Enterprise.CompositionalEffectUniverse

namespace AgenticAILabProof.Enterprise.SourceBoundCompositionalEffectClosure

open BundleOwnership
open BundleEvidenceBinding
open CompositionalEffectUniverse
open EffectDomainCoverage
open PromotionTransactionAtomicity

abbrev ObjectContentDigest := Digest
abbrev EffectContractDigest := Digest
abbrev SourceBoundEffectWitnessId := String
abbrev SourceBoundTraceReceiptId := String

structure CompositionObjectSubject where
  identity : CompositionNodeId
  packageId : PackageId
  revision : Revision
  sourceTreeDigest : Digest
  objectContentDigest : ObjectContentDigest
  effectContractDigest : EffectContractDigest
  deriving DecidableEq, Repr

structure SourceBoundCompositionObject where
  subject : CompositionObjectSubject
  kind : CompositionNodeKind
  imports : List CompositionObjectSubject
  capabilities : List CapabilityId
  profiles : List CompositionObjectSubject
  submodules : List CompositionObjectSubject
  workflows : List CompositionObjectSubject
  delegations : List CompositionObjectSubject
  localEffects : List EffectId
  deriving DecidableEq, Repr

abbrev SourceBoundCompositionRegistry :=
  List SourceBoundCompositionObject

abbrev SourceBoundUseCompositionProfiles :=
  List CompositionObjectSubject

def sourceBoundCompositionLink
    (registry : SourceBoundCompositionRegistry)
    (source target : CompositionObjectSubject) : Prop :=
  ∃ object ∈ registry,
    object.subject = source ∧
      (target ∈ object.imports ∨
        target ∈ object.profiles ∨
        target ∈ object.submodules ∨
        target ∈ object.workflows ∨
        target ∈ object.delegations)

inductive SourceBoundReachable
    (registry : SourceBoundCompositionRegistry)
    (roots : SourceBoundUseCompositionProfiles) :
    CompositionObjectSubject → Prop
  | root {subject} :
      subject ∈ roots →
        SourceBoundReachable registry roots subject
  | step {source target} :
      SourceBoundReachable registry roots source →
        sourceBoundCompositionLink registry source target →
        SourceBoundReachable registry roots target

def sourceBoundReachableDeclaredEffect
    (registry : SourceBoundCompositionRegistry)
    (roots : SourceBoundUseCompositionProfiles)
    (effectId : EffectId) : Prop :=
  ∃ object ∈ registry,
    SourceBoundReachable registry roots object.subject ∧
      effectId ∈ object.localEffects

def sameIdentityPaymentProvider : CompositionObject :=
  { messageProvider with
    localEffects := ["external-payment"] }

def sameIdentityRegistry : CompositionRegistry :=
  [messageProvider, sameIdentityPaymentProvider]

theorem identityOnlyTraceCanSwitchObjectBody :
    "external-payment" ∉ messageProvider.localEffects ∧
      traceRespectsComposition
        sameIdentityRegistry
        ["message-provider"]
        [undeclaredPaymentEvent] := by
  constructor
  · simp [messageProvider]
  · intro event eventInTrace
    have eventIsPayment : event = undeclaredPaymentEvent := by
      simpa using eventInTrace
    subst event
    constructor
    · exact .root (by simp [undeclaredPaymentEvent])
    · exact
        ⟨sameIdentityPaymentProvider,
          by simp [sameIdentityRegistry],
          by
            simp [
              sameIdentityPaymentProvider,
              messageProvider,
              undeclaredPaymentEvent
            ],
          by
            simp [
              sameIdentityPaymentProvider,
              messageProvider,
              undeclaredPaymentEvent
            ]⟩

def messageProviderSubjectA : CompositionObjectSubject where
  identity := "message-provider"
  packageId := "wendao-episteme"
  revision := "revision-a"
  sourceTreeDigest := "sha256:source-tree-a"
  objectContentDigest := "sha256:message-provider-a"
  effectContractDigest := "sha256:message-contract-a"

def messageProviderSubjectB : CompositionObjectSubject where
  identity := "message-provider"
  packageId := "wendao-episteme"
  revision := "revision-b"
  sourceTreeDigest := "sha256:source-tree-b"
  objectContentDigest := "sha256:message-provider-b"
  effectContractDigest := "sha256:message-contract-b"

def sourceBoundMessageProviderA : SourceBoundCompositionObject where
  subject := messageProviderSubjectA
  kind := .providerAsset
  imports := []
  capabilities := ["external-message"]
  profiles := []
  submodules := []
  workflows := []
  delegations := []
  localEffects := ["external-message"]

def sourceBoundMessageProviderB : SourceBoundCompositionObject where
  subject := messageProviderSubjectB
  kind := .providerAsset
  imports := []
  capabilities := ["external-payment"]
  profiles := []
  submodules := []
  workflows := []
  delegations := []
  localEffects := ["external-payment"]

def sameNameSourceBoundRegistry : SourceBoundCompositionRegistry :=
  [sourceBoundMessageProviderA, sourceBoundMessageProviderB]

def sourceBoundMessageRoots : SourceBoundUseCompositionProfiles :=
  [messageProviderSubjectA]

structure SourceBoundEffectExecutionEvent where
  ownerSubject : CompositionObjectSubject
  effectId : EffectId
  deriving DecidableEq, Repr

abbrev SourceBoundEffectExecutionTrace :=
  List SourceBoundEffectExecutionEvent

def sourceBoundTraceRespectsComposition
    (registry : SourceBoundCompositionRegistry)
    (roots : SourceBoundUseCompositionProfiles)
    (trace : SourceBoundEffectExecutionTrace) : Prop :=
  ∀ event ∈ trace,
    SourceBoundReachable registry roots event.ownerSubject ∧
      ∃ object ∈ registry,
        object.subject = event.ownerSubject ∧
          event.effectId ∈ object.localEffects

def wrongRevisionPaymentEvent : SourceBoundEffectExecutionEvent where
  ownerSubject := messageProviderSubjectA
  effectId := "external-payment"

theorem exactSourceBindingRejectsSameNameRevisionSwitch :
    ¬ sourceBoundTraceRespectsComposition
      sameNameSourceBoundRegistry
      sourceBoundMessageRoots
      [wrongRevisionPaymentEvent] := by
  intro traceValid
  have eventValid :=
    traceValid wrongRevisionPaymentEvent (by simp)
  rcases eventValid.2 with
    ⟨object, objectInRegistry, objectSubject, effectDeclared⟩
  simp [sameNameSourceBoundRegistry] at objectInRegistry
  rcases objectInRegistry with rfl | rfl
  · simp [
      sourceBoundMessageProviderA,
      wrongRevisionPaymentEvent
    ] at effectDeclared
  · simp [
      sourceBoundMessageProviderB,
      messageProviderSubjectA,
      messageProviderSubjectB,
      wrongRevisionPaymentEvent
    ] at objectSubject

def sourceClaimOf
    (subject : CompositionObjectSubject) :
    ResolvedSourceClaim where
  packageId := subject.packageId
  revision := subject.revision
  sourceTreeDigest := subject.sourceTreeDigest

def SourceBoundObjectBindingValid :=
  SourceBoundCompositionObject → Prop

def everyReachableObjectBindingValid
    (bindingValid : SourceBoundObjectBindingValid)
    (registry : SourceBoundCompositionRegistry)
    (roots : SourceBoundUseCompositionProfiles) : Prop :=
  ∀ object ∈ registry,
    SourceBoundReachable registry roots object.subject →
      bindingValid object

def SourceBoundRegistrySubjectsUnique
    (registry : SourceBoundCompositionRegistry) : Prop :=
  ∀ left ∈ registry,
    ∀ right ∈ registry,
      left.subject = right.subject →
        left = right

def reachableSourceReceiptsClosed
    (valid : ResolutionReceiptValid)
    (registry : SourceBoundCompositionRegistry)
    (roots : SourceBoundUseCompositionProfiles)
    (receipts : List ResolutionReceipt) : Prop :=
  ∀ object ∈ registry,
    SourceBoundReachable registry roots object.subject →
      ∃ receipt ∈ receipts,
        resolutionReceiptMatches (sourceClaimOf object.subject) receipt ∧
          valid receipt

theorem populatedSourceFieldsDoNotProveObjectBinding :
    ¬ everyReachableObjectBindingValid
      (fun _object => False)
      [sourceBoundMessageProviderA]
      sourceBoundMessageRoots := by
  intro bindingsValid
  exact
    bindingsValid
      sourceBoundMessageProviderA
      (by simp)
      (.root (by
        simp [
          sourceBoundMessageRoots,
          sourceBoundMessageProviderA
        ]))

structure SourceBoundCompositionalEffectWitness where
  witnessId : SourceBoundEffectWitnessId
  materializationPlanDigest : MaterializationPlanDigest
  registryDigest : CompositionRegistryDigest
  roots : SourceBoundUseCompositionProfiles
  effectUniverse : EffectUniverse
  deriving DecidableEq, Repr

structure SourceBoundCompositionRequestSubject where
  transactionId : TransactionId
  materializationPlanDigest : MaterializationPlanDigest
  deriving DecidableEq, Repr

def sourceBoundCompositionRequestSubjectOf
    (request : PromotionCommitRequest) :
    SourceBoundCompositionRequestSubject where
  transactionId := request.transactionId
  materializationPlanDigest :=
    request.subject.materializationPlanDigest

def sourceBoundCompositionRequestA :
    SourceBoundCompositionRequestSubject :=
  sourceBoundCompositionRequestSubjectOf commitRequestA

theorem sourceBoundCompositionRequestProjectionPreservesSubject :
    sourceBoundCompositionRequestA.transactionId =
        commitRequestA.transactionId ∧
      sourceBoundCompositionRequestA.materializationPlanDigest =
        commitRequestA.subject.materializationPlanDigest := by
  constructor <;> rfl

def SourceBoundCompositionRegistryValid :=
  CompositionRegistryDigest →
    SourceBoundCompositionRegistry →
      Prop

def SourceBoundCompositionalEffectWitnessValid :=
  SourceBoundCompositionalEffectWitness → Prop

structure SourceBoundEffectExecutionTraceReceipt where
  receiptId : SourceBoundTraceReceiptId
  transactionId : TransactionId
  fenceToken : Nat
  registryDigest : CompositionRegistryDigest
  events : SourceBoundEffectExecutionTrace
  deriving DecidableEq, Repr

def SourceBoundExecutionTraceOwnerValid :=
  SourceBoundEffectExecutionTraceReceipt → Prop

def sourceBoundWitnessCoversReachableEffects
    (registry : SourceBoundCompositionRegistry)
    (roots : SourceBoundUseCompositionProfiles)
    (witness : SourceBoundCompositionalEffectWitness) : Prop :=
  ∀ effectId,
    sourceBoundReachableDeclaredEffect registry roots effectId →
      effectId ∈ witness.effectUniverse

theorem sourceBoundEffectCoverageIsScaleParametric
    (registry : SourceBoundCompositionRegistry)
    (roots : SourceBoundUseCompositionProfiles)
    (witness : SourceBoundCompositionalEffectWitness)
    (trace : SourceBoundEffectExecutionTrace)
    (covers :
      sourceBoundWitnessCoversReachableEffects
        registry
        roots
        witness)
    (traceRespects :
      sourceBoundTraceRespectsComposition
        registry
        roots
        trace)
    (event : SourceBoundEffectExecutionEvent)
    (eventInTrace : event ∈ trace) :
    event.effectId ∈ witness.effectUniverse := by
  have eventValid := traceRespects event eventInTrace
  rcases eventValid.2 with
    ⟨object, objectInRegistry, objectSubject, effectIsLocal⟩
  apply covers
  exact
    ⟨object,
      objectInRegistry,
      objectSubject.symm ▸ eventValid.1,
      effectIsLocal⟩

structure SourceBoundEffectClosure
    (request : SourceBoundCompositionRequestSubject)
    (activeFenceToken : Nat)
    (registryValid : SourceBoundCompositionRegistryValid)
    (witnessValid : SourceBoundCompositionalEffectWitnessValid)
    (bindingValid : SourceBoundObjectBindingValid)
    (resolutionReceiptValid : ResolutionReceiptValid)
    (traceOwnerValid : SourceBoundExecutionTraceOwnerValid)
    (registry : SourceBoundCompositionRegistry)
    (roots : SourceBoundUseCompositionProfiles)
    (witness : SourceBoundCompositionalEffectWitness)
    (resolutionReceipts : List ResolutionReceipt)
    (traceReceipt : SourceBoundEffectExecutionTraceReceipt) : Prop where
  witnessPlanMatchesRequest :
    witness.materializationPlanDigest =
      request.materializationPlanDigest
  witnessRootsMatch : witness.roots = roots
  registryValidates :
    registryValid witness.registryDigest registry
  witnessValidates : witnessValid witness
  registrySubjectsUnique :
    SourceBoundRegistrySubjectsUnique registry
  everyReachableBindingValid :
    everyReachableObjectBindingValid bindingValid registry roots
  everyReachableSourceResolved :
    reachableSourceReceiptsClosed
      resolutionReceiptValid
      registry
      roots
      resolutionReceipts
  universeCoversReachableEffects :
    sourceBoundWitnessCoversReachableEffects registry roots witness
  traceTransactionMatches :
    traceReceipt.transactionId = request.transactionId
  traceFenceMatches :
    traceReceipt.fenceToken = activeFenceToken
  traceRegistryMatches :
    traceReceipt.registryDigest = witness.registryDigest
  traceOwnerValidates : traceOwnerValid traceReceipt
  traceRespectsExactDeclarations :
    sourceBoundTraceRespectsComposition
      registry
      roots
      traceReceipt.events

theorem closedSourceBoundCompositionCoversEveryRuntimeEvent
    (request : SourceBoundCompositionRequestSubject)
    (activeFenceToken : Nat)
    (registryValid : SourceBoundCompositionRegistryValid)
    (witnessValid : SourceBoundCompositionalEffectWitnessValid)
    (bindingValid : SourceBoundObjectBindingValid)
    (resolutionReceiptValid : ResolutionReceiptValid)
    (traceOwnerValid : SourceBoundExecutionTraceOwnerValid)
    (registry : SourceBoundCompositionRegistry)
    (roots : SourceBoundUseCompositionProfiles)
    (witness : SourceBoundCompositionalEffectWitness)
    (resolutionReceipts : List ResolutionReceipt)
    (traceReceipt : SourceBoundEffectExecutionTraceReceipt)
    (closed :
      SourceBoundEffectClosure
        request
        activeFenceToken
        registryValid
        witnessValid
        bindingValid
        resolutionReceiptValid
        traceOwnerValid
        registry
        roots
        witness
        resolutionReceipts
        traceReceipt)
    (event : SourceBoundEffectExecutionEvent)
    (eventInTrace : event ∈ traceReceipt.events) :
    event.effectId ∈ witness.effectUniverse := by
  exact
    sourceBoundEffectCoverageIsScaleParametric
      registry
      roots
      witness
      traceReceipt.events
      closed.universeCoversReachableEffects
      closed.traceRespectsExactDeclarations
      event
      eventInTrace

def sourceBoundRegistryA : SourceBoundCompositionRegistry :=
  [sourceBoundMessageProviderA]

def sourceBoundWitnessA : SourceBoundCompositionalEffectWitness where
  witnessId := "source-bound-effect-witness-a"
  materializationPlanDigest := "sha256:marlin-plan-a"
  registryDigest := "sha256:source-bound-registry-a"
  roots := sourceBoundMessageRoots
  effectUniverse := ["external-message"]

def sourceBoundExternalMessageEvent :
    SourceBoundEffectExecutionEvent where
  ownerSubject := messageProviderSubjectA
  effectId := "external-message"

def sourceBoundTraceReceiptA :
    SourceBoundEffectExecutionTraceReceipt where
  receiptId := "source-bound-trace-a"
  transactionId := "promotion-transaction-a"
  fenceToken := 8
  registryDigest := "sha256:source-bound-registry-a"
  events := [sourceBoundExternalMessageEvent]

def sourceBoundResolutionReceiptA : ResolutionReceipt where
  packageId := messageProviderSubjectA.packageId
  revision := messageProviderSubjectA.revision
  sourceTreeDigest := messageProviderSubjectA.sourceTreeDigest
  resolverId := "gerbil.pkg"
  resolverReceiptDigest := "sha256:gerbil-package-resolution-a"

theorem completeSourceBoundCompositionalEffectClosure :
    SourceBoundEffectClosure
      sourceBoundCompositionRequestA
      8
      (fun _digest _registry => True)
      (fun _witness => True)
      (fun _object => True)
      (fun _receipt => True)
      (fun _traceReceipt => True)
      sourceBoundRegistryA
      sourceBoundMessageRoots
      sourceBoundWitnessA
      [sourceBoundResolutionReceiptA]
      sourceBoundTraceReceiptA := by
  constructor
  · rfl
  · rfl
  · trivial
  · trivial
  · intro left leftInRegistry right rightInRegistry subjectsEqual
    simp [sourceBoundRegistryA] at leftInRegistry rightInRegistry
    subst left
    subst right
    rfl
  · intro object objectInRegistry objectReachable
    trivial
  · intro object objectInRegistry objectReachable
    simp [sourceBoundRegistryA] at objectInRegistry
    subst object
    exact
      ⟨sourceBoundResolutionReceiptA,
        by simp,
        by
          simp [
            resolutionReceiptMatches,
            sourceClaimOf,
            sourceBoundResolutionReceiptA,
            sourceBoundMessageProviderA,
            messageProviderSubjectA
          ]⟩
  · intro effectId reachableEffect
    rcases reachableEffect with
      ⟨object, objectInRegistry, objectReachable, effectIsLocal⟩
    simp [sourceBoundRegistryA] at objectInRegistry
    subst object
    simpa [
      sourceBoundMessageProviderA,
      sourceBoundWitnessA
    ] using effectIsLocal
  · rfl
  · rfl
  · rfl
  · trivial
  · intro event eventInTrace
    have eventIsExternalMessage :
        event = sourceBoundExternalMessageEvent := by
      simpa [sourceBoundTraceReceiptA] using eventInTrace
    subst event
    constructor
    · exact .root (by
        simp [
          sourceBoundMessageRoots,
          sourceBoundExternalMessageEvent
        ])
    · exact
        ⟨sourceBoundMessageProviderA,
          by simp [sourceBoundRegistryA],
          rfl,
          by
            simp [
              sourceBoundExternalMessageEvent,
              sourceBoundMessageProviderA
            ]⟩

end AgenticAILabProof.Enterprise.SourceBoundCompositionalEffectClosure
