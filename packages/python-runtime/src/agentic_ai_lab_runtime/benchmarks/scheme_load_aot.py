# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Public Scheme load AOT benchmark surface."""

from __future__ import annotations

import argparse
import sys
from collections.abc import Iterable
from pathlib import Path

from ._scheme_load_aot_cases import run_scheme_load_aot_cases
from ._scheme_load_aot_types import (
    SCHEME_LOAD_AOT_BENCHMARK_SCHEMA,
    SchemeLoadAotBenchmark,
)


SCHEME_LOAD_AOT_DEFAULT_SOURCE = Path(
    "packages/python-runtime/t/fixtures/funflow_user_module.ss"
)


def run_scheme_load_aot_benchmarks(
    *,
    source: str | Path = SCHEME_LOAD_AOT_DEFAULT_SOURCE,
    cwd: str | Path = ".",
    iterations: int = 10,
    include_interpreter: bool = False,
    include_fresh_process: bool = True,
    include_artifact: bool = False,
    precompile: bool = False,
    preproject_artifact: bool = False,
) -> tuple[SchemeLoadAotBenchmark, ...]:
    if iterations <= 0:
        raise ValueError("iterations must be positive")
    return run_scheme_load_aot_cases(
        source=Path(source).expanduser().resolve(),
        cwd=Path(cwd).expanduser().resolve(),
        iterations=iterations,
        include_interpreter=include_interpreter,
        include_fresh_process=include_fresh_process,
        include_artifact=include_artifact,
        precompile=precompile,
        preproject_artifact=preproject_artifact,
    )


def parse_scheme_load_aot_args(
    argv: Iterable[str] | None = None,
) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Benchmark Scheme load AOT reuse and projection cache paths.",
    )
    parser.add_argument("--iterations", type=int, default=10)
    parser.add_argument("--source", default=str(SCHEME_LOAD_AOT_DEFAULT_SOURCE))
    parser.add_argument("--cwd", default=".")
    parser.add_argument("--include-interpreter", action="store_true")
    parser.add_argument("--include-artifact", action="store_true")
    parser.add_argument("--skip-fresh-process", action="store_true")
    parser.add_argument("--precompile", action="store_true")
    parser.add_argument("--preproject-artifact", action="store_true")
    return parser.parse_args(None if argv is None else tuple(argv))


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_scheme_load_aot_args(argv)
    for result in run_scheme_load_aot_benchmarks(
        source=args.source,
        cwd=args.cwd,
        iterations=args.iterations,
        include_interpreter=args.include_interpreter,
        include_fresh_process=not args.skip_fresh_process,
        include_artifact=args.include_artifact,
        precompile=args.precompile,
        preproject_artifact=args.preproject_artifact,
    ):
        sys.stdout.write(result.receipt() + "\n")
    return 0


__all__ = [
    "SCHEME_LOAD_AOT_BENCHMARK_SCHEMA",
    "SCHEME_LOAD_AOT_DEFAULT_SOURCE",
    "SchemeLoadAotBenchmark",
    "main",
    "parse_scheme_load_aot_args",
    "run_scheme_load_aot_benchmarks",
]


if __name__ == "__main__":
    raise SystemExit(main())
