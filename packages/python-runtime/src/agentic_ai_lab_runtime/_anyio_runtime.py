# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""AnyIO adapters for ordered runtime graph execution."""

from __future__ import annotations

from collections.abc import Awaitable, Callable, Iterable
from functools import partial
from typing import Any, TypeVar, cast

import anyio

Input = TypeVar("Input")
Output = TypeVar("Output")


class _Missing:
    __slots__ = ()


_MISSING = _Missing()


async def run_blocking(call: Callable[..., Output], *args: Any, **kwargs: Any) -> Output:
    return await anyio.to_thread.run_sync(partial(call, *args, **kwargs))


async def map_ordered_blocking(
    call: Callable[[Input], Output],
    inputs: Iterable[Input],
    *,
    max_concurrency: int | None = None,
) -> list[Output]:
    values = list(inputs)
    results: list[Output | _Missing] = [_MISSING] * len(values)
    limiter = _capacity_limiter(max_concurrency)

    async def run_one(index: int, value: Input) -> None:
        results[index] = await run_blocking(call, value)

    if limiter is None:
        async with anyio.create_task_group() as task_group:
            for index, value in enumerate(values):
                task_group.start_soon(run_one, index, value)
        return _ordered_results(results)

    pending = iter(enumerate(values))

    async def worker() -> None:
        for index, value in pending:
            results[index] = await run_blocking(call, value)

    async with anyio.create_task_group() as task_group:
        for _ in range(min(max_concurrency, len(values))):
            task_group.start_soon(worker)
    return _ordered_results(results)


async def map_ordered_async(
    call: Callable[[Input], Awaitable[Output]],
    inputs: Iterable[Input],
    *,
    max_concurrency: int | None = None,
) -> list[Output]:
    values = list(inputs)
    results: list[Output | _Missing] = [_MISSING] * len(values)
    limiter = _capacity_limiter(max_concurrency)

    async def run_one(index: int, value: Input) -> None:
        results[index] = await call(value)

    if limiter is None:
        async with anyio.create_task_group() as task_group:
            for index, value in enumerate(values):
                task_group.start_soon(run_one, index, value)
        return _ordered_results(results)

    pending = iter(enumerate(values))

    async def worker() -> None:
        for index, value in pending:
            results[index] = await call(value)

    async with anyio.create_task_group() as task_group:
        for _ in range(min(max_concurrency, len(values))):
            task_group.start_soon(worker)
    return _ordered_results(results)


def _ordered_results(results: list[Output | _Missing]) -> list[Output]:
    if any(result is _MISSING for result in results):
        raise RuntimeError("ordered runtime mapping left an incomplete result")
    return [cast(Output, result) for result in results]


def _capacity_limiter(max_concurrency: int | None) -> anyio.CapacityLimiter | None:
    if max_concurrency is None:
        return None
    if max_concurrency < 1:
        raise ValueError("max_concurrency must be positive")
    return anyio.CapacityLimiter(max_concurrency)


__all__ = ["map_ordered_async", "map_ordered_blocking", "run_blocking"]
