# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""LangGraph-style StateGraph builder backed by Agentic AI Lab runtime graphs."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any

from ...builder import RuntimeGraphBuilder
from ...checkpoints import MemoryRuntimeGraphCheckpointer
from ...runtime_graph import RuntimeGraphCommand as Command
from ...runtime_graph import RuntimeGraphSend as Send
from ._helpers import END, START, endpoint, node_name, route_map, schema_reducers
from .compiled import CompiledStateGraph, StateSnapshot

MemorySaver = MemoryRuntimeGraphCheckpointer
InMemorySaver = MemoryRuntimeGraphCheckpointer


class StateGraph:
    """LangGraph-compatible builder that delegates to RuntimeGraphBuilder."""

    def __init__(
        self,
        state_schema: object | None = None,
        config_schema: object | None = None,
        *,
        input_schema: object | None = None,
        output_schema: object | None = None,
        context_schema: object | None = None,
    ) -> None:
        self.state_schema = state_schema
        self.config_schema = config_schema
        self.input_schema = input_schema
        self.output_schema = output_schema
        self.context_schema = context_schema
        self._builder = RuntimeGraphBuilder()
        self._entry_counter = 0
        for key, reducer in schema_reducers(state_schema).items():
            self._builder.add_reducer(key, reducer)

    def add_node(self, name: str | Any, action: Any | None = None) -> "StateGraph":
        node_action = name if action is None else action
        node_name = node_name_from_action(name, node_action, action)
        self._builder.add_node(node_name, node_action)
        return self

    def add_edge(self, start_key: str | Sequence[str], end_key: str) -> "StateGraph":
        if isinstance(start_key, Sequence) and not isinstance(start_key, str):
            for source in start_key:
                self.add_edge(str(source), end_key)
            return self
        self._builder.add_edge(endpoint(str(start_key)), endpoint(end_key))
        return self

    def add_conditional_edges(
        self,
        source: str,
        path: Any,
        path_map: Mapping[str, str] | Sequence[str] | None = None,
        then: str | None = None,
    ) -> "StateGraph":
        if then is not None:
            raise NotImplementedError("LangGraph 'then' branches are not supported yet")
        self._builder.add_conditional_edges(endpoint(source), path, route_map(path_map))
        return self

    def set_conditional_entry_point(
        self,
        path: Any,
        path_map: Mapping[str, str] | Sequence[str] | None = None,
        then: str | None = None,
    ) -> "StateGraph":
        entry_node = self._next_entry_node()
        self._builder.add_node(entry_node, lambda _state: {})
        self._builder.add_edge(START, entry_node)
        return self.add_conditional_edges(entry_node, path, path_map, then=then)

    def add_sequence(self, nodes: Sequence[tuple[str, Any]]) -> "StateGraph":
        self._builder.add_sequence(nodes)
        return self

    def set_entry_point(self, key: str) -> "StateGraph":
        self._builder.set_entry_point(endpoint(key))
        return self

    def set_finish_point(self, key: str) -> "StateGraph":
        self._builder.add_edge(endpoint(key), END)
        return self

    def compile(
        self,
        *,
        checkpointer: MemoryRuntimeGraphCheckpointer | None = None,
        store: Any = None,
        interrupt_before: Sequence[str] | None = None,
        interrupt_after: Sequence[str] | None = None,
        debug: bool = False,
        **metadata: Any,
    ) -> CompiledStateGraph:
        if interrupt_before or interrupt_after:
            raise NotImplementedError("LangGraph interrupt markers are not supported yet")
        executor = self._builder.compile(
            checkpointer=checkpointer,
            store=store,
            metadata={"debug": debug, **metadata},
        )
        return CompiledStateGraph(executor=executor, checkpointer=checkpointer)

    def _next_entry_node(self) -> str:
        self._entry_counter += 1
        return f"__agentic_ai_lab_langgraph_entry_{self._entry_counter}__"


def node_name_from_action(name: str | Any, node_action: Any, action: Any | None) -> str:
    return node_name(node_action) if action is None else str(name)


__all__ = [
    "Command",
    "CompiledStateGraph",
    "END",
    "InMemorySaver",
    "MemorySaver",
    "START",
    "Send",
    "StateGraph",
    "StateSnapshot",
]
