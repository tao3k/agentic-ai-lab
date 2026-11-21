# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any, Iterator

from ._runtime_graph_context import GraphRunContext
from ._runtime_graph_types import RuntimeGraphError
from .runtime import RuntimeGraphRuntime

_CUSTOM_STREAM_KEY = "_agentic_ai_lab_runtime_custom_stream"
_VALID_STREAM_MODES = (
    "values",
    "updates",
    "messages",
    "custom",
    "checkpoints",
    "tasks",
    "events",
    "debug",
)


class StreamPublisher:
    def __init__(
        self,
        executor,
        modes: tuple[str, ...],
        multi_mode: bool,
        context: GraphRunContext,
    ) -> None:
        self.executor = executor
        self.modes = modes
        self.multi_mode = multi_mode
        self.custom_values: list[Any] = []
        self._custom_restore = _install_custom_sink(executor.runtime, self.custom_values)
        self._checkpoint_thread_id = _checkpoint_thread_id(executor.runtime, modes)
        self._checkpoint_store = _checkpoint_store(executor.runtime, modes)

    def __del__(self) -> None:
        self._custom_restore()

    def emit(self, mode: str, chunk: Any) -> Any:
        if self.multi_mode:
            return (mode, chunk)
        return chunk

    def events(self, event) -> Iterator[Any]:
        for mode in self.modes:
            if mode in {"events", "debug"}:
                yield self.emit(mode, event)

    def tasks(self, node: str, step: int, status: str) -> Iterator[Any]:
        for mode in self.modes:
            if mode == "tasks":
                yield self.emit(mode, {"node": node, "step": step, "status": status})

    def node_outputs(
        self,
        node: str,
        context: GraphRunContext,
        update: Mapping[str, Any] | None,
        custom_start: int,
    ) -> Iterator[Any]:
        yield from self.custom(custom_start)
        yield from self.checkpoints(node, context)
        yield from self.updates(node, update)
        yield from self.values(context.state)
        yield from self.messages(node, context.step, update)

    def custom(self, start: int) -> Iterator[Any]:
        for value in self.custom_values[start:]:
            for mode in self.modes:
                if mode == "custom":
                    yield self.emit(mode, value)

    def updates(self, node: str, update: Mapping[str, Any] | None) -> Iterator[Any]:
        for mode in self.modes:
            if mode == "updates":
                yield self.emit(mode, {node: dict(update or {})})

    def values(self, state: Mapping[str, Any]) -> Iterator[Any]:
        for mode in self.modes:
            if mode == "values":
                yield self.emit(mode, dict(state))

    def messages(
        self, node: str, step: int, update: Mapping[str, Any] | None
    ) -> Iterator[Any]:
        if not update or not hasattr(update, "get"):
            return
        value = update.get("messages")
        if value is None:
            return
        for message in _normalize_messages(value):
            metadata = {"node": node, "step": step}
            for mode in self.modes:
                if mode == "messages":
                    yield self.emit(mode, (message, metadata))

    def checkpoints(self, node: str, context: GraphRunContext) -> Iterator[Any]:
        if self._checkpoint_thread_id is None or self._checkpoint_store is None:
            return
        from .checkpoints import RuntimeGraphCheckpoint

        checkpoint = self._checkpoint_store.save(
            RuntimeGraphCheckpoint(
                checkpoint_id="",
                thread_id=self._checkpoint_thread_id,
                interrupt=None,
                node=node,
                step=context.step,
                state=dict(context.state),
                trace=tuple(context.trace),
                pending=tuple(context.pending),
                events=tuple(context.events),
            )
        )
        for mode in self.modes:
            if mode == "checkpoints":
                yield self.emit(mode, checkpoint)


def validated_stream_modes(stream_mode: str | Sequence[str]) -> tuple[str, ...]:
    modes = (stream_mode,) if isinstance(stream_mode, str) else tuple(stream_mode)
    if not modes:
        raise RuntimeGraphError("runtime graph stream mode cannot be empty")
    unknown = tuple(mode for mode in modes if mode not in _VALID_STREAM_MODES)
    if unknown:
        raise RuntimeGraphError("unknown runtime graph stream mode: " + ", ".join(unknown))
    return modes


def _normalize_messages(value: Any) -> Sequence[Any]:
    if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray, dict)):
        return value
    return (value,)


def _checkpoint_thread_id(runtime: RuntimeGraphRuntime, modes: tuple[str, ...]) -> str | None:
    if "checkpoints" not in modes:
        return None
    return runtime.require_thread_id()


def _checkpoint_store(runtime: RuntimeGraphRuntime, modes: tuple[str, ...]) -> Any:
    if "checkpoints" not in modes:
        return None
    return runtime.require_checkpointer()


def _install_custom_sink(runtime: RuntimeGraphRuntime, values: list[Any]):
    metadata = runtime.metadata
    missing = object()
    previous = metadata.get(_CUSTOM_STREAM_KEY, missing)
    metadata[_CUSTOM_STREAM_KEY] = values.append

    def restore() -> None:
        if previous is missing:
            metadata.pop(_CUSTOM_STREAM_KEY, None)
        else:
            metadata[_CUSTOM_STREAM_KEY] = previous

    return restore


__all__ = ["StreamPublisher", "validated_stream_modes"]
