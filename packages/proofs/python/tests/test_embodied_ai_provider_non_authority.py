# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from agentic_ai_lab_proof.embodied_ai_provider_non_authority import (
    AnalysisCandidateV1,
    AuthorityEnvelopeV1,
    AuthorityRole,
    IssuerKind,
    ProviderIdentityV1,
    evaluate_provider_admission,
)


def _candidate(**overrides: str) -> AnalysisCandidateV1:
    identity = {
        "provider_id": "provider-1",
        "model_id": "model-1",
        "input_context_id": "context-1",
        "generation_version": "generation-1",
    }
    identity.update(overrides)
    return AnalysisCandidateV1(
        candidate_id="candidate-1",
        provider=ProviderIdentityV1(**identity),
    )


def test_role_only_policy_accepts_forged_ai_provider_counterexample() -> None:
    role = AuthorityRole.EFFECT_AUTHORIZATION
    trace = evaluate_provider_admission(
        _candidate(),
        AuthorityEnvelopeV1(
            issuer_kind=IssuerKind.AI_PROVIDER,
            issuer_id="provider-1",
            grants=frozenset({role}),
        ),
        role,
    )

    assert trace.role_only_would_admit is True
    assert trace.decision.admitted is False
    assert trace.decision.reason_kind == "ai-provider-non-authority"


def test_ai_provider_cannot_hold_any_ease005_authority_role() -> None:
    roles = frozenset(AuthorityRole)
    authority = AuthorityEnvelopeV1(
        issuer_kind=IssuerKind.AI_PROVIDER,
        issuer_id="provider-1",
        grants=roles,
    )

    for role in AuthorityRole:
        trace = evaluate_provider_admission(_candidate(), authority, role)
        assert trace.role_only_would_admit is True
        assert trace.decision.admitted is False
        assert trace.decision.reason_kind == "ai-provider-non-authority"


def test_independent_human_authority_can_admit_reviewed_candidate() -> None:
    role = AuthorityRole.VERIFICATION_DISCHARGE
    trace = evaluate_provider_admission(
        _candidate(),
        AuthorityEnvelopeV1(
            issuer_kind=IssuerKind.HUMAN_AUTHORITY,
            issuer_id="reviewer-1",
            grants=frozenset({role}),
        ),
        role,
    )

    assert trace.decision.admitted is True
    assert trace.decision.reason_kind == "independent-authority-admitted"
    assert trace.decision.provider_id == "provider-1"
    assert trace.decision.authority_id == "reviewer-1"


def test_missing_provider_provenance_fails_closed_before_authority_admission() -> None:
    role = AuthorityRole.RESIDUAL_RISK_ACCEPTANCE
    trace = evaluate_provider_admission(
        _candidate(model_id=""),
        AuthorityEnvelopeV1(
            issuer_kind=IssuerKind.HUMAN_AUTHORITY,
            issuer_id="risk-owner-1",
            grants=frozenset({role}),
        ),
        role,
    )

    assert trace.decision.admitted is False
    assert trace.decision.reason_kind == "provider-provenance-invalid"


def test_missing_role_grant_fails_closed() -> None:
    trace = evaluate_provider_admission(
        _candidate(),
        AuthorityEnvelopeV1(
            issuer_kind=IssuerKind.ORGANIZATIONAL_AUTHORITY,
            issuer_id="security-board-1",
            grants=frozenset(),
        ),
        AuthorityRole.RESIDUAL_RISK_ACCEPTANCE,
    )

    assert trace.decision.admitted is False
    assert trace.decision.reason_kind == "authority-role-not-granted"
    assert trace.schema_id == "agentic-ai-lab.ai-security.provider-admission-trace.v1"
