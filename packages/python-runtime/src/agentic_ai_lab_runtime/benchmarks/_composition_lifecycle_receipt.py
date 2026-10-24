# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Versioned receipt values for composition lifecycle benchmark evidence."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

COMPOSITION_LIFECYCLE_SCHEMA = "agentic-ai-lab.composition-lifecycle-benchmark.v1"


@dataclass(frozen=True, slots=True)
class CompositionLatencySummary:
    p50_ms: float
    p95_ms: float
    p99_ms: float

    def receipt(self) -> dict[str, float]:
        return {
            "p50_ms": self.p50_ms,
            "p95_ms": self.p95_ms,
            "p99_ms": self.p99_ms,
        }


@dataclass(frozen=True, slots=True)
class CompositionLifecycleBenchmark:
    total_agents: int
    selected_capacity: int
    available_cpus: int
    capacity_source: str
    capacity_policy: str
    service_time_ms: float
    arrival_mode: str
    initial_wave_size: int
    wave_size: int
    wave_interval_ms: int
    simulation_time_scale: float
    wall_time_ms: float
    process_time_ms: float
    startup_latency: CompositionLatencySummary
    service_latency: CompositionLatencySummary
    settlement_latency: CompositionLatencySummary
    barrier_wait: CompositionLatencySummary
    aggregation_latency_ms: float
    throughput_agents_per_second: float
    peak_active_agents: int
    completed_agents: int
    failed_agents: int
    timed_out_agents: int
    cancelled_agents: int
    duplicate_completion_count: int
    lost_completion_count: int
    final_active_agents: int
    total_logical_steps: int
    critical_steps: int
    barrier_opened_after_all_terminal: bool
    aggregate_created_after_barrier: bool

    @property
    def correctness_passed(self) -> bool:
        return (
            self.completed_agents == self.total_agents
            and self.failed_agents == 0
            and self.timed_out_agents == 0
            and self.cancelled_agents == 0
            and self.duplicate_completion_count == 0
            and self.lost_completion_count == 0
            and self.final_active_agents == 0
            and self.barrier_opened_after_all_terminal
            and self.aggregate_created_after_barrier
        )

    def receipt(self) -> dict[str, Any]:
        return {
            "schema": COMPOSITION_LIFECYCLE_SCHEMA,
            "topology": {
                "total_agents": self.total_agents,
                "tenant_count": 1,
                "group_count": 1,
                "realized_agents": self.total_agents,
            },
            "arrival": {
                "mode": self.arrival_mode,
                "initial_wave_size": self.initial_wave_size,
                "wave_size": self.wave_size,
                "wave_interval_ms": self.wave_interval_ms,
                "simulation_time_scale": self.simulation_time_scale,
            },
            "capacity": {
                "available_cpus": self.available_cpus,
                "selected_capacity": self.selected_capacity,
                "capacity_source": self.capacity_source,
                "capacity_policy": self.capacity_policy,
                "calibration_population": 0,
                "calibration_capacities": [],
            },
            "workload": {
                "service_time_ms": self.service_time_ms,
                "total_logical_steps": self.total_logical_steps,
                "critical_steps": self.critical_steps,
            },
            "agent_metrics": {
                "startup_latency": self.startup_latency.receipt(),
                "service_latency": self.service_latency.receipt(),
                "settlement_latency": self.settlement_latency.receipt(),
                "completed_agents": self.completed_agents,
                "failed_agents": self.failed_agents,
                "timed_out_agents": self.timed_out_agents,
                "cancelled_agents": self.cancelled_agents,
            },
            "group_metrics": {
                "barrier_wait": self.barrier_wait.receipt(),
                "aggregation_latency_ms": self.aggregation_latency_ms,
                "barrier_opened_after_all_terminal": (
                    self.barrier_opened_after_all_terminal
                ),
                "aggregate_created_after_barrier": (
                    self.aggregate_created_after_barrier
                ),
            },
            "resource_metrics": {
                "wall_time_ms": self.wall_time_ms,
                "process_time_ms": self.process_time_ms,
                "throughput_agents_per_second": (
                    self.throughput_agents_per_second
                ),
                "peak_active_agents": self.peak_active_agents,
            },
            "correctness": {
                "duplicate_completion_count": self.duplicate_completion_count,
                "lost_completion_count": self.lost_completion_count,
                "final_active_agents": self.final_active_agents,
                "passed": self.correctness_passed,
            },
        }
