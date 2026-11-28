# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Validated runner for composition lifecycle benchmarks."""

from __future__ import annotations

from collections.abc import Sequence

import anyio

from ._benchmark_capacity import available_cpu_count, select_benchmark_capacity
from ._composition_lifecycle_measurement import measure_composition
from ._composition_lifecycle_planner import plan_composition_workload
from ._composition_lifecycle_receipt import CompositionLifecycleBenchmark
from ._composition_lifecycle_workload import ArrivalSchedule

DEFAULT_COMPOSITION_POPULATIONS = (2, 4, 8, 16, 32, 64, 100, 128)


def run_composition_benchmarks(
    populations: Sequence[int] = DEFAULT_COMPOSITION_POPULATIONS,
    *,
    service_time_ms: float = 1.0,
    max_concurrency: int | None = None,
    arrival: ArrivalSchedule | None = None,
) -> list[CompositionLifecycleBenchmark]:
    """Run the normative single-group composition population matrix."""

    requested_populations = tuple(populations)
    _validate_inputs(requested_populations, service_time_ms, max_concurrency)
    available_cpus = available_cpu_count()
    schedule = arrival or ArrivalSchedule(mode="instant")

    async def run_all() -> list[CompositionLifecycleBenchmark]:
        results: list[CompositionLifecycleBenchmark] = []
        for population in requested_populations:
            selected, source, policy = select_benchmark_capacity(
                available_cpus=available_cpus,
                population_cap=population,
                requested=max_concurrency,
            )
            workload = plan_composition_workload(
                population,
                tenant_count=1,
                agents_per_group=population,
                arrival=schedule,
            )
            results.append(
                await measure_composition(
                    workload=workload,
                    selected_capacity=selected,
                    available_cpus=available_cpus,
                    capacity_source=source,
                    capacity_policy=policy,
                    service_time_ms=service_time_ms,
                )
            )
        return results

    return anyio.run(run_all)


def _validate_inputs(
    populations: tuple[int, ...],
    service_time_ms: float,
    max_concurrency: int | None,
) -> None:
    if not populations:
        raise ValueError("populations must not be empty")
    if any(
        isinstance(population, bool)
        or not isinstance(population, int)
        or population < 1
        for population in populations
    ):
        raise ValueError("populations must contain positive integers")
    if service_time_ms < 0:
        raise ValueError("service_time_ms must not be negative")
    if max_concurrency is not None and max_concurrency < 1:
        raise ValueError("max_concurrency must be at least one")
