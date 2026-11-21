# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Framework-neutral benchmark execution pipeline."""

import platform
import sys
from datetime import datetime, timezone

from .common import _run_case
from .model import BenchmarkFailure, BenchmarkResult, Report


def run_cases(cases, *, iterations: int, warmup: int, keep_gc: bool, progress: bool) -> Report:
    results: list[BenchmarkResult] = []
    failures: list[BenchmarkFailure] = []
    for case in cases:
        count = min(iterations, case.max_iterations or iterations)
        case_warmup = min(warmup, max(1, count // 10))
        if progress:
            sys.stderr.write(
                f"[benchmark] {case.name} iterations={count} warmup={case_warmup}\n"
            )
            sys.stderr.flush()
        result = _run_case(case, iterations=count, warmup=case_warmup, keep_gc=keep_gc)
        (failures if isinstance(result, BenchmarkFailure) else results).append(result)
    return Report(
        datetime.now(timezone.utc).isoformat(), " ".join(sys.argv),
        sys.version.replace("\n", " "), platform.platform(), iterations, warmup,
        keep_gc, True, tuple(results), tuple(failures), (),
    )
