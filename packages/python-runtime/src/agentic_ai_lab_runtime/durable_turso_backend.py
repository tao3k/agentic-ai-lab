# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Turso driver capability metadata for durable runtime adapters."""

from __future__ import annotations

from dataclasses import dataclass
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path
from typing import Any

from .durable_policy import RuntimeDurablePolicyError

TURSO_RUNTIME_DRIVER = "turso"
TURSO_RUNTIME_DRIVER_PACKAGE = "pyturso"


def _load_turso() -> Any:
    try:
        import turso
    except ModuleNotFoundError as exc:
        raise RuntimeDurablePolicyError(
            "Turso durable backend requires the optional 'pyturso' package"
        ) from exc
    return turso


@dataclass(frozen=True)
class TursoRuntimeGraphBackend:
    driver: str
    driver_package: str
    driver_version: str
    connection_module: str
    database: str
    concurrent_writes: bool = True
    sync_model: str = "local-first-push-pull"
    ai_vector_search: bool = True
    vector_index: str = "libsql_vector_idx"
    vector_query: str = "vector_top_k"

    def receipt_fields(self) -> dict[str, str]:
        return {
            "driver": self.driver,
            "driver-package": self.driver_package,
            "driver-version": self.driver_version,
            "connection-module": self.connection_module,
            "concurrent-writes": str(self.concurrent_writes).lower(),
            "sync-model": self.sync_model,
            "ai-vector-search": str(self.ai_vector_search).lower(),
            "vector-index": self.vector_index,
            "vector-query": self.vector_query,
        }


def turso_runtime_graph_backend(
    database: str | Path = ":memory:",
) -> TursoRuntimeGraphBackend:
    turso = _load_turso()
    try:
        driver_version = version(TURSO_RUNTIME_DRIVER_PACKAGE)
    except PackageNotFoundError:
        driver_version = "unknown"
    return TursoRuntimeGraphBackend(
        driver=TURSO_RUNTIME_DRIVER,
        driver_package=TURSO_RUNTIME_DRIVER_PACKAGE,
        driver_version=driver_version,
        connection_module=turso.__name__,
        database=str(database),
    )


def connect_turso_runtime_graph(database: str | Path):
    turso = _load_turso()
    return turso.connect(str(database))


def validate_turso_backend_requirements(
    requirements: object,
    backend: TursoRuntimeGraphBackend,
) -> None:
    if not isinstance(requirements, dict) or not requirements:
        return
    expected_driver = requirements.get("driver")
    if expected_driver and str(expected_driver) != backend.driver:
        raise RuntimeDurablePolicyError(
            f"durable backend requires driver {expected_driver!r}, got {backend.driver!r}"
        )
    expected_sync_model = requirements.get("sync-model")
    if expected_sync_model and str(expected_sync_model) != backend.sync_model:
        raise RuntimeDurablePolicyError(
            "durable backend requires sync-model "
            f"{expected_sync_model!r}, got {backend.sync_model!r}"
        )
    expected_vector_index = requirements.get("vector-index")
    if expected_vector_index and str(expected_vector_index) != backend.vector_index:
        raise RuntimeDurablePolicyError(
            "durable backend requires vector-index "
            f"{expected_vector_index!r}, got {backend.vector_index!r}"
        )
    expected_vector_query = requirements.get("vector-query")
    if expected_vector_query and str(expected_vector_query) != backend.vector_query:
        raise RuntimeDurablePolicyError(
            "durable backend requires vector-query "
            f"{expected_vector_query!r}, got {backend.vector_query!r}"
        )
    for field, actual in (
        ("concurrent-writes", backend.concurrent_writes),
        ("ai-vector-search", backend.ai_vector_search),
    ):
        if _require_true(requirements.get(field)) and not actual:
            raise RuntimeDurablePolicyError(
                f"durable backend requires {field}, but Turso capability is false"
            )


def _require_true(value: object) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on"}
    return bool(value)
