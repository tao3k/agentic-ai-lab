-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.AgentRedTeamProofRegressionClosure

namespace AgenticAILabProof.Enterprise.AgentVerificationMetricsClosure

open AgentActionEvidenceEnvelopeClosure

inductive AgentProofDisposition where
  | proved
  | unknownEscalated
  | rejectedFailClosed
  deriving DecidableEq, Repr

inductive AgentReplayDisposition where
  | notAttempted
  | succeeded
  | failed
  deriving DecidableEq, Repr

structure AgentVerificationSample where
  actionId : AgentActionId
  decisionId : AgentDecisionId
  evidenceRoot : AgentEvidenceRoot
  independentBundleDigest : String
  proofDisposition : AgentProofDisposition
  replayDisposition : AgentReplayDisposition
  provenanceDigest : String
  deriving DecidableEq, Repr

def proofCount : List AgentVerificationSample → Nat
  | [] => 0
  | sample :: samples =>
      (match sample.proofDisposition with
        | .proved => 1
        | .unknownEscalated => 0
        | .rejectedFailClosed => 0) + proofCount samples

def unknownEscalationCount : List AgentVerificationSample → Nat
  | [] => 0
  | sample :: samples =>
      (match sample.proofDisposition with
        | .proved => 0
        | .unknownEscalated => 1
        | .rejectedFailClosed => 0) +
        unknownEscalationCount samples

def replayAttemptedCount : List AgentVerificationSample → Nat
  | [] => 0
  | sample :: samples =>
      (match sample.replayDisposition with
        | .notAttempted => 0
        | .succeeded => 1
        | .failed => 1) + replayAttemptedCount samples

def replaySucceededCount : List AgentVerificationSample → Nat
  | [] => 0
  | sample :: samples =>
      (match sample.replayDisposition with
        | .notAttempted => 0
        | .succeeded => 1
        | .failed => 0) + replaySucceededCount samples

structure AgentVerificationPopulation where
  total : Nat
  proved : Nat
  unknownEscalated : Nat
  replayAttempted : Nat
  replaySucceeded : Nat
  deriving DecidableEq, Repr

def verificationPopulation
    (samples : List AgentVerificationSample) :
    AgentVerificationPopulation :=
  {
    total := samples.length
    proved := proofCount samples
    unknownEscalated := unknownEscalationCount samples
    replayAttempted := replayAttemptedCount samples
    replaySucceeded := replaySucceededCount samples
  }

structure AgentMetricFraction where
  numerator : Nat
  denominator : Nat
  deriving DecidableEq, Repr

def proofCoverage
    (population : AgentVerificationPopulation) : AgentMetricFraction :=
  ⟨population.proved, population.total⟩

def unknownEscalationRate
    (population : AgentVerificationPopulation) : AgentMetricFraction :=
  ⟨population.unknownEscalated, population.total⟩

def replaySuccess
    (population : AgentVerificationPopulation) : AgentMetricFraction :=
  ⟨population.replaySucceeded, population.replayAttempted⟩

structure AgentVerificationMetricsReceipt where
  receiptId : String
  schemaId : String
  evidenceRoot : AgentEvidenceRoot
  independentBundleDigest : String
  policyRevision : String
  population : AgentVerificationPopulation
  provenanceDigest : String
  deriving DecidableEq, Repr

def AgentVerificationMetricsReceiptValid :=
  AgentVerificationMetricsReceipt → Prop

def AgentProofSampleValid := AgentVerificationSample → Prop
def AgentEscalationSampleValid := AgentVerificationSample → Prop
def AgentReplaySampleValid := AgentVerificationSample → Prop

