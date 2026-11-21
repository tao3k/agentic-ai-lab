-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.AISecurityExecutableRefinementContractClosure

namespace AgenticAILabProof.Enterprise

/-!
Executable refinement of the provider-neutral action/evidence envelope.

Scheme owns the reference transition object; Python independently replays its
typed projection.  These definitions state the shared logical identity without
claiming that Lean parses either provider logs or runtime JSON.
-/

def actionEvidenceEnvelopeSchemaId : String :=
  "agentic-ai-lab.ai-security.action-evidence-envelope.v1"

def executableTransitionReceiptSchemaId : String :=
  "agentic-ai-lab.ai-security.executable-transition-receipt.v1"

def evidenceContentVerificationSchemaId : String :=
  "agentic-ai-lab.ai-security.evidence-content-verification.v1"

structure ExecutableInvariantEvidence where
  capabilityConfinement : Bool
  toolIdentity : Bool
  effectContainment : Bool
  causalContinuity : Bool
  deriving DecidableEq, Repr

inductive ExecutableTransitionDecision where
  | accepted
  | failClosed
  deriving DecidableEq, Repr

def executableReferenceDecision
    (evidence : ExecutableInvariantEvidence) : ExecutableTransitionDecision :=
  if evidence.capabilityConfinement && evidence.toolIdentity &&
      evidence.effectContainment && evidence.causalContinuity then
    .accepted
  else
    .failClosed

structure SchemePythonIdentityMapping where
  schemeSchemaId : String
  pythonSchemaId : String
  actionId : String
  observationEventId : String
  recoveryDecisionId : String
  evidenceRoot : String
  traceRoot : String
  deriving DecidableEq, Repr

def SchemePythonIdentityMapping.schemaAligned
    (mapping : SchemePythonIdentityMapping) : Prop :=
  mapping.schemeSchemaId = actionEvidenceEnvelopeSchemaId ∧
  mapping.pythonSchemaId = actionEvidenceEnvelopeSchemaId

structure VersionedExecutableTransitionReceipt where
  schemaId : String
  schemaVersion : String
  envelopeDigest : String
  outputDigest : String
  traceRoot : String
  decision : ExecutableTransitionDecision
  evidence : ExecutableInvariantEvidence
  deriving DecidableEq, Repr

def VersionedExecutableTransitionReceipt.replays
    (receipt : VersionedExecutableTransitionReceipt) : Prop :=
  receipt.schemaId = executableTransitionReceiptSchemaId ∧
  receipt.schemaVersion = "1" ∧
  receipt.decision = executableReferenceDecision receipt.evidence

theorem executable_reference_accepts_four_invariants
    (evidence : ExecutableInvariantEvidence)
    (capability : evidence.capabilityConfinement = true)
    (tool : evidence.toolIdentity = true)
    (effect : evidence.effectContainment = true)
    (causal : evidence.causalContinuity = true) :
    executableReferenceDecision evidence = .accepted := by
  simp [executableReferenceDecision, capability, tool, effect, causal]

theorem executable_reference_fails_closed_on_capability
    (evidence : ExecutableInvariantEvidence)
    (failure : evidence.capabilityConfinement = false) :
    executableReferenceDecision evidence = .failClosed := by
  simp [executableReferenceDecision, failure]

theorem executable_reference_fails_closed_on_tool_identity
    (evidence : ExecutableInvariantEvidence)
    (failure : evidence.toolIdentity = false) :
    executableReferenceDecision evidence = .failClosed := by
  simp [executableReferenceDecision, failure]

theorem executable_reference_fails_closed_on_effect
    (evidence : ExecutableInvariantEvidence)
    (failure : evidence.effectContainment = false) :
    executableReferenceDecision evidence = .failClosed := by
  simp [executableReferenceDecision, failure]

theorem executable_reference_fails_closed_on_causal_discontinuity
    (evidence : ExecutableInvariantEvidence)
    (failure : evidence.causalContinuity = false) :
    executableReferenceDecision evidence = .failClosed := by
  simp [executableReferenceDecision, failure]

theorem independent_double_replay_agrees
    (schemeReceipt pythonReceipt : VersionedExecutableTransitionReceipt)
    (sameIdentity : schemeReceipt = pythonReceipt)
    (schemeReplay : schemeReceipt.replays) :
    pythonReceipt.replays := by
  simpa [sameIdentity] using schemeReplay

theorem aligned_mapping_cannot_change_schema
    (mapping : SchemePythonIdentityMapping)
    (aligned : mapping.schemaAligned) :
    mapping.schemeSchemaId = mapping.pythonSchemaId := by
  exact aligned.1.trans aligned.2.symm

inductive EvidenceAuthorityState where
  | verified
  | failed
  | notProvided
  deriving DecidableEq, Repr

structure EvidenceContentStageReceipts where
  digestIntegrity : EvidenceAuthorityState
  schemaSemanticReplay : EvidenceAuthorityState
  issuerAuthentication : EvidenceAuthorityState
  transparencyInclusion : EvidenceAuthorityState
  deriving DecidableEq, Repr

def evidenceContentDecision
    (stages : EvidenceContentStageReceipts) : ExecutableTransitionDecision :=
  if stages.digestIntegrity = .verified ∧
      stages.schemaSemanticReplay = .verified ∧
      stages.issuerAuthentication = .verified ∧
      stages.transparencyInclusion = .verified then
    .accepted
  else
    .failClosed

theorem evidence_content_accepts_four_authorities
    (stages : EvidenceContentStageReceipts)
    (digest : stages.digestIntegrity = .verified)
    (schema : stages.schemaSemanticReplay = .verified)
    (issuer : stages.issuerAuthentication = .verified)
    (transparency : stages.transparencyInclusion = .verified) :
    evidenceContentDecision stages = .accepted := by
  simp [evidenceContentDecision, digest, schema, issuer, transparency]

theorem evidence_content_fails_closed_on_digest
    (stages : EvidenceContentStageReceipts)
    (failure : stages.digestIntegrity = .failed) :
    evidenceContentDecision stages = .failClosed := by
  simp [evidenceContentDecision, failure]

theorem evidence_content_fails_closed_on_schema_replay
    (stages : EvidenceContentStageReceipts)
    (failure : stages.schemaSemanticReplay = .failed) :
    evidenceContentDecision stages = .failClosed := by
  simp [evidenceContentDecision, failure]

theorem evidence_content_fails_closed_without_issuer
    (stages : EvidenceContentStageReceipts)
    (missing : stages.issuerAuthentication = .notProvided) :
    evidenceContentDecision stages = .failClosed := by
  simp [evidenceContentDecision, missing]

theorem evidence_content_fails_closed_without_transparency
    (stages : EvidenceContentStageReceipts)
    (missing : stages.transparencyInclusion = .notProvided) :
    evidenceContentDecision stages = .failClosed := by
  simp [evidenceContentDecision, missing]

end AgenticAILabProof.Enterprise
