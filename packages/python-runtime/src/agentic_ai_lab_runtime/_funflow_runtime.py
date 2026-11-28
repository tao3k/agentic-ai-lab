# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""AnyIO structured-concurrency executor for FunFlow DAG projections."""

from __future__ import annotations

import inspect
import time
from collections.abc import Mapping, Sequence
from typing import Any

import anyio

from ._funflow_types import (
    FunFlowDag,
    FunFlowPlanProjection,
    FunFlowRunReceipt,
    FunFlowRuntimeError,
    FunFlowRuntimeState,
    FunFlowStep,
    FunFlowStepAction,
    FunFlowStepReceipt,
)


class AnyioFunFlowRuntime:
    """Structured-concurrency executor for FunFlow DAG projections."""

    async def run(
        self,
        dag: FunFlowDag | FunFlowPlanProjection,
        state: FunFlowRuntimeState | None = None,
    ) -> FunFlowRunReceipt:
        dag = _coerce_projection(dag)
        pending = {step.name: step for step in dag.steps}
        _validate_dag(pending)
        completed: set[str] = set()
        runtime_state: dict[str, Any] = dict(state or {})
        receipts: list[FunFlowStepReceipt] = []
        trace: list[str] = []
        max_wave_width = 0
        started = time.perf_counter_ns()

        while pending:
            ready = tuple(
                name
                for name, step in pending.items()
                if all(dependency in completed for dependency in step.needs)
            )
            if not ready:
                raise FunFlowRuntimeError("FunFlow DAG has unresolved dependencies")
            max_wave_width = max(max_wave_width, len(ready))
            wave_results = await self._run_wave(
                tuple(pending[name] for name in ready), runtime_state
            )
            for name in ready:
                step_receipt, patch = wave_results[name]
                runtime_state.update(patch)
                receipts.append(step_receipt)
                trace.append(name)
                completed.add(name)
                del pending[name]

        elapsed = (time.perf_counter_ns() - started) // 1_000
        return FunFlowRunReceipt(
            status="passed",
            elapsed_micros=elapsed,
            trace=tuple(trace),
            steps=tuple(receipts),
            state=runtime_state,
            max_wave_width=max_wave_width,
        )

    async def _run_wave(
        self, steps: Sequence[FunFlowStep], state: FunFlowRuntimeState
    ) -> dict[str, tuple[FunFlowStepReceipt, Mapping[str, Any]]]:
        results: dict[str, tuple[FunFlowStepReceipt, Mapping[str, Any]]] = {}

        async def worker(step: FunFlowStep) -> None:
            results[step.name] = await _run_step(step, state)

        async with anyio.create_task_group() as task_group:
            for step in steps:
                task_group.start_soon(worker, step)
        return results


async def _run_step(
    step: FunFlowStep, state: FunFlowRuntimeState
) -> tuple[FunFlowStepReceipt, Mapping[str, Any]]:
    started = time.perf_counter_ns()
    try:
        if step.sandbox.timeout_seconds is None:
            patch = await _call_action(step.action, state)
        else:
            with anyio.fail_after(step.sandbox.timeout_seconds):
                patch = await _call_action(step.action, state)
    except Exception as exc:
        raise FunFlowRuntimeError(f"FunFlow step failed: {step.name}") from exc
    elapsed = (time.perf_counter_ns() - started) // 1_000
    return (
        FunFlowStepReceipt(
            name=step.name,
            status="passed",
            elapsed_micros=elapsed,
            sandbox=step.sandbox.label,
            output_keys=tuple(sorted(patch.keys())),
        ),
        patch,
    )


async def _call_action(
    action: FunFlowStepAction, state: FunFlowRuntimeState
) -> Mapping[str, Any]:
    value = action(state)
    if inspect.isawaitable(value):
        value = await value
    return value


def _validate_dag(steps: Mapping[str, FunFlowStep]) -> None:
    if len(steps) == 0:
        raise FunFlowRuntimeError("FunFlow DAG must contain at least one step")
    for step in steps.values():
        for dependency in step.needs:
            if dependency not in steps:
                raise FunFlowRuntimeError(
                    f"FunFlow step {step.name!r} depends on missing step {dependency!r}"
                )


def _coerce_projection(dag: FunFlowDag | FunFlowPlanProjection) -> FunFlowDag:
    if isinstance(dag, FunFlowPlanProjection):
        if dag.runtime_contract != "yuanxu.anyio.v1":
            raise FunFlowRuntimeError(
                "FunFlow projection requires runtime contract 'yuanxu.anyio.v1'"
            )
        return dag.dag
    return dag


__all__ = ["AnyioFunFlowRuntime"]
