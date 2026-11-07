# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import anyio
import pytest

from agentic_ai_lab_runtime.program import RuntimeGraphProgram, RuntimeGraphRegistries
from agentic_ai_lab_runtime.runtime_graph import (
    END,
    START,
    RuntimeGraphConditionalEdge,
    RuntimeGraphEdge,
    RuntimeGraphExecutor,
    RuntimeGraphInterrupt,
    RuntimeGraphInterrupted,
    RuntimeGraphPlan,
    linear_plan,
)
def test_runtime_graph_executor_anyio_invocation() -> None:
    executor = RuntimeGraphExecutor(
        linear_plan("load"), {"load": lambda state: {"value": state["value"] + 1}}
    )

    async def scenario() -> None:
        assert await executor.ainvoke({"value": 1}) == {"value": 2}
        assert await executor.abatch(
            [{"value": 1}, {"value": 4}], max_concurrency=2
        ) == [{"value": 2}, {"value": 5}]
        chunks = [
            chunk
            async for chunk in executor.astream({"value": 1}, stream_mode="values")
        ]
        assert chunks == [{"value": 2}]

    anyio.run(scenario)


def test_runtime_graph_program_anyio_invocation() -> None:
    registries = RuntimeGraphRegistries(
        actions={"load": lambda state: {"value": state["value"] + 1}}
    )
    program = RuntimeGraphProgram.reference(
        plan=linear_plan("load"), registries=registries
    )

    async def scenario() -> None:
        assert await program.ainvoke({"value": 1}) == {"value": 2}
        assert await program.abatch(
            [{"value": 1}, {"value": 4}], max_concurrency=2
        ) == [{"value": 2}, {"value": 5}]
        chunks = [
            chunk async for chunk in program.astream({"value": 1}, stream_mode="values")
        ]
        assert chunks == [{"value": 2}]

    anyio.run(scenario)


