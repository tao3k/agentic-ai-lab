# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
from copy import deepcopy
import pytest
from agentic_ai_lab_runtime.semantic_runtime import SemanticRuntimeError
from test_temporal_support import request as support_request

def instant(n):
    return dict(identity=f'at-{n}',domain='policy-clock',coordinate=n,provenance='host-observation',modality='observed')
def refresh(identity='policy-abi',revision='r1',generation=1,now=1):
    return dict(schema='agentic-ai-lab.temporal-policy-refresh-request.v1',
                policy=dict(identity=identity,revision=revision,start=instant(1),end=instant(4)),
                generation=generation,effectiveAt=instant(now))
def guard(registered):
    task=support_request();task['program']['policy']=registered['policyIdentity']
    return dict(schema='agentic-ai-lab.temporal-support-guard-request.v1',expectedGeneration=registered['generation'],
                expectedPolicyDigest=registered['policyDigest'],task=task)

def test_real_host_policy_control_and_current_clock(runtime):
    req=refresh();before=deepcopy(req)
    registered=runtime.refresh_temporal_policy(req)
    assert req==before
    assert runtime.refresh_temporal_policy(req)==registered
    query=guard(registered)
    current=runtime.guard_temporal_support(query)
    assert current['policyStatus']=='applicable'
    assert current['effectiveAt']==instant(1)
    assert current['evaluation']['conclusions'][0]['status']=='supported'
    assert not any(current[k] for k in ['proofAdmitted','sourceAuthenticated','selectionAdmitted','actionAuthorized','durable'])
    runtime.refresh_temporal_policy(refresh(generation=2,now=4))
    with pytest.raises(SemanticRuntimeError):runtime.guard_temporal_support(query)
    query['expectedGeneration']=2
    expired=runtime.guard_temporal_support(query)
    assert expired['policyStatus']=='expired-policy' and not expired['policyApplicable']
    assert expired['effectiveAt']==instant(4)
    stale=deepcopy(query);stale['expectedPolicyDigest']='wrong'
    assert runtime.guard_temporal_support(stale)['policyStatus']=='stale-policy'
    for bad in [refresh(generation=3,now=2),refresh(generation=1,now=4)]:
        with pytest.raises(SemanticRuntimeError):runtime.refresh_temporal_policy(bad)
        assert runtime.guard_temporal_support(query)==expired
    conflict=refresh(generation=3,now=4);conflict['policy']['end']=instant(5)
    with pytest.raises(SemanticRuntimeError):runtime.refresh_temporal_policy(conflict)
    assert runtime.guard_temporal_support(query)==expired
    replacement=refresh(revision='r2',generation=3,now=4);replacement['policy']['end']=instant(6)
    latest=runtime.refresh_temporal_policy(replacement)
    assert runtime.guard_temporal_support(guard(latest))['policyStatus']=='applicable'

def test_control_is_not_a_model_tool_even_through_raw_c(runtime):
    req=refresh('control-lane')
    with pytest.raises(ValueError,match='host control'):runtime.call('$host.temporal.policy.refresh',req)
    ffi=runtime._ffi;lib=runtime._lib
    result=ffi.new('agentic_ai_lab_semantic_result *')
    from agentic_ai_lab_runtime.scheme_wire import dumps
    data=dumps(req).encode()
    try:
        assert runtime._submit_host(lambda:lib.agentic_ai_lab_python_semantic_call(b'$host.temporal.policy.refresh',data,len(data),result)).result()==3
        assert result.status == 3 and result.length == 0 and result.data == ffi.NULL
    finally:lib.agentic_ai_lab_python_semantic_release(result)
    fake=dict(policyIdentity='control-lane',generation=1,policyDigest='unregistered')
    with pytest.raises(SemanticRuntimeError):runtime.guard_temporal_support(guard(fake))
    registered=runtime.refresh_temporal_policy(req)
    assert '$host.temporal.policy.refresh' not in runtime.descriptor['operations']
    assert runtime.guard_temporal_support(guard(registered))['policyApplicable']

