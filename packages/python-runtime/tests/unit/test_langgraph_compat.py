# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from typing import Any

from agentic_ai_lab_runtime.compat.langgraph import END, START, MemorySaver, Send, StateGraph
from agentic_ai_lab_runtime.compat.langgraph.checkpoint.memory import MemorySaver as MemorySaverFromPath
from agentic_ai_lab_runtime.compat.langgraph.graph import StateGraph as StateGraphFromGraphPath
from agentic_ai_lab_runtime.compat.langgraph.types import Send as SendFromTypesPath


def test_langgraph_compat_exposes_langgraph_shaped_module_paths() -> None:
    assert StateGraphFromGraphPath is StateGraph
    assert SendFromTypesPath is Send
    assert MemorySaverFromPath is MemorySaver


def test_langgraph_state_graph_invokes_sequence() -> None:
    graph = StateGraph(dict)
    graph.add_node("load", lambda state: {"value": int(state.get("value", 0)) + 1})
    graph.add_node("finish", lambda state: {"result": state["value"] * 2})
    graph.add_edge(START, "load")
    graph.add_edge("load", "finish")
    graph.add_edge("finish", END)

    app = graph.compile()

    assert app.invoke({"value": 2}) == {"value": 3, "result": 6}


def test_langgraph_conditional_send_routes_to_runtime_send() -> None:
    graph = StateGraph(dict)

    def fanout(state: dict[str, Any]) -> list[Send]:
        return [
            Send("left", {"left_input": state["seed"] + 1}),
            Send("right", {"right_input": state["seed"] + 2}),
        ]

    graph.add_node("route", lambda state: {})
    graph.add_node("left", lambda state: {"left": state["left_input"] * 10})
    graph.add_node("right", lambda state: {"right": state["right_input"] * 10})
    graph.add_edge(START, "route")
    graph.add_conditional_edges("route", fanout)
    graph.add_edge("left", END)
    graph.add_edge("right", END)

    result = graph.compile().invoke({"seed": 1})

    assert result["left"] == 20
    assert result["right"] == 30


def test_langgraph_conditional_path_map_accepts_end() -> None:
    graph = StateGraph(dict)
    graph.add_node("decide", lambda state: {"ready": state.get("ready", False)})
    graph.add_node("work", lambda state: {"worked": True})
    graph.add_edge(START, "decide")
    graph.add_conditional_edges(
        "decide",
        lambda state: "work" if state["ready"] else "done",
        {"work": "work", "done": END},
    )
    graph.add_edge("work", END)

    assert graph.compile().invoke({"ready": False}) == {"ready": False}
    assert graph.compile().invoke({"ready": True})["worked"] is True


def test_langgraph_checkpointer_state_facade_uses_thread_config() -> None:
    graph = StateGraph(dict)
    graph.add_node("inc", lambda state: {"count": int(state.get("count", 0)) + 1})
    graph.add_edge(START, "inc")
    graph.add_edge("inc", END)
    memory = MemorySaver()
    app = graph.compile(checkpointer=memory)
    config = {"configurable": {"thread_id": "compat-thread"}}

    assert app.invoke({"count": 1}, config) == {"count": 2}

    snapshot = app.get_state(config)
    assert snapshot.values == {"count": 2}
    assert snapshot.metadata["node"] == "inc"

    updated = app.update_state(config, {"extra": "ok"}, as_node="manual")
    assert updated.values == {"count": 2, "extra": "ok"}
    assert updated.metadata["node"] == "manual"

    history = app.get_state_history(config)
    assert len(history) == 3
    assert history[-1].values["extra"] == "ok"
