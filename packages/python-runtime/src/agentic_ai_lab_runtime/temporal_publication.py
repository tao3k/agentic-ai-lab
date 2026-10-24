# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Host-controlled first-root publication. Grants authorize local selection only."""
from __future__ import annotations

import hashlib
from . import scheme_wire as wire
from pathlib import Path
import threading
from types import MappingProxyType

from ._native._temporal_store import ffi, lib


class TemporalPublicationError(RuntimeError):
    def __init__(self, status):
        self.status = status
        super().__init__({1: 'invalid publication input', 2: 'pointer conflict',
                         3: 'selection authorization denied', 4: 'stale source',
                         5: 'idempotency mismatch', 6: 'storage failure',
                         7: 'receipt absent'}[status])


def _check(status):
    if status:
        raise TemporalPublicationError(status)


def _text(value):
    if not isinstance(value, str) or '\0' in value or not 0 < len(value.encode()) <= 128:
        raise ValueError('host identifier must contain 1..128 UTF-8 bytes')
    return value.encode()


def _number(value):
    if type(value) is not int or not 0 <= value <= 2**63 - 1:
        raise ValueError('fence/version must be an unsigned SQLite integer')
    return value


def _datum(value):
    return wire.dumps(value).encode()


def _receipt(out):
    fields = ['store_identity', 'key', 'request_digest', 'admission', 'subject',
              'scope', 'policy', 'revision', 'proof', 'source_digest', 'authority']
    result = {k: ffi.string(getattr(out, k)).decode() for k in fields}
    for k in ['previous_version', 'version', 'authorization_fence', 'source_generation']:
        result[k] = int(getattr(out, k))
    result.update(selectionAuthorized=True, externalEffectAuthorized=False,
                  authorizationBasis='host-scoped-fence')
    return MappingProxyType(result)


class TemporalPublicationStore:
    """Trusted host port, never expose grants or source registration as model tools.

    The SQLite C transaction checks source, grant and pointer fences and writes
    the receipt atomically. The first-root profile requires an empty predecessor.
    Recovery is available independently of the Scheme process lifetime.
    """
    def __init__(self, path):
        self._lock = threading.RLock()
        self._handle = ffi.new('agentic_ai_lab_temporal_store **')
        _check(lib.agentic_ai_lab_temporal_store_open(str(Path(path).resolve()).encode(), self._handle))

    def _open(self):
        if self._handle[0] == ffi.NULL:
            raise RuntimeError('publication store is closed')
        return self._handle[0]

    def close(self):
        with self._lock:
            if self._handle[0] != ffi.NULL:
                lib.agentic_ai_lab_temporal_store_close(self._handle[0])
                self._handle[0] = ffi.NULL

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()

    def authorize_selection(self, *, subject, scope, policy, authority, fence, enabled=True):
        if type(enabled) is not bool:
            raise ValueError('enabled must be boolean')
        with self._lock:
            _check(lib.agentic_ai_lab_temporal_store_authorize(self._open(), _text(subject),
                _text(scope), _text(policy), _text(authority), _number(fence), int(enabled)))

    def pointer(self, subject, scope):
        with self._lock:
            version, selected = ffi.new('uint64_t *'), ffi.new('char[129]')
            _check(lib.agentic_ai_lab_temporal_store_pointer(self._open(), _text(subject),
                                                      _text(scope), version, selected))
            return int(version[0]), ffi.string(selected).decode()

    def recover(self, key):
        with self._lock:
            out = ffi.new('agentic_ai_lab_temporal_commit_receipt *')
            status = lib.agentic_ai_lab_temporal_store_receipt(self._open(), _text(key), out)
            if status == 7:
                return None
            _check(status)
            return _receipt(out[0])

    def register_source(self, runtime, scope, task):
        # Freeze caller input before queueing; native source update and durable
        # fence update cannot be separated by another local semantic operation.
        data = _datum({'scope': scope, 'task': task})
        def register():
            with self._lock:
                handle = self._open()
                result = runtime._call(b'$host.temporal.source.register', data, control=True)
                snapshot = wire.loads(data)['scope']
                _check(lib.agentic_ai_lab_temporal_store_source(handle, _text(snapshot['identity']),
                    _text(result['sourceDigest']), _number(snapshot['generation'])))
                return result
        return runtime._submit_host(register).result()

    def publish(self, runtime, task, *, source_identity, source_digest,
                conclusion_identity, idempotency_key, authorization_fence,
                expected_version=0, expected_revision=''):
        version, fence = _number(expected_version), _number(authorization_fence)
        if expected_revision != '':
            _text(expected_revision)
        key = _text(idempotency_key)
        data = _datum({'task': task, 'sourceIdentity': source_identity,
                      'sourceDigest': source_digest, 'conclusionIdentity': conclusion_identity})
        if len(data) > 1048576:
            raise ValueError('semantic input exceeds maximum bytes')
        request = 'sha256:' + hashlib.sha256(_datum(["agentic-ai-lab.temporal-publication-request.v1", wire.loads(data), version,
                                                  expected_revision, fence])).hexdigest()
        def commit():
            with self._lock:
                handle = self._open()
                old = self.recover(idempotency_key)
                if old is not None:
                    if old['request_digest'] != request:
                        raise TemporalPublicationError(5)
                    return old
                admitted = runtime._call(b'temporal.family.admit', data)
                if (admitted.get('schema') != 'agentic-ai-lab.temporal-family-admission.v1'
                        or admitted.get('sourceVerified') is not True
                        or admitted.get('trustBasis') != 'host-registered-snapshot'
                        or admitted['conclusion']['operation'] != 'assert'):
                    raise ValueError('native result is not a root admission')
                root = admitted['conclusion']
                basis = ffi.new('agentic_ai_lab_temporal_basis *')
                values = dict(admission=admitted['admissionDigest'], source=source_identity,
                    source_digest=admitted['sourceDigest'], subject=root['subject'],
                    scope=root['scope'], policy=root['policy'], revision=root['identity'],
                    proof=root['proofDigest'])
                for field, value in values.items():
                    setattr(basis[0], field, _text(value))
                basis.generation = _number(int(root['generation']))
                out = ffi.new('agentic_ai_lab_temporal_commit_receipt *')
                _check(lib.agentic_ai_lab_temporal_store_commit(handle, basis, key, request.encode(),
                    version, expected_revision.encode(), fence, out))
                return _receipt(out[0])
        return runtime._submit_host(commit).result()
