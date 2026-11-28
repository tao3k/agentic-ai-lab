# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import replace
from hashlib import sha256

import pytest

from agentic_ai_lab_proof.ai_security_executable_refinement import (
    ACTION_EVIDENCE_ENVELOPE_SCHEMA_ID,
    AgentActionEvidenceEnvelope,
    EvidenceContentVerifier,
    EvidenceVerificationRequest,
    IssuerAssertion,
    RefinementValidationError,
    TransitionPolicy,
    TransparencyProof,
    execute_reference_transition,
    envelope_from_scheme_projection,
    replay_reference_transition,
    replay_evidence_content_verification,
)


def digest(value: bytes) -> str:
    return f"sha256:{sha256(value).hexdigest()}"


def envelope() -> AgentActionEvidenceEnvelope:
    return AgentActionEvidenceEnvelope(
        action_id="action-2",
        parent_action_id="action-1",
        observation_event_id="observation-7",
        recovery_decision_id="decision-7",
        actor_identity="agent:codex",
        tool_identity="tool:filesystem-patch",
        capability_id="capability:repo-write",
        effect_domain="workspace:agentic-ai-lab",
        evidence_root=digest(b"evidence"),
        trace_parent_root=digest(b"parent-trace"),
        requested_effects=("file:update",),
        allowed_effects=("file:create", "file:update"),
    )


def policy() -> TransitionPolicy:
    return TransitionPolicy(
        granted_capabilities=("capability:repo-write",),
        expected_tool_identity="tool:filesystem-patch",
        allowed_effect_domains=("workspace:agentic-ai-lab",),
        expected_parent_action_id="action-1",
        expected_trace_parent_root=digest(b"parent-trace"),
    )


def test_valid_transition_has_four_explicit_invariants() -> None:
    receipt = execute_reference_transition(envelope(), policy())
    assert receipt.decision == "accepted"
    assert [item.invariant for item in receipt.invariants] == [
        "capability-confinement",
        "tool-identity",
        "effect-containment",
        "causal-continuity",
    ]
    assert all(item.satisfied for item in receipt.invariants)


@pytest.mark.parametrize(
    ("changed_envelope", "failed_invariant"),
    [
        (
            replace(envelope(), capability_id="capability:admin"),
            "capability-confinement",
        ),
        (replace(envelope(), tool_identity="tool:spoofed"), "tool-identity"),
        (
            replace(envelope(), requested_effects=("network:egress",)),
            "effect-containment",
        ),
        (
            replace(
                envelope(),
                parent_action_id="action-other",
                trace_parent_root=digest(b"other-parent"),
            ),
            "causal-continuity",
        ),
    ],
)
def test_each_high_value_invariant_fails_closed(
    changed_envelope: AgentActionEvidenceEnvelope,
    failed_invariant: str,
) -> None:
    receipt = execute_reference_transition(changed_envelope, policy())
    assert receipt.decision == "fail-closed"
    assert failed_invariant in receipt.escalation_reasons


def test_transition_replay_is_deterministic_and_detects_tampering() -> None:
    receipt = execute_reference_transition(envelope(), policy())
    assert replay_reference_transition(envelope(), policy(), receipt) == receipt
    with pytest.raises(RefinementValidationError):
        replay_reference_transition(
            envelope(), policy(), replace(receipt, trace_root=digest(b"tampered"))
        )


def test_envelope_requires_canonical_effect_sets() -> None:
    with pytest.raises(RefinementValidationError):
        replace(
            envelope(), requested_effects=("file:update", "file:update")
        ).validate()


def test_scheme_projection_maps_to_the_same_typed_identity() -> None:
    expected = envelope()
    projection = expected.canonical_record()
    assert envelope_from_scheme_projection(projection) == expected
    assert envelope_from_scheme_projection(projection).digest() == expected.digest()


def test_scheme_projection_rejects_untyped_provider_fields() -> None:
    projection = envelope().canonical_record()
    projection["cursorLogLine"] = "provider-specific"
    with pytest.raises(RefinementValidationError):
        envelope_from_scheme_projection(projection)


def verifier() -> EvidenceContentVerifier:
    return EvidenceContentVerifier(
        semantic_replayers={
            ACTION_EVIDENCE_ENVELOPE_SCHEMA_ID: (
                lambda payload: payload.get("actionId") == "action-2"
            )
        },
        issuer_authenticator=lambda artifact, assertion: (
            artifact == b"artifact"
            and assertion.issuer_identity == "issuer:agentic-ai-lab"
            and assertion.signature == "signature:valid"
        ),
        transparency_verifier=lambda artifact_digest, proof: (
            proof.leaf_digest == artifact_digest
            and proof.log_identity == "log:enterprise"
            and bool(proof.inclusion_path)
        ),
    )


