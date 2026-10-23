# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Shared system-adaptive capacity policy for runtime benchmarks."""

from __future__ import annotations

import os

SYSTEM_AVAILABLE_CPU_POLICY = "system-available-cpu-v1"
MANUAL_CAPACITY_POLICY = "manual-override-v1"


def available_cpu_count() -> int:
    cpu_count = getattr(os, "process_cpu_count", os.cpu_count)
    return max(cpu_count() or 1, 1)


def select_benchmark_capacity(
    *,
    available_cpus: int,
    population_cap: int,
    requested: int | None,
) -> tuple[int, str, str]:
    if requested is not None:
        return requested, "manual", MANUAL_CAPACITY_POLICY
    return (
        min(population_cap, available_cpus),
        "system-available-cpu",
        SYSTEM_AVAILABLE_CPU_POLICY,
    )
