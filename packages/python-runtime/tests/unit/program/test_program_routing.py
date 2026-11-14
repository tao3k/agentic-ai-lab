# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from agentic_ai_lab_runtime import (
    END,
    START,
    RuntimeGraphConditionalEdge,
    RuntimeGraphEdge,
    RuntimeGraphPlan,
    RuntimeGraphProgram,
    RuntimeGraphRegistries,
    parse_runtime_receipt,
)


def test_runtime_graph_program_describe_receipt_returns_typed_receipt() -> None:
    plan = RuntimeGraphPlan(
        nodes=("first",),
        edges=(RuntimeGraphEdge(START, "first"), RuntimeGraphEdge("first", END)),
    )
    program = RuntimeGraphProgram.reference(
        plan=plan,
        registries=RuntimeGraphRegistries(actions={"first": lambda state: {"x": 1}}),
    )

    receipt = program.describe_receipt()
    parsed = parse_runtime_receipt(program.describe())

    assert receipt.kind == parsed.kind
    assert receipt.plan_digest == parsed.plan_digest


def test_runtime_graph_program_invokes_conditional_router_registry() -> None:
    plan = RuntimeGraphPlan(
        nodes=("decide", "left", "right"),
        edges=(
            RuntimeGraphEdge(START, "decide"),
            RuntimeGraphEdge("left", END),
            RuntimeGraphEdge("right", END),
        ),
        conditional_edges=(
            RuntimeGraphConditionalEdge(
                "decide", "route", {"left": "left", "right": "right"}
            ),
        ),
    )
    registries = RuntimeGraphRegistries(
        actions={
            "decide": lambda state: {"route": state["route"]},
            "left": lambda state: {"value": "left"},
            "right": lambda state: {"value": "right"},
        },
        routers={"route": lambda state: state["route"]},
    )
    program = RuntimeGraphProgram.reference(plan=plan, registries=registries)

    assert program.invoke({"route": "right"}) == {"route": "right", "value": "right"}
