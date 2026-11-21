# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Public receipt and gate for the large-state ownership-copy benchmark."""

from __future__ import annotations

import argparse
import sys
from collections.abc import Iterable

from ._large_state_copy_receipt import (
    LARGE_STATE_COPY_BENCHMARK_SCHEMA,
    LARGE_STATE_COPY_BOUNDARY,
    LARGE_STATE_COPY_TIME_UNIT,
    LargeStateCopyBenchmark,
)
from .anyio_runtime import (
    ANYIO_RUNTIME_DEFAULT_TARGET_OBSERVATIONS_PER_SIDE,
    ANYIO_RUNTIME_MIN_TARGET_OBSERVATIONS_PER_SIDE,
)

LARGE_STATE_COPY_DEFAULT_TARGET_OBSERVATIONS_PER_SIDE = (
    ANYIO_RUNTIME_DEFAULT_TARGET_OBSERVATIONS_PER_SIDE
)
LARGE_STATE_COPY_MIN_TARGET_OBSERVATIONS_PER_SIDE = (
    ANYIO_RUNTIME_MIN_TARGET_OBSERVATIONS_PER_SIDE
)
LARGE_STATE_COPY_DEFAULT_PAYLOAD_FIELD_COUNT = 256
LARGE_STATE_COPY_DEFAULT_PAYLOAD_FIELD_BYTES = 1_024

def performance_gate_passed(
    benchmarks: Iterable[LargeStateCopyBenchmark],
) -> bool:
    return all(benchmark.passed for benchmark in benchmarks)


def run_large_state_copy_benchmarks(
    *,
    target_observations_per_side: int = (
        LARGE_STATE_COPY_DEFAULT_TARGET_OBSERVATIONS_PER_SIDE
    ),
    items_per_pair: int | None = None,
    max_concurrency: int | None = None,
    payload_field_count: int = LARGE_STATE_COPY_DEFAULT_PAYLOAD_FIELD_COUNT,
    payload_field_bytes: int = LARGE_STATE_COPY_DEFAULT_PAYLOAD_FIELD_BYTES,
    relative_tolerance: float = 0.25,
) -> list[LargeStateCopyBenchmark]:
    from ._large_state_copy_runner import run_large_state_copy_benchmarks as run

    return run(
        target_observations_per_side=target_observations_per_side,
        items_per_pair=items_per_pair,
        max_concurrency=max_concurrency,
        payload_field_count=payload_field_count,
        payload_field_bytes=payload_field_bytes,
        relative_tolerance=relative_tolerance,
    )


def _validate_inputs(
    target_observations_per_side: int,
    items_per_pair: int | None,
    max_concurrency: int | None,
    payload_field_count: int,
    payload_field_bytes: int,
    relative_tolerance: float,
) -> None:
    if (
        target_observations_per_side
        < LARGE_STATE_COPY_MIN_TARGET_OBSERVATIONS_PER_SIDE
    ):
        raise ValueError(
            "target observations per side must be at least "
            f"{LARGE_STATE_COPY_MIN_TARGET_OBSERVATIONS_PER_SIDE}"
        )
    if items_per_pair is not None and items_per_pair < 1:
        raise ValueError("items per pair must be positive")
    if max_concurrency is None:
        raise ValueError("max concurrency must be explicitly provided")
    if max_concurrency < 1:
        raise ValueError("max concurrency must be positive")
    if payload_field_count < 1:
        raise ValueError("payload field count must be positive")
    if payload_field_bytes < 0:
        raise ValueError("payload field bytes must be non-negative")
    if relative_tolerance < 0:
        raise ValueError("relative tolerance must be non-negative")


def _parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Measure the Program-to-executor large-state copy boundary."
    )
    parser.add_argument(
        "--observations-per-side",
        type=int,
        default=LARGE_STATE_COPY_DEFAULT_TARGET_OBSERVATIONS_PER_SIDE,
    )
    parser.add_argument("--items-per-pair", type=int)
    parser.add_argument("--max-concurrency", type=int, required=True)
    parser.add_argument(
        "--payload-field-count",
        type=int,
        default=LARGE_STATE_COPY_DEFAULT_PAYLOAD_FIELD_COUNT,
    )
    parser.add_argument(
        "--payload-field-bytes",
        type=int,
        default=LARGE_STATE_COPY_DEFAULT_PAYLOAD_FIELD_BYTES,
    )
    parser.add_argument("--relative-tolerance", type=float, default=0.25)
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = _parse_args(argv)
    benchmarks = run_large_state_copy_benchmarks(
        target_observations_per_side=args.observations_per_side,
        items_per_pair=args.items_per_pair,
        max_concurrency=args.max_concurrency,
        payload_field_count=args.payload_field_count,
        payload_field_bytes=args.payload_field_bytes,
        relative_tolerance=args.relative_tolerance,
    )
    sys.stdout.write("\n".join(benchmark.receipt() for benchmark in benchmarks))
    sys.stdout.write("\n")
    return 0 if performance_gate_passed(benchmarks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
