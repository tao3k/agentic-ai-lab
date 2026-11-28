# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Preprojected Scheme load artifact ownership for no-Gerbil runtime loading."""

from __future__ import annotations

import hashlib
import os
from collections.abc import Mapping
from pathlib import Path
from typing import Any

from ._scheme_datum import SchemeRows, parse_scheme_datum, write_scheme_datum


SCHEME_LOAD_PROJECTION_ARTIFACT_SCHEMA = (
    "agentic-ai-lab.scheme-load-projection-artifact.v1"
)


def scheme_load_artifact_enabled() -> bool:
    value = os.environ.get("AGENTIC_AI_LAB_SCHEME_LOAD_ARTIFACT", "1").strip().lower()
    return value not in {"0", "false", "no", "off"}


def load_projection_artifact(
    module_path: Path,
    workdir: Path,
    projection_path: Path,
    cache_key: tuple[object, ...],
) -> SchemeRows | None:
    expected = _artifact_fingerprints(module_path, projection_path)
    for artifact_path in projection_artifact_candidates(
        module_path,
        workdir,
        cache_key,
    ):
        if not artifact_path.exists():
            continue
        rows = _read_artifact_rows(
            artifact_path,
            expected,
            require_projection_digest=True,
        )
        if rows is not None:
            return rows
    return None


def load_adjacent_projection_artifact(
    module_path: Path,
    projection_path: Path | None,
) -> SchemeRows | None:
    artifact_path = adjacent_projection_artifact(module_path)
    if not artifact_path.exists():
        return None
    return _read_artifact_rows(
        artifact_path,
        _artifact_fingerprints(module_path, projection_path),
        require_projection_digest=projection_path is not None,
    )


def read_projection_artifact(
    artifact_path: Path,
    *,
    module_path: Path,
    projection_path: Path,
) -> SchemeRows | None:
    return _read_artifact_rows(
        artifact_path,
        _artifact_fingerprints(module_path, projection_path),
        require_projection_digest=True,
    )


def write_projection_artifact(
    path: Path,
    *,
    module_path: Path,
    projection_path: Path,
    rows: SchemeRows,
) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    source_digest, projection_digest = _artifact_fingerprints(
        module_path,
        projection_path,
    )
    artifact = (
        ("schema", SCHEME_LOAD_PROJECTION_ARTIFACT_SCHEMA),
        ("source-digest", source_digest),
        ("projection-digest", projection_digest),
        ("rows", _artifact_rows_payload(rows)),
    )
    path.write_text(write_scheme_datum(artifact) + "\n", encoding="utf-8")
    return path


def adjacent_projection_artifact(module_path: Path) -> Path:
    return module_path.with_name(f"{module_path.name}.agentic-ai-lab-projection.sexp")


def cached_projection_artifact(
    workdir: Path,
    cache_key: tuple[object, ...],
) -> Path:
    digest = hashlib.sha256(repr(cache_key).encode("utf-8")).hexdigest()
    return (
        workdir
        / ".cache"
        / "agentic-ai-lab-runtime-projections"
        / digest[:2]
        / digest
        / "projection.sexp"
    )


def projection_artifact_candidates(
    module_path: Path,
    workdir: Path,
    cache_key: tuple[object, ...],
) -> tuple[Path, ...]:
    return (
        adjacent_projection_artifact(module_path),
        cached_projection_artifact(workdir, cache_key),
    )


def _read_artifact_rows(
    artifact_path: Path,
    expected: tuple[str, str],
    *,
    require_projection_digest: bool,
) -> SchemeRows | None:
    try:
        artifact = _rows(
            parse_scheme_datum(artifact_path.read_text(encoding="utf-8"))
        )
    except (OSError, ValueError):
        return None
    if artifact.get("schema") != SCHEME_LOAD_PROJECTION_ARTIFACT_SCHEMA:
        return None
    if artifact.get("source-digest") != expected[0]:
        return None
    if require_projection_digest and artifact.get("projection-digest") != expected[1]:
        return None
    rows = artifact.get("rows")
    if not isinstance(rows, tuple):
        return None
    return rows


def _artifact_rows_payload(rows: SchemeRows) -> tuple[Any, ...]:
    if isinstance(rows, Mapping):
        return tuple(rows.items())
    return tuple(rows)


def _artifact_fingerprints(
    module_path: Path,
    projection_path: Path | None,
) -> tuple[str, str]:
    projection_digest = "" if projection_path is None else _file_digest(projection_path)
    return (_file_digest(module_path), projection_digest)


def _file_digest(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _rows(value: Any) -> dict[str, Any]:
    rows: dict[str, Any] = {}
    for row in value:
        if not isinstance(row, (tuple, list)) or len(row) == 0:
            return {}
        key = str(row[0])
        if len(row) == 1:
            rows[key] = ()
        elif len(row) == 2:
            rows[key] = row[1]
        else:
            rows[key] = tuple(row[1:])
    return rows


__all__ = [
    "SCHEME_LOAD_PROJECTION_ARTIFACT_SCHEMA",
    "adjacent_projection_artifact",
    "cached_projection_artifact",
    "load_adjacent_projection_artifact",
    "load_projection_artifact",
    "projection_artifact_candidates",
    "read_projection_artifact",
    "scheme_load_artifact_enabled",
    "write_projection_artifact",
]
