-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.AISecurityExecutableRefinementContractClosure

structure FormalTransition where
  rfcClaimId : String
  leanDeclarationSetId : String
  transitionId : String
  preStateRoot : String
  postStateRoot : String
  actionId : String
  capabilityId : String
  toolId : String
  policyRoot : String
  effectDomainRoot : String
  evidenceRequired : Prop

structure ExecutableTrace where
  rfcClaimId : String
  leanDeclarationSetId : String
  transitionId : String
  preStateRoot : String
  postStateRoot : String
  actionId : String
  capabilityId : String
  toolId : String
  policyRoot : String
  effectDomainRoot : String
  evidenceRoot : Option String

def TraceRefines (formal : FormalTransition) (trace : ExecutableTrace) : Prop :=
  trace.rfcClaimId = formal.rfcClaimId ∧
    trace.leanDeclarationSetId = formal.leanDeclarationSetId ∧
    trace.transitionId = formal.transitionId ∧
    trace.preStateRoot = formal.preStateRoot ∧
    trace.postStateRoot = formal.postStateRoot ∧
    trace.actionId = formal.actionId ∧
    trace.capabilityId = formal.capabilityId ∧
    trace.toolId = formal.toolId ∧
    trace.policyRoot = formal.policyRoot ∧
    trace.effectDomainRoot = formal.effectDomainRoot ∧
    (formal.evidenceRequired → trace.evidenceRoot.isSome)

theorem rfcClaimMismatchFailsClosed
    (formal : FormalTransition) (trace : ExecutableTrace)
    (mismatch : trace.rfcClaimId ≠ formal.rfcClaimId) :
    ¬ TraceRefines formal trace := by
  intro refines
  exact mismatch refines.1

theorem theoremSetMismatchFailsClosed
    (formal : FormalTransition) (trace : ExecutableTrace)
    (mismatch : trace.leanDeclarationSetId ≠ formal.leanDeclarationSetId) :
    ¬ TraceRefines formal trace := by
  intro refines
  exact mismatch refines.2.1

theorem transitionMismatchFailsClosed
    (formal : FormalTransition) (trace : ExecutableTrace)
    (mismatch : trace.transitionId ≠ formal.transitionId) :
    ¬ TraceRefines formal trace := by
  intro refines
  exact mismatch refines.2.2.1

theorem preStateMismatchFailsClosed
    (formal : FormalTransition) (trace : ExecutableTrace)
    (mismatch : trace.preStateRoot ≠ formal.preStateRoot) :
    ¬ TraceRefines formal trace := by
  intro refines
  exact mismatch refines.2.2.2.1

theorem postStateMismatchFailsClosed
    (formal : FormalTransition) (trace : ExecutableTrace)
    (mismatch : trace.postStateRoot ≠ formal.postStateRoot) :
    ¬ TraceRefines formal trace := by
  intro refines
  exact mismatch refines.2.2.2.2.1

theorem actionMismatchFailsClosed
    (formal : FormalTransition) (trace : ExecutableTrace)
    (mismatch : trace.actionId ≠ formal.actionId) :
    ¬ TraceRefines formal trace := by
  intro refines
  exact mismatch refines.2.2.2.2.2.1

theorem capabilityMismatchFailsClosed
    (formal : FormalTransition) (trace : ExecutableTrace)
    (mismatch : trace.capabilityId ≠ formal.capabilityId) :
    ¬ TraceRefines formal trace := by
  intro refines
  exact mismatch refines.2.2.2.2.2.2.1

theorem toolMismatchFailsClosed
    (formal : FormalTransition) (trace : ExecutableTrace)
    (mismatch : trace.toolId ≠ formal.toolId) :
    ¬ TraceRefines formal trace := by
  intro refines
  exact mismatch refines.2.2.2.2.2.2.2.1

theorem policyMismatchFailsClosed
    (formal : FormalTransition) (trace : ExecutableTrace)
    (mismatch : trace.policyRoot ≠ formal.policyRoot) :
    ¬ TraceRefines formal trace := by
  intro refines
  exact mismatch refines.2.2.2.2.2.2.2.2.1

theorem effectDomainMismatchFailsClosed
    (formal : FormalTransition) (trace : ExecutableTrace)
    (mismatch : trace.effectDomainRoot ≠ formal.effectDomainRoot) :
    ¬ TraceRefines formal trace := by
  intro refines
  exact mismatch refines.2.2.2.2.2.2.2.2.2.1

theorem requiredEvidenceMissingFailsClosed
    (formal : FormalTransition) (trace : ExecutableTrace)
    (required : formal.evidenceRequired)
    (missing : ¬ trace.evidenceRoot.isSome) :
    ¬ TraceRefines formal trace := by
  intro refines
  exact missing (refines.2.2.2.2.2.2.2.2.2.2 required)

structure EmpiricalReceipt where
  traceRoot : String
  implementationArtifactId : String
  environmentId : String
  sampleSetId : String
  oracleId : String
  empiricalRunId : String
  independentlyReplayed : Prop
  noOpenApplicableCounterexample : Prop

def EmpiricallyQualified (receipt : EmpiricalReceipt) : Prop :=
  receipt.independentlyReplayed ∧ receipt.noOpenApplicableCounterexample

theorem replayFailurePreventsEmpiricalQualification
    (receipt : EmpiricalReceipt)
    (failed : ¬ receipt.independentlyReplayed) :
    ¬ EmpiricallyQualified receipt := by
  intro qualified
  exact failed qualified.1

theorem openCounterexamplePreventsEmpiricalQualification
    (receipt : EmpiricalReceipt)
    (openCounterexample : ¬ receipt.noOpenApplicableCounterexample) :
    ¬ EmpiricallyQualified receipt := by
  intro qualified
  exact openCounterexample qualified.2

end AgenticAILabProof.Enterprise.AISecurityExecutableRefinementContractClosure
