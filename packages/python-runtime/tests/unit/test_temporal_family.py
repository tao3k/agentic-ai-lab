# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
from __future__ import annotations

import asyncio
from copy import deepcopy

import pytest

from agentic_ai_lab_runtime.semantic_runtime import SemanticRuntimeError


def family_task(vocabulary='release'):
    cause, effect = (('build', 'deploy') if vocabulary == 'release'
                     else ('order', 'administer'))
    return {'profile': 'finite-hypothesis-family',
            'model': {'identity': vocabulary, 'mode': 'exclusive-explanations',
                      'complete': True,
                      'domains': [{'identity': 'clock', 'role': 'event-time'}],
                      'observations': [
                          {'identity': cause, 'domain': 'clock', 'position': 1,
                           'provenance': 'source-a', 'modality': 'observed'},
                          {'identity': effect, 'domain': 'clock', 'position': 2,
                           'provenance': 'source-b', 'modality': 'observed'}],
                      'hypotheses': [
                          {'identity': 'a-target', 'cause': cause, 'effect': effect,
                           'constraints': [{'identity': 'order', 'relation': 'before',
                                            'left': cause, 'right': effect}]},
                          {'identity': 'z-alternative', 'cause': effect, 'effect': effect,
                           'constraints': [{'identity': 'reverse', 'relation': 'before',
                                            'left': effect, 'right': cause}]}]},
            'query': {'identity': 'question', 'target': 'a-target', 'limit': False}}


@pytest.mark.parametrize('vocabulary', ['release', 'medication'])
def test_family_reuses_native_engine_for_independent_vocabularies(runtime, vocabulary):
    task = family_task(vocabulary)
    before = deepcopy(task)
    result = runtime.classify_temporal_family(task)
    assert task == before
    assert result['classification'] == 'necessary'
    assert result['admissible'] == ['a-target']
    assert result['refuted'] == ['z-alternative']
    assert result['exhausted'] is True
    assert result['sourceAuthenticated'] is result['actionAuthorized'] is False
    assert runtime.observe_temporal_family(task, result)['verdict'] == 'consistent'


@pytest.mark.parametrize('variant', ['overlap', 'incomplete', 'budget', 'declared', 'cross-clock'])
def test_family_preserves_open_assumptions_and_frontiers(runtime, variant):
    task = family_task()
    if variant == 'overlap':
        task['model']['mode'] = 'overlapping-mechanisms'
    elif variant == 'incomplete':
        task['model']['complete'] = False
    elif variant == 'budget':
        task['query']['limit'] = 1
    elif variant == 'declared':
        task['model']['observations'][0]['modality'] = 'declared'
    else:
        task['model']['domains'].append({'identity': 'other', 'role': 'event-time'})
        task['model']['observations'][0]['domain'] = 'other'
    result = runtime.classify_temporal_family(task)
    assert result['classification'] == ('unknown' if variant in {'declared', 'cross-clock'} else 'possible')
    assert result['actionAuthorized'] is False
    if variant == 'budget':
        assert result['unexplored'] == ['z-alternative']
        assert result['exhausted'] is False


def test_family_local_refutation_does_not_require_exhaustion(runtime):
    task = family_task()
    task['query'].update(target='a-target', limit=1)
    constraint = task['model']['hypotheses'][0]['constraints'][0]
    constraint['left'], constraint['right'] = constraint['right'], constraint['left']
    result = runtime.classify_temporal_family(task)
    assert result['classification'] == 'refuted'
    assert result['exhausted'] is False


def test_family_canonical_model_identity_and_query_budget_binding(runtime):
    task = family_task()
    result = runtime.classify_temporal_family(task)
    reordered = deepcopy(task)
    reordered['model']['observations'].reverse()
    reordered['model']['hypotheses'].reverse()
    assert runtime.classify_temporal_family(reordered) == result
    task['query']['limit'] = 1
    limited = runtime.classify_temporal_family(task)
    assert limited['modelDigest'] == result['modelDigest']
    assert limited['bindingDigest'] != result['bindingDigest']
    assert runtime.observe_temporal_family(task, result)['verdict'] == 'contradicted'


@pytest.mark.parametrize('variant', ['coordinate', 'provenance', 'query', 'mode', 'complete'])
def test_family_stale_result_is_rejected_under_equal_or_changed_classification(runtime, variant):
    task = family_task()
    result = runtime.classify_temporal_family(task)
    if variant == 'coordinate':
        task['model']['observations'][1]['position'] = 3
    elif variant == 'provenance':
        task['model']['observations'][1]['provenance'] = 'new-source'
    elif variant == 'query':
        task['query']['identity'] = 'new-question'
    elif variant == 'mode':
        task['model']['mode'] = 'overlapping-mechanisms'
    else:
        task['model']['complete'] = False
    assert runtime.observe_temporal_family(task, result)['verdict'] == 'contradicted'


@pytest.mark.parametrize('variant', ['classification', 'binding', 'authority', 'extra', 'missing'])
def test_family_result_envelope_is_checked_in_native_owner(runtime, variant):
    task = family_task()
    result = runtime.classify_temporal_family(task)
    if variant == 'classification':
        result['classification'] = 'possible'
    elif variant == 'binding':
        result['bindingDigest'] = 'fake'
    elif variant == 'authority':
        result['actionAuthorized'] = True
    elif variant == 'extra':
        result['proof'] = 'opaque-proof-id'
    else:
        del result['modelDigest']
    assert runtime.observe_temporal_family(task, result)['verdict'] == 'contradicted'


@pytest.mark.parametrize('variant', ['empty', 'duplicate', 'unsupported', 'profile', 'extra', 'limit', 'bounds'])
def test_family_fails_closed_before_returning_a_receipt(runtime, variant):
    task = family_task()
    if variant == 'empty':
        task['model']['hypotheses'] = []
    elif variant == 'duplicate':
        task['model']['hypotheses'].append(deepcopy(task['model']['hypotheses'][0]))
    elif variant == 'unsupported':
        task['model']['hypotheses'][0]['constraints'][0]['relation'] = 'actual-cause'
    elif variant == 'profile':
        task['profile'] = 'finite-behavior-space'
    elif variant == 'extra':
        task['model']['Next'] = 'arbitrary-action'
    elif variant == 'limit':
        task['query']['limit'] = 0
    else:
        task['model']['domains'] *= 33
    with pytest.raises(SemanticRuntimeError):
        runtime.classify_temporal_family(task)
    assert runtime.classify_temporal_family(family_task())['classification'] == 'necessary'


def test_family_async_parity_and_current_model_replay(runtime):
    task = family_task()
    expected = runtime.classify_temporal_family(task)
    async def run():
        result = await runtime.aclassify_temporal_family(task)
        observation = await runtime.aobserve_temporal_family(task, result)
        return result, observation
    result, observation = asyncio.run(run())
    assert result == expected
    assert observation['verdict'] == 'consistent'
