# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
from copy import deepcopy
import os
from pathlib import Path
import pytest
from agentic_ai_lab_runtime.scheme_wire import loads, dumps
from agentic_ai_lab_runtime.semantic_runtime import SemanticRuntimeError

@pytest.fixture
def registered(runtime, request):
    task = deepcopy(loads(Path(os.environ['AGENTIC_AI_LAB_NATIVE_DERIVATION_ORACLE']).read_text())['request'])
    task['journal']['validDomain'] = task['journal']['admissionDomain']
    identity = 'wire-' + request.node.name
    def instant(n):
        return dict(identity=str(n), domain='txn', coordinate=n, provenance='host-clock', modality='observed')
    policy = dict(schema='agentic-ai-lab.temporal-policy-refresh-request.v1',
        policy=dict(identity=identity, revision='v1', start=instant(1), end=instant(4)),
        generation=1, effectiveAt=instant(1))
    p = runtime.refresh_temporal_policy(policy)
    state = dict(schema='agentic-ai-lab.temporal-proof-state-refresh-request.v1', identity=identity, generation=1,
        program=deepcopy(task['projection']['program']), journal=deepcopy(task['journal']))
    s = runtime.refresh_temporal_proof_state(state)
    registration = dict(schema='agentic-ai-lab.temporal-proof-register-request.v1', stateIdentity=identity,
        expectedStateDigest=s['stateDigest'], policyIdentity=identity, task=task)
    proof = runtime.register_temporal_proof(registration)
    current = dict(schema='agentic-ai-lab.temporal-proof-current-request.v1', registration=proof['registration'],
        expectedStateGeneration=1, expectedPolicyGeneration=1, expectedPolicyDigest=p['policyDigest'], budget=128)
    return state, policy, registration, current, proof


def no_effects(value):
    assert not any(value[k] for k in ['sourceAuthenticated', 'selectionAdmitted', 'actionAuthorized', 'durable'])


def test_native_registration_current_parity_and_clock_expiry(runtime, registered):
    state, policy, registration, current, proof = registered
    before = deepcopy(registration)
    admitted = runtime.admit_temporal_derivation(registration['task'])
    assert proof['proofDigest'] == admitted['bindingDigest'] and proof['proofAdmitted']
    assert runtime.register_temporal_proof(registration) == proof and registration == before
    result = runtime.current_temporal_proof(current)
    assert result['current'] and result['status'] == 'current' and result['proofAdmitted']
    assert result['proofDigest'] == proof['proofDigest'] and result['effectiveAt']['coordinate'] == 1
    assert result['currentStateDigest'] == proof['originalStateDigest']
    no_effects(result)
    assert runtime.current_temporal_proof(current) == result
    policy['generation'] = 2
    policy['effectiveAt']['identity'] = '4'
    policy['effectiveAt']['coordinate'] = 4
    runtime.refresh_temporal_policy(policy)
    with pytest.raises(SemanticRuntimeError):
        runtime.current_temporal_proof(current)
    current['expectedPolicyGeneration'] = 2
    expired = runtime.current_temporal_proof(current)
    assert not expired['current'] and expired['status'] == 'expired-policy'
    no_effects(expired)


def test_late_correction_cannot_use_historical_cut_or_erase_history(runtime, registered):
    state, policy, registration, current, proof = registered
    initial = deepcopy(state)
    first = state['journal']['revisions'][0]
    state['generation'] = 2
    state['journal']['revisions'].append(dict(identity='late-correction', subject=first['subject'], operation='correct',
        predecessor=first['identity'], admitted=2, validRange=deepcopy(first['validRange']), content='changed'))
    s = runtime.refresh_temporal_proof_state(state)
    policy['generation'] = 2
    policy['effectiveAt'].update(identity='2', coordinate=2)
    runtime.refresh_temporal_policy(policy)
    current.update(expectedStateGeneration=2, expectedPolicyGeneration=2)
    result = runtime.current_temporal_proof(current)
    assert result['status'] == 'unsupported' and not result['current'] and result['proofAdmitted']
    assert result['currentStateDigest'] == s['stateDigest'] and result['proofDigest'] == proof['proofDigest']
    assert result['originalStateDigest'] != result['currentStateDigest']
    no_effects(result)
    initial['generation'] = 3
    with pytest.raises(SemanticRuntimeError):
        runtime.refresh_temporal_proof_state(initial)
    with pytest.raises(SemanticRuntimeError):
        runtime.register_temporal_proof(registration)
    forged = dict(current, asOf=1)
    with pytest.raises(SemanticRuntimeError):
        runtime.current_temporal_proof(forged)
    assert runtime.current_temporal_proof(current) == result


