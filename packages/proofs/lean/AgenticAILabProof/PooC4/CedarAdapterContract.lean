-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.CedarResponseArbitrationBridge

namespace AgenticAILabProof.PooC4.CedarAdapterContract

open AgenticAILabProof.PooC4.CedarDualEngineArbitration
open AgenticAILabProof.PooC4.CedarResponseArbitrationBridge

/-!
Proof contract for the Agentic AI Lab Cedar adapter.

The adapter is the only Agentic AI Lab owner.  Cedar's Lean definitional engine,
production engine, and DRT are upstream evidence providers behind this
boundary, not separate Agentic AI Lab owners.
-/

structure CedarAdapterProjection
    (RawResponse SemanticVersion InputIdentity : Type) where
  project :
    RawResponse →
      CedarComparableOutcome SemanticVersion InputIdentity

structure CedarAdapterReceipt
    (ExecutableDigest SemanticVersion InputIdentity : Type) where
  executableDigest : Option ExecutableDigest
  semanticVersion : SemanticVersion
  inputIdentity : InputIdentity
  response : Cedar.Spec.Response
deriving DecidableEq, Repr

def receiptComparable
    {ExecutableDigest SemanticVersion InputIdentity : Type}
    (receipt :
      CedarAdapterReceipt
        ExecutableDigest SemanticVersion InputIdentity) :
    CedarComparableOutcome SemanticVersion InputIdentity :=
  { semanticVersion := receipt.semanticVersion
    inputIdentity := receipt.inputIdentity
    response := receipt.response }

structure CedarAdapterAdmission
    {RawResponse ExecutableDigest SemanticVersion InputIdentity : Type}
    (projection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity)
    (raw : RawResponse)
    (expected :
      CedarComparableOutcome SemanticVersion InputIdentity)
    (receipt :
      CedarAdapterReceipt
        ExecutableDigest SemanticVersion InputIdentity) : Prop where
  executableDigestPresent :
    ∃ digest, receipt.executableDigest = some digest
  projectionExact :
    projection.project raw = expected
  receiptExact :
    receiptComparable receipt = expected

theorem admitted_projection_is_exact
    {RawResponse ExecutableDigest SemanticVersion InputIdentity : Type}
    {projection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity}
    {raw : RawResponse}
    {expected :
      CedarComparableOutcome SemanticVersion InputIdentity}
    {receipt :
      CedarAdapterReceipt
        ExecutableDigest SemanticVersion InputIdentity}
    (admission :
      CedarAdapterAdmission projection raw expected receipt) :
    projection.project raw = expected :=
  admission.projectionExact

theorem admitted_receipt_reconstructs_exact_outcome
    {RawResponse ExecutableDigest SemanticVersion InputIdentity : Type}
    {projection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity}
    {raw : RawResponse}
    {expected :
      CedarComparableOutcome SemanticVersion InputIdentity}
    {receipt :
      CedarAdapterReceipt
        ExecutableDigest SemanticVersion InputIdentity}
    (admission :
      CedarAdapterAdmission projection raw expected receipt) :
    receiptComparable receipt = expected :=
  admission.receiptExact

theorem admitted_receipt_has_executable_digest
    {RawResponse ExecutableDigest SemanticVersion InputIdentity : Type}
    {projection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity}
    {raw : RawResponse}
    {expected :
      CedarComparableOutcome SemanticVersion InputIdentity}
    {receipt :
      CedarAdapterReceipt
        ExecutableDigest SemanticVersion InputIdentity}
    (admission :
      CedarAdapterAdmission projection raw expected receipt) :
    ∃ digest, receipt.executableDigest = some digest :=
  admission.executableDigestPresent

theorem missing_executable_digest_blocks_admission
    {RawResponse ExecutableDigest SemanticVersion InputIdentity : Type}
    (projection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity)
    (raw : RawResponse)
    (expected :
      CedarComparableOutcome SemanticVersion InputIdentity)
    (semanticVersion : SemanticVersion)
    (inputIdentity : InputIdentity)
    (response : Cedar.Spec.Response) :
    ¬CedarAdapterAdmission projection raw expected
      { executableDigest := (none : Option ExecutableDigest)
        semanticVersion := semanticVersion
        inputIdentity := inputIdentity
        response := response } := by
  intro admission
  obtain ⟨digest, impossible⟩ := admission.executableDigestPresent
  cases impossible

theorem admitted_adapter_yields_dual_witness
    {RawResponse ExecutableDigest SemanticVersion InputIdentity : Type}
    [DecidableEq SemanticVersion]
    [DecidableEq InputIdentity]
    {projection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity}
    {raw : RawResponse}
    {expected :
      CedarComparableOutcome SemanticVersion InputIdentity}
    {receipt :
      CedarAdapterReceipt
        ExecutableDigest SemanticVersion InputIdentity}
    (admission :
      CedarAdapterAdmission projection raw expected receipt) :
    arbitrateStrict
        (.completed expected)
        (.completed (projection.project raw)) =
      projectOutcome .dualWitnessed true .agreed expected := by
  rw [admission.projectionExact]
  exact exact_cedar_agreement_is_dual_witnessed expected

