# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
from __future__ import annotations

import asyncio
from copy import deepcopy
from agentic_ai_lab_runtime import scheme_wire as wire

import pytest

from agentic_ai_lab_runtime.semantic_runtime import SemanticRuntimeError
from test_temporal_family import family_task


def source_scope(identity, generation=1):
    return {'identity': identity, 'authority': 'fixture-owner', 'subject': 'release',
            'scope': 'release-evidence', 'cut': f'cut-{generation}',
            'projection': f'projection-{generation}', 'policy': 'policy-1',
            'generation': generation}


def admit(runtime, task, scope, registered, conclusion='conclusion-1'):
    return runtime.admit_temporal_family(task, source_identity=scope['identity'],
                                        source_digest=registered['sourceDigest'],
                                        conclusion_identity=conclusion)


def test_host_snapshot_admits_native_recomputed_inert_conclusion(runtime):
    task, scope = family_task(), source_scope('source-success')
    registered = runtime.register_temporal_source(scope, task)
    result = admit(runtime, task, scope, registered)
    assert result['classification'] == 'necessary'
    assert result['sourceVerified'] is True
    assert result['trustBasis'] == 'host-registered-snapshot'
    assert result['sourceAuthenticated'] is result['actionAuthorized'] is False
    assert result['conclusion']['cut'] == scope['cut']
    assert result['conclusion']['projection'] == scope['projection']
    assert result['conclusion']['generation'] == '1'
    assert result['conclusion']['operation'] == 'assert'
    assert result['conclusion']['identity'].startswith('sha256:')
    other = admit(runtime, task, scope, registered, 'different-request')
    assert other['conclusion']['identity'] != result['conclusion']['identity']
    assert result['conclusion']['proofDigest'].startswith('sha256:')
    assert admit(runtime, task, scope, registered) == result
    assert runtime.register_temporal_source(scope, task) == registered


@pytest.mark.parametrize('variant', ['position', 'provenance', 'modality', 'domain', 'role', 'missing'])
def test_model_cannot_replace_registered_observation_inventory(runtime, variant):
    task, scope = family_task(), source_scope(f'source-evidence-{variant}')
    registered = runtime.register_temporal_source(scope, task)
    changed = deepcopy(task)
    if variant == 'position':
        changed['model']['observations'][1]['position'] += 1
    elif variant == 'provenance':
        changed['model']['observations'][1]['provenance'] = 'forged-source'
    elif variant == 'modality':
        changed['model']['observations'][0]['modality'] = 'declared'
    elif variant == 'domain':
        changed['model']['domains'].append({'identity': 'foreign', 'role': 'event-time'})
        changed['model']['observations'][0]['domain'] = 'foreign'
    elif variant == 'role':
        changed['model']['domains'][0]['role'] = 'processing-time'
    else:
        changed['model']['observations'].pop()
    with pytest.raises(SemanticRuntimeError):
        admit(runtime, changed, scope, registered)
    assert admit(runtime, task, scope, registered)['sourceVerified']


def test_source_registration_is_not_available_through_semantic_model_lane(runtime):
    task, scope = family_task(), source_scope('source-control-guard')
    with pytest.raises(ValueError, match='host control'):
        runtime.call('$host.temporal.source.register', {'task': task, 'scope': scope})
    data = wire.dumps({'task': task, 'scope': scope}).encode()
    def bypass_python_guard():
        result = runtime._ffi.new('agentic_ai_lab_semantic_result *')
        try:
            return runtime._lib.agentic_ai_lab_python_semantic_call(
                b'$host.temporal.source.register', data, len(data), result)
        finally:
            runtime._lib.agentic_ai_lab_python_semantic_release(result)
    assert runtime._worker.submit(bypass_python_guard).result() == 3
    with pytest.raises(SemanticRuntimeError):
        runtime.admit_temporal_family(task, source_identity=scope['identity'],
                                     source_digest='fake', conclusion_identity='c')


