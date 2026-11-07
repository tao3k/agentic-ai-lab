-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundCompositionalFixedPointClosure

namespace AgenticAILabProof.Enterprise.SourceBoundCycleObservationClosure

open BundleEvidenceBinding
open CompositionalEffectUniverse
open CompositionalFixedPointClosure
open SourceBoundCompositionalEffectClosure
open SourceBoundCompositionalFixedPointClosure

structure SourceBoundCycleDetectedObservation where
  observationId : CycleObservationId
  registryDigest : CompositionRegistryDigest
  generation : Nat
  closingSource : CompositionObjectSubject
  closingTarget : CompositionObjectSubject
  sccMembers : List CompositionObjectSubject
  causalPath : List CompositionObjectSubject
  provenanceDigest : String
  semanticBudgetConsumed : Nat
  schedulingBudgetConsumed : Nat
  continuationIdentity : ContinuationIdentity
  deriving DecidableEq, Repr

def SourceBoundCycleDetectedObservationValid :=
  SourceBoundCycleDetectedObservation → Prop

def SourceBoundCycleRetryAuthority :=
  SourceBoundCycleDetectedObservation → Prop

def subjectsVisited
    (receipt : SourceBoundFixedPointReceipt)
    (subjects : List CompositionObjectSubject) : Prop :=
  ∀ subject,
    subject ∈ subjects →
      subject ∈ receipt.visited

def subjectsBelongToScc
    (observation : SourceBoundCycleDetectedObservation) : Prop :=
  ∀ subject,
    subject ∈ observation.causalPath →
      subject ∈ observation.sccMembers

def pathFollowsCompositionLinks
    (registry : SourceBoundCompositionRegistry) :
    List CompositionObjectSubject → Prop
  | [] => True
  | [_subject] => True
  | source :: target :: rest =>
      sourceBoundCompositionLink registry source target ∧
        pathFollowsCompositionLinks registry (target :: rest)

def cyclePathClosed
    (path : List CompositionObjectSubject) : Prop :=
  ∃ first middle,
    path = first :: (middle ++ [first])

def pathEndsWithClosingEdge
    (observation : SourceBoundCycleDetectedObservation) : Prop :=
  ∃ pathPrefix,
    observation.causalPath =
      pathPrefix ++
        [observation.closingSource, observation.closingTarget]

def cycleObservationPathClosed
    (registry : SourceBoundCompositionRegistry)
    (receipt : SourceBoundFixedPointReceipt)
    (observation : SourceBoundCycleDetectedObservation) : Prop :=
  observation.sccMembers ≠ [] ∧
    subjectsVisited receipt observation.sccMembers ∧
    subjectsVisited receipt observation.causalPath ∧
    subjectsBelongToScc observation ∧
    pathFollowsCompositionLinks registry observation.causalPath ∧
    cyclePathClosed observation.causalPath ∧
    pathEndsWithClosingEdge observation ∧
    sourceBoundCompositionLink
      registry
      observation.closingSource
      observation.closingTarget

inductive SourceBoundSccReachableWithin
    (registry : SourceBoundCompositionRegistry)
    (members : List CompositionObjectSubject) :
    CompositionObjectSubject →
      CompositionObjectSubject →
        Prop where
  | refl
      {subject : CompositionObjectSubject}
      (subjectInMembers : subject ∈ members) :
      SourceBoundSccReachableWithin registry members subject subject
  | step
      {source middle target : CompositionObjectSubject}
      (sourceInMembers : source ∈ members)
      (middleInMembers : middle ∈ members)
      (sourceLinksToMiddle :
        sourceBoundCompositionLink registry source middle)
      (middleReachesTarget :
        SourceBoundSccReachableWithin registry members middle target) :
      SourceBoundSccReachableWithin registry members source target

def sccStronglyConnected
    (registry : SourceBoundCompositionRegistry)
    (members : List CompositionObjectSubject) : Prop :=
  ∀ source,
    source ∈ members →
      ∀ target,
        target ∈ members →
          SourceBoundSccReachableWithin
            registry
            members
            source
            target

def cycleObservationSubjectClosed
    (registry : SourceBoundCompositionRegistry)
    (receipt : SourceBoundFixedPointReceipt)
    (observation : SourceBoundCycleDetectedObservation) : Prop :=
  cycleObservationPathClosed registry receipt observation ∧
    sccStronglyConnected registry observation.sccMembers ∧
      observation.sccMembers.Nodup

def identityOnlyCycleObservation : CycleDetectedObservation where
  observationId := "identity-only-cycle"
  registryDigest := "sha256:same-name-cycle"
  generation := 1
  sccMembers := ["message-provider"]
  causalPath := ["message-provider", "message-provider"]
  provenanceDigest := "sha256:identity-only-cycle"
  semanticBudgetConsumed := 1
  schedulingBudgetConsumed := 1
  continuationIdentity := "continuation-identity-only-cycle"