theorem receipt_response_mismatch_blocks_admission
    {RawResponse ExecutableDigest SemanticVersion InputIdentity : Type}
    (projection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity)
    (raw : RawResponse)
    (expected :
      CedarComparableOutcome SemanticVersion InputIdentity)
    (digest : ExecutableDigest)
    (response : Cedar.Spec.Response)
    (different : response ≠ expected.response) :
    ¬CedarAdapterAdmission projection raw expected
      { executableDigest := some digest
        semanticVersion := expected.semanticVersion
        inputIdentity := expected.inputIdentity
        response := response } := by
  intro admission
  apply different
  exact congrArg CedarComparableOutcome.response admission.receiptExact

theorem receipt_input_mismatch_blocks_admission
    {RawResponse ExecutableDigest SemanticVersion InputIdentity : Type}
    (projection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity)
    (raw : RawResponse)
    (expected :
      CedarComparableOutcome SemanticVersion InputIdentity)
    (digest : ExecutableDigest)
    (inputIdentity : InputIdentity)
    (different : inputIdentity ≠ expected.inputIdentity) :
    ¬CedarAdapterAdmission projection raw expected
      { executableDigest := some digest
        semanticVersion := expected.semanticVersion
        inputIdentity := inputIdentity
        response := expected.response } := by
  intro admission
  apply different
  exact congrArg CedarComparableOutcome.inputIdentity admission.receiptExact

theorem receipt_version_mismatch_blocks_admission
    {RawResponse ExecutableDigest SemanticVersion InputIdentity : Type}
    (projection :
      CedarAdapterProjection RawResponse SemanticVersion InputIdentity)
    (raw : RawResponse)
    (expected :
      CedarComparableOutcome SemanticVersion InputIdentity)
    (digest : ExecutableDigest)
    (semanticVersion : SemanticVersion)
    (different : semanticVersion ≠ expected.semanticVersion) :
    ¬CedarAdapterAdmission projection raw expected
      { executableDigest := some digest
        semanticVersion := semanticVersion
        inputIdentity := expected.inputIdentity
        response := expected.response } := by
  intro admission
  apply different
  exact congrArg CedarComparableOutcome.semanticVersion admission.receiptExact

structure DrtReceipt
    (CommitIdentity ExecutableDigest CorpusSeed TargetIdentity : Type) where
  cedarSpecCommit : CommitIdentity
  cedarRustCommit : CommitIdentity
  leanExecutableDigest : ExecutableDigest
  rustExecutableDigest : ExecutableDigest
  corpusSeed : CorpusSeed
  target : TargetIdentity
  caseCount : Nat
  failureCount : Nat
deriving DecidableEq, Repr

structure DrtAdmission
    {CommitIdentity ExecutableDigest CorpusSeed TargetIdentity : Type}
    (expectedCedarSpecCommit : CommitIdentity)
    (receipt :
      DrtReceipt
        CommitIdentity ExecutableDigest CorpusSeed TargetIdentity) : Prop where
  cedarSpecCommitPinned :
    receipt.cedarSpecCommit = expectedCedarSpecCommit
  nonemptyCorpus : 0 < receipt.caseCount
  noObservedFailures : receipt.failureCount = 0

theorem admitted_drt_is_nonempty_finite_evidence
    {CommitIdentity ExecutableDigest CorpusSeed TargetIdentity : Type}
    {expectedCedarSpecCommit : CommitIdentity}
    {receipt :
      DrtReceipt
        CommitIdentity ExecutableDigest CorpusSeed TargetIdentity}
    (admission : DrtAdmission expectedCedarSpecCommit receipt) :
    0 < receipt.caseCount ∧ receipt.failureCount = 0 :=
  ⟨admission.nonemptyCorpus, admission.noObservedFailures⟩

theorem wrong_cedar_spec_commit_blocks_drt_admission
    {CommitIdentity ExecutableDigest CorpusSeed TargetIdentity : Type}
    (expected actual : CommitIdentity)
    (different : actual ≠ expected)
    (rustCommit : CommitIdentity)
    (leanDigest rustDigest : ExecutableDigest)
    (seed : CorpusSeed)
    (target : TargetIdentity)
    (caseCount failureCount : Nat) :
    ¬DrtAdmission expected
      { cedarSpecCommit := actual
        cedarRustCommit := rustCommit
        leanExecutableDigest := leanDigest
        rustExecutableDigest := rustDigest
        corpusSeed := seed
        target := target
        caseCount := caseCount
        failureCount := failureCount } := by
  intro admission
  exact different admission.cedarSpecCommitPinned

theorem observed_drt_failure_blocks_admission
    {CommitIdentity ExecutableDigest CorpusSeed TargetIdentity : Type}
    (expected rustCommit : CommitIdentity)
    (leanDigest rustDigest : ExecutableDigest)
    (seed : CorpusSeed)
    (target : TargetIdentity)
    (caseCount failureCount : Nat)
    (failed : failureCount ≠ 0) :
    ¬DrtAdmission expected
      { cedarSpecCommit := expected
        cedarRustCommit := rustCommit
        leanExecutableDigest := leanDigest
        rustExecutableDigest := rustDigest
        corpusSeed := seed
        target := target
        caseCount := caseCount
        failureCount := failureCount } := by
  intro admission
  exact failed admission.noObservedFailures

end AgenticAILabProof.PooC4.CedarAdapterContract
