# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Public receipts and gates for AnyIO runtime performance qualification."""

from __future__ import annotations

import argparse
import sys
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from statistics import median

ANYIO_RUNTIME_BENCHMARK_SCHEMA = "agentic-ai-lab.anyio-runtime-benchmark.v1"
ANYIO_RUNTIME_TIME_UNIT = "ns/item"
ANYIO_RUNTIME_MIN_TARGET_OBSERVATIONS_PER_SIDE = 5_000
ANYIO_RUNTIME_DEFAULT_TARGET_OBSERVATIONS_PER_SIDE = 10_000
ANYIO_RUNTIME_MIN_TIMING_PAIRS = 100


@dataclass(frozen=True, slots=True)
class AnyIORuntimeBenchmark:
    """One cold, warm, or reused-input performance receipt."""

    phase: str
    target_observations_per_side: int
    timing_pairs: int
    items_per_pair: int
    available_cpus: int
    anyio_limiter_capacity: int
    selected_capacity: int
    candidate_median_ns_per_item: float
    candidate_p95_ns_per_item: float
    reference_median_ns_per_item: float
    reference_p95_ns_per_item: float
    ratio: float
    threshold_ratio: float
    gated: bool
    passed: bool
    detail: str

    @property
    def actual_observations_per_side(self) -> int:
        return self.timing_pairs * self.items_per_pair

    @property
    def qualification_volume_met(self) -> bool:
        return (
            self.actual_observations_per_side
            >= self.target_observations_per_side
        )

    def receipt(self) -> str:
        return (
            "|agentic-ai-lab-benchmark "
            f"(schema: \"{ANYIO_RUNTIME_BENCHMARK_SCHEMA}\" "
            f"phase: \"{self.phase}\" "
            "target-observations-per-side: "
            f"{self.target_observations_per_side} "
            f"timing-pairs: {self.timing_pairs} "
            f"items-per-pair: {self.items_per_pair} "
            "actual-observations-per-side: "
            f"{self.actual_observations_per_side} "
            "qualification-volume-met: "
            f"{'#t' if self.qualification_volume_met else '#f'} "
            f"time-unit: \"{ANYIO_RUNTIME_TIME_UNIT}\" "
            f"available-cpus: {self.available_cpus} "
            f"anyio-limiter-capacity: {self.anyio_limiter_capacity} "
            f"selected-capacity: {self.selected_capacity} "
            "candidate-median-ns-per-item: "
            f"{self.candidate_median_ns_per_item:.3f} "
            f"candidate-p95-ns-per-item: {self.candidate_p95_ns_per_item:.3f} "
            "reference-median-ns-per-item: "
            f"{self.reference_median_ns_per_item:.3f} "
            f"reference-p95-ns-per-item: {self.reference_p95_ns_per_item:.3f} "
            f"ratio: {self.ratio:.6f} "
            f"threshold-ratio: {self.threshold_ratio:.6f} "
            f"gated: {'#t' if self.gated else '#f'} "
            f"passed: {'#t' if self.passed else '#f'} "
            f"detail: \"{self.detail}\")|"
        )


def select_runtime_capacity(
    *,
    available_cpus: int,
    anyio_limiter_capacity: int,
    requested: int | None = None,
) -> int:
    """Choose a host-bounded concurrency value without fixed worker constants."""

    if available_cpus < 1 or anyio_limiter_capacity < 1:
        raise ValueError("runtime capacity inputs must be positive")
    if requested is not None and requested < 1:
        raise ValueError("requested concurrency must be positive")
    desired = requested if requested is not None else available_cpus
    return min(desired, available_cpus, anyio_limiter_capacity)


