# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Native admission integration and independent C storage failure receipts."""
import concurrent.futures
import sqlite3
import subprocess
import sys

import pytest
from agentic_ai_lab_runtime.temporal_publication import TemporalPublicationStore, TemporalPublicationError
from agentic_ai_lab_runtime._native._temporal_store import ffi, lib
from test_temporal_admission import source_scope
from test_temporal_family import family_task


def grant(store, fence=1, enabled=True):
    store.authorize_selection(subject='release', scope='release-evidence',
        policy='policy-1', authority='host-policy', fence=fence, enabled=enabled)


def prepared(runtime, tmp_path, name):
    store = TemporalPublicationStore(tmp_path / 'state.db')
    scope, task = source_scope(name), family_task()
    source = store.register_source(runtime, scope, task)
    args = dict(source_identity=name, source_digest=source['sourceDigest'],
                conclusion_identity='root', idempotency_key='publish-1', authorization_fence=1)
    return store, scope, task, args


def test_native_admission_commit_and_recovery(runtime, tmp_path):
    store, scope, task, args = prepared(runtime, tmp_path, 'publication-success')
    with store:
        with pytest.raises(TemporalPublicationError) as error:
            store.publish(runtime, task, **args)
        assert error.value.status == 3
        assert store.pointer('release', 'release-evidence') == (0, '')
        grant(store)
        receipt = store.publish(runtime, task, **args)
        assert receipt['version'] == 1 and receipt['previous_version'] == 0
        assert store.pointer('release', 'release-evidence') == (1, receipt['revision'])
        assert receipt['selectionAuthorized'] and not receipt['externalEffectAuthorized']
        with pytest.raises(TypeError):
            receipt['version'] = 2
        grant(store, fence=2, enabled=False)
        assert store.publish(runtime, task, **args) == receipt
        with pytest.raises(TemporalPublicationError) as error:
            store.publish(runtime, task, **dict(args, conclusion_identity='changed'))
        assert error.value.status == 5
    with TemporalPublicationStore(tmp_path / 'state.db') as reopened:
        assert reopened.recover('publish-1') == receipt
        assert reopened.recover('absent') is None


def test_source_and_authorization_fences(runtime, tmp_path):
    store, scope, task, args = prepared(runtime, tmp_path, 'publication-fences')
    with store:
        grant(store, fence=2)
        with pytest.raises(TemporalPublicationError) as error:
            store.publish(runtime, task, **args)
        assert error.value.status == 3
        with pytest.raises(TemporalPublicationError):
            grant(store, fence=1)
        with pytest.raises(TemporalPublicationError):
            grant(store, fence=2, enabled=False)
        # Independent host advances the shared durable source fence; this
        # process's valid native admission must still fail at transaction time.
        assert lib.agentic_ai_lab_temporal_store_source(store._handle[0],
            scope['identity'].encode(), ('sha256:' + 'f'*64).encode(), 2) == 0
        with pytest.raises(TemporalPublicationError) as error:
            store.publish(runtime, task, **dict(args, authorization_fence=2))
        assert error.value.status == 4
        assert lib.agentic_ai_lab_temporal_store_source(store._handle[0],
            scope['identity'].encode(), args['source_digest'].encode(), 1) == 4
        assert store.pointer('release', 'release-evidence') == (0, '')


def test_failed_receipt_write_rolls_back_pointer(runtime, tmp_path):
    store, _, task, args = prepared(runtime, tmp_path, 'publication-rollback')
    with store:
        grant(store)
        with sqlite3.connect(tmp_path / 'state.db') as db:
            db.execute("CREATE TRIGGER fail_receipt BEFORE INSERT ON temporal_commits BEGIN SELECT RAISE(ABORT,'injected write failure'); END")
        with pytest.raises(TemporalPublicationError) as error:
            store.publish(runtime, task, **args)
        assert error.value.status == 6
        assert store.pointer('release', 'release-evidence') == (0, '')
        assert store.recover('publish-1') is None
        with sqlite3.connect(tmp_path / 'state.db') as db:
            db.execute('DROP TRIGGER fail_receipt')
        assert store.publish(runtime, task, **args)['version'] == 1


def basis():
    value = ffi.new('agentic_ai_lab_temporal_basis *')
    for name in ['admission', 'source_digest', 'revision', 'proof']:
        setattr(value[0], name, ('sha256:' + 'a'*64).encode())
    value.source = b'fixture'; value.subject = b'release'
    value.scope = b'release-evidence'; value.policy = b'policy-1'; value.generation = 1
    return value


