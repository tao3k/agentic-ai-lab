# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import pytest
import anyio

from agentic_ai_lab_runtime.checkpoints import RuntimeGraphCheckpoint
from agentic_ai_lab_runtime import (
    TursoRuntimeGraphBackend,
    turso_runtime_graph_backend,
)
from agentic_ai_lab_runtime.durable import (
    TursoRuntimeGraphCheckpointer,
    TursoRuntimeGraphStore,
)
from agentic_ai_lab_runtime.program import RuntimeGraphProgram, RuntimeGraphRegistries
from agentic_ai_lab_runtime.runtime_graph import (
    END,
    START,
    RuntimeGraphEdge,
    RuntimeGraphInterrupt,
    RuntimeGraphInterrupted,
    RuntimeGraphPlan,
)


def test_turso_runtime_graph_backend_uses_pyturso_driver(tmp_path) -> None:
    backend = turso_runtime_graph_backend(tmp_path / "backend.db")

    assert isinstance(backend, TursoRuntimeGraphBackend)
    assert backend.driver == "turso"
    assert backend.driver_package == "pyturso"
    assert backend.driver_version != "unknown"
    assert backend.connection_module == "turso"
    assert backend.database.endswith("backend.db")
    assert backend.concurrent_writes is True
    assert backend.sync_model == "local-first-push-pull"
    assert backend.ai_vector_search is True
    assert backend.vector_index == "libsql_vector_idx"
    assert backend.vector_query == "vector_top_k"


def test_turso_runtime_graph_store_round_trips_values(tmp_path) -> None:
    store = TursoRuntimeGraphStore(tmp_path / "store.db")

    item = store.put(("tenant", "agent"), "state", {"value": 1})

    assert store.backend.driver_package == "pyturso"
    assert item.value == {"value": 1}
    assert store.get(("tenant", "agent"), "state").value == {"value": 1}
    assert store.list(("tenant", "agent"))[0].key == "state"
    assert store.search(("tenant",))[0].namespace == ("tenant", "agent")
    store.delete(("tenant", "agent"), "state")
    assert store.get(("tenant", "agent"), "state") is None


def test_turso_runtime_graph_store_async_facade(tmp_path) -> None:
    store = TursoRuntimeGraphStore(tmp_path / "async-store.db")

    async def scenario() -> None:
        await store.aput(("tenant", "agent"), "state", {"value": 1})
        assert (await store.aget(("tenant", "agent"), "state")).value == {"value": 1}
        assert (await store.alist(("tenant", "agent")))[0].key == "state"
        assert (await store.asearch(("tenant",)))[0].namespace == ("tenant", "agent")
        await store.adelete(("tenant", "agent"), "state")
        assert await store.aget(("tenant", "agent"), "state") is None

    anyio.run(scenario)


def test_turso_checkpointer_resumes_runtime_graph_thread(tmp_path) -> None:
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
            actions={
                "load": lambda state: {"value": 42},
                "approve": lambda state: RuntimeGraphInterrupt("approve"),
                "done": lambda state: {"done": state["approved"]},
            }
        ),
    )
    checkpointer = TursoRuntimeGraphCheckpointer(tmp_path / "checkpoints.db")
    assert checkpointer.backend.driver == "turso"

    with pytest.raises(RuntimeGraphInterrupted):
        program.invoke_thread("thread-1", {}, checkpointer)

    assert checkpointer.has("thread-1")
    assert len(checkpointer.history("thread-1")) == 1

    execution = program.resume_thread(
        "thread-1", {"approved": True}, checkpointer
    )

    assert execution.state["done"] is True
    assert checkpointer.has("thread-1") is False


def test_turso_checkpointer_async_facade(tmp_path) -> None:
    checkpointer = TursoRuntimeGraphCheckpointer(tmp_path / "async-checkpoints.db")
    checkpoint = checkpointer.save(
        RuntimeGraphCheckpoint(
            checkpoint_id="",
            thread_id="thread-1",
            interrupt=None,
            node="load",
            step=1,
            state={"value": 1},
            trace=("load",),
        )
    )

    async def scenario() -> None:
        assert await checkpointer.ahas("thread-1")
        assert (await checkpointer.aload("thread-1")).checkpoint_id == checkpoint.checkpoint_id
        updated = await checkpointer.aupdate_state("thread-1", {"extra": True})
        assert updated.state["extra"] is True
        assert len(await checkpointer.ahistory("thread-1")) >= 1
        await checkpointer.aclear("thread-1")
        assert await checkpointer.ahas("thread-1") is False

    anyio.run(scenario)


def test_turso_checkpointer_async_runtime_graph_thread(tmp_path) -> None:
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
    checkpointer = TursoRuntimeGraphCheckpointer(tmp_path / "async-thread.db")

    async def scenario() -> None:
        with pytest.raises(RuntimeGraphInterrupted):
            await program.ainvoke_thread("thread-1", {}, checkpointer)
        assert await checkpointer.ahas("thread-1")

        execution = await program.aresume_thread(
            "thread-1", {"approved": True}, checkpointer
        )

        assert execution.state["done"] is True
        assert await checkpointer.ahas("thread-1") is False

    anyio.run(scenario)
