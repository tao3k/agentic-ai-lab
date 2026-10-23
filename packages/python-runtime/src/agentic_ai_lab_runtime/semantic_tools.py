# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Provider JSON adapter only; native runtime transport is Scheme datum ABI v1."""
from __future__ import annotations
import json
from typing import Any, Mapping

from .semantic_runtime import SemanticRuntime, SemanticRuntimeError
from . import scheme_wire as wire


def _unique_json_pairs(pairs):
    result = dict(pairs)
    if len(result) != len(pairs):
        raise ValueError("duplicate provider object key")
    return result


def temporal_tool_definition() -> dict[str, Any]:
    """Describe the read-only Temporal operation; Runtime owns argument validation."""
    return {'type': 'function', 'name': 'agentic_ai_lab_temporal_solve',
            'description': 'Evaluate the supplied caller task through the Temporal Library.',
            'parameters': {'type': 'object', 'required': ['datum'],
                           'additionalProperties': False,
                           'properties': {'datum': {'type': 'string'}}}}


def _bound_task(task: Mapping[str, Any], call: Mapping[str, Any]) -> dict[str, Any]:
    if (call.get('type') != 'function_call' or call.get('name') != 'agentic_ai_lab_temporal_solve'
            or not isinstance(call.get('call_id'), str) or not 0 < len(call['call_id']) <= 128):
        raise SemanticRuntimeError('invalid Temporal tool identity', status=3)
    raw = call.get('arguments')
    if not isinstance(raw, str) or len(raw.encode()) > 1048576:
        raise SemanticRuntimeError('invalid Temporal tool argument size', status=3)
    try:
        arguments = json.loads(raw, object_pairs_hook=_unique_json_pairs)
        if not isinstance(arguments, dict) or set(arguments) != {'datum'} or not isinstance(arguments['datum'], str):
            raise ValueError('tool requires exactly one Scheme datum string')
        expected = wire.dumps(dict(task))
        actual = wire.dumps(wire.loads(arguments['datum']))
        if expected != actual:
            raise ValueError('model task differs from the caller current task')
        return wire.loads(expected)
    except (ValueError, TypeError) as error:
        raise SemanticRuntimeError('Temporal tool task binding rejected', status=3) from error


def invoke_temporal_tool(runtime: SemanticRuntime, task: Mapping[str, Any],
                         call: Mapping[str, Any]) -> dict[str, Any]:
    """Execute one bound read-only call; model parameters cannot replace source data."""
    result = runtime.call('temporal.solve', _bound_task(task, call))
    return {'schema': 'agentic-ai-lab.semantic-tool-result', 'callId': call['call_id'],
            'artifactDigest': runtime.artifact_digest, 'result': result}


async def ainvoke_temporal_tool(runtime: SemanticRuntime, task: Mapping[str, Any],
                               call: Mapping[str, Any]) -> dict[str, Any]:
    """Execute the same bound operation using the Runtime owner thread asynchronously."""
    result = await runtime.acall('temporal.solve', _bound_task(task, call))
    return {'schema': 'agentic-ai-lab.semantic-tool-result', 'callId': call['call_id'],
            'artifactDigest': runtime.artifact_digest, 'result': result}
