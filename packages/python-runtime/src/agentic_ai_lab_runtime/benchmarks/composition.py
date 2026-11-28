# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Public composition benchmark surface for the Python runtime package."""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from typing import Iterable

from .composition_cases import run_composition_cases

COMPOSITION_BENCHMARK_SCHEMA = "agentic-ai-lab.composition-benchmark.v1"


@dataclass(frozen=True, slots=True)
class CompositionBenchmark:
    """Line-oriented receipt for one composition benchmark scenario."""

    scenario: str
    iterations: int
    elapsed_micros: int
    detail: str

    def receipt(self) -> str:
        per_iteration = self.elapsed_micros / max(self.iterations, 1)
        return (
            "|agentic-ai-lab-benchmark "
            f"(schema: \"{COMPOSITION_BENCHMARK_SCHEMA}\" "
            f"scenario: \"{self.scenario}\" "
            f"iterations: {self.iterations} "
            f"elapsed-us: {self.elapsed_micros} "
            f"per-iteration-us: {per_iteration:.3f} "
            f"detail: \"{self.detail}\")|"
        )


def run_composition_benchmarks(
    *, iterations: int = 100, fanout: int = 16
) -> list[CompositionBenchmark]:
    return [
        CompositionBenchmark(
            scenario=case.scenario,
            iterations=case.iterations,
            elapsed_micros=case.elapsed_micros,
            detail=case.detail,
        )
        for case in run_composition_cases(iterations=iterations, fanout=fanout)
    ]


def _parse_composition_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Agentic AI Lab runtime composition benchmarks."
    )
    parser.add_argument("--iterations", type=int, default=100)
    parser.add_argument("--fanout", type=int, default=16)
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = _parse_composition_args(argv)
    receipts = run_composition_benchmarks(
        iterations=args.iterations,
        fanout=args.fanout,
    )
    sys.stdout.write("\n".join(receipt.receipt() for receipt in receipts))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
