# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import replace
from hashlib import sha256
import json
from pathlib import Path

from agentic_ai_lab_proof.embodied_ai_constrained_effect import (
    CompensationReceipt,
    ConstrainedEffectRequest,
    EffectAuthorizationReceipt,
    EffectObligation,
    EffectOutcome,
    EffectReversibility,
    PriorCommitReceipt,
    RecoveryPhase,
    RecoveryReceipt,
    _authorization_only_countermodel,
    evaluate_constrained_effect,
)


IMPLEMENTATION_PATH = Path(__file__).with_name("embodied_ai_constrained_effect.py")


def canonical_request() -> ConstrainedEffectRequest:
    return ConstrainedEffectRequest(
        request_id="ease001-request-1",
        transaction_id="ease001-transaction-1",
        subject_id="robot-motion-stack:v1",
        effect_id="motor-command",
        outcome=EffectOutcome.RECOVERED,
        authorization=EffectAuthorizationReceipt(
            authority_id="motion-safety-authority",
            subject_id="robot-motion-stack:v1",
            effect_id="motor-command",
            receipt_valid=True,
        ),
        declared_obligations=(
            EffectObligation("motor-command", EffectReversibility.COMPENSABLE),
            EffectObligation("audit-event", EffectReversibility.REVERSIBLE),
        ),
        observed_effect_ids=("audit-event", "motor-command"),
        prior_commits=(
            PriorCommitReceipt("ease001-transaction-1", "motor-command", True),
        ),
        compensation_receipts=(
            CompensationReceipt("ease001-transaction-1", "motor-command", True),
        ),
        recovery=RecoveryReceipt(
            transaction_id="ease001-transaction-1",
            claimant_id="recovery-owner-1",
            fence_owner_id="recovery-owner-1",
            phase=RecoveryPhase.COMPENSATED,
            receipt_valid=True,
        ),
    )


def replay_cases() -> tuple[tuple[str, ConstrainedEffectRequest], ...]:
    valid = canonical_request()
    return (
        ("authorized-only-domain-gap", replace(valid, observed_effect_ids=())),
        (
            "duplicate-without-prior-commit",
            replace(valid, outcome=EffectOutcome.DUPLICATE, prior_commits=()),
        ),
        (
            "compensation-evidence-missing",
            replace(valid, compensation_receipts=()),
        ),
        (
            "irreversible-effect-not-recoverable",
            replace(
                valid,
                declared_obligations=(
                    EffectObligation(
                        "motor-command", EffectReversibility.IRREVERSIBLE
                    ),
                    valid.declared_obligations[1],
                ),
            ),
        ),
        (
            "recovery-fence-not-exclusive",
            replace(
                valid,
                recovery=replace(valid.recovery, fence_owner_id="other-owner"),
            ),
        ),
        (
            "recovery-not-terminal",
            replace(valid, recovery=replace(valid.recovery, phase=RecoveryPhase.APPLYING)),
        ),
        ("constrained-effect-admitted", valid),
    )


def canonical_receipt() -> dict[str, object]:
    cases = []
    for case_id, request in replay_cases():
        decision = evaluate_constrained_effect(request)
        cases.append(
            {
                "admitted": decision.admitted,
                "authorizationOnlyWouldAdmit": _authorization_only_countermodel(
                    request
                ),
                "caseId": case_id,
                "effectId": decision.effect_id,
                "reasonKind": decision.reason_kind,
                "requestId": decision.request_id,
                "transactionId": decision.transaction_id,
            }
        )

    implementation_digest = f"sha256:{sha256(IMPLEMENTATION_PATH.read_bytes()).hexdigest()}"
    payload: dict[str, object] = {
        "cases": cases,
        "claimId": "EASE-001",
        "implementationArtifactDigest": implementation_digest,
        "implementationArtifactId": (
            "src/agentic_ai_lab_proof/embodied_ai_constrained_effect.py"
        ),
        "referenceTransitionId": (
            "python://src/agentic_ai_lab_proof/embodied_ai_constrained_effect.py"
            "#item/function/evaluate_constrained_effect"
        ),
        "schemaId": "agentic-ai-lab.ai-security.ease001-replay-receipt.v1",
    }
    trace_root = sha256(
        json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    return {**payload, "traceRoot": f"sha256:{trace_root}"}


def main() -> None:
    print(json.dumps(canonical_receipt(), sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
