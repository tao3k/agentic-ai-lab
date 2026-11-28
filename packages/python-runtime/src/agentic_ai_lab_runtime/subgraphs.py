# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable, Mapping

from .runtime_graph import (
    RuntimeAction,
    RuntimeGraphExecutor,
    RuntimeGraphPlan,
    RuntimeReducer,
    RuntimeRouter,
)


@dataclass(frozen=True)
class RuntimeGraphSubgraph:
    executor: RuntimeGraphExecutor
    input_keys: tuple[str, ...] | None = None
    output_keys: tuple[str, ...] | None = None
    trace_key: str | None = None
    trace_output_key: str | None = None

    @classmethod
    def from_parts(
        cls,
        plan: RuntimeGraphPlan,
        actions: Mapping[str, RuntimeAction],
        *,
        reducers: Mapping[str, RuntimeReducer] | None = None,
        routers: Mapping[str, RuntimeRouter] | None = None,
        input_keys: tuple[str, ...] | None = None,
        output_keys: tuple[str, ...] | None = None,
        trace_key: str | None = None,
        trace_output_key: str | None = None,
    ) -> RuntimeGraphSubgraph:
        return cls(
            RuntimeGraphExecutor(
                plan,
                actions,
                reducers=reducers,
                routers=routers,
            ),
            input_keys=input_keys,
            output_keys=output_keys,
            trace_key=trace_key,
            trace_output_key=trace_output_key,
        )

    def invoke(self, state: Mapping[str, Any]) -> dict[str, Any]:
        subgraph_state = (
            {key: state[key] for key in self.input_keys}
            if self.input_keys is not None
            else dict(state)
        )
        result, trace = self.executor.invoke_with_trace(
            subgraph_state,
            trace_key=self.trace_key,
        )
        update = (
            {key: result[key] for key in self.output_keys}
            if self.output_keys is not None
            else dict(result)
        )
        if self.trace_output_key is not None:
            update[self.trace_output_key] = trace
        return update

    def stream(self, state: Mapping[str, Any], *, stream_mode="values"):
        child_input = (
            {key: state[key] for key in self.input_keys if key in state}
            if self.input_keys is not None
            else dict(state)
        )
        for chunk in self.executor.stream(
            child_input, stream_mode=stream_mode, trace_key=self.trace_key
        ):
            yield self._project_stream_chunk(chunk)

    def stream_projection(self, state: Mapping[str, Any], *, stream_modes=None):
        from .event_stream import RuntimeGraphStreamProjection, normalize_stream_modes

        return RuntimeGraphStreamProjection.from_chunks(
            self.stream(state, stream_mode=normalize_stream_modes(stream_modes))
        )

    def _project_stream_chunk(self, chunk):
        if (
            isinstance(chunk, tuple)
            and len(chunk) == 2
            and chunk[0]
            in (
                "values",
                "updates",
                "messages",
                "custom",
                "checkpoints",
                "tasks",
                "events",
                "debug",
            )
        ):
            mode, value = chunk
            if mode == "values":
                return (mode, self._project_state(value))
            return chunk
        if isinstance(chunk, dict):
            return self._project_state(chunk)
        return chunk

    def _project_state(self, state: Mapping[str, Any]) -> dict[str, Any]:
        if self.output_keys is None:
            result = dict(state)
        else:
            result = {key: state[key] for key in self.output_keys if key in state}
        if self.trace_output_key and self.trace_key and self.trace_key in state:
            result[self.trace_output_key] = state[self.trace_key]
        return result

    def as_action(self) -> Callable[[Mapping[str, Any]], dict[str, Any]]:
        return self.invoke
