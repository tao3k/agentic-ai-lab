# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import pytest

from agentic_ai_lab_runtime import (
    END,
    START,
    RuntimeGraphConditionalEdge,
    RuntimeGraphEdge,
    RuntimeGraphExecutor,
    RuntimeGraphPlan,
    RuntimeGraphToolCall,
    RuntimeGraphToolError,
    RuntimeGraphToolNode,
    add_messages,
    ai_message,
    human_message,
)


def test_add_messages_appends_and_replaces_by_id() -> None:
    first = human_message("hello", id="1")
    second = ai_message("hi", id="2")
    replacement = human_message("hello again", id="1")

    assert add_messages([first], [second]) == [first, second]
    assert add_messages([first, second], replacement) == [replacement, second]


def test_runtime_graph_tool_node_invokes_tool_calls() -> None:
    tool_node = RuntimeGraphToolNode.from_callables(
        {
            "add": lambda a, b: a + b,
            "multiply": lambda a, b: a * b,
        }
    )
    state = {
        "messages": [
            ai_message(
                "",
                tool_calls=(
                    RuntimeGraphToolCall("add", {"a": 2, "b": 3}, id="call-1"),
                    RuntimeGraphToolCall(
                        "multiply",
                        {"a": 4, "b": 5},
                        id="call-2",
                    ),
                ),
            )
        ]
    }

    update = tool_node(state)

    assert [message.role for message in update["messages"]] == ["tool", "tool"]
    assert [message.content for message in update["messages"]] == [5, 20]
    assert [message.tool_call_id for message in update["messages"]] == [
        "call-1",
        "call-2",
    ]


def test_runtime_graph_tool_node_reports_missing_tool() -> None:
    tool_node = RuntimeGraphToolNode.from_callables({"add": lambda a, b: a + b})

    with pytest.raises(RuntimeGraphToolError, match="missing"):
        tool_node(
            {
                "messages": [
                    ai_message(
                        "",
                        tool_calls=(
                            RuntimeGraphToolCall("missing", {"a": 2, "b": 3}),
                        ),
                    )
                ]
            }
        )


def test_runtime_graph_messages_and_tool_node_compose_in_graph() -> None:
    tool_node = RuntimeGraphToolNode.from_callables({"add": lambda a, b: a + b})

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

    def route(state):
        return "end" if state.get("done") else "tools"

    executor = RuntimeGraphExecutor(
        RuntimeGraphPlan(
            nodes=("model", "tools"),
            edges=(
                RuntimeGraphEdge(START, "model"),
                RuntimeGraphEdge("tools", "model"),
            ),
            conditional_edges=(
                RuntimeGraphConditionalEdge(
                    "model",
                    "route",
                    {"tools": "tools", "end": END},
                ),
            ),
        ),
        {"model": model, "tools": tool_node},
        routers={"route": route},
        reducers={"messages": add_messages},
    )

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
