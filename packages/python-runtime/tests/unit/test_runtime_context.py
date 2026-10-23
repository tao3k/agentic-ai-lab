# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import pytest
import anyio
from types import SimpleNamespace

from agentic_ai_lab_runtime import (
    END,
    START,
    MemoryRuntimeGraphStore,
    RuntimeGraphEdge,
    RuntimeGraphError,
    RuntimeGraphExecutor,
    RuntimeGraphPlan,
    RuntimeGraphProgram,
    RuntimeGraphRegistries,
    RuntimeGraphRuntime,
    RuntimeGraphRuntimeError,
    linear_plan,
)


def test_runtime_graph_executor_injects_runtime_context() -> None:
    store = MemoryRuntimeGraphStore()
    runtime = RuntimeGraphRuntime.reference(thread_id="thread-1", store=store)
    executor = RuntimeGraphExecutor(
        RuntimeGraphPlan(
            nodes=("remember", "recall"),
            edges=(
                RuntimeGraphEdge(START, "remember"),
                RuntimeGraphEdge("remember", "recall"),
                RuntimeGraphEdge("recall", END),
            ),
        ),
        {
            "remember": lambda state, runtime: {
                "stored": runtime.require_store()
                .put(("threads", runtime.require_thread_id()), "value", state["value"])
                .key
            },
            "recall": lambda state, runtime: {
                "remembered": runtime.require_store()
                .get(("threads", runtime.require_thread_id()), "value")
                .value
            },
        },
        runtime=runtime,
    )

    state = executor.invoke({"value": 42})

    assert state["stored"] == "value"
    assert state["remembered"] == 42


def test_runtime_graph_program_injects_runtime_context() -> None:
    store = MemoryRuntimeGraphStore()
    runtime = RuntimeGraphRuntime.reference(thread_id="thread-1", store=store)
    program = RuntimeGraphProgram.reference(
        plan=RuntimeGraphPlan(
            nodes=("remember", "recall"),
            edges=(
                RuntimeGraphEdge(START, "remember"),
                RuntimeGraphEdge("remember", "recall"),
                RuntimeGraphEdge("recall", END),
            ),
        ),
        registries=RuntimeGraphRegistries(
            actions={
                "remember": lambda state, runtime: {
                    "stored": runtime.require_store()
                    .put(
                        ("threads", runtime.require_thread_id()),
                        "value",
                        state["value"],
                    )
                    .key
                },
                "recall": lambda state, runtime: {
                    "remembered": runtime.require_store()
                    .get(("threads", runtime.require_thread_id()), "value")
                    .value
                },
            }
        ),
        runtime=runtime,
    )

    execution = program.invoke_with_trace({"value": 42})

    assert execution.state["stored"] == "value"
    assert execution.state["remembered"] == 42
    assert execution.plan_digest is not None


def test_runtime_graph_runtime_requires_configured_resources() -> None:
    runtime = RuntimeGraphRuntime.reference()

    with pytest.raises(RuntimeGraphRuntimeError, match="thread_id"):
        runtime.require_thread_id()

    with pytest.raises(RuntimeGraphRuntimeError, match="store"):
        runtime.require_store()

    with pytest.raises(RuntimeGraphRuntimeError, match="checkpointer"):
        runtime.require_checkpointer()


def test_runtime_graph_runtime_native_backend_fails_closed_without_public_capability() -> None:
    runtime = RuntimeGraphRuntime()

    with pytest.raises(RuntimeGraphRuntimeError, match="negotiated native context"):
        runtime.require_native_context()


def test_runtime_graph_runtime_reference_backend_is_explicit() -> None:
    runtime = RuntimeGraphRuntime.reference()

    assert runtime.backend == "reference"
    with pytest.raises(RuntimeGraphRuntimeError, match="negotiated native context"):
        runtime.require_native_context()


@pytest.mark.parametrize("entrypoint", ["invoke", "stream", "resume"])
def test_native_graph_rejects_before_reference_action(entrypoint: str) -> None:
    calls = []
    program = RuntimeGraphProgram(
        plan=linear_plan("model"),
        runtime=RuntimeGraphRuntime.native(SimpleNamespace(closed=False)),
        registries=RuntimeGraphRegistries(
            actions={"model": lambda state: calls.append(state) or {"answer": 42}}
        ),
    )
    with pytest.raises(RuntimeGraphError, match="native graph execution is unavailable"):
        if entrypoint == "invoke":
            program.invoke({})
        elif entrypoint == "stream":
            list(program.stream({}))
        else:
            program.resume_interrupted(None)
    assert calls == []


@pytest.mark.parametrize("entrypoint", ["invoke", "stream", "batch", "resume"])
def test_async_native_graph_rejects_before_reference_action(entrypoint: str) -> None:
    calls = []
    program = RuntimeGraphProgram(
        plan=linear_plan("model"),
        runtime=RuntimeGraphRuntime.native(SimpleNamespace(closed=False)),
        registries=RuntimeGraphRegistries(
            actions={"model": lambda state: calls.append(state) or {"answer": 42}}
        ),
    )

    async def run() -> None:
        with pytest.raises(RuntimeGraphError, match="native graph execution is unavailable"):
            if entrypoint == "invoke":
                await program.ainvoke({})
            elif entrypoint == "stream":
                async for _ in program.astream({}):
                    pass
            elif entrypoint == "batch":
                await program.abatch([{}])
            else:
                await program.aresume_interrupted(None)

    anyio.run(run)
    assert calls == []
