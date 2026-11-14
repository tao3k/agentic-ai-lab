# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Shared FunFlow DAG and sandbox runtime data shapes."""

from __future__ import annotations

from collections.abc import Awaitable, Callable, Mapping
from dataclasses import dataclass, field
from typing import Any, Literal

FunFlowRuntimeState = Mapping[str, Any]
FunFlowStepStatus = Literal["passed", "failed"]
FunFlowStepAction = Callable[
    [FunFlowRuntimeState], Mapping[str, Any] | Awaitable[Mapping[str, Any]]
]


class FunFlowRuntimeError(RuntimeError):
    """Raised when a FunFlow DAG cannot be executed safely."""


@dataclass(frozen=True, slots=True)
class FunFlowSandbox:
    """Sandbox policy metadata enforced by the Python runtime boundary."""

    label: str
    timeout_seconds: float | None = None
    allowed_env: tuple[str, ...] = ()


@dataclass(frozen=True, slots=True)
class FunFlowStep:
    """One executable node in a FunFlow DAG projection."""

    name: str
    action: FunFlowStepAction
    needs: tuple[str, ...] = ()
    sandbox: FunFlowSandbox = field(default_factory=lambda: FunFlowSandbox("default"))


@dataclass(frozen=True, slots=True)
class FunFlowStepReceipt:
    name: str
    status: FunFlowStepStatus
    elapsed_micros: int
    sandbox: str
    output_keys: tuple[str, ...] = ()


@dataclass(frozen=True, slots=True)
class FunFlowRunReceipt:
    status: FunFlowStepStatus
    elapsed_micros: int
    trace: tuple[str, ...]
    steps: tuple[FunFlowStepReceipt, ...]
    state: Mapping[str, Any]
    max_wave_width: int

    def line_receipt(self) -> str:
        return (
            "|agentic-ai-lab-funflow-runtime "
            '(schema: "agentic-ai-lab.funflow-runtime.v1" '
            f'status: "{self.status}" '
            f"steps: {len(self.steps)} "
            f"max-wave-width: {self.max_wave_width} "
            f"elapsed-us: {self.elapsed_micros})|"
        )


@dataclass(frozen=True, slots=True)
class FunFlowDag:
    """Executable DAG payload produced by a FunFlow runtime projection."""

    name: str
    steps: tuple[FunFlowStep, ...]


@dataclass(frozen=True, slots=True)
class FunFlowPlanProjection:
    """Runtime boundary object projected from the Scheme FunFlow facade."""

    dag: FunFlowDag
    schema: str = "yuanxu.funflow-plan-projection.v1"
    origin: str = "use-module funflow"
    runtime_contract: str = "yuanxu.anyio.v1"
    source_map: Mapping[str, str] = field(default_factory=dict)


__all__ = [
    "FunFlowDag",
    "FunFlowPlanProjection",
    "FunFlowRunReceipt",
    "FunFlowRuntimeError",
    "FunFlowRuntimeState",
    "FunFlowSandbox",
    "FunFlowStep",
    "FunFlowStepAction",
    "FunFlowStepReceipt",
    "FunFlowStepStatus",
]
