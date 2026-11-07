# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from agentic_ai_lab_runtime import (
    END,
    START,
    RuntimeGraphEdge,
    RuntimeGraphExecutor,
    RuntimeGraphPlan,
    RuntimeGraphProgram,
    RuntimeGraphRegistries,
    RuntimeGraphSubgraph,
)


def _math_subgraph() -> RuntimeGraphSubgraph:
    return RuntimeGraphSubgraph.from_parts(
        RuntimeGraphPlan(
            nodes=("increment", "double"),
            edges=(
                RuntimeGraphEdge(START, "increment"),
                RuntimeGraphEdge("increment", "double"),
                RuntimeGraphEdge("double", END),
            ),
        ),
        {
            "increment": lambda state: {"value": state["seed"] + 1},
            "double": lambda state: {"value": state["value"] * 2},
        },
        input_keys=("seed",),
        output_keys=("value",),
        trace_output_key="child-trace",
    )


def test_runtime_graph_subgraph_runs_as_parent_action() -> None:
    subgraph = _math_subgraph()
    executor = RuntimeGraphExecutor(
        RuntimeGraphPlan(
            nodes=("child", "finish"),
            edges=(
                RuntimeGraphEdge(START, "child"),
                RuntimeGraphEdge("child", "finish"),
                RuntimeGraphEdge("finish", END),
            ),
        ),
        {
            "child": subgraph.as_action(),
            "finish": lambda state: {"status": f"value={state['value']}"},
        },
    )

    state, trace = executor.invoke_with_trace({"seed": 20})

    assert state["value"] == 42
    assert state["status"] == "value=42"
    assert state["child-trace"] == ["increment", "double"]
    assert trace == ["child", "finish"]


def test_runtime_graph_program_can_use_subgraph_action() -> None:
    subgraph = _math_subgraph()
    program = RuntimeGraphProgram.reference(
        plan=RuntimeGraphPlan(
            nodes=("child", "finish"),
            edges=(
                RuntimeGraphEdge(START, "child"),
                RuntimeGraphEdge("child", "finish"),
                RuntimeGraphEdge("finish", END),
            ),
        ),
        registries=RuntimeGraphRegistries(
            actions={
                "child": subgraph.as_action(),
                "finish": lambda state: {"status": f"value={state['value']}"},
            }
        ),
    )

    execution = program.invoke_with_trace({"seed": 20}, trace_key="parent-trace")

    assert execution.state["value"] == 42
    assert execution.state["status"] == "value=42"
    assert execution.state["child-trace"] == ["increment", "double"]
    assert execution.state["parent-trace"] == ["child", "finish"]
    assert execution.plan_digest is not None
