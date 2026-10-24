# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""agentic_ai_lab benchmark cases."""
from typing import Any
from collections.abc import Mapping
from .common import Subject, _agent_input, _checksum, _classify, _linear_node_names
from .model import BenchmarkCase

def make_poo_executor_router_agent() -> Subject:
    from agentic_ai_lab_runtime.runtime_graph import END, START, RuntimeGraphConditionalEdge, RuntimeGraphEdge, RuntimeGraphExecutor, RuntimeGraphPlan

    def classify(state: Mapping[str, Any]) -> dict[str, Any]:
        return {'intent': _classify(str(state['question'])), 'trace': [*state.get('trace', ()), 'classify']}

    def route(state: Mapping[str, Any]) -> str:
        return str(state['intent'])

    def retrieve(state: Mapping[str, Any]) -> dict[str, Any]:
        return {'documents': ['policy-proof.org', 'checkpoint-contract.org'], 'trace': [*state.get('trace', ()), 'retrieve']}

    def tool(state: Mapping[str, Any]) -> dict[str, Any]:
        return {'tool_result': 'sandbox-scope:read-only', 'trace': [*state.get('trace', ()), 'tool']}

    def handoff(state: Mapping[str, Any]) -> dict[str, Any]:
        return {'tool_result': 'reviewer:human-review', 'trace': [*state.get('trace', ()), 'handoff']}

    def finalize(state: Mapping[str, Any]) -> dict[str, Any]:
        if state.get('documents'):
            answer = 'rag:proof-docs'
        elif state.get('intent') == 'tool':
            answer = 'tool:permission-reviewed'
        else:
            answer = 'handoff:approval-required'
        return {'answer': answer, 'trace': [*state.get('trace', ()), 'finalize']}
    plan = RuntimeGraphPlan(nodes=('classify', 'retrieve', 'tool', 'handoff', 'finalize'), edges=(RuntimeGraphEdge(START, 'classify'), RuntimeGraphEdge('retrieve', 'finalize'), RuntimeGraphEdge('tool', 'finalize'), RuntimeGraphEdge('handoff', 'finalize'), RuntimeGraphEdge('finalize', END)), conditional_edges=(RuntimeGraphConditionalEdge('classify', 'intent-router', {'rag': 'retrieve', 'tool': 'tool', 'handoff': 'handoff'}),), step_limit=20)
    executor = RuntimeGraphExecutor(plan, {'classify': classify, 'retrieve': retrieve, 'tool': tool, 'handoff': handoff, 'finalize': finalize}, routers={'intent-router': route})

    def subject(iteration: int) -> Any:
        state, trace = executor.invoke_with_trace({**_agent_input(iteration), 'trace': []})
        return {'state': state, 'trace': trace}
    return subject

def make_poo_executor_handoff_reducer() -> Subject:
    from agentic_ai_lab_runtime.runtime_graph import END, START, RuntimeGraphEdge, RuntimeGraphExecutor, RuntimeGraphPlan, RuntimeGraphSend

    def supervisor(state: Mapping[str, Any]) -> list[Any]:
        return [RuntimeGraphSend('worker', {'task': task}) for task in ('retrieve-context', 'review-policy', 'check-sandbox')]

    def worker(state: Mapping[str, Any]) -> dict[str, Any]:
        return {'messages': [f"worker:{state['task']}"]}

    def join(state: Mapping[str, Any]) -> dict[str, Any]:
        return {'final': '|'.join(state.get('messages', ()))}

    def append_values(left: Any, right: Any) -> list[Any]:
        return list(left or []) + list(right or [])
    plan = RuntimeGraphPlan(nodes=('supervisor', 'worker', 'join'), edges=(RuntimeGraphEdge(START, 'supervisor'), RuntimeGraphEdge('supervisor', 'worker'), RuntimeGraphEdge('worker', 'join'), RuntimeGraphEdge('join', END)), step_limit=20)
    executor = RuntimeGraphExecutor(plan, {'supervisor': supervisor, 'worker': worker, 'join': join}, reducers={'messages': append_values})

    def subject(iteration: int) -> Any:
        state, trace = executor.invoke_with_trace({'messages': [], 'final': ''})
        return {'state': state, 'trace': trace}
    return subject

def make_poo_executor_interrupt_resume() -> Subject:
    from agentic_ai_lab_runtime.runtime_graph import END, START, RuntimeGraphEdge, RuntimeGraphExecutor, RuntimeGraphInterrupt, RuntimeGraphInterrupted, RuntimeGraphPlan

    def draft(state: Mapping[str, Any]) -> dict[str, Any]:
        return {'draft': 'ship-policy-change'}

    def approve(state: Mapping[str, Any]) -> RuntimeGraphInterrupt:
        return RuntimeGraphInterrupt({'draft': state['draft'], 'kind': 'approval'})

    def finalize(state: Mapping[str, Any]) -> dict[str, Any]:
        return {'final': 'released' if state.get('approved') else 'blocked'}
    plan = RuntimeGraphPlan(nodes=('draft', 'approve', 'finalize'), edges=(RuntimeGraphEdge(START, 'draft'), RuntimeGraphEdge('draft', 'approve'), RuntimeGraphEdge('approve', 'finalize'), RuntimeGraphEdge('finalize', END)), step_limit=20)
    executor = RuntimeGraphExecutor(plan, {'draft': draft, 'approve': approve, 'finalize': finalize})

    def subject(iteration: int) -> Any:
        try:
            executor.invoke_with_trace({'approved': False, 'draft': '', 'final': ''})
        except RuntimeGraphInterrupted as interrupted:
            state, trace, events = executor.resume_interrupted(interrupted, {'approved': True})
            return {'state': state, 'trace': trace, 'events': tuple((e.kind for e in events))}
        raise RuntimeError('expected POO executor interrupt')
    return subject

