# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass, field
from typing import Any

START = "__start__"
END = "__end__"

RuntimeState = dict[str, Any]
RuntimeReducer = Callable[[Any, Any], Any]


class RuntimeGraphError(RuntimeError):
    pass


@dataclass(frozen=True)
class RuntimeGraphEdge:
    source: str
    target: str


@dataclass(frozen=True)
class RuntimeGraphConditionalEdge:
    source: str
    router: str
    routes: Mapping[str, str]


@dataclass(frozen=True)
class RuntimeGraphPlan:
    nodes: tuple[str, ...]
    edges: tuple[RuntimeGraphEdge, ...]
    conditional_edges: tuple[RuntimeGraphConditionalEdge, ...] = ()
    step_limit: int = 100
    metadata: Mapping[str, str] = field(default_factory=dict)


@dataclass(frozen=True)
class RuntimeGraphCommand:
    update: Mapping[str, Any] = field(default_factory=dict)
    goto: str | Sequence[str] | None = None

    def goto_nodes(self) -> tuple[str, ...]:
        if self.goto is None:
            return ()
        if isinstance(self.goto, str):
            return (self.goto,)
        return tuple(self.goto)


@dataclass(frozen=True)
class RuntimeGraphSend:
    target: str
    update: Mapping[str, Any] = field(default_factory=dict)


RuntimeRouteResult = str | Sequence[str] | RuntimeGraphSend | Sequence[RuntimeGraphSend]
RuntimeRouter = Callable[[Mapping[str, Any]], RuntimeRouteResult]


@dataclass(frozen=True)
class RuntimeGraphInterrupt:
    value: Any
    resumable: bool = True


@dataclass(frozen=True)
class RuntimeGraphEvent:
    kind: str
    node: str | None
    step: int
    detail: Mapping[str, Any] = field(default_factory=dict)


RuntimeActionResult = (
    Mapping[str, Any]
    | RuntimeGraphCommand
    | RuntimeGraphInterrupt
    | RuntimeGraphSend
    | Sequence[RuntimeGraphSend]
    | None
)
RuntimeAction = Callable[[Mapping[str, Any]], RuntimeActionResult]


class RuntimeGraphInterrupted(RuntimeGraphError):
    def __init__(
        self,
        interrupt: RuntimeGraphInterrupt,
        *,
        node: str,
        step: int,
        state: Mapping[str, Any],
        trace: Sequence[str],
        pending: Sequence[Any] = (),
        events: Sequence[RuntimeGraphEvent] = (),
        validation_receipt: bytes = b"",
        plan_digest: str | None = None,
    ) -> None:
        super().__init__("runtime graph interrupted")
        self.interrupt = interrupt
        self.node = node
        self.step = step
        self.state = dict(state)
        self.trace = tuple(trace)
        self.pending = tuple(pending)
        self.events = tuple(events)
        self.validation_receipt = validation_receipt
        self.plan_digest = plan_digest


__all__ = [
    "END",
    "START",
    "RuntimeAction",
    "RuntimeActionResult",
    "RuntimeGraphCommand",
    "RuntimeGraphConditionalEdge",
    "RuntimeGraphEdge",
    "RuntimeGraphError",
    "RuntimeGraphEvent",
    "RuntimeGraphInterrupt",
    "RuntimeGraphInterrupted",
    "RuntimeGraphPlan",
    "RuntimeGraphSend",
    "RuntimeReducer",
    "RuntimeRouteResult",
    "RuntimeRouter",
    "RuntimeState",
]
