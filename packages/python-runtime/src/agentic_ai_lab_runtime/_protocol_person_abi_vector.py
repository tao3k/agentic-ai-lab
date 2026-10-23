# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Parser for POO Contract-derived promotion ABI qualification vectors."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping

from ._protocol_person_abi_schema import (
    ABI_MAJOR,
    ABI_MINOR,
    IDEMPOTENCY_KEY_SCHEMA,
    REQUEST_SCHEMA,
    REQUIRED_CAPABILITIES,
    REQUIRED_CHECKED_GATES,
    REQUIRED_VECTOR_FIELDS,
)


class ProtocolPersonAbiError(ValueError):
    """Raised when a derived ABI qualification vector is malformed."""


def _parse_symbol_list(value: str, *, field: str) -> tuple[str, ...]:
    if not value.startswith("(") or not value.endswith(")"):
        raise ProtocolPersonAbiError(
            f"{field} must be an ordered ABI symbol list"
        )
    body = value[1:-1].strip()
    return tuple(body.split()) if body else ()


def _parse_vector(text: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line_number, raw_line in enumerate(text.splitlines(), start=1):
        line = raw_line.strip()
        if not line:
            continue
        if "=" not in line:
            raise ProtocolPersonAbiError(
                f"qualification vector line {line_number} has no '='"
            )
        name, value = line.split("=", 1)
        if not name or name in fields:
            raise ProtocolPersonAbiError(
                f"qualification vector field is empty or duplicated: {name!r}"
            )
        fields[name] = value
    return fields


def _required_text(fields: Mapping[str, str], name: str) -> str:
    value = fields.get(name)
    if value is None or value == "":
        raise ProtocolPersonAbiError(f"required ABI field is missing: {name}")
    return value


def _required_epoch(fields: Mapping[str, str], name: str) -> int:
    value = _required_text(fields, name)
    try:
        parsed = int(value)
    except ValueError as error:
        raise ProtocolPersonAbiError(f"{name} must be an integer") from error
    if parsed < 0:
        raise ProtocolPersonAbiError(f"{name} must be non-negative")
    return parsed


@dataclass(frozen=True, slots=True)
class PromotionRequest:
    promotion_id: str
    materialization_id: str
    candidate_digest: str
    subject_id: str
    commitment_id: str
    source_role: str
    target_role: str
    scope: str
    bundle_epoch: int
    authority_epoch: int
    proof_epoch: int
    evaluator_epoch: int
    evidence_root: str
    injection_target: str
    rollback_target: str
    required_capabilities: tuple[str, ...]
    checked_gates: tuple[str, ...]
    validation_receipt_schema: str
    approval_code: str

    @classmethod
    def from_vector(cls, text: str) -> "PromotionRequest":
        fields = _parse_vector(text)
        missing = [name for name in REQUIRED_VECTOR_FIELDS if name not in fields]
        if missing:
            raise ProtocolPersonAbiError(
                "qualification vector is missing fields: " + ", ".join(missing)
            )
        if fields["schema"] != REQUEST_SCHEMA:
            raise ProtocolPersonAbiError("unsupported promotion request schema")
        if _required_epoch(fields, "abi-major") != ABI_MAJOR:
            raise ProtocolPersonAbiError("unsupported Runtime Language ABI major")
        if _required_epoch(fields, "abi-minor") != ABI_MINOR:
            raise ProtocolPersonAbiError("unsupported Runtime Language ABI minor")
        if fields["idempotency-key-schema"] != IDEMPOTENCY_KEY_SCHEMA:
            raise ProtocolPersonAbiError("unsupported idempotency key schema")

        capabilities = _parse_symbol_list(
            fields["required-capabilities"], field="required-capabilities"
        )
        if capabilities != REQUIRED_CAPABILITIES:
            raise ProtocolPersonAbiError(
                "qualification vector changed required capability semantics"
            )
        checked_gates = _parse_symbol_list(
            fields["checked-gates"], field="checked-gates"
        )
        if checked_gates != REQUIRED_CHECKED_GATES:
            raise ProtocolPersonAbiError(
                "qualification vector changed approval gate semantics"
            )
        if fields["approval-code"] != "promotion-approved":
            raise ProtocolPersonAbiError("promotion request is not approved")

        return cls(
            promotion_id=_required_text(fields, "promotion-id"),
            materialization_id=_required_text(fields, "materialization-id"),
            candidate_digest=_required_text(fields, "candidate-digest"),
            subject_id=_required_text(fields, "subject-id"),
            commitment_id=_required_text(fields, "commitment-id"),
            source_role=_required_text(fields, "source-role"),
            target_role=_required_text(fields, "target-role"),
            scope=_required_text(fields, "scope"),
            bundle_epoch=_required_epoch(fields, "bundle-epoch"),
            authority_epoch=_required_epoch(fields, "authority-epoch"),
            proof_epoch=_required_epoch(fields, "proof-epoch"),
            evaluator_epoch=_required_epoch(fields, "evaluator-epoch"),
            evidence_root=_required_text(fields, "evidence-root"),
            injection_target=_required_text(fields, "injection-target"),
            rollback_target=_required_text(fields, "rollback-target"),
            required_capabilities=capabilities,
            checked_gates=checked_gates,
            validation_receipt_schema=_required_text(
                fields, "validation-receipt-schema"
            ),
            approval_code=fields["approval-code"],
        )

    @property
    def idempotency_key(self) -> tuple[str, str, str, str]:
        """Implementation-independent identity used across runtime failover."""

        return (
            self.promotion_id,
            self.materialization_id,
            self.candidate_digest,
            self.injection_target,
        )

    @property
    def epochs(self) -> tuple[int, int, int, int]:
        return (
            self.bundle_epoch,
            self.authority_epoch,
            self.proof_epoch,
            self.evaluator_epoch,
        )