@pytest.mark.parametrize('mode',['clock','policy','proof','schema','generation'])
def test_guard_cannot_replace_registered_state(runtime,mode):
    reg=runtime.refresh_temporal_policy(refresh('guard-reject-'+mode))
    query=guard(reg);before=runtime.guard_temporal_support(query);bad=deepcopy(query)
    if mode=='clock':bad['effectiveAt']=instant(0)
    if mode=='policy':bad['policy']=refresh()['policy']
    if mode=='proof':bad['proofAdmitted']=True
    if mode=='schema':bad['schema']='agentic-ai-lab.temporal-support-guard-request.v2'
    if mode=='generation':bad['expectedGeneration']+=1
    with pytest.raises(SemanticRuntimeError):runtime.guard_temporal_support(bad)
    assert runtime.guard_temporal_support(query)==before

@pytest.mark.parametrize('mode',['schema','extra','domain','modality','window'])
def test_rejected_refresh_leaves_previous_state(runtime,mode):
    original=refresh('refresh-reject-'+mode)
    reg=runtime.refresh_temporal_policy(original);query=guard(reg);before=runtime.guard_temporal_support(query)
    bad=deepcopy(original);bad.update(generation=2)
    if mode=='schema':bad['schema']='agentic-ai-lab.temporal-policy-refresh-request.v2'
    if mode=='extra':bad['actionAuthorized']=True
    if mode=='domain':bad['effectiveAt']['domain']='foreign'
    if mode=='modality':bad['effectiveAt']['modality']='predicted'
    if mode=='window':bad['policy']['end']=instant(1)
    with pytest.raises(SemanticRuntimeError):runtime.refresh_temporal_policy(bad)
    assert runtime.guard_temporal_support(query)==before

def test_original_rust_policy_projection_parity(runtime):
    import os
    from pathlib import Path
    from agentic_ai_lab_runtime.scheme_wire import loads
    path = os.environ.get('AGENTIC_AI_LAB_POLICY_ORACLE')
    if not path:
        pytest.skip('original Rust policy projection must be configured')
    original = loads(Path(path).read_text())
    assert runtime.refresh_temporal_policy(original['refresh']) == original['registered']
    assert runtime.refresh_temporal_policy(original['currentRefresh']) == original['current']
    assert runtime.guard_temporal_support(original['query']) == original['expired']

def test_policy_start_boundary_and_generation_conflict(runtime):
    req = refresh('future-policy', now=0)
    registered = runtime.refresh_temporal_policy(req)
    query = guard(registered)
    pending = runtime.guard_temporal_support(query)
    assert pending['policyStatus'] == 'not-yet-effective'
    assert not pending['policyApplicable']
    with pytest.raises(SemanticRuntimeError):
        runtime.refresh_temporal_policy(refresh('future-policy', now=1))
    assert runtime.guard_temporal_support(query) == pending
    latest = runtime.refresh_temporal_policy(refresh('future-policy', generation=2, now=1))
    assert runtime.guard_temporal_support(guard(latest))['policyStatus'] == 'applicable'


def test_named_claim_selection_fences_context_and_preserves_history(runtime):
    reg = runtime.refresh_temporal_policy(refresh('claim-selection'))
    q = guard(reg)
    q.update(schema='agentic-ai-lab.temporal-support-claim-request.v1',
             claim='claim', expectedContextBinding=False)
    q['task']['program']['conclusions'] = ['claim', 'empty']
    first = runtime.select_temporal_claim(q)
    assert first['status'] == 'supported'
    current = deepcopy(q)
    current['task']['asOf'] = 2
    current['expectedContextBinding'] = first['bindingDigest']
    stale = runtime.select_temporal_claim(current)
    assert stale['contextStatus'] == 'stale-context' and stale['status'] == 'unknown'
    assert stale['claim']['status'] == 'supported'
    assert runtime.select_temporal_claim(q) == first
    latest = runtime.refresh_temporal_policy(refresh('claim-selection', generation=2, now=4))
    with pytest.raises(SemanticRuntimeError):
        runtime.select_temporal_claim(q)
    q.update(expectedGeneration=latest['generation'], expectedPolicyDigest=latest['policyDigest'])
    expired = runtime.select_temporal_claim(q)
    assert expired['status'] == 'unknown' and expired['policyStatus'] == 'expired-policy'
    assert expired['claim']['status'] == 'supported'
    assert not any(expired[k] for k in ['proofAdmitted', 'sourceAuthenticated', 'selectionAdmitted', 'actionAuthorized', 'durable'])
    for field, value in [('claim', 'foreign'), ('effectiveAt', instant(1)),
                         ('expectedContextBinding', 7)]:
        bad = deepcopy(q)
        bad[field] = value
        with pytest.raises(SemanticRuntimeError):
            runtime.select_temporal_claim(bad)
