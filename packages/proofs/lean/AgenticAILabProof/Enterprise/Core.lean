-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import YuanxuProof.Contribution.Qualification

namespace AgenticAILabProof.Enterprise.Core

open YuanxuProof.Contribution.Qualification

structure GovernanceContext
    (Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity : Type) where
  qualification :
    QualificationEnvelope
      Asset Action FacetIdentity CoreContractIdentity
  governance :
    GovernanceRelations
      Principal Asset Action Responsibility Evidence
  userAuthority : CapabilityConstraint Action
  principal : Principal
  asset : Asset
  action : Action

def BaseAdmission
    {Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity : Type}
    (context :
      GovernanceContext
        Principal Asset Action Responsibility Evidence FacetIdentity
        CoreContractIdentity) : Prop :=
  GovernedUseCompositionAdmission
    context.qualification context.governance context.userAuthority
    context.principal context.asset context.action

theorem baseAdmissionRequiresExplicitAuthorization
    {Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity : Type}
    (context :
      GovernanceContext
        Principal Asset Action Responsibility Evidence FacetIdentity
        CoreContractIdentity)
    (admitted : BaseAdmission context) :
    context.governance.authorized
      context.principal context.asset context.action :=
  governedAdmissionHasExplicitAuthorization
    context.qualification context.governance context.userAuthority
    context.principal context.asset context.action admitted

theorem baseAdmissionRequiresAuthorityEvidence
    {Principal Asset Action Responsibility Evidence FacetIdentity
      CoreContractIdentity : Type}
    (context :
      GovernanceContext
        Principal Asset Action Responsibility Evidence FacetIdentity
        CoreContractIdentity)
    (admitted : BaseAdmission context) :
    ∃ evidence,
      context.governance.authorityEvidence
        evidence context.principal context.asset context.action :=
  governedAdmissionHasAuthorityEvidence
    context.qualification context.governance context.userAuthority
    context.principal context.asset context.action admitted

end AgenticAILabProof.Enterprise.Core
