# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import asyncio
from copy import deepcopy
import pytest
from agentic_ai_lab_runtime.semantic_runtime import SemanticRuntimeError
from semantic_cases import temporal_request

def test_direct_prediction_receives_task_and_native_difference(runtime):
    from agentic_ai_lab_runtime import scheme_wire as wire
    task = temporal_request()
    calls = []
    def predict(supplied):
        calls.append(supplied)
        assert supplied == task
        assert 'rows' not in supplied and 'bindingDigest' not in supplied
        supplied['source']['parents'].clear()
        return '(object ("rows" (list)) ("status" "complete"))'
    observed = []
    def deliver(event):
        observed.append(deepcopy(event))
        event['receipt']['verdict'] = 'mutated'
    result = runtime.predict_temporal_answer(task, predict, observation_sink=deliver)
    assert len(calls) == 1
    assert observed[0]['artifactDigest'] == runtime.artifact_digest
    feedback = result['receipt']
    assert task['source']['parents'] == [['a', 'b'], ['b', 'c']]
    assert feedback['verdict'] == 'contradicted'
    assert feedback['difference'] == {'kind': 'missing-row', 'index': 0, 'expected': ['a', 'b']}
    assert len(feedback['requestDigest']) == 64
    correct = runtime.observe_model_answer(task, wire.dumps({'status': 'complete', 'rows': [['a', 'b'], ['a', 'c']]}))
    assert correct['verdict'] == 'consistent' and correct['difference'] is False
    assert correct['bindingDigest'] == feedback['bindingDigest']


def test_direct_prediction_recomputes_current_source_and_async(runtime):
    task = temporal_request()
    def change_source(supplied):
        task['source']['parents'].clear()
        task['source']['generation'] = task['lens']['generation'] = 2
        return '(object ("rows" (list (list "a" "b") (list "a" "c"))) ("status" "complete"))'
    prior = runtime.call('temporal.solve', task)
    receipt = runtime.predict_temporal_answer(task, change_source)['receipt']
    assert receipt['bindingDigest'] != prior['bindingDigest']
    assert receipt['difference'] == {'kind': 'extra-row', 'index': 0, 'observed': ['a', 'b']}
    async def predict(supplied):
        assert supplied == task
        return '(object ("rows" (list)) ("status" "complete"))'
    observed = []
    async def deliver(event):
        observed.append(event)
    assert asyncio.run(runtime.apredict_temporal_answer(task, predict, observation_sink=deliver))['receipt']['verdict'] == 'consistent'
    assert observed[0]['receipt']['verdict'] == 'consistent'


@pytest.mark.parametrize('output,kind', [
    ('(object ("rows" (list)) ("status" "partial"))', 'status-mismatch'),
    ('(object ("rows" (list (list "a" "z"))) ("status" "complete"))', 'row-mismatch'),
    ('(object ("rows" "bad") ("status" "complete"))', 'candidate-shape'),
    ('(list)', 'candidate-shape'),
])
def test_native_observation_failure_contract(runtime, output, kind):
    assert runtime.observe_model_answer(temporal_request(), output)['difference']['kind'] == kind


def test_native_observation_rejects_duplicate_scheme_fields(runtime):
    with pytest.raises(SemanticRuntimeError, match='inert Scheme datum'):
        runtime.observe_model_answer(temporal_request(), '(object ("rows" (list)) ("rows" (list)) ("status" "complete"))')


