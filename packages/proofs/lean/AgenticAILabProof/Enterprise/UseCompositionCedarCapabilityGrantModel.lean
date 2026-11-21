-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.UseCompositionCedarCapabilityGrantModel

inductive PolicyDecision where
  | allow
  | deny
  deriving DecidableEq, Repr

structure AuthorizationSubject where
  requestDigest : Nat
  policySetDigest : Nat
  entityStoreDigest : Nat
  bundleDigest : Nat
  epoch : Nat
  deriving DecidableEq, Repr

structure ValidationContext where
  authorityIdentity : Nat
  authorityGeneration : Nat
  policySnapshotIdentity : Nat
  authorizationSnapshotIdentity : Nat
  revocationSnapshotIdentity : Nat
  deriving DecidableEq, Repr

structure ProfileIdentity where
  moduleIdentity : Nat
  profileSlot : Nat
  lineageRoot : Nat
  deriving DecidableEq, Repr

structure CapabilityRequest where
  profileIdentity : ProfileIdentity
  runtimeGeneration : Nat
  requestedCapabilities : List Nat
  subject : AuthorizationSubject
  context : ValidationContext
  bridgeRegistryIdentity : Nat
  bridgeRegistryGeneration : Nat
  bridgeRegistrySemanticIdentity : Nat
  deriving DecidableEq, Repr

structure CapabilityGrant where
  profileIdentity : ProfileIdentity
  runtimeGeneration : Nat
  subject : AuthorizationSubject
  issuedContext : ValidationContext
  bridgeRegistryIdentity : Nat
  bridgeRegistryGeneration : Nat
  bridgeRegistrySemanticIdentity : Nat
  authorizedCapabilities : List Nat
  grantedCapabilities : List Nat
  deriving DecidableEq, Repr

structure DecisionReceipt where
  engineIdentity : Nat
  receiptIdentity : Nat
  subject : AuthorizationSubject
  decision : PolicyDecision
  valid : Bool
  deriving DecidableEq, Repr

def dualAllowEvidenceClosed
    (left right : DecisionReceipt) : Prop :=
  left.subject = right.subject ∧
    left.engineIdentity ≠ right.engineIdentity ∧
    left.receiptIdentity ≠ right.receiptIdentity ∧
    left.valid = true ∧
    right.valid = true ∧
    left.decision = .allow ∧
    right.decision = .allow

def capabilityConfinement
    (request : CapabilityRequest)
    (grant : CapabilityGrant) : Prop :=
  (∀ capability ∈ grant.authorizedCapabilities,
      capability ∈ request.requestedCapabilities) ∧
    (∀ capability ∈ grant.grantedCapabilities,
      capability ∈ grant.authorizedCapabilities)

def legacyAdmission
    (request : CapabilityRequest)
    (grant : CapabilityGrant)
    (left right : DecisionReceipt) : Prop :=
  dualAllowEvidenceClosed left right ∧
    left.subject = request.subject ∧
    capabilityConfinement request grant

structure SubjectContextBridgeReceipt where
  claimedAuthorityIdentity : Nat
  claimedSemanticIdentity : Nat
  registryIdentity : Nat
  registryGeneration : Nat
  policySetDigest : Nat
  policySnapshotIdentity : Nat
  deriving DecidableEq, Repr

structure SubjectContextBridgeBinding where
  authorityIdentity : Nat
  semanticIdentity : Nat
  registryIdentity : Nat
  registryGeneration : Nat
  policySetDigest : Nat
  policySnapshotIdentity : Nat
  deriving DecidableEq, Repr

structure BridgeAcceptanceAuthority where
  validate : SubjectContextBridgeReceipt → Option SubjectContextBridgeBinding
  accepted : SubjectContextBridgeBinding → Prop
  sound :
    ∀ artifact binding,
      validate artifact = some binding → accepted binding

structure BridgeAuthorityBoundNode
    (authority : BridgeAcceptanceAuthority) where
  artifact : SubjectContextBridgeReceipt
  nodeBinding : SubjectContextBridgeBinding
  validatedBinding : SubjectContextBridgeBinding
  validation : authority.validate artifact = some validatedBinding
  exactBinding : validatedBinding = nodeBinding

theorem bridgeAuthorityBoundNodeAccepted
    {authority : BridgeAcceptanceAuthority}
    (node : BridgeAuthorityBoundNode authority) :
    authority.accepted node.nodeBinding := by
  have accepted := authority.sound
    node.artifact node.validatedBinding node.validation
  rw [node.exactBinding] at accepted
  exact accepted

