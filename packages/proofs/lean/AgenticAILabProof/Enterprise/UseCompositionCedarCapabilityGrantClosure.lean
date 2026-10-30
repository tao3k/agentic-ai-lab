-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.AgentActionEvidenceEnvelopeClosure
import AgenticAILabProof.Enterprise.CedarDualEngineAuthorization
import AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure
import AgenticAILabProof.Enterprise.ReceiptAuthorityBindingClosure
import AgenticAILabProof.Enterprise.UseCompositionBindingIdentityDemandGapModel
import AgenticAILabProof.Enterprise.UseCompositionCedarCapabilityGrantModel

namespace AgenticAILabProof.Enterprise.UseCompositionCedarCapabilityGrantClosure

open AgenticAILabProof.Enterprise.AgentActionEvidenceEnvelopeClosure
open AgenticAILabProof.Enterprise.CedarDualEngineAuthorization
open AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure
open AgenticAILabProof.Enterprise.ReceiptAuthorityBindingClosure
open AgenticAILabProof.Enterprise.UseCompositionBindingIdentityDemandGapModel

/-!
`use-composition` profiles request capabilities; they never mint grants.  A
usable grant therefore has to close over both Cedar engines and the exact
composition identity, runtime generation, and validation context that asked
for it.
-/

structure CompositionCapabilityRequest where
  profileIdentity : OriginAwareProfileIdentity
  runtimeGeneration : Nat
  requestedCapabilities : List AgentCapabilityId
  authorizationSubject : AuthorizationSubject
  validationContext : ReceiptValidationContext
  bridgeRegistryIdentity : String
  bridgeRegistryGeneration : Nat
  bridgeRegistrySemanticIdentity : String
  deriving DecidableEq

structure CompositionCapabilityGrant where
  profileIdentity : OriginAwareProfileIdentity
  runtimeGeneration : Nat
  authorizationSubject : AuthorizationSubject
  issuedContext : ReceiptValidationContext
  bridgeRegistryIdentity : String
  bridgeRegistryGeneration : Nat
  bridgeRegistrySemanticIdentity : String
  authorizedCapabilities : List AgentCapabilityId
  grantedCapabilities : List AgentCapabilityId
  deriving DecidableEq

def capabilityConfinement
    (request : CompositionCapabilityRequest)
    (grant : CompositionCapabilityGrant) : Prop :=
  (∀ capability ∈ grant.authorizedCapabilities,
      capability ∈ request.requestedCapabilities) ∧
    (∀ capability ∈ grant.grantedCapabilities,
      capability ∈ grant.authorizedCapabilities)

structure SubjectContextBridgeReceipt where
  claimedAuthorityIdentity : Nat
  claimedSemanticIdentity : String
  registryIdentity : String
  registryGeneration : Nat
  policySetDigest : PolicySetDigest
  policySnapshotIdentity : Nat
  deriving DecidableEq

structure SubjectContextBridgeBinding where
  authorityIdentity : Nat
  semanticIdentity : String
  registryIdentity : String
  registryGeneration : Nat
  policySetDigest : PolicySetDigest
  policySnapshotIdentity : Nat
  deriving DecidableEq

abbrev SubjectContextBridgeAcceptanceAuthority :=
  AcceptanceAuthority SubjectContextBridgeReceipt SubjectContextBridgeBinding

abbrev SubjectContextBridgeAuthorityBoundNode
    (authority : SubjectContextBridgeAcceptanceAuthority) :=
  AuthorityBoundNode
    SubjectContextBridgeReceipt SubjectContextBridgeBinding authority

theorem subjectContextBridgeAuthorityBoundNodeAccepted
    {authority : SubjectContextBridgeAcceptanceAuthority}
    (node : SubjectContextBridgeAuthorityBoundNode authority) :
    authority.accepted node.nodeBinding := by
  have accepted := authority.sound
    node.artifact node.validatedBinding node.validation
  rw [node.exactBinding] at accepted
  exact accepted

def SubjectContextBridgeRegistryFunctional
    (authority : SubjectContextBridgeAcceptanceAuthority) : Prop :=
  ∀ left right,
    authority.accepted left →
    authority.accepted right →
    left.authorityIdentity = right.authorityIdentity →
    left.semanticIdentity = right.semanticIdentity →
    left.registryIdentity = right.registryIdentity →
    left.registryGeneration = right.registryGeneration →
    left.policySetDigest = right.policySetDigest →
    left.policySnapshotIdentity = right.policySnapshotIdentity