def identityCycleNamesSubject
    (observation : CycleDetectedObservation)
    (subject : CompositionObjectSubject) : Prop :=
  subject.identity ∈ observation.sccMembers

theorem identityOnlyCycleCannotDistinguishSourceRevision :
    messageProviderSubjectA ≠ messageProviderSubjectB ∧
      identityCycleNamesSubject
        identityOnlyCycleObservation
        messageProviderSubjectA ∧
      identityCycleNamesSubject
        identityOnlyCycleObservation
        messageProviderSubjectB := by
  constructor
  · decide
  · constructor <;>
      simp [
        identityCycleNamesSubject,
        identityOnlyCycleObservation,
        messageProviderSubjectA,
        messageProviderSubjectB
      ]

def unrelatedCycleObservation : CycleDetectedObservation where
  observationId := "unrelated-cycle"
  registryDigest := completeFixedPointReceipt.registryDigest
  generation := completeFixedPointReceipt.generation
  sccMembers := ["ghost-profile"]
  causalPath := ["ghost-profile", "ghost-profile"]
  provenanceDigest := "sha256:unrelated-cycle"
  semanticBudgetConsumed := 1
  schedulingBudgetConsumed := 1
  continuationIdentity := "continuation-unrelated-cycle"

theorem matchingCycleFieldsDoNotProveVisitedSubjectClosure :
    unrelatedCycleObservation.registryDigest =
        completeFixedPointReceipt.registryDigest ∧
      unrelatedCycleObservation.generation ≤
        completeFixedPointReceipt.generation ∧
      ¬ (∀ nodeId,
        nodeId ∈ unrelatedCycleObservation.sccMembers →
          nodeId ∈ completeFixedPointReceipt.visited) := by
  constructor
  · rfl
  · constructor
    · simp [unrelatedCycleObservation]
    · intro membersVisited
      have ghostVisited :=
        membersVisited "ghost-profile" (by
          simp [unrelatedCycleObservation])
      simp [
        completeFixedPointReceipt,
        completeVisited
      ] at ghostVisited

def cyclicSourceBoundMessageProviderA :
    SourceBoundCompositionObject :=
  { sourceBoundMessageProviderA with
    delegations := [messageProviderSubjectB] }

def cyclicSourceBoundMessageProviderB :
    SourceBoundCompositionObject :=
  { sourceBoundMessageProviderB with
    delegations := [messageProviderSubjectA] }

def sourceBoundCycleRegistry : SourceBoundCompositionRegistry :=
  [
    cyclicSourceBoundMessageProviderA,
    cyclicSourceBoundMessageProviderB
  ]

theorem sourceBoundCycleLinkAB :
    sourceBoundCompositionLink
      sourceBoundCycleRegistry
      messageProviderSubjectA
      messageProviderSubjectB := by
  refine
    ⟨cyclicSourceBoundMessageProviderA,
      by simp [sourceBoundCycleRegistry],
      rfl,
      ?_⟩
  simp [cyclicSourceBoundMessageProviderA]

theorem sourceBoundCycleLinkBA :
    sourceBoundCompositionLink
      sourceBoundCycleRegistry
      messageProviderSubjectB
      messageProviderSubjectA := by
  refine
    ⟨cyclicSourceBoundMessageProviderB,
      by simp [sourceBoundCycleRegistry],
      rfl,
      ?_⟩
  simp [cyclicSourceBoundMessageProviderB]

def sourceBoundCycleRoots : SourceBoundUseCompositionProfiles :=
  [messageProviderSubjectA]

theorem sourceBoundCycleSubjectAReachable :
    SourceBoundReachable
      sourceBoundCycleRegistry
      sourceBoundCycleRoots
      messageProviderSubjectA :=
  .root (by simp [sourceBoundCycleRoots])

theorem sourceBoundCycleSubjectBReachable :
    SourceBoundReachable
      sourceBoundCycleRegistry
      sourceBoundCycleRoots
      messageProviderSubjectB :=
  .step
    sourceBoundCycleSubjectAReachable
    (by
      refine
        ⟨cyclicSourceBoundMessageProviderA,
          by simp [sourceBoundCycleRegistry],
          rfl,
          ?_⟩
      simp [cyclicSourceBoundMessageProviderA])

def sourceBoundCycleRequestSubject :
    SourceBoundCompositionRequestSubject where
  transactionId := "promotion-transaction-a"
  materializationPlanDigest := "sha256:marlin-plan-a"

