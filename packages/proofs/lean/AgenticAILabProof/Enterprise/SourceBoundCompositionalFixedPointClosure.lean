-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Batteries.Data.List.Perm
import AgenticAILabProof.Enterprise.CompositionalFixedPointClosure
import AgenticAILabProof.Enterprise.SourceBoundCompositionalEffectClosure

namespace AgenticAILabProof.Enterprise.SourceBoundCompositionalFixedPointClosure

open BundleEvidenceBinding
open CompositionalEffectUniverse
open CompositionalFixedPointClosure
open EffectDomainCoverage
open SourceBoundCompositionalEffectClosure

abbrev SourceBoundFixedPointReceiptId := String

structure SourceBoundFixedPointReceipt where
  receiptId : SourceBoundFixedPointReceiptId
  registryDigest : CompositionRegistryDigest
  roots : SourceBoundUseCompositionProfiles
  visited : List CompositionObjectSubject
  pending : List CompositionObjectSubject
  effectUniverse : EffectUniverse
  generation : Nat
  iterationCount : Nat
  stable : Bool
  deriving DecidableEq, Repr

def sourceBoundRootsVisited
    (roots : SourceBoundUseCompositionProfiles)
    (receipt : SourceBoundFixedPointReceipt) : Prop :=
  ∀ root,
    root ∈ roots →
      root ∈ receipt.visited

def sourceBoundVisitedLinkClosed
    (registry : SourceBoundCompositionRegistry)
    (receipt : SourceBoundFixedPointReceipt) : Prop :=
  ∀ source,
    source ∈ receipt.visited →
      ∀ target,
        sourceBoundCompositionLink registry source target →
          target ∈ receipt.visited

def sourceBoundVisitedIsMinimal
    (registry : SourceBoundCompositionRegistry)
    (roots : SourceBoundUseCompositionProfiles)
    (receipt : SourceBoundFixedPointReceipt) : Prop :=
  ∀ subject,
    subject ∈ receipt.visited →
      SourceBoundReachable registry roots subject

def registeredSubjects
    (registry : SourceBoundCompositionRegistry) :
    List CompositionObjectSubject :=
  registry.map SourceBoundCompositionObject.subject

def sourceBoundVisitedRegistered
    (registry : SourceBoundCompositionRegistry)
    (receipt : SourceBoundFixedPointReceipt) : Prop :=
  ∀ subject,
    subject ∈ receipt.visited →
      subject ∈ registeredSubjects registry

def sourceBoundVisitedBindingsValid
    (bindingValid : SourceBoundObjectBindingValid)
    (registry : SourceBoundCompositionRegistry)
    (receipt : SourceBoundFixedPointReceipt) : Prop :=
  ∀ object ∈ registry,
    object.subject ∈ receipt.visited →
      bindingValid object

def sourceBoundVisitedSourceReceiptsClosed
    (valid : ResolutionReceiptValid)
    (registry : SourceBoundCompositionRegistry)
    (receipt : SourceBoundFixedPointReceipt)
    (resolutionReceipts : List ResolutionReceipt) : Prop :=
  ∀ object ∈ registry,
    object.subject ∈ receipt.visited →
      ∃ resolutionReceipt ∈ resolutionReceipts,
        resolutionReceiptMatches
            (sourceClaimOf object.subject)
            resolutionReceipt ∧
          valid resolutionReceipt

def identityOnlySubjectReceipt : FixedPointClosureReceipt where
  receiptId := "identity-only-subject"
  registryDigest := "sha256:same-name-registry"
  roots := ["message-provider"]
  visited := ["message-provider"]
  pending := []
  effectUniverse := ["external-message"]
  generation := 1
  iterationCount := 1
  stable := true

def identityReceiptNamesSubject
    (receipt : FixedPointClosureReceipt)
    (subject : CompositionObjectSubject) : Prop :=
  subject.identity ∈ receipt.visited

theorem identityOnlyVisitedCannotDistinguishSourceRevision :
    messageProviderSubjectA ≠ messageProviderSubjectB ∧
      identityReceiptNamesSubject
        identityOnlySubjectReceipt
        messageProviderSubjectA ∧
      identityReceiptNamesSubject
        identityOnlySubjectReceipt
        messageProviderSubjectB := by
  constructor
  · decide
  · constructor <;>
      simp [
        identityReceiptNamesSubject,
        identityOnlySubjectReceipt,
        messageProviderSubjectA,
        messageProviderSubjectB
      ]

structure SourceBoundFiniteWorklistState where
  visited : List CompositionObjectSubject
  pending : List CompositionObjectSubject
  generation : Nat
  semanticDiscoveries : Nat
  schedulingSteps : Nat
  deriving DecidableEq, Repr

