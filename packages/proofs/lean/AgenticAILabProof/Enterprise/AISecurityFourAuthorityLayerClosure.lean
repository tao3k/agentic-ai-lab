-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.AISecurityFourAuthorityLayerClosure

structure AuthorityChain where
  normativeBound : Prop
  formalBound : Prop
  executableRefinementBound : Prop
  empiricalQualificationBound : Prop
  noOpenApplicableCounterexample : Prop

def FourLayerClosed (chain : AuthorityChain) : Prop :=
  chain.normativeBound ∧
    chain.formalBound ∧
    chain.executableRefinementBound ∧
    chain.empiricalQualificationBound ∧
    chain.noOpenApplicableCounterexample

structure PresentationProjection where
  rfcClaimId : String
  leanDeclarationSetId : String
  traceRoot : String
  empiricalRunId : String

theorem fourLayerClosureRequiresNormative
    (chain : AuthorityChain) (closed : FourLayerClosed chain) :
    chain.normativeBound := closed.1

theorem fourLayerClosureRequiresFormal
    (chain : AuthorityChain) (closed : FourLayerClosed chain) :
    chain.formalBound := closed.2.1

theorem fourLayerClosureRequiresExecutableRefinement
    (chain : AuthorityChain) (closed : FourLayerClosed chain) :
    chain.executableRefinementBound := closed.2.2.1

theorem fourLayerClosureRequiresEmpiricalQualification
    (chain : AuthorityChain) (closed : FourLayerClosed chain) :
    chain.empiricalQualificationBound := closed.2.2.2.1

theorem openApplicableCounterexamplePreventsClosure
    (chain : AuthorityChain)
    (counterexampleOpen : ¬ chain.noOpenApplicableCounterexample) :
    ¬ FourLayerClosed chain := by
  intro closed
  exact counterexampleOpen closed.2.2.2.2

theorem presentationCannotSubstituteForNormativeAuthority
    (chain : AuthorityChain) (_presentation : PresentationProjection)
    (missing : ¬ chain.normativeBound) : ¬ FourLayerClosed chain := by
  intro closed
  exact missing closed.1

theorem presentationCannotSubstituteForFormalAuthority
    (chain : AuthorityChain) (_presentation : PresentationProjection)
    (missing : ¬ chain.formalBound) : ¬ FourLayerClosed chain := by
  intro closed
  exact missing closed.2.1

theorem presentationCannotSubstituteForExecutableRefinement
    (chain : AuthorityChain) (_presentation : PresentationProjection)
    (missing : ¬ chain.executableRefinementBound) : ¬ FourLayerClosed chain := by
  intro closed
  exact missing closed.2.2.1

theorem presentationCannotSubstituteForEmpiricalQualification
    (chain : AuthorityChain) (_presentation : PresentationProjection)
    (missing : ¬ chain.empiricalQualificationBound) : ¬ FourLayerClosed chain := by
  intro closed
  exact missing closed.2.2.2.1

theorem allAuthorityBindingsCloseTheAbstractCycle
    (chain : AuthorityChain)
    (normative : chain.normativeBound)
    (formal : chain.formalBound)
    (executable : chain.executableRefinementBound)
    (empirical : chain.empiricalQualificationBound)
    (noCounterexample : chain.noOpenApplicableCounterexample) :
    FourLayerClosed chain :=
  ⟨normative, formal, executable, empirical, noCounterexample⟩

end AgenticAILabProof.Enterprise.AISecurityFourAuthorityLayerClosure
