# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Validate, select capacity, and dispatch burst lifecycle measurements."""

from __future__ import annotations

from collections.abc import Sequence
from functools import partial
import sys

from ._benchmark_capacity import (
    MANUAL_CAPACITY_POLICY,
    SYSTEM_AVAILABLE_CPU_POLICY,
    available_cpu_count,
    select_benchmark_capacity,
)

import anyio

from ._burst_lifecycle_measurement import _measure_population
from .burst_lifecycle import BurstLifecycleBenchmark

def run_burst_lifecycle_benchmarks(
    *,
    populations: Sequence[int],
    max_concurrency: int | None,
    serial_steps: int,
    parallel_fanout: int,
    parallel_steps: int,
    serial_interval_us: int,
    trace_memory: bool,
    stream_progress: bool,
) -> list[BurstLifecycleBenchmark]:
    _validate_inputs(
        populations,
        max_concurrency,
        serial_steps,
        parallel_fanout,
        parallel_steps,
        serial_interval_us,
    )
    return anyio.run(
        partial(
            _run_benchmarks,
            populations=tuple(populations),
            max_concurrency=max_concurrency,
            serial_steps=serial_steps,
            parallel_fanout=parallel_fanout,
            parallel_steps=parallel_steps,
            serial_interval_us=serial_interval_us,
            trace_memory=trace_memory,
            stream_progress=stream_progress,
        )
    )


def _validate_inputs(
    populations: Sequence[int],
    max_concurrency: int | None,
    serial_steps: int,
    parallel_fanout: int,
    parallel_steps: int,
    serial_interval_us: int,
) -> None:
    if not populations or any(population < 1 for population in populations):
        raise ValueError("populations must be non-empty and positive")
    if max_concurrency is not None and max_concurrency < 1:
        raise ValueError("max concurrency must be positive")
    if serial_steps < 0 or parallel_steps < 0 or parallel_fanout < 1:
        raise ValueError("case topology values must be non-negative")
    if serial_interval_us < 0:
        raise ValueError("serial interval must be non-negative")


async def _run_benchmarks(
    *,
    populations: Sequence[int],
    max_concurrency: int | None,
    serial_steps: int,
    parallel_fanout: int,
    parallel_steps: int,
    serial_interval_us: int,
    trace_memory: bool,
    stream_progress: bool,
) -> list[BurstLifecycleBenchmark]:
    available_cpus = _available_cpu_count()
    capacity, source, policy = _select_capacity(
        available_cpus=available_cpus,
        population_cap=min(populations),
        requested=max_concurrency,
    )
    receipts: list[BurstLifecycleBenchmark] = []
    for population in populations:
        receipt = await _measure_population(
            population=population,
            available_cpus=available_cpus,
            capacity=capacity,
            capacity_source=source,
            capacity_policy=policy,
            calibration_population=0,
            calibration_capacities=(),
            serial_steps=serial_steps,
            parallel_fanout=parallel_fanout,
            parallel_steps=parallel_steps,
            serial_interval_us=serial_interval_us,
            trace_memory=trace_memory,
        )
        receipts.append(receipt)
        if stream_progress:
            sys.stderr.write(receipt.progress_receipt() + "\n")
            sys.stderr.flush()
    return receipts


def _available_cpu_count() -> int:
    return available_cpu_count()


def _select_capacity(
    *,
    available_cpus: int,
    population_cap: int,
    requested: int | None,
) -> tuple[int, str, str]:
    return select_benchmark_capacity(
        available_cpus=available_cpus,
        population_cap=population_cap,
        requested=requested,
    )