def sourceBoundStateWithinRegistry
    (registry : SourceBoundCompositionRegistry)
    (state : SourceBoundFiniteWorklistState) : Prop :=
  state.visited.Subperm (registeredSubjects registry)

def freshSourceBoundDiscovery
    (registry : SourceBoundCompositionRegistry)
    (before after : SourceBoundFiniteWorklistState)
    (subject : CompositionObjectSubject) : Prop :=
  subject ∈ registeredSubjects registry ∧
    subject ∉ before.visited ∧
    after.visited = subject :: before.visited ∧
    sourceBoundStateWithinRegistry registry after

theorem freshSourceBoundDiscoveryConsumesFiniteRegistryCapacity
    (registry : SourceBoundCompositionRegistry)
    (before after : SourceBoundFiniteWorklistState)
    (subject : CompositionObjectSubject)
    (_beforeWithin :
      sourceBoundStateWithinRegistry registry before)
    (fresh :
      freshSourceBoundDiscovery registry before after subject) :
    before.visited.length < after.visited.length ∧
      after.visited.length ≤ (registeredSubjects registry).length := by
  rcases fresh with
    ⟨_subjectRegistered, _subjectFresh, afterVisited, afterWithin⟩
  constructor
  · simp [afterVisited]
  · exact afterWithin.length_le

def beforeDiscoveringRevisionA : SourceBoundFiniteWorklistState where
  visited := [messageProviderSubjectB]
  pending := [messageProviderSubjectA]
  generation := 1
  semanticDiscoveries := 1
  schedulingSteps := 1

def afterDiscoveringRevisionA : SourceBoundFiniteWorklistState where
  visited := [messageProviderSubjectA, messageProviderSubjectB]
  pending := []
  generation := 1
  semanticDiscoveries := 2
  schedulingSteps := 2

theorem sameNameDifferentRevisionIsFreshSubjectDiscovery :
    messageProviderSubjectA.identity =
        messageProviderSubjectB.identity ∧
      freshSourceBoundDiscovery
        sameNameSourceBoundRegistry
        beforeDiscoveringRevisionA
        afterDiscoveringRevisionA
        messageProviderSubjectA := by
  constructor
  · rfl
  · constructor
    · simp [
        registeredSubjects,
        sameNameSourceBoundRegistry,
        sourceBoundMessageProviderA
      ]
    · constructor
      · simp [
          beforeDiscoveringRevisionA,
          messageProviderSubjectA,
          messageProviderSubjectB
        ]
      · constructor
        · rfl
        · change
            [messageProviderSubjectA, messageProviderSubjectB].Subperm
              [messageProviderSubjectA, messageProviderSubjectB]
          exact List.Subperm.refl _

def SourceBoundFixedPointReceiptValid :=
  SourceBoundFixedPointReceipt → Prop

structure SourceBoundFixedPointEvidenceClosed
    (request : SourceBoundCompositionRequestSubject)
    (registryValid : SourceBoundCompositionRegistryValid)
    (witnessValid : SourceBoundCompositionalEffectWitnessValid)
    (receiptValid : SourceBoundFixedPointReceiptValid)
    (bindingValid : SourceBoundObjectBindingValid)
    (resolutionReceiptValid : ResolutionReceiptValid)
    (registry : SourceBoundCompositionRegistry)
    (roots : SourceBoundUseCompositionProfiles)
    (witness : SourceBoundCompositionalEffectWitness)
    (receipt : SourceBoundFixedPointReceipt)
    (resolutionReceipts : List ResolutionReceipt) : Prop where
  witnessPlanMatchesRequest :
    witness.materializationPlanDigest =
      request.materializationPlanDigest
  witnessRootsMatch : witness.roots = roots
  registryValidates :
    registryValid witness.registryDigest registry
  witnessValidates : witnessValid witness
  receiptValidates : receiptValid receipt
  receiptRegistryMatches :
    receipt.registryDigest = witness.registryDigest
  receiptRootsMatch : receipt.roots = roots
  receiptUniverseMatches :
    receipt.effectUniverse = witness.effectUniverse
  receiptStable : receipt.stable = true
  receiptPendingEmpty : receipt.pending = []
  registrySubjectsUnique :
    SourceBoundRegistrySubjectsUnique registry
  receiptContainsRoots :
    sourceBoundRootsVisited roots receipt
  receiptLinkClosed :
    sourceBoundVisitedLinkClosed registry receipt
  receiptMinimal :
    sourceBoundVisitedIsMinimal registry roots receipt
  receiptVisitedRegistered :
    sourceBoundVisitedRegistered registry receipt
  receiptBindingsValid :
    sourceBoundVisitedBindingsValid
      bindingValid
      registry
      receipt
  receiptSourcesResolved :
    sourceBoundVisitedSourceReceiptsClosed
      resolutionReceiptValid
      registry
      receipt
      resolutionReceipts