def summarize_phase(
    *,
    phase: str,
    candidate_samples: Sequence[float],
    reference_samples: Sequence[float],
    target_observations_per_side: int,
    items_per_pair: int,
    available_cpus: int,
    anyio_limiter_capacity: int,
    selected_capacity: int,
    relative_tolerance: float,
    gated: bool,
    detail: str,
) -> AnyIORuntimeBenchmark:
    """Build a robust same-process performance qualification receipt."""

    if not candidate_samples or len(candidate_samples) != len(reference_samples):
        raise ValueError("candidate and reference samples must be non-empty and paired")
    if target_observations_per_side < 1:
        raise ValueError("target observations must be positive")
    if items_per_pair < 1:
        raise ValueError("items per pair must be positive")
    if relative_tolerance < 0:
        raise ValueError("relative tolerance must be non-negative")

    candidate_median = float(median(candidate_samples))
    reference_median = max(float(median(reference_samples)), 1.0)
    reference_mad = float(
        median(abs(sample - reference_median) for sample in reference_samples)
    )
    noise_tolerance = 3.0 * reference_mad / reference_median
    threshold_ratio = 1.0 + max(relative_tolerance, noise_tolerance)
    ratio = candidate_median / reference_median
    actual_observations = len(candidate_samples) * items_per_pair
    qualification_volume_met = (
        actual_observations >= target_observations_per_side
    )
    return AnyIORuntimeBenchmark(
        phase=phase,
        target_observations_per_side=target_observations_per_side,
        timing_pairs=len(candidate_samples),
        items_per_pair=items_per_pair,
        available_cpus=available_cpus,
        anyio_limiter_capacity=anyio_limiter_capacity,
        selected_capacity=selected_capacity,
        candidate_median_ns_per_item=candidate_median,
        candidate_p95_ns_per_item=_percentile(candidate_samples, 0.95),
        reference_median_ns_per_item=reference_median,
        reference_p95_ns_per_item=_percentile(reference_samples, 0.95),
        ratio=ratio,
        threshold_ratio=threshold_ratio,
        gated=gated,
        passed=(not gated) or (
            qualification_volume_met and ratio <= threshold_ratio
        ),
        detail=detail,
    )


def plan_timing_pairs(
    *,
    target_observations_per_side: int,
    items_per_pair: int,
    minimum_timing_pairs: int = ANYIO_RUNTIME_MIN_TIMING_PAIRS,
) -> int:
    """Plan an even AB/BA sample count without inflating item observations."""

    if target_observations_per_side < 1:
        raise ValueError("target observations must be positive")
    if items_per_pair < 1:
        raise ValueError("items per pair must be positive")
    if minimum_timing_pairs < 2:
        raise ValueError("minimum timing pairs must be at least two")
    raw_pairs = max(
        minimum_timing_pairs,
        (target_observations_per_side + items_per_pair - 1) // items_per_pair,
    )
    return raw_pairs + raw_pairs % 2


def performance_gate_passed(benchmarks: Iterable[AnyIORuntimeBenchmark]) -> bool:
    return all(benchmark.passed for benchmark in benchmarks)


def run_anyio_runtime_benchmarks(
    *,
    target_observations_per_side: int = (
        ANYIO_RUNTIME_DEFAULT_TARGET_OBSERVATIONS_PER_SIDE
    ),
    items_per_pair: int | None = None,
    max_concurrency: int | None = None,
    relative_tolerance: float = 0.25,
    latency_us: int = 1_000,
) -> list[AnyIORuntimeBenchmark]:
    from ._anyio_runtime_runner import run_anyio_runtime_benchmarks as run

    return run(
        target_observations_per_side=target_observations_per_side,
        items_per_pair=items_per_pair,
        max_concurrency=max_concurrency,
        relative_tolerance=relative_tolerance,
        latency_us=latency_us,
    )


def _percentile(samples: Sequence[float], quantile: float) -> float:
    ordered = sorted(samples)
    index = max(0, min(len(ordered) - 1, int(len(ordered) * quantile - 1e-12)))
    return float(ordered[index])


def _parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Qualify the Agentic AI Lab AnyIO runtime substrate."
    )
    parser.add_argument(
        "--observations-per-side",
        type=int,
        default=ANYIO_RUNTIME_DEFAULT_TARGET_OBSERVATIONS_PER_SIDE,
    )
    parser.add_argument("--items-per-pair", type=int)
    parser.add_argument("--max-concurrency", type=int)
    parser.add_argument("--relative-tolerance", type=float, default=0.25)
    parser.add_argument("--latency-us", type=int, default=1_000)
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = _parse_args(argv)
    benchmarks = run_anyio_runtime_benchmarks(
        target_observations_per_side=args.observations_per_side,
        items_per_pair=args.items_per_pair,
        max_concurrency=args.max_concurrency,
        relative_tolerance=args.relative_tolerance,
        latency_us=args.latency_us,
    )
    sys.stdout.write("\n".join(benchmark.receipt() for benchmark in benchmarks))
    sys.stdout.write("\n")
    return 0 if performance_gate_passed(benchmarks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