def request() -> EvidenceVerificationRequest:
    artifact = b"artifact"
    return EvidenceVerificationRequest(
        artifact=artifact,
        expected_digest=digest(artifact),
        expected_schema_id=ACTION_EVIDENCE_ENVELOPE_SCHEMA_ID,
        decoded_payload={
            "schemaId": ACTION_EVIDENCE_ENVELOPE_SCHEMA_ID,
            "actionId": "action-2",
        },
        issuer_assertion=IssuerAssertion(
            issuer_identity="issuer:agentic-ai-lab",
            key_identity="key:release",
            signature="signature:valid",
        ),
        transparency_proof=TransparencyProof(
            log_identity="log:enterprise",
            leaf_digest=digest(artifact),
            inclusion_path=(digest(b"node"),),
        ),
    )


def test_asr_005_records_all_four_stages_without_validated_boolean() -> None:
    receipt = verifier().verify(request())
    assert receipt.decision == "verified"
    assert [stage.state for stage in receipt.stage_records()] == [
        "verified",
        "verified",
        "verified",
        "verified",
    ]
    assert "validated" not in receipt.canonical_record()


def test_digest_failure_does_not_collapse_other_stage_evidence() -> None:
    receipt = verifier().verify(replace(request(), expected_digest=digest(b"wrong")))
    assert receipt.decision == "fail-closed"
    assert receipt.digest_integrity.state == "failed"
    assert receipt.schema_semantic_replay.state == "verified"
    assert receipt.issuer_authentication.state == "verified"
    assert receipt.transparency_inclusion.state == "verified"


def test_schema_semantic_replay_is_schema_specific() -> None:
    changed = replace(
        request(),
        decoded_payload={
            "schemaId": ACTION_EVIDENCE_ENVELOPE_SCHEMA_ID,
            "actionId": "spoofed",
        },
    )
    receipt = verifier().verify(changed)
    assert receipt.schema_semantic_replay.state == "failed"
    assert receipt.decision == "fail-closed"


def test_missing_issuer_and_transparency_evidence_remains_explicit() -> None:
    receipt = verifier().verify(
        replace(request(), issuer_assertion=None, transparency_proof=None)
    )
    assert receipt.issuer_authentication.state == "not-provided"
    assert receipt.transparency_inclusion.state == "not-provided"
    assert receipt.decision == "fail-closed"


def test_issuer_and_transparency_fail_independently() -> None:
    changed = replace(
        request(),
        issuer_assertion=replace(
            request().issuer_assertion,  # type: ignore[arg-type]
            signature="signature:forged",
        ),
        transparency_proof=replace(
            request().transparency_proof,  # type: ignore[arg-type]
            inclusion_path=(),
        ),
    )
    receipt = verifier().verify(changed)
    assert receipt.issuer_authentication.state == "failed"
    assert receipt.transparency_inclusion.state == "failed"
    assert receipt.digest_integrity.state == "verified"
    assert receipt.schema_semantic_replay.state == "verified"


def test_asr_005_exact_artifact_replay_detects_receipt_tampering() -> None:
    checked = verifier()
    original_request = request()
    receipt = checked.verify(original_request)
    assert (
        replay_evidence_content_verification(
            checked, original_request, receipt
        )
        == receipt
    )
    with pytest.raises(RefinementValidationError):
        replay_evidence_content_verification(
            checked,
            original_request,
            replace(receipt, receipt_digest=digest(b"tampered-receipt")),
        )


def test_verifier_callback_errors_fail_closed_per_stage() -> None:
    def unavailable(*_args: object) -> bool:
        raise RuntimeError("authority unavailable")

    checked = EvidenceContentVerifier(
        semantic_replayers={ACTION_EVIDENCE_ENVELOPE_SCHEMA_ID: unavailable},
        issuer_authenticator=unavailable,
        transparency_verifier=unavailable,
    )
    receipt = checked.verify(request())
    assert receipt.digest_integrity.state == "verified"
    assert receipt.schema_semantic_replay.state == "failed"
    assert receipt.issuer_authentication.state == "failed"
    assert receipt.transparency_inclusion.state == "failed"
    assert receipt.decision == "fail-closed"