def test_catalog_replacement_and_budget_are_conservative(runtime, registered):
    state, policy, registration, current, proof = registered
    unknown = runtime.current_temporal_proof(dict(current, budget=0))
    assert unknown['status'] == 'unknown' and not unknown['current']
    state['generation'] = 2
    state['program']['catalogDigest'] = 'replacement-catalog'
    runtime.refresh_temporal_proof_state(state)
    current['expectedStateGeneration'] = 2
    result = runtime.current_temporal_proof(current)
    assert result['status'] == 'stale-catalog' and not result['current']
    assert result['proofDigest'] == proof['proofDigest']
    no_effects(result)


@pytest.mark.parametrize('case', ['current_schema','clock','journal','proof_flag','stale_generation','unknown_handle',
    'policy_generation','state_schema','state_conflict','register_schema','register_digest','register_flag','forged_rule'])
def test_forged_control_or_current_state_rejected_without_mutation(runtime, registered, case):
    state, policy, registration, current, proof = registered
    previous = runtime.current_temporal_proof(current)
    payload = deepcopy(current)
    operation = runtime.current_temporal_proof
    if case == 'current_schema': payload['schema'] = 'agentic-ai-lab.temporal-proof-current-request.v2'
    elif case == 'clock': payload['effectiveAt'] = 0
    elif case == 'journal': payload['journal'] = state['journal']
    elif case == 'proof_flag': payload['proofAdmitted'] = True
    elif case == 'stale_generation': payload['expectedStateGeneration'] = 0
    elif case == 'unknown_handle': payload['registration'] = 'unknown'
    elif case == 'policy_generation': payload['expectedPolicyGeneration'] = 0
    elif case.startswith('state_'):
        payload = deepcopy(state); operation = runtime.refresh_temporal_proof_state
        if case == 'state_schema': payload['schema'] = 'invalid'
        else: payload['program']['catalogDigest'] = 'conflicting'
    else:
        payload = deepcopy(registration); operation = runtime.register_temporal_proof
        if case == 'register_schema': payload['schema'] = 'invalid'
        elif case == 'register_digest': payload['expectedStateDigest'] = 'stale'
        elif case == 'register_flag': payload['actionAuthorized'] = True
        else: payload['task']['projection']['derivations'][0]['rule'] = 'forged'
    with pytest.raises(SemanticRuntimeError): operation(payload)
    assert runtime.current_temporal_proof(current) == previous


def test_control_hidden_from_ordinary_tools_and_wrong_thread(runtime, registered):
    state, policy, registration, current, proof = registered
    for operation, payload, entry in [('$host.temporal.proof.state.refresh',state,runtime._lib.agentic_ai_lab_python_semantic_proof_state_refresh),
        ('$host.temporal.proof.register',registration,runtime._lib.agentic_ai_lab_python_semantic_proof_register)]:
        assert operation not in runtime.descriptor['operations']
        with pytest.raises(ValueError, match='host control'): runtime.call(operation, payload)
        raw = dumps(payload).encode()
        result = runtime._ffi.new('agentic_ai_lab_semantic_result *')
        try:
            assert runtime._submit_host(lambda:runtime._lib.agentic_ai_lab_python_semantic_call(operation.encode(),raw,len(raw),result)).result() == 3
            assert entry(raw,len(raw),result) == 2
        finally: runtime._lib.agentic_ai_lab_python_semantic_release(result)
    assert 'temporal.proof.current' in runtime.descriptor['operations']
    assert runtime.current_temporal_proof(current)['current']
