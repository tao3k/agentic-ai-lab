-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.AISecurityEmbodiedTypedRelationGraphClosure

inductive NodeKind where
  | systemComponent
  | asset
  | threat
  | risk
  | securityRequirement
  | control
  | verificationEvidence
  | residualRisk
  | authorityAcceptance
  | runFeedback
  deriving DecidableEq, Repr

inductive RelationKind where
  | owns
  | exposedTo
  | realizes
  | derives
  | implementedBy
  | verifiedBy
  | leaves
  | acceptedBy
  | observedBy
  deriving DecidableEq, Repr

structure ArchitectureNode where
  id : String
  kind : NodeKind
  deriving DecidableEq, Repr

/-- The formal projection of the 20.02 `ArchitectureRelation` owner. -/
structure ArchitectureRelation where
  id : String
  kind : RelationKind
  sourceId : String
  sourceKind : NodeKind
  targetId : String
  targetKind : NodeKind
  forward : Bool
  evidenceRequirements : List String
  deriving DecidableEq, Repr

structure TypedRelationGraph where
  nodes : List ArchitectureNode
  relations : List ArchitectureRelation

def relationKindsCompatible : RelationKind → NodeKind → NodeKind → Prop
  | .owns, .systemComponent, .asset => True
  | .exposedTo, .asset, .threat => True
  | .realizes, .threat, .risk => True
  | .derives, .risk, .securityRequirement => True
  | .implementedBy, .securityRequirement, .control => True
  | .verifiedBy, .control, .verificationEvidence => True
  | .leaves, .risk, .residualRisk => True
  | .acceptedBy, .residualRisk, .authorityAcceptance => True
  | .observedBy, .systemComponent, .runFeedback => True
  | _, _, _ => False

def nodeDeclared
    (graph : TypedRelationGraph) (id : String) (kind : NodeKind) : Prop :=
  { id := id, kind := kind } ∈ graph.nodes

def relationWellFormed
    (graph : TypedRelationGraph) (relation : ArchitectureRelation) : Prop :=
  relation.id ≠ "" ∧
    relation.sourceId ≠ "" ∧
    relation.targetId ≠ "" ∧
    relation.forward = true ∧
    nodeDeclared graph relation.sourceId relation.sourceKind ∧
    nodeDeclared graph relation.targetId relation.targetKind ∧
    relationKindsCompatible relation.kind relation.sourceKind relation.targetKind

def typedRelationGraphClosed (graph : TypedRelationGraph) : Prop :=
  ∀ relation ∈ graph.relations, relationWellFormed graph relation

/-- Defective rule retained only as a countermodel: labels alone are accepted. -/
def labelOnlyRelationAdmission (relation : ArchitectureRelation) : Prop :=
  relation.id ≠ "" ∧ relation.sourceId ≠ "" ∧ relation.targetId ≠ ""

def threatNode : ArchitectureNode := { id := "threat-1", kind := .threat }
def controlNode : ArchitectureNode := { id := "control-1", kind := .control }

def mislabeledVerification : ArchitectureRelation :=
  { id := "relation-forged-verification"
    kind := .verifiedBy
    sourceId := threatNode.id
    sourceKind := threatNode.kind
    targetId := controlNode.id
    targetKind := controlNode.kind
    forward := true
    evidenceRequirements := ["receipt-root"] }

def labelOnlyCounterexampleGraph : TypedRelationGraph :=
  { nodes := [threatNode, controlNode]
    relations := [mislabeledVerification] }

theorem labelOnlyAdmissionAcceptsIllTypedRelation :
    labelOnlyRelationAdmission mislabeledVerification := by
  simp [labelOnlyRelationAdmission, mislabeledVerification, threatNode, controlNode]

theorem typedGraphRejectsIllTypedRelation :
    ¬typedRelationGraphClosed labelOnlyCounterexampleGraph := by
  intro closed
  have wellFormed := closed mislabeledVerification (by
    simp [labelOnlyCounterexampleGraph])
  simp [relationWellFormed, relationKindsCompatible, mislabeledVerification,
    threatNode, controlNode, nodeDeclared, labelOnlyCounterexampleGraph] at wellFormed

theorem ease003FormalBound
    (graph : TypedRelationGraph)
    (closed : typedRelationGraphClosed graph)
    (relation : ArchitectureRelation)
    (member : relation ∈ graph.relations) :
    nodeDeclared graph relation.sourceId relation.sourceKind ∧
      nodeDeclared graph relation.targetId relation.targetKind ∧
      relationKindsCompatible relation.kind relation.sourceKind relation.targetKind := by
  have wellFormed := closed relation member
  exact ⟨wellFormed.2.2.2.2.1, wellFormed.2.2.2.2.2.1,
    wellFormed.2.2.2.2.2.2⟩

end AgenticAILabProof.Enterprise.AISecurityEmbodiedTypedRelationGraphClosure