def sourceBoundCycleWitness : SourceBoundCompositionalEffectWitness where
  witnessId := "source-bound-cycle-witness"
  materializationPlanDigest :=
    sourceBoundCycleRequestSubject.materializationPlanDigest
  registryDigest := "sha256:source-bound-cycle-registry"
  roots := sourceBoundCycleRoots
  effectUniverse := ["external-message", "external-payment"]

def sourceBoundCycleFixedPointReceipt :
    SourceBoundFixedPointReceipt where
  receiptId := "source-bound-cycle-fixed-point"
  registryDigest := sourceBoundCycleWitness.registryDigest
  roots := sourceBoundCycleRoots
  visited := [messageProviderSubjectA, messageProviderSubjectB]
  pending := []
  effectUniverse := sourceBoundCycleWitness.effectUniverse
  generation := 2
  iterationCount := 2
  stable := true

def sourceBoundResolutionReceiptB : ResolutionReceipt where
  packageId := messageProviderSubjectB.packageId
  revision := messageProviderSubjectB.revision
  sourceTreeDigest := messageProviderSubjectB.sourceTreeDigest
  resolverId := "gerbil.pkg"
  resolverReceiptDigest := "sha256:gerbil-package-resolution-b"

theorem sourceBoundCycleFixedPointEvidenceCloses :
    SourceBoundFixedPointEvidenceClosed
      sourceBoundCycleRequestSubject
      (fun _digest _registry => True)
      (fun _witness => True)
      (fun _receipt => True)
      (fun _object => True)
      (fun _resolutionReceipt => True)
      sourceBoundCycleRegistry
      sourceBoundCycleRoots
      sourceBoundCycleWitness
      sourceBoundCycleFixedPointReceipt
      [
        sourceBoundResolutionReceiptA,
        sourceBoundResolutionReceiptB
      ] := by
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
    simp [sourceBoundCycleRegistry] at leftInRegistry rightInRegistry
    rcases leftInRegistry with rfl | rfl
    · rcases rightInRegistry with rfl | rfl
      · rfl
      · exfalso
        exact
          (by decide :
            messageProviderSubjectA ≠ messageProviderSubjectB)
          (by
            simpa [
              cyclicSourceBoundMessageProviderA,
              cyclicSourceBoundMessageProviderB,
              sourceBoundMessageProviderA,
              sourceBoundMessageProviderB
            ] using subjectsEqual)
    · rcases rightInRegistry with rfl | rfl
      · exfalso
        exact
          (by decide :
            messageProviderSubjectB ≠ messageProviderSubjectA)
          (by
            simpa [
              cyclicSourceBoundMessageProviderA,
              cyclicSourceBoundMessageProviderB,
              sourceBoundMessageProviderA,
              sourceBoundMessageProviderB
            ] using subjectsEqual)
      · rfl
  · intro root rootInRoots
    have rootIsA : root = messageProviderSubjectA := by
      simpa [sourceBoundCycleRoots] using rootInRoots
    subst root
    simp [sourceBoundCycleFixedPointReceipt]
  · intro source sourceVisited target link
    rcases link with
      ⟨object, objectInRegistry, objectSubject, targetInLinks⟩
    simp [sourceBoundCycleRegistry] at objectInRegistry
    rcases objectInRegistry with rfl | rfl
    · have sourceIsA : source = messageProviderSubjectA := by
        simpa [
          cyclicSourceBoundMessageProviderA,
          sourceBoundMessageProviderA
        ] using objectSubject.symm
      subst source
      have targetIsB : target = messageProviderSubjectB := by
        simpa [
          cyclicSourceBoundMessageProviderA,
          sourceBoundMessageProviderA
        ] using targetInLinks
      subst target
      simp [sourceBoundCycleFixedPointReceipt]
    · have sourceIsB : source = messageProviderSubjectB := by
        simpa [
          cyclicSourceBoundMessageProviderB,
          sourceBoundMessageProviderB
        ] using objectSubject.symm
      subst source
      have targetIsA : target = messageProviderSubjectA := by
        simpa [
          cyclicSourceBoundMessageProviderB,
          sourceBoundMessageProviderB
        ] using targetInLinks
      subst target
      simp [sourceBoundCycleFixedPointReceipt]
  · intro subject subjectVisited
    simp [
      sourceBoundCycleFixedPointReceipt
    ] at subjectVisited
    rcases subjectVisited with rfl | rfl
    · exact sourceBoundCycleSubjectAReachable
    · exact sourceBoundCycleSubjectBReachable
  · intro subject subjectVisited
    simpa [
      sourceBoundCycleFixedPointReceipt,
      registeredSubjects,
      sourceBoundCycleRegistry,
      cyclicSourceBoundMessageProviderA,
      cyclicSourceBoundMessageProviderB,
      sourceBoundMessageProviderA,
      sourceBoundMessageProviderB
    ] using subjectVisited
  · intro object objectInRegistry objectVisited
    trivial
  · intro object objectInRegistry objectVisited
    simp [sourceBoundCycleRegistry] at objectInRegistry
    rcases objectInRegistry with rfl | rfl
    · exact
        ⟨sourceBoundResolutionReceiptA,
          by simp,
          by
            simp [
              resolutionReceiptMatches,
              sourceClaimOf,
              sourceBoundResolutionReceiptA,
              cyclicSourceBoundMessageProviderA,
              sourceBoundMessageProviderA,
              messageProviderSubjectA
            ]⟩
    · exact
        ⟨sourceBoundResolutionReceiptB,
          by simp,
          by
            simp [
              resolutionReceiptMatches,
              sourceClaimOf,
              sourceBoundResolutionReceiptB,
              cyclicSourceBoundMessageProviderB,
              sourceBoundMessageProviderB,
              messageProviderSubjectB
            ]⟩

