# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from agentic_ai_lab_runtime import (
    END,
    START,
    RuntimeGraphBindings,
    RuntimeGraphEdge,
    RuntimeGraphPlan,
    RuntimeGraphProgram,
    RuntimeGraphRegistries,
)


def test_runtime_graph_program_invokes_action_and_reducer_registries() -> None:
    plan = RuntimeGraphPlan(
        nodes=("first", "second"),
        edges=(
            RuntimeGraphEdge(START, "first"),
            RuntimeGraphEdge("first", "second"),
            RuntimeGraphEdge("second", END),
        ),
    )
    bindings = RuntimeGraphBindings(
        node_actions={"first": "set-first", "second": "append-second"},
        state_reducers={"items": "append-items"},
    )
    registries = RuntimeGraphRegistries(
        actions={
            "set-first": lambda state: {"items": ["first"]},
            "append-second": lambda state: {"items": ["second"]},
        },
        reducers={"append-items": lambda left, right: [*(left or []), *right]},
    )
    program = RuntimeGraphProgram.reference(
        plan=plan, graph_bindings=bindings, registries=registries
    )

    assert program.invoke({"items": []}) == {"items": ["first", "second"]}


def test_runtime_graph_program_returns_execution_trace() -> None:
    plan = RuntimeGraphPlan(
        nodes=("first", "second"),
        edges=(
            RuntimeGraphEdge(START, "first"),
            RuntimeGraphEdge("first", "second"),
            RuntimeGraphEdge("second", END),
        ),
    )
    registries = RuntimeGraphRegistries(
        actions={
            "first": lambda state: {"x": 1},
            "second": lambda state: {"y": state["x"] + 1},
        }
    )
    program = RuntimeGraphProgram.reference(plan=plan, registries=registries)

    execution = program.invoke_with_trace({})

    assert execution.state == {"x": 1, "y": 2}
    assert execution.trace == ("first", "second")
