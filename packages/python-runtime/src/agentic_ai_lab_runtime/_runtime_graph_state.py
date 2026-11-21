# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from collections import defaultdict
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from typing import Any

from ._runtime_graph_types import (
    END,
    START,
    RuntimeActionResult,
    RuntimeGraphCommand,
    RuntimeGraphConditionalEdge,
    RuntimeGraphEdge,
    RuntimeGraphError,
    RuntimeGraphInterrupt,
    RuntimeGraphSend,
    RuntimeReducer,
    RuntimeState,
)


@dataclass(frozen=True)
class NormalizedActionResult:
    update: Mapping[str, Any] | None
    goto: tuple[str, ...]
    controls_flow: bool
    sends: tuple[RuntimeGraphSend, ...]
    interrupt: RuntimeGraphInterrupt | None


def check_endpoint(endpoint: str, node_set: set[str]) -> None:
    if endpoint not in node_set and endpoint not in {START, END}:
        raise RuntimeGraphError(f"unknown runtime graph endpoint: {endpoint}")


def index_edges(edges: tuple[RuntimeGraphEdge, ...]) -> dict[str, list[str]]:
    indexed: dict[str, list[str]] = defaultdict(list)
    for edge in edges:
        indexed[edge.source].append(edge.target)
    return indexed


def index_conditional_edges(
    edges: tuple[RuntimeGraphConditionalEdge, ...],
) -> dict[str, list[RuntimeGraphConditionalEdge]]:
    indexed: dict[str, list[RuntimeGraphConditionalEdge]] = defaultdict(list)
    for edge in edges:
        indexed[edge.source].append(edge)
    return indexed


def merge_state(
    state: RuntimeState,
    update: Mapping[str, Any],
    reducers: Mapping[str, RuntimeReducer],
) -> RuntimeState:
    merged = dict(state)
    for key, value in update.items():
        if key in merged and key in reducers:
            merged[key] = reducers[key](merged[key], value)
        else:
            merged[key] = value
    return merged


def with_branch_update(
    state: Mapping[str, Any],
    update: Mapping[str, Any] | None,
) -> RuntimeState:
    branch_state = dict(state)
    if update:
        branch_state.update(update)
    return branch_state


def normalize_action_result(result: RuntimeActionResult) -> NormalizedActionResult:
    if isinstance(result, RuntimeGraphInterrupt):
        return NormalizedActionResult(None, (), True, (), result)
    if isinstance(result, RuntimeGraphCommand):
        goto = result.goto_nodes()
        return NormalizedActionResult(result.update, goto, bool(goto), (), None)
    if isinstance(result, RuntimeGraphSend):
        return NormalizedActionResult(None, (), True, (result,), None)
    if is_send_sequence(result):
        return NormalizedActionResult(None, (), True, tuple(result), None)
    return NormalizedActionResult(result, (), False, (), None)


def is_send_sequence(result: object) -> bool:
    if not isinstance(result, Sequence):
        return False
    if isinstance(result, (str, bytes, bytearray)):
        return False
    return all(isinstance(item, RuntimeGraphSend) for item in result)


__all__ = [
    "NormalizedActionResult",
    "check_endpoint",
    "index_conditional_edges",
    "index_edges",
    "is_send_sequence",
    "merge_state",
    "normalize_action_result",
    "with_branch_update",
]
