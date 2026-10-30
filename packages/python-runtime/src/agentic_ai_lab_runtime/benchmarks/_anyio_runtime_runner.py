# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Measurement runner for the AnyIO runtime performance gate."""

from __future__ import annotations

import os
from collections.abc import Awaitable, Callable, Mapping, Sequence
from functools import partial
from time import perf_counter_ns
from typing import Any

import anyio

from .._anyio_runtime import map_ordered_async
from ..program import RuntimeGraphProgram, RuntimeGraphRegistries
from ..runtime_graph import linear_plan
from .anyio_runtime import (
    ANYIO_RUNTIME_MIN_TARGET_OBSERVATIONS_PER_SIDE,
    AnyIORuntimeBenchmark,
    plan_timing_pairs,
    select_runtime_capacity,
    summarize_phase,
)


def run_anyio_runtime_benchmarks(
    *,
    target_observations_per_side: int,
    items_per_pair: int | None,
    max_concurrency: int | None,
    relative_tolerance: float,
    latency_us: int,
) -> list[AnyIORuntimeBenchmark]:
    _validate_inputs(target_observations_per_side, items_per_pair, latency_us)
    return anyio.run(
        partial(
            _run_benchmarks,
            target_observations_per_side=target_observations_per_side,
            items_per_pair=items_per_pair,
            max_concurrency=max_concurrency,
            relative_tolerance=relative_tolerance,
            latency_us=latency_us,
        )
    )


def _validate_inputs(
    target_observations_per_side: int,
    items_per_pair: int | None,
    latency_us: int,
) -> None:
    if (
        target_observations_per_side
        < ANYIO_RUNTIME_MIN_TARGET_OBSERVATIONS_PER_SIDE
    ):
        raise ValueError(
            "target observations per side must be at least "
            f"{ANYIO_RUNTIME_MIN_TARGET_OBSERVATIONS_PER_SIDE}"
        )
    if items_per_pair is not None and items_per_pair < 1:
        raise ValueError("items per pair must be positive")
    if latency_us < 0:
        raise ValueError("latency must be non-negative")


async def _run_benchmarks(
    *,
    target_observations_per_side: int,
    items_per_pair: int | None,
    max_concurrency: int | None,
    relative_tolerance: float,
    latency_us: int,
) -> list[AnyIORuntimeBenchmark]:
    available_cpus = _available_cpu_count()
    default_limiter = anyio.to_thread.current_default_thread_limiter()
    anyio_limiter_capacity = max(int(default_limiter.total_tokens), 1)
    capacity = select_runtime_capacity(
        available_cpus=available_cpus,
        anyio_limiter_capacity=anyio_limiter_capacity,
        requested=max_concurrency,
    )
    item_count = (
        items_per_pair if items_per_pair is not None else max(capacity * 2, 2)
    )
    timing_pairs = plan_timing_pairs(
        target_observations_per_side=target_observations_per_side,
        items_per_pair=item_count,
    )
    action = _action(latency_us)
    program_factory = _program_factory(action)
    cold = await _cold_receipt(
        program_factory,
        action,
        item_count,
        target_observations_per_side,
        available_cpus,
        anyio_limiter_capacity,
        capacity,
        relative_tolerance,
    )
    warm, reused = await _steady_state_receipts(
        program_factory,
        action,
        timing_pairs,
        item_count,
        target_observations_per_side,
        available_cpus,
        anyio_limiter_capacity,
        capacity,
        relative_tolerance,
    )
    return [cold, warm, reused]


def _action(latency_us: int) -> Callable[[Mapping[str, Any]], Awaitable[dict[str, Any]]]:
    latency_seconds = latency_us / 1_000_000

    async def load(state: Mapping[str, Any]) -> dict[str, Any]:
        await anyio.sleep(latency_seconds)
        return {"value": state["value"] + 1}

    return load


def _program_factory(
    load: Callable[[Mapping[str, Any]], Awaitable[dict[str, Any]]],
) -> Callable[[], RuntimeGraphProgram]:
    def program() -> RuntimeGraphProgram:
        return RuntimeGraphProgram.reference(
            plan=linear_plan("load"),
            registries=RuntimeGraphRegistries(actions={"load": load}),
        )

    return program