structure AgentVerificationMetricsClosed
    (receiptValid : AgentVerificationMetricsReceiptValid)
    (proofSampleValid : AgentProofSampleValid)
    (escalationSampleValid : AgentEscalationSampleValid)
    (replaySampleValid : AgentReplaySampleValid)
    (samples : List AgentVerificationSample)
    (receipt : AgentVerificationMetricsReceipt) : Prop where
  receiptValidates : receiptValid receipt
  samplesNonempty : samples ≠ []
  receiptIdentityPresent : receipt.receiptId ≠ ""
  schemaIdentityPresent : receipt.schemaId ≠ ""
  evidenceRootPresent : receipt.evidenceRoot ≠ ""
  independentBundlePresent : receipt.independentBundleDigest ≠ ""
  policyRevisionPresent : receipt.policyRevision ≠ ""
  provenancePresent : receipt.provenanceDigest ≠ ""
  sampleIdentitiesPresent :
    ∀ sample ∈ samples,
      sample.actionId ≠ "" ∧
        sample.decisionId ≠ "" ∧
        sample.evidenceRoot ≠ "" ∧
        sample.provenanceDigest ≠ ""
  sampleBundlesMatch :
    ∀ sample ∈ samples,
      sample.independentBundleDigest = receipt.independentBundleDigest
  proofSamplesValidate :
    ∀ sample ∈ samples,
      sample.proofDisposition = .proved → proofSampleValid sample
  escalationSamplesValidate :
    ∀ sample ∈ samples,
      sample.proofDisposition = .unknownEscalated →
        escalationSampleValid sample
  replaySamplesValidate :
    ∀ sample ∈ samples,
      sample.replayDisposition = .succeeded → replaySampleValid sample
  populationDerived :
    receipt.population = verificationPopulation samples

theorem proofCountLeLength
    (samples : List AgentVerificationSample) :
    proofCount samples ≤ samples.length := by
  induction samples with
  | nil =>
      simp [proofCount]
  | cons sample samples inductionHypothesis =>
      cases disposition : sample.proofDisposition with
      | proved =>
          simpa [proofCount, disposition, Nat.add_comm] using
            Nat.succ_le_succ inductionHypothesis
      | unknownEscalated =>
          have widened :=
            Nat.le_trans inductionHypothesis (Nat.le_succ samples.length)
          simpa [proofCount, disposition] using widened
      | rejectedFailClosed =>
          have widened :=
            Nat.le_trans inductionHypothesis (Nat.le_succ samples.length)
          simpa [proofCount, disposition] using widened

theorem unknownEscalationCountLeLength
    (samples : List AgentVerificationSample) :
    unknownEscalationCount samples ≤ samples.length := by
  induction samples with
  | nil =>
      simp [unknownEscalationCount]
  | cons sample samples inductionHypothesis =>
      cases disposition : sample.proofDisposition with
      | proved =>
          have widened :=
            Nat.le_trans inductionHypothesis (Nat.le_succ samples.length)
          simpa [unknownEscalationCount, disposition] using widened
      | unknownEscalated =>
          simpa [
            unknownEscalationCount,
            disposition,
            Nat.add_comm
          ] using Nat.succ_le_succ inductionHypothesis
      | rejectedFailClosed =>
          have widened :=
            Nat.le_trans inductionHypothesis (Nat.le_succ samples.length)
          simpa [unknownEscalationCount, disposition] using widened

theorem replayAttemptedCountLeLength
    (samples : List AgentVerificationSample) :
    replayAttemptedCount samples ≤ samples.length := by
  induction samples with
  | nil =>
      simp [replayAttemptedCount]
  | cons sample samples inductionHypothesis =>
      cases disposition : sample.replayDisposition with
      | notAttempted =>
          have widened :=
            Nat.le_trans inductionHypothesis (Nat.le_succ samples.length)
          simpa [replayAttemptedCount, disposition] using widened
      | succeeded =>
          simpa [replayAttemptedCount, disposition, Nat.add_comm] using
            Nat.succ_le_succ inductionHypothesis
      | failed =>
          simpa [replayAttemptedCount, disposition, Nat.add_comm] using
            Nat.succ_le_succ inductionHypothesis

