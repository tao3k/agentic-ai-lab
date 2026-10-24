# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Runtime envelope manifests projected from Scheme durable receipts."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from typing import Any

from .durable_policy import RuntimeDurablePolicyError, RuntimeDurablePolicyManifest

_DEFAULT_OPERATION_KINDS = (
    "append-fact",
    "write-checkpoint",
    "rebuild-index",
    "claim-job-lease",
    "append-repair-event",
    "retain-artifact",
    "append-communication-event",
    "attach-sandbox-handle",
)


@dataclass(frozen=True)
class RuntimeDurableEnvelopeManifest:
    schema: str = "agentic-ai-lab.durable.runtime-envelope.v1"
    owner: str = "scheme"
    policy_id: str = "durable/default"
    store_id: str = "runtime-store/default"
    backend_id: str = "runtime-backend/marlin-store"
    backend_executable: str = "marlin-runtime-store"
    checkpoint_id_strategy: str = "runtime-generated"
    checkpoint_store: str = "runtime/checkpoint-store"
    checkpoint_store_ref: str = "runtime/checkpoint-store"
    repair_mode: str = "fail-closed"
    action_classes: tuple[str, ...] = (
        "replayable",
        "idempotent",
        "compensatable",
        "terminal",
        "manual",
    )
    operation_kinds: tuple[str, ...] = _DEFAULT_OPERATION_KINDS
    operation_count: int = len(_DEFAULT_OPERATION_KINDS)
    negotiate_argv: tuple[str, ...] = (
        "marlin-runtime-store",
        "durable-runtime-store",
        "negotiate",
    )
    operations_argv: tuple[str, ...] = (
        "marlin-runtime-store",
        "durable-runtime-store",
        "operations",
    )
    runtime_owner: str = "marlin-agent-core"
    policy_valid: bool = True
    store_valid: bool = True
    backend_valid: bool = True
    diagnostic_count: int = 0
    receipt: bytes = b""

    def validate(self) -> "RuntimeDurableEnvelopeManifest":
        if self.schema != "agentic-ai-lab.durable.runtime-envelope.v1":
            raise RuntimeDurablePolicyError(
                "durable runtime envelope schema must be agentic-ai-lab.durable.runtime-envelope.v1"
            )
        if self.owner != "scheme":
            raise RuntimeDurablePolicyError("durable runtime envelope owner must be scheme")
        if not self.policy_id:
            raise RuntimeDurablePolicyError("durable runtime envelope policy_id is required")
        if not self.store_id:
            raise RuntimeDurablePolicyError("durable runtime envelope store_id is required")
        if not self.backend_id:
            raise RuntimeDurablePolicyError("durable runtime envelope backend_id is required")
        if not self.backend_executable:
            raise RuntimeDurablePolicyError(
                "durable runtime envelope backend_executable is required"
            )
        if self.checkpoint_store != self.checkpoint_store_ref:
            raise RuntimeDurablePolicyError(
                "durable runtime envelope checkpoint store refs must agree"
            )
        if self.operation_count != len(self.operation_kinds):
            raise RuntimeDurablePolicyError(
                "durable runtime envelope operation_count must match operation_kinds"
            )
        if self.negotiate_argv[:1] != (self.backend_executable,):
            raise RuntimeDurablePolicyError(
                "durable runtime envelope negotiate_argv must start with backend_executable"
            )
        if self.operations_argv[:1] != (self.backend_executable,):
            raise RuntimeDurablePolicyError(
                "durable runtime envelope operations_argv must start with backend_executable"
            )
        if not (self.policy_valid and self.store_valid and self.backend_valid):
            raise RuntimeDurablePolicyError("durable runtime envelope contains invalid receipts")
        if self.diagnostic_count < 0:
            raise RuntimeDurablePolicyError("diagnostic_count must be non-negative")
        return self

    def to_policy_manifest(self) -> RuntimeDurablePolicyManifest:
        return RuntimeDurablePolicyManifest(
            policy_id=self.policy_id,
            checkpoint_id_strategy=self.checkpoint_id_strategy,
            checkpoint_store=self.checkpoint_store,
            repair_mode=self.repair_mode,
            action_classes=self.action_classes,
            runtime_owner=self.runtime_owner,
            receipt_valid=self.policy_valid,
            receipt_diagnostic_count=0,
            receipt=self.receipt,
        ).validate()