def legacyDualEngineAdmission
    (semantics : DecisionSemantics)
    (valid : DecisionReceiptValid)
    (request : CompositionCapabilityRequest)
    (grant : CompositionCapabilityGrant)
    (left right : DecisionReceipt) : Prop :=
  dualDecisionEvidenceClosed semantics valid left right ∧
    left.subject = request.authorizationSubject ∧
    left.decision = .allow ∧
    capabilityConfinement request grant

structure CompositionCedarGrantClosed
    (semantics : DecisionSemantics)
    (valid : DecisionReceiptValid)
    (bridgeAuthority : SubjectContextBridgeAcceptanceAuthority)
    (bridgeNode : SubjectContextBridgeAuthorityBoundNode bridgeAuthority)
    (request : CompositionCapabilityRequest)
    (grant : CompositionCapabilityGrant)
    (left right : DecisionReceipt) : Prop where
  dualEvidence : dualDecisionEvidenceClosed semantics valid left right
  cedarSubjectBound : left.subject = request.authorizationSubject
  grantSubjectBound : grant.authorizationSubject = request.authorizationSubject
  permitDecision : left.decision = .allow
  profileIdentityBound : grant.profileIdentity = request.profileIdentity
  runtimeGenerationBound : grant.runtimeGeneration = request.runtimeGeneration
  validationContextBound : grant.issuedContext = request.validationContext
  bridgeRegistryFunctional :
    SubjectContextBridgeRegistryFunctional bridgeAuthority
  bridgeAuthorityIdentityBound :
    bridgeNode.nodeBinding.authorityIdentity =
      request.validationContext.authorityIdentity
  requestBridgeSemanticIdentityBound :
    bridgeNode.nodeBinding.semanticIdentity =
      request.bridgeRegistrySemanticIdentity
  grantBridgeSemanticIdentityBound :
    grant.bridgeRegistrySemanticIdentity = request.bridgeRegistrySemanticIdentity
  requestBridgeRegistryIdentityBound :
    bridgeNode.nodeBinding.registryIdentity = request.bridgeRegistryIdentity
  grantBridgeRegistryIdentityBound :
    grant.bridgeRegistryIdentity = request.bridgeRegistryIdentity
  requestBridgeRegistryGenerationBound :
    bridgeNode.nodeBinding.registryGeneration = request.bridgeRegistryGeneration
  grantBridgeRegistryGenerationBound :
    grant.bridgeRegistryGeneration = request.bridgeRegistryGeneration
  bridgePolicyDigestBound :
    bridgeNode.nodeBinding.policySetDigest =
      request.authorizationSubject.policySetDigest
  bridgePolicySnapshotBound :
    bridgeNode.nodeBinding.policySnapshotIdentity =
      request.validationContext.policySnapshotIdentity
  confined : capabilityConfinement request grant

def sampleSubject : AuthorizationSubject where
  requestDigest := "request:compose"
  policySetDigest := "policy:v7"
  entityStoreDigest := "entities:v3"
  bundleDigest := "bundle:wendao"
  profileIdentities := ["profile:alpha", "profile:beta"]
  governanceAssessmentDigest := "governance:accepted"
  subjectSnapshotDigest := "subject:compose"
  epoch := 11

def sampleContext : ReceiptValidationContext where
  authorityIdentity := 17
  authorityGeneration := 11
  policySnapshotIdentity := 7
  authorizationSnapshotIdentity := 5
  revocationSnapshotIdentity := 3

def sampleAlphaIdentity : OriginAwareProfileIdentity where
  origin := .moduleExport 42 7
  lineageRoot := 100

def sampleBetaIdentity : OriginAwareProfileIdentity where
  origin := .moduleExport 42 8
  lineageRoot := 101

def sampleRequest
    (profileIdentity : OriginAwareProfileIdentity)
    (generation : Nat) :
    CompositionCapabilityRequest where
  profileIdentity := profileIdentity
  runtimeGeneration := generation
  requestedCapabilities := ["knowledge.read"]
  authorizationSubject := sampleSubject
  validationContext := sampleContext
  bridgeRegistryIdentity := "bridge-registry:v1"
  bridgeRegistryGeneration := 3
  bridgeRegistrySemanticIdentity := "bridge-registry-semantics:v1"

