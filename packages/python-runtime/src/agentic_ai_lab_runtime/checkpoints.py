# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import dataclass, field
import hashlib
import pathlib
import pickle
import time
import uuid
from typing import Any, Mapping, Sequence

from .runtime_graph import (
    RuntimeGraphEvent,
    RuntimeGraphInterrupt,
    RuntimeGraphInterrupted,
)


class RuntimeGraphCheckpointError(RuntimeError):
    pass


def _assign_checkpoint_id(checkpoint: RuntimeGraphCheckpoint) -> RuntimeGraphCheckpoint:
    return RuntimeGraphCheckpoint(
        checkpoint_id=f"{time.time_ns()}-{uuid.uuid4().hex}",
        thread_id=checkpoint.thread_id,
        interrupt=checkpoint.interrupt,
        node=checkpoint.node,
        step=checkpoint.step,
        state=dict(checkpoint.state),
        trace=checkpoint.trace,
        pending=checkpoint.pending,
        events=checkpoint.events,
        validation_receipt=checkpoint.validation_receipt,
        plan_digest=checkpoint.plan_digest,
    )


@dataclass(frozen=True)
class RuntimeGraphCheckpoint:
    checkpoint_id: str
    thread_id: str
    interrupt: RuntimeGraphInterrupt | None
    node: str
    step: int
    state: Mapping[str, Any]
    trace: tuple[str, ...]
    pending: tuple[Any, ...] = ()
    events: tuple[RuntimeGraphEvent, ...] = ()
    validation_receipt: bytes = b""
    plan_digest: str | None = None

    @classmethod
    def from_interrupted(
        cls,
        thread_id: str,
        interrupted: RuntimeGraphInterrupted,
    ) -> RuntimeGraphCheckpoint:
        return cls(
            checkpoint_id="",
            thread_id=thread_id,
            interrupt=interrupted.interrupt,
            node=interrupted.node,
            step=interrupted.step,
            state=dict(interrupted.state),
            trace=tuple(interrupted.trace),
            pending=tuple(interrupted.pending),
            events=tuple(interrupted.events),
            validation_receipt=interrupted.validation_receipt,
            plan_digest=interrupted.plan_digest,
        )

    def to_interrupted(self) -> RuntimeGraphInterrupted:
        if self.interrupt is None:
            raise RuntimeGraphCheckpointError(
                "checkpoint does not contain an interrupt"
            )
        return RuntimeGraphInterrupted(
            self.interrupt,
            node=self.node,
            step=self.step,
            state=dict(self.state),
            trace=self.trace,
            pending=self.pending,
            events=self.events,
            validation_receipt=self.validation_receipt,
            plan_digest=self.plan_digest,
        )

    def with_state_update(
        self,
        update: Mapping[str, Any],
        *,
        replace: bool = False,
    ) -> RuntimeGraphCheckpoint:
        state = dict(update) if replace else {**self.state, **update}
        return RuntimeGraphCheckpoint(
            checkpoint_id="",
            thread_id=self.thread_id,
            interrupt=self.interrupt,
            node=self.node,
            step=self.step,
            state=state,
            trace=self.trace,
            pending=self.pending,
            events=self.events,
            validation_receipt=self.validation_receipt,
            plan_digest=self.plan_digest,
        )


@dataclass
class MemoryRuntimeGraphCheckpointer:
    _checkpoints: dict[str, RuntimeGraphCheckpoint] = field(default_factory=dict)
    _history: dict[str, list[RuntimeGraphCheckpoint]] = field(default_factory=dict)

    def save(self, checkpoint: RuntimeGraphCheckpoint) -> RuntimeGraphCheckpoint:
        if not checkpoint.checkpoint_id:
            checkpoint = _assign_checkpoint_id(checkpoint)
        self._checkpoints[checkpoint.thread_id] = checkpoint
        self._history.setdefault(checkpoint.thread_id, []).append(checkpoint)
        return checkpoint

    def save_interrupted(
        self,
        thread_id: str,
        interrupted: RuntimeGraphInterrupted,
    ) -> RuntimeGraphCheckpoint:
        return self.save(RuntimeGraphCheckpoint.from_interrupted(thread_id, interrupted))

    def load(self, thread_id: str) -> RuntimeGraphCheckpoint:
        try:
            return self._checkpoints[thread_id]
        except KeyError as exc:
            raise RuntimeGraphCheckpointError(
                f"missing runtime graph checkpoint: {thread_id}"
            ) from exc

    def load_interrupted(self, thread_id: str) -> RuntimeGraphInterrupted:
        return self.load(thread_id).to_interrupted()

    def load_at(self, thread_id: str, checkpoint_id: str) -> RuntimeGraphCheckpoint:
        for checkpoint in self._history.get(thread_id, ()):
            if checkpoint.checkpoint_id == checkpoint_id:
                return checkpoint
        raise RuntimeGraphCheckpointError(
            f"missing runtime graph checkpoint: {thread_id}/{checkpoint_id}"
        )

    def history(self, thread_id: str) -> tuple[RuntimeGraphCheckpoint, ...]:
        return tuple(self._history.get(thread_id, ()))

    def has(self, thread_id: str) -> bool:
        return thread_id in self._checkpoints

    def clear(self, thread_id: str) -> None:
        self._checkpoints.pop(thread_id, None)
        self._history.pop(thread_id, None)

    def inspect(self, thread_id: str) -> RuntimeGraphCheckpoint:
        return self.load(thread_id)

    def update_state(
        self,
        thread_id: str,
        update: Mapping[str, Any],
        *,
        replace: bool = False,
    ) -> RuntimeGraphCheckpoint:
        return self.save(self.load(thread_id).with_state_update(update, replace=replace))


