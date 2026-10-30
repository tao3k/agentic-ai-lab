# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import pytest

from agentic_ai_lab_runtime import (
    CrewAIAgentSpec,
    CrewAIFlowSpec,
    CrewAITaskSpec,
    create_crewai_flow_executor,
    crewai_flow_plan,
    run_crewai_flow,
)


def _spec() -> CrewAIFlowSpec:
    return CrewAIFlowSpec(
        name="crewai",
        agents=(
            CrewAIAgentSpec(
                name="planner",
                role="planning-agent",
                goal="turn user intent into tasks",
                tools=("search",),
            ),
            CrewAIAgentSpec(
                name="writer",
                role="writer-agent",
                goal="produce final answer",
                tools=("summarize",),
            ),
        ),
        tasks=(
            CrewAITaskSpec(
                name="plan",
                agent="planner",
                description="build a task outline",
                expected_output="task outline",
                output_key="plan_output",
            ),
            CrewAITaskSpec(
                name="write",
                agent="writer",
                description="write final response",
                expected_output="final response",
                output_key="final_output",
                context=("plan",),
            ),
        ),
        planning_steps=("plan", "write"),
        memory_keys=("thread_id",),
        knowledge_sources=("project-docs",),
        tool_policy={
            "planner": ("search",),
            "writer": ("summarize",),
        },
    )


def test_crewai_flow_runs_as_sequential_runtime_graph() -> None:
    result = run_crewai_flow(_spec(), {"thread_id": "thr-1"})

    assert result.trace == ("planning", "task:plan", "task:write", "crew:finish")
    assert result.state["crew_finished"] is True
    assert result.state["memory"] == {"thread_id": "thr-1"}
    assert result.state["knowledge"] == ("project-docs",)
    assert result.state["final_output"]["context"]["plan"]["task"] == "plan"
    assert result.receipt["kind"] == "crewai-flow"
    assert result.receipt["finished"] is True
    assert result.receipt["completed_tasks"] == ("plan", "write")


def test_crewai_flow_plan_matches_public_runtime_graph_surface() -> None:
    plan = crewai_flow_plan(_spec())

    assert plan.nodes == ("planning", "task:plan", "task:write", "crew:finish")
    assert [(edge.source, edge.target) for edge in plan.edges] == [
        ("__start__", "planning"),
        ("planning", "task:plan"),
        ("task:plan", "task:write"),
        ("task:write", "crew:finish"),
        ("crew:finish", "__end__"),
    ]


def test_crewai_flow_executor_can_be_reused_directly() -> None:
    executor = create_crewai_flow_executor(_spec())
    state, trace = executor.invoke_with_trace({"thread_id": "thr-2"}, trace_key="trace")

    assert trace == ["planning", "task:plan", "task:write", "crew:finish"]
    assert state["crew_summary"]["agent_count"] == 2
    assert state["crew_summary"]["task_count"] == 2


def test_crewai_flow_rejects_missing_agent() -> None:
    spec = CrewAIFlowSpec(
        agents=(CrewAIAgentSpec(name="planner", role="planner", goal="plan"),),
        tasks=(
            CrewAITaskSpec(
                name="write",
                agent="missing",
                description="write",
                expected_output="answer",
                output_key="answer",
            ),
        ),
    )

    with pytest.raises(ValueError, match="references missing agent"):
        crewai_flow_plan(spec)


def test_crewai_flow_rejects_unsupported_process() -> None:
    spec = CrewAIFlowSpec(
        process="hierarchical",
        agents=(CrewAIAgentSpec(name="planner", role="planner", goal="plan"),),
        tasks=(
            CrewAITaskSpec(
                name="plan",
                agent="planner",
                description="plan",
                expected_output="plan",
                output_key="plan",
            ),
        ),
    )

    with pytest.raises(ValueError, match="only sequential"):
        create_crewai_flow_executor(spec)
