# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Turso-backed durable stores and checkpoints for runtime graph state."""

from __future__ import annotations

import json
import pickle
import time
import uuid
from collections.abc import Iterable, Mapping
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any

from .checkpoints import RuntimeGraphCheckpoint, RuntimeGraphCheckpointError
from .durable_policy import (
    RuntimeDurablePolicyError,
    RuntimeDurablePolicyManifest,
    coerce_runtime_durable_policy_manifest,
)
from .durable_turso_backend import (
    connect_turso_runtime_graph,
    turso_runtime_graph_backend,
    validate_turso_backend_requirements,
)
from .stores import RuntimeGraphStoreError, RuntimeGraphStoreItem

Namespace = tuple[str, ...]


@dataclass
class TursoRuntimeGraphStore:
    database: str | Path = ":memory:"
    policy: RuntimeDurablePolicyManifest | Mapping[str, Any] | bytes | None = None

    def __post_init__(self) -> None:
        self.policy = coerce_runtime_durable_policy_manifest(self.policy)
        self.backend = turso_runtime_graph_backend(self.database)
        validate_turso_backend_requirements(self.policy.backend, self.backend)
        self._conn = connect_turso_runtime_graph(self.database)
        self._conn.execute(
            "create table if not exists runtime_store ("
            "namespace text not null, "
            "key text not null, "
            "value blob not null, "
            "created_at integer not null, "
            "updated_at integer not null, "
            "primary key (namespace, key))"
        )
        self._conn.commit()

    def put(
        self, namespace: Iterable[str], key: str, value: Any
    ) -> RuntimeGraphStoreItem:
        ns = _namespace(namespace)
        encoded = _encode(ns)
        payload = pickle.dumps(value)
        now = time.time_ns()
        existing = self.get(ns, key)
        created_at = existing.created_at if existing else now
        self._conn.execute(
            "insert or replace into runtime_store "
            "(namespace, key, value, created_at, updated_at) values (?, ?, ?, ?, ?)",
            (encoded, key, payload, created_at, now),
        )
        self._conn.commit()
        return RuntimeGraphStoreItem(ns, key, value, created_at, now)

    async def aput(
        self, namespace: Iterable[str], key: str, value: Any
    ) -> RuntimeGraphStoreItem:
        from ._anyio_runtime import run_blocking

        return await run_blocking(self.put, tuple(namespace), key, value)

    def get(self, namespace: Iterable[str], key: str) -> RuntimeGraphStoreItem | None:
        row = self._conn.execute(
            "select value, created_at, updated_at from runtime_store "
            "where namespace = ? and key = ?",
            (_encode(_namespace(namespace)), key),
        ).fetchone()
        if row is None:
            return None
        value, created_at, updated_at = row
        return RuntimeGraphStoreItem(
            _namespace(namespace), key, pickle.loads(value), created_at, updated_at
        )

    async def aget(
        self, namespace: Iterable[str], key: str
    ) -> RuntimeGraphStoreItem | None:
        from ._anyio_runtime import run_blocking

        return await run_blocking(self.get, tuple(namespace), key)

    def delete(self, namespace: Iterable[str], key: str) -> None:
        self._conn.execute(
            "delete from runtime_store where namespace = ? and key = ?",
            (_encode(_namespace(namespace)), key),
        )
        self._conn.commit()

    async def adelete(self, namespace: Iterable[str], key: str) -> None:
        from ._anyio_runtime import run_blocking

        await run_blocking(self.delete, tuple(namespace), key)

    def list(self, namespace: Iterable[str]) -> tuple[RuntimeGraphStoreItem, ...]:
        return self._select_items(
            "select namespace, key, value, created_at, updated_at from runtime_store "
            "where namespace = ? order by key",
            (_encode(_namespace(namespace)),),
        )

    async def alist(
        self, namespace: Iterable[str]
    ) -> tuple[RuntimeGraphStoreItem, ...]:
        from ._anyio_runtime import run_blocking

        return await run_blocking(self.list, tuple(namespace))

    def search(
        self, namespace_prefix: Iterable[str]
    ) -> tuple[RuntimeGraphStoreItem, ...]:
        prefix = _encode(_namespace(namespace_prefix))
        return self._select_items(
            "select namespace, key, value, created_at, updated_at from runtime_store "
            "where namespace = ? or namespace like ? order by namespace, key",
            (prefix, prefix[:-1] + ',%'),
        )

    async def asearch(
        self, namespace_prefix: Iterable[str]
    ) -> tuple[RuntimeGraphStoreItem, ...]:
        from ._anyio_runtime import run_blocking

        return await run_blocking(self.search, tuple(namespace_prefix))

    def _select_items(
        self, query: str, params: tuple[Any, ...]
    ) -> tuple[RuntimeGraphStoreItem, ...]:
        rows = self._conn.execute(query, params).fetchall()
        return tuple(
            RuntimeGraphStoreItem(
                _decode(namespace), key, pickle.loads(value), created_at, updated_at
            )
            for namespace, key, value, created_at, updated_at in rows
        )


