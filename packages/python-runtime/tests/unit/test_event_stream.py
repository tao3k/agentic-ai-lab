# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from agentic_ai_lab_runtime import (
    RuntimeGraphBuilder,
    RuntimeGraphRuntime,
    RuntimeGraphStreamProjection,
)
from agentic_ai_lab_runtime.checkpoints import MemoryRuntimeGraphCheckpointer
from agentic_ai_lab_runtime.messages import ai_message


def test_executor_stream_projection_splits_typed_iterators():
    message = ai_message("ready", id="m1")
    runtime = RuntimeGraphRuntime.reference()

    def action(state, runtime):
        runtime.emit_custom({"phase": "model"})
        return {"messages": [message], "answer": 42}

    builder = RuntimeGraphBuilder()
    builder.add_node("model", action)
    builder.set_entry_point("model")
    builder.set_finish_point("model")

    projection = builder.compile(runtime=runtime).stream_projection(
        {}, stream_modes=("updates", "messages", "custom", "tasks")
    )

    assert isinstance(projection, RuntimeGraphStreamProjection)
    assert list(projection.updates()) == [
        {"model": {"messages": [message], "answer": 42}}
    ]
    assert list(projection.messages()) == [
        (message, {"node": "model", "step": 1})
    ]
    assert list(projection.custom()) == [{"phase": "model"}]
    assert list(projection.tasks()) == [
        {"node": "model", "step": 1, "status": "start"},
        {"node": "model", "step": 1, "status": "finish"},
    ]


def test_program_stream_projection_supports_checkpoint_projection():
    checkpointer = MemoryRuntimeGraphCheckpointer()
    runtime = RuntimeGraphRuntime.reference(thread_id="thread-1", checkpointer=checkpointer)
    builder = RuntimeGraphBuilder()
    builder.add_node("first", lambda state: {"x": 1})
    builder.set_entry_point("first")
    builder.set_finish_point("first")

    projection = builder.compile_program(runtime=runtime).stream_projection(
        {}, stream_modes=("values", "checkpoints")
    )

    assert list(projection.values()) == [{"x": 1}]
    checkpoints = list(projection.checkpoints())
    assert len(checkpoints) == 1
    assert checkpoints[0].state == {"x": 1}
