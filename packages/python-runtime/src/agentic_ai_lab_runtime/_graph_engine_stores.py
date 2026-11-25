# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Pluggable ID-indexed `TaskActorIndexStore` adapters (ZERO forced `pyturso` dependency)."""

from __future__ import annotations

import json
from collections.abc import Mapping
from pathlib import Path
from typing import Protocol, runtime_checkable

from ._graph_engine_actor_types import TaskActorIndexEntry


@runtime_checkable
class TaskActorIndexStore(Protocol):
    """Pluggable ID-indexed archive store (in-memory, JSON file, or optional Turso/Marlin)."""

    def put(self, entry: TaskActorIndexEntry) -> None: ...

    def get(self, task_id: str) -> TaskActorIndexEntry | None: ...

    def list_entries(self) -> tuple[TaskActorIndexEntry, ...]: ...


class MemoryTaskActorIndexStore:
    """Zero-dependency in-memory `TaskActorIndexStore`."""

    def __init__(self) -> None:
        self._entries: dict[str, TaskActorIndexEntry] = {}

    def put(self, entry: TaskActorIndexEntry) -> None:
        self._entries[entry.task_id] = entry

    def get(self, task_id: str) -> TaskActorIndexEntry | None:
        return self._entries.get(task_id)

    def list_entries(self) -> tuple[TaskActorIndexEntry, ...]:
        return tuple(self._entries.values())


class FileTaskActorIndexStore:
    """Pure JSON-file `TaskActorIndexStore` (zero SQLite / `pyturso` dependency)."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def _load_map(self) -> dict[str, TaskActorIndexEntry]:
        if not self.path.exists():
            return {}
        raw = json.loads(self.path.read_text(encoding="utf-8"))
        return {
            str(item["task_id"]): TaskActorIndexEntry.from_dict(item)
            for item in raw.get("entries", [])
        }

    def _save_map(self, entries: Mapping[str, TaskActorIndexEntry]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "schema": "agentic-ai-lab.graph-engine.task-actor-index.v1",
            "session_free": True,
            "entries": [entry.to_dict() for entry in entries.values()],
        }
        self.path.write_text(
            json.dumps(payload, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

    def put(self, entry: TaskActorIndexEntry) -> None:
        entries = self._load_map()
        entries[entry.task_id] = entry
        self._save_map(entries)

    def get(self, task_id: str) -> TaskActorIndexEntry | None:
        return self._load_map().get(task_id)

    def list_entries(self) -> tuple[TaskActorIndexEntry, ...]:
        return tuple(self._load_map().values())
