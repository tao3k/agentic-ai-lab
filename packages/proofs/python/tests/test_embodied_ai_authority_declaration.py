# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from dataclasses import replace

from agentic_ai_lab_proof.embodied_ai_authority_declaration import (
    AuthorityAct,
    AuthorityIssuerKind,
    _provider_fields_match_countermodel,
    _roles_populated_countermodel,
    evaluate_authority_declaration_admission,
)
from agentic_ai_lab_proof.embodied_ai_authority_declaration_replay import canonical_request


def test_role_and_provider_fields_do_not_confer_authority() -> None:
    request = canonical_request()
    request = replace(
        request,
        receipt=replace(
            request.receipt,
            issuer_id=request.provider_id,
            issuer_kind=AuthorityIssuerKind.AI_PROVIDER,
        ),
    )
    assert _roles_populated_countermodel(request)
    assert _provider_fields_match_countermodel(request)
    decision = evaluate_authority_declaration_admission(request)
    assert not decision.admitted
    assert decision.reason_kind == "ai-provider-non-authority"


def test_authority_acts_are_not_interchangeable() -> None:
    request = canonical_request(AuthorityAct.EXECUTION)
    request = replace(
        request,
        receipt=replace(request.receipt, authority_act=AuthorityAct.VERIFICATION),
    )
    assert evaluate_authority_declaration_admission(request).reason_kind == (
        "authority-act-mismatch"
    )


def test_subject_binding_is_exact() -> None:
    request = canonical_request()
    other_subject = replace(request.current_subject, policy_id="other-policy")
    request = replace(request, current_subject=other_subject)
    assert evaluate_authority_declaration_admission(request).reason_kind == (
        "authority-subject-mismatch"
    )


def test_freshness_is_required() -> None:
    request = replace(canonical_request(), current_epoch=21)
    assert evaluate_authority_declaration_admission(request).reason_kind == (
        "authority-context-stale"
    )


def test_separation_of_duties_is_required() -> None:
    request = canonical_request()
    request = replace(
        request,
        actors=replace(request.actors, proposer_id=request.actors.approver_id),
    )
    assert evaluate_authority_declaration_admission(request).reason_kind == (
        "separation-of-duties-violated"
    )


def test_receipt_validity_is_required() -> None:
    request = canonical_request()
    request = replace(request, receipt=replace(request.receipt, receipt_valid=False))
    assert evaluate_authority_declaration_admission(request).reason_kind == (
        "authority-receipt-invalid"
    )


def test_all_six_authority_acts_require_exact_receipts() -> None:
    for authority_act in AuthorityAct:
        decision = evaluate_authority_declaration_admission(
            canonical_request(authority_act)
        )
        assert decision.admitted
        assert decision.requested_act is authority_act