theorem sourceBoundClosedReceiptContainsEveryReachableSubject
    (request : SourceBoundCompositionRequestSubject)
    (registryValid : SourceBoundCompositionRegistryValid)
    (witnessValid : SourceBoundCompositionalEffectWitnessValid)
    (receiptValid : SourceBoundFixedPointReceiptValid)
    (bindingValid : SourceBoundObjectBindingValid)
    (resolutionReceiptValid : ResolutionReceiptValid)
    (registry : SourceBoundCompositionRegistry)
    (roots : SourceBoundUseCompositionProfiles)
    (witness : SourceBoundCompositionalEffectWitness)
    (receipt : SourceBoundFixedPointReceipt)
    (resolutionReceipts : List ResolutionReceipt)
    (closed :
      SourceBoundFixedPointEvidenceClosed
        request
        registryValid
        witnessValid
        receiptValid
        bindingValid
        resolutionReceiptValid
        registry
        roots
        witness
        receipt
        resolutionReceipts)
    (subject : CompositionObjectSubject)
    (reachable : SourceBoundReachable registry roots subject) :
    subject ∈ receipt.visited := by
  induction reachable with
  | root rootInRoots =>
      exact closed.receiptContainsRoots _ rootInRoots
  | step sourceReachable link inductionHypothesis =>
      exact closed.receiptLinkClosed
        _
        inductionHypothesis
        _
        link

theorem sourceBoundClosedReceiptIsLeastFixedPoint
    (request : SourceBoundCompositionRequestSubject)
    (registryValid : SourceBoundCompositionRegistryValid)
    (witnessValid : SourceBoundCompositionalEffectWitnessValid)
    (receiptValid : SourceBoundFixedPointReceiptValid)
    (bindingValid : SourceBoundObjectBindingValid)
    (resolutionReceiptValid : ResolutionReceiptValid)
    (registry : SourceBoundCompositionRegistry)
    (roots : SourceBoundUseCompositionProfiles)
    (witness : SourceBoundCompositionalEffectWitness)
    (receipt : SourceBoundFixedPointReceipt)
    (resolutionReceipts : List ResolutionReceipt)
    (closed :
      SourceBoundFixedPointEvidenceClosed
        request
        registryValid
        witnessValid
        receiptValid
        bindingValid
        resolutionReceiptValid
        registry
        roots
        witness
        receipt
        resolutionReceipts)
    (subject : CompositionObjectSubject) :
    subject ∈ receipt.visited ↔
      SourceBoundReachable registry roots subject := by
  constructor
  · exact closed.receiptMinimal subject
  · exact
      sourceBoundClosedReceiptContainsEveryReachableSubject
        request
        registryValid
        witnessValid
        receiptValid
        bindingValid
        resolutionReceiptValid
        registry
        roots
        witness
        receipt
        resolutionReceipts
        closed
        subject

theorem sourceBoundClosedVisitedSubjectHasUniqueObject
    (request : SourceBoundCompositionRequestSubject)
    (registryValid : SourceBoundCompositionRegistryValid)
    (witnessValid : SourceBoundCompositionalEffectWitnessValid)
    (receiptValid : SourceBoundFixedPointReceiptValid)
    (bindingValid : SourceBoundObjectBindingValid)
    (resolutionReceiptValid : ResolutionReceiptValid)
    (registry : SourceBoundCompositionRegistry)
    (roots : SourceBoundUseCompositionProfiles)
    (witness : SourceBoundCompositionalEffectWitness)
    (receipt : SourceBoundFixedPointReceipt)
    (resolutionReceipts : List ResolutionReceipt)
    (closed :
      SourceBoundFixedPointEvidenceClosed
        request
        registryValid
        witnessValid
        receiptValid
        bindingValid
        resolutionReceiptValid
        registry
        roots
        witness
        receipt
        resolutionReceipts)
    (subject : CompositionObjectSubject)
    (subjectVisited : subject ∈ receipt.visited) :
    ∃ object,
      (object ∈ registry ∧
        object.subject = subject) ∧
      ∀ other,
        other ∈ registry ∧
          other.subject = subject →
        other = object := by
  have registered :=
    closed.receiptVisitedRegistered subject subjectVisited
  rcases List.mem_map.mp registered with
    ⟨object, objectInRegistry, objectSubject⟩
  refine
    ⟨object,
      ⟨objectInRegistry, objectSubject⟩,
      ?_⟩
  intro other otherEvidence
  exact
    closed.registrySubjectsUnique
      other
      otherEvidence.1
      object
      objectInRegistry
      (otherEvidence.2.trans objectSubject.symm)

