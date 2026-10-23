# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import pytest

from agentic_ai_lab_runtime.builder import RuntimeGraphBuilder
from agentic_ai_lab_runtime.durable_adapter import RuntimeDurableAdapter
from agentic_ai_lab_runtime.runtime_graph import RuntimeGraphInterrupt, RuntimeGraphInterrupted


def _interrupting_program():
    def pause(_state):
        return RuntimeGraphInterrupt({"question": "approve"})

    def done(state):
        return {"done": True, "approved": state.get("approved")}

    builder = RuntimeGraphBuilder()
    builder.add_node("pause", pause)
    builder.add_node("done", done)
    builder.add_edge("pause", "done")
    builder.set_entry_point("pause")
    builder.set_finish_point("done")
    return builder.compile_reference_program()


def test_durable_adapter_exposes_checkpoint_time_travel(tmp_path):
    adapter = RuntimeDurableAdapter.turso(tmp_path / "runtime.db")
    program = _interrupting_program()

    with pytest.raises(RuntimeGraphInterrupted):
        adapter.invoke_thread(program, "thread-1", {"value": 1}, trace_key="trace")

    assert adapter.has("thread-1") is True
    checkpoint = adapter.inspect("thread-1")
    history = adapter.history("thread-1")
    assert len(history) == 1
    assert history[0].checkpoint_id == checkpoint.checkpoint_id

    loaded = adapter.load_at("thread-1", checkpoint.checkpoint_id)
    assert loaded.node == "pause"
    assert loaded.state["trace"] == ["pause"]

    updated = adapter.update_state("thread-1", {"manual": "patched"})
    assert updated.state["manual"] == "patched"

    result = adapter.resume_thread(
        program,
        "thread-1",
        {"approved": True},
        trace_key="trace",
    )
    assert result.state["done"] is True
    assert result.state["approved"] is True
    assert result.state["manual"] == "patched"
    assert adapter.has("thread-1") is False


async def _run_async_durable_adapter_time_travel(database):
    adapter = RuntimeDurableAdapter.turso(database)
    program = _interrupting_program()

    with pytest.raises(RuntimeGraphInterrupted):
        await adapter.ainvoke_thread(
            program,
            "thread-async",
            {"value": 1},
            trace_key="trace",
        )

    assert await adapter.ahas("thread-async") is True
    checkpoint = await adapter.ainspect("thread-async")
    history = await adapter.ahistory("thread-async")
    assert history[0].checkpoint_id == checkpoint.checkpoint_id

    loaded = await adapter.aload_at("thread-async", checkpoint.checkpoint_id)
    assert loaded.state["trace"] == ["pause"]

    updated = await adapter.aupdate_state("thread-async", {"async": True})
    assert updated.state["async"] is True

    await adapter.aclear("thread-async")
    assert await adapter.ahas("thread-async") is False


def test_durable_adapter_exposes_async_checkpoint_facade(tmp_path):
    import anyio

    anyio.run(_run_async_durable_adapter_time_travel, tmp_path / "runtime-async.db")
