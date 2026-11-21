# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from collections.abc import Mapping
from time import perf_counter_ns
from typing import Any

import anyio

from agentic_ai_lab_runtime.benchmarks._composition_lifecycle_arrival import (
    BENCHMARK_ELIGIBLE_AT_NS,
    run_arrival_batch,
)
from agentic_ai_lab_runtime.benchmarks._composition_lifecycle_workload import ArrivalSchedule


class _ObservedProgram:
    def __init__(self) -> None:
        self.active = 0
        self.peak_active = 0
        self.started_at_ns: dict[int, int] = {}

    async def ainvoke(self, initial_state: Mapping[str, Any]) -> dict[str, Any]:
        index = int(initial_state["index"])
        self.active += 1
        self.peak_active = max(self.peak_active, self.active)
        self.started_at_ns[index] = perf_counter_ns()
        try:
            await anyio.sleep(0.001)
            return dict(initial_state)
        finally:
            self.active -= 1


def test_scheduler_preserves_order_and_waits_outside_capacity() -> None:
    program = _ObservedProgram()
    schedule = ArrivalSchedule(
        mode="ramp",
        initial_wave_size=2,
        wave_size=1,
        wave_interval_ms=10,
        simulation_time_scale=10,
    )
    wall_start_ns = perf_counter_ns()

    async def scenario() -> list[dict[str, Any]]:
        return await run_arrival_batch(
            program,
            tuple({"index": index} for index in range(5)),
            schedule=schedule,
            max_concurrency=2,
            wall_start_ns=wall_start_ns,
        )

    outputs = anyio.run(scenario)

    assert [output["index"] for output in outputs] == [0, 1, 2, 3, 4]
    assert program.peak_active == 2
    assert program.active == 0
    assert outputs[0][BENCHMARK_ELIGIBLE_AT_NS] == wall_start_ns
    assert outputs[1][BENCHMARK_ELIGIBLE_AT_NS] == wall_start_ns
    assert outputs[4][BENCHMARK_ELIGIBLE_AT_NS] == wall_start_ns + 3_000_000
    assert all(
        program.started_at_ns[index] >= output[BENCHMARK_ELIGIBLE_AT_NS]
        for index, output in enumerate(outputs)
    )


def test_scheduler_rejects_invalid_capacity() -> None:
    async def invalid_capacity() -> None:
        await run_arrival_batch(
            _ObservedProgram(),
            (),
            schedule=ArrivalSchedule(mode="ramp"),
            max_concurrency=0,
            wall_start_ns=perf_counter_ns(),
        )

    try:
        anyio.run(invalid_capacity)
    except ValueError:
        return
    raise AssertionError("expected ValueError")
