# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Implementation-neutral receipt semantics for Runtime Language ABI."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

from ._protocol_person_abi_schema import (
    OUTCOMES,
    RECEIPT_SCHEMA,
    REQUIRED_CAPABILITIES,
)
from ._protocol_person_abi_vector import PromotionRequest


@dataclass(frozen=True, slots=True)
class PromotionRuntimeReceipt:
    request: PromotionRequest
    implementation_id: str
    implementation_version: str
    language: str
    supported_capabilities: tuple[str, ...]
    attempt: int
    outcome: str
    observed_epochs: tuple[int, int, int, int]
    materialization_digest: str | None = None
    injection_receipt_digest: str | None = None
    rollback_receipt_digest: str | None = None
    causal_receipt_digest: str | None = None
    runtime_executed: bool = True

    @property
    def schema(self) -> str:
        return RECEIPT_SCHEMA

    @property
    def idempotency_key(self) -> tuple[str, str, str, str]:
        return self.request.idempotency_key

    @property
    def capability_qualified(self) -> bool:
        return set(REQUIRED_CAPABILITIES).issubset(self.supported_capabilities)

    @property
    def epoch_current(self) -> bool:
        return self.observed_epochs == self.request.epochs

    def failures(self) -> tuple[str, ...]:
        failures: list[str] = []
        if self.attempt <= 0:
            failures.append("invalid-attempt")
        if self.outcome not in OUTCOMES:
            failures.append("invalid-outcome")
        if not self.capability_qualified and self.outcome != "rejected-capability":
            failures.append("unsupported-capability-effect")
        if self.capability_qualified and self.outcome == "rejected-capability":
            failures.append("false-capability-rejection")
        if not self.epoch_current and self.outcome != "rejected-stale-epoch":
            failures.append("stale-epoch-effect")
        if self.epoch_current and self.outcome == "rejected-stale-epoch":
            failures.append("false-stale-rejection")
        if self.outcome == "materialized" and not self.materialization_digest:
            failures.append("materialization-digest-missing")
        if self.outcome in {"injected", "replayed-active"} and not (
            self.materialization_digest and self.injection_receipt_digest
        ):
            failures.append("injection-receipt-incomplete")
        if self.outcome == "replayed-active" and not self.causal_receipt_digest:
            failures.append("replay-causal-receipt-missing")
        if self.outcome == "rolled-back" and not self.rollback_receipt_digest:
            failures.append("rollback-receipt-missing")
        if self.outcome in {
            "rejected-stale-epoch",
            "rejected-capability",
            "failed",
        } and any(
            (
                self.materialization_digest,
                self.injection_receipt_digest,
                self.rollback_receipt_digest,
            )
        ):
            failures.append("rejected-outcome-carried-effects")
        if not self.runtime_executed:
            failures.append("runtime-execution-receipt-missing")
        return tuple(failures)

    @property
    def valid(self) -> bool:
        return not self.failures()

    @property
    def active(self) -> bool:
        return self.valid and self.outcome in {"injected", "replayed-active"}

    def normalized_semantics(self) -> tuple[object, ...]:
        """Implementation-neutral comparison surface for qualification."""

        return (
            self.idempotency_key,
            self.outcome,
            self.observed_epochs,
            self.materialization_digest,
            self.injection_receipt_digest,
            self.rollback_receipt_digest,
            self.causal_receipt_digest,
            self.valid,
            self.active,
        )


def receipts_exactly_once(
    receipts: Iterable[PromotionRuntimeReceipt],
) -> bool:
    receipts_tuple = tuple(receipts)
    if not receipts_tuple:
        return False
    key = receipts_tuple[0].idempotency_key
    if any(receipt.idempotency_key != key for receipt in receipts_tuple):
        return False
    committed = sum(
        receipt.valid and receipt.outcome == "injected"
        for receipt in receipts_tuple
    )
    return committed == 1
