# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Executable Scheme load AOT benchmark cases."""

from __future__ import annotations

import subprocess
import sys
import time
from collections.abc import Callable
from pathlib import Path

from .._scheme_load import clear_load_cache, load_projection_rows, precompile_load
from .._scheme_load import preproject_load
from .._scheme_load_aot import scheme_aot_artifact
from .._scheme_load_artifact import cached_projection_artifact
from .._scheme_load_artifact import load_projection_artifact
from .._scheme_load_cache import scheme_load_cache_key
from .._scheme_load_runner import runtime_projection_source
from ._scheme_load_aot_types import SchemeLoadAotBenchmark


def run_scheme_load_aot_cases(
    *,
    source: Path,
    cwd: Path,
    iterations: int,
    include_interpreter: bool,
    include_fresh_process: bool,
    include_artifact: bool,
    precompile: bool,
    preproject_artifact: bool,
) -> tuple[SchemeLoadAotBenchmark, ...]:
    _prepare_aot(source, cwd, precompile=precompile)
    results: list[SchemeLoadAotBenchmark] = []
    if include_artifact:
        _prepare_projection_artifact(source, cwd, preproject=preproject_artifact)
        results.append(_run_projection_artifact(source, cwd, iterations))
    results.extend(
        [
            _run_cache_hit(source, cwd, iterations),
            _run_in_process_aot_reuse(source, cwd, iterations),
        ]
    )
    if include_fresh_process:
        results.append(_run_fresh_process_aot_reuse(source, cwd, iterations))
    if include_interpreter:
        results.append(_run_interpreter_no_cache(source, cwd, iterations))
    return tuple(results)


def scheme_load_aot_binary(source: Path, workdir: Path) -> Path:
    projection = runtime_projection_source(workdir)
    cache_key = scheme_load_cache_key(source, workdir, projection)
    return scheme_aot_artifact(workdir, cache_key).binary


def scheme_load_projection_artifact(source: Path, workdir: Path) -> Path:
    projection = runtime_projection_source(workdir)
    cache_key = scheme_load_cache_key(source, workdir, projection)
    return cached_projection_artifact(workdir, cache_key)


def _prepare_aot(source: Path, workdir: Path, *, precompile: bool) -> None:
    if precompile:
        precompile_load(source, cwd=workdir)
    binary = scheme_load_aot_binary(source, workdir)
    if binary.exists():
        return
    raise FileNotFoundError(
        "missing Scheme AOT runner; run "
        "`python -m agentic_ai_lab_runtime.scheme_load_aot precompile "
        f"{source} --cwd {workdir}` or pass --precompile"
    )


def _prepare_projection_artifact(
    source: Path,
    workdir: Path,
    *,
    preproject: bool,
) -> None:
    projection = runtime_projection_source(workdir)
    cache_key = scheme_load_cache_key(source, workdir, projection)
    artifact = cached_projection_artifact(workdir, cache_key)
    if preproject:
        preproject_load(source, cwd=workdir, output=artifact)
    if load_projection_artifact(source, workdir, projection, cache_key) is not None:
        return
    raise FileNotFoundError(
        "missing Scheme projection artifact; run "
        "`python -m agentic_ai_lab_runtime.scheme_projection_artifact export "
        f"{source} --cwd {workdir}` or pass --preproject-artifact"
    )


def _run_projection_artifact(
    source: Path,
    workdir: Path,
    iterations: int,
) -> SchemeLoadAotBenchmark:
    def load_artifact() -> None:
        clear_load_cache()
        load_projection_rows(
            source,
            cwd=workdir,
            cache=False,
            projection_artifact=True,
            aot=False,
        )

    samples = _sample_micros(load_artifact, iterations)
    return SchemeLoadAotBenchmark(
        scenario="scheme-load-projection-artifact",
        iterations=iterations,
        source=source,
        cwd=workdir,
        samples_micros=samples,
        detail={"process": "in-process", "artifact": True, "aot": False},
    )


def _run_cache_hit(
    source: Path,
    workdir: Path,
    iterations: int,
) -> SchemeLoadAotBenchmark:
    clear_load_cache()
    load_projection_rows(
        source,
        cwd=workdir,
        cache=True,
        projection_artifact=False,
        aot=True,
    )
    samples = _sample_micros(
        lambda: load_projection_rows(
            source,
            cwd=workdir,
            cache=True,
            projection_artifact=False,
            aot=True,
        ),
        iterations,
    )
    return SchemeLoadAotBenchmark(
        scenario="scheme-load-cache-hit",
        iterations=iterations,
        source=source,
        cwd=workdir,
        samples_micros=samples,
        detail={"process": "in-process", "cache": True, "aot": True},
    )


def _run_in_process_aot_reuse(
    source: Path,
    workdir: Path,
    iterations: int,
) -> SchemeLoadAotBenchmark:
    def load_uncached_aot() -> None:
        clear_load_cache()
        load_projection_rows(
            source,
            cwd=workdir,
            cache=False,
            projection_artifact=False,
            aot=True,
        )

    samples = _sample_micros(load_uncached_aot, iterations)
    return SchemeLoadAotBenchmark(
        scenario="scheme-load-in-process-aot-reuse",
        iterations=iterations,
        source=source,
        cwd=workdir,
        samples_micros=samples,
        detail={"process": "in-process", "cache": False, "aot": True},
    )


def _run_fresh_process_aot_reuse(
    source: Path,
    workdir: Path,
    iterations: int,
) -> SchemeLoadAotBenchmark:
    samples = _sample_micros(lambda: _run_fresh_process(source, workdir), iterations)
    return SchemeLoadAotBenchmark(
        scenario="scheme-load-fresh-process-aot-reuse",
        iterations=iterations,
        source=source,
        cwd=workdir,
        samples_micros=samples,
        detail={"process": "fresh-python", "cache": False, "aot": True},
    )


def _run_interpreter_no_cache(
    source: Path,
    workdir: Path,
    iterations: int,
) -> SchemeLoadAotBenchmark:
    def load_interpreter() -> None:
        clear_load_cache()
        load_projection_rows(
            source,
            cwd=workdir,
            cache=False,
            projection_artifact=False,
            aot=False,
        )

    samples = _sample_micros(load_interpreter, iterations)
    return SchemeLoadAotBenchmark(
        scenario="scheme-load-interpreter-no-cache",
        iterations=iterations,
        source=source,
        cwd=workdir,
        samples_micros=samples,
        detail={"process": "in-process", "cache": False, "aot": False},
    )


def _run_fresh_process(source: Path, workdir: Path) -> None:
    subprocess.run(
        (
            sys.executable,
            "-m",
            "agentic_ai_lab_runtime.benchmarks._scheme_load_once",
            "--source",
            str(source),
            "--cwd",
            str(workdir),
            "--cache",
            "off",
            "--artifact",
            "off",
            "--aot",
            "on",
        ),
        cwd=workdir,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def _sample_micros(call: Callable[[], object], iterations: int) -> tuple[int, ...]:
    samples: list[int] = []
    for _index in range(iterations):
        started = time.perf_counter_ns()
        call()
        samples.append((time.perf_counter_ns() - started) // 1000)
    return tuple(samples)


__all__ = [
    "run_scheme_load_aot_cases",
    "scheme_load_aot_binary",
    "scheme_load_projection_artifact",
]
