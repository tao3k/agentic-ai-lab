# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Upstream-shaped LangGraph imports routed into Agentic AI Lab compat."""

from __future__ import annotations

import importlib
import sys
from pathlib import Path
from types import ModuleType
from typing import Any


def test_upstream_langgraph_import_shape_runs_on_agentic_ai_lab(monkeypatch) -> None:
    _remove_langgraph_modules()
    monkeypatch.syspath_prepend(str(_shim_root()))

    graph_module = importlib.import_module("langgraph.graph")
    types_module = importlib.import_module("langgraph.types")
    memory_module = importlib.import_module("langgraph.checkpoint.memory")

    StateGraph = graph_module.StateGraph
    START = graph_module.START
    END = graph_module.END
    Send = types_module.Send
    MemorySaver = memory_module.MemorySaver

    graph = StateGraph(dict)
    graph.add_node("fanout", lambda state: {})
    graph.add_node("worker", lambda state: {"total": state["value"] * 2})
    graph.add_node("finish", lambda state: {"done": state["total"] + 1})
    graph.add_edge(START, "fanout")
    graph.add_conditional_edges(
        "fanout",
        lambda state: [Send("worker", {"value": state["seed"]})],
    )
    graph.add_edge("worker", "finish")
    graph.add_edge("finish", END)

    app = graph.compile(checkpointer=MemorySaver())
    config = {"configurable": {"thread_id": "upstream-shim"}}

    assert app.invoke({"seed": 4}, config) == {"seed": 4, "total": 8, "done": 9}
    assert app.get_state(config).values["done"] == 9


def _shim_root() -> Path:
    return Path(__file__).resolve().parent / "langgraph_shim"


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
    return not path or "tests/langgraph_shim" in str(path)
