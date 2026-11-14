# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Arrival-aware globally bounded scheduler for ramped composition workloads."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from time import perf_counter_ns
from typing import Any, Protocol, cast

import anyio

from ..program import RuntimeGraphProgram
from ._composition_lifecycle_workload import ArrivalSchedule

BENCHMARK_ELIGIBLE_AT_NS = "benchmark_eligible_at_ns"


class AsyncRuntimeProgram(Protocol):
    async def ainvoke(self, initial_state: Mapping[str, Any]) -> dict[str, Any]: ...


@dataclass(frozen=True, slots=True)
class _PreparedRuntimeProgram:
    executor: Any

    async def ainvoke(self, initial_state: Mapping[str, Any]) -> dict[str, Any]:
        return dict(await self.executor.ainvoke(initial_state))


def prepare_runtime_program(program: RuntimeGraphProgram) -> AsyncRuntimeProgram:
    """Validate once and reuse one executor across scheduled agent calls."""

    program._validated_plan()
    return _PreparedRuntimeProgram(
        executor=program._executor(),
    )


async def run_arrival_batch(
    program: AsyncRuntimeProgram,
    inputs: Sequence[Mapping[str, Any]],
    *,
    schedule: ArrivalSchedule,
    max_concurrency: int,
    wall_start_ns: int,
) -> list[dict[str, Any]]:
    """Wait for eligibility before acquiring a runtime execution slot."""

    if max_concurrency < 1:
        raise ValueError("max_concurrency must be at least one")
    limiter = anyio.CapacityLimiter(max_concurrency)
    outputs: list[dict[str, Any] | None] = [None] * len(inputs)

    async def run_one(index: int, initial_state: Mapping[str, Any]) -> None:
        target_ns = wall_start_ns + round(
            schedule.effective_eligible_at_ms(index) * 1_000_000
        )
        delay_seconds = max(target_ns - _now_ns(), 0) / 1_000_000_000
        if delay_seconds:
            await anyio.sleep(delay_seconds)
        eligible_state = dict(initial_state)
        eligible_state[BENCHMARK_ELIGIBLE_AT_NS] = target_ns
        async with limiter:
            outputs[index] = await program.ainvoke(eligible_state)

    async with anyio.create_task_group() as task_group:
        for index, initial_state in enumerate(inputs):
            task_group.start_soon(run_one, index, initial_state)
    return cast(list[dict[str, Any]], outputs)


def _now_ns() -> int:
    return perf_counter_ns()
