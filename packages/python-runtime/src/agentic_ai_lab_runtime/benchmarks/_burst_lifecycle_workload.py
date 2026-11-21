# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Define mixed serial and action-internal parallel burst cases."""

from __future__ import annotations

from collections.abc import Awaitable, Callable, Mapping
from dataclasses import dataclass
from time import perf_counter_ns
from typing import Any

import anyio


@dataclass(slots=True)
class _CaseObserver:
    starts: list[int]
    finishes: list[int]
    active: int = 0
    peak_active: int = 0

    @classmethod
    def for_population(cls, population: int) -> _CaseObserver:
        return cls(starts=[0] * population, finishes=[0] * population)

    def start(self, case_id: int) -> None:
        self.starts[case_id] = perf_counter_ns()
        self.active += 1
        self.peak_active = max(self.peak_active, self.active)

    def finish(self, case_id: int) -> None:
        self.finishes[case_id] = perf_counter_ns()
        self.active -= 1


def _case_action(
    observer: _CaseObserver,
    *,
    serial_steps: int,
    parallel_fanout: int,
    parallel_steps: int,
    serial_interval_us: int,
) -> Callable[[Mapping[str, Any]], Awaitable[dict[str, Any]]]:
    interval_seconds = serial_interval_us / 1_000_000

    async def checkpoint() -> None:
        if interval_seconds:
            await anyio.sleep(interval_seconds)
        else:
            await anyio.lowlevel.checkpoint()

    async def parallel_leaf() -> None:
        for _ in range(parallel_steps):
            await checkpoint()

    async def execute_case(state: Mapping[str, Any]) -> dict[str, Any]:
        case_id = int(state["case-id"])
        observer.start(case_id)
        try:
            await _execute_shape(
                case_id=case_id,
                serial_steps=serial_steps,
                parallel_fanout=parallel_fanout,
                checkpoint=checkpoint,
                parallel_leaf=parallel_leaf,
            )
            return {"case-id": case_id, "completed": True}
        finally:
            observer.finish(case_id)

    return execute_case


async def _execute_shape(
    *,
    case_id: int,
    serial_steps: int,
    parallel_fanout: int,
    checkpoint: Callable[[], Awaitable[None]],
    parallel_leaf: Callable[[], Awaitable[None]],
) -> None:
    shape = case_id % 3
    if shape != 1:
        for _ in range(serial_steps):
            await checkpoint()
    if shape == 0:
        return
    async with anyio.create_task_group() as task_group:
        for _ in range(parallel_fanout):
            task_group.start_soon(parallel_leaf)
