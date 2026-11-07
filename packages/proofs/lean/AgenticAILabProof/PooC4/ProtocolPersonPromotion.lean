-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.PooC4

structure PromotionIntent where
  promotionId : Nat
  candidateDigest : Nat
  expectedBundleEpoch : Nat
  expectedAuthorityEpoch : Nat
  expectedProofEpoch : Nat
  expectedEvaluatorEpoch : Nat
deriving Repr, DecidableEq

structure PromotionWorld where
  bundleEpoch : Nat
  authorityEpoch : Nat
  proofEpoch : Nat
  evaluatorEpoch : Nat
deriving Repr, DecidableEq

structure PromotionDecisionFacts where
  cedarPermit : Bool
  leanVerified : Bool
  evaluatorApplicable : Bool
  evidenceComplete : Bool
  materializedOnce : Bool
  injectionReceipted : Bool
deriving Repr, DecidableEq

def promotionEpochsMatch
    (intent : PromotionIntent)
    (world : PromotionWorld) : Prop :=
  intent.expectedBundleEpoch = world.bundleEpoch
    ∧ intent.expectedAuthorityEpoch = world.authorityEpoch
    ∧ intent.expectedProofEpoch = world.proofEpoch
    ∧ intent.expectedEvaluatorEpoch = world.evaluatorEpoch

def promotionApproved
    (intent : PromotionIntent)
    (world : PromotionWorld)
    (facts : PromotionDecisionFacts) : Prop :=
  facts.cedarPermit = true
    ∧ facts.leanVerified = true
    ∧ facts.evaluatorApplicable = true
    ∧ facts.evidenceComplete = true
    ∧ promotionEpochsMatch intent world

def promotionActive
    (intent : PromotionIntent)
    (world : PromotionWorld)
    (facts : PromotionDecisionFacts) : Prop :=
  promotionApproved intent world facts
    ∧ facts.materializedOnce = true
    ∧ facts.injectionReceipted = true

theorem promotionApprovedByCurrentDualEngine
    (intent : PromotionIntent)
    (world : PromotionWorld)
    (facts : PromotionDecisionFacts)
    (hcedar : facts.cedarPermit = true)
    (hlean : facts.leanVerified = true)
    (hevaluator : facts.evaluatorApplicable = true)
    (hevidence : facts.evidenceComplete = true)
    (hepochs : promotionEpochsMatch intent world) :
    promotionApproved intent world facts := by
  exact ⟨hcedar, hlean, hevaluator, hevidence, hepochs⟩

theorem promotionActiveImpliesApproved
    (intent : PromotionIntent)
    (world : PromotionWorld)
    (facts : PromotionDecisionFacts)
    (hactive : promotionActive intent world facts) :
    promotionApproved intent world facts :=
  hactive.left

theorem promotionRejectsCedarDeny
    (intent : PromotionIntent)
    (world : PromotionWorld)
    (facts : PromotionDecisionFacts)
    (hdeny : facts.cedarPermit = false) :
    ¬ promotionApproved intent world facts := by
  simp [promotionApproved, hdeny]

theorem promotionRejectsUnverifiedProof
    (intent : PromotionIntent)
    (world : PromotionWorld)
    (facts : PromotionDecisionFacts)
    (hunverified : facts.leanVerified = false) :
    ¬ promotionApproved intent world facts := by
  simp [promotionApproved, hunverified]

theorem promotionRejectsStaleAuthorityEpoch
    (intent : PromotionIntent)
    (world : PromotionWorld)
    (facts : PromotionDecisionFacts)
    (hstale : intent.expectedAuthorityEpoch ≠ world.authorityEpoch) :
    ¬ promotionApproved intent world facts := by
  simp [promotionApproved, promotionEpochsMatch, hstale]

theorem promotionRejectsStaleProofEpoch
    (intent : PromotionIntent)
    (world : PromotionWorld)
    (facts : PromotionDecisionFacts)
    (hstale : intent.expectedProofEpoch ≠ world.proofEpoch) :
    ¬ promotionApproved intent world facts := by
  simp [promotionApproved, promotionEpochsMatch, hstale]

theorem promotionRejectsInapplicableEvaluator
    (intent : PromotionIntent)
    (world : PromotionWorld)
    (facts : PromotionDecisionFacts)
    (hstale : facts.evaluatorApplicable = false) :
    ¬ promotionApproved intent world facts := by
  simp [promotionApproved, hstale]

theorem promotionCannotBecomeActiveWithoutInjectionReceipt
    (intent : PromotionIntent)
    (world : PromotionWorld)
    (facts : PromotionDecisionFacts)
    (hmissing : facts.injectionReceipted = false) :
    ¬ promotionActive intent world facts := by
  simp [promotionActive, hmissing]

