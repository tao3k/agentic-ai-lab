# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
from __future__ import annotations
import asyncio
from copy import deepcopy
import os
import pytest
from agentic_ai_lab_runtime.semantic_runtime import SemanticRuntime, SemanticRuntimeError


from semantic_cases import temporal_request


def test_semantic_native_descriptor(runtime):
    assert runtime.descriptor['operations'] == [
        'context.use.observe',
        'temporal.solve',
        'graph.admit',
        'temporal.verify',
        'graph.targets',
        'temporal.observe',
        'temporal.family.classify',
        'temporal.family.observe',
        'temporal.family.admit',
        'temporal.family.current',
        'temporal.family.revision.root',
        'temporal.family.revision.change',
        'temporal.family.journal',
        'temporal.family.archive.export',
        'temporal.family.archive.replay',
        'temporal.support.evaluate', 'temporal.support.revise', 'temporal.support.claim', 'context.restriction.compose', 'context.flow.evaluate', 'temporal.fact.content', 'temporal.support.guard', 'temporal.proof.current',
    ]
    assert runtime.descriptor['threading'] == 'single-owner-thread'


def test_semantic_native_temporal_result_and_generation_binding(runtime):
    payload = temporal_request()
    original = deepcopy(payload)
    first = runtime.call('temporal.solve', payload)
    assert payload == original
    assert first['status'] == 'complete'
    assert first['rows'] == [['a', 'b'], ['a', 'c']]
    assert first['verification'] == 'valid'
    assert first['evidence'] == ['valid', 'valid']
    payload['source']['generation'] = payload['lens']['generation'] = 2
    second = runtime.call('temporal.solve', payload)
    assert second['rows'] == first['rows']
    assert second['bindingDigest'] != first['bindingDigest']


@pytest.mark.parametrize('variant', ['open', 'late', 'interval', 'horizon', 'clock'])
def test_semantic_native_uncertainty_is_preserved(runtime, variant):
    payload = temporal_request()
    if variant == 'open':
        payload['lens']['closed'] = False
    elif variant == 'late':
        payload['lens']['asOf'] = 1
    elif variant == 'interval':
        payload['source']['events'][1][1] = ['between', 0, 20]
    elif variant == 'horizon':
        payload['lens']['horizon'] = 0
    else:
        payload['source']['clock'] = 'other-clock'
    result = runtime.call('temporal.solve', payload)
    assert result['status'] in {'partial', 'rejected'}
    assert result['rows'] == []
    assert result['verification'] != 'valid'


def test_semantic_native_rejection_does_not_poison_following_calls(runtime):
    for operation, payload in [('missing-operation', {}), ('temporal.solve', {})]:
        with pytest.raises(SemanticRuntimeError) as error:
            runtime.call(operation, payload)
        assert error.value.status == 4
    assert runtime.call('temporal.solve', temporal_request())['status'] == 'complete'


def test_semantic_native_concurrent_async_calls_are_serialized(runtime):
    async def run():
        return await asyncio.gather(*[runtime.acall('temporal.solve', temporal_request())
                                      for _ in range(8)])
    answers = asyncio.run(run())
    assert all(answer == answers[0] for answer in answers)


def test_semantic_native_transport_rejects_oversize_and_nul(runtime):
    with pytest.raises(ValueError, match='maximum'):
        runtime.call('temporal.solve', {'value': 'x' * 1048576})
    with pytest.raises(ValueError, match='operation'):
        runtime.call('bad\0operation', {})


def test_semantic_native_owner_thread_and_raw_input_guards(runtime):
    ffi, lib = runtime._ffi, runtime._lib
    result = ffi.new('agentic_ai_lab_semantic_result *')
    assert lib.agentic_ai_lab_python_semantic_call(b'descriptor', b'{}', 2, result) == 2
    assert lib.agentic_ai_lab_python_semantic_close() == 2
    for data in [b'\xff', b'{\0}', b'(' * 65 + b')' * 65]:
        status = runtime._worker.submit(lib.agentic_ai_lab_python_semantic_call,
                                         b'descriptor', data, len(data), result).result()
        assert status == 3
        lib.agentic_ai_lab_python_semantic_release(result)
        lib.agentic_ai_lab_python_semantic_release(result)
    status = runtime._worker.submit(lib.agentic_ai_lab_python_semantic_call,
                                     b'\xff', b'{}', 2, result).result()
    assert status == 3
    assert runtime.call('descriptor', {})['abiVersion'] == 1
    with pytest.raises(SemanticRuntimeError):
        SemanticRuntime(os.environ['AGENTIC_AI_LAB_SEMANTIC_LIBRARY'],
                        expected_digest=runtime.artifact_digest)


