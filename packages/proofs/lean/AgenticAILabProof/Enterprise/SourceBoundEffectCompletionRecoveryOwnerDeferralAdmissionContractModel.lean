-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerDeferralAdmissionContractModel

structure OwnerContractProjection where
  recoveryIdentity : String
  ownerIdentity : String
  runtimeEpoch : Nat
  activeFenceToken : Nat
  deriving DecidableEq, Repr

structure FiniteOwnerDeferralContract where
  projection : OwnerContractProjection
  maxDeferrals : Nat
  deriving DecidableEq, Repr

def finiteOwnerDeferralContractCandidate
    (projection : OwnerContractProjection)
    (maxDeferrals : Nat) :
    FiniteOwnerDeferralContract :=
  { projection, maxDeferrals }

theorem currentProjectionDoesNotDetermineFiniteOwnerLimit
    (projection : OwnerContractProjection) :
    (finiteOwnerDeferralContractCandidate projection 0).projection =
        projection ∧
      (finiteOwnerDeferralContractCandidate projection 1).projection =
        projection ∧
      (finiteOwnerDeferralContractCandidate projection 0).maxDeferrals ≠
        (finiteOwnerDeferralContractCandidate projection 1).maxDeferrals := by
  simp [finiteOwnerDeferralContractCandidate]

structure FiniteStorageAdmissionContract where
  projection : OwnerContractProjection
  publicationIdentity : String
  maxDeferrals : Nat
  requiredUnits : Nat
  deriving DecidableEq, Repr

def finiteStorageAdmissionContractCandidate
    (projection : OwnerContractProjection)
    (publicationIdentity : String)
    (maxDeferrals requiredUnits : Nat) :
    FiniteStorageAdmissionContract :=
  {
    projection
    publicationIdentity
    maxDeferrals
    requiredUnits
  }

theorem currentProjectionDoesNotDetermineFiniteStorageContract
    (projection : OwnerContractProjection)
    (publicationIdentity : String) :
    (finiteStorageAdmissionContractCandidate
        projection publicationIdentity 0 0).projection = projection ∧
      (finiteStorageAdmissionContractCandidate
        projection publicationIdentity 1 1).projection = projection ∧
      (finiteStorageAdmissionContractCandidate
        projection publicationIdentity 0 0).publicationIdentity =
          publicationIdentity ∧
      (finiteStorageAdmissionContractCandidate
        projection publicationIdentity 1 1).publicationIdentity =
          publicationIdentity ∧
      (finiteStorageAdmissionContractCandidate
        projection publicationIdentity 0 0).maxDeferrals ≠
          (finiteStorageAdmissionContractCandidate
            projection publicationIdentity 1 1).maxDeferrals ∧
      (finiteStorageAdmissionContractCandidate
        projection publicationIdentity 0 0).requiredUnits ≠
          (finiteStorageAdmissionContractCandidate
            projection publicationIdentity 1 1).requiredUnits := by
  simp [finiteStorageAdmissionContractCandidate]

theorem remainingDecreasesByOneIsStrict
    {beforeRemaining afterRemaining : Nat}
    (decreases : beforeRemaining = afterRemaining + 1) :
    afterRemaining < beforeRemaining := by
  rw [decreases]
  exact Nat.lt_succ_self afterRemaining

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryOwnerDeferralAdmissionContractModel
