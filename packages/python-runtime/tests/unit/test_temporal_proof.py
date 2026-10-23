# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
from copy import deepcopy
import os
from pathlib import Path
import pytest
from agentic_ai_lab_runtime.scheme_wire import loads, dumps
from agentic_ai_lab_runtime.semantic_runtime import SemanticRuntimeError

@pytest.fixture
def original_proof():
    path = os.environ.get('AGENTIC_AI_LAB_NATIVE_DERIVATION_ORACLE')
    if not path:
        pytest.skip('original Rust/native joint admission oracle must be configured')
    return loads(Path(path).read_text())

def test_actual_original_joint_proof_parity_and_late_correction(runtime, original_proof):
    request = original_proof['request']
    before = deepcopy(request)
    admitted = runtime.admit_temporal_derivation(request)
    assert admitted == original_proof['expected'] and request == before
    assert admitted['proofAdmitted'] and admitted['mrrRuleEquivalenceVerified'] and admitted['derivationCorrespondenceVerified']
    assert not any(admitted[k] for k in ['sourceAuthenticated', 'selectionAdmitted', 'actionAuthorized', 'durable'])
    task = dict(schema='agentic-ai-lab.temporal-support-request.v1',
        program=dict(identity='native-proof-support', policy='read-only', complete=True, supports=[admitted['support']]),
        journal=deepcopy(request['journal']), asOf=1, validAt=False, budget=128)
    assert runtime.evaluate_temporal_support(task)['conclusions'][0]['status'] == 'supported'
    first = task['journal']['revisions'][0]
    task['journal']['revisions'].append(dict(identity='late-correction',subject=first['subject'],operation='correct',
        predecessor=first['identity'],admitted=2,validRange=deepcopy(first['validRange']),content='changed'))
    task['asOf'] = 2
    assert runtime.evaluate_temporal_support(task)['conclusions'][0]['status'] == 'unsupported'
    task['asOf'] = 1
    assert runtime.evaluate_temporal_support(task)['conclusions'][0]['status'] == 'supported'
    assert runtime.admit_temporal_derivation(request) == admitted

def test_proof_control_is_not_available_as_an_ordinary_c_tool(runtime, original_proof):
    request = original_proof['request']
    with pytest.raises(ValueError, match='host control'):
        runtime.call('$host.temporal.derivation.admit', request)
    assert '$host.temporal.derivation.admit' not in runtime.descriptor['operations']
    result = runtime._ffi.new('agentic_ai_lab_semantic_result *')
    raw = dumps(request).encode()
    try:
        status = runtime._submit_host(lambda:runtime._lib.agentic_ai_lab_python_semantic_call(
            b'$host.temporal.derivation.admit',raw,len(raw),result)).result()
        assert status == 3 and result.status == 3 and result.length == 0 and result.data == runtime._ffi.NULL
    finally:
        runtime._lib.agentic_ai_lab_python_semantic_release(result)

@pytest.mark.parametrize('mode', ['schema','flags','rule','direct_support','output','source_content','source_binding',
                                  'missing_fact','duplicate_fact','unused_fact','missing_derivation','source_marker',
                                  'generation','catalog_type','bound','node_bound','unknown_program_field'])
def test_forged_or_incomplete_joint_evidence_rejected(runtime, original_proof, mode):
    request = deepcopy(original_proof['request'])
    p = request['projection']
    if mode == 'schema': request['schema'] = 'agentic-ai-lab.temporal-derivation-admit-request.v2'
    elif mode == 'flags': request['proofAdmitted'] = True
    elif mode == 'rule': p['derivations'][1]['rule'] = p['derivations'][0]['rule']
    elif mode == 'direct_support': p['derivations'][1]['supports'] = [f['content']['identity'] for f in p['facts'] if f['source']]
    elif mode == 'output': p['rootFact'] = p['facts'][0]['content']['identity']
    elif mode == 'source_content': request['journal']['revisions'][0]['content'] = 'forged'
    elif mode == 'source_binding': request['sourceBindings'][0]['revision'] = 'unknown'
    elif mode == 'missing_fact': p['facts'].pop(0)
    elif mode == 'duplicate_fact': p['facts'].append(deepcopy(p['facts'][0]))
    elif mode == 'unused_fact':
        extra = deepcopy(p['facts'][0]); extra['content']['identity'] = 'unused'; p['facts'].append(extra)
    elif mode == 'missing_derivation': p['derivations'].pop(0)
    elif mode == 'source_marker': p['facts'][0]['source'] = False
    elif mode == 'generation': p['program']['ascentGeneration'] = -1
    elif mode == 'catalog_type': p['program']['relations'][0]['columns'][0] = 'boolean'
    elif mode == 'bound': request['workSteps'] = 0
    elif mode == 'node_bound': request['maximumNodes'] = 1
    elif mode == 'unknown_program_field': p['program']['proofAdmitted'] = True
    with pytest.raises(SemanticRuntimeError):
        runtime.admit_temporal_derivation(request)
    assert runtime.admit_temporal_derivation(original_proof['request']) == original_proof['expected']
