# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""FunFlow CI/CD sandbox DAG fixture and benchmark runner."""

from __future__ import annotations

import time
from collections.abc import Mapping
from typing import Any

import anyio

from ._funflow_runtime import AnyioFunFlowRuntime
from ._funflow_types import (
    FunFlowDag,
    FunFlowPlanProjection,
    FunFlowRunReceipt,
    FunFlowRuntimeError,
    FunFlowRuntimeState,
    FunFlowSandbox,
    FunFlowStep,
)


def build_funflow_cicd_sandbox_dag(*, fanout: int = 4) -> FunFlowDag:
    unit_steps = tuple(_unit_step(index) for index in range(fanout))
    gate_needs = ("lint",) + tuple(step.name for step in unit_steps)
    return FunFlowDag(
        name="funflow-cicd-sandbox-dag",
        steps=(
            FunFlowStep(
                name="checkout",
                action=_checkout,
                sandbox=FunFlowSandbox("source-checkout", timeout_seconds=0.25),
            ),
            FunFlowStep(
                name="lint",
                action=_lint,
                needs=("checkout",),
                sandbox=FunFlowSandbox("tooling", timeout_seconds=0.25),
            ),
            *unit_steps,
            FunFlowStep(
                name="sandbox-policy",
                action=_sandbox_policy_gate,
                needs=gate_needs,
                sandbox=FunFlowSandbox(
                    "poo-policy-gate",
                    timeout_seconds=0.25,
                    allowed_env=("CI", "AGENTIC_AI_LAB_POLICY"),
                ),
            ),
            FunFlowStep(
                name="package",
                action=_package,
                needs=("sandbox-policy",),
                sandbox=FunFlowSandbox("artifact-package", timeout_seconds=0.25),
            ),
        ),
    )


def build_funflow_cicd_sandbox_projection(
    *, fanout: int = 4
) -> FunFlowPlanProjection:
    dag = build_funflow_cicd_sandbox_dag(fanout=fanout)
    return FunFlowPlanProjection(
        dag=dag,
        source_map={step.name: f"use-module funflow:{dag.name}:{step.name}" for step in dag.steps},
    )


async def run_funflow_cicd_sandbox_dag(
    *, fanout: int = 4, commit: str = "HEAD"
) -> FunFlowRunReceipt:
    return await AnyioFunFlowRuntime().run(
        build_funflow_cicd_sandbox_projection(fanout=fanout),
        {"commit": commit},
    )


def benchmark_funflow_cicd_sandbox_dag(
    *, iterations: int, fanout: int
) -> FunFlowRunReceipt:
    async def scenario() -> FunFlowRunReceipt:
        receipt = await run_funflow_cicd_sandbox_dag(fanout=fanout)
        started = time.perf_counter_ns()
        for _ in range(iterations):
            receipt = await run_funflow_cicd_sandbox_dag(fanout=fanout)
        elapsed = (time.perf_counter_ns() - started) // 1_000
        return FunFlowRunReceipt(
            status=receipt.status,
            elapsed_micros=elapsed,
            trace=receipt.trace,
            steps=receipt.steps,
            state=receipt.state,
            max_wave_width=receipt.max_wave_width,
        )

    return anyio.run(scenario)


def _checkout(state: FunFlowRuntimeState) -> Mapping[str, Any]:
    return {"checkout": "ready", "commit": state.get("commit", "HEAD")}


def _lint(state: FunFlowRuntimeState) -> Mapping[str, Any]:
    return {"lint": "passed"}


def _package(state: FunFlowRuntimeState) -> Mapping[str, Any]:
    return {"artifact": f"{state['commit']}:package"}


def _unit_step(index: int) -> FunFlowStep:
    async def action(state: FunFlowRuntimeState) -> Mapping[str, Any]:
        await anyio.sleep(0)
        return {f"unit_{index}": "passed"}

    return FunFlowStep(
        name=f"unit-{index}",
        action=action,
        needs=("checkout",),
        sandbox=FunFlowSandbox("unit-test", timeout_seconds=0.25),
    )


def _sandbox_policy_gate(state: FunFlowRuntimeState) -> Mapping[str, Any]:
    failed = tuple(
        key
        for key, value in state.items()
        if (key == "lint" or key.startswith("unit_")) and value != "passed"
    )
    if failed:
        raise FunFlowRuntimeError(f"sandbox policy gate rejected steps: {failed!r}")
    return {"sandbox_policy": "passed"}


__all__ = [
    "benchmark_funflow_cicd_sandbox_dag",
    "build_funflow_cicd_sandbox_dag",
    "build_funflow_cicd_sandbox_projection",
    "run_funflow_cicd_sandbox_dag",
]