async def _cold_receipt(
    program_factory: Callable[[], RuntimeGraphProgram],
    action: Callable[[Mapping[str, Any]], Awaitable[dict[str, Any]]],
    items: int,
    target_observations_per_side: int,
    available_cpus: int,
    anyio_limiter_capacity: int,
    capacity: int,
    relative_tolerance: float,
) -> AnyIORuntimeBenchmark:
    values = _inputs(items)
    candidate = await _measure_ns_per_item(
        lambda: program_factory().abatch(values, max_concurrency=capacity), items
    )
    reference = await _measure_ns_per_item(
        lambda: map_ordered_async(
            action, values, max_concurrency=capacity
        ),
        items,
    )
    return summarize_phase(
        phase="cold",
        candidate_samples=(candidate,),
        reference_samples=(reference,),
        target_observations_per_side=target_observations_per_side,
        items_per_pair=items,
        available_cpus=available_cpus,
        anyio_limiter_capacity=anyio_limiter_capacity,
        selected_capacity=capacity,
        relative_tolerance=relative_tolerance,
        gated=False,
        detail="first-use-report-only",
    )


async def _steady_state_receipts(
    program_factory: Callable[[], RuntimeGraphProgram],
    action: Callable[[Mapping[str, Any]], Awaitable[dict[str, Any]]],
    timing_pairs: int,
    items: int,
    target_observations_per_side: int,
    available_cpus: int,
    anyio_limiter_capacity: int,
    capacity: int,
    relative_tolerance: float,
) -> tuple[AnyIORuntimeBenchmark, AnyIORuntimeBenchmark]:
    candidate_program = program_factory()
    values = _inputs(items)
    await candidate_program.abatch(values, max_concurrency=capacity)
    await map_ordered_async(action, values, max_concurrency=capacity)
    warm_samples = await _paired_samples(
        timing_pairs,
        lambda: _inputs(items),
        candidate_program,
        action,
        capacity,
    )
    reused_samples = await _paired_samples(
        timing_pairs,
        lambda: values,
        candidate_program,
        action,
        capacity,
    )
    gated = capacity > 1
    common = {
        "target_observations_per_side": target_observations_per_side,
        "items_per_pair": items,
        "available_cpus": available_cpus,
        "anyio_limiter_capacity": anyio_limiter_capacity,
        "selected_capacity": capacity,
        "relative_tolerance": relative_tolerance,
        "gated": gated,
    }
    return (
        summarize_phase(
            phase="warm",
            candidate_samples=warm_samples[0],
            reference_samples=warm_samples[1],
            detail=(
                "paired-native-bounded-fresh-inputs"
                if gated
                else "single-capacity-report-only"
            ),
            **common,
        ),
        summarize_phase(
            phase="reused-input",
            candidate_samples=reused_samples[0],
            reference_samples=reused_samples[1],
            detail=(
                "paired-native-bounded-reused-inputs"
                if gated
                else "single-capacity-report-only"
            ),
            **common,
        ),
    )


async def _paired_samples(
    timing_pairs: int,
    inputs: Callable[[], tuple[dict[str, int], ...]],
    candidate_program: RuntimeGraphProgram,
    reference_action: Callable[
        [Mapping[str, Any]], Awaitable[dict[str, Any]]
    ],
    capacity: int,
) -> tuple[list[float], list[float]]:
    candidate_samples: list[float] = []
    reference_samples: list[float] = []
    for index in range(timing_pairs):
        values = inputs()
        candidate_call = lambda: candidate_program.abatch(
            values, max_concurrency=capacity
        )
        reference_call = lambda: map_ordered_async(
            reference_action, values, max_concurrency=capacity
        )
        ordered_calls = (
            (candidate_call, candidate_samples, reference_call, reference_samples)
            if index % 2 == 0
            else (reference_call, reference_samples, candidate_call, candidate_samples)
        )
        first_call, first_samples, second_call, second_samples = ordered_calls
        first_samples.append(await _measure_ns_per_item(first_call, len(values)))
        second_samples.append(await _measure_ns_per_item(second_call, len(values)))
    return candidate_samples, reference_samples


async def _measure_ns_per_item(
    call: Callable[[], Awaitable[list[dict[str, Any]]]], items: int
) -> float:
    started = perf_counter_ns()
    results = await call()
    elapsed = max(perf_counter_ns() - started, 1)
    if len(results) != items:
        raise RuntimeError("runtime benchmark returned an unexpected result count")
    return elapsed / items


def _inputs(items: int) -> tuple[dict[str, int], ...]:
    return tuple({"value": index} for index in range(items))


def _available_cpu_count() -> int:
    affinity = getattr(os, "sched_getaffinity", None)
    if affinity is not None:
        try:
            return max(len(affinity(0)), 1)
        except OSError:
            pass
    return max(os.cpu_count() or 1, 1)
