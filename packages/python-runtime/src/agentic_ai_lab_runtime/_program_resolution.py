# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Registry resolution helpers for runtime graph programs."""

from __future__ import annotations

from typing import Any

from .materialization import RuntimeGraphBindings
from .runtime_graph import RuntimeAction, RuntimeGraphError, RuntimeGraphPlan, RuntimeReducer


def resolve_actions(
    plan: RuntimeGraphPlan,
    graph_bindings: RuntimeGraphBindings,
    registries: Any,
) -> dict[str, RuntimeAction]:
    resolved: dict[str, RuntimeAction] = {}
    for node in plan.nodes:
        action_symbol = graph_bindings.action_for(node)
        try:
            resolved[node] = registries.actions[action_symbol]
        except KeyError as exc:
            raise RuntimeGraphError(
                f"missing runtime action registry entry: {action_symbol}"
            ) from exc
    return resolved


def resolve_reducers(
    graph_bindings: RuntimeGraphBindings,
    registries: Any,
) -> dict[str, RuntimeReducer]:
    resolved: dict[str, RuntimeReducer] = {}
    for state_key, reducer_symbol in graph_bindings.state_reducers.items():
        try:
            resolved[state_key] = registries.reducers[reducer_symbol]
        except KeyError as exc:
            raise RuntimeGraphError(
                f"missing runtime reducer registry entry: {reducer_symbol}"
            ) from exc
    return resolved