theorem sourceBoundClosedVisitedSubjectHasBindingAndResolution
    (request : SourceBoundCompositionRequestSubject)
    (registryValid : SourceBoundCompositionRegistryValid)
    (witnessValid : SourceBoundCompositionalEffectWitnessValid)
    (receiptValid : SourceBoundFixedPointReceiptValid)
    (bindingValid : SourceBoundObjectBindingValid)
    (resolutionReceiptValid : ResolutionReceiptValid)
    (registry : SourceBoundCompositionRegistry)
    (roots : SourceBoundUseCompositionProfiles)
    (witness : SourceBoundCompositionalEffectWitness)
    (receipt : SourceBoundFixedPointReceipt)
    (resolutionReceipts : List ResolutionReceipt)
    (closed :
      SourceBoundFixedPointEvidenceClosed
        request
        registryValid
        witnessValid
        receiptValid
        bindingValid
        resolutionReceiptValid
        registry
        roots
        witness
        receipt
        resolutionReceipts)
    (subject : CompositionObjectSubject)
    (subjectVisited : subject ∈ receipt.visited) :
    ∃ object ∈ registry,
      object.subject = subject ∧
        bindingValid object ∧
          ∃ resolutionReceipt ∈ resolutionReceipts,
            resolutionReceiptMatches
                (sourceClaimOf object.subject)
                resolutionReceipt ∧
              resolutionReceiptValid resolutionReceipt := by
  have registered :=
    closed.receiptVisitedRegistered subject subjectVisited
  rcases List.mem_map.mp registered with
    ⟨object, objectInRegistry, objectSubject⟩
  refine
    ⟨object,
      objectInRegistry,
      objectSubject,
      closed.receiptBindingsValid
        object
        objectInRegistry
        (objectSubject ▸ subjectVisited),
      ?_⟩
  exact
    closed.receiptSourcesResolved
      object
      objectInRegistry
      (objectSubject ▸ subjectVisited)

def completeSourceBoundFixedPointReceipt :
    SourceBoundFixedPointReceipt where
  receiptId := "source-bound-fixed-point-a"
  registryDigest := sourceBoundWitnessA.registryDigest
  roots := sourceBoundMessageRoots
  visited := [messageProviderSubjectA]
  pending := []
  effectUniverse := sourceBoundWitnessA.effectUniverse
  generation := 1
  iterationCount := 1
  stable := true

theorem completeSourceBoundFixedPointEvidenceCloses :
    SourceBoundFixedPointEvidenceClosed
      sourceBoundCompositionRequestA
      (fun _digest _registry => True)
      (fun _witness => True)
      (fun _receipt => True)
      (fun _object => True)
      (fun _resolutionReceipt => True)
      sourceBoundRegistryA
      sourceBoundMessageRoots
      sourceBoundWitnessA
      completeSourceBoundFixedPointReceipt
      [sourceBoundResolutionReceiptA] := by
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
  · intro left leftInRegistry right rightInRegistry subjectsEqual
    simp [sourceBoundRegistryA] at leftInRegistry rightInRegistry
    subst left
    subst right
    rfl
  · intro root rootInRoots
    have rootIsMessageProvider :
        root = messageProviderSubjectA := by
      simpa [sourceBoundMessageRoots] using rootInRoots
    subst root
    simp [completeSourceBoundFixedPointReceipt]
  · intro source sourceVisited target link
    rcases link with
      ⟨object, objectInRegistry, objectSubject, targetInLinks⟩
    simp [sourceBoundRegistryA] at objectInRegistry
    subst object
    simp [
      sourceBoundMessageProviderA
    ] at targetInLinks
  · intro subject subjectVisited
    have subjectIsRoot :
        subject = messageProviderSubjectA := by
      simpa [
        completeSourceBoundFixedPointReceipt
      ] using subjectVisited
    subst subject
    exact .root (by simp [sourceBoundMessageRoots])
  · intro subject subjectVisited
    simpa [
      completeSourceBoundFixedPointReceipt,
      registeredSubjects,
      sourceBoundRegistryA,
      sourceBoundMessageProviderA
    ] using subjectVisited
  · intro object objectInRegistry objectVisited
    trivial
  · intro object objectInRegistry objectVisited
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

end AgenticAILabProof.Enterprise.SourceBoundCompositionalFixedPointClosure
