# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import pytest

from agentic_ai_lab_runtime import (
    END,
    START,
    RuntimeGraphConditionalEdge,
    RuntimeGraphCommand,
    RuntimeGraphSend,
    RuntimeGraphEdge,
    RuntimeGraphEvent,
    RuntimeGraphError,
    RuntimeGraphExecutor,
    RuntimeGraphInterrupt,
    RuntimeGraphInterrupted,
    RuntimeGraphPlan,
    linear_plan,
)


def test_runtime_graph_executes_linear_plan() -> None:
    executor = RuntimeGraphExecutor(
        linear_plan("load", "double"),
        {
            "load": lambda state: {"value": state["seed"] + 1},
            "double": lambda state: {"value": state["value"] * 2},
        },
    )

    assert executor.invoke({"seed": 20})["value"] == 42


def test_runtime_graph_can_return_execution_trace() -> None:
    executor = RuntimeGraphExecutor(
        linear_plan("load", "double"),
        {
            "load": lambda state: {"value": state["seed"] + 1},
            "double": lambda state: {"value": state["value"] * 2},
        },
    )

    state, trace = executor.invoke_with_trace({"seed": 20}, trace_key="trace")

    assert state["value"] == 42
    assert state["trace"] == ["load", "double"]
    assert trace == ["load", "double"]


def test_runtime_graph_command_updates_state_and_routes() -> None:
    executor = RuntimeGraphExecutor(
        RuntimeGraphPlan(
            nodes=("decide", "accept", "reject"),
            edges=(RuntimeGraphEdge(START, "decide"),),
        ),
        {
            "decide": lambda state: RuntimeGraphCommand(
                update={"route": "accept"},
                goto="accept",
            ),
            "accept": lambda state: {"status": state["route"]},
            "reject": lambda state: {"status": "reject"},
        },
    )

    state, trace = executor.invoke_with_trace({})

    assert state["route"] == "accept"
    assert state["status"] == "accept"
    assert trace == ["decide", "accept"]


def test_runtime_graph_send_fans_out_with_branch_updates() -> None:
    executor = RuntimeGraphExecutor(
        RuntimeGraphPlan(
            nodes=("dispatch", "worker"),
            edges=(
                RuntimeGraphEdge(START, "dispatch"),
                RuntimeGraphEdge("worker", END),
            ),
        ),
        {
            "dispatch": lambda state: (
                RuntimeGraphSend("worker", {"item": 2}),
                RuntimeGraphSend("worker", {"item": 3}),
            ),
            "worker": lambda state: {"results": [state["item"] * 2]},
        },
        reducers={"results": lambda current, incoming: current + incoming},
    )

    state, trace = executor.invoke_with_trace({"results": []})

    assert state["results"] == [4, 6]
    assert "item" not in state
    assert trace == ["dispatch", "worker", "worker"]


def test_runtime_graph_emits_execution_events() -> None:
    executor = RuntimeGraphExecutor(
        RuntimeGraphPlan(
            nodes=("dispatch", "worker"),
            edges=(
                RuntimeGraphEdge(START, "dispatch"),
                RuntimeGraphEdge("worker", END),
            ),
        ),
        {
            "dispatch": lambda state: (
                RuntimeGraphSend("worker", {"item": 2}),
                RuntimeGraphSend("worker", {"item": 3}),
            ),
            "worker": lambda state: {"results": [state["item"] * 2]},
        },
        reducers={"results": lambda current, incoming: current + incoming},
    )

    state, trace, events = executor.invoke_with_events({"results": []})

    assert state["results"] == [4, 6]
    assert trace == ["dispatch", "worker", "worker"]
    assert all(isinstance(event, RuntimeGraphEvent) for event in events)
    assert [event.kind for event in events] == [
        "start",
        "node-start",
        "node-end",
        "node-start",
        "node-end",
        "node-start",
        "node-end",
        "complete",
    ]
    assert events[2].detail["send-targets"] == ("worker", "worker")
    assert events[-1].detail["trace"] == ("dispatch", "worker", "worker")


