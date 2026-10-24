# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Python-facing loader for Scheme user-interface fragments."""

from __future__ import annotations

import subprocess
from collections.abc import Mapping
from pathlib import Path

from ._scheme_datum import SchemeRows, parse_scheme_datum
from ._funflow_scheme_projection import funflow_projection_from_scheme_plan
from ._funflow_types import FunFlowPlanProjection, FunFlowStepAction
from ._scheme_load_aot import (
    build_aot_projection,
    run_aot_projection,
    scheme_aot_artifact,
    scheme_load_aot_compile_enabled,
    scheme_load_aot_enabled,
)
from ._scheme_load_artifact import (
    adjacent_projection_artifact,
    load_adjacent_projection_artifact,
    load_projection_artifact,
    read_projection_artifact,
    scheme_load_artifact_enabled,
    write_projection_artifact,
)
from ._scheme_load_cache import (
    clear_load_cache,
    get_cached_projection_rows,
    scheme_load_cache_enabled,
    scheme_load_cache_key,
    store_cached_projection_rows,
)
from ._scheme_load_runner import (
    aot_runner_source,
    find_runtime_projection_source,
    run_scheme_projection,
    runtime_projection_source,
)


def load(
    path: str | Path,
    *,
    actions: Mapping[str, FunFlowStepAction],
    cwd: str | Path | None = None,
    cache: bool = True,
    projection_artifact: bool = True,
    aot: bool = True,
    compile_aot: bool = False,
) -> FunFlowPlanProjection:
    """Load a Scheme user fragment through the public `use-module` surface."""

    rows = load_projection_rows(
        path,
        cwd=cwd,
        cache=cache,
        projection_artifact=projection_artifact,
        aot=aot,
        compile_aot=compile_aot,
    )
    return funflow_projection_from_scheme_plan(rows, actions)


def load_projection_rows(
    path: str | Path,
    *,
    cwd: str | Path | None = None,
    cache: bool = True,
    projection_artifact: bool = True,
    aot: bool = True,
    compile_aot: bool = False,
) -> SchemeRows:
    """Return runtime projection rows emitted by Scheme `load` plumbing."""

    module_path = Path(path).expanduser().resolve()
    workdir = Path(cwd).expanduser().resolve() if cwd is not None else Path.cwd()
    projection_path = find_runtime_projection_source(workdir)
    if projection_path is None:
        if projection_artifact and scheme_load_artifact_enabled():
            rows = load_adjacent_projection_artifact(module_path, None)
            if rows is not None:
                return rows
        projection_path = runtime_projection_source(workdir)
    cache_key = scheme_load_cache_key(module_path, workdir, projection_path)
    if cache and scheme_load_cache_enabled():
        cached_rows = get_cached_projection_rows(cache_key)
        if cached_rows is not None:
            return cached_rows
    if projection_artifact and scheme_load_artifact_enabled():
        rows = load_projection_artifact(
            module_path,
            workdir,
            projection_path,
            cache_key,
        )
        if rows is not None:
            if cache and scheme_load_cache_enabled():
                store_cached_projection_rows(cache_key, rows)
            return rows
    rows = _load_aot_projection_rows(
        module_path,
        workdir,
        projection_path,
        cache_key,
        aot=aot,
        compile_aot=compile_aot,
    )
    if rows is not None:
        if cache and scheme_load_cache_enabled():
            store_cached_projection_rows(cache_key, rows)
        return rows
    rows = _load_projection_rows_uncached(module_path, workdir, projection_path)
    if cache and scheme_load_cache_enabled():
        store_cached_projection_rows(cache_key, rows)
    return rows


def precompile_load(
    path: str | Path,
    *,
    cwd: str | Path | None = None,
    force: bool = False,
) -> Path:
    """Compile a Scheme user fragment into a reusable Gerbil AOT runner."""

    module_path = Path(path).expanduser().resolve()
    workdir = Path(cwd).expanduser().resolve() if cwd is not None else Path.cwd()
    projection_path = runtime_projection_source(workdir)
    cache_key = scheme_load_cache_key(module_path, workdir, projection_path)
    artifact = scheme_aot_artifact(workdir, cache_key)
    if force or not artifact.binary.exists():
        build_aot_projection(
            workdir,
            cache_key,
            aot_runner_source(module_path, projection_path),
        )
    return artifact.binary


def preproject_load(
    path: str | Path,
    *,
    cwd: str | Path | None = None,
    output: str | Path | None = None,
    force: bool = False,
) -> Path:
    """Export a Scheme user fragment as a no-Gerbil projection artifact."""

    module_path = Path(path).expanduser().resolve()
    workdir = Path(cwd).expanduser().resolve() if cwd is not None else Path.cwd()
    projection_path = runtime_projection_source(workdir)
    artifact_path = (
        Path(output).expanduser().resolve()
        if output is not None
        else adjacent_projection_artifact(module_path)
    )
    if not force and artifact_path.exists():
        rows = read_projection_artifact(
            artifact_path,
            module_path=module_path,
            projection_path=projection_path,
        )
        if rows is not None:
            return artifact_path
    rows = load_projection_rows(
        module_path,
        cwd=workdir,
        cache=False,
        projection_artifact=False,
    )
    return write_projection_artifact(
        artifact_path,
        module_path=module_path,
        projection_path=projection_path,
        rows=rows,
    )


def _load_aot_projection_rows(
    module_path: Path,
    workdir: Path,
    projection_path: Path,
    cache_key: tuple[object, ...],
    *,
    aot: bool,
    compile_aot: bool,
) -> SchemeRows | None:
    if not (aot and scheme_load_aot_enabled()):
        return None
    should_compile = compile_aot or scheme_load_aot_compile_enabled()
    if should_compile:
        build_aot_projection(
            workdir,
            cache_key,
            aot_runner_source(module_path, projection_path),
        )
    try:
        result = run_aot_projection(workdir, cache_key)
    except subprocess.CalledProcessError as exc:
        if should_compile:
            detail = (exc.stderr or exc.stdout or "").strip()
            raise RuntimeError(
                f"Scheme AOT runner failed for {module_path}: {detail}"
            ) from exc
        return None
    if result is None:
        return None
    return parse_scheme_datum(result.stdout)


def _load_projection_rows_uncached(
    module_path: Path,
    workdir: Path,
    projection_path: Path,
) -> SchemeRows:
    return run_scheme_projection(module_path, workdir, projection_path)


__all__ = [
    "clear_load_cache",
    "load",
    "load_projection_rows",
    "precompile_load",
    "preproject_load",
]
