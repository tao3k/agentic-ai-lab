# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Execute one bounded composition group and capture lifecycle timing evidence."""

from __future__ import annotations

from dataclasses import dataclass, field
from time import perf_counter_ns, process_time_ns
from typing import Any, Awaitable, Callable, Mapping

import anyio

from ..program import RuntimeGraphProgram, RuntimeGraphRegistries
from ..runtime_graph import linear_plan
from ._composition_lifecycle_arrival import prepare_runtime_program, run_arrival_batch
from ._composition_lifecycle_projection import (
    CompositionTimingEvidence,
    project_composition_benchmark,
)
from ._composition_lifecycle_receipt import CompositionLifecycleBenchmark
from ._composition_lifecycle_workload import CompositionWorkload, PlannedAgent

AgentAction = Callable[[Mapping[str, Any]], Awaitable[dict[str, Any]]]


@dataclass(slots=True)
class _CompositionObserver:
    started_at_ns: dict[str, int] = field(default_factory=dict)
    finished_at_ns: dict[str, int] = field(default_factory=dict)
    active: int = 0
    peak_active: int = 0

    def start(self, agent_id: str) -> None:
        self.started_at_ns[agent_id] = perf_counter_ns()
        self.active += 1
        self.peak_active = max(self.peak_active, self.active)

    def finish(self, agent_id: str) -> None:
        self.finished_at_ns[agent_id] = perf_counter_ns()
        self.active -= 1

    def evidence(self) -> CompositionTimingEvidence:
        return CompositionTimingEvidence(
            started_at_ns=dict(self.started_at_ns),
            finished_at_ns=dict(self.finished_at_ns),
            peak_active=self.peak_active,
            final_active=self.active,
        )


@dataclass(frozen=True, slots=True)
class _ExecutionSample:
    outputs: list[dict[str, Any]]
    wall_start_ns: int
    barrier_open_ns: int
    aggregate_created_ns: int
    process_elapsed_ns: int


async def measure_composition(
    *,
    workload: CompositionWorkload,
    selected_capacity: int,
    available_cpus: int,
    capacity_source: str,
    capacity_policy: str,
    service_time_ms: float,
) -> CompositionLifecycleBenchmark:
    """Execute one composition group and project its terminal barrier evidence."""

    _validate_single_group(workload)
    observer = _CompositionObserver()
    sample = await _execute_inputs(
        program=_program(observer, service_time_ms),
        inputs=tuple(_agent_input(agent) for agent in workload.agents),
        workload=workload,
        selected_capacity=selected_capacity,
    )
    completed_ids = tuple(
        output["agent_id"]
        for output in sample.outputs
        if output.get("lifecycle_state") == "completed"
    )
    return project_composition_benchmark(
        workload=workload,
        timings=observer.evidence(),
        outputs=sample.outputs,
        completed_ids=completed_ids,
        wall_start_ns=sample.wall_start_ns,
        barrier_open_ns=sample.barrier_open_ns,
        aggregate_created_ns=sample.aggregate_created_ns,
        process_elapsed_ns=sample.process_elapsed_ns,
        selected_capacity=selected_capacity,
        available_cpus=available_cpus,
        capacity_source=capacity_source,
        capacity_policy=capacity_policy,
        service_time_ms=service_time_ms,
    )


async def _execute_inputs(
    *,
    program: RuntimeGraphProgram,
    inputs: tuple[dict[str, Any], ...],
    workload: CompositionWorkload,
    selected_capacity: int,
) -> _ExecutionSample:
    prepared = prepare_runtime_program(program)
    wall_start_ns = perf_counter_ns()
    process_start_ns = process_time_ns()
    outputs = await run_arrival_batch(
        prepared,
        inputs,
        schedule=workload.arrival,
        max_concurrency=selected_capacity,
        wall_start_ns=wall_start_ns,
    )
    barrier_open_ns = perf_counter_ns()
    aggregate_created_ns = perf_counter_ns()
    return _ExecutionSample(
        outputs=outputs,
        wall_start_ns=wall_start_ns,
        barrier_open_ns=barrier_open_ns,
        aggregate_created_ns=aggregate_created_ns,
        process_elapsed_ns=process_time_ns() - process_start_ns,
    )


def _program(
    observer: _CompositionObserver, service_time_ms: float
) -> RuntimeGraphProgram:
    return RuntimeGraphProgram.reference(
        plan=linear_plan("agent"),
        registries=RuntimeGraphRegistries(
            actions={"agent": _agent_action(observer, service_time_ms)}
        ),
    )


def _agent_action(observer: _CompositionObserver, service_time_ms: float) -> AgentAction:
    async def execute(state: Mapping[str, Any]) -> dict[str, Any]:
        agent_id = str(state["agent_id"])
        observer.start(agent_id)
        try:
            await anyio.sleep(service_time_ms / 1_000.0)
            return {"lifecycle_state": "completed"}
        finally:
            observer.finish(agent_id)

    return execute


def _agent_input(agent: PlannedAgent) -> dict[str, Any]:
    return {
        "tenant_id": agent.tenant_id,
        "group_id": agent.group_id,
        "agent_id": agent.agent_id,
        "parent_agent_id": agent.parent_agent_id,
        "role_id": agent.role_id,
        "policy_id": agent.policy_id,
        "capability_set_id": agent.capability_set_id,
        "lifecycle_state": "queued",
    }


def _validate_single_group(workload: CompositionWorkload) -> None:
    if workload.tenant_count != 1 or workload.group_count != 1:
        raise ValueError("composition measurement requires exactly one group")
