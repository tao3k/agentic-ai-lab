# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import pytest

from agentic_ai_lab_runtime.benchmarks import _composition_lifecycle_runner as runner
from agentic_ai_lab_runtime.benchmarks.composition_lifecycle import (
    ArrivalSchedule,
    COMPOSITION_LIFECYCLE_SCHEMA,
    run_composition_benchmarks,
)


def test_runs_real_composition_through_runtime_program(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(runner, "available_cpu_count", lambda: 2)

    result = run_composition_benchmarks((8,), service_time_ms=2.0)[0]
    receipt = result.receipt()

    assert receipt["schema"] == COMPOSITION_LIFECYCLE_SCHEMA
    assert receipt["topology"] == {
        "total_agents": 8,
        "tenant_count": 1,
        "group_count": 1,
        "realized_agents": 8,
    }
    assert receipt["capacity"]["selected_capacity"] == 2
    assert receipt["capacity"]["capacity_policy"] == "system-available-cpu-v1"
    assert receipt["capacity"]["calibration_population"] == 0
    assert receipt["capacity"]["calibration_capacities"] == []
    assert receipt["agent_metrics"]["completed_agents"] == 8
    assert receipt["resource_metrics"]["peak_active_agents"] == 2
    assert receipt["correctness"]["passed"] is True


def test_manual_capacity_is_authoritative(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(runner, "available_cpu_count", lambda: 12)

    result = run_composition_benchmarks(
        (8,), service_time_ms=1.0, max_concurrency=3
    )[0]

    assert result.selected_capacity == 3
    assert result.capacity_source == "manual"
    assert result.capacity_policy == "manual-override-v1"
    assert result.peak_active_agents == 3
    assert result.correctness_passed


def test_result_order_matches_requested_population_order(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(runner, "available_cpu_count", lambda: 4)

    results = run_composition_benchmarks((4, 2), service_time_ms=0.0)

    assert [result.total_agents for result in results] == [4, 2]
    assert all(result.completed_agents == result.total_agents for result in results)
    assert all(result.final_active_agents == 0 for result in results)
    assert all(result.aggregate_created_after_barrier for result in results)


def test_ramp_waits_for_eligibility_without_holding_capacity(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(runner, "available_cpu_count", lambda: 2)
    schedule = ArrivalSchedule(
        mode="ramp",
        initial_wave_size=2,
        wave_size=1,
        wave_interval_ms=20,
        simulation_time_scale=10,
    )

    result = run_composition_benchmarks(
        (5,), service_time_ms=1.0, arrival=schedule
    )[0]
    receipt = result.receipt()

    assert receipt["arrival"] == {
        "mode": "ramp",
        "initial_wave_size": 2,
        "wave_size": 1,
        "wave_interval_ms": 20,
        "simulation_time_scale": 10,
    }
    assert result.peak_active_agents <= 2
    assert result.wall_time_ms >= 5.0
    assert result.completed_agents == 5
    assert result.correctness_passed


@pytest.mark.parametrize(
    "kwargs",
    [
        {"populations": ()},
        {"populations": (0,)},
        {"populations": (True,)},
        {"service_time_ms": -1.0},
        {"max_concurrency": 0},
    ],
)
def test_rejects_invalid_runner_inputs(kwargs: dict[str, object]) -> None:
    with pytest.raises(ValueError):
        run_composition_benchmarks(**kwargs)  # type: ignore[arg-type]