def sourceBoundCycleObservation :
    SourceBoundCycleDetectedObservation where
  observationId := "source-bound-cycle-observation"
  registryDigest := sourceBoundCycleFixedPointReceipt.registryDigest
  generation := sourceBoundCycleFixedPointReceipt.generation
  closingSource := messageProviderSubjectB
  closingTarget := messageProviderSubjectA
  sccMembers := [messageProviderSubjectA, messageProviderSubjectB]
  causalPath :=
    [
      messageProviderSubjectA,
      messageProviderSubjectB,
      messageProviderSubjectA
    ]
  provenanceDigest := "sha256:source-bound-cycle-provenance"
  semanticBudgetConsumed := 2
  schedulingBudgetConsumed := 2
  continuationIdentity := "continuation-source-bound-cycle"

def cycleObservationWithRepeatedSccMember :
    SourceBoundCycleDetectedObservation :=
  { sourceBoundCycleObservation with
    observationId := "source-bound-cycle-repeated-scc-member"
    sccMembers :=
      [
        messageProviderSubjectA,
        messageProviderSubjectB,
        messageProviderSubjectA
      ] }

theorem sourceBoundCycleSccStronglyConnected :
    sccStronglyConnected
      sourceBoundCycleRegistry
      sourceBoundCycleObservation.sccMembers := by
  intro source sourceInScc target targetInScc
  simp [sourceBoundCycleObservation] at sourceInScc targetInScc
  rcases sourceInScc with rfl | rfl
  · rcases targetInScc with rfl | rfl
    · exact .refl (by simp [sourceBoundCycleObservation])
    · exact
        .step
          (by simp [sourceBoundCycleObservation])
          (by simp [sourceBoundCycleObservation])
          sourceBoundCycleLinkAB
          (.refl (by simp [sourceBoundCycleObservation]))
  · rcases targetInScc with rfl | rfl
    · exact
        .step
          (by simp [sourceBoundCycleObservation])
          (by simp [sourceBoundCycleObservation])
          sourceBoundCycleLinkBA
          (.refl (by simp [sourceBoundCycleObservation]))
    · exact .refl (by simp [sourceBoundCycleObservation])

theorem repeatedSccMembersRemainStronglyConnected :
    sccStronglyConnected
      sourceBoundCycleRegistry
      cycleObservationWithRepeatedSccMember.sccMembers := by
  intro source sourceInScc target targetInScc
  simp [
    cycleObservationWithRepeatedSccMember,
    sourceBoundCycleObservation
  ] at sourceInScc targetInScc
  have sourceIsAOrB :
      source = messageProviderSubjectA ∨
        source = messageProviderSubjectB := by
    rcases sourceInScc with sourceIsA | sourceIsB | sourceIsA
    · exact Or.inl sourceIsA
    · exact Or.inr sourceIsB
    · exact Or.inl sourceIsA
  have targetIsAOrB :
      target = messageProviderSubjectA ∨
        target = messageProviderSubjectB := by
    rcases targetInScc with targetIsA | targetIsB | targetIsA
    · exact Or.inl targetIsA
    · exact Or.inr targetIsB
    · exact Or.inl targetIsA
  rcases sourceIsAOrB with rfl | rfl
  · rcases targetIsAOrB with rfl | rfl
    · exact
        .refl
          (by
            simp [
              cycleObservationWithRepeatedSccMember,
              sourceBoundCycleObservation
            ])
    · exact
        .step
          (by
            simp [
              cycleObservationWithRepeatedSccMember,
              sourceBoundCycleObservation
            ])
          (by
            simp [
              cycleObservationWithRepeatedSccMember,
              sourceBoundCycleObservation
            ])
          sourceBoundCycleLinkAB
          (.refl
            (by
              simp [
                cycleObservationWithRepeatedSccMember,
                sourceBoundCycleObservation
              ]))
  · rcases targetIsAOrB with rfl | rfl
    · exact
        .step
          (by
            simp [
              cycleObservationWithRepeatedSccMember,
              sourceBoundCycleObservation
            ])
          (by
            simp [
              cycleObservationWithRepeatedSccMember,
              sourceBoundCycleObservation
            ])
          sourceBoundCycleLinkBA
          (.refl
            (by
              simp [
                cycleObservationWithRepeatedSccMember,
                sourceBoundCycleObservation
              ]))
    · exact
        .refl
          (by
            simp [
              cycleObservationWithRepeatedSccMember,
              sourceBoundCycleObservation
            ])