def sampleGrant
    (profileIdentity : OriginAwareProfileIdentity)
    (generation : Nat) :
    CompositionCapabilityGrant where
  profileIdentity := profileIdentity
  runtimeGeneration := generation
  authorizationSubject := sampleSubject
  issuedContext := sampleContext
  bridgeRegistryIdentity := "bridge-registry:v1"
  bridgeRegistryGeneration := 3
  bridgeRegistrySemanticIdentity := "bridge-registry-semantics:v1"
  authorizedCapabilities := ["knowledge.read"]
  grantedCapabilities := ["knowledge.read"]

def sampleSemantics : DecisionSemantics := fun _ => .allow

def sampleValid : DecisionReceiptValid := fun _ => True

def sampleDecisionReceipt
    (engineId receiptId : String) : DecisionReceipt where
  engineId := engineId
  receiptId := receiptId
  subject := sampleSubject
  decision := .allow

def sampleBridgeReceipt (snapshot : Nat) : SubjectContextBridgeReceipt where
  claimedAuthorityIdentity := 17
  claimedSemanticIdentity := "bridge-registry-semantics:v1"
  registryIdentity := "bridge-registry:v1"
  registryGeneration := 3
  policySetDigest := "policy:v7"
  policySnapshotIdentity := snapshot

def LegacySubjectContextBridgeReceiptValid :=
  SubjectContextBridgeReceipt → Prop

def LegacySubjectContextBridgeRegistryFunctional
    (valid : LegacySubjectContextBridgeReceiptValid) : Prop :=
  ∀ left right,
    valid left →
    valid right →
    left.registryIdentity = right.registryIdentity →
    left.registryGeneration = right.registryGeneration →
    left.policySetDigest = right.policySetDigest →
    left.policySnapshotIdentity = right.policySnapshotIdentity

def acceptAllBridgeReceipts : LegacySubjectContextBridgeReceiptValid :=
  fun _ => True

theorem acceptAllBridgeReceiptsAreNotFunctional :
    ¬ LegacySubjectContextBridgeRegistryFunctional acceptAllBridgeReceipts := by
  intro functional
  have conflict := functional
    (sampleBridgeReceipt 7)
    (sampleBridgeReceipt 8)
    trivial
    trivial
    rfl
    rfl
    rfl
  exact (by decide : (7 : Nat) ≠ 8) conflict

def forgedSingletonBridgeReceipt : SubjectContextBridgeReceipt where
  claimedAuthorityIdentity := 999
  claimedSemanticIdentity := "bridge-registry-semantics:v1"
  registryIdentity := "bridge-registry:v1"
  registryGeneration := 3
  policySetDigest := "policy:v7"
  policySnapshotIdentity := 7

def forgedSingletonBridgeValid : LegacySubjectContextBridgeReceiptValid :=
  fun receipt => receipt = forgedSingletonBridgeReceipt

theorem forgedSingletonBridgeIsFunctionalButUnauthorized :
    LegacySubjectContextBridgeRegistryFunctional forgedSingletonBridgeValid ∧
      forgedSingletonBridgeReceipt.claimedAuthorityIdentity ≠
        sampleContext.authorityIdentity := by
  constructor
  · intro left right leftValid rightValid _ _ _
    rw [leftValid, rightValid]
  · decide

theorem legacyAdmissionAcceptsCrossProfileGrantReuse :
    legacyDualEngineAdmission
        sampleSemantics
        sampleValid
        (sampleRequest sampleBetaIdentity 11)
        (sampleGrant sampleAlphaIdentity 11)
        (sampleDecisionReceipt "cedar-spec" "receipt:left")
        (sampleDecisionReceipt "cedar-runtime" "receipt:right") ∧
      (sampleGrant sampleAlphaIdentity 11).profileIdentity ≠
        (sampleRequest sampleBetaIdentity 11).profileIdentity := by
  simp [legacyDualEngineAdmission, dualDecisionEvidenceClosed,
    decisionCorrect, sampleSemantics, sampleValid, sampleDecisionReceipt,
    sampleRequest, sampleGrant, capabilityConfinement, sampleSubject,
    sampleContext, sampleAlphaIdentity, sampleBetaIdentity]

theorem legacyAdmissionAcceptsCrossGenerationGrantReuse :
    legacyDualEngineAdmission
        sampleSemantics
        sampleValid
        (sampleRequest sampleAlphaIdentity 12)
        (sampleGrant sampleAlphaIdentity 11)
        (sampleDecisionReceipt "cedar-spec" "receipt:left")
        (sampleDecisionReceipt "cedar-runtime" "receipt:right") ∧
      (sampleGrant sampleAlphaIdentity 11).runtimeGeneration ≠
        (sampleRequest sampleAlphaIdentity 12).runtimeGeneration := by
  simp [legacyDualEngineAdmission, dualDecisionEvidenceClosed,
    decisionCorrect, sampleSemantics, sampleValid, sampleDecisionReceipt,
    sampleRequest, sampleGrant, capabilityConfinement, sampleSubject,
    sampleContext, sampleAlphaIdentity]

