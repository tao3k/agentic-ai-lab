# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import pytest

from agentic_ai_lab_runtime import (
    RuntimeDurableAdapter,
    RuntimeDurablePolicyError,
    coerce_runtime_durable_envelope_manifest,
)
from scheme_durable_fixtures import scheme_durable_runtime_envelope_bytes


SCHEME_DURABLE_RUNTIME_ENVELOPE = b"""schema=agentic-ai-lab.durable.runtime-envelope.v1
owner=scheme
policy-schema=agentic-ai-lab.durable.runtime-policy-manifest.v1
policy-id=durable/default
checkpoint-id-strategy=runtime-generated
checkpoint-store=runtime/checkpoint-store
repair-mode=fail-closed
action-classes=replayable,idempotent,compensatable,terminal,manual
store-schema=agentic-ai-lab.module-system.durable-runtime-store-contract.receipt.v1
store-id=runtime-store/default
store-owner=marlin-runtime-store
fact-log-ref=runtime/fact-log
checkpoint-store-ref=runtime/checkpoint-store
derived-index-ref=runtime/derived-index
job-store-ref=runtime/job-store
repair-journal-ref=runtime/repair-journal
artifact-store-ref=runtime/artifact-store
communication-ledger-ref=runtime/communication-ledger
sandbox-ledger-ref=runtime/sandbox-ledger
ledger-kinds=fact-log,checkpoint,derived-index,job,repair,artifact,communication,sandbox
capability-flags=append-fact,write-checkpoint,rebuild-index,claim-job-lease,append-repair-event,retain-artifact,append-communication-event,attach-sandbox-handle
backend-schema=agentic-ai-lab.module-system.durable-runtime-store-backend.receipt.v1
backend-id=runtime-backend/marlin-store
backend-kind=marlin-runtime-store
backend-executable=marlin-runtime-store
backend-protocol=stdout-s-expression
operation-kinds=append-fact,write-checkpoint,rebuild-index,claim-job-lease,append-repair-event,retain-artifact,append-communication-event,attach-sandbox-handle
operation-count=8
negotiate-argv=marlin-runtime-store,durable-runtime-store,negotiate
operations-argv=marlin-runtime-store,durable-runtime-store,operations
runtime-owner=marlin-agent-core
policy-valid=true
store-valid=true
backend-valid=true
diagnostic-count=0
runtime-executed=
"""


def test_parses_scheme_durable_runtime_envelope_payload() -> None:
    envelope = coerce_runtime_durable_envelope_manifest(
        SCHEME_DURABLE_RUNTIME_ENVELOPE
    )

    assert envelope.schema == "agentic-ai-lab.durable.runtime-envelope.v1"
    assert envelope.owner == "scheme"
    assert envelope.policy_id == "durable/default"
    assert envelope.store_id == "runtime-store/default"
    assert envelope.backend_id == "runtime-backend/marlin-store"
    assert envelope.backend_executable == "marlin-runtime-store"
    assert envelope.checkpoint_store == "runtime/checkpoint-store"
    assert envelope.checkpoint_store_ref == "runtime/checkpoint-store"
    assert envelope.operation_count == 8
    assert envelope.operation_kinds == (
        "append-fact",
        "write-checkpoint",
        "rebuild-index",
        "claim-job-lease",
        "append-repair-event",
        "retain-artifact",
        "append-communication-event",
        "attach-sandbox-handle",
    )
    assert envelope.operations_argv == (
        "marlin-runtime-store",
        "durable-runtime-store",
        "operations",
    )
    assert envelope.receipt == SCHEME_DURABLE_RUNTIME_ENVELOPE


def test_parses_scheme_generated_durable_runtime_envelope_payload() -> None:
    generated = scheme_durable_runtime_envelope_bytes()
    envelope = coerce_runtime_durable_envelope_manifest(generated)

    assert envelope.policy_id == "durable/python-runtime-envelope"
    assert envelope.store_id == "runtime-store/default"
    assert envelope.backend_executable == "marlin-runtime-store"
    assert envelope.operation_count == len(envelope.operation_kinds)
    assert envelope.receipt == generated


def test_builds_turso_adapter_from_scheme_generated_runtime_envelope() -> None:
    generated = scheme_durable_runtime_envelope_bytes()
    adapter = RuntimeDurableAdapter.turso_from_envelope(envelope=generated)

    assert adapter.policy.policy_id == "durable/python-runtime-envelope"
    assert adapter.policy.checkpoint_store == "runtime/checkpoint-store"
    assert adapter.policy.action_classes == (
        "replayable",
        "idempotent",
        "compensatable",
        "terminal",
        "manual",
    )
    assert adapter.policy.receipt == generated


def test_rejects_mismatched_operation_count() -> None:
    with pytest.raises(RuntimeDurablePolicyError, match="operation_count"):
        coerce_runtime_durable_envelope_manifest(
            SCHEME_DURABLE_RUNTIME_ENVELOPE.replace(
                b"operation-count=8", b"operation-count=7"
            )
        )


def test_rejects_invalid_store_receipt_in_envelope() -> None:
    with pytest.raises(RuntimeDurablePolicyError, match="invalid receipts"):
        coerce_runtime_durable_envelope_manifest(
            SCHEME_DURABLE_RUNTIME_ENVELOPE.replace(
                b"store-valid=true", b"store-valid=false"
            )
        )