def test_new_source_revision_withdraws_old_applicability_without_mutating_old_result(runtime):
    task, scope = family_task(), source_scope('source-revision')
    registered = runtime.register_temporal_source(scope, task)
    historical = admit(runtime, task, scope, registered)
    original = deepcopy(historical)
    revised_task = deepcopy(task)
    revised_task['model']['observations'][1]['position'] = 3
    revised_scope = source_scope(scope['identity'], 2)
    revised = runtime.register_temporal_source(revised_scope, revised_task)
    assert revised['sourceDigest'] != registered['sourceDigest']
    with pytest.raises(SemanticRuntimeError, match='stale'):
        admit(runtime, task, scope, registered)
    with pytest.raises(SemanticRuntimeError):
        admit(runtime, task, revised_scope, revised)
    result = admit(runtime, revised_task, revised_scope, revised, 'conclusion-2')
    assert result['conclusion']['generation'] == '2'
    assert result['conclusion']['proofDigest'] != historical['conclusion']['proofDigest']
    assert historical == original
    with pytest.raises(SemanticRuntimeError, match='rollback'):
        runtime.register_temporal_source(scope, task)


@pytest.mark.parametrize('variant', ['cut', 'projection', 'policy', 'authority', 'evidence'])
def test_conflicting_registration_cannot_replace_same_generation(runtime, variant):
    task, scope = family_task(), source_scope(f'source-conflict-{variant}')
    registered = runtime.register_temporal_source(scope, task)
    changed_scope, changed_task = deepcopy(scope), deepcopy(task)
    if variant == 'evidence':
        changed_task['model']['observations'][1]['position'] = 3
    else:
        changed_scope[variant] = 'different'
    with pytest.raises(SemanticRuntimeError, match='conflicting'):
        runtime.register_temporal_source(changed_scope, changed_task)
    assert admit(runtime, task, scope, registered)['sourceDigest'] == registered['sourceDigest']


def test_unknown_classification_cannot_produce_conclusion(runtime):
    task, scope = family_task(), source_scope('source-unknown')
    task['model']['observations'][0]['modality'] = 'declared'
    registered = runtime.register_temporal_source(scope, task)
    with pytest.raises(SemanticRuntimeError, match='unresolved'):
        admit(runtime, task, scope, registered)


def test_hypotheses_are_assumptions_and_budget_changes_proof_not_source_snapshot(runtime):
    task, scope = family_task(), source_scope('source-proof-binding')
    registered = runtime.register_temporal_source(scope, task)
    necessary = admit(runtime, task, scope, registered)
    changed = deepcopy(task)
    changed['query']['limit'] = 1
    possible = admit(runtime, changed, scope, registered)
    assert possible['classification'] == 'possible'
    assert possible['sourceDigest'] == necessary['sourceDigest']
    assert possible['conclusion']['proofDigest'] != necessary['conclusion']['proofDigest']
    assert possible['conclusion']['identity'] != necessary['conclusion']['identity']
    changed['model']['mode'] = 'overlapping-mechanisms'
    overlap = admit(runtime, changed, scope, registered)
    assert overlap['conclusion']['proofDigest'] != possible['conclusion']['proofDigest']
    assert overlap['sourceAuthenticated'] is overlap['actionAuthorized'] is False


def test_registered_source_permutation_and_async_admission(runtime):
    task, scope = family_task(), source_scope('source-async')
    registered = runtime.register_temporal_source(scope, task)
    expected = admit(runtime, task, scope, registered)
    task['model']['observations'].reverse()
    task['model']['hypotheses'].reverse()
    assert runtime.register_temporal_source(scope, task) == registered
    result = asyncio.run(runtime.aadmit_temporal_family(
        task, source_identity=scope['identity'], source_digest=registered['sourceDigest'],
        conclusion_identity='conclusion-1'))
    assert result == expected


def test_source_control_preserves_native_owner_thread_and_transport_guards(runtime):
    data = wire.dumps({'task': family_task(), 'scope': source_scope('source-wrong-thread')}).encode()
    result = runtime._ffi.new('agentic_ai_lab_semantic_result *')
    assert runtime._lib.agentic_ai_lab_python_semantic_source_register(data, len(data), result) == 2
    def reject_transport():
        result = runtime._ffi.new('agentic_ai_lab_semantic_result *')
        try:
            return runtime._lib.agentic_ai_lab_python_semantic_source_register(b'(object)\0', 9, result)
        finally:
            runtime._lib.agentic_ai_lab_python_semantic_release(result)
    assert runtime._worker.submit(reject_transport).result() == 3
    with pytest.raises(SemanticRuntimeError):
        runtime.admit_temporal_family(family_task(), source_identity='source-wrong-thread',
                                     source_digest='fake', conclusion_identity='c')
