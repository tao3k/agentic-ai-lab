# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Deterministic program, payload, and projection for copy measurements."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any

from .._runtime_graph_types import RuntimeGraphEvent, RuntimeState
from ..program import RuntimeGraphProgram, RuntimeGraphRegistries
from ..runtime_graph import RuntimeGraphExecutor, linear_plan

_ExecutionOutcome = tuple[RuntimeState, list[str], list[RuntimeGraphEvent]]
_ProjectedOutcome = tuple[
    RuntimeState,
    tuple[str, ...],
    tuple[RuntimeGraphEvent, ...],
]


def _program_and_executor(
    payload_field_count: int,
) -> tuple[RuntimeGraphProgram, RuntimeGraphExecutor]:
    last_payload_key = _payload_key(payload_field_count - 1)

    async def inspect_payload(state: Mapping[str, Any]) -> dict[str, Any]:
        return {
            "observation-result": (
                state["observation-id"],
                len(state[last_payload_key]),
            )
        }

    program = RuntimeGraphProgram.reference(
        plan=linear_plan("inspect-payload"),
        registries=RuntimeGraphRegistries(
            actions={"inspect-payload": inspect_payload}
        ),
    )
    return program, program._executor()


def _payload_key(index: int) -> str:
    return f"payload-{index:06d}"


def _payload_template(
    payload_field_count: int,
    payload_field_bytes: int,
) -> tuple[tuple[str, bytes], ...]:
    return tuple(
        (
            _payload_key(index),
            bytes([index % 251]) * payload_field_bytes,
        )
        for index in range(payload_field_count)
    )


def _fresh_internal_states(
    program: RuntimeGraphProgram,
    template: Sequence[tuple[str, bytes]],
    items: int,
    *,
    observation_offset: int,
) -> tuple[RuntimeState, ...]:
    return tuple(
        program._internal_state(
            {
                **dict(template),
                "observation-id": observation_offset + index,
            }
        )
        for index in range(items)
    )


def _fresh_equivalent_pair(
    program: RuntimeGraphProgram,
    template: Sequence[tuple[str, bytes]],
    items: int,
    *,
    observation_offset: int,
) -> tuple[tuple[RuntimeState, ...], tuple[RuntimeState, ...]]:
    candidate = _fresh_internal_states(
        program,
        template,
        items,
        observation_offset=observation_offset,
    )
    reference = _fresh_internal_states(
        program,
        template,
        items,
        observation_offset=observation_offset,
    )
    if any(
        left is right or left != right
        for left, right in zip(candidate, reference, strict=True)
    ):
        raise RuntimeError(
            "large-state copy benchmark inputs are not fresh and equivalent"
        )
    return candidate, reference


def _project_outcomes(
    program: RuntimeGraphProgram,
    outcomes: Sequence[_ExecutionOutcome],
) -> tuple[_ProjectedOutcome, ...]:
    return tuple(
        (
            program._public_state(state),
            tuple(trace),
            tuple(program._public_event(event) for event in events),
        )
        for state, trace, events in outcomes
    )


def _assert_semantics_equal(
    candidate: Sequence[_ProjectedOutcome],
    reference: Sequence[_ProjectedOutcome],
) -> None:
    if candidate != reference:
        raise RuntimeError(
            "large-state copy benchmark candidate/reference semantic mismatch"
        )
