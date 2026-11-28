# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Paired AB/BA sampling for the large-state copy benchmark."""

from __future__ import annotations

from collections.abc import Awaitable, Callable, Sequence
from functools import partial
from time import perf_counter_ns

from .._anyio_runtime import map_ordered_async
from .._runtime_graph_types import RuntimeState
from ..program import RuntimeGraphProgram
from ._large_state_copy_workload import (
    _ExecutionOutcome,
    _assert_semantics_equal,
    _fresh_equivalent_pair,
    _project_outcomes,
)

_Invoke = Callable[[RuntimeState], Awaitable[_ExecutionOutcome]]


async def _measure_paired_samples(
    program: RuntimeGraphProgram,
    candidate: _Invoke,
    reference: _Invoke,
    payload_template: Sequence[tuple[str, bytes]],
    timing_pairs: int,
    items: int,
    capacity: int,
) -> tuple[list[float], list[float]]:
    await _warm_up(
        program,
        candidate,
        reference,
        payload_template,
        items,
        capacity,
    )
    candidate_samples: list[float] = []
    reference_samples: list[float] = []
    for pair_index in range(timing_pairs):
        candidate_states, reference_states = _fresh_equivalent_pair(
            program,
            payload_template,
            items,
            observation_offset=pair_index * items,
        )
        candidate_call = partial(
            _measure_batch, candidate, candidate_states, capacity
        )
        reference_call = partial(
            _measure_batch, reference, reference_states, capacity
        )
        first_call, second_call = (
            (candidate_call, reference_call)
            if pair_index % 2 == 0
            else (reference_call, candidate_call)
        )
        first = await first_call()
        second = await second_call()
        candidate_measurement, reference_measurement = (
            (first, second) if pair_index % 2 == 0 else (second, first)
        )
        candidate_samples.append(candidate_measurement[0])
        reference_samples.append(reference_measurement[0])
        _assert_semantics_equal(
            _project_outcomes(program, candidate_measurement[1]),
            _project_outcomes(program, reference_measurement[1]),
        )
    return candidate_samples, reference_samples


async def _warm_up(
    program: RuntimeGraphProgram,
    candidate: _Invoke,
    reference: _Invoke,
    payload_template: Sequence[tuple[str, bytes]],
    items: int,
    capacity: int,
) -> None:
    candidate_states, reference_states = _fresh_equivalent_pair(
        program,
        payload_template,
        items,
        observation_offset=-items,
    )
    _candidate_ns, candidate_outcomes = await _measure_batch(
        candidate, candidate_states, capacity
    )
    _reference_ns, reference_outcomes = await _measure_batch(
        reference, reference_states, capacity
    )
    _assert_semantics_equal(
        _project_outcomes(program, candidate_outcomes),
        _project_outcomes(program, reference_outcomes),
    )


async def _measure_batch(
    invoke: _Invoke,
    states: Sequence[RuntimeState],
    capacity: int,
) -> tuple[float, list[_ExecutionOutcome]]:
    started = perf_counter_ns()
    outcomes = await map_ordered_async(
        invoke,
        states,
        max_concurrency=capacity,
    )
    elapsed = max(perf_counter_ns() - started, 1)
    if len(outcomes) != len(states):
        raise RuntimeError(
            "large-state copy benchmark returned an unexpected result count"
        )
    return elapsed / len(states), outcomes