def coerce_runtime_durable_envelope_manifest(
    value: RuntimeDurableEnvelopeManifest | Mapping[str, Any] | bytes | None,
) -> RuntimeDurableEnvelopeManifest:
    if value is None:
        return RuntimeDurableEnvelopeManifest()
    if isinstance(value, RuntimeDurableEnvelopeManifest):
        return value.validate()
    if isinstance(value, bytes):
        return _parse_envelope_bytes(value).validate()
    return RuntimeDurableEnvelopeManifest(
        schema=str(value.get("schema", "agentic-ai-lab.durable.runtime-envelope.v1")),
        owner=str(value.get("owner", "scheme")),
        policy_id=str(value.get("policy_id", value.get("policy-id", "durable/default"))),
        store_id=str(value.get("store_id", value.get("store-id", "runtime-store/default"))),
        backend_id=str(
            value.get("backend_id", value.get("backend-id", "runtime-backend/marlin-store"))
        ),
        backend_executable=str(
            value.get(
                "backend_executable",
                value.get("backend-executable", "marlin-runtime-store"),
            )
        ),
        checkpoint_id_strategy=str(
            value.get(
                "checkpoint_id_strategy",
                value.get("checkpoint-id-strategy", "runtime-generated"),
            )
        ),
        checkpoint_store=str(
            value.get(
                "checkpoint_store",
                value.get("checkpoint-store", "runtime/checkpoint-store"),
            )
        ),
        checkpoint_store_ref=str(
            value.get(
                "checkpoint_store_ref",
                value.get("checkpoint-store-ref", "runtime/checkpoint-store"),
            )
        ),
        repair_mode=str(value.get("repair_mode", value.get("repair-mode", "fail-closed"))),
        action_classes=_as_str_tuple(
            value.get(
                "action_classes",
                value.get(
                    "action-classes",
                    ("replayable", "idempotent", "compensatable", "terminal", "manual"),
                ),
            )
        ),
        operation_kinds=_as_str_tuple(
            value.get("operation_kinds", value.get("operation-kinds", _DEFAULT_OPERATION_KINDS))
        ),
        operation_count=int(
            value.get("operation_count", value.get("operation-count", len(_DEFAULT_OPERATION_KINDS)))
        ),
        negotiate_argv=_as_str_tuple(
            value.get(
                "negotiate_argv",
                value.get(
                    "negotiate-argv",
                    ("marlin-runtime-store", "durable-runtime-store", "negotiate"),
                ),
            )
        ),
        operations_argv=_as_str_tuple(
            value.get(
                "operations_argv",
                value.get(
                    "operations-argv",
                    ("marlin-runtime-store", "durable-runtime-store", "operations"),
                ),
            )
        ),
        runtime_owner=str(
            value.get("runtime_owner", value.get("runtime-owner", "marlin-agent-core"))
        ),
        policy_valid=_as_bool(value.get("policy_valid", value.get("policy-valid", True))),
        store_valid=_as_bool(value.get("store_valid", value.get("store-valid", True))),
        backend_valid=_as_bool(value.get("backend_valid", value.get("backend-valid", True))),
        diagnostic_count=int(value.get("diagnostic_count", value.get("diagnostic-count", 0))),
        receipt=_as_bytes(value.get("receipt", b"")),
    ).validate()


def _parse_envelope_bytes(value: bytes) -> RuntimeDurableEnvelopeManifest:
    return coerce_runtime_durable_envelope_manifest(
        {**_parse_manifest_lines(value), "receipt": value}
    )


def _parse_manifest_lines(value: bytes) -> dict[str, str]:
    fields: dict[str, str] = {}
    for raw_line in value.decode("utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, field_value = line.split("=", 1)
        fields[key.strip()] = field_value.strip()
    return fields


def _as_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    return str(value).lower() in {"1", "true", "yes", "on"}


def _as_bytes(value: Any) -> bytes:
    if isinstance(value, bytes):
        return value
    return str(value).encode("utf-8")


def _as_str_tuple(value: Any) -> tuple[str, ...]:
    if value is None:
        return ()
    if isinstance(value, str):
        return tuple(part.strip() for part in value.split(",") if part.strip())
    return tuple(str(item) for item in value)


__all__ = [
    "RuntimeDurableEnvelopeManifest",
    "coerce_runtime_durable_envelope_manifest",
]
