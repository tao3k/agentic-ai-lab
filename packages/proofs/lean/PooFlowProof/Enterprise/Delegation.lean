-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import PooFlowCoreProof.PooC4.CrossDomainFederation

namespace PooFlowProof.Enterprise.Delegation

open PooFlowProof.PooC4

structure Admitted
    (CapabilityIdentity Scope ActionRole Expiry DelegationDepth
      DelegationEvidenceIdentity RevocationObservationIdentity : Type) where
  attenuation :
    CrossDomainFederation.CapabilityAttenuation
      CapabilityIdentity Scope ActionRole Expiry DelegationDepth
  delegationEvidenceIdentity : DelegationEvidenceIdentity
  revocationObservationIdentity : RevocationObservationIdentity
  delegationEvidenceFresh : Prop
  freshnessEstablished : delegationEvidenceFresh
  delegationRevoked : Prop
  notRevoked : ¬ delegationRevoked

theorem neverAmplifies
    {CapabilityIdentity Scope ActionRole Expiry DelegationDepth
      DelegationEvidenceIdentity RevocationObservationIdentity : Type}
    (delegation :
      Admitted
        CapabilityIdentity Scope ActionRole Expiry DelegationDepth
        DelegationEvidenceIdentity RevocationObservationIdentity) :
    delegation.attenuation.scopeNotAmplified ∧
      delegation.attenuation.actionNotAmplified ∧
      delegation.attenuation.expiryNotExtended ∧
      delegation.attenuation.delegationDepthNotIncreased :=
  delegation.attenuation.attenuationEstablished

theorem requiresFreshUnrevokedEvidence
    {CapabilityIdentity Scope ActionRole Expiry DelegationDepth
      DelegationEvidenceIdentity RevocationObservationIdentity : Type}
    (delegation :
      Admitted
        CapabilityIdentity Scope ActionRole Expiry DelegationDepth
        DelegationEvidenceIdentity RevocationObservationIdentity) :
    delegation.delegationEvidenceFresh ∧
      ¬ delegation.delegationRevoked :=
  ⟨delegation.freshnessEstablished, delegation.notRevoked⟩

end PooFlowProof.Enterprise.Delegation
