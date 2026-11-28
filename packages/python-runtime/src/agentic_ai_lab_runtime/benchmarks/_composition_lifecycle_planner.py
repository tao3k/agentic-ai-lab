# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Pure grouping algorithm for deterministic composition benchmark workloads."""

from __future__ import annotations

from bisect import bisect_right
from collections.abc import Sequence
from dataclasses import dataclass
from math import ceil

from ._composition_lifecycle_workload import (
    ArrivalSchedule,
    CompositionWorkload,
    PlannedAgent,
    PlannedExecutionGroup,
    PlannedTenant,
)


@dataclass(frozen=True, slots=True)
class _ProfileCombination:
    role_ids: tuple[str, ...]
    policy_ids: tuple[str, ...]
    capability_set_ids: tuple[str, ...]
    step_budget: int
    tool_call_budget: int


@dataclass(frozen=True, slots=True)
class _LaunchRange:
    start: int
    count: int
    profile: _ProfileCombination

    @property
    def end(self) -> int:
        return self.start + self.count


@dataclass(frozen=True, slots=True)
class _PlannedAgentSequence(Sequence[PlannedAgent]):
    """Compact ordinal view over planned agents.

    Agent objects are projected only when a caller indexes or iterates the view.
    Profile ranges stay compact even when a workload contains many agents.
    """

    _launch_ranges: tuple[_LaunchRange, ...]
    _range_ends: tuple[int, ...]
    _tenant_count: int
    _agents_per_group: int
    _tenant_ids: tuple[str, ...]
    _schedule: ArrivalSchedule
    _agent_id_width: int

    def __post_init__(self) -> None:
        if len(self._launch_ranges) != len(self._range_ends):
            raise ValueError("launch ranges and end ordinals must have equal lengths")
        expected_start = 0
        for launch_range, range_end in zip(
            self._launch_ranges, self._range_ends, strict=True
        ):
            if launch_range.start != expected_start or launch_range.count <= 0:
                raise ValueError("launch ranges must be positive and contiguous")
            if range_end != launch_range.end:
                raise ValueError("launch range end ordinal does not match its range")
            expected_start = range_end

    def __len__(self) -> int:
        return self._range_ends[-1] if self._range_ends else 0

    def __getitem__(
        self, index: int | slice
    ) -> PlannedAgent | tuple[PlannedAgent, ...]:
        if isinstance(index, slice):
            return tuple(
                self[ordinal] for ordinal in range(*index.indices(len(self)))
            )

        ordinal = index
        if ordinal < 0:
            ordinal += len(self)
        if ordinal < 0 or ordinal >= len(self):
            raise IndexError("planned agent index out of range")

        range_index = bisect_right(self._range_ends, ordinal)
        launch_range = self._launch_ranges[range_index]
        local_ordinal = ordinal - launch_range.start
        profile = launch_range.profile

        tenant_index = ordinal % self._tenant_count
        tenant_position = ordinal // self._tenant_count
        group_index, member_index = divmod(
            tenant_position, self._agents_per_group
        )
        tenant_id = self._tenant_ids[tenant_index]
        main_ordinal = (
            tenant_index
            + group_index * self._agents_per_group * self._tenant_count
        )
        main_agent_id = _agent_id(main_ordinal, self._agent_id_width)
        return PlannedAgent(
            tenant_id=tenant_id,
            group_id=f"{tenant_id}/group-{group_index + 1:04d}",
            agent_id=_agent_id(ordinal, self._agent_id_width),
            parent_agent_id=None if member_index == 0 else main_agent_id,
            role_id=profile.role_ids[local_ordinal % len(profile.role_ids)],
            policy_id=profile.policy_ids[local_ordinal % len(profile.policy_ids)],
            capability_set_id=profile.capability_set_ids[
                local_ordinal % len(profile.capability_set_ids)
            ],
            step_budget=profile.step_budget,
            tool_call_budget=profile.tool_call_budget,
            logical_eligible_at_ms=self._schedule.logical_eligible_at_ms(ordinal),
        )


def plan_composition_workload(
    total_agents: int,
    tenant_count: int,
    agents_per_group: int,
    *,
    arrival: ArrivalSchedule | None = None,
    role_ids: Sequence[str] = ("worker",),
    policy_ids: Sequence[str] = ("default",),
    capability_set_ids: Sequence[str] = ("default",),
    step_budget: int = 100,
    tool_call_budget: int = 100,
) -> CompositionWorkload:
    """Plan bounded groups with deterministic round-robin tenant assignment."""

    _validate_dimensions(
        total_agents=total_agents,
        tenant_count=tenant_count,
        agents_per_group=agents_per_group,
        step_budget=step_budget,
        tool_call_budget=tool_call_budget,
    )
    roles = _require_ids("role_ids", role_ids)
    policies = _require_ids("policy_ids", policy_ids)
    capabilities = _require_ids("capability_set_ids", capability_set_ids)
    schedule = arrival or ArrivalSchedule()
    width = max(4, len(str(total_agents)))
    tenant_populations = _tenant_populations(total_agents, tenant_count)
    tenant_ids = _tenant_ids(tenant_count)
    return CompositionWorkload(
        requested_total_agents=total_agents,
        tenant_count=tenant_count,
        agents_per_group=agents_per_group,
        arrival=schedule,
        agents=_plan_agents(
            total_agents=total_agents,
            tenant_count=tenant_count,
            agents_per_group=agents_per_group,
            tenant_ids=tenant_ids,
            schedule=schedule,
            roles=roles,
            policies=policies,
            capabilities=capabilities,
            step_budget=step_budget,
            tool_call_budget=tool_call_budget,
            agent_id_width=width,
        ),
        groups=_plan_execution_groups(
            tenant_ids=tenant_ids,
            tenant_populations=tenant_populations,
            tenant_count=tenant_count,
            agents_per_group=agents_per_group,
            agent_id_width=width,
        ),
        tenants=_plan_tenants(
            tenant_ids=tenant_ids,
            tenant_populations=tenant_populations,
            agents_per_group=agents_per_group,
        ),
    )


