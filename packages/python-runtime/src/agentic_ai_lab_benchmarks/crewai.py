# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""crewai benchmark cases."""
import json
from typing import Any
from collections.abc import Mapping
from .common import Subject, _agent_input, _checksum, _classify, _linear_node_names
from .model import BenchmarkCase

def make_crewai_sequential_crew_native() -> Subject:
    from crewai import Agent, Crew, Process, Task
    from crewai.llms.base_llm import BaseLLM

    class DeterministicCrewAILLM(BaseLLM):

        def __init__(self) -> None:
            super().__init__(model='agentic-ai-lab-deterministic')

        def call(self, messages: Any, tools: list[Any] | None=None, callbacks: list[Any] | None=None, available_functions: Mapping[str, Any] | None=None, from_task: Any | None=None, from_agent: Any | None=None, response_model: Any | None=None) -> str:
            task_name = str(getattr(from_task, 'name', None) or 'task')
            agent_role = str(getattr(from_agent, 'role', None) or 'agent')
            return json.dumps({'task': task_name, 'agent': agent_role, 'result': 'deterministic-result'}, separators=(',', ':'))
    llm = DeterministicCrewAILLM()
    researcher = Agent(role='researcher', goal='classify policy strategy requests', backstory='Deterministic CrewAI benchmark agent.', llm=llm, verbose=False, max_iter=1, cache=False)
    reviewer = Agent(role='reviewer', goal='finalize routed policy strategy work', backstory='Deterministic CrewAI benchmark reviewer.', llm=llm, verbose=False, max_iter=1, cache=False)
    classify = Task(name='classify', description='Classify request {question} for session {session_id}.', expected_output='A deterministic route classification.', agent=researcher)
    finalize = Task(name='finalize', description='Finalize the policy result using the classification context.', expected_output='A deterministic final control-plane output.', agent=reviewer, context=[classify])
    crew = Crew(agents=[researcher, reviewer], tasks=[classify, finalize], process=Process.sequential, verbose=False, memory=False, planning=False, tracing=False, cache=False)

    def subject(iteration: int) -> Any:
        output = crew.kickoff(inputs=_agent_input(iteration))
        return {'output': str(output), 'tasks': tuple((str(task.name) for task in crew.tasks))}
    return subject

def cases() -> tuple[BenchmarkCase, ...]:
    return (BenchmarkCase('crewai-sequential-crew-native', 'crewai-native', 'CrewAI deterministic sequential crew.', ('crew', 'sequential-process', 'agent', 'task-context'), make_crewai_sequential_crew_native, 50),)