theorem closedGrantRejectsCrossProfileReuse
    {semantics : DecisionSemantics}
    {valid : DecisionReceiptValid}
    {bridgeAuthority : SubjectContextBridgeAcceptanceAuthority}
    {bridgeNode : SubjectContextBridgeAuthorityBoundNode bridgeAuthority}
    {request : CompositionCapabilityRequest}
    {grant : CompositionCapabilityGrant}
    {left right : DecisionReceipt}
    (closed : CompositionCedarGrantClosed semantics valid bridgeAuthority bridgeNode request grant left right)
    (mismatch : grant.profileIdentity ≠ request.profileIdentity) : False :=
  mismatch closed.profileIdentityBound

theorem closedGrantRejectsCrossGenerationReuse
    {semantics : DecisionSemantics}
    {valid : DecisionReceiptValid}
    {bridgeAuthority : SubjectContextBridgeAcceptanceAuthority}
    {bridgeNode : SubjectContextBridgeAuthorityBoundNode bridgeAuthority}
    {request : CompositionCapabilityRequest}
    {grant : CompositionCapabilityGrant}
    {left right : DecisionReceipt}
    (closed : CompositionCedarGrantClosed semantics valid bridgeAuthority bridgeNode request grant left right)
    (mismatch : grant.runtimeGeneration ≠ request.runtimeGeneration) : False :=
  mismatch closed.runtimeGenerationBound

theorem closedGrantRejectsStalePolicyOrAuthorityContext
    {semantics : DecisionSemantics}
    {valid : DecisionReceiptValid}
    {bridgeAuthority : SubjectContextBridgeAcceptanceAuthority}
    {bridgeNode : SubjectContextBridgeAuthorityBoundNode bridgeAuthority}
    {request : CompositionCapabilityRequest}
    {grant : CompositionCapabilityGrant}
    {left right : DecisionReceipt}
    (closed : CompositionCedarGrantClosed semantics valid bridgeAuthority bridgeNode request grant left right)
    (mismatch : grant.issuedContext ≠ request.validationContext) : False :=
  mismatch closed.validationContextBound

theorem closedGrantRejectsDifferentCedarSubject
    {semantics : DecisionSemantics}
    {valid : DecisionReceiptValid}
    {bridgeAuthority : SubjectContextBridgeAcceptanceAuthority}
    {bridgeNode : SubjectContextBridgeAuthorityBoundNode bridgeAuthority}
    {request : CompositionCapabilityRequest}
    {grant : CompositionCapabilityGrant}
    {left right : DecisionReceipt}
    (closed : CompositionCedarGrantClosed semantics valid bridgeAuthority bridgeNode request grant left right)
    (mismatch : grant.authorizationSubject ≠ request.authorizationSubject) : False :=
  mismatch closed.grantSubjectBound

theorem closedGrantConfinesEveryGrantedCapability
    {semantics : DecisionSemantics}
    {valid : DecisionReceiptValid}
    {bridgeAuthority : SubjectContextBridgeAcceptanceAuthority}
    {bridgeNode : SubjectContextBridgeAuthorityBoundNode bridgeAuthority}
    {request : CompositionCapabilityRequest}
    {grant : CompositionCapabilityGrant}
    {left right : DecisionReceipt}
    (closed : CompositionCedarGrantClosed semantics valid bridgeAuthority bridgeNode request grant left right)
    {capability : AgentCapabilityId}
    (granted : capability ∈ grant.grantedCapabilities) :
    capability ∈ request.requestedCapabilities := by
  exact closed.confined.1 capability
    (closed.confined.2 capability granted)

theorem closedGrantUsesOneCedarSubject
    {semantics : DecisionSemantics}
    {valid : DecisionReceiptValid}
    {bridgeAuthority : SubjectContextBridgeAcceptanceAuthority}
    {bridgeNode : SubjectContextBridgeAuthorityBoundNode bridgeAuthority}
    {request : CompositionCapabilityRequest}
    {grant : CompositionCapabilityGrant}
    {left right : DecisionReceipt}
    (closed : CompositionCedarGrantClosed semantics valid bridgeAuthority bridgeNode request grant left right) :
    left.subject = right.subject ∧
      left.subject = grant.authorizationSubject := by
  constructor
  · exact closed.dualEvidence.1
  · exact closed.cedarSubjectBound.trans closed.grantSubjectBound.symm

