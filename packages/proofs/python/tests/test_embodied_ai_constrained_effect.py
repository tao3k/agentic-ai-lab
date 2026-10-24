# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from dataclasses import replace

from agentic_ai_lab_proof.embodied_ai_constrained_effect import (
    EffectObligation,
    EffectOutcome,
    EffectReversibility,
    RecoveryPhase,
    _authorization_only_countermodel,
    evaluate_constrained_effect,
)
from agentic_ai_lab_proof.embodied_ai_constrained_effect_replay import canonical_request


def test_authorization_only_does_not_close_effect_domain() -> None:
    request = replace(canonical_request(), observed_effect_ids=())
    assert _authorization_only_countermodel(request)
    decision = evaluate_constrained_effect(request)
    assert not decision.admitted
    assert decision.reason_kind == "effect-domain-coverage-incomplete"


def test_duplicate_requires_prior_commit() -> None:
    request = replace(
        canonical_request(), outcome=EffectOutcome.DUPLICATE, prior_commits=()
    )
    assert evaluate_constrained_effect(request).reason_kind == (
        "duplicate-without-prior-commit"
    )


def test_compensable_recovery_requires_compensation_receipt() -> None:
    request = replace(canonical_request(), compensation_receipts=())
    assert evaluate_constrained_effect(request).reason_kind == (
        "compensation-evidence-missing"
    )


def test_every_compensable_plan_effect_requires_evidence() -> None:
    request = canonical_request()
    request = replace(
        request,
        declared_obligations=(
            request.declared_obligations[0],
            EffectObligation("audit-event", EffectReversibility.COMPENSABLE),
        ),
    )
    assert evaluate_constrained_effect(request).reason_kind == (
        "compensation-evidence-missing"
    )


def test_irreversible_effect_cannot_claim_recovery() -> None:
    request = canonical_request()
    request = replace(
        request,
        declared_obligations=(
            EffectObligation("motor-command", EffectReversibility.IRREVERSIBLE),
            request.declared_obligations[1],
        ),
    )
    assert evaluate_constrained_effect(request).reason_kind == (
        "irreversible-effect-not-recoverable"
    )


def test_recovery_requires_exclusive_fence() -> None:
    request = canonical_request()
    request = replace(
        request, recovery=replace(request.recovery, fence_owner_id="other-owner")
    )
    assert evaluate_constrained_effect(request).reason_kind == (
        "recovery-fence-not-exclusive"
    )


def test_recovery_requires_terminal_phase() -> None:
    request = canonical_request()
    request = replace(
        request, recovery=replace(request.recovery, phase=RecoveryPhase.APPLYING)
    )
    assert evaluate_constrained_effect(request).reason_kind == "recovery-not-terminal"


def test_complete_constrained_effect_is_admitted() -> None:
    decision = evaluate_constrained_effect(canonical_request())
    assert decision.admitted
    assert decision.reason_kind == "constrained-system-effect-admitted"