def test_semantic_native_graph_admission_and_actual_python_io(runtime, tmp_path):
    from agentic_ai_lab_runtime import (RuntimeGraphProgram, RuntimeGraphRuntime,
                                 RuntimeGraphRegistries, linear_plan)
    from agentic_ai_lab_runtime._native.session import NativeRuntimeSession, NativeBundleDescriptor
    path = os.environ.get('AGENTIC_AI_LAB_RUNTIME_V0_LIBRARY')
    if not path:
        pytest.fail('graph execution qualification requires the real control-lane artifact')
    artifact = tmp_path / 'action-result.txt'
    def model(state):
        artifact.write_text(str(state['value'] + 1))
        return {'answer': state['value'] + 1}
    with NativeRuntimeSession(NativeBundleDescriptor(bytes(32), 1, b'bundle'), library_path=path) as session:
        program = RuntimeGraphProgram(
            plan=linear_plan('model', 'format'),
            runtime=RuntimeGraphRuntime.native(session, semantic_context=runtime),
            registries=RuntimeGraphRegistries(actions={
                'model': model,
                'format': lambda state: {'formatted': artifact.read_text()}}))
        execution = program.invoke_with_trace({'value': 41})
    assert execution.state['formatted'] == '42'
    assert execution.validation.kind == 'scheme-graph-admission'
    assert len(execution.plan_digest) == 64
    assert execution.trace == ('model', 'format')


def test_semantic_native_graph_rejects_invalid_endpoint_before_io(runtime):
    from agentic_ai_lab_runtime import RuntimeGraphBindings, RuntimeGraphPlan, RuntimeGraphEdge
    plan = RuntimeGraphPlan(nodes=('model',), edges=(RuntimeGraphEdge('__start__', 'missing'),))
    with pytest.raises(SemanticRuntimeError) as error:
        runtime.admit_graph(plan, RuntimeGraphBindings())
    assert error.value.status == 4


def test_semantic_native_final_model_answer_is_revalidated(runtime):
    from agentic_ai_lab_runtime import scheme_wire as wire
    task = temporal_request()
    candidate = {'status': 'complete', 'rows': [['a', 'b'], ['a', 'c']]}
    accepted = runtime.validate_model_answer(task, wire.dumps(candidate))
    assert accepted['verdict'] == 'consistent'
    task['source']['parents'] = []
    rejected = runtime.validate_model_answer(task, wire.dumps(candidate))
    assert rejected['verdict'] == 'contradicted'
    assert rejected['bindingDigest'] != accepted['bindingDigest']
    assert runtime.validate_model_answer(task, '(object ("rows" (list)) ("status" "complete"))')['verdict'] == 'consistent'
    with pytest.raises(SemanticRuntimeError, match='inert Scheme datum'):
        runtime.validate_model_answer(task, '(system "echo unsafe")')
    with pytest.raises(SemanticRuntimeError, match='inert Scheme datum'):
        runtime.validate_model_answer(task, '(object ("status" "complete") ("status" "partial") ("rows" (list)))')
    assert runtime.validate_model_answer(task,
        '(object ("authorized" #t) ("rows" (list)) ("status" "complete"))')['verdict'] == 'contradicted'


def test_semantic_native_async_cancellation_discards_queued_call(runtime):
    import threading
    entered = threading.Event()
    release = threading.Event()
    def block_owner():
        entered.set()
        assert release.wait(2)
    blocker = runtime._worker.submit(block_owner)
    assert entered.wait(1)
    async def cancel():
        task = asyncio.create_task(runtime.acall('temporal.solve', temporal_request()))
        await asyncio.sleep(0)
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task
    try:
        asyncio.run(cancel())
    finally:
        release.set()
        blocker.result()
    assert runtime.call('temporal.solve', temporal_request())['status'] == 'complete'


def test_semantic_native_rejects_duplicate_nodes_and_unknown_action_binding(runtime):
    payload = {'nodes': ['model', 'model'], 'edges': [], 'stepLimit': 8,
               'conditionalEdges': [], 'actions': {}, 'reducers': {}}
    with pytest.raises(SemanticRuntimeError):
        runtime.call('graph.admit', payload)
    payload['nodes'] = ['model']
    payload['actions'] = {'missing': 'action'}
    with pytest.raises(SemanticRuntimeError):
        runtime.call('graph.admit', payload)

    payload['actions'] = {}
    payload['conditionalEdges'] = [{'source': 'model', 'router': 'choose', 'routes': {}}] * 2
    with pytest.raises(SemanticRuntimeError, match="duplicate conditional router"):
        runtime.call('graph.admit', payload)


