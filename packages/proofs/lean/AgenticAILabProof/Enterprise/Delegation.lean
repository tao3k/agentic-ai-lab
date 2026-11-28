-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import YuanxuProof.Admission.Federation

namespace AgenticAILabProof.Enterprise.Delegation

structure Admitted
    (CapabilityIdentity Scope ActionRole
      DelegationEvidenceIdentity RevocationObservationIdentity : Type) where
  attenuation :
    YuanxuProof.Admission.Federation.CapabilityAttenuation
      CapabilityIdentity Scope ActionRole
  delegationEvidenceIdentity : DelegationEvidenceIdentity
  revocationObservationIdentity : RevocationObservationIdentity
  delegationEvidenceFresh : Prop
  freshnessEstablished : delegationEvidenceFresh
  delegationRevoked : Prop
  notRevoked : ¬ delegationRevoked

theorem neverAmplifies
    {CapabilityIdentity Scope ActionRole DelegationEvidenceIdentity RevocationObservationIdentity : Type}
    [DecidableEq Scope] [DecidableEq ActionRole]
    (delegation : Admitted CapabilityIdentity Scope ActionRole
      DelegationEvidenceIdentity RevocationObservationIdentity) :
    let result := YuanxuProof.Admission.Federation.attenuate delegation.attenuation
    (∀ scope ∈ result.scopes, scope ∈ delegation.attenuation.source.scopes) ∧
    (∀ action ∈ result.actions, action ∈ delegation.attenuation.source.actions) ∧
    result.expiresAt ≤ delegation.attenuation.source.expiresAt ∧
    result.delegationDepth ≤ delegation.attenuation.source.delegationDepth :=
  YuanxuProof.Admission.Federation.attenuationCannotAmplify delegation.attenuation

theorem requiresFreshUnrevokedEvidence
    {CapabilityIdentity Scope ActionRole
      DelegationEvidenceIdentity RevocationObservationIdentity : Type}
    (delegation :
      Admitted
        CapabilityIdentity Scope ActionRole
        DelegationEvidenceIdentity RevocationObservationIdentity) :
    delegation.delegationEvidenceFresh ∧
      ¬ delegation.delegationRevoked :=
  ⟨delegation.freshnessEstablished, delegation.notRevoked⟩

end AgenticAILabProof.Enterprise.Delegation