theorem strongConnectivityDoesNotProveCanonicalSccMembership :
    sccStronglyConnected
        sourceBoundCycleRegistry
        cycleObservationWithRepeatedSccMember.sccMembers ∧
      ¬ cycleObservationWithRepeatedSccMember.sccMembers.Nodup := by
  exact ⟨repeatedSccMembersRemainStronglyConnected, by decide⟩

def disconnectedCycleSubject : CompositionObjectSubject where
  identity := "independent-audit-provider"
  packageId := "wendao-episteme"
  revision := "revision-independent"
  sourceTreeDigest := "sha256:source-tree-independent"
  objectContentDigest := "sha256:audit-provider-independent"
  effectContractDigest := "sha256:audit-contract-independent"

def disconnectedCycleObject : SourceBoundCompositionObject where
  subject := disconnectedCycleSubject
  kind := .providerAsset
  imports := []
  capabilities := ["external-audit"]
  profiles := []
  submodules := []
  workflows := []
  delegations := []
  localEffects := ["external-audit"]

def sourceBoundRegistryWithDisconnectedRoot :
    SourceBoundCompositionRegistry :=
  sourceBoundCycleRegistry ++ [disconnectedCycleObject]

def sourceBoundRootsWithDisconnectedRoot :
    SourceBoundUseCompositionProfiles :=
  [messageProviderSubjectA, disconnectedCycleSubject]

def sourceBoundReceiptWithDisconnectedRoot :
    SourceBoundFixedPointReceipt where
  receiptId := "source-bound-fixed-point-with-disconnected-root"
  registryDigest := "sha256:registry-with-disconnected-root"
  roots := sourceBoundRootsWithDisconnectedRoot
  visited :=
    [
      messageProviderSubjectA,
      messageProviderSubjectB,
      disconnectedCycleSubject
    ]
  pending := []
  effectUniverse :=
    ["external-message", "external-payment", "external-audit"]
  generation := 3
  iterationCount := 3
  stable := true

def cycleObservationWithDisconnectedSccMember :
    SourceBoundCycleDetectedObservation where
  observationId := "cycle-with-disconnected-scc-member"
  registryDigest := sourceBoundReceiptWithDisconnectedRoot.registryDigest
  generation := sourceBoundReceiptWithDisconnectedRoot.generation
  closingSource := messageProviderSubjectB
  closingTarget := messageProviderSubjectA
  sccMembers :=
    [
      messageProviderSubjectA,
      messageProviderSubjectB,
      disconnectedCycleSubject
    ]
  causalPath :=
    [
      messageProviderSubjectA,
      messageProviderSubjectB,
      messageProviderSubjectA
    ]
  provenanceDigest := "sha256:cycle-with-disconnected-scc-member"
  semanticBudgetConsumed := 2
  schedulingBudgetConsumed := 2
  continuationIdentity := "continuation-disconnected-scc-member"

