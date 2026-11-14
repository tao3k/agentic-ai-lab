# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import pytest

from agentic_ai_lab_runtime import (
    END,
    START,
    RuntimeGraphBindings,
    RuntimeGraphEdge,
    RuntimeGraphEvent,
    RuntimeGraphInterrupt,
    RuntimeGraphInterrupted,
    RuntimeGraphPlan,
    RuntimeGraphProgram,
    RuntimeGraphRegistries,
)


def test_runtime_graph_program_execution_carries_events() -> None:
    plan = RuntimeGraphPlan(
        nodes=("load",),
        edges=(
            RuntimeGraphEdge(START, "load"),
            RuntimeGraphEdge("load", END),
        ),
    )
    program = RuntimeGraphProgram.reference(
        plan=plan,
        graph_bindings=RuntimeGraphBindings(node_actions={"load": "poo.load"}),
        registries=RuntimeGraphRegistries(
            actions={"poo.load": lambda state: {"value": 42}}
        ),
    )

    execution = program.invoke_with_trace({}, trace_key="trace")

    assert execution.state["value"] == 42
    assert execution.trace == ("load",)
    assert execution.state["trace"] == ["load"]
    assert all(isinstance(event, RuntimeGraphEvent) for event in execution.events)
    assert [event.kind for event in execution.events] == [
        "start",
        "node-start",
        "node-end",
        "complete",
    ]
    assert execution.events[-1].detail["trace"] == ("load",)


def test_runtime_graph_program_interrupt_does_not_leak_internal_handle() -> None:
    plan = RuntimeGraphPlan(
        nodes=("load", "pause"),
        edges=(
            RuntimeGraphEdge(START, "load"),
            RuntimeGraphEdge("load", "pause"),
            RuntimeGraphEdge("pause", END),
        ),
    )
    program = RuntimeGraphProgram.reference(
        plan=plan,
        graph_bindings=RuntimeGraphBindings(
            node_actions={
                "load": "poo.load",
                "pause": "poo.pause",
            }
        ),
        registries=RuntimeGraphRegistries(
            actions={
                "poo.load": lambda state: {"value": 42},
                "poo.pause": lambda state: RuntimeGraphInterrupt(
                    {"question": "approve?", "value": state["value"]}
                ),
            }
        ),
    )

    with pytest.raises(RuntimeGraphInterrupted) as raised:
        program.invoke_with_trace({}, trace_key="trace")

    interrupted = raised.value
    assert interrupted.node == "pause"
    assert interrupted.state["value"] == 42
    assert interrupted.state["trace"] == ["load", "pause"]
    assert "_agentic_ai_lab_runtime_graph_plan" not in interrupted.state
    assert interrupted.trace == ("load", "pause")
    assert interrupted.events[-1].kind == "interrupt"


def test_runtime_graph_program_resumes_from_interrupt() -> None:
    plan = RuntimeGraphPlan(
        nodes=("load", "approve", "done"),
        edges=(
            RuntimeGraphEdge(START, "load"),
            RuntimeGraphEdge("load", "approve"),
            RuntimeGraphEdge("approve", "done"),
            RuntimeGraphEdge("done", END),
        ),
    )
    program = RuntimeGraphProgram.reference(
        plan=plan,
        graph_bindings=RuntimeGraphBindings(
            node_actions={
                "load": "poo.load",
                "approve": "poo.approve",
                "done": "poo.done",
            }
        ),
        registries=RuntimeGraphRegistries(
            actions={
                "poo.load": lambda state: {"value": 42},
                "poo.approve": lambda state: RuntimeGraphInterrupt(
                    {"question": "approve?", "value": state["value"]}
                ),
                "poo.done": lambda state: {
                    "status": "approved" if state["approved"] else "rejected"
                },
            }
        ),
    )

    with pytest.raises(RuntimeGraphInterrupted) as raised:
        program.invoke_with_trace({}, trace_key="trace")

    execution = program.resume_interrupted(
        raised.value,
        {"approved": True},
        trace_key="trace",
    )

    assert execution.state["status"] == "approved"
    assert execution.state["trace"] == ["load", "approve", "done"]
    assert "_agentic_ai_lab_runtime_graph_plan" not in execution.state
    assert execution.trace == ("load", "approve", "done")
    assert execution.plan_digest is not None
    assert any(event.kind == "resume" for event in execution.events)
