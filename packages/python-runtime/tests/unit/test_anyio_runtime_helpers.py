# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from collections.abc import Callable
from threading import Barrier, Event, Lock
from time import monotonic, sleep
from typing import Any

import anyio
import pytest

from agentic_ai_lab_runtime import _anyio_runtime as runtime


class _CountingTaskGroup:
    def __init__(
        self,
        task_group: Any,
        starts: list[int],
        entered_groups: list[Any] | None = None,
    ) -> None:
        self._task_group = task_group
        self._entered: Any = None
        self._starts = starts
        self._entered_groups = entered_groups

    async def __aenter__(self) -> "_CountingTaskGroup":
        self._entered = await self._task_group.__aenter__()
        if self._entered_groups is not None:
            self._entered_groups.append(self._entered)
        return self

    async def __aexit__(self, *args: Any) -> bool | None:
        return await self._task_group.__aexit__(*args)

    def start_soon(self, call: Callable[..., Any], *args: Any) -> None:
        self._starts[0] += 1
        self._entered.start_soon(call, *args)


def _count_task_starts(monkeypatch: pytest.MonkeyPatch) -> list[int]:
    starts = [0]
    create_task_group = runtime.anyio.create_task_group

    def counting_task_group() -> _CountingTaskGroup:
        return _CountingTaskGroup(create_task_group(), starts)

    monkeypatch.setattr(runtime.anyio, "create_task_group", counting_task_group)
    return starts


def _contains_exception(exc: BaseException, expected: type[BaseException]) -> bool:
    if isinstance(exc, expected):
        return True
    if isinstance(exc, BaseExceptionGroup):
        return any(_contains_exception(child, expected) for child in exc.exceptions)
    return False


def test_map_ordered_async_bounds_spawned_workers(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    starts = _count_task_starts(monkeypatch)

    async def scenario() -> list[int]:
        async def call(value: int) -> int:
            await anyio.sleep(0)
            return value

        return await runtime.map_ordered_async(call, range(20), max_concurrency=3)

    assert anyio.run(scenario) == list(range(20))
    assert starts[0] == 3


def test_map_ordered_blocking_bounds_spawned_workers(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    starts = _count_task_starts(monkeypatch)

    async def scenario() -> list[int]:
        return await runtime.map_ordered_blocking(
            lambda value: value,
            range(20),
            max_concurrency=3,
        )

    assert anyio.run(scenario) == list(range(20))
    assert starts[0] == 3


def test_map_ordered_async_preserves_order_and_none_outputs() -> None:
    async def scenario() -> list[int | None]:
        async def call(value: int) -> int | None:
            await anyio.sleep((4 - value) / 10_000)
            return None if value == 2 else value

        return await runtime.map_ordered_async(call, range(5), max_concurrency=2)

    assert anyio.run(scenario) == [0, 1, None, 3, 4]


def test_map_ordered_blocking_preserves_order_and_none_outputs() -> None:
    def call(value: int) -> int | None:
        sleep((4 - value) / 10_000)
        return None if value == 2 else value

    async def scenario() -> list[int | None]:
        return await runtime.map_ordered_blocking(call, range(5), max_concurrency=2)

    assert anyio.run(scenario) == [0, 1, None, 3, 4]


def test_map_ordered_blocking_failure_stops_pending_work(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class WorkerFailure(RuntimeError):
        pass

    starts = [0]
    entered_groups: list[Any] = []
    create_task_group = runtime.anyio.create_task_group

    def counting_task_group() -> _CountingTaskGroup:
        return _CountingTaskGroup(
            create_task_group(),
            starts,
            entered_groups,
        )

    monkeypatch.setattr(runtime.anyio, "create_task_group", counting_task_group)
    in_flight = Barrier(2)
    failure_started = Event()
    called: list[int] = []
    called_lock = Lock()

    def call(value: int) -> int:
        with called_lock:
            called.append(value)
        in_flight.wait(timeout=2)
        if value == 0:
            failure_started.set()
            raise WorkerFailure("synthetic blocking worker failure")

        assert failure_started.wait(timeout=2)
        deadline = monotonic() + 2
        while not entered_groups[0].cancel_scope.cancel_called:
            if monotonic() >= deadline:
                raise AssertionError("task group did not cancel after worker failure")
            sleep(0.001)
        return value

    async def scenario() -> list[int]:
        return await runtime.map_ordered_blocking(
            call,
            range(10),
            max_concurrency=2,
        )

    with pytest.raises(BaseException) as exc_info:
        anyio.run(scenario)

    assert _contains_exception(exc_info.value, WorkerFailure)
    assert sorted(called) == [0, 1]
    assert starts[0] == 2


def test_map_ordered_async_preserves_unbounded_semantics(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    starts = _count_task_starts(monkeypatch)

    async def scenario() -> list[int | None]:
        async def call(value: int) -> int | None:
            await anyio.sleep(0)
            return None if value == 1 else value

        return await runtime.map_ordered_async(call, range(4))

    assert anyio.run(scenario) == [0, None, 2, 3]
    assert starts[0] == 4


def test_map_ordered_blocking_preserves_unbounded_semantics(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    starts = _count_task_starts(monkeypatch)

    def call(value: int) -> int | None:
        return None if value == 1 else value

    async def scenario() -> list[int | None]:
        return await runtime.map_ordered_blocking(call, range(4))

    assert anyio.run(scenario) == [0, None, 2, 3]
    assert starts[0] == 4


def test_map_ordered_async_failure_cancels_siblings() -> None:
    class WorkerFailure(RuntimeError):
        pass

    cancelled = [0]

    async def scenario() -> None:
        started = [0]
        all_started = anyio.Event()

        async def call(value: int) -> int:
            started[0] += 1
            if started[0] == 3:
                all_started.set()
            await all_started.wait()
            if value == 1:
                raise WorkerFailure("synthetic worker failure")
            try:
                await anyio.sleep_forever()
            except anyio.get_cancelled_exc_class():
                cancelled[0] += 1
                raise

        await runtime.map_ordered_async(call, range(10), max_concurrency=3)

    with pytest.raises(BaseException) as exc_info:
        anyio.run(scenario)

    assert _contains_exception(exc_info.value, WorkerFailure)
    assert cancelled[0] == 2


def test_map_ordered_async_propagates_caller_cancellation() -> None:
    cancelled = [0]

    async def scenario() -> None:
        started = [0]
        all_started = anyio.Event()

        async def call(value: int) -> int:
            started[0] += 1
            if started[0] == 2:
                all_started.set()
            try:
                await anyio.sleep_forever()
            except anyio.get_cancelled_exc_class():
                cancelled[0] += 1
                raise

        async def run_mapping() -> None:
            await runtime.map_ordered_async(
                call,
                range(10),
                max_concurrency=2,
            )

        async with anyio.create_task_group() as task_group:
            task_group.start_soon(run_mapping)
            await all_started.wait()
            task_group.cancel_scope.cancel()

    anyio.run(scenario)
    assert cancelled[0] == 2


def test_capacity_limiter_validation() -> None:
    assert runtime._capacity_limiter(None) is None
    assert runtime._capacity_limiter(2).total_tokens == 2
    with pytest.raises(ValueError, match="positive"):
        runtime._capacity_limiter(0)
    with pytest.raises(ValueError, match="positive"):
        runtime._capacity_limiter(-1)
