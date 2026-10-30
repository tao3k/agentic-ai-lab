# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from collections import deque
from collections.abc import Mapping, Sequence
from typing import Any

from ._runtime_graph_types import (
    RuntimeGraphEvent,
    RuntimeGraphInterrupted,
    RuntimeGraphSend,
    RuntimeState,
)


class GraphRunContext:
    def __init__(
        self,
        state: Mapping[str, Any],
        pending: Sequence[Any],
        *,
        state_is_owned: bool = False,
        trace: Sequence[str] = (),
        events: Sequence[RuntimeGraphEvent] = (),
        step: int = 0,
    ) -> None:
        self.state = state if state_is_owned else dict(state)
        self.pending = deque(pending)
        self.trace = list(trace)
        self.events = list(events)
        self.step = step

    @classmethod
    def from_initial(cls, executor, initial_state: Mapping[str, Any]) -> "GraphRunContext":
        from ._runtime_graph_types import START

        return cls(initial_state, executor._edges[START])

    @classmethod
    def from_owned(cls, executor, initial_state: RuntimeState) -> "GraphRunContext":
        """Take single-use ownership of a fresh state without copying it.

        The caller must relinquish the dictionary and must not observe or reuse it
        after this call. Shared or caller-visible state must use ``from_initial``.
        """
        from ._runtime_graph_types import START

        return cls(initial_state, executor._edges[START], state_is_owned=True)

    @classmethod
    def from_interrupted(cls, interrupted: RuntimeGraphInterrupted) -> "GraphRunContext":
        return cls(
            interrupted.state,
            interrupted.pending,
            trace=interrupted.trace,
            events=interrupted.events,
            step=interrupted.step,
        )

    def next_node(self) -> tuple[str, Mapping[str, Any] | None]:
        item = self.pending.popleft()
        if isinstance(item, RuntimeGraphSend):
            return item.target, item.update
        return item, None

    def advance_step(self, step_limit: int) -> None:
        self.step += 1
        if self.step > step_limit:
            from ._runtime_graph_types import RuntimeGraphError

            raise RuntimeGraphError("runtime graph step limit exceeded")

    def publish(
        self,
        kind: str,
        node: str | None,
        step: int,
        detail: Mapping[str, Any],
    ) -> RuntimeGraphEvent:
        event = RuntimeGraphEvent(kind, node, step, detail)
        self.events.append(event)
        return event


def record_trace(state: RuntimeState, trace_key: str | None, trace: Sequence[str]) -> None:
    if trace_key is not None:
        state[trace_key] = list(trace)


__all__ = ["GraphRunContext", "record_trace"]
