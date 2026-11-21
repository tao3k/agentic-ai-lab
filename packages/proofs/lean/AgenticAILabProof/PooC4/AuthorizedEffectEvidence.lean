-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.PooC4

structure AuthorizedEffectEvidenceFacts where
  tokenBindingOk : Bool
  decisionBindingOk : Bool
  semanticRootOk : Bool
  committedObservation : Bool
  executionRootLinked : Bool
  durableEvidenceReference : Bool
  signaturePresent : Bool
  signatureVerified : Bool
  inclusionProofVerified : Bool
deriving Repr, DecidableEq

def authorizedEffectL1 (facts : AuthorizedEffectEvidenceFacts) : Prop :=
  facts.tokenBindingOk = true
    ∧ facts.decisionBindingOk = true
    ∧ facts.semanticRootOk = true

def authorizedEffectL2 (facts : AuthorizedEffectEvidenceFacts) : Prop :=
  authorizedEffectL1 facts
    ∧ facts.committedObservation = true
    ∧ facts.executionRootLinked = true

def authorizedEffectL3 (facts : AuthorizedEffectEvidenceFacts) : Prop :=
  authorizedEffectL2 facts
    ∧ facts.durableEvidenceReference = true
    ∧ facts.signatureVerified = true
    ∧ facts.inclusionProofVerified = true

theorem authorizedEffectL3ByVerifiedBindings
    (facts : AuthorizedEffectEvidenceFacts)
    (hl2 : authorizedEffectL2 facts)
    (href : facts.durableEvidenceReference = true)
    (hsig : facts.signatureVerified = true)
    (hinclusion : facts.inclusionProofVerified = true) :
    authorizedEffectL3 facts := by
  exact ⟨hl2, href, hsig, hinclusion⟩

theorem authorizedEffectL2ImpliesL1
    (facts : AuthorizedEffectEvidenceFacts)
    (hl2 : authorizedEffectL2 facts) :
    authorizedEffectL1 facts := hl2.left

theorem authorizedEffectL3ImpliesL2
    (facts : AuthorizedEffectEvidenceFacts)
    (hl3 : authorizedEffectL3 facts) :
    authorizedEffectL2 facts := hl3.left

theorem authorizedEffectSignatureBytesDoNotEstablishL3
    (facts : AuthorizedEffectEvidenceFacts)
    (_hpresent : facts.signaturePresent = true)
    (hunverified : facts.signatureVerified = false) :
    ¬ authorizedEffectL3 facts := by
  intro h
  unfold authorizedEffectL3 at h
  rw [hunverified] at h
  cases h.right.right.left

theorem authorizedEffectMissingInclusionRejectsL3
    (facts : AuthorizedEffectEvidenceFacts)
    (hmissing : facts.inclusionProofVerified = false) :
    ¬ authorizedEffectL3 facts := by
  intro h
  unfold authorizedEffectL3 at h
  rw [hmissing] at h
  cases h.right.right.right

theorem authorizedEffectUncommittedRejectsL2
    (facts : AuthorizedEffectEvidenceFacts)
    (huncommitted : facts.committedObservation = false) :
    ¬ authorizedEffectL2 facts := by
  intro h
  unfold authorizedEffectL2 at h
  rw [huncommitted] at h
  cases h.right.left

theorem authorizedEffectUnlinkedRootRejectsL2
    (facts : AuthorizedEffectEvidenceFacts)
    (hunlinked : facts.executionRootLinked = false) :
    ¬ authorizedEffectL2 facts := by
  intro h
  unfold authorizedEffectL2 at h
  rw [hunlinked] at h
  cases h.right.right

end AgenticAILabProof.PooC4
