# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Run Agentic AI Lab runtime benchmark suites as project modules."""

from __future__ import annotations

import argparse
import sys

from . import anyio_runtime
from . import burst_lifecycle
from . import composition
from . import large_state_copy
from . import langgraph_alignment
from . import scheme_load_aot


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Agentic AI Lab Python runtime benchmark suites."
    )
    parser.add_argument(
        "suite",
        choices=(
            "anyio-runtime",
            "burst-lifecycle",
            "large-state-copy",
            "langgraph-alignment",
            "composition",
            "scheme-load-aot",
        ),
        help="Benchmark suite to run.",
    )
    parser.add_argument("--iterations", type=int, default=100)
    parser.add_argument(
        "--observations-per-side",
        type=int,
        default=anyio_runtime.ANYIO_RUNTIME_DEFAULT_TARGET_OBSERVATIONS_PER_SIDE,
    )
    parser.add_argument("--fanout", type=int, default=16)
    parser.add_argument("--population", type=int, action="append")
    parser.add_argument("--items-per-pair", type=int)
    parser.add_argument("--max-concurrency", type=int)
    parser.add_argument("--relative-tolerance", type=float, default=0.25)
    parser.add_argument("--latency-us", type=int, default=1_000)
    parser.add_argument(
        "--payload-field-count",
        type=int,
        default=large_state_copy.LARGE_STATE_COPY_DEFAULT_PAYLOAD_FIELD_COUNT,
    )
    parser.add_argument(
        "--payload-field-bytes",
        type=int,
        default=large_state_copy.LARGE_STATE_COPY_DEFAULT_PAYLOAD_FIELD_BYTES,
    )
    parser.add_argument("--serial-steps", type=int, default=3)
    parser.add_argument("--parallel-fanout", type=int, default=4)
    parser.add_argument("--parallel-steps", type=int, default=1)
    parser.add_argument("--serial-interval-us", type=int, default=0)
    parser.add_argument("--trace-memory", action="store_true")
    parser.add_argument(
        "--source",
        default=str(scheme_load_aot.SCHEME_LOAD_AOT_DEFAULT_SOURCE),
    )
    parser.add_argument("--cwd", default=".")
    parser.add_argument("--include-interpreter", action="store_true")
    parser.add_argument("--include-artifact", action="store_true")
    parser.add_argument("--skip-fresh-process", action="store_true")
    parser.add_argument("--precompile", action="store_true")
    parser.add_argument("--preproject-artifact", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.suite == "anyio-runtime":
        benchmarks = anyio_runtime.run_anyio_runtime_benchmarks(
            target_observations_per_side=args.observations_per_side,
            items_per_pair=args.items_per_pair,
            max_concurrency=args.max_concurrency,
            relative_tolerance=args.relative_tolerance,
            latency_us=args.latency_us,
        )
    elif args.suite == "large-state-copy":
        benchmarks = large_state_copy.run_large_state_copy_benchmarks(
            target_observations_per_side=args.observations_per_side,
            items_per_pair=args.items_per_pair,
            max_concurrency=args.max_concurrency,
            payload_field_count=args.payload_field_count,
            payload_field_bytes=args.payload_field_bytes,
            relative_tolerance=args.relative_tolerance,
        )
    elif args.suite == "burst-lifecycle":
        benchmarks = burst_lifecycle.run_burst_lifecycle_benchmarks(
            populations=(
                tuple(args.population)
                if args.population is not None
                else burst_lifecycle.BURST_LIFECYCLE_DEFAULT_POPULATIONS
            ),
            max_concurrency=args.max_concurrency,
            serial_steps=args.serial_steps,
            parallel_fanout=args.parallel_fanout,
            parallel_steps=args.parallel_steps,
            serial_interval_us=args.serial_interval_us,
            trace_memory=args.trace_memory,
            stream_progress=True,
        )
    elif args.suite == "langgraph-alignment":
        benchmarks = langgraph_alignment.run_benchmarks(
            iterations=args.iterations,
            fanout=args.fanout,
        )
    elif args.suite == "composition":
        benchmarks = composition.run_composition_benchmarks(
            iterations=args.iterations,
            fanout=args.fanout,
        )
    else:
        benchmarks = scheme_load_aot.run_scheme_load_aot_benchmarks(
            source=args.source,
            cwd=args.cwd,
            iterations=args.iterations,
            include_interpreter=args.include_interpreter,
            include_fresh_process=not args.skip_fresh_process,
            include_artifact=args.include_artifact,
            precompile=args.precompile,
            preproject_artifact=args.preproject_artifact,
        )
    sys.stdout.write("\n".join(benchmark.receipt() for benchmark in benchmarks))
    sys.stdout.write("\n")
    if args.suite == "anyio-runtime":
        return 0 if anyio_runtime.performance_gate_passed(benchmarks) else 1
    if args.suite == "large-state-copy":
        return 0 if large_state_copy.performance_gate_passed(benchmarks) else 1
    if args.suite == "burst-lifecycle":
        return 0 if burst_lifecycle.performance_gate_passed(benchmarks) else 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
