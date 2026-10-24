# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from agentic_ai_lab_runtime import RuntimeDurableAdapter


def _receipt_fields(payload: bytes) -> dict[str, str]:
    rows: dict[str, str] = {}
    for raw_line in payload.decode("utf-8").splitlines()[1:]:
        key, value = raw_line.split("=", 1)
        rows[key] = value
    return rows


def test_durable_adapter_receipt_carries_scheme_policy_manifest_fields() -> None:
    adapter = RuntimeDurableAdapter.turso(
        policy={
            "policy-id": "durable/runtime",
            "checkpoint-store": "runtime/checkpoint-store",
            "repair-mode": "fail-closed",
            "action-classes": "replayable,idempotent,compensatable",
            "receipt-diagnostic-count": "0",
        }
    )

    fields = _receipt_fields(adapter.receipt())

    assert fields["manifest-schema"] == "agentic-ai-lab.durable.runtime-policy-manifest.v1"
    assert fields["policy-id"] == "durable/runtime"
    assert fields["owner"] == "scheme"
    assert fields["backend"] == "turso"
    assert fields["checkpoint-store"] == "runtime/checkpoint-store"
    assert fields["repair-mode"] == "fail-closed"
    assert fields["action-classes"] == "replayable,idempotent,compensatable"
    assert fields["runtime-owner"] == "marlin-agent-core"
    assert fields["receipt-schema"] == "agentic-ai-lab.module-system.durable-policy.receipt.v1"
    assert fields["receipt-kind"] == "agentic-ai-lab.durable.policy"
    assert fields["receipt-valid"] == "true"
    assert fields["receipt-diagnostic-count"] == "0"