theorem closedGrantRequiresVersionedSubjectContextBridge
    {semantics : DecisionSemantics}
    {valid : DecisionReceiptValid}
    {bridgeAuthority : SubjectContextBridgeAcceptanceAuthority}
    {bridgeNode : SubjectContextBridgeAuthorityBoundNode bridgeAuthority}
    {request : CompositionCapabilityRequest}
    {grant : CompositionCapabilityGrant}
    {left right : DecisionReceipt}
    (closed : CompositionCedarGrantClosed semantics valid bridgeAuthority bridgeNode request grant left right) :
    bridgeAuthority.accepted bridgeNode.nodeBinding ∧
      bridgeNode.nodeBinding.authorityIdentity =
        request.validationContext.authorityIdentity ∧
      bridgeNode.nodeBinding.semanticIdentity =
        request.bridgeRegistrySemanticIdentity ∧
      bridgeNode.nodeBinding.registryIdentity = request.bridgeRegistryIdentity ∧
      bridgeNode.nodeBinding.registryGeneration = request.bridgeRegistryGeneration ∧
      bridgeNode.nodeBinding.policySetDigest =
        request.authorizationSubject.policySetDigest ∧
      bridgeNode.nodeBinding.policySnapshotIdentity =
        request.validationContext.policySnapshotIdentity := by
  exact ⟨subjectContextBridgeAuthorityBoundNodeAccepted bridgeNode,
    closed.bridgeAuthorityIdentityBound,
    closed.requestBridgeSemanticIdentityBound,
    closed.requestBridgeRegistryIdentityBound,
    closed.requestBridgeRegistryGenerationBound,
    closed.bridgePolicyDigestBound,
    closed.bridgePolicySnapshotBound⟩

theorem closedGrantRejectsBridgeRegistryGenerationReplay
    {semantics : DecisionSemantics}
    {valid : DecisionReceiptValid}
    {bridgeAuthority : SubjectContextBridgeAcceptanceAuthority}
    {bridgeNode : SubjectContextBridgeAuthorityBoundNode bridgeAuthority}
    {request : CompositionCapabilityRequest}
    {grant : CompositionCapabilityGrant}
    {left right : DecisionReceipt}
    (closed : CompositionCedarGrantClosed semantics valid bridgeAuthority bridgeNode request grant left right)
    (mismatch :
      bridgeNode.nodeBinding.registryGeneration ≠
        request.bridgeRegistryGeneration) : False :=
  mismatch closed.requestBridgeRegistryGenerationBound

theorem closedGrantBridgeMappingIsUnique
    {semantics : DecisionSemantics}
    {valid : DecisionReceiptValid}
    {bridgeAuthority : SubjectContextBridgeAcceptanceAuthority}
    {bridgeNode : SubjectContextBridgeAuthorityBoundNode bridgeAuthority}
    {other : SubjectContextBridgeBinding}
    {request : CompositionCapabilityRequest}
    {grant : CompositionCapabilityGrant}
    {left right : DecisionReceipt}
    (closed : CompositionCedarGrantClosed semantics valid bridgeAuthority bridgeNode request grant left right)
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
    (subjectContextBridgeAuthorityBoundNodeAccepted bridgeNode)
    sameAuthorityIdentity sameSemanticIdentity sameRegistryIdentity
    sameRegistryGeneration samePolicyDigest

def projectCedarDecision : Cedar.Spec.Decision →
    AgenticAILabProof.Enterprise.UseCompositionCedarCapabilityGrantModel.PolicyDecision
  | .allow => .allow
  | .deny => .deny

theorem closedGrantProjectsCedarAllowToAxleModel
    {semantics : DecisionSemantics}
    {valid : DecisionReceiptValid}
    {bridgeAuthority : SubjectContextBridgeAcceptanceAuthority}
    {bridgeNode : SubjectContextBridgeAuthorityBoundNode bridgeAuthority}
    {request : CompositionCapabilityRequest}
    {grant : CompositionCapabilityGrant}
    {left right : DecisionReceipt}
    (closed : CompositionCedarGrantClosed semantics valid bridgeAuthority bridgeNode request grant left right) :
    projectCedarDecision left.decision = .allow := by
  rw [closed.permitDecision]
  rfl

end AgenticAILabProof.Enterprise.UseCompositionCedarCapabilityGrantClosure
