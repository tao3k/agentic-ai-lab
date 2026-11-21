# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""CrewAI-style deterministic orchestration helpers.

This module does not embed CrewAI's runtime. It models the control-plane
surface that Agentic AI Lab needs to hand to a runtime language: agents, tasks,
crew process, planning, memory, knowledge, and tool policy.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Mapping, Sequence

from .runtime_graph import RuntimeGraphExecutor, RuntimeGraphPlan
from .builder import RuntimeGraphBuilder


@dataclass(frozen=True)
class CrewAIAgentSpec:
    name: str
    role: str
    goal: str
    tools: tuple[str, ...] = ()
    memory_scope: str = "crew"


@dataclass(frozen=True)
class CrewAITaskSpec:
    name: str
    agent: str
    description: str
    expected_output: str
    output_key: str
    context: tuple[str, ...] = ()
    requires_human_input: bool = False


@dataclass(frozen=True)
class CrewAIFlowSpec:
    name: str = "crewai"
    process: str = "sequential"
    agents: tuple[CrewAIAgentSpec, ...] = ()
    tasks: tuple[CrewAITaskSpec, ...] = ()
    planning_steps: tuple[str, ...] = ()
    memory_keys: tuple[str, ...] = ()
    knowledge_sources: tuple[str, ...] = ()
    tool_policy: Mapping[str, tuple[str, ...]] = field(default_factory=dict)


@dataclass(frozen=True)
class CrewAIFlowResult:
    state: Mapping[str, Any]
    trace: tuple[str, ...]
    receipt: Mapping[str, Any]


def _agent_index(spec: CrewAIFlowSpec) -> dict[str, CrewAIAgentSpec]:
    return {agent.name: agent for agent in spec.agents}


def _validate_crewai_flow_spec(spec: CrewAIFlowSpec) -> None:
    if spec.process != "sequential":
        raise ValueError("only sequential CrewAI-style process is supported")
    if not spec.agents:
        raise ValueError("CrewAI-style flow requires at least one agent")
    if not spec.tasks:
        raise ValueError("CrewAI-style flow requires at least one task")
    agents = _agent_index(spec)
    if len(agents) != len(spec.agents):
        raise ValueError("agent names must be unique")
    task_names = {task.name for task in spec.tasks}
    if len(task_names) != len(spec.tasks):
        raise ValueError("task names must be unique")
    for task in spec.tasks:
        if task.agent not in agents:
            raise ValueError(f"task {task.name!r} references missing agent {task.agent!r}")
        for dependency in task.context:
            if dependency not in task_names:
                raise ValueError(
                    f"task {task.name!r} references missing context task {dependency!r}"
                )


def crewai_flow_plan(spec: CrewAIFlowSpec) -> RuntimeGraphPlan:
    _validate_crewai_flow_spec(spec)
    node_names = ["planning", *(f"task:{task.name}" for task in spec.tasks), "crew:finish"]
    builder = RuntimeGraphBuilder(step_limit=len(node_names) + 2)
    builder.add_node("planning", _planning_action(spec))
    for task in spec.tasks:
        builder.add_node(f"task:{task.name}", _task_action(spec, task))
    builder.add_node("crew:finish", _finish_action(spec))
    builder.set_entry_point("planning")
    previous = "planning"
    for task in spec.tasks:
        node = f"task:{task.name}"
        builder.add_edge(previous, node)
        previous = node
    builder.add_edge(previous, "crew:finish")
    builder.set_finish_point("crew:finish")
    return builder.plan()


def create_crewai_flow_executor(spec: CrewAIFlowSpec) -> RuntimeGraphExecutor:
    _validate_crewai_flow_spec(spec)
    node_names = ["planning", *(f"task:{task.name}" for task in spec.tasks), "crew:finish"]
    builder = RuntimeGraphBuilder(step_limit=len(node_names) + 2)
    builder.add_node("planning", _planning_action(spec))
    for task in spec.tasks:
        builder.add_node(f"task:{task.name}", _task_action(spec, task))
    builder.add_node("crew:finish", _finish_action(spec))
    builder.set_entry_point("planning")
    previous = "planning"
    for task in spec.tasks:
        node = f"task:{task.name}"
        builder.add_edge(previous, node)
        previous = node
    builder.add_edge(previous, "crew:finish")
    builder.set_finish_point("crew:finish")
    return builder.compile()


def run_crewai_flow(
    spec: CrewAIFlowSpec, initial_state: Mapping[str, Any] | None = None
) -> CrewAIFlowResult:
    executor = create_crewai_flow_executor(spec)
    state, trace = executor.invoke_with_trace(dict(initial_state or {}), trace_key="trace")
    receipt = crewai_flow_receipt(spec, state, trace)
    return CrewAIFlowResult(state=state, trace=tuple(trace), receipt=receipt)


def crewai_flow_receipt(
    spec: CrewAIFlowSpec, state: Mapping[str, Any], trace: Sequence[str]
) -> Mapping[str, Any]:
    outputs = state.get("task_outputs", {})
    return {
        "kind": "crewai-flow",
        "name": spec.name,
        "process": spec.process,
        "agent_count": len(spec.agents),
        "task_count": len(spec.tasks),
        "planning_steps": tuple(spec.planning_steps),
        "memory_keys": tuple(spec.memory_keys),
        "knowledge_sources": tuple(spec.knowledge_sources),
        "trace": tuple(trace),
        "completed_tasks": tuple(outputs.keys()) if isinstance(outputs, Mapping) else (),
        "finished": state.get("crew_finished") is True,
    }


def _planning_action(spec: CrewAIFlowSpec):
    def action(state: Mapping[str, Any]) -> Mapping[str, Any]:
        planned = tuple(spec.planning_steps) or tuple(task.name for task in spec.tasks)
        return {
            "crew_name": spec.name,
            "crew_process": spec.process,
            "crew_plan": planned,
            "memory": {key: state.get(key) for key in spec.memory_keys},
            "knowledge": tuple(spec.knowledge_sources),
        }

    return action


def _task_action(spec: CrewAIFlowSpec, task: CrewAITaskSpec):
    agents = _agent_index(spec)

    def action(state: Mapping[str, Any]) -> Mapping[str, Any]:
        agent = agents[task.agent]
        allowed_tools = tuple(spec.tool_policy.get(agent.name, agent.tools))
        prior_outputs = state.get("task_outputs", {})
        context = {
            dependency: prior_outputs.get(dependency)
            for dependency in task.context
            if isinstance(prior_outputs, Mapping)
        }
        output = {
            "task": task.name,
            "agent": agent.name,
            "role": agent.role,
            "goal": agent.goal,
            "expected_output": task.expected_output,
            "tools": allowed_tools,
            "context": context,
            "requires_human_input": task.requires_human_input,
        }
        merged_outputs = dict(prior_outputs) if isinstance(prior_outputs, Mapping) else {}
        merged_outputs[task.name] = output
        return {
            "task_outputs": merged_outputs,
            task.output_key: output,
        }

    return action


def _finish_action(spec: CrewAIFlowSpec):
    def action(state: Mapping[str, Any]) -> Mapping[str, Any]:
        outputs = state.get("task_outputs", {})
        completed = tuple(outputs.keys()) if isinstance(outputs, Mapping) else ()
        return {
            "crew_finished": True,
            "crew_summary": {
                "name": spec.name,
                "process": spec.process,
                "completed_tasks": completed,
                "agent_count": len(spec.agents),
                "task_count": len(spec.tasks),
            },
        }

    return action