def test_runtime_graph_program_abatch_prepares_once_per_call_and_refreshes_registries(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    actions = {"load": lambda state: {"value": state["value"] + 1}}
    program = RuntimeGraphProgram.reference(
        plan=linear_plan("load"),
        registries=RuntimeGraphRegistries(actions=actions),
    )
    preparation_counts = [0, 0]
    validated_plan = program._validated_plan
    make_executor = program._executor

    def counted_validated_plan():
        preparation_counts[0] += 1
        return validated_plan()

    def counted_executor():
        preparation_counts[1] += 1
        return make_executor()

    monkeypatch.setattr(program, "_validated_plan", counted_validated_plan)
    monkeypatch.setattr(program, "_executor", counted_executor)
    inputs = [{"value": 1}, {"value": 4}]

    async def scenario():
        first = await program.abatch(inputs, max_concurrency=2)
        actions["load"] = lambda state: {"value": state["value"] + 10}
        second = await program.abatch(inputs, max_concurrency=2)
        actions["load"] = lambda state: RuntimeGraphInterrupt(state["value"])
        with pytest.raises(ExceptionGroup) as raised:
            await program.abatch([{"value": 7}], max_concurrency=1)
        return first, second, raised.value

    first, second, raised = anyio.run(scenario)
    assert preparation_counts == [3, 3]
    assert first == [{"value": 2}, {"value": 5}]
    assert second == [{"value": 11}, {"value": 14}]
    assert inputs == [{"value": 1}, {"value": 4}]
    first[0]["value"] = 99
    assert inputs[0] == {"value": 1} and first[1] == {"value": 5}
    interrupted = next(
        exc for exc in raised.exceptions if isinstance(exc, RuntimeGraphInterrupted)
    )
    assert interrupted.state == {"value": 7}
    assert interrupted.validation_receipt == program.describe()
    assert interrupted.plan_digest == program.describe_receipt().plan_digest


def test_runtime_graph_program_empty_abatch_skips_preparation(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    program = RuntimeGraphProgram.reference(
        plan=linear_plan("missing"),
        registries=RuntimeGraphRegistries(),
    )
    preparation_calls: list[str] = []
    monkeypatch.setattr(
        program, "_validated_plan", lambda: preparation_calls.append("validation")
    )
    monkeypatch.setattr(
        program, "_executor", lambda: preparation_calls.append("executor")
    )

    async def scenario() -> list[dict[str, object]]:
        result = await program.abatch(iter(()))
        with pytest.raises(ValueError, match="max_concurrency must be positive"):
            await program.abatch(iter(()), max_concurrency=0)
        return result

    assert anyio.run(scenario) == []
    assert preparation_calls == []
def test_runtime_graph_executor_awaits_async_action_and_router() -> None:
    async def load(state):
        await anyio.sleep(0)
        return {"route": "right"}

    async def route(state):
        await anyio.sleep(0)
        return state["route"]

    executor = RuntimeGraphExecutor(
        RuntimeGraphPlan(
            nodes=("load", "left", "right"),
            edges=(
                RuntimeGraphEdge(START, "load"),
                RuntimeGraphEdge("left", END),
                RuntimeGraphEdge("right", END),
            ),
            conditional_edges=(
                RuntimeGraphConditionalEdge(
                    "load", "choose", {"left": "left", "right": "right"}
                ),
            ),
        ),
        {
            "load": load,
            "left": lambda state: {"value": "left"},
            "right": lambda state: {"value": "right"},
        },
        routers={"choose": route},
    )

    async def scenario() -> None:
        state, trace = await executor.ainvoke_with_trace({})
        assert state["value"] == "right"
        assert trace == ["load", "right"]

    anyio.run(scenario)


def test_runtime_graph_program_awaits_async_action() -> None:
    async def load(state):
        await anyio.sleep(0)
        return {"value": state["value"] + 1}

    registries = RuntimeGraphRegistries(actions={"load": load})
    program = RuntimeGraphProgram.reference(plan=linear_plan("load"), registries=registries)

    async def scenario() -> None:
        assert await program.ainvoke({"value": 1}) == {"value": 2}
        chunks = [
            chunk async for chunk in program.astream({"value": 2}, stream_mode="values")
        ]
        assert chunks == [{"value": 3}]

    anyio.run(scenario)


def test_runtime_graph_program_abatch_bounds_concurrency_and_preserves_order() -> None:
    async def scenario() -> None:
        active = 0
        peak = 0
        started = 0
        saturated = anyio.Event()
        third_started = anyio.Event()
        release = anyio.Event()
        results: list[dict[str, int]] | None = None

        async def load(state):
            nonlocal active, peak, started
            started += 1
            active += 1
            peak = max(peak, active)
            if started == 2:
                saturated.set()
            if started == 3:
                third_started.set()
            try:
                await release.wait()
                return {"value": state["value"] * 2}
            finally:
                active -= 1

        program = RuntimeGraphProgram.reference(
            plan=linear_plan("load"),
            registries=RuntimeGraphRegistries(actions={"load": load}),
        )

        async def run_batch() -> None:
            nonlocal results
            results = await program.abatch(
                [{"value": value} for value in range(6)],
                max_concurrency=2,
            )

        with anyio.fail_after(2):
            async with anyio.create_task_group() as task_group:
                task_group.start_soon(run_batch)
                await saturated.wait()
                assert peak == 2
                for _ in range(3):
                    await anyio.sleep(0)
                assert not third_started.is_set()
                release.set()

        assert results == [{"value": value * 2} for value in range(6)]
        assert active == 0

    anyio.run(scenario)


def test_runtime_graph_program_abatch_propagates_cancellation() -> None:
    async def scenario() -> None:
        active = 0
        stopped = 0
        saturated = anyio.Event()

        async def load(state):
            nonlocal active, stopped
            active += 1
            if active == 2:
                saturated.set()
            try:
                await anyio.sleep_forever()
            finally:
                active -= 1
                stopped += 1

        program = RuntimeGraphProgram.reference(
            plan=linear_plan("load"),
            registries=RuntimeGraphRegistries(actions={"load": load}),
        )

        async def run_batch() -> None:
            await program.abatch(
                [{"value": value} for value in range(4)],
                max_concurrency=2,
            )

        with anyio.fail_after(2):
            async with anyio.create_task_group() as task_group:
                task_group.start_soon(run_batch)
                await saturated.wait()
                task_group.cancel_scope.cancel()

        assert active == 0
        assert stopped == 2

    anyio.run(scenario)


def test_runtime_graph_program_astream_respects_consumer_backpressure() -> None:
    async def scenario() -> None:
        executed: list[str] = []

        async def first(state):
            executed.append("first")
            return {"first": True}

        async def second(state):
            executed.append("second")
            return {"second": True}

        program = RuntimeGraphProgram.reference(
            plan=linear_plan("first", "second"),
            registries=RuntimeGraphRegistries(
                actions={"first": first, "second": second}
            ),
        )
        stream = program.astream({}, stream_mode="updates")

        first_chunk = await anext(stream)
        assert first_chunk == {"first": {"first": True}}
        assert executed == ["first"]

        await stream.aclose()
        assert executed == ["first"]

    anyio.run(scenario)
