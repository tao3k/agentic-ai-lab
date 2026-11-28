# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from collections import Counter
from collections.abc import Sequence
from random import Random

import pytest

from agentic_ai_lab_runtime.benchmarks._composition_lifecycle_planner import (
    _PlannedAgentSequence,
    plan_composition_workload,
)
from agentic_ai_lab_runtime.benchmarks._composition_lifecycle_workload import ArrivalSchedule


def test_plans_one_bounded_group_with_explicit_composition() -> None:
    workload = plan_composition_workload(
        4,
        tenant_count=1,
        agents_per_group=4,
        role_ids=("research", "verify"),
        policy_ids=("fast", "strict"),
        capability_set_ids=("web", "code"),
        step_budget=15,
        tool_call_budget=30,
    )

    assert workload.realized_total_agents == 4
    assert workload.group_count == 1
    assert workload.groups[0].member_count == 4
    assert workload.agents[0].parent_agent_id is None
    assert all(
        agent.parent_agent_id == workload.agents[0].agent_id
        for agent in workload.agents[1:]
    )
    assert [agent.role_id for agent in workload.agents] == [
        "research",
        "verify",
        "research",
        "verify",
    ]
    assert [agent.policy_id for agent in workload.agents] == [
        "fast",
        "strict",
        "fast",
        "strict",
    ]
    assert [agent.capability_set_id for agent in workload.agents] == [
        "web",
        "code",
        "web",
        "code",
    ]


def test_ramp_schedule_preserves_logical_and_effective_time() -> None:
    schedule = ArrivalSchedule(
        mode="ramp",
        initial_wave_size=5,
        wave_size=1,
        wave_interval_ms=700,
        simulation_time_scale=100,
    )
    workload = plan_composition_workload(
        8,
        tenant_count=1,
        agents_per_group=8,
        arrival=schedule,
    )

    assert [agent.logical_eligible_at_ms for agent in workload.agents] == [
        0,
        0,
        0,
        0,
        0,
        700,
        1400,
        2100,
    ]
    assert schedule.effective_eligible_at_ms(7) == 21


def test_multitenant_plan_is_fair_and_keeps_partial_groups_explicit() -> None:
    workload = plan_composition_workload(
        5_003,
        tenant_count=12,
        agents_per_group=128,
    )
    tenant_counts = [tenant.agent_count for tenant in workload.tenants]

    assert max(tenant_counts) - min(tenant_counts) == 1
    assert sum(tenant_counts) == 5_003
    assert sum(group.member_count for group in workload.groups) == 5_003
    assert all(1 <= group.member_count <= 128 for group in workload.groups)
    assert any(group.member_count < 128 for group in workload.groups)
    assert workload.group_count == sum(
        tenant.group_count for tenant in workload.tenants
    )


