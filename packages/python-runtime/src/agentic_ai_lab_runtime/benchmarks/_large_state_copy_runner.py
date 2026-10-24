# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Measurement runner for the large-state ownership-copy benchmark."""

from __future__ import annotations

import os
from collections.abc import Awaitable, Callable
from functools import partial

import anyio

from .._runtime_graph_types import RuntimeState
from ..runtime_graph import RuntimeGraphExecutor
from ._large_state_copy_sampling import _measure_paired_samples
from ._large_state_copy_workload import (
    _ExecutionOutcome,
    _payload_template,
    _program_and_executor,
)
from .anyio_runtime import plan_timing_pairs, summarize_phase
from .large_state_copy import (
    LargeStateCopyBenchmark,
    _validate_inputs,
)

_Invoke = Callable[[RuntimeState], Awaitable[_ExecutionOutcome]]

def run_large_state_copy_benchmarks(
    *,
    target_observations_per_side: int,
    items_per_pair: int | None,
    max_concurrency: int | None,
    payload_field_count: int,
    payload_field_bytes: int,
    relative_tolerance: float,
) -> list[LargeStateCopyBenchmark]:
    _validate_inputs(
        target_observations_per_side,
        items_per_pair,
        max_concurrency,
        payload_field_count,
        payload_field_bytes,
        relative_tolerance,
    )
    assert max_concurrency is not None
    return anyio.run(
        partial(
            _run_benchmarks,
            target_observations_per_side=target_observations_per_side,
            items_per_pair=items_per_pair,
            max_concurrency=max_concurrency,
            payload_field_count=payload_field_count,
            payload_field_bytes=payload_field_bytes,
            relative_tolerance=relative_tolerance,
        )
    )


async def _run_benchmarks(
    *,
    target_observations_per_side: int,
    items_per_pair: int | None,
    max_concurrency: int,
    payload_field_count: int,
    payload_field_bytes: int,
    relative_tolerance: float,
) -> list[LargeStateCopyBenchmark]:
    item_count = (
        items_per_pair
        if items_per_pair is not None
        else max(max_concurrency * 2, 2)
    )
    timing_pairs = plan_timing_pairs(
        target_observations_per_side=target_observations_per_side,
        items_per_pair=item_count,
    )
    program, executor = _program_and_executor(payload_field_count)
    template = _payload_template(
        payload_field_count, payload_field_bytes
    )
    candidate, reference = _invocation_pair(executor)
    candidate_samples, reference_samples = await _measure_paired_samples(
        program,
        candidate,
        reference,
        template,
        timing_pairs,
        item_count,
        max_concurrency,
    )
    cpu_count = getattr(os, "process_cpu_count", os.cpu_count)
    available_cpus = max(cpu_count() or 1, 1)
    anyio_limiter_capacity = max(
        int(anyio.to_thread.current_default_thread_limiter().total_tokens), 1
    )
    summary = summarize_phase(
        phase="steady-fresh-state",
        candidate_samples=candidate_samples,
        reference_samples=reference_samples,
        target_observations_per_side=target_observations_per_side,
        items_per_pair=item_count,
        available_cpus=available_cpus,
        anyio_limiter_capacity=anyio_limiter_capacity,
        selected_capacity=max_concurrency,
        relative_tolerance=relative_tolerance,
        gated=True,
        detail="paired-program-executor-owned-vs-defensive-copy",
    )
    return [
        LargeStateCopyBenchmark(
            phase=summary.phase,
            target_observations_per_side=summary.target_observations_per_side,
            timing_pairs=summary.timing_pairs,
            items_per_pair=summary.items_per_pair,
            available_cpus=summary.available_cpus,
            anyio_limiter_capacity=summary.anyio_limiter_capacity,
            selected_capacity=summary.selected_capacity,
            payload_field_count=payload_field_count,
            payload_field_bytes=payload_field_bytes,
            root_field_count=payload_field_count + 2,
            candidate_median_ns_per_item=(
                summary.candidate_median_ns_per_item
            ),
            candidate_p95_ns_per_item=summary.candidate_p95_ns_per_item,
            reference_median_ns_per_item=(
                summary.reference_median_ns_per_item
            ),
            reference_p95_ns_per_item=summary.reference_p95_ns_per_item,
            ratio=summary.ratio,
            threshold_ratio=summary.threshold_ratio,
            gated=summary.gated,
            passed=summary.passed,
            semantics_verified=True,
            detail=(
                "payload bytes are logical retained payload only; "
                "the measured shallow root copy scales with field count"
            ),
        )
    ]


def _invocation_pair(
    executor: RuntimeGraphExecutor,
) -> tuple[_Invoke, _Invoke]:
    async def candidate(state: RuntimeState) -> _ExecutionOutcome:
        return await executor._ainvoke_owned_with_events(state)

    async def reference(state: RuntimeState) -> _ExecutionOutcome:
        return await executor.ainvoke_with_events(state)

    return candidate, reference
