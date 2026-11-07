# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Provider-neutral executable refinement for Agentic AI Lab AI-security contracts.

The module deliberately consumes a typed action/evidence envelope instead of
provider logs.  Its receipts keep each proof obligation and each ASR-005
verification stage distinct so that insufficient evidence remains visible.
"""

from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
import json
from typing import Any, Callable, Mapping


ACTION_EVIDENCE_ENVELOPE_SCHEMA_ID = (
    "agentic-ai-lab.ai-security.action-evidence-envelope.v1"
)
EXECUTABLE_TRANSITION_RECEIPT_SCHEMA_ID = (
    "agentic-ai-lab.ai-security.executable-transition-receipt.v1"
)
EVIDENCE_CONTENT_VERIFICATION_SCHEMA_ID = (
    "agentic-ai-lab.ai-security.evidence-content-verification.v1"
)
SCHEMA_VERSION = "1"


class RefinementValidationError(ValueError):
    """Raised when an envelope or receipt cannot be replayed safely."""


def _canonical_json(value: Mapping[str, Any]) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def _sha256_bytes(value: bytes) -> str:
    return f"sha256:{sha256(value).hexdigest()}"


def _require_nonempty(name: str, value: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise RefinementValidationError(f"{name} must be a non-empty string")


def _require_digest(name: str, value: str) -> None:
    _require_nonempty(name, value)
    prefix, separator, digest = value.partition(":")
    if separator != ":" or prefix != "sha256" or len(digest) != 64:
        raise RefinementValidationError(f"{name} must be a sha256 digest")
    try:
        bytes.fromhex(digest)
    except ValueError as error:
        raise RefinementValidationError(
            f"{name} must be a sha256 digest"
        ) from error


def _canonical_strings(name: str, values: tuple[str, ...]) -> tuple[str, ...]:
    if not isinstance(values, tuple):
        raise RefinementValidationError(f"{name} must be a tuple")
    for value in values:
        _require_nonempty(name, value)
    canonical = tuple(sorted(set(values)))
    if canonical != values:
        raise RefinementValidationError(
            f"{name} must be unique and canonically sorted"
        )
    return canonical


@dataclass(frozen=True)
class AgentActionEvidenceEnvelope:
    action_id: str
    observation_event_id: str
    recovery_decision_id: str
    actor_identity: str
    tool_identity: str
    capability_id: str
    effect_domain: str
    evidence_root: str
    requested_effects: tuple[str, ...]
    allowed_effects: tuple[str, ...]
    parent_action_id: str | None = None
    trace_parent_root: str | None = None
    schema_id: str = ACTION_EVIDENCE_ENVELOPE_SCHEMA_ID
    schema_version: str = SCHEMA_VERSION

    def validate(self) -> None:
        if self.schema_id != ACTION_EVIDENCE_ENVELOPE_SCHEMA_ID:
            raise RefinementValidationError("unsupported action envelope schema")
        if self.schema_version != SCHEMA_VERSION:
            raise RefinementValidationError("unsupported action envelope version")
        for name in (
            "action_id",
            "observation_event_id",
            "recovery_decision_id",
            "actor_identity",
            "tool_identity",
            "capability_id",
            "effect_domain",
        ):
            _require_nonempty(name, getattr(self, name))
        _require_digest("evidence_root", self.evidence_root)
        _canonical_strings("requested_effects", self.requested_effects)
        _canonical_strings("allowed_effects", self.allowed_effects)
        if (self.parent_action_id is None) != (self.trace_parent_root is None):
            raise RefinementValidationError(
                "parent_action_id and trace_parent_root must be present together"
            )
        if self.parent_action_id is not None:
            _require_nonempty("parent_action_id", self.parent_action_id)
            assert self.trace_parent_root is not None
            _require_digest("trace_parent_root", self.trace_parent_root)

    def canonical_record(self) -> dict[str, Any]:
        self.validate()
        return {
            "schemaId": self.schema_id,
            "schemaVersion": self.schema_version,
            "actionId": self.action_id,
            "parentActionId": self.parent_action_id,
            "observationEventId": self.observation_event_id,
            "recoveryDecisionId": self.recovery_decision_id,
            "actorIdentity": self.actor_identity,
            "toolIdentity": self.tool_identity,
            "capabilityId": self.capability_id,
            "effectDomain": self.effect_domain,
            "evidenceRoot": self.evidence_root,
            "traceParentRoot": self.trace_parent_root,
            "requestedEffects": list(self.requested_effects),
            "allowedEffects": list(self.allowed_effects),
        }

    def digest(self) -> str:
        return _sha256_bytes(_canonical_json(self.canonical_record()))


def envelope_from_scheme_projection(
    projection: Mapping[str, Any],
) -> AgentActionEvidenceEnvelope:
    """Decode the named Scheme projection without accepting provider log shape."""

    required = {
        "schemaId",
        "schemaVersion",
        "actionId",
        "parentActionId",
        "observationEventId",
        "recoveryDecisionId",
        "actorIdentity",
        "toolIdentity",
        "capabilityId",
        "effectDomain",
        "evidenceRoot",
        "traceParentRoot",
        "requestedEffects",
        "allowedEffects",
    }
    if set(projection) != required:
        missing = sorted(required - set(projection))
        unexpected = sorted(set(projection) - required)
        raise RefinementValidationError(
            f"Scheme envelope projection mismatch: missing={missing}, "
            f"unexpected={unexpected}"
        )
    envelope = AgentActionEvidenceEnvelope(
        schema_id=str(projection["schemaId"]),
        schema_version=str(projection["schemaVersion"]),
        action_id=str(projection["actionId"]),
        parent_action_id=(
            None
            if projection["parentActionId"] is None
            else str(projection["parentActionId"])
        ),
        observation_event_id=str(projection["observationEventId"]),
        recovery_decision_id=str(projection["recoveryDecisionId"]),
        actor_identity=str(projection["actorIdentity"]),
        tool_identity=str(projection["toolIdentity"]),
        capability_id=str(projection["capabilityId"]),
        effect_domain=str(projection["effectDomain"]),
        evidence_root=str(projection["evidenceRoot"]),
        trace_parent_root=(
            None
            if projection["traceParentRoot"] is None
            else str(projection["traceParentRoot"])
        ),
        requested_effects=tuple(str(item) for item in projection["requestedEffects"]),
        allowed_effects=tuple(str(item) for item in projection["allowedEffects"]),
    )
    envelope.validate()
    return envelope


@dataclass(frozen=True)
class TransitionPolicy:
    granted_capabilities: tuple[str, ...]
    expected_tool_identity: str
    allowed_effect_domains: tuple[str, ...]
    expected_parent_action_id: str | None
    expected_trace_parent_root: str | None

    def validate(self) -> None:
        _canonical_strings("granted_capabilities", self.granted_capabilities)
        _require_nonempty("expected_tool_identity", self.expected_tool_identity)
        _canonical_strings("allowed_effect_domains", self.allowed_effect_domains)
        if (self.expected_parent_action_id is None) != (
            self.expected_trace_parent_root is None
        ):
            raise RefinementValidationError(
                "policy parent action and trace root must be present together"
            )
        if self.expected_parent_action_id is not None:
            _require_nonempty(
                "expected_parent_action_id", self.expected_parent_action_id
            )
            assert self.expected_trace_parent_root is not None
            _require_digest(
                "expected_trace_parent_root", self.expected_trace_parent_root
            )


@dataclass(frozen=True)
class InvariantEvidence:
    invariant: str
    satisfied: bool
    reason: str

    def canonical_record(self) -> dict[str, Any]:
        return {
            "invariant": self.invariant,
            "satisfied": self.satisfied,
            "reason": self.reason,
        }


@dataclass(frozen=True)
class ExecutableTransitionReceipt:
    envelope_digest: str
    decision: str
    invariants: tuple[InvariantEvidence, ...]
    escalation_reasons: tuple[str, ...]
    output_digest: str
    trace_root: str
    schema_id: str = EXECUTABLE_TRANSITION_RECEIPT_SCHEMA_ID
    schema_version: str = SCHEMA_VERSION

    def canonical_record(self) -> dict[str, Any]:
        return {
            "schemaId": self.schema_id,
            "schemaVersion": self.schema_version,
            "envelopeDigest": self.envelope_digest,
            "decision": self.decision,
            "invariants": [item.canonical_record() for item in self.invariants],
            "escalationReasons": list(self.escalation_reasons),
            "outputDigest": self.output_digest,
            "traceRoot": self.trace_root,
        }


def execute_reference_transition(
    envelope: AgentActionEvidenceEnvelope,
    policy: TransitionPolicy,
) -> ExecutableTransitionReceipt:
    """Execute the deterministic reference transition and fail closed."""

    envelope.validate()
    policy.validate()
    requested = set(envelope.requested_effects)
    allowed = set(envelope.allowed_effects)
    checks = (
        InvariantEvidence(
            "capability-confinement",
            envelope.capability_id in policy.granted_capabilities,
            "capability is explicitly granted"
            if envelope.capability_id in policy.granted_capabilities
            else "capability is outside the granted set",
        ),
        InvariantEvidence(
            "tool-identity",
            envelope.tool_identity == policy.expected_tool_identity,
            "tool identity matches policy"
            if envelope.tool_identity == policy.expected_tool_identity
            else "tool identity does not match policy",
        ),
        InvariantEvidence(
            "effect-containment",
            envelope.effect_domain in policy.allowed_effect_domains
            and requested.issubset(allowed),
            "effect domain and requested effects are contained"
            if envelope.effect_domain in policy.allowed_effect_domains
            and requested.issubset(allowed)
            else "effect domain or requested effects escape containment",
        ),
        InvariantEvidence(
            "causal-continuity",
            envelope.parent_action_id == policy.expected_parent_action_id
            and envelope.trace_parent_root == policy.expected_trace_parent_root,
            "parent action and trace root are continuous"
            if envelope.parent_action_id == policy.expected_parent_action_id
            and envelope.trace_parent_root == policy.expected_trace_parent_root
            else "parent action or trace root breaks causal continuity",
        ),
    )
    failures = tuple(item.invariant for item in checks if not item.satisfied)
    decision = "accepted" if not failures else "fail-closed"
    envelope_digest = envelope.digest()
    output_projection = {
        "decision": decision,
        "invariants": [item.canonical_record() for item in checks],
        "escalationReasons": list(failures),
    }
    output_digest = _sha256_bytes(_canonical_json(output_projection))
    trace_root = _sha256_bytes(
        _canonical_json(
            {
                "envelopeDigest": envelope_digest,
                "outputDigest": output_digest,
                "evidenceRoot": envelope.evidence_root,
                "traceParentRoot": envelope.trace_parent_root,
            }
        )
    )
    return ExecutableTransitionReceipt(
        envelope_digest=envelope_digest,
        decision=decision,
        invariants=checks,
        escalation_reasons=failures,
        output_digest=output_digest,
        trace_root=trace_root,
    )


def replay_reference_transition(
    envelope: AgentActionEvidenceEnvelope,
    policy: TransitionPolicy,
    receipt: ExecutableTransitionReceipt,
) -> ExecutableTransitionReceipt:
    """Independently recompute a receipt and reject any receipt-level drift."""

    replayed = execute_reference_transition(envelope, policy)
    if replayed != receipt:
        raise RefinementValidationError(
            "transition receipt does not match independent replay"
        )
    return replayed


@dataclass(frozen=True)
class IssuerAssertion:
    issuer_identity: str
    key_identity: str
    signature: str


@dataclass(frozen=True)
class TransparencyProof:
    log_identity: str
    leaf_digest: str
    inclusion_path: tuple[str, ...]


@dataclass(frozen=True)
class EvidenceVerificationRequest:
    artifact: bytes
    expected_digest: str
    expected_schema_id: str
    decoded_payload: Mapping[str, Any]
    issuer_assertion: IssuerAssertion | None = None
    transparency_proof: TransparencyProof | None = None


@dataclass(frozen=True)
class VerificationStageReceipt:
    stage: str
    state: str
    reason: str

    def canonical_record(self) -> dict[str, str]:
        return {"stage": self.stage, "state": self.state, "reason": self.reason}


@dataclass(frozen=True)
class EvidenceContentVerificationReceipt:
    artifact_digest: str
    expected_schema_id: str
    digest_integrity: VerificationStageReceipt
    schema_semantic_replay: VerificationStageReceipt
    issuer_authentication: VerificationStageReceipt
    transparency_inclusion: VerificationStageReceipt
    decision: str
    receipt_digest: str
    schema_id: str = EVIDENCE_CONTENT_VERIFICATION_SCHEMA_ID
    schema_version: str = SCHEMA_VERSION

    def stage_records(self) -> tuple[VerificationStageReceipt, ...]:
        return (
            self.digest_integrity,
            self.schema_semantic_replay,
            self.issuer_authentication,
            self.transparency_inclusion,
        )

    def canonical_record(self) -> dict[str, Any]:
        return {
            "schemaId": self.schema_id,
            "schemaVersion": self.schema_version,
            "artifactDigest": self.artifact_digest,
            "expectedSchemaId": self.expected_schema_id,
            "digestIntegrity": self.digest_integrity.canonical_record(),
            "schemaSemanticReplay": self.schema_semantic_replay.canonical_record(),
            "issuerAuthentication": self.issuer_authentication.canonical_record(),
            "transparencyInclusion": self.transparency_inclusion.canonical_record(),
            "decision": self.decision,
            "receiptDigest": self.receipt_digest,
        }


SemanticReplayer = Callable[[Mapping[str, Any]], bool]
IssuerAuthenticator = Callable[[bytes, IssuerAssertion], bool]
TransparencyVerifier = Callable[[str, TransparencyProof], bool]


class EvidenceContentVerifier:
    """ASR-005 verifier whose four authorities remain independently visible."""

    def __init__(
        self,
        semantic_replayers: Mapping[str, SemanticReplayer],
        issuer_authenticator: IssuerAuthenticator,
        transparency_verifier: TransparencyVerifier,
    ) -> None:
        self._semantic_replayers = dict(semantic_replayers)
        self._issuer_authenticator = issuer_authenticator
        self._transparency_verifier = transparency_verifier

    def verify(
        self, request: EvidenceVerificationRequest
    ) -> EvidenceContentVerificationReceipt:
        _require_digest("expected_digest", request.expected_digest)
        _require_nonempty("expected_schema_id", request.expected_schema_id)
        artifact_digest = _sha256_bytes(request.artifact)
        digest_ok = artifact_digest == request.expected_digest
        digest_stage = VerificationStageReceipt(
            "digest-integrity",
            "verified" if digest_ok else "failed",
            "artifact digest matches expected digest"
            if digest_ok
            else "artifact digest mismatch",
        )

        payload_schema = request.decoded_payload.get("schemaId")
        replayer = self._semantic_replayers.get(request.expected_schema_id)
        schema_matches = payload_schema == request.expected_schema_id
        try:
            replay_ok = bool(
                schema_matches
                and replayer is not None
                and replayer(request.decoded_payload)
            )
        except Exception:
            replay_ok = False
        schema_stage = VerificationStageReceipt(
            "schema-semantic-replay",
            "verified" if replay_ok else "failed",
            "schema-specific semantic replay succeeded"
            if replay_ok
            else "schema identity or semantic replay failed",
        )

        if request.issuer_assertion is None:
            issuer_stage = VerificationStageReceipt(
                "issuer-authentication",
                "not-provided",
                "issuer assertion is absent",
            )
        else:
            try:
                issuer_ok = self._issuer_authenticator(
                    request.artifact, request.issuer_assertion
                )
            except Exception:
                issuer_ok = False
            issuer_stage = VerificationStageReceipt(
                "issuer-authentication",
                "verified" if issuer_ok else "failed",
                "issuer authentication succeeded"
                if issuer_ok
                else "issuer authentication failed",
            )

        if request.transparency_proof is None:
            transparency_stage = VerificationStageReceipt(
                "transparency-inclusion",
                "not-provided",
                "transparency proof is absent",
            )
        else:
            try:
                inclusion_ok = self._transparency_verifier(
                    artifact_digest, request.transparency_proof
                )
            except Exception:
                inclusion_ok = False
            transparency_stage = VerificationStageReceipt(
                "transparency-inclusion",
                "verified" if inclusion_ok else "failed",
                "transparency inclusion succeeded"
                if inclusion_ok
                else "transparency inclusion failed",
            )

        stages = (
            digest_stage,
            schema_stage,
            issuer_stage,
            transparency_stage,
        )
        decision = (
            "verified"
            if all(stage.state == "verified" for stage in stages)
            else "fail-closed"
        )
        receipt_projection = {
            "schemaId": EVIDENCE_CONTENT_VERIFICATION_SCHEMA_ID,
            "schemaVersion": SCHEMA_VERSION,
            "artifactDigest": artifact_digest,
            "expectedSchemaId": request.expected_schema_id,
            "stages": [stage.canonical_record() for stage in stages],
            "decision": decision,
        }
        receipt_digest = _sha256_bytes(_canonical_json(receipt_projection))
        return EvidenceContentVerificationReceipt(
            artifact_digest=artifact_digest,
            expected_schema_id=request.expected_schema_id,
            digest_integrity=digest_stage,
            schema_semantic_replay=schema_stage,
            issuer_authentication=issuer_stage,
            transparency_inclusion=transparency_stage,
            decision=decision,
            receipt_digest=receipt_digest,
        )


def replay_evidence_content_verification(
    verifier: EvidenceContentVerifier,
    request: EvidenceVerificationRequest,
    receipt: EvidenceContentVerificationReceipt,
) -> EvidenceContentVerificationReceipt:
    """Re-run all four ASR-005 stages over the exact artifact bytes."""

    replayed = verifier.verify(request)
    if replayed != receipt:
        raise RefinementValidationError(
            "evidence-content receipt does not match exact artifact replay"
        )
    return replayed
