# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from functools import partial
from typing import Any

import anyio

from agentic_ai_lab_runtime.benchmarks import _large_state_copy_runner as runner
from agentic_ai_lab_runtime.benchmarks import _large_state_copy_sampling as sampling


def test_invocation_pair_uses_same_executor_and_owned_public_routes() -> None:
    class FakeExecutor:
        def __init__(self) -> None:
            self.calls: list[tuple[str, int, int]] = []

        async def _ainvoke_owned_with_events(
            self, state: dict[str, int]
        ) -> tuple[dict[str, int], list[str], list[Any]]:
            self.calls.append(("owned", id(self), id(state)))
            return state, [], []

        async def ainvoke_with_events(
            self, state: dict[str, int]
        ) -> tuple[dict[str, int], list[str], list[Any]]:
            self.calls.append(("public", id(self), id(state)))
            return state, [], []

    executor = FakeExecutor()
    candidate, reference = runner._invocation_pair(executor)
    candidate_state = {"value": 1}
    reference_state = {"value": 1}

    async def scenario() -> None:
        await candidate(candidate_state)
        await reference(reference_state)

    anyio.run(scenario)

    assert executor.calls == [
        ("owned", id(executor), id(candidate_state)),
        ("public", id(executor), id(reference_state)),
    ]


def test_measure_batch_times_only_executor_invocation(monkeypatch) -> None:
    events: list[str] = []
    ticks = iter((100, 160))

    def fake_clock() -> int:
        events.append("clock")
        return next(ticks)

    async def fake_map_ordered_async(
        invoke: Any,
        states: Any,
        *,
        max_concurrency: int | None,
    ) -> list[Any]:
        events.append("invoke")
        return [await invoke(state) for state in states]

    async def invoke(
        state: dict[str, int],
    ) -> tuple[dict[str, int], list[str], list[Any]]:
        events.append("action")
        return state, [], []

    monkeypatch.setattr(sampling, "perf_counter_ns", fake_clock)
    monkeypatch.setattr(
        sampling, "map_ordered_async", fake_map_ordered_async
    )

    elapsed, _outcomes = anyio.run(
        partial(sampling._measure_batch, invoke, ({"value": 1},), 1)
    )

    assert elapsed == 60.0
    assert events == ["clock", "invoke", "action", "clock"]


def test_input_creation_and_projection_stay_outside_measurement(
    monkeypatch,
) -> None:
    events: list[str] = []

    def fake_inputs(
        *args: Any, **kwargs: Any
    ) -> tuple[tuple[dict[str, int], ...], tuple[dict[str, int], ...]]:
        events.append("inputs")
        return ({"value": 1},), ({"value": 1},)

    async def fake_measure(
        *args: Any, **kwargs: Any
    ) -> tuple[float, list[tuple[dict[str, int], list[str], list[Any]]]]:
        events.append("measure")
        return 1.0, [({"value": 1}, [], [])]

    def fake_projection(
        *args: Any, **kwargs: Any
    ) -> tuple[tuple[dict[str, int], tuple[str, ...], tuple[Any, ...]], ...]:
        events.append("projection")
        return (({"value": 1}, (), ()),)

    async def invoke(
        state: dict[str, int],
    ) -> tuple[dict[str, int], list[str], list[Any]]:
        return state, [], []

    monkeypatch.setattr(
        sampling, "_fresh_equivalent_pair", fake_inputs
    )
    monkeypatch.setattr(sampling, "_measure_batch", fake_measure)
    monkeypatch.setattr(sampling, "_project_outcomes", fake_projection)

    anyio.run(
        partial(
            sampling._measure_paired_samples,
            object(),
            invoke,
            invoke,
            (),
            1,
            1,
            1,
        )
    )

    assert events == [
        "inputs",
        "measure",
        "measure",
        "projection",
        "projection",
        "inputs",
        "measure",
        "measure",
        "projection",
        "projection",
    ]
