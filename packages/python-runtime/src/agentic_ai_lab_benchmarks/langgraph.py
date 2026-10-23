# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""langgraph benchmark cases."""
from typing import Any
from collections.abc import Mapping
from .common import (
    AgentRouterState, ApprovalState, HandoffState, LongGraphState, Subject,
    _agent_input, _checksum, _classify, _linear_node_names,
)
from .model import BenchmarkCase

def make_langgraph_router_agent() -> Subject:
    from langgraph.graph import END, START, StateGraph

    def classify(state: AgentRouterState) -> AgentRouterState:
        trace = [*state.get('trace', ()), 'classify']
        return {'intent': _classify(state['question']), 'trace': trace}

    def route(state: AgentRouterState) -> str:
        return state['intent']

    def retrieve(state: AgentRouterState) -> AgentRouterState:
        trace = [*state.get('trace', ()), 'retrieve']
        return {'documents': ['policy-proof.org', 'checkpoint-contract.org'], 'trace': trace}

    def tool(state: AgentRouterState) -> AgentRouterState:
        trace = [*state.get('trace', ()), 'tool']
        return {'tool_result': 'sandbox-scope:read-only', 'trace': trace}

    def handoff(state: AgentRouterState) -> AgentRouterState:
        trace = [*state.get('trace', ()), 'handoff']
        return {'tool_result': 'reviewer:human-review', 'trace': trace}

    def finalize(state: AgentRouterState) -> AgentRouterState:
        trace = [*state.get('trace', ()), 'finalize']
        if state.get('documents'):
            answer = 'rag:proof-docs'
        elif state.get('intent') == 'tool':
            answer = 'tool:permission-reviewed'
        else:
            answer = 'handoff:approval-required'
        return {'answer': answer, 'trace': trace}
    graph = StateGraph(AgentRouterState)
    graph.add_node('classify', classify)
    graph.add_node('retrieve', retrieve)
    graph.add_node('tool', tool)
    graph.add_node('handoff', handoff)
    graph.add_node('finalize', finalize)
    graph.add_edge(START, 'classify')
    graph.add_conditional_edges('classify', route, {'rag': 'retrieve', 'tool': 'tool', 'handoff': 'handoff'})
    graph.add_edge('retrieve', 'finalize')
    graph.add_edge('tool', 'finalize')
    graph.add_edge('handoff', 'finalize')
    graph.add_edge('finalize', END)
    app = graph.compile()

    def subject(iteration: int) -> Any:
        return app.invoke({**_agent_input(iteration), 'trace': []})
    return subject

def make_langgraph_handoff_reducer() -> Subject:
    from langgraph.graph import END, START, StateGraph
    from langgraph.types import Send

    def supervisor(state: HandoffState) -> HandoffState:
        return {'tasks': ['retrieve-context', 'review-policy', 'check-sandbox'], 'messages': ['supervisor:assigned']}

    def dispatch(state: HandoffState):
        return [Send('worker', {'task': task, 'messages': []}) for task in state['tasks']]

    def worker(state: HandoffState) -> HandoffState:
        return {'messages': [f"worker:{state['task']}"]}

    def join(state: HandoffState) -> HandoffState:
        return {'final': '|'.join(state['messages'])}
    graph = StateGraph(HandoffState)
    graph.add_node('supervisor', supervisor)
    graph.add_node('worker', worker)
    graph.add_node('join', join)
    graph.add_edge(START, 'supervisor')
    graph.add_conditional_edges('supervisor', dispatch, ['worker'])
    graph.add_edge('worker', 'join')
    graph.add_edge('join', END)
    app = graph.compile()

    def subject(iteration: int) -> Any:
        return app.invoke({'tasks': [], 'messages': [], 'final': ''})
    return subject