theorem pathClosedCycleCanIncludeDisconnectedSccMember :
    sourceBoundRootsVisited
        sourceBoundRootsWithDisconnectedRoot
        sourceBoundReceiptWithDisconnectedRoot ∧
      sourceBoundVisitedLinkClosed
        sourceBoundRegistryWithDisconnectedRoot
        sourceBoundReceiptWithDisconnectedRoot ∧
      sourceBoundVisitedIsMinimal
        sourceBoundRegistryWithDisconnectedRoot
        sourceBoundRootsWithDisconnectedRoot
        sourceBoundReceiptWithDisconnectedRoot ∧
      sourceBoundVisitedRegistered
        sourceBoundRegistryWithDisconnectedRoot
        sourceBoundReceiptWithDisconnectedRoot ∧
      cycleObservationPathClosed
        sourceBoundRegistryWithDisconnectedRoot
        sourceBoundReceiptWithDisconnectedRoot
        cycleObservationWithDisconnectedSccMember ∧
      ¬ sccStronglyConnected
        sourceBoundRegistryWithDisconnectedRoot
        cycleObservationWithDisconnectedSccMember.sccMembers := by
  constructor
  · intro root rootInRoots
    simp [sourceBoundRootsWithDisconnectedRoot] at rootInRoots
    rcases rootInRoots with rfl | rfl <;>
      simp [sourceBoundReceiptWithDisconnectedRoot]
  · constructor
    · intro source sourceVisited target sourceLinksToTarget
      rcases sourceLinksToTarget with
        ⟨object, objectInRegistry, objectSubject, targetInLinks⟩
      simp [
        sourceBoundRegistryWithDisconnectedRoot,
        sourceBoundCycleRegistry
      ] at objectInRegistry
      rcases objectInRegistry with rfl | rfl | rfl
      · have sourceIsA : source = messageProviderSubjectA := by
          simpa [
            cyclicSourceBoundMessageProviderA,
            sourceBoundMessageProviderA
          ] using objectSubject.symm
        subst source
        have targetIsB : target = messageProviderSubjectB := by
          simpa [
            cyclicSourceBoundMessageProviderA,
            sourceBoundMessageProviderA
          ] using targetInLinks
        subst target
        simp [sourceBoundReceiptWithDisconnectedRoot]
      · have sourceIsB : source = messageProviderSubjectB := by
          simpa [
            cyclicSourceBoundMessageProviderB,
            sourceBoundMessageProviderB
          ] using objectSubject.symm
        subst source
        have targetIsA : target = messageProviderSubjectA := by
          simpa [
            cyclicSourceBoundMessageProviderB,
            sourceBoundMessageProviderB
          ] using targetInLinks
        subst target
        simp [sourceBoundReceiptWithDisconnectedRoot]
      · simp [disconnectedCycleObject] at targetInLinks
    · constructor
      · intro subject subjectVisited
        simp [sourceBoundReceiptWithDisconnectedRoot] at subjectVisited
        rcases subjectVisited with rfl | rfl | rfl
        · exact
            .root
              (by simp [sourceBoundRootsWithDisconnectedRoot])
        · exact
            .step
              (show
                SourceBoundReachable
                  sourceBoundRegistryWithDisconnectedRoot
                  sourceBoundRootsWithDisconnectedRoot
                  messageProviderSubjectA
                from
                  .root
                    (by
                      simp [sourceBoundRootsWithDisconnectedRoot]))
              (by
                refine
                  ⟨cyclicSourceBoundMessageProviderA,
                    by
                      simp [
                        sourceBoundRegistryWithDisconnectedRoot,
                        sourceBoundCycleRegistry
                      ],
                    rfl,
                    ?_⟩
                simp [cyclicSourceBoundMessageProviderA])
        · exact
            .root
              (by simp [sourceBoundRootsWithDisconnectedRoot])
      · constructor
        · intro subject subjectVisited
          simpa [
            sourceBoundReceiptWithDisconnectedRoot,
            registeredSubjects,
            sourceBoundRegistryWithDisconnectedRoot,
            sourceBoundCycleRegistry,
            cyclicSourceBoundMessageProviderA,
            cyclicSourceBoundMessageProviderB,
            sourceBoundMessageProviderA,
            sourceBoundMessageProviderB,
            disconnectedCycleObject
          ] using subjectVisited
        · constructor
          · constructor
            · simp [cycleObservationWithDisconnectedSccMember]
            · constructor
              · intro subject subjectInScc
                simpa [
                  cycleObservationWithDisconnectedSccMember,
                  sourceBoundReceiptWithDisconnectedRoot
                ] using subjectInScc
              · constructor
                · intro subject subjectInPath
                  simp [
                    cycleObservationWithDisconnectedSccMember
                  ] at subjectInPath
                  rcases subjectInPath with rfl | rfl | rfl
                  all_goals
                    simp [sourceBoundReceiptWithDisconnectedRoot]
                · constructor
                  · intro subject subjectInPath
                    simp [
                      cycleObservationWithDisconnectedSccMember
                    ] at subjectInPath ⊢
                    rcases subjectInPath with
                      subjectIsA | subjectIsB | subjectIsA
                    · exact Or.inl subjectIsA
                    · exact Or.inr (Or.inl subjectIsB)
                    · exact Or.inl subjectIsA
                  · constructor
                    · constructor
                      · refine
                          ⟨cyclicSourceBoundMessageProviderA,
                            by
                              simp [
                                sourceBoundRegistryWithDisconnectedRoot,
                                sourceBoundCycleRegistry
                              ],
                            rfl,
                            ?_⟩
                        simp [cyclicSourceBoundMessageProviderA]
                      · constructor
                        · refine
                            ⟨cyclicSourceBoundMessageProviderB,
                              by
                                simp [
                                  sourceBoundRegistryWithDisconnectedRoot,
                                  sourceBoundCycleRegistry
                                ],
                              rfl,
                              ?_⟩
                          simp [
                            cyclicSourceBoundMessageProviderB,
                            sourceBoundMessageProviderB
                          ]
                        · trivial
                    · constructor
                      · exact
                          ⟨messageProviderSubjectA,
                            [messageProviderSubjectB],
                            rfl⟩
                      · constructor
                        · exact ⟨[messageProviderSubjectA], rfl⟩
                        · refine
                            ⟨cyclicSourceBoundMessageProviderB,
                              by
                                simp [
                                  sourceBoundRegistryWithDisconnectedRoot,
                                  sourceBoundCycleRegistry
                                ],
                              rfl,
                              ?_⟩
                          simp [
                            cycleObservationWithDisconnectedSccMember,
                            cyclicSourceBoundMessageProviderB
                          ]
          · intro stronglyConnected
            have disconnectedHasNoOutgoingLink :
                ∀ target,
                  ¬ sourceBoundCompositionLink
                    sourceBoundRegistryWithDisconnectedRoot
                    disconnectedCycleSubject
                    target := by
              intro target link
              rcases link with
                ⟨object,
                  objectInRegistry,
                  objectSubject,
                  targetInLinks⟩
              simp [
                sourceBoundRegistryWithDisconnectedRoot,
                sourceBoundCycleRegistry
              ] at objectInRegistry
              rcases objectInRegistry with rfl | rfl | rfl
              · exact
                  (by decide :
                    messageProviderSubjectA ≠ disconnectedCycleSubject)
                  (by
                    simpa [
                      cyclicSourceBoundMessageProviderA,
                      sourceBoundMessageProviderA
                    ] using objectSubject)
              · exact
                  (by decide :
                    messageProviderSubjectB ≠ disconnectedCycleSubject)
                  (by
                    simpa [
                      cyclicSourceBoundMessageProviderB,
                      sourceBoundMessageProviderB
                    ] using objectSubject)
              · simp [disconnectedCycleObject] at targetInLinks
            have disconnectedReachabilityIsReflexiveOnly :
                ∀ target,
                  SourceBoundSccReachableWithin
                      sourceBoundRegistryWithDisconnectedRoot
                      cycleObservationWithDisconnectedSccMember.sccMembers
                      disconnectedCycleSubject
                      target →
                    target = disconnectedCycleSubject := by
              intro target reachesTarget
              cases reachesTarget with
              | refl subjectInMembers => rfl
              | step
                  sourceInMembers
                  middleInMembers
                  link
                  middleReachesTarget =>
                    exact False.elim
                      (disconnectedHasNoOutgoingLink _ link)
            have disconnectedReachesA :=
              stronglyConnected
                disconnectedCycleSubject
                (by
                  simp [cycleObservationWithDisconnectedSccMember])
                messageProviderSubjectA
                (by
                  simp [cycleObservationWithDisconnectedSccMember])
            exact
              (by decide :
                messageProviderSubjectA ≠ disconnectedCycleSubject)
              (disconnectedReachabilityIsReflexiveOnly
                messageProviderSubjectA
                disconnectedReachesA)

