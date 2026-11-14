# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from agentic_ai_lab_runtime import (
    END,
    RuntimeGraphBuilder,
    RuntimeGraphToolCall,
    ai_message,
    create_tool_call_loop,
    human_message,
    tools_condition,
)


def test_runtime_graph_builder_compiles_executor() -> None:
    builder = RuntimeGraphBuilder()
    builder.add_node("load", lambda state: {"value": state["seed"] + 1})
    builder.add_node("double", lambda state: {"value": state["value"] * 2})
    builder.set_entry_point("load")
    builder.add_edge("load", "double")
    builder.set_finish_point("double")

    state = builder.compile().invoke({"seed": 20})

    assert state["value"] == 42


def test_runtime_graph_builder_compiles_program() -> None:
    builder = RuntimeGraphBuilder()
    builder.add_node("load", lambda state: {"value": state["seed"] + 1})
    builder.add_node("double", lambda state: {"value": state["value"] * 2})
    builder.set_entry_point("load")
    builder.add_edge("load", "double")
    builder.set_finish_point("double")

    execution = builder.compile_reference_program().invoke_with_trace({"seed": 20})

    assert execution.state["value"] == 42
    assert execution.trace == ("load", "double")
    assert execution.plan_digest is not None


def test_runtime_graph_builder_compiles_conditional_executor() -> None:
    builder = RuntimeGraphBuilder()
    builder.add_node("classify", lambda state: {"route": "ok" if state["score"] > 0 else "bad"})
    builder.add_node("accept", lambda state: {"status": "accepted"})
    builder.add_node("reject", lambda state: {"status": "rejected"})
    builder.set_entry_point("classify")
    builder.add_conditional_edges(
        "classify",
        lambda state: state["route"],
        {"ok": "accept", "bad": "reject"},
    )
    builder.set_finish_point("accept")
    builder.set_finish_point("reject")

    assert builder.compile().invoke({"score": 1})["status"] == "accepted"
    assert builder.compile().invoke({"score": -1})["status"] == "rejected"


def test_tools_condition_routes_to_tools_or_end() -> None:
    assert tools_condition({"messages": [ai_message("", tool_calls=(RuntimeGraphToolCall("add"),))]}) == "tools"
    assert tools_condition({"messages": [ai_message("done")]}) == END


def test_create_tool_call_loop_runs_common_tool_cycle() -> None:
    def model(state):
        if any(message.role == "tool" for message in state["messages"]):
            return {"messages": [ai_message("done")], "done": True}
        return {
            "messages": [
                ai_message(
                    "call add",
                    tool_calls=(
                        RuntimeGraphToolCall("add", {"a": 20, "b": 22}, id="call-1"),
                    ),
                )
            ]
        }

    executor = create_tool_call_loop(model, {"add": lambda a, b: a + b})

    state, trace = executor.invoke_with_trace({"messages": [human_message("hi")]})

    assert trace == ["model", "tools", "model"]
    assert [message.role for message in state["messages"]] == [
        "human",
        "ai",
        "tool",
        "ai",
    ]
    assert state["messages"][2].content == 42
    assert state["done"] is True