@dataclass
class FileRuntimeGraphCheckpointer:
    root: pathlib.Path | str

    def __post_init__(self) -> None:
        self.root = pathlib.Path(self.root)
        self.root.mkdir(parents=True, exist_ok=True)

    def _path(self, thread_id: str) -> pathlib.Path:
        digest = hashlib.sha256(thread_id.encode("utf-8")).hexdigest()
        return pathlib.Path(self.root) / f"{digest}.checkpoint.pickle"

    def _history_dir(self, thread_id: str) -> pathlib.Path:
        digest = hashlib.sha256(thread_id.encode("utf-8")).hexdigest()
        return pathlib.Path(self.root) / f"{digest}.history"

    def _history_path(self, thread_id: str, checkpoint_id: str) -> pathlib.Path:
        return self._history_dir(thread_id) / f"{checkpoint_id}.checkpoint.pickle"

    def _write(self, path: pathlib.Path, checkpoint: RuntimeGraphCheckpoint) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp_path = path.with_suffix(".tmp")
        tmp_path.write_bytes(pickle.dumps(checkpoint, protocol=pickle.HIGHEST_PROTOCOL))
        tmp_path.replace(path)

    def save(self, checkpoint: RuntimeGraphCheckpoint) -> RuntimeGraphCheckpoint:
        if not checkpoint.checkpoint_id:
            checkpoint = _assign_checkpoint_id(checkpoint)
        path = self._path(checkpoint.thread_id)
        self._write(path, checkpoint)
        self._write(
            self._history_path(checkpoint.thread_id, checkpoint.checkpoint_id),
            checkpoint,
        )
        return checkpoint

    def save_interrupted(
        self,
        thread_id: str,
        interrupted: RuntimeGraphInterrupted,
    ) -> RuntimeGraphCheckpoint:
        return self.save(RuntimeGraphCheckpoint.from_interrupted(thread_id, interrupted))

    def load(self, thread_id: str) -> RuntimeGraphCheckpoint:
        path = self._path(thread_id)
        if not path.exists():
            raise RuntimeGraphCheckpointError(
                f"missing runtime graph checkpoint: {thread_id}"
            )
        checkpoint = pickle.loads(path.read_bytes())
        if not isinstance(checkpoint, RuntimeGraphCheckpoint):
            raise RuntimeGraphCheckpointError(
                f"invalid runtime graph checkpoint: {thread_id}"
            )
        return checkpoint

    def load_interrupted(self, thread_id: str) -> RuntimeGraphInterrupted:
        return self.load(thread_id).to_interrupted()

    def load_at(self, thread_id: str, checkpoint_id: str) -> RuntimeGraphCheckpoint:
        path = self._history_path(thread_id, checkpoint_id)
        if not path.exists():
            raise RuntimeGraphCheckpointError(
                f"missing runtime graph checkpoint: {thread_id}/{checkpoint_id}"
            )
        checkpoint = pickle.loads(path.read_bytes())
        if not isinstance(checkpoint, RuntimeGraphCheckpoint):
            raise RuntimeGraphCheckpointError(
                f"invalid runtime graph checkpoint: {thread_id}/{checkpoint_id}"
            )
        return checkpoint

    def history(self, thread_id: str) -> tuple[RuntimeGraphCheckpoint, ...]:
        history_dir = self._history_dir(thread_id)
        if not history_dir.exists():
            return ()
        checkpoints = []
        for path in sorted(history_dir.glob("*.checkpoint.pickle")):
            checkpoint = pickle.loads(path.read_bytes())
            if not isinstance(checkpoint, RuntimeGraphCheckpoint):
                raise RuntimeGraphCheckpointError(
                    f"invalid runtime graph checkpoint history: {thread_id}"
                )
            checkpoints.append(checkpoint)
        return tuple(checkpoints)

    def has(self, thread_id: str) -> bool:
        return self._path(thread_id).exists()

    def clear(self, thread_id: str) -> None:
        self._path(thread_id).unlink(missing_ok=True)
        history_dir = self._history_dir(thread_id)
        if history_dir.exists():
            for path in history_dir.glob("*.checkpoint.pickle"):
                path.unlink()
            history_dir.rmdir()

    def inspect(self, thread_id: str) -> RuntimeGraphCheckpoint:
        return self.load(thread_id)

    def update_state(
        self,
        thread_id: str,
        update: Mapping[str, Any],
        *,
        replace: bool = False,
    ) -> RuntimeGraphCheckpoint:
        return self.save(self.load(thread_id).with_state_update(update, replace=replace))