def test_100k_plan_has_no_lost_or_duplicate_agent_membership() -> None:
    workload = plan_composition_workload(
        100_000,
        tenant_count=1_000,
        agents_per_group=128,
        role_ids=("r0", "r1", "r2"),
        policy_ids=("p0", "p1"),
        capability_set_ids=("c0", "c1", "c2", "c3"),
    )
    agents = workload.agents

    assert workload.requested_total_agents == 100_000
    assert workload.realized_total_agents == 100_000
    assert isinstance(agents, Sequence)
    assert isinstance(agents, _PlannedAgentSequence)
    assert not isinstance(agents, tuple)
    assert len(agents) == 100_000
    assert agents[0].agent_id == "agent-000001"
    assert agents[-1].agent_id == "agent-100000"
    assert agents[-1] == agents[99_999]

    group_counts: Counter[str] = Counter()
    for ordinal, agent in enumerate(agents):
        assert agent.agent_id == f"agent-{ordinal + 1:06d}"
        group_counts[agent.group_id] += 1
    assert sum(group_counts.values()) == 100_000
    assert set(group_counts) == {group.group_id for group in workload.groups}
    assert all(
        group_counts[group.group_id] == group.member_count
        for group in workload.groups
    )

    with pytest.raises(IndexError):
        _ = agents[100_000]
    with pytest.raises(IndexError):
        _ = agents[-100_001]

    ordinals = sorted(
        {
            0,
            1,
            127,
            128,
            99_999,
            *Random(0).sample(range(100_000), 16),
        }
    )
    for ordinal in ordinals:
        tenant_index = ordinal % 1_000
        tenant_position = ordinal // 1_000
        group_index, member_index = divmod(tenant_position, 128)
        tenant_id = f"tenant-{tenant_index + 1:04d}"
        main_ordinal = tenant_index + group_index * 128 * 1_000
        agent = agents[ordinal]

        assert agent.tenant_id == tenant_id
        assert agent.group_id == f"{tenant_id}/group-{group_index + 1:04d}"
        assert agent.agent_id == f"agent-{ordinal + 1:06d}"
        assert agent.parent_agent_id == (
            None
            if member_index == 0
            else f"agent-{main_ordinal + 1:06d}"
        )
        assert agent.role_id == ("r0", "r1", "r2")[ordinal % 3]
        assert agent.policy_id == ("p0", "p1")[ordinal % 2]
        assert agent.capability_set_id == ("c0", "c1", "c2", "c3")[
            ordinal % 4
        ]

    assert tuple(agent.agent_id for agent in agents[127:131]) == (
        "agent-000128",
        "agent-000129",
        "agent-000130",
        "agent-000131",
    )
    assert agents[5:0:-2] == (agents[5], agents[3], agents[1])

    small = plan_composition_workload(
        1_000,
        tenant_count=1_000,
        agents_per_group=128,
        role_ids=("r0", "r1", "r2"),
        policy_ids=("p0", "p1"),
        capability_set_ids=("c0", "c1", "c2", "c3"),
    )
    assert isinstance(small.agents, _PlannedAgentSequence)
    assert len(agents._launch_ranges) == len(small.agents._launch_ranges) == 1
    assert len(agents._range_ends) == len(small.agents._range_ends) == 1
    assert len(agents._tenant_ids) == len(small.agents._tenant_ids) == 1_000
    assert not hasattr(agents, "_agents")
    assert not hasattr(small.agents, "_agents")


@pytest.mark.parametrize(
    ("kwargs", "match"),
    [
        ({"total_agents": 0}, "total_agents"),
        ({"tenant_count": 0}, "tenant_count"),
        ({"tenant_count": 3, "total_agents": 2}, "must not exceed"),
        ({"agents_per_group": 0}, "agents_per_group"),
        ({"step_budget": 0}, "step_budget"),
        ({"tool_call_budget": 0}, "tool_call_budget"),
        ({"role_ids": ()}, "role_ids"),
        ({"policy_ids": "default"}, "policy_ids"),
        ({"capability_set_ids": ("",)}, "capability_set_ids"),
    ],
)
def test_rejects_invalid_workload_dimensions(
    kwargs: dict[str, object], match: str
) -> None:
    arguments: dict[str, object] = {
        "total_agents": 4,
        "tenant_count": 1,
        "agents_per_group": 4,
    }
    arguments.update(kwargs)

    with pytest.raises(ValueError, match=match):
        plan_composition_workload(**arguments)  # type: ignore[arg-type]


@pytest.mark.parametrize(
    "schedule",
    [
        ArrivalSchedule(mode="instant"),
        ArrivalSchedule(mode="ramp", initial_wave_size=5, wave_size=2),
    ],
)
def test_schedule_rejects_negative_agent_ordinal(schedule: ArrivalSchedule) -> None:
    with pytest.raises(ValueError, match="ordinal"):
        schedule.logical_eligible_at_ms(-1)


@pytest.mark.parametrize(
    "kwargs",
    [
        {"mode": "unknown"},
        {"initial_wave_size": 0},
        {"wave_size": 0},
        {"wave_interval_ms": -1},
        {"simulation_time_scale": 0},
    ],
)
def test_rejects_invalid_arrival_schedule(kwargs: dict[str, object]) -> None:
    with pytest.raises(ValueError):
        ArrivalSchedule(**kwargs)  # type: ignore[arg-type]
