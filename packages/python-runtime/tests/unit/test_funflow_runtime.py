# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import time
from pathlib import Path

import anyio
import pytest

from agentic_ai_lab_runtime import load as load_agentic_ai_lab
from agentic_ai_lab_runtime.funflow import (
    AnyioFunFlowRuntime,
    FunFlowDag,
    FunFlowPlanProjection,
    FunFlowRuntimeError,
    FunFlowStep,
    build_funflow_cicd_sandbox_dag,
    build_funflow_cicd_sandbox_projection,
    run_funflow_cicd_sandbox_dag,
)

REPO_ROOT = Path(__file__).resolve().parents[4]
SCHEME_FIXTURE = (
    REPO_ROOT
    / "packages"
    / "python-runtime"
    / "t"
    / "fixtures"
    / "funflow_user_module.ss"
)


def test_funflow_cicd_sandbox_dag_runs_with_parallel_wave() -> None:
    async def scenario() -> None:
        receipt = await run_funflow_cicd_sandbox_dag(fanout=3, commit="abc123")

        assert receipt.status == "passed"
        assert receipt.state["artifact"] == "abc123:package"
        assert receipt.state["sandbox_policy"] == "passed"
        assert receipt.max_wave_width == 4
        assert receipt.trace == (
            "checkout",
            "lint",
            "unit-0",
            "unit-1",
            "unit-2",
            "sandbox-policy",
            "package",
        )
        assert receipt.line_receipt().startswith("|agentic-ai-lab-funflow-runtime ")

    anyio.run(scenario)


def test_funflow_runtime_rejects_missing_dependency() -> None:
    dag = FunFlowDag(
        name="invalid",
        steps=(FunFlowStep("package", lambda state: {}, needs=("build",)),),
    )

    async def scenario() -> None:
        with pytest.raises(FunFlowRuntimeError, match="missing step"):
            await AnyioFunFlowRuntime().run(dag)

    anyio.run(scenario)


def test_funflow_runtime_rejects_wrong_projection_contract() -> None:
    projection = FunFlowPlanProjection(
        dag=FunFlowDag(name="invalid", steps=(FunFlowStep("noop", lambda state: {}),)),
        runtime_contract="agentic-ai-lab.other-runtime.v1",
    )

    async def scenario() -> None:
        with pytest.raises(FunFlowRuntimeError, match="runtime contract"):
            await AnyioFunFlowRuntime().run(projection)

    anyio.run(scenario)


def test_funflow_cicd_sandbox_dag_shape_is_funflow_native() -> None:
    dag = build_funflow_cicd_sandbox_dag(fanout=2)

    assert dag.name == "funflow-cicd-sandbox-dag"
    assert tuple(step.name for step in dag.steps) == (
        "checkout",
        "lint",
        "unit-0",
        "unit-1",
        "sandbox-policy",
        "package",
    )
    assert dag.steps[-2].sandbox.allowed_env == ("CI", "AGENTIC_AI_LAB_POLICY")


def test_funflow_cicd_projection_marks_scheme_facade_origin() -> None:
    projection = build_funflow_cicd_sandbox_projection(fanout=2)

    assert projection.schema == "yuanxu.funflow-plan-projection.v1"
    assert projection.origin == "use-module funflow"
    assert projection.runtime_contract == "yuanxu.anyio.v1"
    assert projection.dag.name == "funflow-cicd-sandbox-dag"
    assert projection.source_map["checkout"].startswith("use-module funflow:")


def test_funflow_scheme_plan_projection_runs_in_python_runtime() -> None:
    projection = load_agentic_ai_lab(
        SCHEME_FIXTURE,
        actions={
            "build": lambda state: {"build": "passed"},
            "test": lambda state: {"test": state["build"]},
            "package": lambda state: {"artifact": f"{state['test']}:artifact"},
        },
        cwd=REPO_ROOT,
    )

    async def scenario() -> None:
        receipt = await AnyioFunFlowRuntime().run(projection)

        assert receipt.status == "passed"
        assert receipt.trace == ("build", "test", "package")
        assert receipt.state["artifact"] == "passed:artifact"
        assert projection.origin == "user-composition funflow"
        assert (
            projection.source_map["build"]
            == "user-composition/funflow/python-runtime-ci/default/build"
        )

    anyio.run(scenario)


def test_funflow_scheme_plan_projection_requires_action_bindings() -> None:
    with pytest.raises(FunFlowRuntimeError, match="missing Python action binding"):
        load_agentic_ai_lab(SCHEME_FIXTURE, actions={}, cwd=REPO_ROOT)


def test_funflow_scheme_load_reuses_projection_cache() -> None:
    actions = {
        "build": lambda state: {"build": "passed"},
        "test": lambda state: {"test": state["build"]},
        "package": lambda state: {"artifact": f"{state['test']}:artifact"},
    }
    load_agentic_ai_lab(SCHEME_FIXTURE, actions=actions, cwd=REPO_ROOT)

    started = time.perf_counter()
    for _ in range(20):
        projection = load_agentic_ai_lab(SCHEME_FIXTURE, actions=actions, cwd=REPO_ROOT)
    elapsed = time.perf_counter() - started

    assert projection.origin == "user-composition funflow"
    assert elapsed < 0.25
