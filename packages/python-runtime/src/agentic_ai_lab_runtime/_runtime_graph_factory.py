# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import inspect

from ._runtime_graph_types import (
    END,
    START,
    RuntimeAction,
    RuntimeGraphEdge,
    RuntimeGraphError,
    RuntimeGraphPlan,
)
from .runtime import RuntimeGraphRuntime


def linear_plan(*nodes: str, step_limit: int = 100) -> RuntimeGraphPlan:
    if not nodes:
        raise RuntimeGraphError("linear runtime graph requires at least one node")
    edges = [RuntimeGraphEdge(START, nodes[0])]
    edges.extend(RuntimeGraphEdge(source, target) for source, target in zip(nodes, nodes[1:]))
    edges.append(RuntimeGraphEdge(nodes[-1], END))
    return RuntimeGraphPlan(tuple(nodes), tuple(edges), step_limit=step_limit)


def bind_runtime_action(
    action: RuntimeAction, runtime: RuntimeGraphRuntime
) -> RuntimeAction:
    signature = inspect.signature(action)
    positional = [
        parameter
        for parameter in signature.parameters.values()
        if parameter.kind
        in (inspect.Parameter.POSITIONAL_ONLY, inspect.Parameter.POSITIONAL_OR_KEYWORD)
    ]
    has_varargs = any(
        parameter.kind == inspect.Parameter.VAR_POSITIONAL
        for parameter in signature.parameters.values()
    )
    if has_varargs or len(positional) >= 2:
        return lambda state: action(state, runtime)
    return action


__all__ = ["bind_runtime_action", "linear_plan"]
