# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Public receipts for production-shaped burst lifecycle benchmarks."""

from __future__ import annotations

import argparse
import sys
from collections.abc import Iterable, Sequence
from dataclasses import dataclass

BURST_LIFECYCLE_SCHEMA = "agentic-ai-lab.burst-lifecycle-benchmark.v1"
BURST_LIFECYCLE_TIME_UNIT = "ms"
BURST_LIFECYCLE_DEFAULT_POPULATIONS = (1_000, 10_000, 100_000)


@dataclass(frozen=True, slots=True)
class BurstLifecycleBenchmark:
    """One instant-arrival case-population lifecycle receipt."""

    population: int
    available_cpus: int
    selected_capacity: int
    capacity_source: str
    capacity_policy: str
    calibration_population: int
    calibration_capacities: tuple[int, ...]
    serial_steps: int
    parallel_fanout: int
    parallel_steps: int
    serial_interval_us: int
    prepare_ms: float
    makespan_ms: float
    throughput_cases_per_second: float
    startup_p50_ms: float
    startup_p95_ms: float
    startup_p99_ms: float
    service_p50_ms: float
    service_p95_ms: float
    service_p99_ms: float
    completion_p50_ms: float
    completion_p95_ms: float
    completion_p99_ms: float
    peak_active_cases: int
    memory_profile: bool
    python_traced_peak_bytes: int | None
    completed: int
    failed: int
    passed: bool

    def progress_receipt(self) -> str:
        return (
            "|agentic-ai-lab-benchmark-progress "
            f"(schema: \"{BURST_LIFECYCLE_SCHEMA}\" "
            f"population: {self.population} "
            f"completed: {self.completed} "
            f"makespan-ms: {self.makespan_ms:.3f} "
            f"passed: {'#t' if self.passed else '#f'})|"
        )

    def receipt(self) -> str:
        return (
            "|agentic-ai-lab-benchmark "
            f"(schema: \"{BURST_LIFECYCLE_SCHEMA}\" "
            'arrival-profile: "instant" '
            'parallel-kind: "action-internal-fanout-join" '
            f"population: {self.population} "
            f"available-cpus: {self.available_cpus} "
            f"selected-capacity: {self.selected_capacity} "
            f"capacity-source: \"{self.capacity_source}\" "
            f"capacity-policy: \"{self.capacity_policy}\" "
            f"calibration-population: {self.calibration_population} "
            "calibration-capacities: \""
            f"{','.join(str(value) for value in self.calibration_capacities)}\" "
            f"serial-steps: {self.serial_steps} "
            f"parallel-fanout: {self.parallel_fanout} "
            f"parallel-steps: {self.parallel_steps} "
            f"serial-interval-us: {self.serial_interval_us} "
            f"time-unit: \"{BURST_LIFECYCLE_TIME_UNIT}\" "
            f"prepare-ms: {self.prepare_ms:.3f} "
            f"makespan-ms: {self.makespan_ms:.3f} "
            "throughput-unit: \"cases/s\" "
            f"throughput-cases-per-second: {self.throughput_cases_per_second:.3f} "
            f"startup-p50-ms: {self.startup_p50_ms:.3f} "
            f"startup-p95-ms: {self.startup_p95_ms:.3f} "
            f"startup-p99-ms: {self.startup_p99_ms:.3f} "
            f"service-p50-ms: {self.service_p50_ms:.3f} "
            f"service-p95-ms: {self.service_p95_ms:.3f} "
            f"service-p99-ms: {self.service_p99_ms:.3f} "
            f"completion-p50-ms: {self.completion_p50_ms:.3f} "
            f"completion-p95-ms: {self.completion_p95_ms:.3f} "
            f"completion-p99-ms: {self.completion_p99_ms:.3f} "
            f"memory-profile: {'#t' if self.memory_profile else '#f'} "
            'memory-unit: "bytes" '
            "python-traced-peak-bytes: "
            f"{self.python_traced_peak_bytes if self.python_traced_peak_bytes is not None else '#f'} "
            f"peak-active-cases: {self.peak_active_cases} "
            f"completed: {self.completed} "
            f"failed: {self.failed} "
            f"passed: {'#t' if self.passed else '#f'})|"
        )


def run_burst_lifecycle_benchmarks(
    *,
    populations: Sequence[int] = BURST_LIFECYCLE_DEFAULT_POPULATIONS,
    max_concurrency: int | None = None,
    serial_steps: int = 3,
    parallel_fanout: int = 4,
    parallel_steps: int = 1,
    serial_interval_us: int = 0,
    trace_memory: bool = False,
    stream_progress: bool = False,
) -> list[BurstLifecycleBenchmark]:
    from ._burst_lifecycle_runner import run_burst_lifecycle_benchmarks as run

    return run(
        populations=populations,
        max_concurrency=max_concurrency,
        serial_steps=serial_steps,
        parallel_fanout=parallel_fanout,
        parallel_steps=parallel_steps,
        serial_interval_us=serial_interval_us,
        trace_memory=trace_memory,
        stream_progress=stream_progress,
    )


def performance_gate_passed(
    benchmarks: Iterable[BurstLifecycleBenchmark],
) -> bool:
    return all(benchmark.passed for benchmark in benchmarks)


def _parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Measure instant Agentic AI Lab case admission and drain."
    )
    parser.add_argument("--population", type=int, action="append")
    parser.add_argument("--max-concurrency", type=int)
    parser.add_argument("--serial-steps", type=int, default=3)
    parser.add_argument("--parallel-fanout", type=int, default=4)
    parser.add_argument("--parallel-steps", type=int, default=1)
    parser.add_argument("--serial-interval-us", type=int, default=0)
    parser.add_argument("--trace-memory", action="store_true")
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = _parse_args(argv)
    benchmarks = run_burst_lifecycle_benchmarks(
        populations=(
            tuple(args.population)
            if args.population is not None
            else BURST_LIFECYCLE_DEFAULT_POPULATIONS
        ),
        max_concurrency=args.max_concurrency,
        serial_steps=args.serial_steps,
        parallel_fanout=args.parallel_fanout,
        parallel_steps=args.parallel_steps,
        serial_interval_us=args.serial_interval_us,
        trace_memory=args.trace_memory,
        stream_progress=True,
    )
    sys.stdout.write("\n".join(benchmark.receipt() for benchmark in benchmarks))
    sys.stdout.write("\n")
    return 0 if performance_gate_passed(benchmarks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