theorem replaySucceededCountLeAttemptedCount
    (samples : List AgentVerificationSample) :
    replaySucceededCount samples ≤ replayAttemptedCount samples := by
  induction samples with
  | nil =>
      simp [replaySucceededCount, replayAttemptedCount]
  | cons sample samples inductionHypothesis =>
      cases disposition : sample.replayDisposition with
      | notAttempted =>
          simpa [
            replaySucceededCount,
            replayAttemptedCount,
            disposition
          ] using inductionHypothesis
      | succeeded =>
          simpa [
            replaySucceededCount,
            replayAttemptedCount,
            disposition,
            Nat.add_comm
          ] using Nat.succ_le_succ inductionHypothesis
      | failed =>
          have widened :=
            Nat.le_trans
              inductionHypothesis
              (Nat.le_succ (replayAttemptedCount samples))
          simpa [
            replaySucceededCount,
            replayAttemptedCount,
            disposition,
            Nat.add_comm
          ] using widened

theorem closedMetricsReportAllThreeEnterpriseRates
    {receiptValid : AgentVerificationMetricsReceiptValid}
    {proofSampleValid : AgentProofSampleValid}
    {escalationSampleValid : AgentEscalationSampleValid}
    {replaySampleValid : AgentReplaySampleValid}
    {samples : List AgentVerificationSample}
    {receipt : AgentVerificationMetricsReceipt}
    (closed :
      AgentVerificationMetricsClosed
        receiptValid
        proofSampleValid
        escalationSampleValid
        replaySampleValid
        samples
        receipt) :
    (proofCoverage receipt.population =
        ⟨proofCount samples, samples.length⟩) ∧
      (unknownEscalationRate receipt.population =
        ⟨unknownEscalationCount samples, samples.length⟩) ∧
      (replaySuccess receipt.population =
        ⟨replaySucceededCount samples, replayAttemptedCount samples⟩) := by
  rw [closed.populationDerived]
  constructor
  · rfl
  constructor
  · rfl
  · rfl

theorem closedMetricsProofCoverageIsBounded
    {receiptValid : AgentVerificationMetricsReceiptValid}
    {proofSampleValid : AgentProofSampleValid}
    {escalationSampleValid : AgentEscalationSampleValid}
    {replaySampleValid : AgentReplaySampleValid}
    {samples : List AgentVerificationSample}
    {receipt : AgentVerificationMetricsReceipt}
    (closed :
      AgentVerificationMetricsClosed
        receiptValid
        proofSampleValid
        escalationSampleValid
        replaySampleValid
        samples
        receipt) :
    receipt.population.proved ≤ receipt.population.total := by
  rw [closed.populationDerived]
  exact proofCountLeLength samples

theorem closedMetricsReplaySuccessIsBounded
    {receiptValid : AgentVerificationMetricsReceiptValid}
    {proofSampleValid : AgentProofSampleValid}
    {escalationSampleValid : AgentEscalationSampleValid}
    {replaySampleValid : AgentReplaySampleValid}
    {samples : List AgentVerificationSample}
    {receipt : AgentVerificationMetricsReceipt}
    (closed :
      AgentVerificationMetricsClosed
        receiptValid
        proofSampleValid
        escalationSampleValid
        replaySampleValid
        samples
        receipt) :
    receipt.population.replaySucceeded ≤
      receipt.population.replayAttempted := by
  rw [closed.populationDerived]
  exact replaySucceededCountLeAttemptedCount samples

theorem unknownEscalationIsNotProof
    (sample : AgentVerificationSample)
    (unknown : sample.proofDisposition = .unknownEscalated) :
    sample.proofDisposition ≠ .proved := by
  rw [unknown]
  decide

theorem mismatchedBundleRejectsMetrics
    (receiptValid : AgentVerificationMetricsReceiptValid)
    (proofSampleValid : AgentProofSampleValid)
    (escalationSampleValid : AgentEscalationSampleValid)
    (replaySampleValid : AgentReplaySampleValid)
    (samples : List AgentVerificationSample)
    (receipt : AgentVerificationMetricsReceipt)
    (sample : AgentVerificationSample)
    (member : sample ∈ samples)
    (mismatch :
      sample.independentBundleDigest ≠ receipt.independentBundleDigest) :
    ¬ AgentVerificationMetricsClosed
      receiptValid
      proofSampleValid
      escalationSampleValid
      replaySampleValid
      samples
      receipt := by
  intro closed
  exact mismatch (closed.sampleBundlesMatch sample member)

end AgenticAILabProof.Enterprise.AgentVerificationMetricsClosure
