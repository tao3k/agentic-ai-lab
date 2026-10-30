# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Crash/reopen reconciliation tests for native AC-08 evidence state."""

from pathlib import Path

import pytest

from agentic_ai_lab_runtime import (
    AuthorizedEffectEvidenceReservation,
    TursoAuthorizedEffectEvidenceStore,
)
from agentic_ai_lab_runtime._native.arena import NativeEvent, NativeMediation
from agentic_ai_lab_runtime._native.errors import NativeRuntimeError
from agentic_ai_lab_runtime._native.loader import native_library_path
from agentic_ai_lab_runtime._native.session import NativeBundleDescriptor, NativeRuntimeSession


def _repo_library() -> Path:
    return native_library_path()


def _sink(store, root: bytes, row: str):
    return store.native_sink(
        session_id="recovered-session",
        committed_execution_root=root,
        evidence_reference=row,
        kernel_signature=b"kernel-signature",
    )


def test_native_session_reconciles_durable_root_and_nonce_after_reopen(
    tmp_path: Path,
) -> None:
    pytest.importorskip("agentic_ai_lab_runtime._native._runtime_v0_cffi")
    library = _repo_library()
    if not library.is_file():
        pytest.skip("focused runtime-C build has not run")
    database = tmp_path / "native-evidence.db"
    bundle = NativeBundleDescriptor(bytes.fromhex("88" * 32), 12, b"bundle")
    root = bytes.fromhex("aa" * 32)
    semantic_root = bytes.fromhex("55" * 32)
    evidence = TursoAuthorizedEffectEvidenceStore(database)
    with NativeRuntimeSession(bundle, library_path=library) as session:
        with session.arena(bytearray(4096)) as arena:
            mediation = NativeMediation(
                nonce=(0, 91), semantic_root=semantic_root,
                before_execution_root=bytes(32), after_execution_root=root,
                observation_digest=bytes.fromhex("bb" * 32),
            )
            arena.roundtrip((NativeEvent(1),), mediation, _sink(evidence, root, "row-1"))
    evidence.reserve(
        AuthorizedEffectEvidenceReservation(
            "recovered-session", 2, 2, 2, (0, 92), semantic_root, root
        )
    )
    evidence.close()

    reopened = TursoAuthorizedEffectEvidenceStore(database)
    reconciliation = reopened.reconciliation("recovered-session")
    assert reconciliation is not None
    assert reconciliation.consumed_nonces == ((0, 91), (0, 92))
    _assert_replay_rejected(bundle, library, reopened, reconciliation, root, semantic_root)
    _assert_fork_rejected(bundle, library, reopened, reconciliation, semantic_root)
    reopened.close()


def test_native_batched_leaf_reopens_and_flushes_without_adapter_replay(
    tmp_path: Path,
) -> None:
    pytest.importorskip("agentic_ai_lab_runtime._native._runtime_v0_cffi")
    library = _repo_library()
    if not library.is_file():
        pytest.skip("focused runtime-C build has not run")
    database = tmp_path / "native-batched-evidence.db"
    bundle = NativeBundleDescriptor(bytes.fromhex("89" * 32), 13, b"bundle")
    semantic_root = bytes.fromhex("56" * 32)
    evidence = TursoAuthorizedEffectEvidenceStore(database)
    sink = _sink(evidence, bytes.fromhex("aa" * 32), "batched-row")
    with NativeRuntimeSession(
        bundle, library_path=library, batched_evidence=True
    ) as session:
        with session.arena(bytearray(4096)) as arena:
            buffered = arena.roundtrip(
                (NativeEvent(1),),
                NativeMediation(
                    nonce=(0, 101),
                    semantic_root=semantic_root,
                    before_execution_root=bytes(32),
                    after_execution_root=bytes.fromhex("aa" * 32),
                    observation_digest=bytes.fromhex("bc" * 32),
                    durability=2,
                    input_digest=bytes.fromhex("ab" * 32),
                ),
                sink,
            )
            assert buffered.mediation_outcome == 2
            assert buffered.execution_root == bytes(32)
    evidence.close()

    reopened = TursoAuthorizedEffectEvidenceStore(database)
    reconciliation = reopened.reconciliation("recovered-session")
    assert reconciliation is not None
    assert reconciliation.staged_mediation_sequences == (1,)
    assert len(reconciliation.staged_leaf_digests) == 1
    with NativeRuntimeSession(
        bundle, library_path=library, batched_evidence=True
    ) as recovered:
        recovered.reconcile_evidence(reconciliation)
        committed = recovered.flush_batched(
            bytes(32), _sink(reopened, bytes(32), "batched-flush")
        )
    assert committed.after_execution_root != bytes(32)
    after = reopened.reconciliation("recovered-session")
    assert after is not None
    assert after.execution_root == committed.after_execution_root
    assert after.staged_leaf_digests == ()
    reopened.close()


def _assert_replay_rejected(bundle, library, store, reconciliation, root, semantic_root):
    with NativeRuntimeSession(bundle, library_path=library) as recovered:
        recovered.reconcile_evidence(reconciliation)
        with recovered.arena(bytearray(4096)) as arena:
            replay = NativeMediation(
                nonce=(0, 92), semantic_root=semantic_root,
                before_execution_root=root, after_execution_root=bytes.fromhex("cc" * 32),
                observation_digest=bytes.fromhex("bb" * 32),
            )
            with pytest.raises(NativeRuntimeError) as error:
                arena.roundtrip((NativeEvent(3),), replay, _sink(store, replay.after_execution_root, "row-3"))
            assert error.value.status == 21


def _assert_fork_rejected(bundle, library, store, reconciliation, semantic_root):
    with NativeRuntimeSession(bundle, library_path=library) as recovered:
        recovered.reconcile_evidence(reconciliation)
        with recovered.arena(bytearray(4096)) as arena:
            fork = NativeMediation(
                nonce=(0, 93), semantic_root=semantic_root,
                before_execution_root=bytes(32), after_execution_root=bytes.fromhex("dd" * 32),
                observation_digest=bytes.fromhex("bb" * 32),
            )
            with pytest.raises(NativeRuntimeError) as error:
                arena.roundtrip((NativeEvent(3),), fork, _sink(store, fork.after_execution_root, "row-3"))
            assert error.value.status == 22
