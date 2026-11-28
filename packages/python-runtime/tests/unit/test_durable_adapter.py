# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import anyio
import pytest

from agentic_ai_lab_runtime.durable_adapter import RuntimeDurableAdapter
from agentic_ai_lab_runtime.program import RuntimeGraphProgram, RuntimeGraphRegistries
from agentic_ai_lab_runtime.runtime_graph import (
    END,
    START,
    RuntimeGraphEdge,
    RuntimeGraphInterrupt,
    RuntimeGraphInterrupted,
    RuntimeGraphPlan,
)


def test_turso_durable_adapter_consumes_scheme_manifest(tmp_path) -> None:
    adapter = RuntimeDurableAdapter.turso(
        tmp_path / "adapter.db",
        policy=(
            b"policy-id=agentic-ai-lab-durable-policy.v1\n"
            b"owner=scheme\n"
            b"checkpoint-id-strategy=runtime-generated\n"
            b"require-plan-digest-match=true\n"
            b"history-retention-limit=2\n"
            b"backend-driver=turso\n"
            b"backend-concurrent-writes=true\n"
            b"backend-ai-vector-search=true\n"
        ),
    )

    adapter.store.put(("agent",), "state", {"value": 1})
    receipt = adapter.receipt()

    assert adapter.store.get(("agent",), "state").value == {"value": 1}
    assert b"agentic-ai-lab-durable-adapter.v1" in receipt
    assert b"owner=scheme" in receipt
    assert b"backend=turso" in receipt
    assert b"driver=turso" in receipt
    assert b"driver-package=pyturso" in receipt
    assert b"connection-module=turso" in receipt
    assert b"concurrent-writes=true" in receipt
    assert b"sync-model=local-first-push-pull" in receipt
    assert b"ai-vector-search=true" in receipt
    assert b"vector-index=libsql_vector_idx" in receipt
    assert b"vector-query=vector_top_k" in receipt
    assert b"driver-version=unknown" not in receipt


def test_turso_durable_adapter_rejects_mismatched_backend_requirement(tmp_path) -> None:
    with pytest.raises(RuntimeError, match="requires driver"):
        RuntimeDurableAdapter.turso(
            tmp_path / "adapter.db",
            policy={
                "backend": {
                    "driver": "libsql",
                    "concurrent-writes": True,
                }
            },
        )


def test_turso_durable_adapter_runs_async_thread_workflow(tmp_path) -> None:
    async def load(state):
        await anyio.sleep(0)
        return {"value": 42}

    async def approve(state):
        await anyio.sleep(0)
        return RuntimeGraphInterrupt("approve")

    async def done(state):
        await anyio.sleep(0)
        return {"done": state["approved"]}

    program = RuntimeGraphProgram.reference(
        plan=RuntimeGraphPlan(
            nodes=("load", "approve", "done"),
            edges=(
                RuntimeGraphEdge(START, "load"),
                RuntimeGraphEdge("load", "approve"),
                RuntimeGraphEdge("approve", "done"),
                RuntimeGraphEdge("done", END),
            ),
        ),
        registries=RuntimeGraphRegistries(
            actions={"load": load, "approve": approve, "done": done}
        ),
    )
    adapter = RuntimeDurableAdapter.turso(tmp_path / "thread.db")

    async def scenario() -> None:
        with pytest.raises(RuntimeGraphInterrupted):
            await program.ainvoke_thread("thread-1", {}, adapter.checkpointer)
        execution = await program.aresume_thread(
            "thread-1", {"approved": True}, adapter.checkpointer
        )
        assert execution.state["done"] is True

    anyio.run(scenario)