def test_semantic_native_queue_bound_and_digest_rejection(runtime):
    import threading
    with pytest.raises(SemanticRuntimeError, match='digest mismatch'):
        SemanticRuntime(os.environ['AGENTIC_AI_LAB_SEMANTIC_LIBRARY'], expected_digest='0'*64)
    entered = threading.Event(); release = threading.Event()
    def block_owner():
        entered.set()
        assert release.wait(2)
    blocker = runtime._worker.submit(block_owner)
    assert entered.wait(1)
    pending = []
    try:
        pending = [runtime._submit('descriptor', {}) for _ in range(64)]
        with pytest.raises(SemanticRuntimeError) as error:
            runtime.call('descriptor', {})
        assert error.value.status == 7
        for future in pending:
            assert future.cancel()
    finally:
        release.set(); blocker.result()
    assert runtime.call('descriptor', {})['abiVersion'] == 1


def test_semantic_answer_validation_binds_current_source(runtime):
    task = temporal_request()
    output = '(object ("rows" (list (list "a" "b") (list "a" "c"))) ("status" "complete"))'
    assert runtime.validate_model_answer(task, output)['verdict'] == 'consistent'
    assert runtime.validate_model_answer(task, '(object ("rows" (list)) ("status" "complete"))')['verdict'] == 'contradicted'
    task['source']['parents'].clear()
    assert runtime.validate_model_answer(task, output)['verdict'] == 'contradicted'


def test_semantic_native_rejects_excess_finite_domain_before_solver(runtime):
    task = temporal_request()
    task['source']['events'] *= 50
    with pytest.raises(SemanticRuntimeError) as error:
        runtime.call('temporal.solve', task)
    assert error.value.status == 4


def test_semantic_native_routes_and_dynamic_targets_are_scheme_owned(runtime):
    from agentic_ai_lab_runtime import (START, END, RuntimeGraphPlan, RuntimeGraphEdge,
        RuntimeGraphConditionalEdge, RuntimeGraphProgram, RuntimeGraphRegistries,
        RuntimeGraphRuntime, RuntimeGraphBindings)
    from agentic_ai_lab_runtime._native.session import NativeRuntimeSession, NativeBundleDescriptor
    plan = RuntimeGraphPlan(nodes=('decide', 'left', 'right'),
        edges=(RuntimeGraphEdge(START, 'decide'), RuntimeGraphEdge('left', END),
               RuntimeGraphEdge('right', END)),
        conditional_edges=(RuntimeGraphConditionalEdge('decide', 'route',
                          {'yes': 'right', 'no': 'left'}),))
    binding = runtime.bind_graph(plan, RuntimeGraphBindings())
    assert binding.static_successors[START] == ('decide',)
    assert binding.targets('decide', 'route', router='route', labels=['yes']) == ['right']
    with pytest.raises(SemanticRuntimeError):
        binding.targets('decide', 'route', router='route', labels=['unknown'])
    with pytest.raises(SemanticRuntimeError):
        binding.targets('decide', 'control', targets=['missing'])
    with pytest.raises(SemanticRuntimeError):
        runtime.call('graph.targets', dict(plan=binding.payload, expectedDigest='0'*64,
                     source='decide', mode='control', targets=['right']))
    with NativeRuntimeSession(NativeBundleDescriptor(bytes(32), 1, b'bundle'),
            library_path=os.environ['AGENTIC_AI_LAB_RUNTIME_V0_LIBRARY']) as session:
        registries = RuntimeGraphRegistries(actions={
            'decide': lambda state: {}, 'left': lambda state: {'answer': 'left'},
            'right': lambda state: {'answer': 'right'}},
            routers={'route': lambda state: state['label']})
        program = RuntimeGraphProgram(plan=plan, registries=registries,
            runtime=RuntimeGraphRuntime.native(session, semantic_context=runtime))
        assert program.invoke({'label': 'yes'})['answer'] == 'right'
        assert asyncio.run(program.ainvoke({'label': 'no'}))['answer'] == 'left'
        with pytest.raises(SemanticRuntimeError):
            program.invoke({'label': 'unknown'})


def test_semantic_abi_v1_rejects_legacy_json_and_reader_extensions(runtime):
    import ctypes
    native = ctypes.CDLL(os.environ['AGENTIC_AI_LAB_SEMANTIC_LIBRARY'])
    with pytest.raises(AttributeError):
        getattr(native, 'agentic_ai_lab_semantic_open')
    with pytest.raises(AttributeError):
        getattr(native, 'agentic_ai_lab_semantic_v2_open')
    assert runtime.descriptor['wireFormat'] == 'scheme-datum-v1'
    for data in [b'{}', b'#.(exit)', b'#0=(list #0#)', b'(object ("a" 1) ("a" 2))']:
        result = runtime._ffi.new('agentic_ai_lab_semantic_result *')
        status = runtime._worker.submit(runtime._lib.agentic_ai_lab_python_semantic_call,
            b'descriptor', data, len(data), result).result()
        try:
            assert status == 4
        finally:
            runtime._lib.agentic_ai_lab_python_semantic_release(result)
    assert runtime.call('descriptor', {})['abiVersion'] == 1