noncomputable def nextHarness
    (currentHarness candidateHarness : Nat)
    (intent : PromotionIntent)
    (world : PromotionWorld)
    (facts : PromotionDecisionFacts) : Nat := by
  classical
  exact
    if promotionActive intent world facts then
      candidateHarness
    else
      currentHarness

theorem activePromotionSelectsCandidateHarness
    (currentHarness candidateHarness : Nat)
    (intent : PromotionIntent)
    (world : PromotionWorld)
    (facts : PromotionDecisionFacts)
    (hactive : promotionActive intent world facts) :
    nextHarness currentHarness candidateHarness intent world facts =
      candidateHarness := by
  simp [nextHarness, hactive]

theorem rejectedPromotionPreservesCurrentHarness
    (currentHarness candidateHarness : Nat)
    (intent : PromotionIntent)
    (world : PromotionWorld)
    (facts : PromotionDecisionFacts)
    (hrejected : ¬ promotionActive intent world facts) :
    nextHarness currentHarness candidateHarness intent world facts =
      currentHarness := by
  simp [nextHarness, hrejected]

structure ConstitutionalAmendmentFacts where
  oldPolicyPermit : Bool
  oldSpecVerified : Bool
  requiredQuorum : Bool
  transitionReceiptReady : Bool
  newPolicySelfPermit : Bool
  newSpecSelfVerified : Bool
deriving Repr, DecidableEq

def constitutionalAmendmentApproved
    (facts : ConstitutionalAmendmentFacts) : Prop :=
  facts.oldPolicyPermit = true
    ∧ facts.oldSpecVerified = true
    ∧ facts.requiredQuorum = true
    ∧ facts.transitionReceiptReady = true

theorem constitutionalAmendmentByOldEpoch
    (facts : ConstitutionalAmendmentFacts)
    (hpolicy : facts.oldPolicyPermit = true)
    (hproof : facts.oldSpecVerified = true)
    (hquorum : facts.requiredQuorum = true)
    (hreceipt : facts.transitionReceiptReady = true) :
    constitutionalAmendmentApproved facts := by
  exact ⟨hpolicy, hproof, hquorum, hreceipt⟩

theorem newEpochSelfApprovalIsInsufficient
    (facts : ConstitutionalAmendmentFacts)
    (_hnewPolicy : facts.newPolicySelfPermit = true)
    (_hnewProof : facts.newSpecSelfVerified = true)
    (holdPolicyMissing : facts.oldPolicyPermit = false) :
    ¬ constitutionalAmendmentApproved facts := by
  simp [constitutionalAmendmentApproved, holdPolicyMissing]

structure TemporalProjectionFacts where
  admitted : Bool
  superseded : Bool
  revoked : Bool
  applicable : Bool
deriving Repr, DecidableEq

def historicallyAdmitted (facts : TemporalProjectionFacts) : Prop :=
  facts.admitted = true

def activeProjection (facts : TemporalProjectionFacts) : Prop :=
  historicallyAdmitted facts
    ∧ facts.superseded = false
    ∧ facts.revoked = false
    ∧ facts.applicable = true

theorem activeProjectionImpliesHistory
    (facts : TemporalProjectionFacts)
    (hactive : activeProjection facts) :
    historicallyAdmitted facts :=
  hactive.left

theorem revokedItemCannotRemainActive
    (facts : TemporalProjectionFacts)
    (hrevoked : facts.revoked = true) :
    ¬ activeProjection facts := by
  simp [activeProjection, hrevoked]

theorem supersededItemCannotRemainActive
    (facts : TemporalProjectionFacts)
    (hsuperseded : facts.superseded = true) :
    ¬ activeProjection facts := by
  simp [activeProjection, hsuperseded]

inductive MaterializationOutcome where
  | applied
  | alreadyApplied
  | conflict
deriving Repr, DecidableEq

def materializePromotion
    (promotionId : Nat)
    (appliedPromotionId : Option Nat) : MaterializationOutcome × Option Nat :=
  match appliedPromotionId with
  | none => (.applied, some promotionId)
  | some current =>
      if current = promotionId then
        (.alreadyApplied, some current)
      else
        (.conflict, some current)

theorem firstMaterializationApplies (promotionId : Nat) :
    materializePromotion promotionId none =
      (.applied, some promotionId) := by
  rfl

theorem repeatedMaterializationIsExactlyOnce (promotionId : Nat) :
    materializePromotion promotionId (some promotionId) =
      (.alreadyApplied, some promotionId) := by
  simp [materializePromotion]

theorem conflictingMaterializationRejects
    (promotionId current : Nat)
    (hconflict : current ≠ promotionId) :
    materializePromotion promotionId (some current) =
      (.conflict, some current) := by
  simp [materializePromotion, hconflict]

end AgenticAILabProof.PooC4
