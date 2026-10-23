# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Installed Python transports declarations; native POO owns every decision."""
from copy import deepcopy
import pytest
from agentic_ai_lab_runtime.semantic_runtime import SemanticRuntimeError
from test_temporal_family import family_task
from test_temporal_admission import source_scope, admit
from test_temporal_policy import refresh


def test_context_use_observes_actual_native_host_state(runtime):
    task, scope = family_task(), source_scope('python-context-use')
    registered = runtime.register_temporal_source(scope, task)
    family = admit(runtime, task, scope, registered, 'python-context')
    policy = runtime.refresh_temporal_policy(refresh('policy-1'))
    request = dict(schema='agentic-ai-lab.context-use-refresh-request.v1', identity='python-context',
                   generation=1, manifestDigest='sha256:'+'a'*64, admissionDigest=family['admissionDigest'],
                   contract=dict(actor='original-MRR-actor', task='original-MRR-task', policyDigest='sha256:'+'b'*64,
                                 required=[], temporalReceipts=['original-MRR-fact'], requireComplete=True),
                   policyIdentity='policy-1', policyDigest=policy['policyDigest'], purposes=['display'], enabled=True)
    before = deepcopy(request)
    reg = runtime.refresh_context_use(request)
    assert request == before and runtime.refresh_context_use(request) == reg
    query = dict(schema='agentic-ai-lab.context-use-observe-request.v1', identity='python-context',
                 expectedGeneration=1, purpose='display', admissionDigest=family['admissionDigest'])
    observed = runtime.observe_context_use(query)
    assert observed['decision'] == 'allowed' and observed['contract'] == request['contract']
    assert observed['currentSource']['status'] == 'current'
    assert not observed['actionAuthorized'] and not observed['durable']
    with pytest.raises(ValueError, match='host control'):
        runtime.call('$host.context.use.refresh', request)
    ffi, lib = runtime._ffi, runtime._lib
    from agentic_ai_lab_runtime.scheme_wire import dumps
    data, result = dumps(request).encode(), ffi.new('agentic_ai_lab_semantic_result *')
    try:
        assert runtime._submit_host(lambda: lib.agentic_ai_lab_python_semantic_call(
            b'$host.context.use.refresh', data, len(data), result)).result() == 3
    finally:
        lib.agentic_ai_lab_python_semantic_release(result)
    for key, value in [('effectiveAt', 0), ('contract', request['contract']), ('decision', 'allowed')]:
        bad = dict(query, **{key:value})
        with pytest.raises(SemanticRuntimeError): runtime.observe_context_use(bad)
        assert runtime.observe_context_use(query) == observed
    action = dict(query, purpose='action')
    assert runtime.observe_context_use(action)['decision'] == 'denied'
    epoch = dict(request, generation=2)
    runtime.refresh_context_use(epoch)
    assert runtime.observe_context_use(query)['decision'] == 'denied'
    query['expectedGeneration'] = 2
    runtime.refresh_temporal_policy(refresh('policy-1', generation=2, now=4))
    assert runtime.observe_context_use(query)['decision'] == 'expired'
    runtime.refresh_context_use(dict(request, generation=3, enabled=False))
    assert runtime.observe_context_use(query)['decision'] == 'revoked'
    with pytest.raises(SemanticRuntimeError): runtime.refresh_context_use(dict(request, generation=4))
    corrected = deepcopy(task)
    corrected['model']['observations'][1]['position'] += 1
    runtime.register_temporal_source(source_scope('python-context-use', 2), corrected)
    assert runtime.observe_context_use(query)['currentSource']['status'] == 'stale'
    assert runtime.observe_context_use(query)['decision'] == 'denied'
    # A stale source can still be retired by Host control; it cannot be re-enabled.
    runtime.refresh_context_use(dict(request, generation=4, enabled=False))
