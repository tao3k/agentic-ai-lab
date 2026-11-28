# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from pathlib import Path

import pytest

from agentic_ai_lab_runtime.protocol_person_abi import (
    ABI_MINOR,
    REQUIRED_CAPABILITIES,
    PromotionRequest,
    PromotionRuntimeReceipt,
    ProtocolPersonAbiError,
    receipts_exactly_once,
)


REPOSITORY_ROOT = Path(__file__).resolve().parents[4]
VECTOR_PATH = (
    REPOSITORY_ROOT
    / "t"
    / "fixtures"
    / "runtime-language-abi"
    / "promotion-request-v1.vector"
)


@pytest.fixture
def promotion_request() -> PromotionRequest:
    return PromotionRequest.from_vector(VECTOR_PATH.read_text())


def receipt(
    request: PromotionRequest,
    *,
    implementation_id: str = "python-runtime",
    language: str = "python",
    supported_capabilities: tuple[str, ...] = REQUIRED_CAPABILITIES,
    attempt: int = 1,
    outcome: str = "injected",
    observed_epochs: tuple[int, int, int, int] = (11, 7, 5, 3),
    materialization_digest: str | None = "materialization-digest-1",
    injection_receipt_digest: str | None = "injection-receipt-digest-1",
    rollback_receipt_digest: str | None = None,
    causal_receipt_digest: str | None = None,
) -> PromotionRuntimeReceipt:
    return PromotionRuntimeReceipt(
        request=request,
        implementation_id=implementation_id,
        implementation_version="0.1.0",
        language=language,
        supported_capabilities=supported_capabilities,
        attempt=attempt,
        outcome=outcome,
        observed_epochs=observed_epochs,
        materialization_digest=materialization_digest,
        injection_receipt_digest=injection_receipt_digest,
        rollback_receipt_digest=rollback_receipt_digest,
        causal_receipt_digest=causal_receipt_digest,
    )


def test_python_consumes_the_contract_derived_abi_vector(
    promotion_request: PromotionRequest,
) -> None:
    assert ABI_MINOR == 1
    assert promotion_request.idempotency_key == (
        "promotion-1",
        "materialization-1",
        "candidate-digest-1",
        "org-bundle-active",
    )
    assert promotion_request.epochs == (11, 7, 5, 3)
    assert promotion_request.required_capabilities == REQUIRED_CAPABILITIES


def test_vector_rejects_private_capability_semantics() -> None:
    vector = VECTOR_PATH.read_text().replace(
        " LANGUAGE_QUALIFICATION)", ")"
    )
    with pytest.raises(ProtocolPersonAbiError):
        PromotionRequest.from_vector(vector)


def test_complete_injection_receipt_is_active(
    promotion_request: PromotionRequest,
) -> None:
    result = receipt(promotion_request)
    assert result.valid
    assert result.active


def test_stale_epoch_and_missing_capability_fail_closed(
    promotion_request: PromotionRequest,
) -> None:
    stale = receipt(promotion_request, observed_epochs=(12, 7, 5, 3))
    unsupported = receipt(
        promotion_request,
        supported_capabilities=("PROMOTION_MATERIALIZE",),
    )
    assert "stale-epoch-effect" in stale.failures()
    assert "unsupported-capability-effect" in unsupported.failures()


def test_rejected_stale_epoch_carries_no_effects(
    promotion_request: PromotionRequest,
) -> None:
    result = receipt(
        promotion_request,
        outcome="rejected-stale-epoch",
        observed_epochs=(12, 7, 5, 3),
        materialization_digest=None,
        injection_receipt_digest=None,
    )
    assert result.valid
    assert not result.active


def test_replay_is_causal_and_not_a_second_commit(
    promotion_request: PromotionRequest,
) -> None:
    injected = receipt(promotion_request)
    replay = receipt(
        promotion_request,
        attempt=2,
        outcome="replayed-active",
        causal_receipt_digest="original-runtime-receipt-digest",
    )
    duplicate = receipt(
        promotion_request,
        attempt=2,
        materialization_digest="materialization-digest-2",
        injection_receipt_digest="injection-receipt-digest-2",
    )
    assert replay.valid
    assert receipts_exactly_once((injected, replay))
    assert not receipts_exactly_once((injected, duplicate))


def test_normalized_semantics_ignore_runtime_implementation(
    promotion_request: PromotionRequest,
) -> None:
    python = receipt(promotion_request)
    marlin = receipt(
        promotion_request,
        implementation_id="marlin-agent-core",
        language="rust",
    )
    assert python.normalized_semantics() == marlin.normalized_semantics()
