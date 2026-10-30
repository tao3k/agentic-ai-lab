# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
from copy import deepcopy
import os
from pathlib import Path
import pytest
from agentic_ai_lab_runtime.semantic_runtime import SemanticRuntimeError
from agentic_ai_lab_runtime.scheme_wire import loads


def declarations():
    return [dict(schema='agentic-ai-lab.context-restriction.v1', domain='declared-library-clock',
                 readers=readers, destinations=['store'], provenance=[source], leaseStart=start, leaseEnd=end)
            for readers, source, start, end in [(['alice', 'bob'], 'source-a', 1, 10),
                                                (['bob'], 'source-b', 2, 8)]]


def query(runtime):
    labels = declarations()
    composed = runtime.compose_context_restrictions(dict(
        schema='agentic-ai-lab.context-restriction-compose-request.v1', restrictions=labels))
    return dict(schema='agentic-ai-lab.context-flow-request.v1', restrictions=labels,
                expectedRestrictionDigest=composed['bindingDigest'], sourceDigest='sha256:'+'a'*64,
                contentDigest='sha256:'+'b'*64, principal='bob', destination='store', declaredAt=2)


def test_native_context_composition_preserves_provenance_and_order(runtime):
    request = dict(schema='agentic-ai-lab.context-restriction-compose-request.v1', restrictions=declarations())
    original = deepcopy(request)
    first = runtime.compose_context_restrictions(request)
    assert request == original
    assert first['restriction']['readers'] == ['bob']
    assert first['restriction']['provenance'] == ['source-a', 'source-b']
    assert first['restriction']['leaseStart'] == 2 and first['restriction']['leaseEnd'] == 8
    request['restrictions'].reverse()
    assert runtime.compose_context_restrictions(request) == first


@pytest.mark.parametrize('field,value,status', [
    ('declaredAt', 2, 'eligible'), ('declaredAt', 8, 'expired-lease'),
    ('declaredAt', 1, 'not-yet-effective'), ('principal', 'alice', 'reader-denied'),
    ('destination', 'model', 'destination-denied')])
def test_declared_flow_boundary_is_not_io_authority(runtime, field, value, status):
    request = query(runtime)
    request[field] = value
    result = runtime.evaluate_declared_context_flow(request)
    assert result['status'] == status
    assert not any(result[k] for k in ['sourceAuthenticated', 'flowAdmitted', 'actionAuthorized', 'durable'])
    assert result['restrictionDigest'] == request['expectedRestrictionDigest']


@pytest.mark.parametrize('mode', ['binding', 'widening', 'clock', 'authority', 'domain', 'schema', 'digest'])
def test_context_wire_rejects_stale_or_unqualified_declarations(runtime, mode):
    request = query(runtime)
    if mode == 'binding':
        request['expectedRestrictionDigest'] = 'forged'
    if mode == 'widening':
        request['restrictions'][1]['readers'].append('alice')
    if mode == 'clock':
        request['effectiveAt'] = 2
    if mode == 'authority':
        request['flowAdmitted'] = True
    if mode == 'domain':
        request['restrictions'][1]['domain'] = 'foreign'
    if mode == 'schema':
        request['schema'] = 'unsupported'
    if mode == 'digest':
        request['sourceDigest'] = 'forged'
    with pytest.raises(SemanticRuntimeError):
        runtime.evaluate_declared_context_flow(request)


def test_original_mrr_context_flow_oracle_replay(runtime):
    path = os.environ.get('AGENTIC_AI_LAB_MRR_CONTEXT_FLOW_ORACLE')
    if not path:
        pytest.skip('original MRR Context flow oracle must be configured')
    receipt = loads(Path(path).read_text())
    for name in ['originalSourceFact', 'originalOutputFact']:
        fact = receipt[name]
        assert runtime.canonical_mrr_fact_content(fact['request']) == fact['expected']
    assert runtime.compose_context_restrictions(receipt['compose']['request']) == receipt['compose']['expected']
    assert len(receipt['flows']) == 7
    for row in receipt['flows']:
        assert runtime.evaluate_declared_context_flow(row['request']) == row['expected']
