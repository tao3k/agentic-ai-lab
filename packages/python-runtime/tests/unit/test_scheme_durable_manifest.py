# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import pytest

from agentic_ai_lab_runtime.durable_policy import (
    RuntimeDurablePolicyError,
    coerce_runtime_durable_policy_manifest,
)
from scheme_durable_fixtures import scheme_durable_policy_manifest_bytes


SCHEME_DURABLE_MANIFEST = b"""schema=agentic-ai-lab.durable.runtime-policy-manifest.v1
owner=scheme
policy-id=durable/runtime
checkpoint-id-strategy=runtime-generated
require-plan-digest-match=true
history-retention-limit=
checkpoint-store=runtime/checkpoint-store
repair-mode=fail-closed
action-classes=replayable,idempotent,compensatable,terminal,manual
runtime-owner=marlin-agent-core
receipt-schema=agentic-ai-lab.module-system.durable-policy.receipt.v1
receipt-kind=agentic-ai-lab.durable.policy
receipt-valid=true
receipt-diagnostic-count=0
"""


def test_parses_scheme_durable_runtime_manifest_payload() -> None:
    manifest = coerce_runtime_durable_policy_manifest(SCHEME_DURABLE_MANIFEST)

    assert manifest.manifest_schema == "agentic-ai-lab.durable.runtime-policy-manifest.v1"
    assert manifest.policy_id == "durable/runtime"
    assert manifest.owner == "scheme"
    assert manifest.checkpoint_store == "runtime/checkpoint-store"
    assert manifest.repair_mode == "fail-closed"
    assert manifest.action_classes == (
        "replayable",
        "idempotent",
        "compensatable",
        "terminal",
        "manual",
    )
    assert manifest.runtime_owner == "marlin-agent-core"
    assert manifest.receipt_valid is True
    assert manifest.receipt_diagnostic_count == 0
    assert manifest.receipt == SCHEME_DURABLE_MANIFEST


def test_parses_scheme_generated_durable_runtime_manifest_payload() -> None:
    generated = scheme_durable_policy_manifest_bytes()
    manifest = coerce_runtime_durable_policy_manifest(generated)

    assert manifest.policy_id == "durable/python-runtime-envelope"
    assert manifest.owner == "scheme"
    assert manifest.checkpoint_store == "runtime/checkpoint-store"
    assert manifest.repair_mode == "fail-closed"
    assert manifest.receipt == generated


def test_rejects_invalid_scheme_durable_receipt_payload() -> None:
    with pytest.raises(RuntimeDurablePolicyError, match="receipt is invalid"):
        coerce_runtime_durable_policy_manifest(
            SCHEME_DURABLE_MANIFEST.replace(
                b"receipt-valid=true", b"receipt-valid=false"
            )
        )


def test_rejects_unsupported_scheme_durable_action_class() -> None:
    with pytest.raises(RuntimeDurablePolicyError, match="unsupported values"):
        coerce_runtime_durable_policy_manifest(
            SCHEME_DURABLE_MANIFEST.replace(
                b"action-classes=replayable,idempotent,compensatable,terminal,manual",
                b"action-classes=replayable,side-effectful",
            )
        )
