# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""langchain benchmark cases."""
import json
from typing import Any
from collections.abc import Mapping
from .common import Subject, _agent_input, _checksum, _classify, _linear_node_names
from .model import BenchmarkCase

def make_langchain_linear_agent() -> Subject:
    from langchain_core.output_parsers import JsonOutputParser
    from langchain_core.prompts import ChatPromptTemplate
    from langchain_core.runnables import RunnableLambda
    prompt = ChatPromptTemplate.from_messages([('system', 'You are a deterministic policy model for agent flow routing.'), ('human', 'session={session_id}\nquestion={question}')])
    parser = JsonOutputParser()

    def policy_model(prompt_value: Any) -> str:
        text = prompt_value.to_string()
        intent = _classify(text)
        payload = {'intent': intent, 'next': 'retrieve' if intent == 'rag' else 'tool' if intent == 'tool' else 'review', 'confidence': 0.91}
        return json.dumps(payload, separators=(',', ':'))

    def attach_observation(parsed: Mapping[str, Any]) -> dict[str, Any]:
        intent = str(parsed['intent'])
        return {'intent': intent, 'observation': f'{intent}-observation', 'answer': f"final:{parsed['next']}:{intent}"}
    chain = prompt | RunnableLambda(policy_model) | parser | RunnableLambda(attach_observation)

    def subject(iteration: int) -> Any:
        return chain.invoke(_agent_input(iteration))
    return subject

def make_langchain_branch_agent() -> Subject:
    from langchain_core.runnables import RunnableBranch, RunnableLambda

    def classify(payload: Mapping[str, str]) -> dict[str, Any]:
        intent = _classify(payload['question'])
        return {'intent': intent, 'session_id': payload['session_id'], 'question': payload['question']}

    def rag_branch(state: Mapping[str, Any]) -> dict[str, Any]:
        return {'intent': state['intent'], 'documents': ['policy-proof.org', 'checkpoint-contract.org'], 'answer': 'rag:proof-docs'}

    def tool_branch(state: Mapping[str, Any]) -> dict[str, Any]:
        return {'intent': state['intent'], 'tool_result': 'sandbox-scope:read-only', 'answer': 'tool:permission-reviewed'}

    def handoff_branch(state: Mapping[str, Any]) -> dict[str, Any]:
        return {'intent': state['intent'], 'reviewer': 'human-review', 'answer': 'handoff:approval-required'}
    branch = RunnableBranch((lambda state: state['intent'] == 'rag', RunnableLambda(rag_branch)), (lambda state: state['intent'] == 'tool', RunnableLambda(tool_branch)), RunnableLambda(handoff_branch))
    chain = RunnableLambda(classify) | branch

    def subject(iteration: int) -> Any:
        return chain.invoke(_agent_input(iteration))
    return subject

def cases() -> tuple[BenchmarkCase, ...]:
    return (BenchmarkCase('langchain-linear-agent-native', 'langchain-native', 'LangChain prompt/parser/runnable sequence.', ('prompt-template', 'output-parser', 'runnable-sequence', 'agent-policy'), make_langchain_linear_agent, 1000), BenchmarkCase('langchain-branch-tool-native', 'langchain-native', 'LangChain branch routing for RAG, tool, and handoff selection.', ('runnable-branch', 'policy-router', 'tool-selection', 'handoff-route'), make_langchain_branch_agent, 1000))
