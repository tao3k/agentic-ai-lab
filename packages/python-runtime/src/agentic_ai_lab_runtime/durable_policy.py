# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Durable policy manifests projected from the Scheme control plane."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field
from typing import Any


_DEFAULT_ACTION_CLASSES = (
    "replayable",
    "idempotent",
    "compensatable",
    "terminal",
    "manual",
)
_ALLOWED_ACTION_CLASSES = frozenset(_DEFAULT_ACTION_CLASSES)
_ALLOWED_REPAIR_MODES = frozenset(
    ("fail-closed", "retry", "rebuild", "compensate", "quarantine", "manual")
)
_BACKEND_FIELD_ALIASES = {
    "backend-driver": "driver",
    "backend-concurrent-writes": "concurrent-writes",
    "backend-sync-model": "sync-model",
    "backend-ai-vector-search": "ai-vector-search",
    "backend-vector-index": "vector-index",
    "backend-vector-query": "vector-query",
}


class RuntimeDurablePolicyError(RuntimeError):
    pass


@dataclass(frozen=True)
class RuntimeDurablePolicyManifest:
    manifest_schema: str = "agentic-ai-lab.durable.runtime-policy-manifest.v1"
    policy_id: str = "durable/default"
    owner: str = "scheme"
    checkpoint_id_strategy: str = "runtime-generated"
    require_plan_digest_match: bool = True
    history_retention_limit: int | None = None
    checkpoint_store: str = "runtime/checkpoint-store"
    repair_mode: str = "fail-closed"
    action_classes: tuple[str, ...] = _DEFAULT_ACTION_CLASSES
    runtime_owner: str = "marlin-agent-core"
    receipt_schema: str = "agentic-ai-lab.module-system.durable-policy.receipt.v1"
    receipt_kind: str = "agentic-ai-lab.durable.policy"
    receipt_valid: bool = True
    receipt_diagnostic_count: int = 0
    receipt: bytes = b""
    backend: Mapping[str, Any] = field(default_factory=dict)

    def validate(self) -> "RuntimeDurablePolicyManifest":
        if self.owner != "scheme":
            raise RuntimeDurablePolicyError("durable policy owner must be scheme")
        if self.manifest_schema != "agentic-ai-lab.durable.runtime-policy-manifest.v1":
            raise RuntimeDurablePolicyError(
                "durable policy manifest schema must be agentic-ai-lab.durable.runtime-policy-manifest.v1"
            )
        if self.checkpoint_id_strategy not in {"runtime-generated", "provided"}:
            raise RuntimeDurablePolicyError(
                "checkpoint_id_strategy must be runtime-generated or provided"
            )
        if self.history_retention_limit is not None and self.history_retention_limit < 1:
            raise RuntimeDurablePolicyError("history_retention_limit must be positive")
        if not self.checkpoint_store:
            raise RuntimeDurablePolicyError("checkpoint_store is required")
        if self.repair_mode not in _ALLOWED_REPAIR_MODES:
            raise RuntimeDurablePolicyError("repair_mode is not supported by Scheme policy")
        unsupported_action_classes = tuple(
            action_class
            for action_class in self.action_classes
            if action_class not in _ALLOWED_ACTION_CLASSES
        )
        if unsupported_action_classes:
            raise RuntimeDurablePolicyError(
                f"action_classes include unsupported values: {unsupported_action_classes!r}"
            )
        if not self.receipt_valid:
            raise RuntimeDurablePolicyError("Scheme durable policy receipt is invalid")
        if self.receipt_diagnostic_count < 0:
            raise RuntimeDurablePolicyError("receipt_diagnostic_count must be non-negative")
        return self


def coerce_runtime_durable_policy_manifest(
    value: RuntimeDurablePolicyManifest | Mapping[str, Any] | bytes | None,
) -> RuntimeDurablePolicyManifest:
    if value is None:
        return RuntimeDurablePolicyManifest()
    if isinstance(value, RuntimeDurablePolicyManifest):
        return value.validate()
    if isinstance(value, bytes):
        return _parse_policy_bytes(value).validate()
    return RuntimeDurablePolicyManifest(
        manifest_schema=str(
            value.get(
                "manifest_schema",
                value.get(
                    "manifest-schema",
                    value.get("schema", "agentic-ai-lab.durable.runtime-policy-manifest.v1"),
                ),
            )
        ),
        policy_id=str(value.get("policy_id", value.get("policy-id", "durable/default"))),
        owner=str(value.get("owner", "scheme")),
        checkpoint_id_strategy=str(
            value.get(
                "checkpoint_id_strategy",
                value.get("checkpoint-id-strategy", "runtime-generated"),
            )
        ),
        require_plan_digest_match=_as_bool(
            value.get(
                "require_plan_digest_match",
                value.get("require-plan-digest-match", True),
            )
        ),
        history_retention_limit=_optional_int(
            value.get(
                "history_retention_limit",
                value.get("history-retention-limit"),
            )
        ),
        checkpoint_store=str(
            value.get(
                "checkpoint_store",
                value.get("checkpoint-store", "runtime/checkpoint-store"),
            )
        ),
        repair_mode=str(value.get("repair_mode", value.get("repair-mode", "fail-closed"))),
        action_classes=_as_str_tuple(
            value.get("action_classes", value.get("action-classes", _DEFAULT_ACTION_CLASSES))
        ),
        runtime_owner=str(
            value.get("runtime_owner", value.get("runtime-owner", "marlin-agent-core"))
        ),
        receipt_schema=str(
            value.get(
                "receipt_schema",
                value.get(
                    "receipt-schema",
                    "agentic-ai-lab.module-system.durable-policy.receipt.v1",
                ),
            )
        ),
        receipt_kind=str(
            value.get("receipt_kind", value.get("receipt-kind", "agentic-ai-lab.durable.policy"))
        ),
        receipt_valid=_as_bool(value.get("receipt_valid", value.get("receipt-valid", True))),
        receipt_diagnostic_count=int(
            value.get(
                "receipt_diagnostic_count",
                value.get("receipt-diagnostic-count", 0),
            )
        ),
        receipt=_as_bytes(value.get("receipt", b"")),
        backend=_coerce_backend(value),
    ).validate()


def _parse_policy_bytes(value: bytes) -> RuntimeDurablePolicyManifest:
    return coerce_runtime_durable_policy_manifest({**_parse_manifest_lines(value), "receipt": value})


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


def _coerce_backend(value: Mapping[str, Any]) -> dict[str, Any]:
    backend_value = value.get("backend", {})
    if isinstance(backend_value, Mapping):
        backend = dict(backend_value)
    else:
        backend = {}
    for field, backend_field in _BACKEND_FIELD_ALIASES.items():
        if field in value:
            backend[backend_field] = value[field]
    return backend


def _optional_int(value: Any) -> int | None:
    if value in (None, ""):
        return None
    return int(value)


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
    "RuntimeDurablePolicyError",
    "RuntimeDurablePolicyManifest",
    "coerce_runtime_durable_policy_manifest",
]