def SubjectContextBridgeRegistryFunctional
    (authority : BridgeAcceptanceAuthority) : Prop :=
  ∀ left right,
    authority.accepted left →
    authority.accepted right →
    left.authorityIdentity = right.authorityIdentity →
    left.semanticIdentity = right.semanticIdentity →
    left.registryIdentity = right.registryIdentity →
    left.registryGeneration = right.registryGeneration →
    left.policySetDigest = right.policySetDigest →
    left.policySnapshotIdentity = right.policySnapshotIdentity

structure GrantClosed
    (bridgeAuthority : BridgeAcceptanceAuthority)
    (bridgeNode : BridgeAuthorityBoundNode bridgeAuthority)
    (request : CapabilityRequest)
    (grant : CapabilityGrant)
    (left right : DecisionReceipt) : Prop where
  dualEvidence : dualAllowEvidenceClosed left right
  cedarSubjectBound : left.subject = request.subject
  grantSubjectBound : grant.subject = request.subject
  profileIdentityBound : grant.profileIdentity = request.profileIdentity
  runtimeGenerationBound : grant.runtimeGeneration = request.runtimeGeneration
  validationContextBound : grant.issuedContext = request.context
  bridgeRegistryFunctional :
    SubjectContextBridgeRegistryFunctional bridgeAuthority
  bridgeAuthorityIdentityBound :
    bridgeNode.nodeBinding.authorityIdentity = request.context.authorityIdentity
  requestBridgeSemanticIdentityBound :
    bridgeNode.nodeBinding.semanticIdentity =
      request.bridgeRegistrySemanticIdentity
  grantBridgeSemanticIdentityBound :
    grant.bridgeRegistrySemanticIdentity =
      request.bridgeRegistrySemanticIdentity
  requestBridgeRegistryIdentityBound :
    bridgeNode.nodeBinding.registryIdentity = request.bridgeRegistryIdentity
  grantBridgeRegistryIdentityBound :
    grant.bridgeRegistryIdentity = request.bridgeRegistryIdentity
  requestBridgeRegistryGenerationBound :
    bridgeNode.nodeBinding.registryGeneration = request.bridgeRegistryGeneration
  grantBridgeRegistryGenerationBound :
    grant.bridgeRegistryGeneration = request.bridgeRegistryGeneration
  bridgePolicyDigestBound :
    bridgeNode.nodeBinding.policySetDigest = request.subject.policySetDigest
  bridgePolicySnapshotBound :
    bridgeNode.nodeBinding.policySnapshotIdentity =
      request.context.policySnapshotIdentity
  confined : capabilityConfinement request grant

def sampleSubject : AuthorizationSubject where
  requestDigest := 101
  policySetDigest := 7
  entityStoreDigest := 3
  bundleDigest := 19
  epoch := 11

def sampleContext : ValidationContext where
  authorityIdentity := 17
  authorityGeneration := 11
  policySnapshotIdentity := 7
  authorizationSnapshotIdentity := 5
  revocationSnapshotIdentity := 3

def alphaIdentity : ProfileIdentity where
  moduleIdentity := 42
  profileSlot := 7
  lineageRoot := 100

def betaIdentity : ProfileIdentity where
  moduleIdentity := 42
  profileSlot := 8
  lineageRoot := 101

def sampleRequest
    (profileIdentity : ProfileIdentity)
    (generation : Nat) : CapabilityRequest where
  profileIdentity := profileIdentity
  runtimeGeneration := generation
  requestedCapabilities := [23]
  subject := sampleSubject
  context := sampleContext
  bridgeRegistryIdentity := 29
  bridgeRegistryGeneration := 3
  bridgeRegistrySemanticIdentity := 31

def sampleGrant
    (profileIdentity : ProfileIdentity)
    (generation : Nat) : CapabilityGrant where
  profileIdentity := profileIdentity
  runtimeGeneration := generation
  subject := sampleSubject
  issuedContext := sampleContext
  bridgeRegistryIdentity := 29
  bridgeRegistryGeneration := 3
  bridgeRegistrySemanticIdentity := 31
  authorizedCapabilities := [23]
  grantedCapabilities := [23]

def sampleReceipt
    (engineIdentity receiptIdentity : Nat) : DecisionReceipt where
  engineIdentity := engineIdentity
  receiptIdentity := receiptIdentity
  subject := sampleSubject
  decision := .allow
  valid := true