def make_langgraph_interrupt_resume() -> Subject:
    from langgraph.checkpoint.memory import InMemorySaver
    from langgraph.graph import END, START, StateGraph
    from langgraph.types import Command, interrupt

    def draft(state: ApprovalState) -> ApprovalState:
        return {'draft': 'ship-policy-change'}

    def approve(state: ApprovalState) -> ApprovalState:
        decision = interrupt({'draft': state['draft'], 'kind': 'approval'})
        return {'approved': bool(decision.get('approved'))}

    def finalize(state: ApprovalState) -> ApprovalState:
        return {'final': 'released' if state.get('approved') else 'blocked'}
    graph = StateGraph(ApprovalState)
    graph.add_node('draft', draft)
    graph.add_node('approve', approve)
    graph.add_node('finalize', finalize)
    graph.add_edge(START, 'draft')
    graph.add_edge('draft', 'approve')
    graph.add_edge('approve', 'finalize')
    graph.add_edge('finalize', END)
    app = graph.compile(checkpointer=InMemorySaver())

    def subject(iteration: int) -> Any:
        config = {'configurable': {'thread_id': f'approval-{iteration}'}}
        first = app.invoke({'approved': False, 'draft': '', 'final': ''}, config=config)
        if '__interrupt__' not in first:
            raise RuntimeError('expected LangGraph interrupt')
        return app.invoke(Command(resume={'approved': True}), config=config)
    return subject

def make_langgraph_long_graph() -> Subject:
    from langgraph.graph import END, START, StateGraph
    graph = StateGraph(LongGraphState)
    nodes = _linear_node_names()
    for name in nodes:

        def node(state: LongGraphState, node_name: str=name) -> LongGraphState:
            return {'value': int(state.get('value', 0)) + 1, 'trace': [node_name]}
        graph.add_node(name, node)
    graph.add_edge(START, nodes[0])
    for left, right in zip(nodes, nodes[1:]):
        graph.add_edge(left, right)
    graph.add_edge(nodes[-1], END)
    app = graph.compile()

    def subject(iteration: int) -> Any:
        return app.invoke({'value': iteration, 'trace': []})
    return subject

def make_langgraph_router_stream() -> Subject:
    from langgraph.graph import END, START, StateGraph

    def classify(state: AgentRouterState) -> AgentRouterState:
        return {'intent': _classify(state['question']), 'trace': ['classify']}

    def route(state: AgentRouterState) -> str:
        return state['intent']

    def retrieve(state: AgentRouterState) -> AgentRouterState:
        return {'documents': ['policy-proof.org'], 'trace': ['retrieve']}

    def tool(state: AgentRouterState) -> AgentRouterState:
        return {'tool_result': 'sandbox-scope:read-only', 'trace': ['tool']}

    def handoff(state: AgentRouterState) -> AgentRouterState:
        return {'tool_result': 'reviewer:human-review', 'trace': ['handoff']}

    def finalize(state: AgentRouterState) -> AgentRouterState:
        return {'answer': state.get('intent', 'unknown'), 'trace': ['finalize']}
    graph = StateGraph(AgentRouterState)
    graph.add_node('classify', classify)
    graph.add_node('retrieve', retrieve)
    graph.add_node('tool', tool)
    graph.add_node('handoff', handoff)
    graph.add_node('finalize', finalize)
    graph.add_edge(START, 'classify')
    graph.add_conditional_edges('classify', route, {'rag': 'retrieve', 'tool': 'tool', 'handoff': 'handoff'})
    graph.add_edge('retrieve', 'finalize')
    graph.add_edge('tool', 'finalize')
    graph.add_edge('handoff', 'finalize')
    graph.add_edge('finalize', END)
    app = graph.compile()

    def subject(iteration: int) -> Any:
        return tuple(app.stream({**_agent_input(iteration), 'trace': []}, stream_mode='updates'))
    return subject

def cases() -> tuple[BenchmarkCase, ...]:
    return (BenchmarkCase('langgraph-router-agent-native', 'langgraph-native', 'LangGraph conditional policy router.', ('state-graph', 'conditional-edge', 'policy-router', 'agent-state'), make_langgraph_router_agent, 200), BenchmarkCase('langgraph-handoff-reducer-native', 'langgraph-native', 'LangGraph Send handoff and reducer aggregation.', ('state-graph', 'send', 'multi-agent-handoff', 'reducer'), make_langgraph_handoff_reducer, 200), BenchmarkCase('langgraph-interrupt-resume-native', 'langgraph-native', 'LangGraph checkpoint-backed interrupt and resume.', ('interrupt', 'resume', 'checkpoint', 'human-in-loop'), make_langgraph_interrupt_resume, 100), BenchmarkCase('langgraph-long-graph-native', 'langgraph-native', 'LangGraph 32-node linear graph.', ('state-graph', 'long-graph', 'scale', 'linear-graph'), make_langgraph_long_graph, 100), BenchmarkCase('langgraph-router-stream-native', 'langgraph-native', 'LangGraph conditional router stream consumption.', ('state-graph', 'stream', 'events', 'conditional-edge'), make_langgraph_router_stream, 200))
