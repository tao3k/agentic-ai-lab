# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Small upstream-derived LangGraph cases routed through Agentic AI Lab compat."""

from __future__ import annotations

import importlib
import operator
import sys
from pathlib import Path
from types import ModuleType
from typing import Annotated, Any, TypedDict


def test_state_graph_accepts_upstream_callable_node_shape(monkeypatch) -> None:
    _install_langgraph_shim(monkeypatch)
    graph_state = importlib.import_module("langgraph.graph.state")

    class InputState(TypedDict):
        question: str

    class OutputState(TypedDict):
        input_state: InputState

    def complete_hint(state: InputState) -> OutputState:
        return {"input_state": state}

    def add_marker(state: OutputState) -> dict[str, str]:
        assert state["input_state"]["question"] == "Hello"
        return {"marker": "done"}

    graph = graph_state.StateGraph(InputState, output_schema=OutputState)
    graph.add_node(complete_hint)
    graph.add_node(add_marker)
    graph.set_entry_point("complete_hint")
    graph.add_edge("complete_hint", "add_marker")
    graph.set_finish_point("add_marker")

    assert graph.compile().invoke({"question": "Hello"}) == {
        "question": "Hello",
        "input_state": {"question": "Hello"},
        "marker": "done",
    }


def test_conditional_entry_point_send_shape_matches_upstream(monkeypatch) -> None:
    _install_langgraph_shim(monkeypatch)
    constants = importlib.import_module("langgraph.constants")
    graph_module = importlib.import_module("langgraph.graph")
    types_module = importlib.import_module("langgraph.types")

    def get_weather(state: dict[str, str]) -> dict[str, list[str]]:
        weather = "sunny" if len(state["location"]) > 2 else "cloudy"
        return {"results": [f"It's {weather} in {state['location']}"]}

    def continue_to_weather(state: dict[str, Any]) -> list[Any]:
        return [
            types_module.Send("get_weather", {"location": location})
            for location in state["locations"]
        ]

    class OverallState(TypedDict):
        locations: list[str]
        results: Annotated[list[str], operator.add]

    workflow = graph_module.StateGraph(OverallState)
    workflow.add_node("get_weather", get_weather)
    workflow.add_edge("get_weather", constants.END)
    workflow.set_conditional_entry_point(
        continue_to_weather,
        path_map=["get_weather"],
    )

    result = workflow.compile().invoke({"locations": ["SF", "Paris"]})

    assert result["locations"] == ["SF", "Paris"]
    assert result["results"] == ["It's cloudy in SF", "It's sunny in Paris"]


def _install_langgraph_shim(monkeypatch) -> None:
    _remove_langgraph_modules()
    monkeypatch.syspath_prepend(str(Path(__file__).resolve().parent / "langgraph_shim"))


def _remove_langgraph_modules() -> None:
    modules: list[str] = [
        name
        for name, module in sys.modules.items()
        if name == "langgraph" or name.startswith("langgraph.")
        if _is_test_shim_or_unknown(module)
    ]
    for name in modules:
        sys.modules.pop(name, None)


def _is_test_shim_or_unknown(module: ModuleType | Any) -> bool:
    path = getattr(module, "__file__", "")
    return not path or "tests/unit/langgraph_shim" in str(path)
