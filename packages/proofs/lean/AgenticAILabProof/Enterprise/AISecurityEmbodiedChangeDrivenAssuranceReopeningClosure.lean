-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.AISecurityFourAuthorityLayerClosure

namespace AgenticAILabProof.Enterprise.AISecurityEmbodiedChangeDrivenAssuranceReopeningClosure

structure AssuranceContext where
  architectureRevision : String
  authorityContextRevision : String
  publicationHead : String
  evidenceEnvelopeRevision : String
  deriving DecidableEq, Repr

structure LayerEvidence where
  normativeBound : Bool
  formalBound : Bool
  executableRefinementBound : Bool
  empiricalQualificationBound : Bool
  deriving DecidableEq, Repr

def evidenceAccumulationClosed (evidence : LayerEvidence) : Prop :=
  evidence.normativeBound = true ∧
  evidence.formalBound = true ∧
  evidence.executableRefinementBound = true ∧
  evidence.empiricalQualificationBound = true

def contextBoundClosed
    (evidence : LayerEvidence)
    (boundContext currentContext : AssuranceContext)
    (noOpenApplicableCounterexample : Prop) : Prop :=
  evidenceAccumulationClosed evidence ∧
  boundContext = currentContext ∧
  noOpenApplicableCounterexample

def ContextChanged
    (boundContext currentContext : AssuranceContext) : Prop :=
  boundContext ≠ currentContext

def completeEvidence : LayerEvidence where
  normativeBound := true
  formalBound := true
  executableRefinementBound := true
  empiricalQualificationBound := true

def boundContext : AssuranceContext where
  architectureRevision := "architecture-r1"
  authorityContextRevision := "authority-r1"
  publicationHead := "head-r1"
  evidenceEnvelopeRevision := "evidence-r1"

def changedArchitectureContext : AssuranceContext where
  architectureRevision := "architecture-r2"
  authorityContextRevision := "authority-r1"
  publicationHead := "head-r1"
  evidenceEnvelopeRevision := "evidence-r1"

theorem accumulationOnlyCounterexample :
    evidenceAccumulationClosed completeEvidence ∧
    ContextChanged boundContext changedArchitectureContext := by
  simp [
    evidenceAccumulationClosed,
    completeEvidence,
    ContextChanged,
    boundContext,
    changedArchitectureContext
  ]

theorem contextBoundClosureRejectsChangedArchitecture :
    ¬ contextBoundClosed
      completeEvidence
      boundContext
      changedArchitectureContext
      True := by
  simp [
    contextBoundClosed,
    boundContext,
    changedArchitectureContext
  ]

def EASE004FormalBound : Prop :=
  ∀ (evidence : LayerEvidence)
    (bound current : AssuranceContext)
    (noOpenApplicableCounterexample : Prop),
    ContextChanged bound current →
    ¬ contextBoundClosed
      evidence
      bound
      current
      noOpenApplicableCounterexample

theorem ease004FormalBound : EASE004FormalBound := by
  intro evidence bound current noOpen changed closed
  exact changed closed.2.1

theorem admittedClosureRetainsCurrentContext
    (evidence : LayerEvidence)
    (bound current : AssuranceContext)
    (noOpenApplicableCounterexample : Prop)
    (closed : contextBoundClosed
      evidence
      bound
      current
      noOpenApplicableCounterexample) :
    bound = current :=
  closed.2.1

end AgenticAILabProof.Enterprise.AISecurityEmbodiedChangeDrivenAssuranceReopeningClosure