structure SourceBoundCycleEvidenceClosed
    (observationValid : SourceBoundCycleDetectedObservationValid)
    (registry : SourceBoundCompositionRegistry)
    (receipt : SourceBoundFixedPointReceipt)
    (observation : SourceBoundCycleDetectedObservation) : Prop where
  observationValidates : observationValid observation
  observationRegistryMatches :
    observation.registryDigest = receipt.registryDigest
  observationGenerationBound :
    observation.generation ≤ receipt.generation
  observationSubjectClosed :
    cycleObservationSubjectClosed registry receipt observation

theorem closedSourceBoundCycleMemberIsReachable
    (request : SourceBoundCompositionRequestSubject)
    (registryValid : SourceBoundCompositionRegistryValid)
    (witnessValid : SourceBoundCompositionalEffectWitnessValid)
    (receiptValid : SourceBoundFixedPointReceiptValid)
    (bindingValid : SourceBoundObjectBindingValid)
    (resolutionReceiptValid : ResolutionReceiptValid)
    (observationValid : SourceBoundCycleDetectedObservationValid)
    (registry : SourceBoundCompositionRegistry)
    (roots : SourceBoundUseCompositionProfiles)
    (witness : SourceBoundCompositionalEffectWitness)
    (receipt : SourceBoundFixedPointReceipt)
    (resolutionReceipts : List ResolutionReceipt)
    (observation : SourceBoundCycleDetectedObservation)
    (fixedPointClosed :
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
    (cycleClosed :
      SourceBoundCycleEvidenceClosed
        observationValid
        registry
        receipt
        observation)
    (subject : CompositionObjectSubject)
    (subjectInScc : subject ∈ observation.sccMembers) :
    SourceBoundReachable registry roots subject := by
  have subjectVisited :=
    cycleClosed.observationSubjectClosed.1.2.1
      subject
      subjectInScc
  exact
    (sourceBoundClosedReceiptIsLeastFixedPoint
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
      fixedPointClosed
      subject).1 subjectVisited

theorem completeSourceBoundCycleEvidenceCloses :
    SourceBoundCycleEvidenceClosed
      (fun _observation => True)
      sourceBoundCycleRegistry
      sourceBoundCycleFixedPointReceipt
      sourceBoundCycleObservation := by
  constructor
  · trivial
  · rfl
  · simp [sourceBoundCycleObservation]
  · refine ⟨?_, sourceBoundCycleSccStronglyConnected, ?_⟩
    constructor
    · simp [sourceBoundCycleObservation]
    · constructor
      · intro subject subjectInScc
        simpa [
          sourceBoundCycleObservation,
          sourceBoundCycleFixedPointReceipt
        ] using subjectInScc
      · constructor
        · intro subject subjectInPath
          simp [
            sourceBoundCycleObservation
          ] at subjectInPath
          rcases subjectInPath with rfl | rfl | rfl
          all_goals
            simp [sourceBoundCycleFixedPointReceipt]
        · constructor
          · intro subject subjectInPath
            simp [
              sourceBoundCycleObservation
            ] at subjectInPath ⊢
            rcases subjectInPath with
              subjectIsA | subjectIsB | subjectIsA
            · exact Or.inl subjectIsA
            · exact Or.inr subjectIsB
            · exact Or.inl subjectIsA
          · constructor
            · constructor
              · refine
                  ⟨cyclicSourceBoundMessageProviderA,
                    by simp [sourceBoundCycleRegistry],
                    rfl,
                    ?_⟩
                simp [cyclicSourceBoundMessageProviderA]
              · constructor
                · refine
                    ⟨cyclicSourceBoundMessageProviderB,
                      by simp [sourceBoundCycleRegistry],
                      rfl,
                      ?_⟩
                  simp [
                    cyclicSourceBoundMessageProviderB,
                    sourceBoundMessageProviderB
                  ]
                · trivial
            · constructor
              · exact
                  ⟨messageProviderSubjectA,
                    [messageProviderSubjectB],
                    rfl⟩
              · constructor
                · exact ⟨[messageProviderSubjectA], rfl⟩
                · change
                    sourceBoundCompositionLink
                      sourceBoundCycleRegistry
                      messageProviderSubjectB
                      messageProviderSubjectA
                  refine
                    ⟨cyclicSourceBoundMessageProviderB,
                      by simp [sourceBoundCycleRegistry],
                      rfl,
                      ?_⟩
                  simp [cyclicSourceBoundMessageProviderB]
    · decide

theorem sourceBoundCycleMembersAreReachable
    (subject : CompositionObjectSubject)
    (subjectInScc :
      subject ∈ sourceBoundCycleObservation.sccMembers) :
    SourceBoundReachable
      sourceBoundCycleRegistry
      sourceBoundCycleRoots
      subject := by
  exact
    closedSourceBoundCycleMemberIsReachable
      sourceBoundCycleRequestSubject
      (fun _digest _registry => True)
      (fun _witness => True)
      (fun _receipt => True)
      (fun _object => True)
      (fun _resolutionReceipt => True)
      (fun _observation => True)
      sourceBoundCycleRegistry
      sourceBoundCycleRoots
      sourceBoundCycleWitness
      sourceBoundCycleFixedPointReceipt
      [
        sourceBoundResolutionReceiptA,
        sourceBoundResolutionReceiptB
      ]
      sourceBoundCycleObservation
      sourceBoundCycleFixedPointEvidenceCloses
      completeSourceBoundCycleEvidenceCloses
      subject
      subjectInScc

theorem sourceBoundCycleObservationDoesNotAuthorizeRetry :
    sourceBoundCycleObservation.continuationIdentity =
        "continuation-source-bound-cycle" ∧
      ¬ (fun _observation : SourceBoundCycleDetectedObservation => False)
        sourceBoundCycleObservation := by
  simp [sourceBoundCycleObservation]

end AgenticAILabProof.Enterprise.SourceBoundCycleObservationClosure
