# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import asyncio

import pytest

from agentic_ai_lab_runtime._runtime_graph_context import GraphRunContext
from agentic_ai_lab_runtime import (
    MemoryRuntimeGraphCheckpointer,
    MemoryRuntimeGraphStore,
    RuntimeGraphBuilder,
    RuntimeGraphError,
    RuntimeGraphRuntime,
    RuntimeRouteResult,
    RuntimeGraphSend,
)


def test_builder_compile_accepts_runtime_options() -> None:
    store = MemoryRuntimeGraphStore()
    checkpointer = MemoryRuntimeGraphCheckpointer()

    def read_runtime(state, runtime):
        return {
            "thread_id": runtime.require_thread_id(),
            "store": runtime.require_store() is store,
            "checkpointer": runtime.require_checkpointer() is checkpointer,
            "label": runtime.metadata["label"],
        }

    graph = (
        RuntimeGraphBuilder()
        .add_node("read", read_runtime)
        .set_entry_point("read")
        .set_finish_point("read")
        .compile(
            thread_id="thread-1",
            store=store,
            checkpointer=checkpointer,
            metadata={"label": "runtime-options"},
        )
    )

    assert graph.invoke({}) == {
        "thread_id": "thread-1",
        "store": True,
        "checkpointer": True,
        "label": "runtime-options",
    }


def test_runtime_route_result_is_public_typing_surface() -> None:
    assert RuntimeRouteResult is not None


def test_builder_compile_program_accepts_runtime_options() -> None:
    graph = (
        RuntimeGraphBuilder()
        .add_node("read", lambda state, runtime: {"thread_id": runtime.require_thread_id()})
        .set_entry_point("read")
        .set_finish_point("read")
        .compile_program(runtime=RuntimeGraphRuntime.reference(thread_id="program-thread"))
    )

    assert graph.invoke({}) == {"thread_id": "program-thread"}


def test_program_invoke_thread_saves_successful_checkpoint() -> None:
    checkpointer = MemoryRuntimeGraphCheckpointer()
    graph = (
        RuntimeGraphBuilder()
        .add_node("step", lambda state: {"value": state.get("value", 0) + 1})
        .set_entry_point("step")
        .set_finish_point("step")
        .compile_reference_program()
    )

    execution = graph.invoke_thread("thread-1", {}, checkpointer)
    checkpoint = checkpointer.inspect("thread-1")

    assert execution.state == {"value": 1}
    assert checkpoint.interrupt is None
    assert checkpoint.state == {"value": 1}
    assert checkpointer.history("thread-1") == (checkpoint,)


def test_program_state_facade_matches_langgraph_state_access() -> None:
    checkpointer = MemoryRuntimeGraphCheckpointer()
    graph = (
        RuntimeGraphBuilder()
        .add_node("step", lambda state: {"value": state.get("value", 0) + 1})
        .set_entry_point("step")
        .set_finish_point("step")
        .compile_reference_program()
    )

    graph.invoke_thread("thread-1", {}, checkpointer)
    checkpoint = graph.get_state("thread-1", checkpointer)
    same_checkpoint = graph.get_state_at(
        "thread-1",
        checkpoint.checkpoint_id,
        checkpointer,
    )
    updated = graph.update_state("thread-1", {"value": 10}, checkpointer)

    assert checkpoint.state == {"value": 1}
    assert same_checkpoint == checkpoint
    assert updated.state == {"value": 10}
    assert graph.get_state("thread-1", checkpointer) == updated
    assert graph.get_state_history("thread-1", checkpointer) == (checkpoint, updated)


def test_program_async_state_facade_uses_same_checkpoint_surface() -> None:
    async def run() -> None:
        checkpointer = MemoryRuntimeGraphCheckpointer()
        graph = (
            RuntimeGraphBuilder()
            .add_node("step", lambda state: {"value": state.get("value", 0) + 1})
            .set_entry_point("step")
            .set_finish_point("step")
            .compile_reference_program()
        )

        await graph.ainvoke_thread("thread-1", {}, checkpointer)
        checkpoint = await graph.aget_state("thread-1", checkpointer)
        updated = await graph.aupdate_state(
            "thread-1",
            {"value": 12},
            checkpointer,
        )
        history = await graph.aget_state_history("thread-1", checkpointer)
        same_checkpoint = await graph.aget_state_at(
            "thread-1",
            checkpoint.checkpoint_id,
            checkpointer,
        )

        assert same_checkpoint == checkpoint
        assert updated.state == {"value": 12}
        assert history == (checkpoint, updated)

    asyncio.run(run())