def _plan_agents(
    *,
    total_agents: int,
    tenant_count: int,
    agents_per_group: int,
    tenant_ids: tuple[str, ...],
    schedule: ArrivalSchedule,
    roles: tuple[str, ...],
    policies: tuple[str, ...],
    capabilities: tuple[str, ...],
    step_budget: int,
    tool_call_budget: int,
    agent_id_width: int,
) -> Sequence[PlannedAgent]:
    profile = _ProfileCombination(
        role_ids=roles,
        policy_ids=policies,
        capability_set_ids=capabilities,
        step_budget=step_budget,
        tool_call_budget=tool_call_budget,
    )
    launch_range = _LaunchRange(start=0, count=total_agents, profile=profile)
    return _PlannedAgentSequence(
        _launch_ranges=(launch_range,),
        _range_ends=(launch_range.end,),
        _tenant_count=tenant_count,
        _agents_per_group=agents_per_group,
        _tenant_ids=tenant_ids,
        _schedule=schedule,
        _agent_id_width=agent_id_width,
    )


def _plan_execution_groups(
    *,
    tenant_ids: tuple[str, ...],
    tenant_populations: tuple[int, ...],
    tenant_count: int,
    agents_per_group: int,
    agent_id_width: int,
) -> tuple[PlannedExecutionGroup, ...]:
    groups: list[PlannedExecutionGroup] = []
    for tenant_index, (tenant_id, population) in enumerate(
        zip(tenant_ids, tenant_populations, strict=True)
    ):
        for group_index, start in enumerate(range(0, population, agents_per_group)):
            main_ordinal = tenant_index + start * tenant_count
            groups.append(
                PlannedExecutionGroup(
                    tenant_id=tenant_id,
                    group_id=f"{tenant_id}/group-{group_index + 1:04d}",
                    main_agent_id=_agent_id(main_ordinal, agent_id_width),
                    member_count=min(agents_per_group, population - start),
                )
            )
    return tuple(groups)


def _plan_tenants(
    *,
    tenant_ids: tuple[str, ...],
    tenant_populations: tuple[int, ...],
    agents_per_group: int,
) -> tuple[PlannedTenant, ...]:
    return tuple(
        PlannedTenant(
            tenant_id=tenant_id,
            agent_count=population,
            group_count=ceil(population / agents_per_group),
        )
        for tenant_id, population in zip(
            tenant_ids, tenant_populations, strict=True
        )
    )


def _tenant_ids(tenant_count: int) -> tuple[str, ...]:
    width = max(4, len(str(tenant_count)))
    return tuple(
        f"tenant-{index + 1:0{width}d}" for index in range(tenant_count)
    )


def _tenant_populations(total_agents: int, tenant_count: int) -> tuple[int, ...]:
    base, remainder = divmod(total_agents, tenant_count)
    return tuple(base + (index < remainder) for index in range(tenant_count))


def _agent_id(ordinal: int, width: int) -> str:
    return f"agent-{ordinal + 1:0{width}d}"


def _validate_dimensions(
    *,
    total_agents: int,
    tenant_count: int,
    agents_per_group: int,
    step_budget: int,
    tool_call_budget: int,
) -> None:
    _require_positive("total_agents", total_agents)
    _require_positive("tenant_count", tenant_count)
    _require_positive("agents_per_group", agents_per_group)
    _require_positive("step_budget", step_budget)
    _require_positive("tool_call_budget", tool_call_budget)
    if tenant_count > total_agents:
        raise ValueError("tenant_count must not exceed total_agents")


def _require_positive(name: str, value: int) -> None:
    if isinstance(value, bool) or not isinstance(value, int) or value < 1:
        raise ValueError(f"{name} must be a positive integer")


def _require_ids(name: str, values: Sequence[str]) -> tuple[str, ...]:
    if isinstance(values, str):
        raise ValueError(f"{name} must be a non-empty sequence of identifiers")
    normalized = tuple(values)
    if not normalized or any(not isinstance(value, str) or not value for value in normalized):
        raise ValueError(f"{name} must be a non-empty sequence of identifiers")
    return normalized
