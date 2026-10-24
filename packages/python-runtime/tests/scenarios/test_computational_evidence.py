# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Actual CFFI proof-store admission and Scheme/Quint correspondence."""
import os
import subprocess
import sys
import unittest


class ComputationalEvidenceIntegration(unittest.TestCase):
    def test_caller_owned_counts_preserve_complete_source_and_finite_rejection(self):
        code = '''
import copy, os
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import ComputationalEvidence
library = os.environ.get('ASCENT_ENGINE_LIBRARY') if os.environ.get('ASCENT_ENGINE_BACKEND') == 'abi' else None
source = {'identity':'caller-count-policy','generation':0,
          'relations':[['seed',1,[[i] for i in range(1100)]]]}
candidate = ['candidate',['relation','answer',1],
             ['rule',['answer',0],['seed',0]],['query','answer',0],
             ['limits','unlimited','unlimited','unlimited']]
with ReasoningRuntime() as engine, ComputationalEvidence(engine) as store:
    original = copy.deepcopy(source)
    resolved = store.resolve(source, candidate)
    assert resolved['status'] == 'verified', resolved
    packet = store.observe(source,candidate,resolved['handle'],[['answer',0]],support=True)
    assert packet['observations'][0]['conclusion']['status'] == 'verified'
    assert packet['supportNodes'] and source == original and len(source['relations'][0][2]) == 1100
    finite = copy.deepcopy(candidate); finite[-1] = ['limits',1024,4096,4096]
    assert store.resolve(source, finite)['status'] != 'verified'
    assert store.resolve(source, candidate)['reused'] is True
    changed = copy.deepcopy(source); changed['generation'] = 1
    changed['relations'][0][2].remove([0])
    assert store.fact(changed,candidate,resolved['handle'],['answer',0])['status'] == 'unknown'
    withdrawn = store.resolve(changed,candidate)
    assert withdrawn['status'] == 'verified' and [0] not in withdrawn['rows']
    absent = store.fact(changed,candidate,withdrawn['handle'],['answer',0])
    assert absent['status'] == 'finite-absent' and absent['present'] is False
    assert absent['support-nodes'] == [] and ['generation',1] in absent['scope']
    restored = copy.deepcopy(source); restored['generation'] = 2
    current = store.resolve(restored,candidate)
    assert current['status'] == 'verified' and current['reused'] is False
    assert store.observe(restored,candidate,current['handle'],[['answer',0]],support=True)['supportNodes']
    for value in (0,-1,True,'infinite'):
        invalid = copy.deepcopy(candidate); invalid[-1][1] = value
        assert store.resolve(source,invalid)['status'] != 'verified'
print('CALLER-PROOF-COUNTS-OK',flush=True)
'''
        subprocess.run([sys.executable, '-u', '-'], input=code, text=True,
                       env=os.environ.copy(), check=True, timeout=45)

    def test_native_store_through_selected_public_binding(self):
        code = '''
import copy, os
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime, ReasoningError
from agentic_ai_lab_runtime.reasoning import ComputationalEvidence, compact_observation, expand_observation
from agentic_ai_lab_testing.assessment_studies.evidence_chain_study import shared_qualify, shared_tasks, shared_source, SHARED_CANDIDATE
library = os.environ.get('ASCENT_ENGINE_LIBRARY') if os.environ.get('ASCENT_ENGINE_BACKEND') == 'abi' else None
with ReasoningRuntime() as engine:
    checks = shared_qualify(engine)
    assert len(checks['taskChecks']) == 2 and len(checks['nativeQuintRows']) == 32
    with ComputationalEvidence(engine) as a, ComputationalEvidence(engine) as b:
        task = shared_tasks()[0]; source = shared_source(task)
        r = a.resolve(source, SHARED_CANDIDATE)
        changed = copy.deepcopy(source)
        changed['relations'][0][2].remove([1,2])
        assert a.fact(changed, SHARED_CANDIDATE, r['handle'], ['path',0,2])['status'] == 'unknown'
        assert b.fact(source, SHARED_CANDIDATE, r['handle'], ['path',0,2])['status'] == 'unknown'
        first = a.fragment(source, SHARED_CANDIDATE, r['handle'], ['path',0,2])
        first['nodes'].clear()
        assert a.fragment(source, SHARED_CANDIDATE, r['handle'], ['path',0,2])['nodes']
        observed = a.observe(source, SHARED_CANDIDATE, r['handle'], [['path',0,2]], support=True)
        assert observed['scope']['source-identity'] == source['identity']
        assert observed['observations'][0]['conclusion']['atom'] == ['path',0,2]
        assert expand_observation(compact_observation(observed)) == observed
        nodes = observed['supportNodes']
        assert nodes[-1]['atom'] == ['path',0,2] and nodes[-1]['parents']
        combined = a.observe(source, SHARED_CANDIDATE, r['handle'], [['path',0,2], ['path',0,1]], support=True)
        assert len({n['id'] for n in combined['supportNodes']}) == len(combined['supportNodes']) == len(nodes)
        stale = a.observe(changed, SHARED_CANDIDATE, r['handle'], [['path',0,2]], support=True)
        assert stale['observations'][0]['conclusion']['status'] == 'unknown'
        assert 'support' not in stale['observations'][0]
        assert expand_observation(compact_observation(stale)) == stale
        try:
            a.stats(eval='42')
            raise AssertionError('extra request fields admitted')
        except TypeError: pass
        assert a.stats()['proof-builds'] == 1
    try: a.stats(); raise AssertionError('closed owner used')
    except ValueError: pass
print('COMPUTATIONAL-EVIDENCE-CFFI-OK', flush=True)
'''
        subprocess.run([sys.executable, '-u', '-'], input=code, text=True,
                       env=os.environ.copy(), check=True, timeout=45)


if __name__ == '__main__': unittest.main()
