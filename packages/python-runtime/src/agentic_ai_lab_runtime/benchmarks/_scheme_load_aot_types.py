# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Receipt model for Scheme load AOT benchmark samples."""

from __future__ import annotations

import math
import statistics
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SCHEME_LOAD_AOT_BENCHMARK_SCHEMA = "agentic-ai-lab.scheme-load-aot-benchmark.v1"


@dataclass(frozen=True, slots=True)
class SchemeLoadAotBenchmark:
    scenario: str
    iterations: int
    source: Path
    cwd: Path
    samples_micros: tuple[int, ...]
    detail: Mapping[str, Any]

    @property
    def elapsed_micros(self) -> int:
        return sum(self.samples_micros)

    @property
    def min_micros(self) -> int:
        return min(self.samples_micros)

    @property
    def median_micros(self) -> float:
        return float(statistics.median(self.samples_micros))

    @property
    def mean_micros(self) -> float:
        return float(statistics.fmean(self.samples_micros))

    @property
    def p95_micros(self) -> int:
        return _nearest_rank(self.samples_micros, 0.95)

    @property
    def max_micros(self) -> int:
        return max(self.samples_micros)

    def receipt(self) -> str:
        detail = " ".join(
            f"{key}: {_receipt_value(value)}" for key, value in self.detail.items()
        )
        return (
            "|agentic-ai-lab-benchmark "
            f"(schema: \"{SCHEME_LOAD_AOT_BENCHMARK_SCHEMA}\" "
            f"scenario: {_receipt_value(self.scenario)} "
            f"iterations: {self.iterations} "
            f"source: {_receipt_value(str(self.source))} "
            f"cwd: {_receipt_value(str(self.cwd))} "
            f"samples-us: ({' '.join(str(value) for value in self.samples_micros)}) "
            f"elapsed-us: {self.elapsed_micros} "
            f"min-us: {self.min_micros} "
            f"median-us: {self.median_micros:.3f} "
            f"mean-us: {self.mean_micros:.3f} "
            f"p95-us: {self.p95_micros} "
            f"max-us: {self.max_micros} "
            f"detail: ({detail}))|"
        )


def _nearest_rank(samples: tuple[int, ...], percentile: float) -> int:
    ordered = sorted(samples)
    index = max(0, math.ceil(percentile * len(ordered)) - 1)
    return ordered[index]


def _receipt_value(value: object) -> str:
    if isinstance(value, bool):
        if value:
            return "#t"
        return "#f"
    if isinstance(value, str):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f"\"{escaped}\""
    return str(value)


__all__ = ["SCHEME_LOAD_AOT_BENCHMARK_SCHEMA", "SchemeLoadAotBenchmark"]
