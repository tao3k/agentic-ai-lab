# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from agentic_ai_lab_runtime import RuntimeGraphBuilder, RuntimeGraphSubgraph


def test_subgraph_stream_values_project_child_outputs():
    child = RuntimeGraphBuilder()
    child.add_node("child", lambda state: {"b": state["a"] + 1, "hidden": 9})
    child.set_entry_point("child")
    child.set_finish_point("child")
    subgraph = RuntimeGraphSubgraph(
        child.compile(),
        input_keys=("a",),
        output_keys=("b",),
        trace_key="trace",
        trace_output_key="child_trace",
    )

    assert list(subgraph.stream({"a": 1, "z": 0}, stream_mode="values")) == [
        {"b": 2, "child_trace": ["child"]}
    ]


def test_subgraph_stream_projection_exposes_debug_modes():
    child = RuntimeGraphBuilder()
    child.add_node("child", lambda state: {"b": state["a"] + 1})
    child.set_entry_point("child")
    child.set_finish_point("child")
    subgraph = RuntimeGraphSubgraph(
        child.compile(), input_keys=("a",), output_keys=("b",)
    )

    projection = subgraph.stream_projection(
        {"a": 1}, stream_modes=("values", "updates", "tasks")
    )

    assert list(projection.values()) == [{"b": 2}]
    assert list(projection.updates()) == [{"child": {"b": 2}}]
    assert list(projection.tasks()) == [
        {"node": "child", "step": 1, "status": "start"},
        {"node": "child", "step": 1, "status": "finish"},
    ]