def bridgeReceiptAt (snapshot : Nat) : SubjectContextBridgeReceipt where
  claimedAuthorityIdentity := 17
  claimedSemanticIdentity := 31
  registryIdentity := 29
  registryGeneration := 3
  policySetDigest := 7
  policySnapshotIdentity := snapshot

def LegacyBridgeReceiptValid := SubjectContextBridgeReceipt → Prop

def LegacyBridgeRegistryFunctional
    (valid : LegacyBridgeReceiptValid) : Prop :=
  ∀ left right,
    valid left →
    valid right →
    left.registryIdentity = right.registryIdentity →
    left.registryGeneration = right.registryGeneration →
    left.policySetDigest = right.policySetDigest →
    left.policySnapshotIdentity = right.policySnapshotIdentity

def acceptAllBridgeReceipts : LegacyBridgeReceiptValid :=
  fun _ => True

theorem acceptAllBridgeReceiptsAreNotFunctional :
    ¬ LegacyBridgeRegistryFunctional acceptAllBridgeReceipts := by
  intro functional
  have conflict := functional
    (bridgeReceiptAt 7)
    (bridgeReceiptAt 8)
    trivial
    trivial
    rfl
    rfl
    rfl
  exact (by decide : (7 : Nat) ≠ 8) conflict

def forgedSingletonReceipt : SubjectContextBridgeReceipt where
  claimedAuthorityIdentity := 999
  claimedSemanticIdentity := 31
  registryIdentity := 29
  registryGeneration := 3
  policySetDigest := 7
  policySnapshotIdentity := 7

def forgedSingletonValid : LegacyBridgeReceiptValid :=
  fun receipt => receipt = forgedSingletonReceipt

theorem forgedSingletonIsFunctionalButUnauthorized :
    LegacyBridgeRegistryFunctional forgedSingletonValid ∧
      forgedSingletonReceipt.claimedAuthorityIdentity ≠
        sampleContext.authorityIdentity := by
  constructor
  · intro left right leftValid rightValid _ _ _
    rw [leftValid, rightValid]
  · decide

theorem legacyAcceptsCrossProfileGrantReuse :
    legacyAdmission
        (sampleRequest betaIdentity 11)
        (sampleGrant alphaIdentity 11)
        (sampleReceipt 1 101)
        (sampleReceipt 2 102) ∧
      (sampleGrant alphaIdentity 11).profileIdentity ≠
        (sampleRequest betaIdentity 11).profileIdentity := by
  simp [legacyAdmission, dualAllowEvidenceClosed, capabilityConfinement,
    sampleRequest, sampleGrant, sampleReceipt, sampleSubject, sampleContext,
    alphaIdentity, betaIdentity]

theorem legacyAcceptsCrossGenerationGrantReuse :
    legacyAdmission
        (sampleRequest alphaIdentity 12)
        (sampleGrant alphaIdentity 11)
        (sampleReceipt 1 101)
        (sampleReceipt 2 102) ∧
      (sampleGrant alphaIdentity 11).runtimeGeneration ≠
        (sampleRequest alphaIdentity 12).runtimeGeneration := by
  simp [legacyAdmission, dualAllowEvidenceClosed, capabilityConfinement,
    sampleRequest, sampleGrant, sampleReceipt, sampleSubject, sampleContext,
    alphaIdentity]

theorem closedRejectsCrossProfileReuse
    {bridgeAuthority : BridgeAcceptanceAuthority}
    {bridgeNode : BridgeAuthorityBoundNode bridgeAuthority}
    {request : CapabilityRequest}
    {grant : CapabilityGrant}
    {left right : DecisionReceipt}
    (closed : GrantClosed bridgeAuthority bridgeNode request grant left right)
    (mismatch : grant.profileIdentity ≠ request.profileIdentity) : False :=
  mismatch closed.profileIdentityBound

theorem closedRejectsCrossGenerationReuse
    {bridgeAuthority : BridgeAcceptanceAuthority}
    {bridgeNode : BridgeAuthorityBoundNode bridgeAuthority}
    {request : CapabilityRequest}
    {grant : CapabilityGrant}
    {left right : DecisionReceipt}
    (closed : GrantClosed bridgeAuthority bridgeNode request grant left right)
    (mismatch : grant.runtimeGeneration ≠ request.runtimeGeneration) : False :=
  mismatch closed.runtimeGenerationBound

theorem closedRejectsStaleContext
    {bridgeAuthority : BridgeAcceptanceAuthority}
    {bridgeNode : BridgeAuthorityBoundNode bridgeAuthority}
    {request : CapabilityRequest}
    {grant : CapabilityGrant}
    {left right : DecisionReceipt}
    (closed : GrantClosed bridgeAuthority bridgeNode request grant left right)
    (mismatch : grant.issuedContext ≠ request.context) : False :=
  mismatch closed.validationContextBound