def test_runtime_graph_interrupt_carries_state_trace_and_events() -> None:
    executor = RuntimeGraphExecutor(
        RuntimeGraphPlan(
            nodes=("load", "approve"),
            edges=(
                RuntimeGraphEdge(START, "load"),
                RuntimeGraphEdge("load", "approve"),
                RuntimeGraphEdge("approve", END),
            ),
        ),
        {
            "load": lambda state: {"value": 42},
            "approve": lambda state: RuntimeGraphInterrupt(
                {"question": "approve?", "value": state["value"]}
            ),
        },
    )

    with pytest.raises(RuntimeGraphInterrupted) as raised:
        executor.invoke_with_events({})

    interrupted = raised.value
    assert interrupted.node == "approve"
    assert interrupted.step == 2
    assert interrupted.state["value"] == 42
    assert interrupted.trace == ("load", "approve")
    assert interrupted.interrupt.value == {"question": "approve?", "value": 42}
    assert [event.kind for event in interrupted.events] == [
        "start",
        "node-start",
        "node-end",
        "node-start",
        "interrupt",
    ]


def test_runtime_graph_resumes_from_interrupt() -> None:
    executor = RuntimeGraphExecutor(
        RuntimeGraphPlan(
            nodes=("load", "approve", "done"),
            edges=(
                RuntimeGraphEdge(START, "load"),
                RuntimeGraphEdge("load", "approve"),
                RuntimeGraphEdge("approve", "done"),
                RuntimeGraphEdge("done", END),
            ),
        ),
        {
            "load": lambda state: {"value": 42},
            "approve": lambda state: RuntimeGraphInterrupt(
                {"question": "approve?", "value": state["value"]}
            ),
            "done": lambda state: {
                "status": "approved" if state["approved"] else "rejected"
            },
        },
    )

    with pytest.raises(RuntimeGraphInterrupted) as raised:
        executor.invoke_with_events({}, trace_key="trace")

    state, trace, events = executor.resume_interrupted(
        raised.value,
        {"approved": True},
        trace_key="trace",
    )

    assert state["status"] == "approved"
    assert state["trace"] == ["load", "approve", "done"]
    assert trace == ["load", "approve", "done"]
    assert [event.kind for event in events][-3:] == [
        "node-start",
        "node-end",
        "complete",
    ]
    assert any(event.kind == "resume" for event in events)


def test_runtime_graph_routes_conditionally() -> None:
    plan = RuntimeGraphPlan(
        nodes=("classify", "accept", "reject"),
        edges=(
            RuntimeGraphEdge(START, "classify"),
            RuntimeGraphEdge("accept", END),
            RuntimeGraphEdge("reject", END),
        ),
        conditional_edges=(
            RuntimeGraphConditionalEdge(
                "classify",
                "classification",
                {"ok": "accept", "bad": "reject"},
            ),
        ),
    )
    executor = RuntimeGraphExecutor(
        plan,
        {
            "classify": lambda state: {"route": "ok" if state["score"] > 0 else "bad"},
            "accept": lambda state: {"status": "accepted"},
            "reject": lambda state: {"status": "rejected"},
        },
        routers={"classification": lambda state: state["route"]},
    )

    assert executor.invoke({"score": 1})["status"] == "accepted"
    assert executor.invoke({"score": 0})["status"] == "rejected"


def test_runtime_graph_applies_reducers() -> None:
    plan = RuntimeGraphPlan(
        nodes=("left", "right"),
        edges=(
            RuntimeGraphEdge(START, "left"),
            RuntimeGraphEdge(START, "right"),
            RuntimeGraphEdge("left", END),
            RuntimeGraphEdge("right", END),
        ),
    )
    executor = RuntimeGraphExecutor(
        plan,
        {
            "left": lambda state: {"events": ["left"]},
            "right": lambda state: {"events": ["right"]},
        },
        reducers={"events": lambda current, incoming: current + incoming},
    )

    assert executor.invoke({"events": []})["events"] == ["left", "right"]


def test_runtime_graph_rejects_missing_action() -> None:
    with pytest.raises(RuntimeGraphError, match="missing runtime graph actions"):
        RuntimeGraphExecutor(linear_plan("missing"), {})


def test_runtime_graph_enforces_step_limit() -> None:
    plan = RuntimeGraphPlan(
        nodes=("loop",),
        edges=(
            RuntimeGraphEdge(START, "loop"),
            RuntimeGraphEdge("loop", "loop"),
        ),
        step_limit=3,
    )
    executor = RuntimeGraphExecutor(plan, {"loop": lambda state: {"count": 1}})

    with pytest.raises(RuntimeGraphError, match="step limit exceeded"):
        executor.invoke({})
