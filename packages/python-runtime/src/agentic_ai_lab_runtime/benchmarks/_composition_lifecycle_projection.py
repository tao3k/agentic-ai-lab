# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Project raw composition execution timings into a versioned benchmark receipt."""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from typing import Any

from ._composition_lifecycle_arrival import BENCHMARK_ELIGIBLE_AT_NS
from ._composition_lifecycle_receipt import (
    CompositionLatencySummary,
    CompositionLifecycleBenchmark,
)
from ._composition_lifecycle_workload import CompositionWorkload


@dataclass(frozen=True, slots=True)
class CompositionTimingEvidence:
    started_at_ns: Mapping[str, int]
    finished_at_ns: Mapping[str, int]
    peak_active: int
    final_active: int


def project_composition_benchmark(
    *,
    workload: CompositionWorkload,
    timings: CompositionTimingEvidence,
    outputs: list[dict[str, Any]],
    completed_ids: tuple[str, ...],
    wall_start_ns: int,
    barrier_open_ns: int,
    aggregate_created_ns: int,
    process_elapsed_ns: int,
    selected_capacity: int,
    available_cpus: int,
    capacity_source: str,
    capacity_policy: str,
    service_time_ms: float,
) -> CompositionLifecycleBenchmark:
    expected_ids = {agent.agent_id for agent in workload.agents}
    completed_id_set = set(completed_ids)
    starts = tuple(timings.started_at_ns[agent_id] for agent_id in completed_ids)
    finishes = tuple(timings.finished_at_ns[agent_id] for agent_id in completed_ids)
    eligible_at = {
        str(output["agent_id"]): int(output[BENCHMARK_ELIGIBLE_AT_NS])
        for output in outputs
    }
    wall_elapsed_ns = aggregate_created_ns - wall_start_ns
    return CompositionLifecycleBenchmark(
        total_agents=workload.realized_total_agents,
        selected_capacity=selected_capacity,
        available_cpus=available_cpus,
        capacity_source=capacity_source,
        capacity_policy=capacity_policy,
        service_time_ms=service_time_ms,
        arrival_mode=workload.arrival.mode,
        initial_wave_size=(
            workload.realized_total_agents
            if workload.arrival.mode == "instant"
            else workload.arrival.initial_wave_size
        ),
        wave_size=(
            workload.realized_total_agents
            if workload.arrival.mode == "instant"
            else workload.arrival.wave_size
        ),
        wave_interval_ms=workload.arrival.wave_interval_ms,
        simulation_time_scale=workload.arrival.simulation_time_scale,
        wall_time_ms=_ms(wall_elapsed_ns),
        process_time_ms=_ms(process_elapsed_ns),
        startup_latency=_latencies(
            start - eligible_at[agent_id]
            for agent_id, start in zip(completed_ids, starts, strict=True)
        ),
        service_latency=_latencies(
            finish - start for start, finish in zip(starts, finishes, strict=True)
        ),
        settlement_latency=_latencies(
            aggregate_created_ns - finish for finish in finishes
        ),
        barrier_wait=_latencies(barrier_open_ns - finish for finish in finishes),
        aggregation_latency_ms=_ms(aggregate_created_ns - barrier_open_ns),
        throughput_agents_per_second=(
            len(completed_ids) / (max(wall_elapsed_ns, 1) / 1_000_000_000)
        ),
        peak_active_agents=timings.peak_active,
        completed_agents=len(completed_ids),
        failed_agents=0,
        timed_out_agents=0,
        cancelled_agents=0,
        duplicate_completion_count=len(completed_ids) - len(completed_id_set),
        lost_completion_count=len(expected_ids - completed_id_set),
        final_active_agents=timings.final_active,
        total_logical_steps=workload.realized_total_agents,
        critical_steps=1,
        barrier_opened_after_all_terminal=(
            len(timings.finished_at_ns) == workload.realized_total_agents
            and all(finish <= barrier_open_ns for finish in finishes)
        ),
        aggregate_created_after_barrier=aggregate_created_ns >= barrier_open_ns,
    )


def _latencies(values: Iterable[int | float]) -> CompositionLatencySummary:
    ordered = sorted(values)
    return CompositionLatencySummary(
        p50_ms=_ms(_percentile(ordered, 0.50)),
        p95_ms=_ms(_percentile(ordered, 0.95)),
        p99_ms=_ms(_percentile(ordered, 0.99)),
    )


def _percentile(ordered: list[int | float], fraction: float) -> float:
    if not ordered:
        return 0.0
    position = (len(ordered) - 1) * fraction
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    weight = position - lower
    return ordered[lower] * (1 - weight) + ordered[upper] * weight


def _ms(nanoseconds: int | float) -> float:
    return nanoseconds / 1_000_000
