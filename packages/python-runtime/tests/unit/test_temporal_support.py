# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
from copy import deepcopy
import pytest
from agentic_ai_lab_runtime.semantic_runtime import SemanticRuntimeError

def request():
    def rev(identity, subject, op, predecessor, admitted):
        return dict(identity=identity, subject=subject, operation=op, predecessor=predecessor,
                    admitted=admitted, validRange=False if op == 'retract' else [0, 10],
                    content=False if op == 'retract' else identity)
    return dict(schema='agentic-ai-lab.temporal-support-request.v1',
        program=dict(identity='supports', policy='read-only', complete=True, supports=[
            dict(identity=s, conclusion='claim', proof='declared-proof-'+s,
                 premises=[dict(subject=s, revision=s+'1')], parents=[]) for s in ['a','b']]),
        journal=dict(identity='journal', admissionDomain='txn', validDomain='valid', revisions=[
            rev('a1','a','assert',False,1),rev('b1','b','assert',False,1),
            rev('a2','a','retract','a1',2),rev('b2','b','retract','b1',3)]),
        asOf=1, validAt=False, budget=128)

def test_native_support_withdrawal_and_inert_receipt(runtime):
    payload=request(); before=deepcopy(payload)
    first=runtime.evaluate_temporal_support(payload)
    assert payload == before
    assert first['conclusions'][0]['activeSupports'] == ['a','b']
    payload['asOf']=2
    assert runtime.evaluate_temporal_support(payload)['conclusions'][0]['activeSupports'] == ['b']
    payload['asOf']=3
    final=runtime.evaluate_temporal_support(payload)
    assert final['conclusions'][0]['status'] == 'unsupported'
    assert not any(final[k] for k in ['proofAdmitted','sourceAuthenticated','actionAuthorized','durable'])
    assert runtime.evaluate_temporal_support(before) == first

@pytest.mark.parametrize('mode',['partial','budget','future','outside'])
def test_native_support_uncertainty(runtime,mode):
    p=request();p['asOf']=3
    if mode=='partial':p['program']['complete']=False
    if mode=='budget':p['budget']=0
    if mode=='future':p['asOf']=0
    if mode=='outside':p.update(asOf=1,validAt=11)
    r=runtime.evaluate_temporal_support(p)
    assert r['conclusions'][0]['status']==('unsupported' if mode=='outside' else 'unknown')

@pytest.mark.parametrize('mode',['schema','extra','cycle','foreign','budget','reorder'])
def test_native_support_rejects_unqualified_input(runtime,mode):
    p=request()
    if mode=='schema':p['schema']='agentic-ai-lab.temporal-support-request.v2'
    if mode=='extra':p['publish']=True
    if mode=='cycle':p['program']['supports'][0]['parents']=['claim']
    if mode=='foreign':p['program']['supports'][0]['premises'][0]['subject']='foreign'
    if mode=='budget':p['budget']=129
    if mode=='reorder':p['journal']['revisions'][2]['admitted']=0
    with pytest.raises(SemanticRuntimeError):runtime.evaluate_temporal_support(p)

def test_original_mrr_scheme_oracle(runtime):
    import os
    from pathlib import Path
    from agentic_ai_lab_runtime.scheme_wire import loads
    oracle = os.environ.get('AGENTIC_AI_LAB_MRR_SUPPORT_ORACLE')
    if not oracle:
        pytest.skip('original MRR oracle must be configured')
    receipt = loads(Path(oracle).read_text())
    assert runtime.evaluate_temporal_support(receipt['request']) == receipt['expected']


def test_original_mrr_named_claim_revision_oracles(runtime):
    import os
    from pathlib import Path
    from agentic_ai_lab_runtime.scheme_wire import loads
    path = os.environ.get('AGENTIC_AI_LAB_MRR_CLAIM_ORACLE')
    if not path:
        pytest.skip('original MRR claim oracle must be configured')
    rows = loads(Path(path).read_text())
    assert len(rows) == 2
    for row in rows:
        assert runtime.revise_temporal_support(row['request']) == row['expected']


def test_named_empty_claim_and_reverse_frontier(runtime):
    p = request()
    p['program']['conclusions'] = ['claim', 'downstream', 'unproved']
    p['program']['supports'].append(dict(identity='child', conclusion='downstream',
        proof='child-proof', premises=[], parents=['claim']))
    result = runtime.revise_temporal_support(dict(
        schema='agentic-ai-lab.temporal-support-revision-request.v1', task=p, previousAsOf=0))
    assert result['affectedConclusions'] == ['claim', 'downstream']
    assert result['changedSubjects'] == ['a', 'b']
    rows = {r['identity']: r for r in result['current']['conclusions']}
    assert rows['unproved']['status'] == 'unsupported'
    assert rows['downstream']['status'] == 'supported'
    p['program']['complete'] = False
    p['asOf'] = 3
    rows = {r['identity']: r for r in runtime.evaluate_temporal_support(p)['conclusions']}
    assert all(r['status'] == 'unknown' for r in rows.values())