theorem closedConfinesEveryGrantedCapability
    {bridgeAuthority : BridgeAcceptanceAuthority}
    {bridgeNode : BridgeAuthorityBoundNode bridgeAuthority}
    {request : CapabilityRequest}
    {grant : CapabilityGrant}
    {left right : DecisionReceipt}
    (closed : GrantClosed bridgeAuthority bridgeNode request grant left right)
    {capability : Nat}
    (granted : capability ∈ grant.grantedCapabilities) :
    capability ∈ request.requestedCapabilities := by
  exact closed.confined.1 capability
    (closed.confined.2 capability granted)

theorem closedRequiresVersionedSubjectContextBridge
    {bridgeAuthority : BridgeAcceptanceAuthority}
    {bridgeNode : BridgeAuthorityBoundNode bridgeAuthority}
    {request : CapabilityRequest}
    {grant : CapabilityGrant}
    {left right : DecisionReceipt}
    (closed : GrantClosed bridgeAuthority bridgeNode request grant left right) :
    bridgeAuthority.accepted bridgeNode.nodeBinding ∧
      bridgeNode.nodeBinding.authorityIdentity = request.context.authorityIdentity ∧
      bridgeNode.nodeBinding.semanticIdentity =
        request.bridgeRegistrySemanticIdentity ∧
      bridgeNode.nodeBinding.registryIdentity = request.bridgeRegistryIdentity ∧
      bridgeNode.nodeBinding.registryGeneration = request.bridgeRegistryGeneration ∧
      bridgeNode.nodeBinding.policySetDigest = request.subject.policySetDigest ∧
      bridgeNode.nodeBinding.policySnapshotIdentity =
        request.context.policySnapshotIdentity := by
  exact ⟨bridgeAuthorityBoundNodeAccepted bridgeNode,
    closed.bridgeAuthorityIdentityBound,
    closed.requestBridgeSemanticIdentityBound,
    closed.requestBridgeRegistryIdentityBound,
    closed.requestBridgeRegistryGenerationBound,
    closed.bridgePolicyDigestBound,
    closed.bridgePolicySnapshotBound⟩

theorem closedRejectsBridgeRegistryGenerationReplay
    {bridgeAuthority : BridgeAcceptanceAuthority}
    {bridgeNode : BridgeAuthorityBoundNode bridgeAuthority}
    {request : CapabilityRequest}
    {grant : CapabilityGrant}
    {left right : DecisionReceipt}
    (closed : GrantClosed bridgeAuthority bridgeNode request grant left right)
    (mismatch :
      bridgeNode.nodeBinding.registryGeneration ≠
        request.bridgeRegistryGeneration) : False :=
  mismatch closed.requestBridgeRegistryGenerationBound

theorem closedBridgeMappingIsUnique
    {bridgeAuthority : BridgeAcceptanceAuthority}
    {bridgeNode : BridgeAuthorityBoundNode bridgeAuthority}
    {other : SubjectContextBridgeBinding}
    {request : CapabilityRequest}
    {grant : CapabilityGrant}
    {left right : DecisionReceipt}
    (closed : GrantClosed bridgeAuthority bridgeNode request grant left right)
    (otherAccepted : bridgeAuthority.accepted other)
    (sameAuthorityIdentity :
      other.authorityIdentity = bridgeNode.nodeBinding.authorityIdentity)
    (sameSemanticIdentity :
      other.semanticIdentity = bridgeNode.nodeBinding.semanticIdentity)
    (sameRegistryIdentity :
      other.registryIdentity = bridgeNode.nodeBinding.registryIdentity)
    (sameRegistryGeneration :
      other.registryGeneration = bridgeNode.nodeBinding.registryGeneration)
    (samePolicyDigest :
      other.policySetDigest = bridgeNode.nodeBinding.policySetDigest) :
    other.policySnapshotIdentity =
      bridgeNode.nodeBinding.policySnapshotIdentity :=
  closed.bridgeRegistryFunctional
    other bridgeNode.nodeBinding otherAccepted
    (bridgeAuthorityBoundNodeAccepted bridgeNode)
    sameAuthorityIdentity sameSemanticIdentity sameRegistryIdentity
    sameRegistryGeneration samePolicyDigest

end AgenticAILabProof.Enterprise.UseCompositionCedarCapabilityGrantModel
