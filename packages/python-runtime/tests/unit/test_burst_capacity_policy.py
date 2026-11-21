# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Deterministic system-adaptive burst capacity policy tests."""

from __future__ import annotations

from types import SimpleNamespace

import pytest

from agentic_ai_lab_runtime.benchmarks import _burst_lifecycle_runner as runner
from agentic_ai_lab_runtime.benchmarks import burst_lifecycle as benchmark


def test_system_available_cpu_selection() -> None:
    assert runner._select_capacity(
        available_cpus=12,
        population_cap=1_000,
        requested=None,
    ) == (12, "system-available-cpu", "system-available-cpu-v1")


def test_system_available_cpu_selection_is_capped_by_population() -> None:
    assert runner._select_capacity(
        available_cpus=12,
        population_cap=8,
        requested=None,
    ) == (8, "system-available-cpu", "system-available-cpu-v1")


def test_manual_capacity_stays_authoritative() -> None:
    assert runner._select_capacity(
        available_cpus=12,
        population_cap=1_000,
        requested=77,
    ) == (77, "manual", "manual-override-v1")


def test_auto_capacity_is_deterministic_without_calibration_measurements(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    measurements: list[dict[str, object]] = []

    async def measure(**kwargs: object) -> SimpleNamespace:
        measurements.append(kwargs)
        return SimpleNamespace(
            selected_capacity=kwargs["capacity"],
            capacity_source=kwargs["capacity_source"],
            capacity_policy=kwargs["capacity_policy"],
            calibration_population=kwargs["calibration_population"],
            calibration_capacities=kwargs["calibration_capacities"],
        )

    monkeypatch.setattr(runner, "_available_cpu_count", lambda: 12)
    monkeypatch.setattr(runner, "_measure_population", measure)

    receipts = [
        benchmark.run_burst_lifecycle_benchmarks(populations=(1_000,))[0]
        for _ in range(5)
    ]

    assert [receipt.selected_capacity for receipt in receipts] == [12] * 5
    assert len(measurements) == 5
    assert all(call["population"] == 1_000 for call in measurements)
    assert all(call["capacity_source"] == "system-available-cpu" for call in measurements)
    assert all(call["capacity_policy"] == "system-available-cpu-v1" for call in measurements)
    assert all(call["calibration_population"] == 0 for call in measurements)
    assert all(call["calibration_capacities"] == () for call in measurements)
