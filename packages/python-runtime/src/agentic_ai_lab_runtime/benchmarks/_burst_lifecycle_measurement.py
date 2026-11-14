# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Measure one burst population and project its lifecycle receipt."""

from __future__ import annotations

import tracemalloc
from collections.abc import Awaitable, Callable, Mapping, Sequence
from time import perf_counter_ns
from typing import Any

from ..program import RuntimeGraphProgram, RuntimeGraphRegistries
from ..runtime_graph import linear_plan
from ._burst_lifecycle_workload import _CaseObserver, _case_action
from .burst_lifecycle import BurstLifecycleBenchmark


async def _measure_population(
    *,
    population: int,
    available_cpus: int,
    capacity: int,
    capacity_source: str,
    capacity_policy: str,
    calibration_population: int,
    calibration_capacities: tuple[int, ...],
    serial_steps: int,
    parallel_fanout: int,
    parallel_steps: int,
    serial_interval_us: int,
    trace_memory: bool,
) -> BurstLifecycleBenchmark:
    observer = _CaseObserver.for_population(population)
    action = _case_action(
        observer,
        serial_steps=serial_steps,
        parallel_fanout=parallel_fanout,
        parallel_steps=parallel_steps,
        serial_interval_us=serial_interval_us,
    )
    program = _program(action)
    _start_memory_profile(trace_memory)
    try:
        run_started_ns = perf_counter_ns()
        inputs = tuple({"case-id": case_id} for case_id in range(population))
        submitted_ns = perf_counter_ns()
        results = await program.abatch(inputs, max_concurrency=capacity)
        finished_ns = perf_counter_ns()
    finally:
        traced_peak_bytes = _finish_memory_profile(trace_memory)
    return _project_receipt(
        population=population,
        available_cpus=available_cpus,
        capacity=capacity,
        capacity_source=capacity_source,
        capacity_policy=capacity_policy,
        calibration_population=calibration_population,
        calibration_capacities=calibration_capacities,
        serial_steps=serial_steps,
        parallel_fanout=parallel_fanout,
        parallel_steps=parallel_steps,
        serial_interval_us=serial_interval_us,
        trace_memory=trace_memory,
        traced_peak_bytes=traced_peak_bytes,
        run_started_ns=run_started_ns,
        submitted_ns=submitted_ns,
        finished_ns=finished_ns,
        observer=observer,
        results=results,
    )


def _finish_memory_profile(enabled: bool) -> int | None:
    if not enabled:
        return None
    _, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    return peak


def _start_memory_profile(enabled: bool) -> None:
    if not enabled:
        return
    if tracemalloc.is_tracing():
        raise RuntimeError(
            "burst memory profile requires ownership of the tracemalloc lifecycle"
        )
    tracemalloc.start()


def _project_receipt(
    *,
    population: int,
    available_cpus: int,
    capacity: int,
    capacity_source: str,
    capacity_policy: str,
    calibration_population: int,
    calibration_capacities: tuple[int, ...],
    serial_steps: int,
    parallel_fanout: int,
    parallel_steps: int,
    serial_interval_us: int,
    trace_memory: bool,
    traced_peak_bytes: int | None,
    run_started_ns: int,
    submitted_ns: int,
    finished_ns: int,
    observer: _CaseObserver,
    results: Sequence[Mapping[str, Any]],
) -> BurstLifecycleBenchmark:
    completed = sum(finish > 0 for finish in observer.finishes)
    makespan_ns = max(finished_ns - submitted_ns, 1)
    ordered = all(
        int(result["case-id"]) == case_id and result.get("completed") is True
        for case_id, result in enumerate(results)
    )
    startup = tuple(start - submitted_ns for start in observer.starts)
    service = tuple(
        finish - start
        for start, finish in zip(observer.starts, observer.finishes)
    )
    completion = tuple(finish - submitted_ns for finish in observer.finishes)
    return BurstLifecycleBenchmark(
        population=population,
        available_cpus=available_cpus,
        selected_capacity=capacity,
        capacity_source=capacity_source,
        capacity_policy=capacity_policy,
        calibration_population=calibration_population,
        calibration_capacities=calibration_capacities,
        serial_steps=serial_steps,
        parallel_fanout=parallel_fanout,
        parallel_steps=parallel_steps,
        serial_interval_us=serial_interval_us,
        prepare_ms=_ns_to_ms(submitted_ns - run_started_ns),
        makespan_ms=_ns_to_ms(makespan_ns),
        throughput_cases_per_second=population * 1_000_000_000 / makespan_ns,
        startup_p50_ms=_percentile_ms(startup, 0.50),
        startup_p95_ms=_percentile_ms(startup, 0.95),
        startup_p99_ms=_percentile_ms(startup, 0.99),
        service_p50_ms=_percentile_ms(service, 0.50),
        service_p95_ms=_percentile_ms(service, 0.95),
        service_p99_ms=_percentile_ms(service, 0.99),
        completion_p50_ms=_percentile_ms(completion, 0.50),
        completion_p95_ms=_percentile_ms(completion, 0.95),
        completion_p99_ms=_percentile_ms(completion, 0.99),
        peak_active_cases=observer.peak_active,
        memory_profile=trace_memory,
        python_traced_peak_bytes=traced_peak_bytes,
        completed=completed,
        failed=population - completed,
        passed=(completed == population and len(results) == population and ordered),
    )


def _program(
    action: Callable[[Mapping[str, Any]], Awaitable[dict[str, Any]]],
) -> RuntimeGraphProgram:
    return RuntimeGraphProgram.reference(
        plan=linear_plan("case"),
        registries=RuntimeGraphRegistries(actions={"case": action}),
    )


def _percentile_ms(values: Sequence[int], quantile: float) -> float:
    ordered = sorted(values)
    index = max(0, min(len(ordered) - 1, int(len(ordered) * quantile - 1e-12)))
    return _ns_to_ms(ordered[index])


def _ns_to_ms(value: int) -> float:
    return value / 1_000_000
