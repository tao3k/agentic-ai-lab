# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from typing import Any, Callable, Mapping

from .messages import add_messages
from .runtime import RuntimeGraphRuntime
from .runtime_graph import END, RuntimeAction, RuntimeGraphExecutor
from .tools import RuntimeGraphToolNode
from .builder import RuntimeGraphBuilder


def tools_condition(
    state: Mapping[str, Any],
    *,
    messages_key: str = "messages",
    tools_route: str = "tools",
    end_route: str = END,
) -> str:
    messages = tuple(state.get(messages_key, ()))
    if messages and messages[-1].tool_calls:
        return tools_route
    return end_route


def create_tool_call_loop(
    model_action: RuntimeAction,
    tools: Mapping[str, Callable[..., Any]],
    *,
    model_node: str = "model",
    tool_node: str = "tools",
    messages_key: str = "messages",
    runtime: RuntimeGraphRuntime | None = None,
) -> RuntimeGraphExecutor:
    router_name = f"{model_node}:tools-condition"
    builder = RuntimeGraphBuilder()
    builder.add_node(model_node, model_action)
    builder.add_node(
        tool_node,
        RuntimeGraphToolNode.from_callables(tools, messages_key=messages_key),
    )
    builder.set_entry_point(model_node)
    builder.add_edge(tool_node, model_node)
    builder.add_conditional_edges(
        model_node,
        lambda state: tools_condition(
            state,
            messages_key=messages_key,
            tools_route=tool_node,
            end_route=END,
        ),
        {tool_node: tool_node, END: END},
        name=router_name,
    )
    builder.add_reducer(messages_key, add_messages)
    return builder.compile(runtime=runtime)
