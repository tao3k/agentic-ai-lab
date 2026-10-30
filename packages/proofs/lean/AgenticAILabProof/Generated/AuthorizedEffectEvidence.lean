-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.AuthorizedEffectEvidence

namespace AgenticAILabProof.PooC4

def GeneratedAuthorizedEffectVerified : AuthorizedEffectEvidenceFacts where
  tokenBindingOk := true
  decisionBindingOk := true
  semanticRootOk := true
  committedObservation := true
  executionRootLinked := true
  durableEvidenceReference := true
  signaturePresent := true
  signatureVerified := true
  inclusionProofVerified := true

theorem GeneratedAuthorizedEffectVerifiedL3 :
    authorizedEffectL3 GeneratedAuthorizedEffectVerified :=
  authorizedEffectL3ByVerifiedBindings
    GeneratedAuthorizedEffectVerified
    ⟨⟨rfl, rfl, rfl⟩, rfl, rfl⟩
    rfl
    rfl
    rfl

def GeneratedAuthorizedEffectUnverifiedSignature :
    AuthorizedEffectEvidenceFacts :=
  { GeneratedAuthorizedEffectVerified with signatureVerified := false }

theorem GeneratedSignatureBytesOnlyRejectedAtL3 :
    ¬ authorizedEffectL3 GeneratedAuthorizedEffectUnverifiedSignature :=
  authorizedEffectSignatureBytesDoNotEstablishL3
    GeneratedAuthorizedEffectUnverifiedSignature
    rfl
    rfl

def GeneratedAuthorizedEffectBuffered : AuthorizedEffectEvidenceFacts :=
  { GeneratedAuthorizedEffectVerified with
      committedObservation := false
      executionRootLinked := false
      signatureVerified := false
      inclusionProofVerified := false }

theorem GeneratedBufferedReceiptRejectedAtL2 :
    ¬ authorizedEffectL2 GeneratedAuthorizedEffectBuffered :=
  authorizedEffectUncommittedRejectsL2
    GeneratedAuthorizedEffectBuffered
    rfl

theorem GeneratedBufferedReceiptRetainsL1 :
    authorizedEffectL1 GeneratedAuthorizedEffectBuffered :=
  ⟨rfl, rfl, rfl⟩

def GeneratedAuthorizedEffectMissingInclusion :
    AuthorizedEffectEvidenceFacts :=
  { GeneratedAuthorizedEffectVerified with inclusionProofVerified := false }

theorem GeneratedMissingInclusionRejectedAtL3 :
    ¬ authorizedEffectL3 GeneratedAuthorizedEffectMissingInclusion :=
  authorizedEffectMissingInclusionRejectsL3
    GeneratedAuthorizedEffectMissingInclusion
    rfl

end AgenticAILabProof.PooC4
