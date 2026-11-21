# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import dataclass, field
import hashlib
import pathlib
import pickle
import time
from typing import Any, Iterable


Namespace = tuple[str, ...]


class RuntimeGraphStoreError(RuntimeError):
    pass


@dataclass(frozen=True)
class RuntimeGraphStoreItem:
    namespace: Namespace
    key: str
    value: Any
    created_at: int
    updated_at: int


def _normalize_namespace(namespace: Iterable[str]) -> Namespace:
    normalized = tuple(namespace)
    if not normalized:
        raise RuntimeGraphStoreError("runtime graph store namespace must not be empty")
    if any(not part for part in normalized):
        raise RuntimeGraphStoreError("runtime graph store namespace parts must be non-empty")
    return normalized


def _now_ns() -> int:
    return time.time_ns()


@dataclass
class MemoryRuntimeGraphStore:
    _items: dict[tuple[Namespace, str], RuntimeGraphStoreItem] = field(
        default_factory=dict
    )

    def put(
        self,
        namespace: Iterable[str],
        key: str,
        value: Any,
    ) -> RuntimeGraphStoreItem:
        namespace = _normalize_namespace(namespace)
        if not key:
            raise RuntimeGraphStoreError("runtime graph store key must not be empty")
        now = _now_ns()
        previous = self._items.get((namespace, key))
        item = RuntimeGraphStoreItem(
            namespace=namespace,
            key=key,
            value=value,
            created_at=previous.created_at if previous else now,
            updated_at=now,
        )
        self._items[(namespace, key)] = item
        return item

    def get(self, namespace: Iterable[str], key: str) -> RuntimeGraphStoreItem | None:
        return self._items.get((_normalize_namespace(namespace), key))

    def delete(self, namespace: Iterable[str], key: str) -> None:
        self._items.pop((_normalize_namespace(namespace), key), None)

    def list(self, namespace: Iterable[str]) -> tuple[RuntimeGraphStoreItem, ...]:
        namespace = _normalize_namespace(namespace)
        return tuple(
            item
            for (item_namespace, _), item in sorted(self._items.items())
            if item_namespace == namespace
        )

    def search(self, namespace_prefix: Iterable[str]) -> tuple[RuntimeGraphStoreItem, ...]:
        namespace_prefix = _normalize_namespace(namespace_prefix)
        return tuple(
            item
            for (item_namespace, _), item in sorted(self._items.items())
            if item_namespace[: len(namespace_prefix)] == namespace_prefix
        )


@dataclass
class FileRuntimeGraphStore:
    root: pathlib.Path | str

    def __post_init__(self) -> None:
        self.root = pathlib.Path(self.root)
        self.root.mkdir(parents=True, exist_ok=True)

    def _namespace_dir(self, namespace: Namespace) -> pathlib.Path:
        digest = hashlib.sha256("\0".join(namespace).encode("utf-8")).hexdigest()
        return pathlib.Path(self.root) / digest

    def _path(self, namespace: Namespace, key: str) -> pathlib.Path:
        digest = hashlib.sha256(key.encode("utf-8")).hexdigest()
        return self._namespace_dir(namespace) / f"{digest}.store.pickle"

    def put(
        self,
        namespace: Iterable[str],
        key: str,
        value: Any,
    ) -> RuntimeGraphStoreItem:
        namespace = _normalize_namespace(namespace)
        if not key:
            raise RuntimeGraphStoreError("runtime graph store key must not be empty")
        previous = self.get(namespace, key)
        now = _now_ns()
        item = RuntimeGraphStoreItem(
            namespace=namespace,
            key=key,
            value=value,
            created_at=previous.created_at if previous else now,
            updated_at=now,
        )
        path = self._path(namespace, key)
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp_path = path.with_suffix(".tmp")
        tmp_path.write_bytes(pickle.dumps(item, protocol=pickle.HIGHEST_PROTOCOL))
        tmp_path.replace(path)
        return item

    def get(self, namespace: Iterable[str], key: str) -> RuntimeGraphStoreItem | None:
        namespace = _normalize_namespace(namespace)
        path = self._path(namespace, key)
        if not path.exists():
            return None
        item = pickle.loads(path.read_bytes())
        if not isinstance(item, RuntimeGraphStoreItem):
            raise RuntimeGraphStoreError("invalid runtime graph store item")
        return item

    def delete(self, namespace: Iterable[str], key: str) -> None:
        namespace = _normalize_namespace(namespace)
        self._path(namespace, key).unlink(missing_ok=True)

    def list(self, namespace: Iterable[str]) -> tuple[RuntimeGraphStoreItem, ...]:
        namespace = _normalize_namespace(namespace)
        namespace_dir = self._namespace_dir(namespace)
        if not namespace_dir.exists():
            return ()
        return tuple(
            self._load_item(path)
            for path in sorted(namespace_dir.glob("*.store.pickle"))
        )

    def search(self, namespace_prefix: Iterable[str]) -> tuple[RuntimeGraphStoreItem, ...]:
        namespace_prefix = _normalize_namespace(namespace_prefix)
        items = []
        for path in sorted(pathlib.Path(self.root).glob("*/*.store.pickle")):
            item = self._load_item(path)
            if item.namespace[: len(namespace_prefix)] == namespace_prefix:
                items.append(item)
        return tuple(items)

    def _load_item(self, path: pathlib.Path) -> RuntimeGraphStoreItem:
        item = pickle.loads(path.read_bytes())
        if not isinstance(item, RuntimeGraphStoreItem):
            raise RuntimeGraphStoreError("invalid runtime graph store item")
        return item