def test_builder_add_sequence_adds_nodes_and_edges() -> None:
    graph = (
        RuntimeGraphBuilder()
        .add_sequence(
            (
                ("first", lambda state: {"value": 1}),
                ("second", lambda state: {"value": state["value"] + 1}),
                ("third", lambda state: {"value": state["value"] + 1}),
            )
        )
        .set_entry_point("first")
        .set_finish_point("third")
        .compile()
    )

    assert graph.invoke({}) == {"value": 3}


def test_builder_add_sequence_rejects_empty_sequence() -> None:
    with pytest.raises(RuntimeGraphError, match="sequence cannot be empty"):
        RuntimeGraphBuilder().add_sequence(())


def test_conditional_router_can_return_direct_send_fanout() -> None:
    graph = RuntimeGraphBuilder()
    graph.add_node("fanout", lambda state: {})
    graph.add_node("worker", lambda state: {"results": [state["item"]]})
    graph.add_reducer("results", lambda left, right: left + right)
    graph.set_entry_point("fanout")
    graph.add_conditional_edges(
        "fanout",
        lambda state: [
            RuntimeGraphSend("worker", {"item": item}) for item in state["items"]
        ],
    )
    graph.set_finish_point("worker")

    assert graph.compile().invoke({"items": ["a", "b"], "results": []}) == {
        "items": ["a", "b"],
        "results": ["a", "b"],
    }


def test_public_executor_async_action_state_is_isolated() -> None:
    retained: list[dict] = []
    caller_state = {"value": 1}

    async def mutate(state: dict) -> dict:
        retained.append(state)
        state["value"] += 1
        return state

    executor = (
        RuntimeGraphBuilder()
        .add_node("mutate", mutate)
        .set_entry_point("mutate")
        .set_finish_point("mutate")
        .compile()
    )

    async def run() -> None:
        state, _trace, events = await executor.ainvoke_with_events(
            caller_state, trace_key="trace"
        )
        assert caller_state == {"value": 1}
        assert state == {"value": 2, "trace": ["mutate"]}
        retained[0]["late"] = True
        assert "late" not in state
        assert "late" not in events[-1].detail["state"]

    asyncio.run(run())


def test_program_async_transfers_owned_state_and_matches_public_executor(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def route(state: dict) -> list[RuntimeGraphSend]:
        await asyncio.sleep(0)
        return [RuntimeGraphSend("worker", {"item": item}) for item in state["items"]]

    graph = RuntimeGraphBuilder()
    graph.add_node("fanout", lambda state: {"started": True})
    graph.add_node("worker", lambda state: {"results": [state["item"]]})
    graph.add_reducer("results", lambda left, right: left + right)
    graph.set_entry_point("fanout")
    graph.add_conditional_edges("fanout", route)
    graph.set_finish_point("worker")
    program = graph.compile_reference_program()
    initial_state = {"items": ["a", "b"], "results": []}
    created: list[dict] = []
    transferred: list[tuple[dict, dict]] = []
    make_internal_state = program._internal_state
    make_owned_context = GraphRunContext.from_owned.__func__

    def capture_internal_state(state: dict) -> dict:
        internal_state = make_internal_state(state)
        created.append(internal_state)
        return internal_state

    def capture_owned_context(
        cls: type[GraphRunContext], executor: object, state: dict
    ) -> GraphRunContext:
        context = make_owned_context(cls, executor, state)
        transferred.append((state, context.state))
        return context

    monkeypatch.setattr(program, "_internal_state", capture_internal_state)
    monkeypatch.setattr(
        GraphRunContext, "from_owned", classmethod(capture_owned_context)
    )

    async def run() -> None:
        state, trace, events = await program._executor().ainvoke_with_events(
            make_internal_state(initial_state)
        )
        execution = await program.ainvoke_with_trace(initial_state)
        assert execution.state == program._public_state(state)
        assert execution.trace == tuple(trace)
        assert execution.events == tuple(events)

    asyncio.run(run())
    assert created[0] is transferred[0][0] is transferred[0][1]


def test_conditional_router_can_return_direct_target_list() -> None:
    graph = RuntimeGraphBuilder()
    graph.add_node("route", lambda state: {})
    graph.add_node("left", lambda state: {"seen": ["left"]})
    graph.add_node("right", lambda state: {"seen": ["right"]})
    graph.add_reducer("seen", lambda left, right: left + right)
    graph.set_entry_point("route")
    graph.add_conditional_edges("route", lambda state: ["left", "right"])
    graph.add_edge("left", "__end__")
    graph.add_edge("right", "__end__")

    assert graph.compile().invoke({"seen": []}) == {"seen": ["left", "right"]}


def test_conditional_direct_route_validates_target() -> None:
    graph = (
        RuntimeGraphBuilder()
        .add_node("route", lambda state: {})
        .set_entry_point("route")
        .add_conditional_edges("route", lambda state: "missing")
    )

    with pytest.raises(RuntimeGraphError, match="unknown runtime graph endpoint"):
        graph.compile().invoke({})