def raw_commit(store, key):
    out = ffi.new('agentic_ai_lab_temporal_commit_receipt *')
    return lib.agentic_ai_lab_temporal_store_commit(store._handle[0], basis(), key.encode(),
        ('sha256:' + 'b'*64).encode(), 0, b'', 1, out)


def test_two_independent_c_handles_compete_once(tmp_path):
    with TemporalPublicationStore(tmp_path / 'state.db') as one, TemporalPublicationStore(tmp_path / 'state.db') as two:
        grant(one)
        assert lib.agentic_ai_lab_temporal_store_source(one._handle[0], b'fixture', basis().source_digest, 1) == 0
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            a = pool.submit(raw_commit, one, 'one'); b = pool.submit(raw_commit, two, 'two')
            assert sorted([a.result(), b.result()]) == [0, 2]
        assert one.pointer('release', 'release-evidence')[0] == 1
        assert sum(one.recover(k) is not None for k in ['one', 'two']) == 1


def test_sigkill_after_commit_recovers_without_native_runtime(tmp_path):
    # Trusted C fixture isolates process-crash recovery from semantic admission.
    script = '''
import sys
from agentic_ai_lab_runtime.temporal_publication import TemporalPublicationStore
from agentic_ai_lab_runtime._native._temporal_store import ffi, lib
s=TemporalPublicationStore(sys.argv[1])
s.authorize_selection(subject='release',scope='release-evidence',policy='policy-1',authority='host-policy',fence=1)
b=ffi.new('agentic_ai_lab_temporal_basis *')
for n in ['admission','source_digest','revision','proof']: setattr(b[0],n,('sha256:'+'a'*64).encode())
b.source=b'fixture';b.subject=b'release';b.scope=b'release-evidence';b.policy=b'policy-1';b.generation=1
assert lib.agentic_ai_lab_temporal_store_source(s._handle[0],b.source,b.source_digest,1)==0
o=ffi.new('agentic_ai_lab_temporal_commit_receipt *')
assert lib.agentic_ai_lab_temporal_store_commit(s._handle[0],b,b'crash',('sha256:'+'b'*64).encode(),0,b'',1,o)==0
print('COMMITTED',flush=True)
import signal
while True: signal.pause()
'''
    child = subprocess.Popen([sys.executable, '-c', script, str(tmp_path / 'state.db')],
                             stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    try:
        import selectors
        with selectors.DefaultSelector() as ready:
            ready.register(child.stdout, selectors.EVENT_READ)
            assert ready.select(timeout=5), 'child made no progress within five seconds'
        assert child.stdout.readline().strip() == 'COMMITTED'
        assert child.poll() is None
        child.kill(); child.wait(timeout=5)
        # Gambit may reap SIGCHLD before subprocess.wait observes its status.
        import os
        with pytest.raises(ProcessLookupError):
            os.kill(child.pid, 0)
        with TemporalPublicationStore(tmp_path / 'state.db') as recovered:
            receipt = recovered.recover('crash')
            assert receipt['version'] == 1
            assert recovered.pointer('release', 'release-evidence') == (1, receipt['revision'])
    finally:
        if child.poll() is None:
            child.kill(); child.wait(timeout=5)


def test_closed_store_and_invalid_fence(tmp_path):
    store = TemporalPublicationStore(tmp_path / 'state.db')
    with pytest.raises(ValueError):
        grant(store, fence=True)
    store.close(); store.close()
    with pytest.raises(RuntimeError, match='closed'):
        store.recover('key')

@pytest.mark.parametrize('changed', ['subject', 'scope', 'policy', 'revoked'])
def test_grant_is_scoped_and_revocable(runtime, tmp_path, changed):
    store, _, task, args = prepared(runtime, tmp_path, 'publication-grant-' + changed)
    with store:
        values = dict(subject='release', scope='release-evidence', policy='policy-1',
                      authority='host-policy', fence=1)
        if changed != 'revoked':
            values[changed] = 'foreign'
        store.authorize_selection(**values)
        if changed == 'revoked':
            store.authorize_selection(**dict(values, fence=2, enabled=False))
            args['authorization_fence'] = 2
        with pytest.raises(TemporalPublicationError) as error:
            store.publish(runtime, task, **args)
        assert error.value.status == 3
        assert store.recover('publish-1') is None
        assert store.pointer('release', 'release-evidence') == (0, '')