def make_poo_executor_long_graph() -> Subject:
    from agentic_ai_lab_runtime.runtime_graph import END, START, RuntimeGraphEdge, RuntimeGraphExecutor, RuntimeGraphPlan
    nodes = _linear_node_names()
    actions = {node: lambda state, node_name=node: {'value': int(state.get('value', 0)) + 1} for node in nodes}
    edges = [RuntimeGraphEdge(START, nodes[0])]
    edges.extend((RuntimeGraphEdge(left, right) for left, right in zip(nodes, nodes[1:])))
    edges.append(RuntimeGraphEdge(nodes[-1], END))
    executor = RuntimeGraphExecutor(RuntimeGraphPlan(nodes=nodes, edges=tuple(edges), step_limit=64), actions)

    def subject(iteration: int) -> Any:
        state, trace = executor.invoke_with_trace({'value': iteration})
        return {'state': state, 'trace': trace}
    return subject

def make_poo_executor_router_stream_events() -> Subject:
    from agentic_ai_lab_runtime.runtime_graph import END, START, RuntimeGraphConditionalEdge, RuntimeGraphEdge, RuntimeGraphExecutor, RuntimeGraphPlan

    def classify(state: Mapping[str, Any]) -> dict[str, Any]:
        return {'intent': _classify(str(state['question']))}

    def route(state: Mapping[str, Any]) -> str:
        return str(state['intent'])

    def retrieve(state: Mapping[str, Any]) -> dict[str, Any]:
        return {'answer': 'rag:proof-docs'}

    def tool(state: Mapping[str, Any]) -> dict[str, Any]:
        return {'answer': 'tool:permission-reviewed'}

    def handoff(state: Mapping[str, Any]) -> dict[str, Any]:
        return {'answer': 'handoff:approval-required'}
    plan = RuntimeGraphPlan(nodes=('classify', 'retrieve', 'tool', 'handoff'), edges=(RuntimeGraphEdge(START, 'classify'), RuntimeGraphEdge('retrieve', END), RuntimeGraphEdge('tool', END), RuntimeGraphEdge('handoff', END)), conditional_edges=(RuntimeGraphConditionalEdge('classify', 'intent-router', {'rag': 'retrieve', 'tool': 'tool', 'handoff': 'handoff'}),), step_limit=20)
    executor = RuntimeGraphExecutor(plan, {'classify': classify, 'retrieve': retrieve, 'tool': tool, 'handoff': handoff}, routers={'intent-router': route})

    def subject(iteration: int) -> Any:
        return tuple(((event.kind, event.node) for event in executor.stream_events(_agent_input(iteration))))
    return subject

def make_poo_executor_crewai_sequential() -> Subject:
    from agentic_ai_lab_runtime.crewai import CrewAIAgentSpec, CrewAIFlowSpec, CrewAITaskSpec, create_crewai_flow_executor
    spec = CrewAIFlowSpec(name='crewai', process='sequential', agents=(CrewAIAgentSpec('researcher', role='researcher', goal='classify policy strategy requests', tools=('rag', 'route')), CrewAIAgentSpec('reviewer', role='reviewer', goal='finalize routed policy strategy work', tools=('review',))), tasks=(CrewAITaskSpec('classify', agent='researcher', description='Classify request for the current session.', expected_output='A deterministic route classification.', output_key='classification'), CrewAITaskSpec('finalize', agent='reviewer', description='Finalize the policy result using the classification context.', expected_output='A deterministic final control-plane output.', output_key='answer', context=('classify',))), planning_steps=('classify', 'finalize'), memory_keys=('session_id', 'classification'), knowledge_sources=('policy-proof.org', 'checkpoint-contract.org'), tool_policy={'researcher': ('rag', 'route'), 'reviewer': ('review',)})
    executor = create_crewai_flow_executor(spec)

    def subject(iteration: int) -> Any:
        state, trace = executor.invoke_with_trace({**_agent_input(iteration), 'trace': []})
        return {'state': state, 'trace': trace}
    return subject

def cases() -> tuple[BenchmarkCase, ...]:
    definitions = (('agentic-ai-lab-executor-router-agent', 'conditional-edge', make_poo_executor_router_agent), ('agentic-ai-lab-executor-handoff-reducer', 'handoff-reducer', make_poo_executor_handoff_reducer), ('agentic-ai-lab-executor-interrupt-resume', 'interrupt-resume', make_poo_executor_interrupt_resume), ('agentic-ai-lab-executor-long-graph', 'long-graph', make_poo_executor_long_graph), ('agentic-ai-lab-executor-router-stream-events', 'stream-events', make_poo_executor_router_stream_events), ('agentic-ai-lab-executor-crewai-sequential', 'crewai-sequential', make_poo_executor_crewai_sequential))
    return tuple((BenchmarkCase(name, 'agentic-ai-lab-executor', f'Agentic AI Lab executor {feature} case.', ('runtime-graph', feature, 'executor-only'), factory) for name, feature, factory in definitions))
