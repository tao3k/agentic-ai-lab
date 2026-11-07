# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Iterable, Iterator, Sequence


DEFAULT_RUNTIME_GRAPH_STREAM_MODES = (
    "values",
    "updates",
    "messages",
    "custom",
    "tasks",
    "events",
    "debug",
)


@dataclass(frozen=True)
class RuntimeGraphStreamProjection:
    chunks: tuple[tuple[str, Any], ...]

    @classmethod
    def from_chunks(
        cls, chunks: Iterable[tuple[str, Any]]
    ) -> "RuntimeGraphStreamProjection":
        return cls(tuple((mode, chunk) for mode, chunk in chunks))

    def __iter__(self) -> Iterator[tuple[str, Any]]:
        return iter(self.chunks)

    def modes(self) -> tuple[str, ...]:
        return tuple(dict.fromkeys(mode for mode, _chunk in self.chunks))

    def iter_mode(self, mode: str) -> Iterator[Any]:
        return (chunk for chunk_mode, chunk in self.chunks if chunk_mode == mode)

    def values(self) -> Iterator[Any]:
        return self.iter_mode("values")

    def updates(self) -> Iterator[Any]:
        return self.iter_mode("updates")

    def messages(self) -> Iterator[Any]:
        return self.iter_mode("messages")

    def custom(self) -> Iterator[Any]:
        return self.iter_mode("custom")

    def checkpoints(self) -> Iterator[Any]:
        return self.iter_mode("checkpoints")

    def tasks(self) -> Iterator[Any]:
        return self.iter_mode("tasks")

    def events(self) -> Iterator[Any]:
        return self.iter_mode("events")

    def debug(self) -> Iterator[Any]:
        return self.iter_mode("debug")


def normalize_stream_modes(modes: str | Sequence[str] | None) -> tuple[str, ...]:
    if modes is None:
        return DEFAULT_RUNTIME_GRAPH_STREAM_MODES
    if isinstance(modes, str):
        return (modes,)
    return tuple(modes)
