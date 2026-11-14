# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from agentic_ai_lab_runtime import (
    RuntimeGraphBuilder,
    RuntimeGraphToolCall,
    RuntimeGraphToolError,
    RuntimeGraphToolNode,
    ai_message,
    create_tool_call_loop,
    linear_plan,
    tools_condition,
)


def test_langchain_scheme_case_maps_to_linear_runtime_graph():
    plan = linear_plan("memory", "prompt", "model", "parser", step_limit=8)
    assert [edge.source for edge in plan.edges] == [
        "__start__",
        "memory",
        "prompt",
        "model",
        "parser",
    ]
    assert [edge.target for edge in plan.edges] == [
        "memory",
        "prompt",
        "model",
        "parser",
        "__end__",
    ]

    def memory(state):
        return {"history": tuple(state.get("history", ())) + ("remembered",)}

    def prompt(state):
        return {"prompt": f"{state['question']} :: {state['history'][-1]}"}

    def model(state):
        return {"raw_output": state["prompt"].upper()}

    def parser(state):
        return {"parsed_output": state["raw_output"].lower()}

    executor = RuntimeGraphBuilder(step_limit=8).add_sequence(
        [
            ("memory", memory),
            ("prompt", prompt),
            ("model", model),
            ("parser", parser),
        ]
    ).set_entry_point("memory").set_finish_point("parser").compile()
    state, trace = executor.invoke_with_trace({"question": "hello"})
    assert trace == ["memory", "prompt", "model", "parser"]
    assert state["parsed_output"] == "hello :: remembered"


def test_tool_calling_scheme_case_maps_to_runtime_tool_loop():
    observed_calls = []

    def lookup(query: str) -> str:
        observed_calls.append(query)
        return f"result:{query}"

    def model(state):
        messages = state.get("messages", ())
        if not messages:
            return {
                "messages": (
                    ai_message(
                        "call lookup",
                        tool_calls=(
                            RuntimeGraphToolCall(
                                name="lookup",
                                args={"query": "agentic-ai-lab"},
                                id="call-1",
                            ),
                        ),
                    ),
                )
            }
        return {"accepted": True, "final": messages[-1].content}

    executor = create_tool_call_loop(model, {"lookup": lookup})
    state, trace = executor.invoke_with_trace({"messages": ()})
    assert trace == ["model", "tools", "model"]
    assert observed_calls == ["agentic-ai-lab"]
    assert state["accepted"] is True
    assert state["final"] == "result:agentic-ai-lab"


def test_tool_calling_scheme_case_validates_missing_tool_scope():
    tool_node = RuntimeGraphToolNode.from_callables({})
    message = ai_message(
        "call missing",
        tool_calls=(
            RuntimeGraphToolCall(name="missing", args={}, id="missing-call"),
        ),
    )
    import pytest

    with pytest.raises(RuntimeGraphToolError, match="missing runtime graph tool"):
        tool_node({"messages": (message,)})


def test_tool_condition_matches_scheme_exit_gate():
    assert tools_condition({"messages": ()}) == "__end__"
    assert tools_condition({"messages": (ai_message("done"),)}) == "__end__"
    assert (
        tools_condition(
            {
                "messages": (
                    ai_message(
                        "call",
                        tool_calls=(
                            RuntimeGraphToolCall(name="lookup", id="call-1"),
                        ),
                    ),
                )
            }
        )
        == "tools"
    )
