# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from agentic_ai_lab_runtime import RuntimeGraphBuilder, RuntimeGraphCommand
from agentic_ai_lab_runtime.checkpoints import (
    MemoryRuntimeGraphCheckpointer,
    RuntimeGraphCheckpointError,
)
from agentic_ai_lab_runtime.messages import ai_message
from agentic_ai_lab_runtime.runtime import RuntimeGraphRuntime
from agentic_ai_lab_runtime.runtime_graph import (
    END,
    START,
    RuntimeGraphEdge,
    RuntimeGraphEvent,
    RuntimeGraphExecutor,
    RuntimeGraphPlan,
)


def test_command_goto_skips_default_edges_in_invoke_path():
    plan = RuntimeGraphPlan(
        nodes=("decide", "fallback"),
        edges=(
            RuntimeGraphEdge(START, "decide"),
            RuntimeGraphEdge("decide", "fallback"),
            RuntimeGraphEdge("fallback", END),
        ),
    )
    executor = RuntimeGraphExecutor(
        plan,
        {
            "decide": lambda state: RuntimeGraphCommand({"route": "done"}, goto=END),
            "fallback": lambda state: {"fallback": True},
        },
    )

    state, trace = executor.invoke_with_trace({})

    assert state == {"route": "done"}
    assert trace == ["decide"]


def test_executor_stream_modes_emit_updates_values_and_events():
    builder = RuntimeGraphBuilder()
    builder.add_node("first", lambda state: {"x": 1})
    builder.add_node("second", lambda state: {"y": state["x"] + 1})
    builder.set_entry_point("first")
    builder.add_edge("first", "second")
    builder.set_finish_point("second")

    chunks = list(
        builder.compile().stream({}, stream_mode=("updates", "values", "events"))
    )

    assert ("updates", {"first": {"x": 1}}) in chunks
    assert ("values", {"x": 1, "y": 2}) in chunks
    assert any(
        mode == "events"
        and isinstance(event, RuntimeGraphEvent)
        and event.kind == "complete"
        for mode, event in chunks
    )


def test_executor_stream_updates_accept_empty_action_result():
    builder = RuntimeGraphBuilder()
    builder.add_node("noop", lambda state: None)
    builder.set_entry_point("noop")
    builder.set_finish_point("noop")

    assert list(builder.compile().stream({}, stream_mode="updates")) == [
        {"noop": {}}
    ]


def test_executor_stream_messages_project_message_updates():
    builder = RuntimeGraphBuilder()
    message = ai_message("ready", id="m1")
    builder.add_node("model", lambda state: {"messages": [message]})
    builder.set_entry_point("model")
    builder.set_finish_point("model")

    assert list(builder.compile().stream({}, stream_mode="messages")) == [
        (message, {"node": "model", "step": 1})
    ]


def test_executor_stream_custom_projects_runtime_writer_chunks():
    runtime = RuntimeGraphRuntime.reference()

    def action(state, runtime):
        runtime.emit_custom({"phase": "thinking"})
        return {"answer": 42}

    builder = RuntimeGraphBuilder()
    builder.add_node("model", action)
    builder.set_entry_point("model")
    builder.set_finish_point("model")

    chunks = list(
        builder.compile(runtime=runtime).stream(
            {}, stream_mode=("custom", "updates")
        )
    )

    assert ("custom", {"phase": "thinking"}) in chunks
    assert ("updates", {"model": {"answer": 42}}) in chunks


def test_executor_stream_tasks_project_node_lifecycle():
    builder = RuntimeGraphBuilder()
    builder.add_node("first", lambda state: {"x": 1})
    builder.add_node("second", lambda state: {"y": state["x"] + 1})
    builder.set_entry_point("first")
    builder.add_edge("first", "second")
    builder.set_finish_point("second")

    assert list(builder.compile().stream({}, stream_mode="tasks")) == [
        {"node": "first", "step": 1, "status": "start"},
        {"node": "first", "step": 1, "status": "finish"},
        {"node": "second", "step": 2, "status": "start"},
        {"node": "second", "step": 2, "status": "finish"},
    ]


def test_executor_stream_checkpoints_persists_step_checkpoints():
    checkpointer = MemoryRuntimeGraphCheckpointer()
    runtime = RuntimeGraphRuntime.reference(thread_id="thread-1", checkpointer=checkpointer)
    builder = RuntimeGraphBuilder()
    builder.add_node("first", lambda state: {"x": 1})
    builder.add_node("second", lambda state: {"y": state["x"] + 1})
    builder.set_entry_point("first")
    builder.add_edge("first", "second")
    builder.set_finish_point("second")

    checkpoints = list(
        builder.compile(runtime=runtime).stream({}, stream_mode="checkpoints")
    )

    assert [checkpoint.node for checkpoint in checkpoints] == ["first", "second"]
    assert [checkpoint.state for checkpoint in checkpoints] == [
        {"x": 1},
        {"x": 1, "y": 2},
    ]
    assert [checkpoint.node for checkpoint in checkpointer.history("thread-1")] == [
        "first",
        "second",
    ]
    try:
        checkpoints[-1].to_interrupted()
    except RuntimeGraphCheckpointError:
        pass
    else:
        raise AssertionError("step checkpoint must not resume as an interrupt")


def test_program_stream_hides_internal_runtime_plan_state():
    builder = RuntimeGraphBuilder()
    builder.add_node("first", lambda state: {"x": 1})
    builder.add_node("second", lambda state: {"y": state["x"] + 1})
    builder.set_entry_point("first")
    builder.add_edge("first", "second")
    builder.set_finish_point("second")

    chunks = list(
        builder.compile_reference_program().stream({}, stream_mode=("values", "events"))
    )

    for mode, chunk in chunks:
        if mode == "values":
            assert "_agentic_ai_lab_runtime_graph_plan" not in chunk
        if mode == "events" and chunk.kind == "complete":
            assert "_agentic_ai_lab_runtime_graph_plan" not in chunk.detail["state"]

def test_program_stream_checkpoints_hide_internal_runtime_plan_state():
    checkpointer = MemoryRuntimeGraphCheckpointer()
    runtime = RuntimeGraphRuntime.reference(thread_id="thread-1", checkpointer=checkpointer)
    builder = RuntimeGraphBuilder()
    builder.add_node("first", lambda state: {"x": 1})
    builder.set_entry_point("first")
    builder.set_finish_point("first")

    checkpoints = list(
        builder.compile_program(runtime=runtime).stream(
            {}, stream_mode="checkpoints"
        )
    )

    assert len(checkpoints) == 1
    assert "_agentic_ai_lab_runtime_graph_plan" not in checkpoints[0].state
