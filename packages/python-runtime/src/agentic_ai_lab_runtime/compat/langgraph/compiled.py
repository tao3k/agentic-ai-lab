# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Compiled LangGraph facade backed by Agentic AI Lab runtime execution."""

from __future__ import annotations

import time
import uuid
from collections.abc import Iterable, Mapping
from dataclasses import dataclass, field
from typing import Any

from ...checkpoints import (
    MemoryRuntimeGraphCheckpointer,
    RuntimeGraphCheckpoint,
    RuntimeGraphCheckpointError,
)


@dataclass(frozen=True, slots=True)
class StateSnapshot:
    """LangGraph-shaped view over a runtime graph checkpoint."""

    values: Mapping[str, Any]
    config: Mapping[str, Any] = field(default_factory=dict)
    next: tuple[str, ...] = ()
    metadata: Mapping[str, Any] = field(default_factory=dict)
    checkpoint_id: str | None = None


@dataclass(frozen=True, slots=True)
class CompiledStateGraph:
    """LangGraph-style compiled graph facade."""

    executor: Any
    checkpointer: MemoryRuntimeGraphCheckpointer | None = None

    def invoke(
        self,
        input: Mapping[str, Any],
        config: Mapping[str, Any] | None = None,
        **_kwargs: Any,
    ) -> dict[str, Any]:
        thread_id = _thread_id(config)
        if self.checkpointer is not None and thread_id is not None:
            state, trace = self.executor.invoke_with_trace(dict(input))
            self.checkpointer.save(
                RuntimeGraphCheckpoint(
                    checkpoint_id=_checkpoint_id(),
                    thread_id=thread_id,
                    interrupt=None,
                    node=str(trace[-1]) if trace else "",
                    step=len(trace),
                    state=state,
                    trace=tuple(trace),
                )
            )
            return dict(state)
        return dict(self.executor.invoke(input))

    def stream(
        self,
        input: Mapping[str, Any],
        config: Mapping[str, Any] | None = None,
        *,
        stream_mode: object = "values",
        **_kwargs: Any,
    ) -> Iterable[Any]:
        thread_id = _thread_id(config)
        if self.checkpointer is not None and thread_id is not None:
            yield self.invoke(input, config)
            return
        yield from self.executor.stream(input, stream_mode=stream_mode)

    def get_state(self, config: Mapping[str, Any]) -> StateSnapshot:
        checkpoint = self._load_checkpoint(config)
        return _snapshot(checkpoint, config)

    def get_state_history(self, config: Mapping[str, Any]) -> tuple[StateSnapshot, ...]:
        checkpointer = self._require_checkpointer()
        thread_id = _require_thread_id(config)
        return tuple(_snapshot(checkpoint, config) for checkpoint in checkpointer.history(thread_id))

    def update_state(
        self,
        config: Mapping[str, Any],
        values: Mapping[str, Any],
        as_node: str | None = None,
    ) -> StateSnapshot:
        checkpointer = self._require_checkpointer()
        checkpoint = checkpointer.update_state(_require_thread_id(config), values)
        if as_node is not None:
            checkpoint = _with_node(checkpoint, as_node)
            checkpointer.save(checkpoint)
        return _snapshot(checkpoint, config)

    def _load_checkpoint(self, config: Mapping[str, Any]) -> RuntimeGraphCheckpoint:
        checkpointer = self._require_checkpointer()
        thread_id = _require_thread_id(config)
        try:
            return checkpointer.load(thread_id)
        except RuntimeGraphCheckpointError:
            return RuntimeGraphCheckpoint(
                checkpoint_id="",
                thread_id=thread_id,
                interrupt=None,
                node="",
                step=0,
                state={},
                trace=(),
            )

    def _require_checkpointer(self) -> MemoryRuntimeGraphCheckpointer:
        if self.checkpointer is None:
            raise ValueError("LangGraph state access requires compile(checkpointer=...)")
        return self.checkpointer


def _thread_id(config: Mapping[str, Any] | None) -> str | None:
    if config is None:
        return None
    configurable = config.get("configurable")
    if isinstance(configurable, Mapping):
        value = configurable.get("thread_id")
        if value is not None:
            return str(value)
    value = config.get("thread_id")
    return None if value is None else str(value)


def _require_thread_id(config: Mapping[str, Any]) -> str:
    thread_id = _thread_id(config)
    if thread_id is None:
        raise ValueError("LangGraph state access requires config.configurable.thread_id")
    return thread_id


def _snapshot(
    checkpoint: RuntimeGraphCheckpoint,
    config: Mapping[str, Any],
) -> StateSnapshot:
    return StateSnapshot(
        values=checkpoint.state,
        config=config,
        next=tuple(str(item) for item in checkpoint.pending),
        metadata={
            "node": checkpoint.node,
            "step": checkpoint.step,
            "trace": checkpoint.trace,
            "plan_digest": checkpoint.plan_digest,
        },
        checkpoint_id=checkpoint.checkpoint_id or None,
    )


def _with_node(
    checkpoint: RuntimeGraphCheckpoint,
    node: str,
) -> RuntimeGraphCheckpoint:
    return RuntimeGraphCheckpoint(
        checkpoint_id=checkpoint.checkpoint_id,
        thread_id=checkpoint.thread_id,
        interrupt=checkpoint.interrupt,
        node=node,
        step=checkpoint.step,
        state=checkpoint.state,
        trace=checkpoint.trace,
        pending=checkpoint.pending,
        events=checkpoint.events,
        validation_receipt=checkpoint.validation_receipt,
        plan_digest=checkpoint.plan_digest,
    )


def _checkpoint_id() -> str:
    return f"{time.time_ns()}-{uuid.uuid4().hex}"