@dataclass
class TursoRuntimeGraphCheckpointer:
    database: str | Path = ":memory:"
    policy: RuntimeDurablePolicyManifest | Mapping[str, Any] | bytes | None = None

    def __post_init__(self) -> None:
        self.policy = coerce_runtime_durable_policy_manifest(self.policy)
        self.backend = turso_runtime_graph_backend(self.database)
        validate_turso_backend_requirements(self.policy.backend, self.backend)
        self._conn = connect_turso_runtime_graph(self.database)
        self._conn.execute(
            "create table if not exists runtime_checkpoints ("
            "thread_id text not null, "
            "checkpoint_id text not null, "
            "payload blob not null, "
            "created_at integer not null, "
            "primary key (thread_id, checkpoint_id))"
        )
        self._conn.execute(
            "create table if not exists runtime_checkpoint_heads ("
            "thread_id text primary key, "
            "checkpoint_id text not null)"
        )
        self._conn.commit()

    def save(self, checkpoint: RuntimeGraphCheckpoint) -> RuntimeGraphCheckpoint:
        current = checkpoint
        if not current.checkpoint_id:
            if self.policy.checkpoint_id_strategy == "provided":
                raise RuntimeDurablePolicyError(
                    "checkpoint_id is required by durable policy"
                )
            current = replace(current, checkpoint_id=_checkpoint_id())
        payload = pickle.dumps(current)
        now = time.time_ns()
        self._conn.execute(
            "insert or replace into runtime_checkpoints "
            "(thread_id, checkpoint_id, payload, created_at) values (?, ?, ?, ?)",
            (current.thread_id, current.checkpoint_id, payload, now),
        )
        self._conn.execute(
            "insert or replace into runtime_checkpoint_heads "
            "(thread_id, checkpoint_id) values (?, ?)",
            (current.thread_id, current.checkpoint_id),
        )
        self._conn.commit()
        self._enforce_retention(current.thread_id)
        return current

    async def asave(
        self, checkpoint: RuntimeGraphCheckpoint
    ) -> RuntimeGraphCheckpoint:
        from ._anyio_runtime import run_blocking

        return await run_blocking(self.save, checkpoint)

    def save_interrupted(
        self, thread_id: str, interrupted
    ) -> RuntimeGraphCheckpoint:
        return self.save(
            RuntimeGraphCheckpoint(
                checkpoint_id="",
                thread_id=thread_id,
                interrupt=interrupted.interrupt,
                node=interrupted.node,
                step=interrupted.step,
                state=interrupted.state,
                trace=tuple(interrupted.trace),
                pending=tuple(interrupted.pending),
                events=tuple(interrupted.events),
                validation_receipt=interrupted.validation_receipt,
                plan_digest=interrupted.plan_digest,
            )
        )

    async def asave_interrupted(
        self, thread_id: str, interrupted
    ) -> RuntimeGraphCheckpoint:
        from ._anyio_runtime import run_blocking

        return await run_blocking(self.save_interrupted, thread_id, interrupted)

    def has(self, thread_id: str) -> bool:
        row = self._conn.execute(
            "select 1 from runtime_checkpoint_heads where thread_id = ?",
            (thread_id,),
        ).fetchone()
        return row is not None

    async def ahas(self, thread_id: str) -> bool:
        from ._anyio_runtime import run_blocking

        return await run_blocking(self.has, thread_id)

    def load(self, thread_id: str) -> RuntimeGraphCheckpoint:
        return self.inspect(thread_id)

    async def aload(self, thread_id: str) -> RuntimeGraphCheckpoint:
        from ._anyio_runtime import run_blocking

        return await run_blocking(self.load, thread_id)

    def inspect(self, thread_id: str) -> RuntimeGraphCheckpoint:
        row = self._conn.execute(
            "select checkpoint_id from runtime_checkpoint_heads where thread_id = ?",
            (thread_id,),
        ).fetchone()
        if row is None:
            raise RuntimeGraphCheckpointError(f"missing checkpoint for thread {thread_id}")
        return self.load_at(thread_id, row[0])

    async def ainspect(self, thread_id: str) -> RuntimeGraphCheckpoint:
        from ._anyio_runtime import run_blocking

        return await run_blocking(self.inspect, thread_id)

    def load_at(self, thread_id: str, checkpoint_id: str) -> RuntimeGraphCheckpoint:
        row = self._conn.execute(
            "select payload from runtime_checkpoints "
            "where thread_id = ? and checkpoint_id = ?",
            (thread_id, checkpoint_id),
        ).fetchone()
        if row is None:
            raise RuntimeGraphCheckpointError(
                f"missing checkpoint {checkpoint_id} for thread {thread_id}"
            )
        return pickle.loads(row[0])

    async def aload_at(
        self, thread_id: str, checkpoint_id: str
    ) -> RuntimeGraphCheckpoint:
        from ._anyio_runtime import run_blocking

        return await run_blocking(self.load_at, thread_id, checkpoint_id)

    def load_interrupted(self, thread_id: str):
        return self.inspect(thread_id).to_interrupted()

    async def aload_interrupted(self, thread_id: str):
        from ._anyio_runtime import run_blocking

        return await run_blocking(self.load_interrupted, thread_id)

    def update_state(
        self,
        thread_id: str,
        update: Mapping[str, Any],
        *,
        replace: bool = False,
    ) -> RuntimeGraphCheckpoint:
        return self.save(self.inspect(thread_id).with_state_update(update, replace=replace))

    async def aupdate_state(
        self,
        thread_id: str,
        update: Mapping[str, Any],
        *,
        replace: bool = False,
    ) -> RuntimeGraphCheckpoint:
        from ._anyio_runtime import run_blocking

        return await run_blocking(
            self.update_state, thread_id, update, replace=replace
        )

    def history(self, thread_id: str) -> tuple[RuntimeGraphCheckpoint, ...]:
        rows = self._conn.execute(
            "select payload from runtime_checkpoints "
            "where thread_id = ? order by checkpoint_id",
            (thread_id,),
        ).fetchall()
        return tuple(pickle.loads(row[0]) for row in rows)

    async def ahistory(self, thread_id: str) -> tuple[RuntimeGraphCheckpoint, ...]:
        from ._anyio_runtime import run_blocking

        return await run_blocking(self.history, thread_id)

    def clear(self, thread_id: str) -> None:
        self._conn.execute(
            "delete from runtime_checkpoint_heads where thread_id = ?",
            (thread_id,),
        )
        self._conn.execute(
            "delete from runtime_checkpoints where thread_id = ?",
            (thread_id,),
        )
        self._conn.commit()

    async def aclear(self, thread_id: str) -> None:
        from ._anyio_runtime import run_blocking

        await run_blocking(self.clear, thread_id)

    def _enforce_retention(self, thread_id: str) -> None:
        limit = self.policy.history_retention_limit
        if limit is None:
            return
        rows = self._conn.execute(
            "select checkpoint_id from runtime_checkpoints "
            "where thread_id = ? order by created_at desc, checkpoint_id desc",
            (thread_id,),
        ).fetchall()
        expired = rows[limit:]
        for row in expired:
            self._conn.execute(
                "delete from runtime_checkpoints "
                "where thread_id = ? and checkpoint_id = ?",
                (thread_id, row[0]),
            )
        self._conn.commit()


def _namespace(namespace: Iterable[str]) -> Namespace:
    return tuple(namespace)


def _encode(namespace: Namespace) -> str:
    return json.dumps(namespace, separators=(",", ":"))


def _decode(value: str) -> Namespace:
    return tuple(json.loads(value))


def _checkpoint_id() -> str:
    return f"{time.time_ns()}-{uuid.uuid4().hex}"


__all__ = ["TursoRuntimeGraphCheckpointer", "TursoRuntimeGraphStore"]
